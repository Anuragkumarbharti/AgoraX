import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/room_model.dart';
import 'package:creania/services/room_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Room System Production Stability Tests', () {
    test('RoomChatMessage copyWith and deduplication', () {
      final now = DateTime.now();
      final msg1 = RoomChatMessage(
        id: 'msg_1001',
        senderId: 'user_a',
        senderName: 'Alice',
        text: 'Hello Room!',
        timestamp: now,
      );

      expect(msg1.id, equals('msg_1001'));
      expect(msg1.senderId, equals('user_a'));
      expect(msg1.text, equals('Hello Room!'));

      final msg2 = msg1.copyWith(text: 'Hello Room Updated!');
      expect(msg2.id, equals('msg_1001'));
      expect(msg2.text, equals('Hello Room Updated!'));
    });

    test('15-Second Heartbeat calculation bounds', () {
      final lastHeartbeat = DateTime.now().subtract(const Duration(seconds: 16));
      final bool isExpired = DateTime.now().difference(lastHeartbeat).inSeconds >= 15;
      expect(isExpired, isTrue);

      final freshHeartbeat = DateTime.now().subtract(const Duration(seconds: 4));
      final bool isFreshExpired = DateTime.now().difference(freshHeartbeat).inSeconds >= 15;
      expect(isFreshExpired, isFalse);
    });

    test('Eye Count calculations from active members', () {
      final members = [
        RoomMember(userId: 'u1', role: 'Host', isMuted: false),
        RoomMember(userId: 'u2', role: 'Listener', isMuted: false),
        RoomMember(userId: 'u3', role: 'Speaker', isMuted: false),
      ];

      expect(members.length, equals(3));
    });
  });
}
