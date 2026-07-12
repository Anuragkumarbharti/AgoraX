import 'package:flutter_test/flutter_test.dart';
import 'package:creania/services/career_progression_controller.dart';
import 'package:creania/models/task_progress_model.dart';

void main() {
  group('Daily Task System - Level Progression & Math Tests', () {
    late CareerProgressionController controller;

    setUp(() {
      controller = CareerProgressionController();
    });

    test('Cubic XP Progression Formula matches 4.5 years scaling boundary (~2.95M XP for Level 60)', () {
      // CumulativeXP(lvl) = 10 * (lvl - 1)^3 + 250 * (lvl - 1)^2 + 500 * (lvl - 1)
      int xpForLevel60 = controller.xpRequiredForIdLevel(60);
      expect(xpForLevel60, equals(2953540)); // 2.95 Million XP

      // Assuming average daily task completion yields 1800 XP:
      double daysToMaxLevel = xpForLevel60 / 1800.0;
      double yearsToMaxLevel = daysToMaxLevel / 365.0;

      expect(yearsToMaxLevel, greaterThanOrEqualTo(4.0));
      expect(yearsToMaxLevel, lessThanOrEqualTo(5.0));
      print('Mathematical Verification: Cumulative XP to Level 60: $xpForLevel60 XP');
      print('Mathematical Verification: Time to reach Level 60: ${yearsToMaxLevel.toStringAsFixed(2)} years');
    });

    test('Progression requirements increase non-linearly with levels', () {
      // Level 2 requires: 10*1^3 + 250*1^2 + 500*1 = 760 XP
      expect(controller.xpRequiredForIdLevel(2), equals(760));

      // Level 3 requires: 10*8 + 250*4 + 1000 = 80 + 1000 + 1000 = 2080 XP
      expect(controller.xpRequiredForIdLevel(3), equals(2080));

      // Level 10 requires: 10*729 + 250*81 + 4500 = 7290 + 20250 + 4500 = 32040 XP
      expect(controller.xpRequiredForIdLevel(10), equals(32040));
    });

    test('TaskProgress model correctly parses dynamic Supabase JSON responses', () {
      final jsonPayload = {
        'id': 'progress_uuid_101',
        'user_id': 'user_uuid_909',
        'task_id': 'task_uuid_808',
        'task_type': 'career',
        'progress': 1,
        'required_progress': 2,
        'completed': false,
        'claimed': false,
        'completed_at': null,
        'claimed_at': null,
        'date': '2026-07-12',
        'task_code': 'complete_quiz',
        'title': 'Complete Daily Quiz',
        'description': 'Test your knowledge on daily topics.',
        'icon': 'quiz',
        'category': 'Study',
        'verification_type': 'quiz_score',
        'xp': 200,
        'silver_coin': 150,
        'bonus_reward': {'badge_id': 'quiz_badge_gold'}
      };

      final task = TaskProgress.fromJson(jsonPayload);

      expect(task.id, equals('progress_uuid_101'));
      expect(task.taskType, equals('career'));
      expect(task.progress, equals(1));
      expect(task.requiredProgress, equals(2));
      expect(task.completed, isFalse);
      expect(task.claimed, isFalse);
      expect(task.taskCode, equals('complete_quiz'));
      expect(task.title, equals('Complete Daily Quiz'));
      expect(task.xp, equals(200));
      expect(task.silverCoin, equals(150));
      expect(task.bonusReward['badge_id'], equals('quiz_badge_gold'));
    });
  });
}
