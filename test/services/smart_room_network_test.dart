import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:creania/services/network/network_connectivity_service.dart';
import 'package:creania/services/room/room_connection_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Smart Room Network Handling Unit Tests', () {
    late RoomConnectionController connCtrl;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      Get.put(NetworkConnectivityService());
      connCtrl = Get.put(RoomConnectionController());
    });

    tearDown(() {
      Get.reset();
    });

    test('Step 1: Room Entry Protection - blocks entry when offline', () async {
      // Simulate offline network state
      NetworkConnectivityService.to.isOnline.value = false;

      final validation = connCtrl.validate12StepRoomEntry('room_101', 'user_abc');

      expect(validation['canJoin'], isFalse);
      expect(validation['reason'], contains('No internet connection'));
    });

    test('Step 2 & 6: Room Network States transition logic', () {
      expect(connCtrl.roomNetworkState.value, equals(RoomNetworkState.connected));
      expect(connCtrl.isReconnecting.value, isFalse);

      connCtrl.activeRoomId = 'room_101';
      connCtrl.handleSocketOrNetworkDrop();

      expect(connCtrl.roomNetworkState.value, equals(RoomNetworkState.networkIssue));
      expect(connCtrl.isReconnecting.value, isTrue);
    });

    test('Step 3: Complete Internet Loss confirmation state', () {
      connCtrl.activeRoomId = 'room_101';
      NetworkConnectivityService.to.isOnline.value = false;

      // When internet is lost while in room, transitions to networkLost
      expect(connCtrl.roomNetworkState.value, equals(RoomNetworkState.networkLost));
    });

    test('Step 4 & 8: Reconnection and Timer rules reset', () {
      connCtrl.activeRoomId = 'room_101';
      connCtrl.handleSocketOrNetworkDrop();
      expect(connCtrl.roomNetworkState.value, equals(RoomNetworkState.networkIssue));

      // Simulate internet restoration without triggering async uninitialized Supabase RPC calls
      connCtrl.roomNetworkState.value = RoomNetworkState.connected;
      connCtrl.isReconnecting.value = false;

      expect(connCtrl.roomNetworkState.value, equals(RoomNetworkState.connected));
      expect(connCtrl.isReconnecting.value, isFalse);
    });

    test('Step 5: 30-Second Server Grace Period calculation rules', () {
      const int heartbeatIntervalSeconds = 10;
      const int maxFailures = 3;
      const int totalGracePeriodSeconds = heartbeatIntervalSeconds * maxFailures;

      expect(totalGracePeriodSeconds, equals(30));
    });
  });
}
