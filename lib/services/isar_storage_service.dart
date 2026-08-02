import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/isar_chat_model.dart';
import 'user_profile_cache_manager.dart';
import 'chat_controller.dart';

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

  Future<void> migrateLocalConversationsToDeterministicIds() async {
    final uid = UserProfileCacheManager.currentUserId;
    if (uid.isEmpty) return;

    try {
      final allConvs = await _isar.isarConversations.where().findAll();
      final allMsgs = await _isar.isarChatMessages.where().findAll();

      await _isar.writeTxn(() async {
        for (final msg in allMsgs) {
          if (msg.senderId.isNotEmpty && msg.receiverId.isNotEmpty) {
            final detConvId = ChatController.getDeterministicConversationId(msg.senderId, msg.receiverId);
            if (msg.conversationId != detConvId) {
              msg.conversationId = detConvId;
              await _isar.isarChatMessages.put(msg);
            }
          }
        }

        final Map<String, IsarConversation> map = {};
        final List<int> idsToDelete = [];

        for (final c in allConvs) {
          if (c.otherUserId.isEmpty) continue;
          final detConvId = ChatController.getDeterministicConversationId(uid, c.otherUserId);
          c.uuid = '$uid:$detConvId';

          if (!map.containsKey(c.otherUserId)) {
            map[c.otherUserId] = c;
          } else {
            final existing = map[c.otherUserId]!;
            if (c.lastMessageTime.isAfter(existing.lastMessageTime)) {
              idsToDelete.add(existing.id);
              map[c.otherUserId] = c;
            } else {
              idsToDelete.add(c.id);
            }
          }
        }

        for (final id in idsToDelete) {
          await _isar.isarConversations.delete(id);
        }

        for (final c in map.values) {
          await _isar.isarConversations.put(c);
        }
      });
    } catch (_) {}
  }
}
