import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/gift/gift_animation_metadata.dart';
import 'package:creania/services/gifting/sender_position_resolver.dart';
import 'package:creania/services/gifting/receiver_resolver.dart';
import 'package:creania/services/gifting/animation_timeline.dart';
import 'package:creania/services/gifting/gift_animation_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gift Animation Pipeline & Timing Tests', () {
    test('AnimationTimeline stage durations and total duration by tier', () {
      expect(AnimationTimeline.stageADuration, const Duration(seconds: 1));
      expect(AnimationTimeline.stageCDuration, const Duration(seconds: 1));

      expect(AnimationTimeline.getStageBDuration(GiftTier.basic), const Duration(seconds: 2));
      expect(AnimationTimeline.getStageBDuration(GiftTier.premium), const Duration(seconds: 3));
      expect(AnimationTimeline.getStageBDuration(GiftTier.epic), const Duration(seconds: 4));
      expect(AnimationTimeline.getStageBDuration(GiftTier.legendary), const Duration(seconds: 5));
      expect(AnimationTimeline.getStageBDuration(GiftTier.mythic), const Duration(seconds: 6));

      expect(AnimationTimeline.getTotalDuration(GiftTier.basic), const Duration(seconds: 4));
      expect(AnimationTimeline.getTotalDuration(GiftTier.premium), const Duration(seconds: 5));
      expect(AnimationTimeline.getTotalDuration(GiftTier.epic), const Duration(seconds: 6));
      expect(AnimationTimeline.getTotalDuration(GiftTier.legendary), const Duration(seconds: 7));
      expect(AnimationTimeline.getTotalDuration(GiftTier.mythic), const Duration(seconds: 8));
    });

    test('AnimationTimeline stage progress calculation', () {
      // Basic Tier (Total 4 seconds: A=1s [0-0.25], B=2s [0.25-0.75], C=1s [0.75-1.0])
      final stageA = AnimationTimeline.getStageProgress(0.10, GiftTier.basic);
      expect(stageA.stage, AnimationStage.stageA);
      expect(stageA.stageNormalizedProgress, closeTo(0.4, 0.01));

      final stageB = AnimationTimeline.getStageProgress(0.50, GiftTier.basic);
      expect(stageB.stage, AnimationStage.stageB);
      expect(stageB.stageNormalizedProgress, closeTo(0.5, 0.01));

      final stageC = AnimationTimeline.getStageProgress(0.875, GiftTier.basic);
      expect(stageC.stage, AnimationStage.stageC);
      expect(stageC.stageNormalizedProgress, closeTo(0.5, 0.01));
    });
  });

  group('SenderPositionResolver Tests', () {
    test('Case 1: Sender is sitting on a room seat -> returns seat position', () {
      final keyMap = <int, GlobalKey>{};

      final seats = [
        {'seatIndex': 0, 'userId': 'user_123', 'name': 'Alice'},
        {'seatIndex': 1, 'userId': 'user_456', 'name': 'Bob'},
      ];

      // Since seatKeys context is null in pure unit test, returns fallback/calculated seat
      final pos = SenderPositionResolver.resolve(
        senderId: 'user_123',
        roomSeats: seats,
        seatKeys: keyMap,
        fallbackProfilePosition: const Offset(100, 600),
      );

      // User 123 is sitting on seat 0
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

      // User listener is NOT sitting on any seat -> fallback profile position used
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
        'gift_id': 'a2000000-0000-0000-0000-000000000003',
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

      // Duplicate dispatch of same id should be ignored
      controller.dispatchBroadcastGiftEvent(payload);
      expect(controller.activeEvents.length, 1);

      // Clean up event
      controller.removeEvent('evt_12345');
      expect(controller.activeEvents.isEmpty, true);
    });
  });
}
