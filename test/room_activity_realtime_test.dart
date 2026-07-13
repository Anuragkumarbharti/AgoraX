import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/room_activity_event.dart';

void main() {
  group('Room Activity Realtime Event Tests', () {
    test('RoomActivityEvent serialization and properties mapping works', () {
      final json = {
        'event_id': 'evt_983247',
        'room_id': 'CRN-RM-8F4K2X',
        'event_type': 'room_join',
        'user_id': 'uid_anurag_101',
        'username': 'Anurag Kumar Bharti',
        'seat_number': 3,
        'target_user_id': null,
        'target_username': null,
        'message': '👋 Welcome Anurag Kumar Bharti! Enjoy your time in this room.',
        'created_at': '2026-07-13T10:00:00.000Z',
        'metadata': {
          'level': 32,
          'vip_level': 2,
          'noble_level': 0,
        },
      };

      final event = RoomActivityEvent.fromJson(json);

      expect(event.eventId, 'evt_983247');
      expect(event.roomId, 'CRN-RM-8F4K2X');
      expect(event.eventType, 'room_join');
      expect(event.userId, 'uid_anurag_101');
      expect(event.username, 'Anurag Kumar Bharti');
      expect(event.seatNumber, 3);
      expect(event.message, '👋 Welcome Anurag Kumar Bharti! Enjoy your time in this room.');
      expect(event.metadata['level'], 32);
      expect(event.metadata['vip_level'], 2);

      final outJson = event.toJson();
      expect(outJson['event_id'], 'evt_983247');
      expect(outJson['event_type'], 'room_join');
    });

    test('RoomActivityEvent constructs properly with helper method', () {
      final event = RoomActivityEvent(
        eventId: 'evt_new_101',
        roomId: 'CRN-RM-8F4K2X',
        eventType: 'gift_sent',
        userId: 'uid_alice',
        username: 'Alice Smith',
        seatNumber: 1,
        message: '🎁 Alice Smith sent 10 Gold Coins to Bob.',
        createdAt: DateTime.parse('2026-07-13T10:05:00.000Z'),
        metadata: {'amount': 10, 'is_gold': true},
      );

      expect(event.eventId, 'evt_new_101');
      expect(event.metadata['amount'], 10);
      expect(event.metadata['is_gold'], true);
    });
  });
}
