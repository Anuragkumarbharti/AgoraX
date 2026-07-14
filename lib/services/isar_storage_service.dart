import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/isar_chat_model.dart';

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
  }

  // ─── Conversations ───

  Future<void> saveConversation(IsarConversation conv) async {
    await _isar.writeTxn(() async {
      await _isar.isarConversations.putByUuid(conv);
    });
  }

  Future<List<IsarConversation>> getAllConversations() async {
    return await _isar.isarConversations
        .where()
        .sortByIsPinnedDesc()
        .thenByLastMessageTimeDesc()
        .findAll();
  }

  Future<IsarConversation?> getConversationByUuid(String uuid) async {
    return await _isar.isarConversations.filter().uuidEqualTo(uuid).findFirst();
  }

  Future<IsarConversation?> getConversation(String uuid) async {
    return await getConversationByUuid(uuid);
  }

  Future<void> deleteMessage(String messageUuid) async {
    await _isar.writeTxn(() async {
      final msg = await _isar.isarChatMessages.filter().uuidEqualTo(messageUuid).findFirst();
      if (msg != null) {
        msg.isDeleted = true;
        await _isar.isarChatMessages.put(msg);
      }
    });
  }

  Future<void> deleteConversation(String conversationId) async {
    await _isar.writeTxn(() async {
      // 1. Delete conversation
      final conv = await _isar.isarConversations.filter().uuidEqualTo(conversationId).findFirst();
      if (conv != null) {
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

  // ─── Messages ───

  Future<void> saveMessage(IsarChatMessage message) async {
    await _isar.writeTxn(() async {
      await _isar.isarChatMessages.putByUuid(message);
    });
  }

  Future<void> saveMessages(List<IsarChatMessage> messages) async {
    await _isar.writeTxn(() async {
      for (final msg in messages) {
        await _isar.isarChatMessages.putByUuid(msg);
      }
    });
  }

  Future<List<IsarChatMessage>> getMessagesForConversation(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return await _isar.isarChatMessages
        .filter()
        .conversationIdEqualTo(conversationId)
        .sortByTimestampDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  Future<void> updateMessageStatus(String messageUuid, int statusValue) async {
    await _isar.writeTxn(() async {
      final msg = await _isar.isarChatMessages.filter().uuidEqualTo(messageUuid).findFirst();
      if (msg != null) {
        msg.statusValue = statusValue;
        await _isar.isarChatMessages.put(msg);
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
}
