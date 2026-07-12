import 'dart:typed_data';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import '../core/chat_crypto.dart';
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

  @override
  void onInit() {
    super.onInit();
    _loadConversations().then((_) {
      _initSupabaseRealtime();
      ever(conversations, (_) => _saveConversations());
    });
  }

  Future<void> _saveConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(conversations.map((c) => c.toJson()).toList());
      await prefs.setString('chat_conversations', jsonStr);
    } catch (_) {}
  }

  Future<void> _loadConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('chat_conversations');
      if (jsonStr != null) {
        final List<dynamic> decoded = json.decode(jsonStr);
        final list = decoded.map((item) => Conversation.fromJson(item)).toList();
        conversations.assignAll(list);
      }
    } catch (_) {}
  }

  Future<void> _saveMessages(String convId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _messages[convId] ?? [];
      final jsonStr = json.encode(list.map((m) => m.toJson()).toList());
      await prefs.setString('chat_messages_$convId', jsonStr);
    } catch (_) {}
  }

  Future<void> _loadMessages(String convId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('chat_messages_$convId');
      if (jsonStr != null) {
        final List<dynamic> decoded = json.decode(jsonStr);
        final list = decoded.map((item) => ChatMessage.fromJson(item)).toList();
        _messages[convId] = list;
        _messages.refresh();
      }
    } catch (_) {}
  }

  void _initSupabaseRealtime() {
    try {
      final client = Supabase.instance.client;
      final currentAuthUser = client.auth.currentUser;
      if (currentAuthUser == null) return;

      client
          .from('messages')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: true)
          .listen((List<Map<String, dynamic>> data) {
            for (var row in data) {
              final String? senderId = row['sender_id'];
              final String? receiverId = row['receiver_id'];
              final String? encryptedContent = row['encrypted_content'];
              final String? messageId = row['id']?.toString();
              final String? createdAtStr = row['created_at'];

              if (senderId == null || receiverId == null || encryptedContent == null) continue;

              final String myId = currentAuthUser.id;
              if (senderId != myId && receiverId != myId) continue;

              final String otherUserId = (senderId == myId) ? receiverId : senderId;
              final String convId = 'conv_$otherUserId';

              final key = ChatCrypto.deriveFallbackKey(myId, otherUserId);
              final decrypted = ChatCrypto.decryptMessage(encryptedContent, key);

              final timestamp = createdAtStr != null 
                  ? DateTime.tryParse(createdAtStr) ?? DateTime.now() 
                  : DateTime.now();

              final currentMsgs = _messages[convId] ?? [];
              if (!currentMsgs.any((m) => m.id == messageId)) {
                final newMsg = ChatMessage(
                  id: messageId ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
                  senderId: senderId == myId ? currentUserId : otherUserId,
                  receiverId: receiverId == myId ? currentUserId : otherUserId,
                  conversationId: convId,
                  content: decrypted,
                  timestamp: timestamp,
                  status: MessageStatus.read,
                );
                _messages[convId] = [...currentMsgs, newMsg];
                _messages.refresh();
                _saveMessages(convId);

                getOrCreateConversation(otherUserId, 'User $otherUserId', 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100');
                final idx = conversations.indexWhere((c) => c.id == convId);
                if (idx != -1) {
                  final conv = conversations[idx];
                  conversations[idx] = Conversation(
                    id: conv.id,
                    otherUserId: conv.otherUserId,
                    otherUserName: conv.otherUserName,
                    otherUserAvatar: conv.otherUserAvatar,
                    otherUserOnline: conv.otherUserOnline,
                    isVerified: conv.isVerified,
                    lastMessage: decrypted,
                    lastMessageTime: timestamp,
                    unreadCount: conv.unreadCount,
                    isPinned: conv.isPinned,
                    isMuted: conv.isMuted,
                    levelTitle: conv.levelTitle,
                    level: conv.level,
                    lastMessageSenderId: senderId,
                  );
                  conversations.refresh();
                }
              }
            }
          }, onError: (error) {
            print('Supabase Realtime Stream Error: $error');
          });
    } catch (_) {}
  }

  // ─── Typing state ───
  final RxMap<String, bool> typingState = <String, bool>{}.obs;

  // ─── Search ───
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;

  // ─── Selected messages (for multi-select) ───
  final RxSet<String> selectedMessageIds = <String>{}.obs;
  final RxBool isSelectionMode = false.obs;

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
    _saveConversations();
    return newConv;
  }

  List<ChatMessage> getMessages(String conversationId) {
    if (!_messages.containsKey(conversationId)) {
      _messages[conversationId] = [];
      _loadMessages(conversationId);
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

    final key = ChatCrypto.deriveFallbackKey(currentUserId, conv.otherUserId);
    final String encrypted = ChatCrypto.encryptMessage(content.trim(), key);

    // Try inserting into Supabase
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser != null) {
        await client.from('messages').insert({
          'sender_id': currentUserId,
          'receiver_id': conv.otherUserId.length == 36 ? conv.otherUserId : null,
          'encrypted_content': encrypted,
          'is_private': true,
        });
      }
    } catch (_) {
      // Fail silently to allow simulated offline fallback
    }

    final msg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUserId,
      receiverId: conv.otherUserId,
      conversationId: conversationId,
      content: content.trim(),
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    final current = getMessages(conversationId);
    _messages[conversationId] = [...current, msg];
    _saveMessages(conversationId);

    // Update conversation last message
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
        lastMessageTime: DateTime.now(),
        unreadCount: 0,
        isPinned: conv.isPinned,
        isMuted: conv.isMuted,
        levelTitle: conv.levelTitle,
        level: conv.level,
        lastMessageSenderId: currentUserId,
      );
      _saveConversations();
    }

    // Simulate sent after delay
    Future.delayed(const Duration(milliseconds: 800), () {
      final msgs = _messages[conversationId] ?? [];
      final updatedMsgs = msgs.map((m) {
        if (m.id == msg.id) return m.copyWith(status: MessageStatus.sent);
        return m;
      }).toList();
      _messages[conversationId] = updatedMsgs;
      _messages.refresh();
      _saveMessages(conversationId);

      // Simulate delivered
      Future.delayed(const Duration(seconds: 2), () {
        final msgs2 = _messages[conversationId] ?? [];
        final updatedMsgs2 = msgs2.map((m) {
          if (m.id == msg.id) return m.copyWith(status: MessageStatus.delivered);
          return m;
        }).toList();
        _messages[conversationId] = updatedMsgs2;
        _messages.refresh();
        _saveMessages(conversationId);
      });
    });

    _messages.refresh();
    conversations.refresh();
    _saveConversations();
  }

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

  void deleteMessage(String conversationId, String messageId) {
    final msgs = _messages[conversationId] ?? [];
    final updatedMsgs = msgs.map((m) {
      if (m.id == messageId) return m.copyWith(isDeleted: true);
      return m;
    }).toList();
    _messages[conversationId] = updatedMsgs;
    _messages.refresh();
  }

  void markConversationRead(String conversationId) {
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
    }
  }

  void setTyping(String conversationId, bool value) {
    typingState[conversationId] = value;
    typingState.refresh();
  }

  int get totalUnread =>
      conversations.fold(0, (sum, c) => sum + c.unreadCount);

  void togglePin(String conversationId) {
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
  }

  void toggleMute(String conversationId) {
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
  }

  void deleteConversation(String conversationId) {
    conversations.removeWhere((c) => c.id == conversationId);
    _messages.remove(conversationId);
  }
}
