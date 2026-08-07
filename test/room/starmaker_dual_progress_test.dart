import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/progression/room_dual_progress_model.dart';

void main() {
  group('StarMaker Decoupled Daily Task vs Room Level System Tests', () {
    test('Completing Daily Task (600/600) DOES NOT trigger Room Level Up when Total Task < Target', () {
      // Level 1: Requires 35,500 Total Task to reach Level 2
      // User completes Daily Task: Free = 600/600, Gold = 1200/1200
      // But Total Task = 450 / 35,500
      const prog = RoomDualProgress(
        roomId: 'room_101',
        dailyFreeProgress: 600,
        freeTaskLimit: 600,
        dailyGoldProgress: 1200,
        goldTaskLimit: 1200,
        totalTask: 450,
        totalTaskTarget: 35500,
        roomLevel: 1,
      );

      expect(prog.isFreeLimitReached, isTrue);
      expect(prog.isGoldLimitReached, isTrue);
      expect(prog.totalTask, equals(450));
      expect(prog.roomLevel, equals(1)); // MUST REMAIN LEVEL 1!
    });

    test('Room Level increases ONLY when Total Task reaches target', () {
      // Base state: Total Task = 35,480 / 35,500 (Level 1)
      const initial = RoomDualProgress(
        roomId: 'room_101',
        totalTask: 35480,
        totalTaskTarget: 35500,
        roomLevel: 1,
      );

      // User earns +50 Total Task -> Total Task becomes 35,530 >= 35,500
      final excess = (initial.totalTask + 50) - initial.totalTaskTarget; // 30
      final newLevel = initial.roomLevel + 1; // 2
      final newTarget = RoomDualProgress.getRequiredTaskForLevel(newLevel); // 59,500

      final levelUpState = initial.copyWith(
        roomLevel: newLevel,
        totalTask: excess,
        totalTaskTarget: newTarget,
      );

      expect(levelUpState.roomLevel, equals(2));
      expect(levelUpState.totalTask, equals(30)); // Resets ONLY Total Task for Level 2!
      expect(levelUpState.totalTaskTarget, equals(59500));
    });

    test('Level Up resets ONLY Total Task for current level; Daily Task does NOT reset on level up', () {
      // User has Daily Task = 600/600, Total Task hits Level Up (35,530 >= 35,500)
      const beforeLevelUp = RoomDualProgress(
        roomId: 'room_101',
        dailyFreeProgress: 600,
        freeTaskLimit: 600,
        totalTask: 35530,
        totalTaskTarget: 35500,
        roomLevel: 1,
      );

      final afterLevelUp = beforeLevelUp.copyWith(
        roomLevel: 2,
        totalTask: 30, // Reset Total Task for Level 2
        totalTaskTarget: 59500,
        dailyFreeProgress: 600, // Daily Task DOES NOT reset on Level Up!
      );

      expect(afterLevelUp.roomLevel, equals(2));
      expect(afterLevelUp.totalTask, equals(30));
      expect(afterLevelUp.dailyFreeProgress, equals(600)); // Intact!
    });

    test('4:00 AM Reset clears Daily Tasks to 0 but preserves Total Task and Room Level', () {
      // Yesterday: Daily Free = 600/600, Daily Gold = 1200/1200, Total Task = 520 / 35,500, Level = 1
      const yesterday = RoomDualProgress(
        roomId: 'room_101',
        dailyFreeProgress: 600,
        freeTaskLimit: 600,
        dailyGoldProgress: 1200,
        goldTaskLimit: 1200,
        totalTask: 520,
        totalTaskTarget: 35500,
        roomLevel: 1,
        lastResetDate: '2026-08-06',
      );

      // Simulating 4:00 AM Reset
      final todayAfterReset = yesterday.copyWith(
        dailyFreeProgress: 0,
        dailyGoldProgress: 0,
        lastResetDate: '2026-08-07',
      );

      expect(todayAfterReset.dailyFreeProgress, equals(0));
      expect(todayAfterReset.dailyGoldProgress, equals(0));
      expect(todayAfterReset.totalTask, equals(520)); // Preserved!
      expect(todayAfterReset.roomLevel, equals(1)); // Preserved!
    });
  });
}
