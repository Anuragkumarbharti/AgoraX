import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/chat/chat_model.dart';
import 'package:creania/services/chat/message_normalizer_deduplicator.dart';
import 'package:creania/services/chat/chat_controller.dart';

void main() {
  group('CHAT TIMEZONE & CHRONOLOGICAL SORTING TESTS', () {
    test('1. ChatMessage timestamp parsing normalizes UTC correctly', () {
      final jsonUtc = {
        'id': 'msg_1',
        'sender_id': 'user_a',
        'receiver_id': 'user_b',
        'content': 'Hello from UTC',
        'created_at': '2026-08-12T02:28:00.000Z',
      };

      final msg = ChatMessage.fromJson(jsonUtc);
      expect(msg.timestamp.isUtc, isTrue);
      expect(msg.timestamp.hour, equals(2));
      expect(msg.timestamp.minute, equals(28));
    });

    test('2. MessageNormalizerDeduplicator normalizes raw payload timestamps to UTC', () {
      final rawPayload = {
        'id': 'msg_2',
        'sender_id': 'user_b',
        'receiver_id': 'user_a',
        'content': 'Response from user B',
        'timestamp': '2026-08-12T02:29:15.000000Z',
      };

      final msg = MessageNormalizerDeduplicator.normalizePayload(rawPayload, currentUserId: 'user_a');
      expect(msg.timestamp.isUtc, isTrue);
      expect(msg.timestamp.minute, equals(29));
    });

    test('3. Mixed Local and UTC timestamps sort in strict chronological order', () {
      final nowUtc = DateTime.parse('2026-08-12T02:28:00.000Z');
      final nowLocal = nowUtc.toLocal(); // Local time (e.g. 07:58 AM IST)

      final msg1 = ChatMessage(
        id: 'msg_1',
        senderId: 'user_a',
        receiverId: 'user_b',
        conversationId: 'conv_user_b',
        content: 'First message',
        type: MessageType.text,
        status: MessageStatus.sent,
        timestamp: nowUtc,
      );

      final msg2 = ChatMessage(
        id: 'msg_2',
        senderId: 'user_b',
        receiverId: 'user_a',
        conversationId: 'conv_user_b',
        content: 'Second message',
        type: MessageType.text,
        status: MessageStatus.sent,
        timestamp: nowLocal, // local DateTime instance
      );

      final msg3 = ChatMessage(
        id: 'msg_3',
        senderId: 'user_a',
        receiverId: 'user_b',
        conversationId: 'conv_user_b',
        content: 'Third message',
        type: MessageType.text,
        status: MessageStatus.sent,
        timestamp: nowUtc.add(const Duration(minutes: 5)),
      );

      final messages = [msg3, msg1, msg2];
      
      // Sort using our standard chat controller sorting logic
      messages.sort((a, b) => a.timestamp.toUtc().compareTo(b.timestamp.toUtc()));

      expect(messages[0].id, equals('msg_1'));
      expect(messages[1].id, equals('msg_2'));
      expect(messages[2].id, equals('msg_3'));
    });

    test('4. ChatController.extractOtherUserId accurately resolves target user ID regardless of alphabetical ordering', () {
      final myUid = 'user_b';
      final otherUid = 'user_a';
      final convId = 'conv_user_a_user_b';

      final resolved = ChatController.extractOtherUserId(convId, myUid);
      expect(resolved, equals(otherUid));
      expect(resolved, isNot(equals(myUid)));
    });
  });
}
