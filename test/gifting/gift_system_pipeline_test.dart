import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/gift/gift_animation_metadata.dart';
import 'package:creania/services/gifting/sender_position_resolver.dart';
import 'package:creania/services/gifting/receiver_resolver.dart';
import 'package:creania/services/gifting/animation_timeline.dart';
import 'package:creania/services/gifting/gift_animation_controller.dart';
import 'package:creania/services/gifting/gift_pipeline_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gift Animation Pipeline & Timing Tests', () {
    test('AnimationTimeline stage durations and total duration by tier', () {
      expect(AnimationTimeline.getShowcaseDuration(GiftTier.tier1), const Duration(milliseconds: 5500));
      expect(AnimationTimeline.getTotalDuration(GiftTier.tier1), const Duration(milliseconds: 8100));

      expect(AnimationTimeline.getShowcaseDuration(GiftTier.tier2), const Duration(milliseconds: 7000));
      expect(AnimationTimeline.getShowcaseDuration(GiftTier.tier3), const Duration(milliseconds: 8800));
      expect(AnimationTimeline.getShowcaseDuration(GiftTier.tier4), const Duration(milliseconds: 10500));
      expect(AnimationTimeline.getShowcaseDuration(GiftTier.tier5), const Duration(milliseconds: 12500));
    });

    test('AnimationTimeline stage progress calculation', () {
      final stageA = AnimationTimeline.getStageProgress(0.02, GiftTier.tier1);
      expect(stageA.stage, AnimationStage.stageA);

      final stageB = AnimationTimeline.getStageProgress(0.50, GiftTier.tier1);
      expect(stageB.stage, AnimationStage.stageB);

      final stageC = AnimationTimeline.getStageProgress(0.95, GiftTier.tier1);
      expect(stageC.stage, AnimationStage.stageC);
    });

    test('GiftPipelineManager Queue & Particle Pool Tests', () {
      final manager = GiftPipelineManager();
      expect(manager.deviceTier, DevicePerformanceTier.highEnd);

      final particle = ParticlePoolManager().obtainParticle();
      expect(particle, isNotNull);
      ParticlePoolManager().releaseParticle(particle);
    });
  });

  group('SenderPositionResolver Tests', () {
    test('Case 1: Sender is sitting on a room seat -> returns seat position', () {
      final keyMap = <int, GlobalKey>{};
      final seats = [
        {'seatIndex': 0, 'userId': 'user_123', 'name': 'Alice'},
        {'seatIndex': 1, 'userId': 'user_456', 'name': 'Bob'},
      ];

      final pos = SenderPositionResolver.resolve(
        senderId: 'user_123',
        roomSeats: seats,
        seatKeys: keyMap,
        fallbackProfilePosition: const Offset(100, 600),
      );

      expect(pos, isNotNull);
    });

    test('Case 2: Sender is NOT sitting on any seat -> starts from profile area', () {
      final keyMap = <int, GlobalKey>{};
      final seats = [
        {'seatIndex': 0, 'userId': 'user_456', 'name': 'Bob'},
      ];

      final pos = SenderPositionResolver.resolve(
        senderId: 'user_listener_789',
        roomSeats: seats,
        seatKeys: keyMap,
        fallbackProfilePosition: const Offset(200, 700),
      );

      expect(pos, const Offset(200, 700));
    });
  });

  group('ReceiverResolver Tests', () {
    test('Resolves single and multiple receiver seats with live room mapping', () {
      final keyMap = <int, GlobalKey>{};
      final seats = [
        {'seatIndex': 1, 'userId': 'user_a', 'name': 'User A', 'avatar': 'https://example.com/a.png'},
        {'seatIndex': 2, 'userId': 'user_b', 'name': 'User B', 'avatar': 'https://example.com/b.png'},
        {'seatIndex': 3, 'userId': 'user_c', 'name': 'User C', 'avatar': 'https://example.com/c.png'},
      ];

      final resolved = ReceiverResolver.resolve(
        receiverIds: ['user_a', 'user_b', 'user_c'],
        seatIndices: [1, 2, 3],
        receiverNames: ['User A', 'User B', 'User C'],
        roomSeats: seats,
        seatKeys: keyMap,
      );

      expect(resolved.length, 3);
      expect(resolved[0].userId, 'user_a');
      expect(resolved[0].seatIndex, 1);
      expect(resolved[1].userId, 'user_b');
      expect(resolved[1].seatIndex, 2);
      expect(resolved[2].userId, 'user_c');
      expect(resolved[2].seatIndex, 3);
    });
  });

  group('GiftAnimationController Event Dispatching Tests', () {
    test('Dispatches and deduplicates broadcast gift events', () {
      final controller = GiftAnimationController();

      final payload = {
        'id': 'evt_12345',
        'gift_id': 'f1000001-0000-0000-0000-000000000001',
        'gift_name': 'Rose',
        'gift_icon': '🌹',
        'sender_id': 'user_sender',
        'sender_name': 'Sender User',
        'receiver_ids': ['user_rec1', 'user_rec2'],
        'receiver_names': ['Rec 1', 'Rec 2'],
        'seat_indices': [1, 2],
        'count': 1,
        'timestamp': 1723000000000,
      };

      controller.dispatchBroadcastGiftEvent(payload);
      expect(controller.activeEvents.length, 1);

      controller.dispatchBroadcastGiftEvent(payload);
      expect(controller.activeEvents.length, 1);

      controller.removeEvent('evt_12345');
      expect(controller.activeEvents.isEmpty, true);
    });
  });
}
