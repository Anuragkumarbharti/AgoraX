import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/chat/chat_model.dart';
import 'package:creania/models/chat/isar_chat_model.dart';

void main() {
  group('WhatsApp Style Offline Messaging System Unit Tests', () {
    test('1. Message Status Enum Mapping & WhatsApp State Transitions', () {
      expect(MessageStatus.sending.index, equals(0));
      expect(MessageStatus.sent.index, equals(1));
      expect(MessageStatus.delivered.index, equals(2));
      expect(MessageStatus.read.index, equals(3));

      final now = DateTime.now();
      var msg = ChatMessage(
        id: 'msg_status_test_001',
        senderId: 'user_sender',
        receiverId: 'user_receiver',
        conversationId: 'conv_user_sender',
        content: 'Hello WhatsApp Offline',
        status: MessageStatus.sending,
        timestamp: now,
      );

      expect(msg.status, equals(MessageStatus.sending));

      // Transition to Sent (saved on server - single tick)
      msg = msg.copyWith(status: MessageStatus.sent);
      expect(msg.status, equals(MessageStatus.sent));

      // Transition to Delivered (receiver device online - double grey tick)
      msg = msg.copyWith(status: MessageStatus.delivered);
      expect(msg.status, equals(MessageStatus.delivered));

      // Transition to Read (receiver opened chat - double blue tick)
      msg = msg.copyWith(status: MessageStatus.read);
      expect(msg.status, equals(MessageStatus.read));
    });

    test('2. Complete Media Serialization (All 10 Supported Media Types)', () {
      final now = DateTime.now();
      
      final mediaTypesToTest = [
        MessageType.text,
        MessageType.image,
        MessageType.audio,
        MessageType.video,
        MessageType.document,
        MessageType.gif,
        MessageType.sticker,
        MessageType.location,
        MessageType.contact,
        MessageType.gift,
      ];

      for (final mType in mediaTypesToTest) {
        final msg = ChatMessage(
          id: 'msg_media_${mType.name}',
          senderId: 'user_a',
          receiverId: 'user_b',
          conversationId: 'conv_user_a',
          content: 'Test content for ${mType.name}',
          type: mType,
          mediaUrl: 'https://storage.creaniaa.app/media/${mType.name}.dat',
          fileName: 'sample_${mType.name}.dat',
          fileSize: 2048500,
          thumbnailUrl: 'https://storage.creaniaa.app/media/thumb_${mType.name}.jpg',
          locationLat: 12.9716,
          locationLng: 77.5946,
          locationName: 'Tech Park Center',
          contactName: 'Alice Johnson',
          contactPhone: '+919988776655',
          timestamp: now,
        );

        final jsonMap = msg.toJson();
        expect(jsonMap['type'], equals(mType.index));
        expect(jsonMap['mediaUrl'], equals('https://storage.creaniaa.app/media/${mType.name}.dat'));
        expect(jsonMap['fileName'], equals('sample_${mType.name}.dat'));
        expect(jsonMap['fileSize'], equals(2048500));
        expect(jsonMap['locationLat'], equals(12.9716));
        expect(jsonMap['contactName'], equals('Alice Johnson'));

        final restoredMsg = ChatMessage.fromJson(jsonMap);
        expect(restoredMsg.id, equals('msg_media_${mType.name}'));
        expect(restoredMsg.type, equals(mType));
        expect(restoredMsg.mediaUrl, equals(jsonMap['mediaUrl']));
        expect(restoredMsg.fileName, equals('sample_${mType.name}.dat'));
      }
    });

    test('3. IsarChatMessage Media Metadata Storage', () {
      final now = DateTime.now();
      final isarMsg = IsarChatMessage()
        ..uuid = 'isar_msg_1001'
        ..senderId = 'user_x'
        ..receiverId = 'user_y'
        ..conversationId = 'conv_user_x'
        ..content = 'Recorded Voice Note'
        ..typeValue = MessageType.audio.index
        ..statusValue = MessageStatus.delivered.index
        ..timestamp = now
        ..mediaUrl = 'https://storage.creaniaa.app/audio/voice_1001.m4a'
        ..fileName = 'voice_1001.m4a'
        ..fileSize = 450000
        ..thumbnailUrl = ''
        ..locationLat = null
        ..locationLng = null
        ..locationName = null
        ..contactName = null
        ..contactPhone = null
        ..isDeleted = false
        ..isEdited = false;

      expect(isarMsg.uuid, equals('isar_msg_1001'));
      expect(isarMsg.typeValue, equals(MessageType.audio.index));
      expect(isarMsg.statusValue, equals(MessageStatus.delivered.index));
      expect(isarMsg.mediaUrl, equals('https://storage.creaniaa.app/audio/voice_1001.m4a'));
      expect(isarMsg.fileName, equals('voice_1001.m4a'));
      expect(isarMsg.fileSize, equals(450000));
    });

    test('4. Idempotent Deduplication Logic', () {
      final existingUuids = {'msg_001', 'msg_002', 'msg_003'};
      
      bool isDuplicate(String msgId) => existingUuids.contains(msgId);

      expect(isDuplicate('msg_001'), isTrue); // Should be suppressed
      expect(isDuplicate('msg_002'), isTrue); // Should be suppressed
      expect(isDuplicate('msg_004'), isFalse); // New message allowed

      existingUuids.add('msg_004');
      expect(isDuplicate('msg_004'), isTrue); // Now suppressed
    });

    test('5. Chronological Ordering of Undelivered Catch-Up Messages', () {
      final baseTime = DateTime.now();
      
      final msg1 = ChatMessage(
        id: 'msg_c1',
        senderId: 'user_a',
        receiverId: 'user_b',
        conversationId: 'conv_user_a',
        content: 'First offline message',
        timestamp: baseTime.subtract(const Duration(minutes: 30)),
      );

      final msg2 = ChatMessage(
        id: 'msg_c2',
        senderId: 'user_a',
        receiverId: 'user_b',
        conversationId: 'conv_user_a',
        content: 'Second offline message',
        timestamp: baseTime.subtract(const Duration(minutes: 15)),
      );

      final msg3 = ChatMessage(
        id: 'msg_c3',
        senderId: 'user_a',
        receiverId: 'user_b',
        conversationId: 'conv_user_a',
        content: 'Third offline message',
        timestamp: baseTime,
      );

      // Simulating out-of-order network arrival
      final arrivedList = [msg3, msg1, msg2];
      
      // Sort chronologically (oldest first)
      arrivedList.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      expect(arrivedList[0].id, equals('msg_c1'));
      expect(arrivedList[1].id, equals('msg_c2'));
      expect(arrivedList[2].id, equals('msg_c3'));
    });
  });
}
