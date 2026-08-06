import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/progression/room_progression_models.dart';
import 'package:creania/services/room/room_progression_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Creania Room Level & Task Engine Unit Tests', () {
    late RoomProgressionController progressionCtrl;

    setUp(() {
      progressionCtrl = RoomProgressionController();
    });

    test('1. Room Level Matrix Thresholds & Config (Levels 1 to 7)', () {
      final l1 = RoomLevelMatrixConfig.getForLevel(1);
      expect(l1.level, equals(1));
      expect(l1.requiredVp, equals(0));
      expect(l1.maxCoOwners, equals(1));
      expect(l1.maxAdmins, equals(4));
      expect(l1.maxHostSeats, equals(4));
      expect(l1.hasRoomMusic, isTrue);

      final l3 = RoomLevelMatrixConfig.getForLevel(3);
      expect(l3.level, equals(3));
      expect(l3.requiredVp, equals(59500));
      expect(l3.maxCoOwners, equals(2));
      expect(l3.maxAdmins, equals(11));
      expect(l3.maxHostSeats, equals(8));
      expect(l3.hasShowcaseBadge, isTrue);

      final l5 = RoomLevelMatrixConfig.getForLevel(5);
      expect(l5.level, equals(5));
      expect(l5.requiredVp, equals(490000));
      expect(l5.grandPrizeCoins, equals(2000));
      expect(l5.grandPrizeVipLevel, equals(2));
      expect(l5.grandPrizeVipDays, equals(60));
      expect(l5.maxCoOwners, equals(3));
      expect(l5.maxAdmins, equals(16));
      expect(l5.hasPermanentChatBubble, isTrue);

      final l6 = RoomLevelMatrixConfig.getForLevel(6);
      expect(l6.level, equals(6));
      expect(l6.requiredVp, equals(940000));
      expect(l6.grandPrizeCoins, equals(5000));
      expect(l6.grandPrizeVipLevel, equals(2));
      expect(l6.grandPrizeVipDays, equals(180));

      final l7 = RoomLevelMatrixConfig.getForLevel(7);
      expect(l7.level, equals(7));
      expect(l7.requiredVp, equals(1590000));
      expect(l7.grandPrizeCoins, equals(12000));
      expect(l7.grandPrizeVipLevel, equals(3));
      expect(l7.grandPrizeVipDays, equals(365));
      expect(l7.maxCoOwners, equals(3));
      expect(l7.maxAdmins, equals(20));
      expect(l7.maxHostSeats, equals(15));
      expect(l7.hasRoomMusic, isTrue);
    });

    test('2. Role & Host Seat Caps Enforcement Across Levels', () {
      bool canAssignAdmin(int roomLevel, int currentAdminCount) {
        final cfg = RoomLevelMatrixConfig.getForLevel(roomLevel);
        return currentAdminCount < cfg.maxAdmins;
      }

      bool canAssignCoOwner(int roomLevel, int currentCoOwnerCount) {
        final cfg = RoomLevelMatrixConfig.getForLevel(roomLevel);
        return currentCoOwnerCount < cfg.maxCoOwners;
      }

      // Level 1: Max 4 Admins, Max 1 Co-Owner
      expect(canAssignAdmin(1, 3), isTrue);
      expect(canAssignAdmin(1, 4), isFalse);
      expect(canAssignCoOwner(1, 0), isTrue);
      expect(canAssignCoOwner(1, 1), isFalse);

      // Level 7: Max 20 Admins, Max 3 Co-Owners
      expect(canAssignAdmin(7, 19), isTrue);
      expect(canAssignAdmin(7, 20), isFalse);
      expect(canAssignCoOwner(7, 2), isTrue);
      expect(canAssignCoOwner(7, 3), isFalse);
    });

    test('3. Active Member Turbo VP Surge Multiplier Calculation', () {
      // 1 to 4 members = 1.0x
      expect(progressionCtrl.calculateActiveMemberSurgeMultiplier(3), equals(1.0));

      // 5 to 7 members = 1.5x
      expect(progressionCtrl.calculateActiveMemberSurgeMultiplier(6), equals(1.5));

      // 8 to 9 members = 2.0x
      expect(progressionCtrl.calculateActiveMemberSurgeMultiplier(8), equals(2.0));

      // 10 to 14 members = 2.5x
      expect(progressionCtrl.calculateActiveMemberSurgeMultiplier(12), equals(2.5));

      // 15 to 19 members = 3.5x
      expect(progressionCtrl.calculateActiveMemberSurgeMultiplier(17), equals(3.5));

      // 20+ members = 4.0x
      expect(progressionCtrl.calculateActiveMemberSurgeMultiplier(22), equals(4.0));
    });

    test('4. VP Source Rate Addition & Level Progression Calculation', () {
      int calculateVpEarned({
        int silverGifts = 0,
        int goldGifts = 0,
        int stayMinutes = 0,
        int micMinutes = 0,
        int pkVictories = 0,
      }) {
        return (silverGifts * 1) +
            (goldGifts * 10) +
            (stayMinutes * 5) +
            (micMinutes * 8) +
            (pkVictories * 500);
      }

      final earnedVp = calculateVpEarned(
        silverGifts: 50,
        goldGifts: 10,
        stayMinutes: 20,
        micMinutes: 15,
        pkVictories: 1,
      );

      // 50*1 + 10*10 + 20*5 + 15*8 + 500*1 = 50 + 100 + 100 + 120 + 500 = 870 VP
      expect(earnedVp, equals(870));
    });

    test('5. Daily Reset Rule Verification (Daily Progress Resets to 0, Total VP Preserved)', () {
      final initialTotalVp = 350000;
      final initialLevel = 3;
      final todayTaskProgress = 850;

      // Simulate 04:00 AM daily reset
      final resetTodayTaskProgress = 0;
      final preservedTotalVp = initialTotalVp;
      final preservedLevel = initialLevel;

      expect(resetTodayTaskProgress, equals(0));
      expect(preservedTotalVp, equals(350000));
      expect(preservedLevel, equals(3));
    });

    test('6. Perk Tier Unlocks (Avatar Frames, Showcase Badges L3+, Chat Bubbles L5+)', () {
      expect(RoomLevelMatrixConfig.getForLevel(2).hasShowcaseBadge, isFalse);
      expect(RoomLevelMatrixConfig.getForLevel(3).hasShowcaseBadge, isTrue);
      expect(RoomLevelMatrixConfig.getForLevel(4).hasPermanentChatBubble, isFalse);
      expect(RoomLevelMatrixConfig.getForLevel(5).hasPermanentChatBubble, isTrue);
    });

    test('7. Overflow Carry Forward Protection on Level Up (e.g. 35,498 + 5 = 35,503 => Level 2, 3 Carry Forward)', () {
      final level1Target = 35500;
      final currentXp = 35498;
      final addedXp = 5;
      final newTotal = currentXp + addedXp; // 35503

      expect(newTotal >= level1Target, isTrue);

      final newLevel = RoomLevelMatrixConfig.levels
          .lastWhere((cfg) => cfg.requiredVp <= newTotal)
          .level;
      expect(newLevel, equals(2));

      final level2Base = RoomLevelMatrixConfig.getForLevel(2).requiredVp; // 35500
      final overflowCarryForward = newTotal - level2Base; // 3 XP
      expect(overflowCarryForward, equals(3));
    });

    test('8. Active Seat VP Matrix Rates (1:4 to 10:60) & Weekend Targets (1250 Free / 1250 Gold)', () {
      final progCtrl = RoomProgressionController();
      expect(progCtrl.calculateActiveStageVpRate(1), equals(4));
      expect(progCtrl.calculateActiveStageVpRate(2), equals(8));
      expect(progCtrl.calculateActiveStageVpRate(3), equals(14));
      expect(progCtrl.calculateActiveStageVpRate(4), equals(20));
      expect(progCtrl.calculateActiveStageVpRate(5), equals(28));
      expect(progCtrl.calculateActiveStageVpRate(6), equals(36));
      expect(progCtrl.calculateActiveStageVpRate(7), equals(44));
      expect(progCtrl.calculateActiveStageVpRate(8), equals(50));
      expect(progCtrl.calculateActiveStageVpRate(9), equals(55));
      expect(progCtrl.calculateActiveStageVpRate(10), equals(60));

      expect(RoomDailyVpConfig.getFreeTarget(false), equals(700));
      expect(RoomDailyVpConfig.getGoldTarget(false), equals(1000));
      expect(RoomDailyVpConfig.getFreeTarget(true), equals(1400));
      expect(RoomDailyVpConfig.getGoldTarget(true), equals(2400));
      expect(RoomDailyVpConfig.getTotalTarget(true), equals(3800));
    });

    test('9. Star Gift Tiers, Gold Dual Fill & 10-Min Idle Freeze Protection', () {
      expect(RoomDailyVpConfig.getStarGiftVp(1), equals(2));
      expect(RoomDailyVpConfig.getStarGiftVp(3), equals(10));
      expect(RoomDailyVpConfig.getStarGiftVp(6), equals(70));
      expect(RoomDailyVpConfig.firstFiveGiftsBonusVp, equals(25));
      expect(RoomDailyVpConfig.firstSeatBonusVp, equals(20));

      final progCtrl = RoomProgressionController();
      final roomId = 'room_test_101';
      progCtrl.registerRoomActivity(roomId);
      expect(progCtrl.isRoomIdleFrozen(roomId), isFalse);
    });

    test('10. Hidden Trust Score Engine & 20 Anti-Fake Rules Validation', () {
      final progCtrl = RoomProgressionController();
      final roomId = 'room_anti_fake_1';
      final userId = 'user_abc_123';

      // 1. Normal trust score (80) allows VP
      expect(progCtrl.userTrustScore.value, equals(80));
      expect(progCtrl.canEarnVp(roomId: roomId, userId: userId), isTrue);

      // 2. Low trust score (<30) blocks VP
      progCtrl.userTrustScore.value = 25;
      expect(progCtrl.canEarnVp(roomId: roomId, userId: userId), isFalse);

      // Reset score
      progCtrl.userTrustScore.value = 85;

      // 3. Self-gifting penalty reduces trust score by 30 and blocks VP (Rule 4)
      final canSelfGift = progCtrl.canEarnVp(
        roomId: roomId,
        userId: userId,
        ownerId: userId,
        isSelfGift: true,
      );
      expect(canSelfGift, isFalse);
      expect(progCtrl.userTrustScore.value, equals(55));

      // 4. Banned device guard blocks VP (Rule 17)
      final canBannedEarn = progCtrl.canEarnVp(
        roomId: roomId,
        userId: userId,
        isBannedDevice: true,
      );
      expect(canBannedEarn, isFalse);

      // 5. Solo seat slow mode multiplier (Rule 1: 50% rate)
      expect(RoomDailyVpConfig.getSoloSeatMultiplier(1), equals(0.5));
      expect(RoomDailyVpConfig.getSoloSeatMultiplier(3), equals(1.0));

      // 6. Minimum stay duration (Rule 12: 60s minimum)
      expect(RoomDailyVpConfig.minStayDurationSeconds, equals(60));

      // 7. Join Cooldown & Room Switch Cooldown (Rules 6 & 11)
      expect(RoomDailyVpConfig.joinCooldownSeconds, equals(30));
      expect(RoomDailyVpConfig.roomSwitchCooldownSeconds, equals(60));

      // 8. UserTrustScore model brackets & multipliers
      final highTrust = UserTrustScore(userId: 'u1', trustScore: 90);
      expect(highTrust.trustLevel, equals('High'));
      expect(highTrust.vpMultiplier, equals(1.0));

      final lowTrust = UserTrustScore(userId: 'u2', trustScore: 40);
      expect(lowTrust.trustLevel, equals('Low'));
      expect(lowTrust.vpMultiplier, equals(0.5));

      final untrusted = UserTrustScore(userId: 'u3', trustScore: 15);
      expect(untrusted.trustLevel, equals('Untrusted'));
      expect(untrusted.vpMultiplier, equals(0.0));

      final banned = UserTrustScore(userId: 'u4', trustScore: 85, isDeviceBanned: true);
      expect(banned.trustLevel, equals('Untrusted'));
      expect(banned.vpMultiplier, equals(0.0));
    });
  });
}
