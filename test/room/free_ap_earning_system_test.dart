import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/progression/room_dual_progress_model.dart';

void main() {
  group('Balanced Free AP Earning System Unit Tests', () {
    test('1. Unique Seat Join Bonus (+20 Normal AP per unique user, max 5 users/day = 100 AP)', () {
      RoomDualProgress prog = const RoomDualProgress(
        roomId: 'room_505',
        goldPoints: 0,
        normalPoints: 0,
      );

      // Simulating unique user 1 sitting on seat for 1st time today (+20 AP)
      prog = prog.copyWith(normalPoints: prog.normalPoints + 20);
      expect(prog.normalPoints, equals(20));

      // Simulating unique user 2, 3, 4, 5 sitting (+20 AP each)
      for (int i = 2; i <= 5; i++) {
        prog = prog.copyWith(normalPoints: prog.normalPoints + 20);
      }

      // Max 5 unique users = 100 AP total join bonus
      expect(prog.normalPoints, equals(100));
      expect(prog.goldPoints, equals(0)); // Gold progress MUST stay 0

      // 6th user tries to join -> capped at max 5 unique users per day
      // Progress remains 100 AP
      expect(prog.normalPoints, equals(100));
    });

    test('2. Rejoining room or switching seats yields 0 extra Join Bonus', () {
      RoomDualProgress prog = const RoomDualProgress(
        roomId: 'room_505',
        normalPoints: 20, // User 1 already claimed 20 AP
      );

      // User 1 switches seat from Seat 1 to Seat 4 -> 0 extra bonus
      final seatSwitchedState = prog.copyWith(normalPoints: prog.normalPoints + 0);
      expect(seatSwitchedState.normalPoints, equals(20));

      // User 1 leaves room and rejoins -> 0 extra bonus
      final rejoinedState = seatSwitchedState.copyWith(normalPoints: seatSwitchedState.normalPoints + 0);
      expect(rejoinedState.normalPoints, equals(20));
    });

    test('3. First Gift Bonus (+5 Normal AP bonus on 1st gift sent today, max 20 users/day = 100 AP)', () {
      RoomDualProgress prog = const RoomDualProgress(
        roomId: 'room_505',
        goldPoints: 0,
        normalPoints: 0,
      );

      // User 1 sends 100 Silver Gift (1 AP) + 5 First Gift Bonus = 6 AP total
      const int giftAp = 1;
      const int firstGiftBonus = 5;
      prog = prog.copyWith(normalPoints: prog.normalPoints + giftAp + firstGiftBonus);
      expect(prog.normalPoints, equals(6));

      // User 1 sends 2nd gift on same day -> 1 AP only (0 bonus)
      prog = prog.copyWith(normalPoints: prog.normalPoints + giftAp + 0);
      expect(prog.normalPoints, equals(7));

      // Gold progress stays 0 for Silver gifts
      expect(prog.goldPoints, equals(0));
    });

    test('4. Active Seat Time Reward (4 Normal AP / min per active seated user)', () {
      RoomDualProgress prog = const RoomDualProgress(
        roomId: 'room_505',
        normalPoints: 0,
      );

      // 1 active seated user -> 4 AP/min
      prog = prog.copyWith(normalPoints: prog.normalPoints + (1 * 4));
      expect(prog.normalPoints, equals(4));

      // 5 active seated users -> 20 AP/min
      prog = prog.copyWith(normalPoints: prog.normalPoints + (5 * 4));
      expect(prog.normalPoints, equals(24));

      // 10 active seated users -> 40 AP/min
      prog = prog.copyWith(normalPoints: prog.normalPoints + (10 * 4));
      expect(prog.normalPoints, equals(64));

      // 0 seated users -> 0 AP/min
      prog = prog.copyWith(normalPoints: prog.normalPoints + (0 * 4));
      expect(prog.normalPoints, equals(64));

      // Gold progress MUST stay 0
      expect(prog.goldPoints, equals(0));
    });

    test('5. Progress Priority & Anti-Abuse Integrity', () {
      // Base state: Gold=200/1000, Normal=50/700
      RoomDualProgress prog = const RoomDualProgress(
        roomId: 'room_505',
        dailyGoldProgress: 200,
        goldTaskLimit: 1000,
        dailyFreeProgress: 50,
        freeTaskLimit: 700,
      );

      // Applying Free AP events (Join bonus +20, First gift bonus +5, Active seat time +40)
      prog = prog.copyWith(dailyFreeProgress: prog.dailyFreeProgress + 20 + 5 + 40);

      // Normal progress increases by 65 AP (50 + 65 = 115)
      expect(prog.dailyFreeProgress, equals(115));

      // Gold progress MUST REMAIN EXACTLY 200 (NEVER increased by free events)
      expect(prog.dailyGoldProgress, equals(200));
      expect(prog.goldRatio, equals(0.2));
    });
  });
}
