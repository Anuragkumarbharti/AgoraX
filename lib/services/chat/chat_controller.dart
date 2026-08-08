import 'dart:convert';
import 'dart:math';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chat/chat_model.dart';
import '../../models/chat/isar_chat_model.dart';
import '../../core/chat_crypto.dart';
import 'package:flutter/material.dart';
import '../storage/isar_storage_service.dart';
import './chat_socket_service.dart';
import '../user/user_profile_cache_manager.dart';
import '../../utils/secure_dto_sanitizer.dart';
import '../network/network_connectivity_service.dart';
import '../network/network_guard.dart';

class ChatController extends GetxController {
  static String get currentUserId => UserProfileCacheManager.currentUserId;
  static String get currentUserName => Supabase.instance.client.auth.currentUser?.email ?? 'Anurag Kumar';
  static String get currentUserAvatar => '';

  // ─── Conversations list ───
  final RxList<Conversation> conversations = <Conversation>[].obs;

  // ─── Messages per conversation ───
  final RxMap<String, List<ChatMessage>> _messages =
      <String, List<ChatMessage>>{}.obs;

  // ─── Pagination states ───
  final RxMap<String, int> _loadedMessageOffsets = <String, int>{}.obs;
  final RxMap<String, bool> _hasMoreMessages = <String, bool>{}.obs;

  // ─── Typing state ───
  final RxMap<String, bool> typingState = <String, bool>{}.obs;

  // ─── User presence online state ───
  final RxMap<String, bool> userPresence = <String, bool>{}.obs;

  // ─── Last seen presence ───
  final RxMap<String, String> userLastSeen = <String, String>{}.obs;

  // ─── Search ───
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;

