import 'dart:typed_data';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import '../models/isar_chat_model.dart';
import '../core/chat_crypto.dart';
import 'isar_storage_service.dart';
import 'chat_socket_service.dart';
import 'user_profile_cache_manager.dart';

class ChatController extends GetxController {
  static String get currentUserId => UserProfileCacheManager.currentUserId;
  static String get currentUserName => Supabase.instance.client.auth.currentUser?.email ?? 'Anurag Kumar';
  static String get currentUserAvatar => '';

  // ─── Conversations list ───
  final RxList<Conversation> conversations = <Conversation>[].obs;

  // ─── Messages per conversation ───
  final RxMap<String, List<ChatMessage>> _messages =
      <String, List<ChatMessage>>{}.obs;

  // ─── Typing state ───
  final RxMap<String, bool> typingState = <String, bool>{}.obs;

  // ─── Search ───
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;

  // ─── Selected messages (for multi-select) ───
  final RxSet<String> selectedMessageIds = <String>{}.obs;
  final RxBool isSelectionMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadConversationsFromIsar();
  }

  Future<void> _loadConversationsFromIsar() async {
    try {
      final isarConvs = await IsarStorageService.to.getAllConversations();
      final list = isarConvs.map((c) {
        return Conversation(
          id: c.uuid,
          otherUserId: c.otherUserId,
          otherUserName: c.otherUserName,
          otherUserAvatar: c.otherUserAvatar,
          otherUserOnline: c.otherUserOnline,
          isVerified: c.isVerified,
          lastMessage: c.lastMessage,
          lastMessageTime: c.lastMessageTime,
          unreadCount: c.unreadCount,
          isPinned: c.isPinned,
          isMuted: c.isMuted,
          levelTitle: c.levelTitle,
          level: c.level,
          lastMessageSenderId: c.lastMessageSenderId,
        );
      }).toList();
      
      Future.microtask(() {
        conversations.assignAll(list);
      });
    } catch (_) {}
  }

  Future<void> _loadMessagesFromIsar(String convId) async {
    try {
      final isarMsgs = await IsarStorageService.to.getMessagesForConversation(convId, limit: 100);
      final list = isarMsgs.map((m) {
        return ChatMessage(
          id: m.uuid,
          senderId: m.senderId,
          receiverId: m.receiverId,
          conversationId: m.conversationId,
          content: m.content,
          timestamp: m.timestamp,
          status: MessageStatus.values[m.statusValue],
          type: MessageType.values[m.typeValue],
          reactions: m.reactions,
          isDeleted: m.isDeleted,
          isEdited: m.isEdited,
        );
      }).toList();
      
      Future.microtask(() {
        _messages[convId] = list.reversed.toList(); // Isar returns chronological order
        _messages.refresh();
      });
    } catch (_) {}
  }

  List<Conversation> get filteredConversations {
    if (searchQuery.isEmpty) return conversations;
    return conversations
        .where((c) =>
            c.otherUserName
                .toLowerCase()
                .contains(searchQuery.value.toLowerCase()) ||
            c.lastMessage
                .toLowerCase()
                .contains(searchQuery.value.toLowerCase()))
        .toList();
  }

  Conversation getOrCreateConversation(String otherUserId, String otherUserName, String otherUserAvatar) {
    final String convId = 'conv_$otherUserId';
    final int idx = conversations.indexWhere((c) => c.id == convId || c.otherUserId == otherUserId);
    if (idx != -1) {
      return conversations[idx];
    }
    final newConv = Conversation(
      id: convId,
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      otherUserAvatar: otherUserAvatar,
      lastMessage: 'Started chat',
      lastMessageTime: DateTime.now(),
      otherUserOnline: true,
    );
    conversations.add(newConv);

    // Save to local Isar DB (Single Source of Truth)
    final isarConv = IsarConversation()
      ..uuid = convId
      ..otherUserId = otherUserId
      ..otherUserName = otherUserName
      ..otherUserAvatar = otherUserAvatar
      ..lastMessage = 'Started chat'
      ..lastMessageTime = DateTime.now()
      ..otherUserOnline = true
      ..isVerified = false
      ..unreadCount = 0
      ..isPinned = false
      ..isMuted = false
      ..levelTitle = 'Newbie'
      ..level = 0
      ..lastMessageSenderId = '';
    IsarStorageService.to.saveConversation(isarConv);

    return newConv;
  }

  List<ChatMessage> getMessages(String conversationId) {
    if (!_messages.containsKey(conversationId)) {
      _messages[conversationId] = [];
      _loadMessagesFromIsar(conversationId);
    }
    return _messages[conversationId] ?? [];
  }

  void sendMessage(String conversationId, String content) async {
    if (content.trim().isEmpty) return;

    final int idxSearch = conversations.indexWhere((c) => c.id == conversationId);
    final conv = idxSearch != -1 
        ? conversations[idxSearch] 
        : getOrCreateConversation(
            conversationId.startsWith('conv_') ? conversationId.substring(5) : conversationId,
            'User',
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100',
          );

    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    final msg = ChatMessage(
      id: msgId,
      senderId: currentUserId,
      receiverId: conv.otherUserId,
      conversationId: conversationId,
      content: content.trim(),
      timestamp: now,
      status: MessageStatus.sending,
    );

    // 1. Write message directly to local Isar DB (Single Source of Truth)
    final isarMsg = IsarChatMessage()
      ..uuid = msgId
      ..senderId = currentUserId
      ..receiverId = conv.otherUserId
      ..conversationId = conversationId
      ..content = content.trim()
      ..typeValue = MessageType.text.index
      ..statusValue = MessageStatus.sending.index
      ..timestamp = now
      ..isDeleted = false
      ..isEdited = false;
    await IsarStorageService.to.saveMessage(isarMsg);

    // Update conversation metadata locally in Isar
    final isarConv = IsarConversation()
      ..uuid = conv.id
      ..otherUserId = conv.otherUserId
      ..otherUserName = conv.otherUserName
      ..otherUserAvatar = conv.otherUserAvatar
      ..lastMessage = content.trim()
      ..lastMessageTime = now
      ..otherUserOnline = conv.otherUserOnline
      ..isVerified = conv.isVerified
      ..unreadCount = 0
      ..isPinned = conv.isPinned
      ..isMuted = conv.isMuted
      ..levelTitle = conv.levelTitle
      ..level = conv.level
      ..lastMessageSenderId = currentUserId;
    await IsarStorageService.to.saveConversation(isarConv);

    // 2. Update memory stream and trigger state updates instantly
    final current = getMessages(conversationId);
    _messages[conversationId] = [...current, msg];
    _messages.refresh();

    final idx = conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      conversations[idx] = Conversation(
        id: conv.id,
        otherUserId: conv.otherUserId,
        otherUserName: conv.otherUserName,
        otherUserAvatar: conv.otherUserAvatar,
        otherUserOnline: conv.otherUserOnline,
        isVerified: conv.isVerified,
        lastMessage: content.trim(),
        lastMessageTime: now,
        unreadCount: 0,
        isPinned: conv.isPinned,
        isMuted: conv.isMuted,
        levelTitle: conv.levelTitle,
        level: conv.level,
        lastMessageSenderId: currentUserId,
      );
    }
    conversations.refresh();

    // 3. Emit message event to Socket.IO layer (handled asynchronously)
    ChatSocketService.to.emitMessage(msg);
  }

  // ─── Socket Event Receivers ───

  void onMessageReceivedFromSocket(ChatMessage msg) async {
    final current = getMessages(msg.conversationId);
    if (!current.any((m) => m.id == msg.id)) {
      _messages[msg.conversationId] = [...current, msg];
      _messages.refresh();

      // Update conversation last message in memory list
      final idx = conversations.indexWhere((c) => c.id == msg.conversationId);
      if (idx != -1) {
        final conv = conversations[idx];
        conversations[idx] = Conversation(
          id: conv.id,
          otherUserId: conv.otherUserId,
          otherUserName: conv.otherUserName,
          otherUserAvatar: conv.otherUserAvatar,
          otherUserOnline: conv.otherUserOnline,
          isVerified: conv.isVerified,
          lastMessage: msg.content,
          lastMessageTime: msg.timestamp,
          unreadCount: conv.unreadCount + 1,
          isPinned: conv.isPinned,
          isMuted: conv.isMuted,
          levelTitle: conv.levelTitle,
          level: conv.level,
          lastMessageSenderId: msg.senderId,
        );

        // Save new conversation state in Isar
        final isarConv = IsarConversation()
          ..uuid = conv.id
          ..otherUserId = conv.otherUserId
          ..otherUserName = conv.otherUserName
          ..otherUserAvatar = conv.otherUserAvatar
          ..lastMessage = msg.content
          ..lastMessageTime = msg.timestamp
          ..otherUserOnline = conv.otherUserOnline
          ..isVerified = conv.isVerified
          ..unreadCount = conv.unreadCount + 1
          ..isPinned = conv.isPinned
          ..isMuted = conv.isMuted
          ..levelTitle = conv.levelTitle
          ..level = conv.level
          ..lastMessageSenderId = msg.senderId;
        await IsarStorageService.to.saveConversation(isarConv);
      }
      conversations.refresh();
    }
  }

  void updateMessageStatus(String msgId, MessageStatus status) {
    _messages.forEach((convId, list) {
      final idx = list.indexWhere((m) => m.id == msgId);
      if (idx != -1) {
        final currentList = List<ChatMessage>.from(list);
        currentList[idx] = currentList[idx].copyWith(status: status);
        _messages[convId] = currentList;
        _messages.refresh();
      }
    });
  }

  void setTypingFromSocket(String conversationId, bool isTyping) {
    typingState[conversationId] = isTyping;
    typingState.refresh();
  }

  // ─── Actions ───

  void addReaction(String conversationId, String messageId, String emoji) {
    final msgs = _messages[conversationId] ?? [];
    final updatedMsgs = msgs.map((m) {
      if (m.id == messageId) {
        final existing = List<String>.from(m.reactions ?? []);
        if (existing.contains(emoji)) {
          existing.remove(emoji);
        } else {
          existing.add(emoji);
        }
        return m.copyWith(reactions: existing);
      }
      return m;
    }).toList();
    _messages[conversationId] = updatedMsgs;
    _messages.refresh();
  }

  void deleteMessage(String conversationId, String messageId) async {
    final msgs = _messages[conversationId] ?? [];
    final updatedMsgs = msgs.map((m) {
      if (m.id == messageId) return m.copyWith(isDeleted: true);
      return m;
    }).toList();
    _messages[conversationId] = updatedMsgs;
    _messages.refresh();

    // Delete in Isar
    await IsarStorageService.to.deleteMessage(messageId);
  }

  void markConversationRead(String conversationId) async {
    final idx = conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      final conv = conversations[idx];
      conversations[idx] = Conversation(
        id: conv.id,
        otherUserId: conv.otherUserId,
        otherUserName: conv.otherUserName,
        otherUserAvatar: conv.otherUserAvatar,
        otherUserOnline: conv.otherUserOnline,
        isVerified: conv.isVerified,
        lastMessage: conv.lastMessage,
        lastMessageTime: conv.lastMessageTime,
        unreadCount: 0,
        isPinned: conv.isPinned,
        isMuted: conv.isMuted,
        levelTitle: conv.levelTitle,
        level: conv.level,
        lastMessageSenderId: conv.lastMessageSenderId,
      );
      conversations.refresh();

      // Update Isar
      final isarConv = await IsarStorageService.to.getConversation(conversationId);
      if (isarConv != null) {
        isarConv.unreadCount = 0;
        await IsarStorageService.to.saveConversation(isarConv);
      }

      // Notify peer via Socket
      ChatSocketService.to.emitReadReceipt(conversationId, conv.otherUserId);
    }
  }

  void setTyping(String conversationId, bool value) {
    typingState[conversationId] = value;
    typingState.refresh();
    ChatSocketService.to.emitTypingState(conversationId, value);
  }

  int get totalUnread =>
      conversations.fold(0, (sum, c) => sum + c.unreadCount);

  void togglePin(String conversationId) async {
    final idx = conversations.indexWhere((c) => c.id == conversationId);
    if (idx == -1) return;
    final conv = conversations[idx];
    conversations[idx] = Conversation(
      id: conv.id,
      otherUserId: conv.otherUserId,
      otherUserName: conv.otherUserName,
      otherUserAvatar: conv.otherUserAvatar,
      otherUserOnline: conv.otherUserOnline,
      isVerified: conv.isVerified,
      lastMessage: conv.lastMessage,
      lastMessageTime: conv.lastMessageTime,
      unreadCount: conv.unreadCount,
      isPinned: !conv.isPinned,
      isMuted: conv.isMuted,
      levelTitle: conv.levelTitle,
      level: conv.level,
    );
    conversations.refresh();

    // Update Isar
    final isarConv = await IsarStorageService.to.getConversation(conversationId);
    if (isarConv != null) {
      isarConv.isPinned = !isarConv.isPinned;
      await IsarStorageService.to.saveConversation(isarConv);
    }
  }

  void toggleMute(String conversationId) async {
    final idx = conversations.indexWhere((c) => c.id == conversationId);
    if (idx == -1) return;
    final conv = conversations[idx];
    conversations[idx] = Conversation(
      id: conv.id,
      otherUserId: conv.otherUserId,
      otherUserName: conv.otherUserName,
      otherUserAvatar: conv.otherUserAvatar,
      otherUserOnline: conv.otherUserOnline,
      isVerified: conv.isVerified,
      lastMessage: conv.lastMessage,
      lastMessageTime: conv.lastMessageTime,
      unreadCount: conv.unreadCount,
      isPinned: conv.isPinned,
      isMuted: !conv.isMuted,
      levelTitle: conv.levelTitle,
      level: conv.level,
    );
    conversations.refresh();

    // Update Isar
    final isarConv = await IsarStorageService.to.getConversation(conversationId);
    if (isarConv != null) {
      isarConv.isMuted = !isarConv.isMuted;
      await IsarStorageService.to.saveConversation(isarConv);
    }
  }

  void deleteConversation(String conversationId) async {
    conversations.removeWhere((c) => c.id == conversationId);
    _messages.remove(conversationId);
    await IsarStorageService.to.deleteConversation(conversationId);
  }
}
