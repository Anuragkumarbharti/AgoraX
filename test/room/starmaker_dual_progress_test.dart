import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/progression/room_dual_progress_model.dart';

void main() {
  group('StarMaker Dual Progress System Model Tests', () {
    test('Initial dual progress defaults to level 1 targets', () {
      const dualProg = RoomDualProgress(roomId: 'room_101');

      expect(dualProg.roomId, equals('room_101'));
      expect(dualProg.goldPoints, equals(0));
      expect(dualProg.goldTarget, equals(1000));
      expect(dualProg.normalPoints, equals(0));
      expect(dualProg.normalTarget, equals(700));
      expect(dualProg.goldRatio, equals(0.0));
      expect(dualProg.normalRatio, equals(0.0));
      expect(dualProg.isGoldFull, isFalse);
      expect(dualProg.isNormalFull, isFalse);
      expect(dualProg.isOverflowActive, isFalse);
    });

    test('Gold Progress fills up to 100% capacity', () {
      const dualProg = RoomDualProgress(
        roomId: 'room_101',
        goldPoints: 1000,
        goldTarget: 1000,
        normalPoints: 200,
        normalTarget: 700,
      );

      expect(dualProg.goldRatio, equals(1.0));
      expect(dualProg.isGoldFull, isTrue);
      expect(dualProg.isOverflowActive, isTrue);
      expect(dualProg.normalPoints, equals(200));
      expect(dualProg.normalRatio, closeTo(0.285, 0.01));
    });

    test('Gold Overflow points fill Normal Progress', () {
      // User sent 1500 Gold Coins -> 1000 fills Gold Bar, 500 overflows to Normal Bar
      const dualProg = RoomDualProgress(
        roomId: 'room_101',
        goldPoints: 1000,
        goldTarget: 1000,
        normalPoints: 500,
        normalTarget: 700,
        overflowPoints: 500,
      );

      expect(dualProg.isGoldFull, isTrue);
      expect(dualProg.goldPoints, equals(1000));
      expect(dualProg.normalPoints, equals(500));
      expect(dualProg.overflowPoints, equals(500));
      expect(dualProg.totalPoints, equals(1500));
      expect(dualProg.totalTarget, equals(1700));
      expect(dualProg.overallRatio, closeTo(0.882, 0.01));
    });

    test('Free activities increase ONLY Normal Progress and NEVER Gold Progress', () {
      // Base state: Gold=300/1000, Normal=100/700
      const initial = RoomDualProgress(
        roomId: 'room_101',
        goldPoints: 300,
        goldTarget: 1000,
        normalPoints: 100,
        normalTarget: 700,
      );

      // Simulating a free activity (like / room stay / chat): +150 points
      final afterFreeActivity = initial.copyWith(
        normalPoints: initial.normalPoints + 150,
      );

      // Gold Progress MUST stay unchanged (300)
      expect(afterFreeActivity.goldPoints, equals(300));
      expect(afterFreeActivity.normalPoints, equals(250));
      expect(afterFreeActivity.goldRatio, equals(0.3));
      expect(afterFreeActivity.normalRatio, closeTo(0.357, 0.01));
    });

    test('JSON serialization & deserialization integrity', () {
      final jsonMap = {
        'room_id': 'room_777',
        'gold_points': 1000,
        'gold_target': 2000,
        'normal_points': 1400,
        'normal_target': 1400,
        'overflow_points': 400,
        'room_level': 2,
        'updated_at': '2026-08-07T18:00:00.000Z',
      };

      final dualProg = RoomDualProgress.fromJson(jsonMap);

      expect(dualProg.roomId, equals('room_777'));
      expect(dualProg.goldPoints, equals(1000));
      expect(dualProg.goldTarget, equals(2000));
      expect(dualProg.normalPoints, equals(1400));
      expect(dualProg.normalTarget, equals(1400));
      expect(dualProg.overflowPoints, equals(400));
      expect(dualProg.roomLevel, equals(2));
      expect(dualProg.isNormalFull, isTrue);

      final exportedJson = dualProg.toJson();
      expect(exportedJson['room_id'], equals('room_777'));
      expect(exportedJson['gold_points'], equals(1000));
      expect(exportedJson['normal_points'], equals(1400));
    });
  });
}
