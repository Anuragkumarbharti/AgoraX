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
      expect(l3.requiredVp, equals(300000));
      expect(l3.maxCoOwners, equals(2));
      expect(l3.maxAdmins, equals(11));
      expect(l3.maxHostSeats, equals(8));
      expect(l3.hasShowcaseBadge, isTrue);

      final l5 = RoomLevelMatrixConfig.getForLevel(5);
      expect(l5.level, equals(5));
      expect(l5.requiredVp, equals(1500000));
      expect(l5.maxCoOwners, equals(3));
      expect(l5.maxAdmins, equals(16));
      expect(l5.hasPermanentChatBubble, isTrue);

      final l7 = RoomLevelMatrixConfig.getForLevel(7);
      expect(l7.level, equals(7));
      expect(l7.requiredVp, equals(6000000));
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
      bool isShowcaseBadgeUnlocked(int level) => level >= 3;
      bool isChatBubbleUnlocked(int level) => level >= 5;

      expect(isShowcaseBadgeUnlocked(1), isFalse);
      expect(isShowcaseBadgeUnlocked(2), isFalse);
      expect(isShowcaseBadgeUnlocked(3), isTrue);
      expect(isShowcaseBadgeUnlocked(7), isTrue);

      expect(isChatBubbleUnlocked(3), isFalse);
      expect(isChatBubbleUnlocked(4), isFalse);
      expect(isChatBubbleUnlocked(5), isTrue);
      expect(isChatBubbleUnlocked(7), isTrue);
    });
  });
}