  // ─── Selected messages (for multi-select) ───
  final RxSet<String> selectedMessageIds = <String>{}.obs;
  final RxBool isSelectionMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadConversationsFromIsar().then((_) {
      performStartupAndReconnectSync();
    });
  }

  final RxBool isLoading = false.obs;

  bool _isSyncing = false;

  Future<void> performStartupAndReconnectSync() async {
    final uid = currentUserId;
    if (uid.isEmpty || _isSyncing) return;
    _isSyncing = true;
    isLoading.value = true;

    try {
      debugPrint('[ChatPipeline] Sync Started: Checking missed messages from Supabase DB');
      
      final List<dynamic> rows = [];

      // 1. Call atomic RPC to fetch & mark undelivered messages where current user is receiver
      try {
        final rpcRes = await Supabase.instance.client.rpc(
          'fetch_and_mark_undelivered_messages',
          params: {'p_user_id': uid},
        );
        if (rpcRes is List) {
          rows.addAll(rpcRes);
        }
      } catch (rpcErr) {
        debugPrint('[ChatPipeline] RPC fetch_and_mark_undelivered_messages fallback: $rpcErr');
      }

      // 2. Also fetch any messages sent/received since latest local timestamp
      final latestTs = await IsarStorageService.to.getLatestMessageTimestamp();
      final DateTime querySince = latestTs ?? DateTime.now().subtract(const Duration(days: 7));

      try {
        final dbRes = await Supabase.instance.client
            .from('messages')
            .select('*')
            .or('sender_id.eq.$uid,receiver_id.eq.$uid')
            .gt('created_at', querySince.toIso8601String())
            .order('created_at', ascending: true);

        final dbResList = dbRes as List;
        for (final row in dbResList) {
            final id = row['id']?.toString();
            if (id != null && !rows.any((r) => r['id']?.toString() == id)) {
              rows.add(row);
            }
          }
      } catch (dbErr) {
        debugPrint('[ChatPipeline] DB fallback query error: $dbErr');
      }

      if (rows.isEmpty) {
        debugPrint('[ChatPipeline] Sync Finished: No missed messages found');
        return;
      }

      debugPrint('[ChatPipeline] Sync Downloaded ${rows.length} missed messages from Supabase DB');

      final List<IsarChatMessage> isarList = [];
      bool memoryUpdated = false;

      for (final r in rows) {
        final Map<String, dynamic> row = Map<String, dynamic>.from(r);
        final String msgUuid = row['id']?.toString() ?? '';
        final String senderId = row['sender_id']?.toString() ?? '';
        final String receiverId = row['receiver_id']?.toString() ?? '';
        final String encryptedContent = row['encrypted_content']?.toString() ?? '';
        final String timestampStr = row['created_at']?.toString() ?? '';
        final String mediaTypeStr = row['media_type']?.toString() ?? 'text';
        final String statusStr = row['message_status']?.toString() ?? 'sent';

        if (msgUuid.isEmpty || senderId.isEmpty) continue;

        final matchedType = MessageType.values.firstWhere(
          (e) => e.name == mediaTypeStr,
          orElse: () => MessageType.text,
        );
        final int typeValue = matchedType.index;

        int statusVal = MessageStatus.sent.index;
        if (statusStr == 'delivered' || receiverId == uid) statusVal = MessageStatus.delivered.index;
        if (statusStr == 'seen') statusVal = MessageStatus.read.index;

        final aesKey = ChatCrypto.deriveFallbackKey(senderId, receiverId);
        final decryptedText = ChatCrypto.decryptMessage(encryptedContent, aesKey);
        final cleanContent = SecureDtoSanitizer.sanitizeChatMessageContent(decryptedText, fallback: 'Encrypted message');
        final dt = timestampStr.isNotEmpty ? DateTime.parse(timestampStr) : DateTime.now();

        final String convId = getDeterministicConversationId(senderId, receiverId);

        final isarMsg = IsarChatMessage()
          ..uuid = msgUuid
          ..senderId = senderId
          ..receiverId = receiverId
          ..conversationId = convId
          ..content = cleanContent
          ..typeValue = typeValue
          ..statusValue = statusVal
          ..timestamp = dt
          ..mediaUrl = row['media_url']
          ..fileName = row['file_name']
          ..fileSize = row['file_size'] != null ? (row['file_size'] as num).toInt() : null
          ..thumbnailUrl = row['thumbnail']
          ..locationLat = row['location_lat'] != null ? (row['location_lat'] as num).toDouble() : null
          ..locationLng = row['location_lng'] != null ? (row['location_lng'] as num).toDouble() : null
          ..locationName = row['location_name']
          ..contactName = row['contact_name']
          ..contactPhone = row['contact_phone']
          ..isDeleted = false
          ..isEdited = false;

        isarList.add(isarMsg);

        // Update memory list if loaded
        if (_messages.containsKey(convId)) {
          final current = List<ChatMessage>.from(_messages[convId] ?? []);
          final existingIdx = current.indexWhere((m) => m.id == msgUuid);
          final newMsg = ChatMessage(
            id: msgUuid,
            senderId: senderId,
            receiverId: receiverId,
            conversationId: convId,
            content: decryptedText,
            timestamp: dt,
            status: MessageStatus.values[statusVal.clamp(0, MessageStatus.values.length - 1)],
            type: MessageType.values[typeValue.clamp(0, MessageType.values.length - 1)],
            mediaUrl: row['media_url'],
            fileName: row['file_name'],
            fileSize: row['file_size'] != null ? (row['file_size'] as num).toInt() : null,
            thumbnailUrl: row['thumbnail'],
            locationLat: row['location_lat'] != null ? (row['location_lat'] as num).toDouble() : null,
            locationLng: row['location_lng'] != null ? (row['location_lng'] as num).toDouble() : null,
            locationName: row['location_name'],
            contactName: row['contact_name'],
            contactPhone: row['contact_phone'],
          );

          if (existingIdx != -1) {
            current[existingIdx] = newMsg;
          } else {
            current.add(newMsg);
          }
          _messages[convId] = current;
          memoryUpdated = true;
        }
      }

      if (memoryUpdated) {
        _messages.refresh();
      }

      if (isarList.isNotEmpty) {
        await IsarStorageService.to.saveMessages(isarList);
        await _loadConversationsFromIsar();
      }

      debugPrint('[ChatPipeline] Sync Finished: Catch-up complete');
    } catch (e) {
      debugPrint('[ChatPipeline] Error during startup catch-up sync: $e');
    } finally {
      _isSyncing = false;
      isLoading.value = false;
    }
  }

  static String sanitizeMessageText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        jsonDecode(trimmed);
        return 'Media Attachment';
      } catch (_) {}
    }
    return trimmed;
  }

  void clearAllDataOnLogout() {
    conversations.clear();
    _messages.clear();
    _loadedMessageOffsets.clear();
    _hasMoreMessages.clear();
    typingState.clear();
    userPresence.clear();
    userLastSeen.clear();
    searchQuery.value = '';
    selectedMessageIds.clear();
    isSelectionMode.value = false;
  }


  Future<void> refreshConversations() => _loadConversationsFromIsar();

  Future<void> _loadConversationsFromIsar() async {
    try {
      final isarConvs = await IsarStorageService.to.getAllConversations();
      final Map<String, Conversation> dedupMap = {};

      for (final c in isarConvs) {
        if (c.otherUserId.isEmpty) continue; // Skip cache entry rows
        final cleanLastMsg = sanitizeMessageText(c.lastMessage);
        final isMutual = UserProfileCacheManager.connectionStatuses[c.otherUserId] == 'mutual' ||
            (UserProfileCacheManager.followerUserIds.contains(c.otherUserId) &&
                UserProfileCacheManager.followedUserIds.contains(c.otherUserId));

        final msgs = await IsarStorageService.to.getMessagesForConversation(c.uuid, limit: 1);
        final hasHistory = msgs.isNotEmpty || cleanLastMsg.isNotEmpty;

        // RULE: Show conversation ONLY if Mutual Follow OR Has Message History
        if (isMutual || hasHistory) {
          final convObj = Conversation(
            id: c.uuid,
            otherUserId: c.otherUserId,
            otherUserName: c.otherUserName,
            otherUserAvatar: c.otherUserAvatar,
            otherUserOnline: c.otherUserOnline,
            isVerified: c.isVerified,
            lastMessage: cleanLastMsg,
            lastMessageTime: c.lastMessageTime,
            unreadCount: c.unreadCount,
            isPinned: c.isPinned,
            isMuted: c.isMuted,
            levelTitle: c.levelTitle,
            level: c.level,
            lastMessageSenderId: c.lastMessageSenderId,
            isMutualFollow: isMutual,
          );

          if (!dedupMap.containsKey(c.otherUserId) ||
              c.lastMessageTime.isAfter(dedupMap[c.otherUserId]!.lastMessageTime)) {
            dedupMap[c.otherUserId] = convObj;
          }
        }
      }

      // ✅ BUG #17 FIX: Use unified canonical sort function (same as _sortConversations)
      // Previously this sort had 4 criteria while _sortConversations only had 2,
      // causing inconsistent list ordering after send/receive events.
      final List<Conversation> list = dedupMap.values.toList();
      _sortConversationList(list);

      Future.microtask(() {
        conversations.assignAll(list);
      });
    } catch (_) {}
  }


  Future<void> _loadMessagesFromIsar(String convId) async {
    try {
      _loadedMessageOffsets[convId] = 0;
      _hasMoreMessages[convId] = true;

      final isarMsgs = await IsarStorageService.to.getMessagesForConversation(convId, limit: 100);
      final list = isarMsgs.map((m) {
        return ChatMessage(
          id: m.uuid,
          senderId: m.senderId,
          receiverId: m.receiverId,
          conversationId: m.conversationId,
          content: m.content,
          timestamp: m.timestamp,
          status: MessageStatus.values[m.statusValue.clamp(0, MessageStatus.values.length - 1)],
          type: MessageType.values[m.typeValue.clamp(0, MessageType.values.length - 1)],
          reactions: m.reactions,
          mediaUrl: m.mediaUrl,
          fileName: m.fileName,
          fileSize: m.fileSize,
          thumbnailUrl: m.thumbnailUrl,
          locationLat: m.locationLat,
          locationLng: m.locationLng,
          locationName: m.locationName,
          contactName: m.contactName,
          contactPhone: m.contactPhone,
          isDeleted: m.isDeleted,
          isEdited: m.isEdited,
        );
      }).toList();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messages[convId] = list;
        _messages.refresh();
      });

      if (isarMsgs.length < 100) {
        _hasMoreMessages[convId] = false;
      }
    } catch (_) {}
  }

  final RxMap<String, bool> isLoadingMore = <String, bool>{}.obs;

  Future<void> loadMoreMessages(String convId) async {
    if (isLoadingMore[convId] == true) return;
    final hasMore = _hasMoreMessages[convId] ?? true;
    if (!hasMore) return;

    isLoadingMore[convId] = true;
    final currentOffset = _loadedMessageOffsets[convId] ?? 0;
    final nextOffset = currentOffset + 100;

    try {
      final isarMsgs = await IsarStorageService.to.getMessagesForConversation(
        convId,
        limit: 100,
        offset: nextOffset,
      );

      if (isarMsgs.isEmpty) {
        _hasMoreMessages[convId] = false;
        return;
      }

      final list = isarMsgs.map((m) {
        return ChatMessage(
          id: m.uuid,
          senderId: m.senderId,
          receiverId: m.receiverId,
          conversationId: m.conversationId,
          content: m.content,
          timestamp: m.timestamp,
          status: MessageStatus.values[m.statusValue.clamp(0, MessageStatus.values.length - 1)],
          type: MessageType.values[m.typeValue.clamp(0, MessageType.values.length - 1)],
          reactions: m.reactions,
          mediaUrl: m.mediaUrl,
          fileName: m.fileName,
          fileSize: m.fileSize,
          thumbnailUrl: m.thumbnailUrl,
          locationLat: m.locationLat,
          locationLng: m.locationLng,
          locationName: m.locationName,
          contactName: m.contactName,
          contactPhone: m.contactPhone,
          isDeleted: m.isDeleted,
          isEdited: m.isEdited,
        );
      }).toList();

      Future.microtask(() {
        final currentList = _messages[convId] ?? [];
        _messages[convId] = [...list.reversed, ...currentList];
        _loadedMessageOffsets[convId] = nextOffset;
        _messages.refresh();
      });

      if (isarMsgs.length < 100) {
        _hasMoreMessages[convId] = false;
      }
    } catch (_) {} finally {
      isLoadingMore[convId] = false;
    }
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

  static String getDeterministicConversationId(String u1, String u2) {
    if (u1.isEmpty || u2.isEmpty) return u1.isNotEmpty ? u1 : u2;
    final cleanU1 = u1.startsWith('conv_') ? u1.substring(5) : u1;
    final cleanU2 = u2.startsWith('conv_') ? u2.substring(5) : u2;
    if (cleanU1 == cleanU2) return cleanU1;
    final list = [cleanU1, cleanU2]..sort();
    return '${list[0]}_${list[1]}';
  }

  Conversation getOrCreateConversation(String otherUserId, String otherUserName, String otherUserAvatar) {
    final String convId = getDeterministicConversationId(currentUserId, otherUserId);
    final int idx = conversations.indexWhere((c) => c.id == convId || c.otherUserId == otherUserId);
    if (idx != -1) {
      return conversations[idx];
    }

    final bool isOnline = userPresence[otherUserId] ?? false;
    final newConv = Conversation(
      id: convId,
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      otherUserAvatar: otherUserAvatar,
      lastMessage: 'Started chat',
      lastMessageTime: DateTime.now(),
      otherUserOnline: isOnline,
    );
    conversations.insert(0, newConv);

    // Save to local Isar DB (Single Source of Truth)
    final isarConv = IsarConversation()
      ..uuid = convId
      ..otherUserId = otherUserId
      ..otherUserName = otherUserName
      ..otherUserAvatar = otherUserAvatar
      ..lastMessage = 'Started chat'
      ..lastMessageTime = DateTime.now()
      ..otherUserOnline = isOnline
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadMessagesFromIsar(conversationId);
      });
    }
    return _messages[conversationId] ?? [];
  }

  static String generateUuidV4() {
    final Random random = Random();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // Version 4
    values[8] = (values[8] & 0x3f) | 0x80; // Variant 10xx

    final buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  bool isMutualFollower(String otherUserId) {
    if (otherUserId.isEmpty) return false;
    final status = UserProfileCacheManager.connectionStatuses[otherUserId];
    if (status == 'mutual' || status == 'friends') return true;
    final followsMe = UserProfileCacheManager.followerUserIds.contains(otherUserId);
    final iFollow = UserProfileCacheManager.followedUserIds.contains(otherUserId);
    return followsMe && iFollow;
  }

  int getOutboundRequestCount(String conversationId, String otherUserId) {
    final msgs = getMessages(conversationId);
    if (msgs.isEmpty) return 0;

    int lastResetIndex = -1;
    for (int i = msgs.length - 1; i >= 0; i--) {
      final m = msgs[i];
      if (m.senderId != currentUserId || m.isUnlockGift) {
        lastResetIndex = i;
        break;
      }
    }

    int outboundCount = 0;
    final startIndex = lastResetIndex + 1;
    for (int i = startIndex; i < msgs.length; i++) {
      if (msgs[i].senderId == currentUserId && !msgs[i].isDeleted) {
        outboundCount++;
      }
    }
    return outboundCount;
  }

  int getRemainingRequestQuota(String conversationId, String otherUserId) {
    if (isMutualFollower(otherUserId)) return 999;

    final msgs = getMessages(conversationId);
    final bool recipientHasReplied = msgs.any((m) => m.senderId == otherUserId && !m.isDeleted);
    if (recipientHasReplied) return 999;

    final outbound = getOutboundRequestCount(conversationId, otherUserId);
    return max(0, 3 - outbound);
  }

  void sendGiftMessage(String conversationId, String giftName, String giftIcon, int giftStars, String recipientId) {
    final bool isUnlock = giftStars >= 2;
    final String contentText = '$giftIcon Sent $giftName ($giftStars 💎)${isUnlock ? " • Unlocked 3 Request Messages 🔓" : ""}';

    sendMessage(
      conversationId,
      contentText,
      type: MessageType.gift,
      isUnlockGift: isUnlock,
    );
  }

  void sendMessage(
    String conversationId,
    String content, {
    MessageType type = MessageType.text,
    int audioDurationSeconds = 0,
    bool isUnlockGift = false,
    String? mediaUrl,
    String? fileName,
    int? fileSize,
    String? thumbnailUrl,
    double? locationLat,
    double? locationLng,
    String? locationName,
    String? contactName,
    String? contactPhone,
  }) async {
    if (!NetworkGuard.checkInternet(
      actionName: 'chat',
      customOfflineMessage: 'Waiting for internet connection...',
    )) {
      return;
    }
    final String cleanContent = content.trim().isEmpty ? (fileName ?? 'Media Attachment') : content.trim();

    final int idxSearch = conversations.indexWhere((c) => c.id == conversationId);
    final conv = idxSearch != -1 
        ? conversations[idxSearch] 
        : getOrCreateConversation(
            conversationId.startsWith('conv_') ? conversationId.substring(5) : conversationId,
            'User',
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100',
          );

    final msgId = generateUuidV4();
    final now = DateTime.now();

    final msg = ChatMessage(
      id: msgId,
      senderId: currentUserId,
      receiverId: conv.otherUserId,
      conversationId: conversationId,
      content: cleanContent,
      type: type,
      timestamp: now,
      status: MessageStatus.sending,
      isUnlockGift: isUnlockGift,
      audioDurationSeconds: audioDurationSeconds,
      mediaUrl: mediaUrl,
      fileName: fileName,
      fileSize: fileSize,
      thumbnailUrl: thumbnailUrl,
      locationLat: locationLat,
      locationLng: locationLng,
      locationName: locationName,
      contactName: contactName,
      contactPhone: contactPhone,
    );

    // 1. Write message directly to local Isar DB (Single Source of Truth)
    final isarMsg = IsarChatMessage()
      ..uuid = msgId
      ..senderId = currentUserId
      ..receiverId = conv.otherUserId
      ..conversationId = conversationId
      ..content = cleanContent
      ..typeValue = type.index
      ..statusValue = MessageStatus.sending.index
      ..timestamp = now
      ..mediaUrl = mediaUrl
      ..fileName = fileName
      ..fileSize = fileSize
      ..thumbnailUrl = thumbnailUrl
      ..locationLat = locationLat
      ..locationLng = locationLng
      ..locationName = locationName
      ..contactName = contactName
      ..contactPhone = contactPhone
      ..isDeleted = false
      ..isEdited = false;
    await IsarStorageService.to.saveMessage(isarMsg);

    // Update conversation metadata locally in Isar
    final isarConv = IsarConversation()
      ..uuid = conv.id
      ..otherUserId = conv.otherUserId
      ..otherUserName = conv.otherUserName
      ..otherUserAvatar = conv.otherUserAvatar
      ..lastMessage = cleanContent
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

    final updatedConv = Conversation(
      id: conv.id,
      otherUserId: conv.otherUserId,
      otherUserName: conv.otherUserName,
      otherUserAvatar: conv.otherUserAvatar,
      otherUserOnline: conv.otherUserOnline,
      isVerified: conv.isVerified,
      lastMessage: cleanContent,
      lastMessageTime: now,
      unreadCount: 0,
      isPinned: conv.isPinned,
      isMuted: conv.isMuted,
      levelTitle: conv.levelTitle,
      level: conv.level,
      lastMessageSenderId: currentUserId,
      isMutualFollow: conv.isMutualFollow,
    );

    // Instant top reordering
    _upsertAndMoveToTop(updatedConv);

    // 3. Emit message event to Socket.IO & Supabase Broadcast layers
    ChatSocketService.to.emitMessage(msg);

    // 4. Guaranteed status transition fallback: if server_ack / delivery_ack is not received in 1.5s, update status to sent (single tick)
    Future.delayed(const Duration(milliseconds: 1500), () async {
      final current = getMessages(conversationId);
      final idx = current.indexWhere((m) => m.id == msgId);
      if (idx != -1 && current[idx].status == MessageStatus.sending) {
        updateMessageStatus(msgId, MessageStatus.sent);
        await IsarStorageService.to.updateMessageStatus(msgId, MessageStatus.sent.index);
      }
    });
  }

  // ─── Unified Canonical Sort ───

  /// Single source of truth for conversation ordering:
  /// Pinned first > Unread > Latest timestamp > Muted last
  void _sortConversationList(List<Conversation> list) {
    list.sort((a, b) {
      // 1. Pinned conversations always at top
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      // 2. Conversations with unread messages above read ones
      if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
      if (a.unreadCount == 0 && b.unreadCount > 0) return 1;

      // 3. Muted conversations sink to bottom
      if (a.isMuted && !b.isMuted) return 1;
      if (!a.isMuted && b.isMuted) return -1;

      // 4. Most recent message on top
      return b.lastMessageTime.compareTo(a.lastMessageTime);
    });
  }

  void _upsertAndMoveToTop(Conversation updatedConv) {
    conversations.removeWhere(
        (c) => c.id == updatedConv.id || c.otherUserId == updatedConv.otherUserId);
    conversations.add(updatedConv);
    _sortConversations();
  }

  // ✅ BUG #17 FIX: _sortConversations now uses the same 4-criteria logic as _loadConversationsFromIsar
  void _sortConversations() {
    _sortConversationList(conversations);
    conversations.refresh();
  }

  // ─── Socket Event Receivers ───

  void onMessageReceivedFromSocket(ChatMessage msg) async {
    final current = getMessages(msg.conversationId);
    if (!current.any((m) => m.id == msg.id)) {
      _messages[msg.conversationId] = [...current, msg];
      _messages.refresh();

      final String peerId = msg.senderId == UserProfileCacheManager.currentUserId ? msg.receiverId : msg.senderId;
      final idx = conversations.indexWhere((c) => c.id == msg.conversationId || c.otherUserId == peerId);
      Conversation conv;
      if (idx != -1) {
        conv = conversations[idx];
      } else {
        try {
          final senderUser = await UserProfileCacheManager.fetchUserProfile(msg.senderId);
          conv = Conversation(
            id: msg.conversationId,
            otherUserId: msg.senderId,
            otherUserName: senderUser.displayName,
            otherUserAvatar: senderUser.avatar ?? '',
            otherUserOnline: true,
            lastMessage: msg.content,
            lastMessageTime: msg.timestamp,
            unreadCount: 0,
            lastMessageSenderId: msg.senderId,
          );
        } catch (_) {
          conv = Conversation(
            id: msg.conversationId,
            otherUserId: msg.senderId,
            otherUserName: 'Creaniaa User',
            otherUserAvatar: '',
            otherUserOnline: true,
            lastMessage: msg.content,
            lastMessageTime: msg.timestamp,
            unreadCount: 0,
            lastMessageSenderId: msg.senderId,
          );
        }
      }

      final updatedConv = Conversation(
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
        isMutualFollow: conv.isMutualFollow,
      );

      // Save new conversation state in Isar
      final isarConv = IsarConversation()
        ..uuid = updatedConv.id
        ..otherUserId = updatedConv.otherUserId
        ..otherUserName = updatedConv.otherUserName
        ..otherUserAvatar = updatedConv.otherUserAvatar
        ..lastMessage = updatedConv.lastMessage
        ..lastMessageTime = updatedConv.lastMessageTime
        ..otherUserOnline = updatedConv.otherUserOnline
        ..isVerified = updatedConv.isVerified
        ..unreadCount = updatedConv.unreadCount
        ..isPinned = updatedConv.isPinned
        ..isMuted = updatedConv.isMuted
        ..levelTitle = updatedConv.levelTitle
        ..level = updatedConv.level
        ..lastMessageSenderId = updatedConv.lastMessageSenderId ?? '';

      await IsarStorageService.to.saveConversation(isarConv);

      // Reorder conversation list instantly to top position
      _upsertAndMoveToTop(updatedConv);
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

  void updateUserPresence(String userId, bool isOnline, String? lastSeen) async {
    userPresence[userId] = isOnline;
    userPresence.refresh();

    if (lastSeen != null) {
      try {
        final dt = DateTime.parse(lastSeen);
        userLastSeen[userId] = _formatLastSeen(dt);
      } catch (_) {}
    } else if (isOnline) {
      userLastSeen.remove(userId);
    }
    userLastSeen.refresh();

    // Update in conversation list memory
    final idx = conversations.indexWhere((c) => c.otherUserId == userId);
    if (idx != -1) {
      final conv = conversations[idx];
      conversations[idx] = Conversation(
        id: conv.id,
        otherUserId: conv.otherUserId,
        otherUserName: conv.otherUserName,
        otherUserAvatar: conv.otherUserAvatar,
        otherUserOnline: isOnline,
        isVerified: conv.isVerified,
        lastMessage: conv.lastMessage,
        lastMessageTime: conv.lastMessageTime,
        unreadCount: conv.unreadCount,
        isPinned: conv.isPinned,
        isMuted: conv.isMuted,
        levelTitle: conv.levelTitle,
        level: conv.level,
        lastMessageSenderId: conv.lastMessageSenderId,
      );
      conversations.refresh();
      
      // Update local Isar DB
      final isarConv = await IsarStorageService.to.getConversation(conv.id);
      if (isarConv != null) {
        isarConv.otherUserOnline = isOnline;
        await IsarStorageService.to.saveConversation(isarConv);
      }
    }
  }


  String _formatLastSeen(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(dt.year, dt.month, dt.day);

    final timeStr = DateFormat('h:mm a').format(dt);
    if (checkDate == today) {
      return 'Last seen today at $timeStr';
    } else if (checkDate == yesterday) {
      return 'Last seen yesterday at $timeStr';
    } else {
      return 'Last seen on ${DateFormat('dd MMM').format(dt)} at $timeStr';
    }
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
      await IsarStorageService.to.markConversationMessagesRead(conversationId);

      // Update active memory stream
      final msgs = _messages[conversationId] ?? [];
      final updatedMsgs = msgs.map((m) => m.copyWith(status: MessageStatus.read)).toList();
      _messages[conversationId] = updatedMsgs;
      _messages.refresh();

      // Call database RPC to mark read on backend
      try {
        await Supabase.instance.client.rpc('mark_messages_read', params: {
          'p_user_id': currentUserId,
          'p_sender_id': conv.otherUserId,
        });
      } catch (_) {}

      // Notify peer via Socket
      ChatMessage? lastPeerMsg;
      for (int i = msgs.length - 1; i >= 0; i--) {
        if (msgs[i].senderId != currentUserId) {
          lastPeerMsg = msgs[i];
          break;
        }
      }
      if (lastPeerMsg != null) {
        ChatSocketService.to.emitReadReceipt(conversationId, lastPeerMsg.id, conv.otherUserId);
      }
    }
  }

  void setTyping(String conversationId, bool value, {String? receiverId}) {
    final conv = conversations.firstWhereOrNull((c) => c.id == conversationId);
    final targetReceiver = receiverId ?? conv?.otherUserId ?? '';
    if (targetReceiver.isNotEmpty) {
      if (value) {
        ChatSocketService.to.emitTypingStart(conversationId, targetReceiver);
      } else {
        ChatSocketService.to.emitTypingStop(conversationId, targetReceiver);
      }
    }
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

  void clearChat(String conversationId) async {
    _messages[conversationId] = [];
    _messages.refresh();

    await IsarStorageService.to.clearMessagesForConversation(conversationId);

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
        lastMessage: '',
        lastMessageTime: conv.lastMessageTime,
        unreadCount: 0,
        isPinned: conv.isPinned,
        isMuted: conv.isMuted,
        levelTitle: conv.levelTitle,
        level: conv.level,
        lastMessageSenderId: conv.lastMessageSenderId,
        isMutualFollow: conv.isMutualFollow,
      );
      conversations.refresh();

      final isarConv = await IsarStorageService.to.getConversation(conversationId);
      if (isarConv != null) {
        isarConv.lastMessage = '';
        isarConv.unreadCount = 0;
        await IsarStorageService.to.saveConversation(isarConv);
      }
    }
  }
}

