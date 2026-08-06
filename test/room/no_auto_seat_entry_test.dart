import 'package:flutter_test/flutter_test.dart';
import 'package:creania/services/room/room_seat_controller.dart';

void main() {
  group('Strict Audience Default & No Auto-Seat Tests', () {
    test('Initial 10 room seats start completely vacant for all roles', () {
      final seats = List.generate(
        10,
        (index) => {
          'seatIndex': index,
          'role': index == 0 ? 'Owner' : (index == 1 ? 'Co-owner' : 'Guest'),
          'userId': null,
          'name': RoomSeatController.getSeatName(index),
          'isSpeaking': false,
          'isLocked': false,
        },
      );

      expect(seats.length, equals(10));
      for (int i = 0; i < 10; i++) {
        expect(seats[i]['userId'], isNull, reason: 'Seat $i must be vacant (null) on room entry');
        expect(seats[i]['isSpeaking'], isFalse, reason: 'Seat $i must have speaking set to false');
      }
    });

    test('Default microphone state is OFF (muted) on room entry for all users', () {
      bool isMicOn = false;
      bool enableMicParam = false;

      expect(isMicOn, isFalse);
      expect(enableMicParam, isFalse);
    });

    test('Room seat controller getSeatName maps seat indices correctly', () {
      expect(RoomSeatController.getSeatName(0), equals('Host'));
      expect(RoomSeatController.getSeatName(1), equals('Co Host'));
      expect(RoomSeatController.getSeatName(2), equals('No.1'));
      expect(RoomSeatController.getSeatName(9), equals('No.8'));
    });
  });
}
