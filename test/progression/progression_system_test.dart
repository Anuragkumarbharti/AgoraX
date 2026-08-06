import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:creania/models/progression/progression_models.dart';
import 'package:creania/services/progression/progression_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Progression Model Parsing Tests', () {
    test('UserProgressModel parsing test', () {
      final json = {
        'id': 'test-uuid-123',
        'level': 5,
        'xp': 150,
        'total_xp': 2340,
        'today_earned_xp': 80,
        'today_bonus_xp': 20,
        'weekly_xp': 450,
        'monthly_xp': 1800,
        'last_xp_update': '2026-07-17T13:48:16.000Z',
      };

      final model = UserProgressModel.fromJson(json);

      expect(model.id, 'test-uuid-123');
      expect(model.level, 5);
      expect(model.xp, 150);
      expect(model.totalXp, 2340);
      expect(model.todayEarnedXp, 80);
      expect(model.todayBonusXp, 20);
      expect(model.weeklyXp, 450);
      expect(model.monthlyXp, 1800);
      expect(model.lastXpUpdate, isNotNull);
      expect(model.lastXpUpdate!.year, 2026);
    });

    test('TaskModel & TaskRewardModel parsing test', () {
      final json = {
        'task_id': 'daily_login',
        'type': 'daily',
        'title': 'Daily Sign In',
        'description': 'Sign in to earn rewards',
        'required_action': 'daily_login',
        'required_count': 1,
        'priority': 10,
        'current_count': 1,
        'is_completed': true,
        'is_claimed': false,
        'rewards': [
          {'reward_type': 'xp', 'amount': 50},
          {'reward_type': 'silver', 'amount': 100, 'cosmetic_id': 'extra_boost'}
        ]
      };

      final model = TaskModel.fromJson(json);

      expect(model.taskId, 'daily_login');
      expect(model.type, 'daily');
      expect(model.title, 'Daily Sign In');
      expect(model.description, 'Sign in to earn rewards');
      expect(model.requiredCount, 1);
      expect(model.currentCount, 1);
      expect(model.isCompleted, true);
      expect(model.isClaimed, false);
      expect(model.rewards.length, 2);
      expect(model.rewards[0].rewardType, 'xp');
      expect(model.rewards[0].amount, 50);
      expect(model.rewards[1].rewardType, 'silver');
      expect(model.rewards[1].amount, 100);
      expect(model.rewards[1].cosmeticId, 'extra_boost');
    });

    test('CheckinStatusModel parsing test', () {
      final json = {
        'month_key': '2026-07',
        'claimed_days': [1, 2, 3],
        'can_claim_today': true,
        'next_day_to_claim': 4,
        'streak_count': 3,
        'week_start': 1,
        'week_end': 7,
      };

      final model = CheckinStatusModel.fromJson(json);

      expect(model.monthKey, '2026-07');
      expect(model.claimedDays, equals([1, 2, 3]));
      expect(model.canClaimToday, true);
      expect(model.nextDayToClaim, 4);
      expect(model.streakCount, 3);
      expect(model.weekStart, 1);
      expect(model.weekEnd, 7);
    });

    test('SpinResultModel parsing test', () {
      final json = {
        'success': true,
        'won_reward_type': 'silver',
        'won_amount': 200,
        'won_cosmetic_id': null,
      };

      final model = SpinResultModel.fromJson(json);

      expect(model.success, true);
      expect(model.wonRewardType, 'silver');
      expect(model.wonAmount, 200);
      expect(model.wonCosmeticId, isNull);
    });

    test('LoyaltyStatusModel parsing test', () {
      final json = {
        'total_active_days': 120,
        'milestones': [
          {
            'required_days': 100,
            'reward_type': 'badge',
            'amount': 1,
            'cosmetic_id': 'Veteran Badge',
            'is_claimed': true,
          },
          {
            'required_days': 200,
            'reward_type': 'badge',
            'amount': 1,
            'cosmetic_id': 'Elite Explorer Badge',
            'is_claimed': false,
          }
        ]
      };

      final model = LoyaltyStatusModel.fromJson(json);

      expect(model.totalActiveDays, 120);
      expect(model.milestones.length, 2);
      expect(model.milestones[0].requiredDays, 100);
      expect(model.milestones[0].rewardType, 'badge');
      expect(model.milestones[0].isClaimed, true);
      expect(model.milestones[1].requiredDays, 200);
      expect(model.milestones[1].isClaimed, false);
    });
  });

  group('Progression Controller Logic Tests', () {
    late ProgressionController controller;

    setUp(() {
      Get.reset();
      controller = Get.put(ProgressionController());
    });

    test('getXpProgress returns correct percentages', () {
      // Mock requirements mapping
      controller.levelRequirements.addAll({
        1: 0,
        2: 100,
        3: 109,
        4: 118,
        5: 129,
        6: 141,
      });

      // User at level 5 with 64.5 XP (exactly 50% of the 129 XP required for level 6)
      controller.userProgress.value = UserProgressModel(
        id: 'test-user',
        level: 5,
        xp: 64, // (64 / 141) = ~0.45
        totalXp: 1000,
        todayEarnedXp: 50,
        todayBonusXp: 10,
        weeklyXp: 100,
        monthlyXp: 400,
      );

      final progress = controller.getXpProgress();
      expect(progress, closeTo(0.45, 0.01));
    });

    test('getIdTitleForLevel returns appropriate titles for levels', () {
      expect(controller.getIdTitleForLevel(1), '🌱 Newcomer');
      expect(controller.getIdTitleForLevel(5), '🌱 Newcomer');
      expect(controller.getIdTitleForLevel(10), '🚀 Explorer');
      expect(controller.getIdTitleForLevel(20), '📘 Pathfinder');
      expect(controller.getIdTitleForLevel(35), '⭐ Trailblazer');
      expect(controller.getIdTitleForLevel(48), '🔥 Rising Star');
      expect(controller.getIdTitleForLevel(60), '👑 Legendary');
    });
  });
}
