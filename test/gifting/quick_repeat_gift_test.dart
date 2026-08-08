import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:creania/models/user/user_model.dart';
import 'package:creania/services/gifting/quick_repeat_controller.dart';
import 'package:creania/services/gifting/gift_event_service.dart';
import 'package:creania/services/user/user_profile_cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QuickRepeatController controller;

  setUp(() {
    Get.reset();
    UserProfileCacheManager.setCurrentUserForTesting(
      User.fromJson({
        'id': 'user_sender_123',
        'username': 'Sender',
        'email': 'sender@example.com',
      }),
    );
    controller = Get.put(QuickRepeatController());
  });

  tearDown(() {
    controller.clearQuickRepeat();
    UserProfileCacheManager.setCurrentUserForTesting(null);
    Get.reset();
  });

  group('Quick Repeat System Tests', () {
    test('Sender-Only Isolation: activates ONLY for current sender', () {
      // Attempt activation for a DIFFERENT user
      controller.activateQuickRepeat(
        originalGiftTransactionId: 'tx_1',
        roomId: 'room_101',
        senderId: 'user_other_999',
        giftId: 'g_pearl',
        giftName: 'Pearl',
        giftIcon: '🦪',
        currency: 'gold',
        giftCost: 1,
        recipientIds: ['user_rec_1'],
        recipientNames: ['Alice'],
        seatIndices: [1],
        initialQuantity: 1,
      );

      expect(controller.activeState.value, isNull);
      expect(controller.isVisible('room_101', 'user_sender_123'), false);
      expect(controller.isVisible('room_101', 'user_other_999'), false);

      // Activate for CURRENT sender
      controller.activateQuickRepeat(
        originalGiftTransactionId: 'tx_2',
        roomId: 'room_101',
        senderId: 'user_sender_123',
        giftId: 'g_pearl',
        giftName: 'Pearl',
        giftIcon: '🦪',
        currency: 'gold',
        giftCost: 1,
        recipientIds: ['user_rec_1'],
        recipientNames: ['Alice'],
        seatIndices: [1],
        initialQuantity: 1,
      );

      expect(controller.activeState.value, isNotNull);
      expect(controller.activeState.value!.giftName, 'Pearl');
      expect(controller.activeState.value!.currentQuantity.value, 1);
      expect(controller.isVisible('room_101', 'user_sender_123'), true);
      expect(controller.isVisible('room_101', 'user_other_999'), false);
    });

    test('Multi-Recipient List Preservation', () {
      controller.activateQuickRepeat(
        originalGiftTransactionId: 'tx_multi',
        roomId: 'room_101',
        senderId: 'user_sender_123',
        giftId: 'g_pearl',
        giftName: 'Pearl',
        giftIcon: '🦪',
        currency: 'gold',
        giftCost: 5,
        recipientIds: ['rec_a', 'rec_b', 'rec_c'],
        recipientNames: ['Alice', 'Bob', 'Charlie'],
        seatIndices: [1, 2, 3],
        initialQuantity: 1,
      );

      final state = controller.activeState.value!;
      expect(state.recipientIds, ['rec_a', 'rec_b', 'rec_c']);
      expect(state.recipientNames, ['Alice', 'Bob', 'Charlie']);
      expect(state.seatIndices, [1, 2, 3]);
      expect(state.giftCost, 5);
    });

    test('Different Gift Replacement Behavior', () {
      // 1. Send Pearl
      controller.activateQuickRepeat(
        originalGiftTransactionId: 'tx_pearl',
        roomId: 'room_101',
        senderId: 'user_sender_123',
        giftId: 'g_pearl',
        giftName: 'Pearl',
        giftIcon: '🦪',
        currency: 'gold',
        giftCost: 1,
        recipientIds: ['rec_a'],
        recipientNames: ['Alice'],
        seatIndices: [1],
        initialQuantity: 1,
      );

      expect(controller.activeState.value!.giftName, 'Pearl');

      // 2. Send Balloon while Pearl active
      controller.activateQuickRepeat(
        originalGiftTransactionId: 'tx_balloon',
        roomId: 'room_101',
        senderId: 'user_sender_123',
        giftId: 'g_balloon',
        giftName: 'Balloon',
        giftIcon: '🎈',
        currency: 'gold',
        giftCost: 10,
        recipientIds: ['rec_a'],
        recipientNames: ['Alice'],
        seatIndices: [1],
        initialQuantity: 1,
      );

      expect(controller.activeState.value!.giftName, 'Balloon');
      expect(controller.activeState.value!.giftCost, 10);
      expect(controller.activeState.value!.currentQuantity.value, 1);
    });

    test('Clear Quick Repeat resets state and cancels timer', () {
      controller.activateQuickRepeat(
        originalGiftTransactionId: 'tx_1',
        roomId: 'room_101',
        senderId: 'user_sender_123',
        giftId: 'g_pearl',
        giftName: 'Pearl',
        giftIcon: '🦪',
        currency: 'gold',
        giftCost: 1,
        recipientIds: ['rec_a'],
        recipientNames: ['Alice'],
        seatIndices: [1],
        initialQuantity: 1,
      );

      expect(controller.activeState.value, isNotNull);
      controller.clearQuickRepeat();
      expect(controller.activeState.value, isNull);
      expect(controller.remainingSeconds.value, 0);
    });

    test('Smart Timer: 10s total window and 3s repeat reset rule', () {
      controller.activateQuickRepeat(
        originalGiftTransactionId: 'tx_timer',
        roomId: 'room_101',
        senderId: 'user_sender_123',
        giftId: 'g_pearl',
        giftName: 'Pearl',
        giftIcon: '🦪',
        currency: 'gold',
        giftCost: 1,
        recipientIds: ['rec_a'],
        recipientNames: ['Alice'],
        seatIndices: [1],
        initialQuantity: 1,
      );

      // Initially active with 10s window
      expect(controller.remainingSeconds.value, 10);
      expect(controller.progress.value, 1.0);

      // Verify timer constants
      expect(QuickRepeatController.totalWindowSeconds, 10);
      expect(QuickRepeatController.tapResetSeconds, 3);
    });
  });
}
