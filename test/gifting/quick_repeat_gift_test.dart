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

    test('Smart Timer: 10s global window, 3s inactivity showcase after repeat', () {
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

      // Initially active with full 10s global window
      expect(controller.remainingSeconds.value, QuickRepeatController.totalWindowSeconds);
      expect(controller.progress.value, 1.0);
      // Phase 1: 0 repeats -> shouldTriggerShowcase is false
      expect(controller.shouldTriggerShowcase.value, false);

      // Verify timer constants
      expect(QuickRepeatController.totalWindowSeconds, 10);
      expect(QuickRepeatController.inactivityShowcaseSeconds, 3);
    });

    test('Preserves original multiplier (e.g. 10x) and exact recipients for Quick Repeat', () {
      const originalRecipients = ['user_1', 'user_2', 'user_3', 'user_4', 'user_5', 'user_6', 'user_7', 'user_8', 'user_9', 'user_10'];
      controller.activateQuickRepeat(
        originalGiftTransactionId: 'tx_10x',
        roomId: 'room_101',
        senderId: 'user_sender_123',
        giftId: 'f1000001-0000-0000-0000-000000000004',
        giftName: 'Sakura',
        giftIcon: '🌸',
        currency: 'gold',
        giftCost: 2,
        recipientIds: originalRecipients,
        recipientNames: originalRecipients.map((id) => 'Name_$id').toList(),
        seatIndices: List.generate(10, (i) => i),
        initialQuantity: 10,
        multiplier: 10,
      );

      final state = controller.activeState.value!;
      expect(state.originalMultiplier, equals(10));
      expect(state.originalRecipientIds.length, equals(10));
      expect(state.currentQuantity.value, equals(10));
    });
  });
}
