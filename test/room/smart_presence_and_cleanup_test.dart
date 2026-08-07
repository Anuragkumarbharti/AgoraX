import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:creania/services/room/room_seat_controller.dart';
import 'package:creania/services/room/room_connection_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Smart Presence & Room Cleanup System Tests', () {
    late RoomSeatController seatCtrl;
    late RoomConnectionController connCtrl;

    setUp(() {
      Get.reset();
      seatCtrl = RoomSeatController();
      Get.put(seatCtrl);
      connCtrl = RoomConnectionController();
      Get.put(connCtrl);
    });

    tearDown(() {
      Get.reset();
    });

    test('isUserReconnectingOnSeat returns true during grace period', () {
      const roomId = 'room_101';
      seatCtrl.roomSeatsInfo[roomId] = [
        {
          'seatIndex': 0,
          'userId': 'user_a',
          'name': 'Host',
          'isSpeaking': false,
          'is_reconnecting': true,
        },
        {
          'seatIndex': 1,
          'userId': 'user_b',
          'name': 'Co-Host',
          'isSpeaking': true,
          'is_reconnecting': false,
        },
      ];

      expect(seatCtrl.isUserReconnectingOnSeat(roomId, 0), true);
      expect(seatCtrl.isUserReconnectingOnSeat(roomId, 1), false);
    });

    test('RoomConnectionController initializes presence state defaults', () {
      expect(connCtrl.isRoomDisconnecting.value, false);
      expect(connCtrl.disconnectTitle.value, '');
      expect(connCtrl.disconnectReason.value, '');
    });
  });
}
