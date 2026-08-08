import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:creania/models/room/room_background_model.dart';
import 'package:creania/models/gift/gift_animation_metadata.dart';
import 'package:creania/services/room/room_background_controller.dart';
import 'package:creania/services/gifting/gift_animation_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Background & Effect Decoupling Verification', () {
    late RoomBackgroundController bgController;
    late GiftAnimationController giftController;

    setUp(() {
      Get.reset();
      bgController = Get.put(RoomBackgroundController());
      giftController = Get.put(GiftAnimationController());
    });

    tearDown(() {
      Get.reset();
    });

    test('Rapid background updates (10+ changes) do not disrupt active gift animation queue', () async {
      // 1. Dispatch active gift animation payload
      final payload = GiftAnimationEventPayload(
        id: 'test_gift_anim_1001',
        giftId: 'super_car',
        giftName: 'Super Car',
        giftIcon: '🏎️',
        senderId: 'user_1',
        senderName: 'Alice',
        receiverIds: ['user_2'],
        receiverNames: ['Bob'],
        receiverSeats: [1],
        tier: GiftTier.tier4,
        price: 500,
        currency: 'gold',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      giftController.dispatchBroadcastGiftEvent(payload.toJson());
      expect(giftController.activeEvents.length, equals(1));
      expect(giftController.activeEvents.first.id, equals('test_gift_anim_1001'));

      // 2. Change room background WebP 10+ times continuously
      final backgrounds = RoomBackgroundCatalog.allBackgrounds;
      for (int i = 0; i < 15; i++) {
        final selectedBg = backgrounds[i % backgrounds.length];
        bgController.activeRoomBackground.value = selectedBg;
        expect(bgController.activeRoomBackground.value.id, equals(selectedBg.id));
      }

      // 3. Verify that the active gift event remained active and untouched in the queue
      expect(giftController.activeEvents.length, equals(1));
      expect(giftController.activeEvents.first.id, equals('test_gift_anim_1001'));
    });
  });
}
