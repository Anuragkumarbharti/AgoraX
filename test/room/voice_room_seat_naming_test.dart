import 'package:flutter_test/flutter_test.dart';
import 'package:creania/services/room/room_seat_controller.dart';

void main() {
  group('Voice Room Seat System Naming Convention Tests', () {
    test('Verifies exact 10 seat names mapping', () {
      expect(RoomSeatController.getSeatName(0), equals('Host'));
      expect(RoomSeatController.getSeatName(1), equals('Co-Host'));
      expect(RoomSeatController.getSeatName(2), equals('No.1'));
      expect(RoomSeatController.getSeatName(3), equals('No.2'));
      expect(RoomSeatController.getSeatName(4), equals('No.3'));
      expect(RoomSeatController.getSeatName(5), equals('No.4'));
      expect(RoomSeatController.getSeatName(6), equals('No.5'));
      expect(RoomSeatController.getSeatName(7), equals('No.6'));
      expect(RoomSeatController.getSeatName(8), equals('No.7'));
      expect(RoomSeatController.getSeatName(9), equals('No.8'));
    });

    test('Verifies 1-based seat number mapping', () {
      expect(RoomSeatController.getSeatNameByNumber(1), equals('Host'));
      expect(RoomSeatController.getSeatNameByNumber(2), equals('Co-Host'));
      expect(RoomSeatController.getSeatNameByNumber(3), equals('No.1'));
      expect(RoomSeatController.getSeatNameByNumber(4), equals('No.2'));
      expect(RoomSeatController.getSeatNameByNumber(5), equals('No.3'));
      expect(RoomSeatController.getSeatNameByNumber(6), equals('No.4'));
      expect(RoomSeatController.getSeatNameByNumber(7), equals('No.5'));
      expect(RoomSeatController.getSeatNameByNumber(8), equals('No.6'));
      expect(RoomSeatController.getSeatNameByNumber(9), equals('No.7'));
      expect(RoomSeatController.getSeatNameByNumber(10), equals('No.8'));
    });
  });
}
