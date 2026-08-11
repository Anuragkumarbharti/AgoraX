import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/chat/chat_model.dart';
import 'package:creania/services/chat/chat_data_deletion_service.dart';
import 'package:creania/services/chat/message_normalizer_deduplicator.dart';

void main() {
  group('Creania Chat System Architecture Tests', () {
    test('1. Deterministic DM Conversation ID Mapping', () {
      final userA = 'usr_101_alpha';
      final userB = 'usr_202_beta';

      final convId1 = ChatMessage.getDeterministicConversationId(userA, userB);
      final convId2 = ChatMessage.getDeterministicConversationId(userB, userA);

      expect(convId1, equals(convId2));
      expect(convId1, equals('dm_${userA}_${userB}'));
      expect(convId1.startsWith('dm_'), isTrue);
    });

    test('2. Pure Emoji Message Detection', () {
      final emojiMsg1 = ChatMessage(
        id: 'msg_1',
        senderId: 'user1',
        receiverId: 'user2',
        conversationId: 'dm_user1_user2',
        content: '❤️',
        timestamp: DateTime.now(),
      );

      final emojiMsg2 = ChatMessage(
        id: 'msg_2',
        senderId: 'user1',
        receiverId: 'user2',
        conversationId: 'dm_user1_user2',
        content: '✨🔥',
        timestamp: DateTime.now(),
      );

      final textMsg = ChatMessage(
        id: 'msg_3',
        senderId: 'user1',
        receiverId: 'user2',
        conversationId: 'dm_user1_user2',
        content: 'Hello World ❤️',
        timestamp: DateTime.now(),
      );

      expect(emojiMsg1.isPureEmoji, isTrue);
      expect(emojiMsg2.isPureEmoji, isTrue);
      expect(textMsg.isPureEmoji, isFalse);
    });

    test('3. Deletion Guard Policy - Block Automatic Deletes', () {
      final deletionService = ChatDataDeletionService();

      expect(deletionService.isDeletionAllowed(DeletionReason.userDeleteMessage), isTrue);
      expect(deletionService.isDeletionAllowed(DeletionReason.userClearChat), isTrue);
      expect(deletionService.isDeletionAllowed(DeletionReason.userDeleteConversation), isTrue);
      expect(deletionService.isDeletionAllowed(DeletionReason.serverConfirmedDelete), isTrue);

      // Blocked automatic events
      expect(deletionService.isDeletionAllowed(DeletionReason.logout), isFalse);
      expect(deletionService.isDeletionAllowed(DeletionReason.socketDisconnect), isFalse);
      expect(deletionService.isDeletionAllowed(DeletionReason.syncReconciliation), isFalse);
      expect(deletionService.isDeletionAllowed(DeletionReason.cacheRefresh), isFalse);
      expect(deletionService.isDeletionAllowed(DeletionReason.appRestart), isFalse);
      expect(deletionService.isDeletionAllowed(DeletionReason.profileMissing), isFalse);
      expect(deletionService.isDeletionAllowed(DeletionReason.networkError), isFalse);
      expect(deletionService.isDeletionAllowed(DeletionReason.pagination), isFalse);
    });

    test('4. Message Normalizer & Deduplication Pipeline', () {
      final rawSocketPayload = {
        'id': 'msg_test_1001',
        'client_message_id': 'client_1001',
        'sender_id': 'usr_99',
        'receiver_id': 'usr_100',
        'content': 'Hello from pipeline',
        'type': 0,
        'created_at': DateTime.now().toIso8601String(),
      };

      final normalized = MessageNormalizerDeduplicator.normalizePayload(rawSocketPayload, currentUserId: 'usr_99');

      expect(normalized.id, equals('msg_test_1001'));
      expect(normalized.clientMessageId, equals('client_1001'));
      expect(normalized.conversationId, equals('dm_usr_100_usr_99'));
      expect(normalized.type, equals(MessageType.text));
    });

    test('5. Room Invite Deduplication Attributes', () {
      final rawInvitePayload = {
        'id': 'msg_invite_555',
        'invite_id': 'inv_room_777_evt_1',
        'sender_id': 'host_1',
        'receiver_id': 'guest_2',
        'media_type': 'roomInvite',
        'room_id': 'CRN-RM-777',
        'location_name': 'Super Star Arena',
        'contact_name': 'Host Sukik',
        'created_at': DateTime.now().toIso8601String(),
      };

      final normalized = MessageNormalizerDeduplicator.normalizePayload(rawInvitePayload, currentUserId: 'host_1');

      expect(normalized.type, equals(MessageType.roomInvite));
      expect(normalized.inviteId, equals('inv_room_777_evt_1'));
      expect(normalized.inviteRoomId, equals('CRN-RM-777'));
      expect(normalized.inviteRoomTitle, equals('Super Star Arena'));
      expect(normalized.inviteHostName, equals('Host Sukik'));
    });
  });
}
