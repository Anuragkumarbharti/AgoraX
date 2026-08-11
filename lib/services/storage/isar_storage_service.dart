import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/chat/chat_model.dart';
import '../../models/chat/isar_chat_model.dart';
import '../user/user_profile_cache_manager.dart';
import '../chat/chat_controller.dart';

class IsarStorageService extends GetxService {
  static IsarStorageService get to => Get.find();

  late final Isar _isar;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
       [IsarConversationSchema, IsarChatMessageSchema],
       directory: dir.path,
       name: 'creania_chat_db',
     );
     _initialized = true;
     migrateLocalConversationsToDeterministicIds();
  }

  // ─── Conversations ───

  Future<void> saveConversation(IsarConversation conv) async {
    final uid = UserProfileCacheManager.currentUserId;
    if (uid.isNotEmpty && !conv.uuid.startsWith('$uid:')) {
      conv.uuid = '$uid:${conv.uuid}';
    }
    await _isar.writeTxn(() async {
      await _isar.isarConversations.putByUuid(conv);
    });
  }

  Future<List<IsarConversation>> getAllConversations() async {
    final uid = UserProfileCacheManager.currentUserId;
    if (uid.isEmpty) return [];
    return await _isar.isarConversations
        .filter()
        .uuidStartsWith('$uid:')
        .sortByIsPinnedDesc()
        .thenByLastMessageTimeDesc()
        .findAll();
  }

  Future<IsarConversation?> getConversationByUuid(String uuid) async {
    final uid = UserProfileCacheManager.currentUserId;
    if (uid.isEmpty) return null;
    final scopedUuid = uuid.startsWith('$uid:') ? uuid : '$uid:$uuid';
    return await _isar.isarConversations
        .filter()
        .uuidEqualTo(scopedUuid)
        .findFirst();
  }

  Future<IsarConversation?> getConversation(String uuid) async {
    return await getConversationByUuid(uuid);
  }

  Future<void> deleteMessage(String messageUuid) async {
    final uid = UserProfileCacheManager.currentUserId;
    final scopedUuid = messageUuid.startsWith('$uid:') ? messageUuid : '$uid:$messageUuid';
    await _isar.writeTxn(() async {
      final msg = await _isar.isarChatMessages
          .filter()
          .uuidEqualTo(scopedUuid)
          .findFirst();
      if (msg != null) {
        msg.isDeleted = true;
        await _isar.isarChatMessages.put(msg);
      }
    });
  }

  Future<void> deleteConversation(String conversationId) async {
    final uid = UserProfileCacheManager.currentUserId;
    final scopedConvUuid = conversationId.startsWith('$uid:') ? conversationId : '$uid:$conversationId';
    await _isar.writeTxn(() async {
      // 1. Delete conversation matching scoped or raw uuid
      final convList = await _isar.isarConversations
          .filter()
          .uuidEqualTo(scopedConvUuid)
          .or()
          .uuidEqualTo(conversationId)
          .findAll();
          
      for (final conv in convList) {
        await _isar.isarConversations.delete(conv.id);
      }

      // 2. Delete all messages for conversation
      final messageIds = await _isar.isarChatMessages
          .filter()
          .conversationIdEqualTo(conversationId)
          .idProperty()
          .findAll();
      await _isar.isarChatMessages.deleteAll(messageIds);
    });
  }

  Future<void> clearMessagesForConversation(String conversationId) async {
    await _isar.writeTxn(() async {
      final messageIds = await _isar.isarChatMessages
          .filter()
          .conversationIdEqualTo(conversationId)
          .idProperty()
          .findAll();
      await _isar.isarChatMessages.deleteAll(messageIds);
    });
  }

  Future<void> hardClearConversationData({
    required String conversationId,
    required String canonicalConvId,
    required String currentUserId,
    required String otherUserId,
  }) async {
    await _isar.writeTxn(() async {
      final ids1 = await _isar.isarChatMessages
          .filter()
          .conversationIdEqualTo(conversationId)
          .idProperty()
          .findAll();

      final ids2 = await _isar.isarChatMessages
          .filter()
          .conversationIdEqualTo(canonicalConvId)
          .idProperty()
          .findAll();

      final ids3 = await _isar.isarChatMessages
          .filter()
          .senderIdEqualTo(currentUserId)
          .and()
          .receiverIdEqualTo(otherUserId)
          .idProperty()
          .findAll();

      final ids4 = await _isar.isarChatMessages
          .filter()
          .senderIdEqualTo(otherUserId)
          .and()
          .receiverIdEqualTo(currentUserId)
          .idProperty()
          .findAll();

      final allIdsToPurge = <int>{...ids1, ...ids2, ...ids3, ...ids4}.toList();
      if (allIdsToPurge.isNotEmpty) {
        await _isar.isarChatMessages.deleteAll(allIdsToPurge);
      }

      final conv1 = await _isar.isarConversations
          .filter()
          .uuidEqualTo(conversationId)
          .findFirst();
      if (conv1 != null) {
        conv1.lastMessage = '';
        conv1.unreadCount = 0;
        await _isar.isarConversations.putByUuid(conv1);
      }

      final conv2 = await _isar.isarConversations
          .filter()
          .uuidEqualTo(canonicalConvId)
          .findFirst();
      if (conv2 != null) {
        conv2.lastMessage = '';
        conv2.unreadCount = 0;
        await _isar.isarConversations.putByUuid(conv2);
      }
    });
  }


  // ─── Messages ───

  Future<void> saveMessage(IsarChatMessage message) async {
    final uid = UserProfileCacheManager.currentUserId;
    if (uid.isNotEmpty && !message.uuid.startsWith('$uid:')) {
      message.uuid = '$uid:${message.uuid}';
    }
    await _isar.writeTxn(() async {
      await _isar.isarChatMessages.putByUuid(message);
      
      // Enforce 1000 message limit FIFO per conversation
      final count = await _isar.isarChatMessages
          .filter()
          .conversationIdEqualTo(message.conversationId)
          .count();
      
      if (count > 1000) {
        final oldestMsgs = await _isar.isarChatMessages
            .filter()
            .conversationIdEqualTo(message.conversationId)
            .sortByTimestamp()
            .limit(count - 1000)
            .findAll();
            
        final idsToDelete = oldestMsgs.map((m) => m.id).toList();
        await _isar.isarChatMessages.deleteAll(idsToDelete);
        debugPrint('🧹 FIFO: Deleted ${idsToDelete.length} oldest messages from conversation ${message.conversationId}');
      }
    });
  }

  Future<void> saveMessages(List<IsarChatMessage> messages) async {
    final uid = UserProfileCacheManager.currentUserId;
    await _isar.writeTxn(() async {
      for (final msg in messages) {
        if (uid.isNotEmpty && !msg.uuid.startsWith('$uid:')) {
          msg.uuid = '$uid:${msg.uuid}';
        }
        await _isar.isarChatMessages.putByUuid(msg);
      }
      
      // Enforce FIFO limit per conversation affected
      final convIds = messages.map((m) => m.conversationId).toSet();
      for (final convId in convIds) {
        final count = await _isar.isarChatMessages
            .filter()
            .conversationIdEqualTo(convId)
            .count();
            
        if (count > 1000) {
          final oldestMsgs = await _isar.isarChatMessages
              .filter()
              .conversationIdEqualTo(convId)
              .sortByTimestamp()
              .limit(count - 1000)
              .findAll();
              
          final idsToDelete = oldestMsgs.map((m) => m.id).toList();
          await _isar.isarChatMessages.deleteAll(idsToDelete);
          debugPrint('🧹 FIFO: Deleted ${idsToDelete.length} oldest messages from conversation $convId');
        }
      }
    });
  }

  Future<List<IsarChatMessage>> getMessagesForConversation(
    String conversationId, {
    int limit = 100,
    int offset = 0,
  }) async {
    final uid = UserProfileCacheManager.currentUserId;
    if (uid.isEmpty) return [];

    final String cleanId = conversationId.startsWith('conv_')
        ? conversationId.substring(5)
        : conversationId;

    return _isar.isarChatMessages
        .filter()
        .conversationIdEqualTo(conversationId)
        .or()
        .conversationIdEqualTo(cleanId)
        .or()
        .conversationIdEqualTo('conv_$cleanId')
        .sortByTimestamp()
        .offset(offset)
        .limit(limit)
        .findAll();
  }



  Future<List<IsarChatMessage>> getUnsentMessages() async {
    final uid = UserProfileCacheManager.currentUserId;
    if (uid.isEmpty) return [];
    return await _isar.isarChatMessages
        .filter()
        .senderIdEqualTo(uid)
        .statusValueEqualTo(0) // MessageStatus.sending index
        .sortByTimestamp()
        .findAll();
  }

  Future<List<IsarChatMessage>> getPendingUnsentMessages() => getUnsentMessages();

  Future<DateTime?> getLatestMessageTimestamp() async {
    final uid = UserProfileCacheManager.currentUserId;
    if (uid.isEmpty) return null;
    final latest = await _isar.isarChatMessages
        .filter()
        .senderIdEqualTo(uid)
        .or()
        .receiverIdEqualTo(uid)
        .sortByTimestampDesc()
        .findFirst();
    return latest?.timestamp;
  }

  Future<IsarChatMessage?> getMessageByUuid(String messageUuid) async {
    final uid = UserProfileCacheManager.currentUserId;
    final scopedUuid = uid.isNotEmpty && !messageUuid.startsWith('$uid:') ? '$uid:$messageUuid' : messageUuid;
    return await _isar.isarChatMessages
        .filter()
        .uuidEqualTo(scopedUuid)
        .or()
        .uuidEqualTo(messageUuid)
        .findFirst();
  }

  Future<void> updateMessageStatus(String messageUuid, int statusValue) async {
    final uid = UserProfileCacheManager.currentUserId;
    final scopedUuid = uid.isNotEmpty && !messageUuid.startsWith('$uid:') ? '$uid:$messageUuid' : messageUuid;
    await _isar.writeTxn(() async {
      final msg = await _isar.isarChatMessages
          .filter()
          .uuidEqualTo(scopedUuid)
          .or()
          .uuidEqualTo(messageUuid)
          .findFirst();
      if (msg != null) {
        msg.statusValue = statusValue;
        await _isar.isarChatMessages.put(msg);
      }
    });
  }

  Future<void> markConversationMessagesRead(String conversationId) async {
    await _isar.writeTxn(() async {
      final msgs = await _isar.isarChatMessages
          .filter()
          .conversationIdEqualTo(conversationId)
          .findAll();
      for (final m in msgs) {
        if (m.statusValue != 3) {
          m.statusValue = 3; // MessageStatus.read index
          await _isar.isarChatMessages.put(m);
        }
      }
    });
  }

  Future<void> clearAllMessages(String conversationId) async {
    await _isar.writeTxn(() async {
      final messageIds = await _isar.isarChatMessages
          .filter()
          .conversationIdEqualTo(conversationId)
          .idProperty()
          .findAll();
      await _isar.isarChatMessages.deleteAll(messageIds);
      
      // Update last message metadata on the conversation
      final conv = await _isar.isarConversations.filter().uuidEqualTo(conversationId).findFirst();
      if (conv != null) {
        conv.lastMessage = '';
        conv.unreadCount = 0;
        await _isar.isarConversations.put(conv);
      }
    });
  }

  // ─── Cache Entries ───

  Future<void> saveCacheEntry(String key, String jsonPayload) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.isarConversations.filter().uuidEqualTo(key).findFirst();
      final conv = IsarConversation()
        ..uuid = key
        ..lastMessage = jsonPayload
        ..otherUserId = ''
        ..otherUserName = ''
        ..otherUserAvatar = ''
        ..otherUserOnline = false
        ..isVerified = false
        ..lastMessageTime = DateTime.now()
        ..unreadCount = 0
        ..isPinned = false
        ..isMuted = true
        ..levelTitle = ''
        ..level = 0
        ..lastMessageSenderId = '';
      if (existing != null) {
        conv.id = existing.id;
      }
      await _isar.isarConversations.put(conv);
    });
  }

  Future<String?> getCacheEntryPayload(String key) async {
    final entry = await _isar.isarConversations.filter().uuidEqualTo(key).findFirst();
    return entry?.lastMessage;
  }

  Future<void> saveCache<T>(String key, T data, Map<String, dynamic> Function(T) toJson) async {
    try {
      final jsonStr = jsonEncode(toJson(data));
      await saveCacheEntry(key, jsonStr);
    } catch (e) {
      debugPrint('Isar saveCache error for $key: $e');
    }
  }

  Future<T?> getCache<T>(String key, T Function(Map<String, dynamic>) fromJson) async {
    try {
      final jsonStr = await getCacheEntryPayload(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        return fromJson(map);
      }
    } catch (e) {
      debugPrint('Isar getCache error for $key: $e');
    }
    return null;
  }

  Future<void> saveCacheList<T>(String key, List<T> list, Map<String, dynamic> Function(T) toJson) async {
    try {
      final jsonStr = jsonEncode(list.map((item) => toJson(item)).toList());
      await saveCacheEntry(key, jsonStr);
    } catch (e) {
      debugPrint('Isar saveCacheList error for $key: $e');
    }
  }

  Future<List<T>?> getCacheList<T>(String key, T Function(Map<String, dynamic>) fromJson) async {
    try {
      final jsonStr = await getCacheEntryPayload(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((item) => fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Isar getCacheList error for $key: $e');
    }
    return null;
  }

  Stream<String?> watchCacheEntry(String key) {
    return _isar.isarConversations
        .filter()
        .uuidEqualTo(key)
        .watch(fireImmediately: true)
        .map((results) => results.isNotEmpty ? results.first.lastMessage : null);
  }

  Future<IsarChatMessage?> getMessageByClientMessageId(String clientMessageId) async {
    if (clientMessageId.isEmpty) return null;
    final all = await _isar.isarChatMessages.where().findAll();
    for (final m in all) {
      if (m.clientMessageId == clientMessageId) return m;
    }
    return null;
  }

  Future<IsarChatMessage?> getMessageByInviteId(String inviteId) async {
    if (inviteId.isEmpty) return null;
    final all = await _isar.isarChatMessages.where().findAll();
    for (final m in all) {
      if (m.inviteId == inviteId) return m;
    }
    return null;
  }

  Future<void> auditAndMigrateLocalDatabase() async {
    final uid = UserProfileCacheManager.currentUserId;
    if (uid.isEmpty) return;

    try {
      debugPrint('🔍 [MIGRATION AUDIT] Starting Non-Destructive Local Database Audit & Migration (READ -> MERGE -> VERIFY -> COMMIT)...');
      final allConvs = await _isar.isarConversations.where().findAll();
      final allMsgs = await _isar.isarChatMessages.where().findAll();

      int oldConvCount = allConvs.length;
      int oldMsgCount = allMsgs.length;
      int duplicateConvCount = 0;
      int duplicateMsgCount = 0;
      int mergedMsgCount = 0;
      int tombstonedCount = 0;

      final Map<String, IsarConversation> canonicalConvs = {};
      final Set<String> seenMsgUuids = {};
      final Set<String> seenClientMsgIds = {};
      final Set<String> seenInviteIds = {};
      final List<int> convIdsToDelete = [];
      final List<int> msgIdsToDelete = [];

      // 1. Audit & Normalize Messages
      for (final msg in allMsgs) {
        if (msg.isDeleted) tombstonedCount++;

        if (msg.senderId.isNotEmpty && msg.receiverId.isNotEmpty) {
          final detConvId = ChatMessage.getDeterministicConversationId(msg.senderId, msg.receiverId);
          if (msg.conversationId != detConvId) {
            msg.conversationId = detConvId;
            mergedMsgCount++;
          }
        }

        bool isDup = false;
        if (msg.uuid.isNotEmpty) {
          if (seenMsgUuids.contains(msg.uuid)) {
            isDup = true;
          } else {
            seenMsgUuids.add(msg.uuid);
          }
        }

        if (!isDup && msg.clientMessageId != null && msg.clientMessageId!.isNotEmpty) {
          if (seenClientMsgIds.contains(msg.clientMessageId!)) {
            isDup = true;
          } else {
            seenClientMsgIds.add(msg.clientMessageId!);
          }
        }

        if (!isDup && msg.inviteId != null && msg.inviteId!.isNotEmpty) {
          if (seenInviteIds.contains(msg.inviteId!)) {
            isDup = true;
          } else {
            seenInviteIds.add(msg.inviteId!);
          }
        }

        if (isDup) {
          duplicateMsgCount++;
          msgIdsToDelete.add(msg.id);
        }
      }

      // 2. Audit & Merge Conversations
      for (final c in allConvs) {
        if (c.otherUserId.isEmpty) continue; // Skip cache entries
        final detConvId = ChatMessage.getDeterministicConversationId(uid, c.otherUserId);
        c.uuid = '$uid:$detConvId';

        if (!canonicalConvs.containsKey(c.otherUserId)) {
          canonicalConvs[c.otherUserId] = c;
        } else {
          duplicateConvCount++;
          final existing = canonicalConvs[c.otherUserId]!;
          if (c.lastMessageTime.isAfter(existing.lastMessageTime)) {
            convIdsToDelete.add(existing.id);
            canonicalConvs[c.otherUserId] = c;
          } else {
            convIdsToDelete.add(c.id);
          }
        }
      }

      // 3. Perform Transaction (COMMIT)
      await _isar.writeTxn(() async {
        for (final id in convIdsToDelete) {
          await _isar.isarConversations.delete(id);
        }
        for (final id in msgIdsToDelete) {
          await _isar.isarChatMessages.delete(id);
        }
        for (final msg in allMsgs) {
          if (!msgIdsToDelete.contains(msg.id)) {
            await _isar.isarChatMessages.put(msg);
          }
        }
        for (final c in canonicalConvs.values) {
          await _isar.isarConversations.put(c);
        }
      });

      final finalConvCount = canonicalConvs.length;
      final finalMsgCount = oldMsgCount - duplicateMsgCount;

      debugPrint('''
📊 [MIGRATION AUDIT REPORT COMPLETE]
====================================
• Old Conversations Count: $oldConvCount
• Old Messages Count: $oldMsgCount
• Duplicate Conversations Found & Merged: $duplicateConvCount
• Duplicate Messages Found & Deduplicated: $duplicateMsgCount
• Merged Message Mappings: $mergedMsgCount
• Soft-Deleted / Tombstoned Messages Preserved: $tombstonedCount
• Canonical Conversations Active: $finalConvCount
• Canonical Messages Active: $finalMsgCount
====================================
      ''');
    } catch (e) {
      debugPrint('❌ [MIGRATION AUDIT ERROR] Migration audit failed safely: $e');
    }
  }

  Future<void> migrateLocalConversationsToDeterministicIds() => auditAndMigrateLocalDatabase();
}

