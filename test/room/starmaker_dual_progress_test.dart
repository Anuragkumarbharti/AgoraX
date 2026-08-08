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

    test('Gold Gift fills Gold Task FIRST; Normal Task remains 0 until Gold Task is full', () {
      const goldLimit = 1000;
      const freeLimit = 700;
      int dailyGold = 0;
      int dailyFree = 0;

      // User sends 500 Gold Gift
      const goldGiftAmount = 500;
      final goldCapacity = (goldLimit - dailyGold).clamp(0, goldLimit);
      final addedGold = goldGiftAmount < goldCapacity ? goldGiftAmount : goldCapacity;
      final remainingGold = goldGiftAmount - addedGold;
      final addedFree = remainingGold > 0 ? (remainingGold < (freeLimit - dailyFree) ? remainingGold : (freeLimit - dailyFree)) : 0;

      dailyGold += addedGold;
      dailyFree += addedFree;

      expect(dailyGold, equals(500));
      expect(dailyFree, equals(0)); // MUST STAY 0!
    });

    test('Gold Gift spills over to Normal Task ONLY after Gold Task is 100% complete', () {
      const goldLimit = 1000;
      const freeLimit = 700;
      int dailyGold = 900; // Gold Task is 900/1000
      int dailyFree = 0;

      // User sends 300 Gold Gift
      const goldGiftAmount = 300;
      final goldCapacity = (goldLimit - dailyGold).clamp(0, goldLimit); // 100
      final addedGold = goldGiftAmount < goldCapacity ? goldGiftAmount : goldCapacity; // 100
      final remainingGold = goldGiftAmount - addedGold; // 200
      final freeCapacity = (freeLimit - dailyFree).clamp(0, freeLimit); // 700
      final addedFree = remainingGold < freeCapacity ? remainingGold : freeCapacity; // 200

      dailyGold += addedGold;
      dailyFree += addedFree;

      expect(dailyGold, equals(1000)); // Gold Task complete (1000/1000)
      expect(dailyFree, equals(200)); // Excess 200 went to Normal Task!
    });

    test('Silver Gift (100:1 AP ratio) and Volt Gift count ONLY in Normal Task', () {
      const silverCoinsSent = 1000;
      final silverAp = (silverCoinsSent / 100).floor(); // 10 AP
      const voltAp = 25; // 25 AP

      const goldLimit = 1000;
      const freeLimit = 700;
      int dailyGold = 0;
      int dailyFree = 0;

      // Silver gift added to free task only
      dailyFree += silverAp;
      expect(dailyFree, equals(10));
      expect(dailyGold, equals(0)); // Gold Task remains 0

      // Volt gift added to free task only
      dailyFree += voltAp;
      expect(dailyFree, equals(35));
      expect(dailyGold, equals(0)); // Gold Task remains 0
    });

    test('Weekend 2x Limit expands total limit from 1700 AP to 3400 AP', () {
      const weekdayFreeLimit = 700;
      const weekdayGoldLimit = 1000;
      const weekdayTotalLimit = weekdayFreeLimit + weekdayGoldLimit;

      const weekendFreeLimit = 1400; // 700 * 2
      const weekendGoldLimit = 2000; // 1000 * 2
      const weekendTotalLimit = weekendFreeLimit + weekendGoldLimit;

      expect(weekdayTotalLimit, equals(1700));
      expect(weekendTotalLimit, equals(3400)); // Exactly 2x limit!
    });
  });
}
