import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:creania/services/network/network_connectivity_service.dart';
import 'package:creania/services/network/network_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Network Detection System Tests', () {
    late NetworkConnectivityService netService;

    setUp(() {
      Get.reset();
      netService = NetworkConnectivityService();
      Get.put(netService);
    });

    tearDown(() {
      Get.reset();
    });

    test('Default state is online with verified internet', () {
      expect(netService.isOnline.value, true);
      expect(netService.isWeak.value, false);
      expect(netService.networkState.value, NetworkState.wifi);
    });

    test('NetworkGuard.checkInternet returns true when online', () {
      final canProceed = NetworkGuard.checkInternet(actionName: 'room_entry', showSnackbar: false);
      expect(canProceed, true);
    });

    test('NetworkGuard blocks action and triggers callback when offline', () async {
      netService.isOnline.value = false;
      bool actionRan = false;
      bool blockedCallbackTriggered = false;

      final result = await NetworkGuard.runIfOnline(
        action: () async {
          actionRan = true;
        },
        actionName: 'send_gift',
        onOfflineBlocked: () {
          blockedCallbackTriggered = true;
        },
      );

      expect(result, false);
      expect(actionRan, false);
      expect(blockedCallbackTriggered, true);
    });

    test('NetworkGuard allows action execution when internet returns', () async {
      netService.isOnline.value = true;
      bool actionRan = false;

      final result = await NetworkGuard.runIfOnline(
        action: () async {
          actionRan = true;
        },
        actionName: 'post',
      );

      expect(result, true);
      expect(actionRan, true);
    });

    test('Manual forceRetryCheck evaluates internet status without exceptions', () async {
      final status = await netService.forceRetryCheck();
      expect(status, isA<bool>());
    });
  });
}
