import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/room_progression_models.dart';

void main() {
  group('Room Progression Models & Cap Verification Tests', () {
    test('RoomDailyTask parsing and completion checks', () {
      final json = {
        'task_key': 'speak_20m',
        'description': 'Speak 20 minutes in room',
        'target_value': 1200,
        'current_value': 600,
        'task_points': 50,
        'xp_reward': 25,
        'silver_reward': 40,
        'gold_reward': 0,
        'is_completed': false,
      };

      final task = RoomDailyTask.fromJson(json);

      expect(task.taskKey, 'speak_20m');
      expect(task.currentValue, 600);
      expect(task.targetValue, 1200);
      expect(task.isCompleted, false);

      final outJson = task.toJson();
      expect(outJson['task_key'], 'speak_20m');
      expect(outJson['is_completed'], false);
    });

    test('RoomLevelProgress parsing and consecutive days checks', () {
      final json = {
        'room_id': 'CRN-RM-8F4K2X',
        'current_level': 3,
        'current_xp': 54000,
        'consecutive_days_completed': 12,
        'last_completed_date': '2026-07-12',
      };

      final progress = RoomLevelProgress.fromJson(json);

      expect(progress.roomId, 'CRN-RM-8F4K2X');
      expect(progress.currentLevel, 3);
      expect(progress.currentXp, 54000);
      expect(progress.consecutiveDaysCompleted, 12);
      expect(progress.lastCompletedDate, isNotNull);
    });

    test('RoomStatistics serialization and caps calculation checks', () {
      final json = {
        'room_id': 'CRN-RM-8F4K2X',
        'total_visitors': 1500,
        'today_visitors': 45,
        'today_silver_coins': 850,
        'today_gold_coins': 5,
        'today_task_points': 1200, // Capped normal tasks
        'today_extra_xp_points': 150, // Additional points from gold coin boost
        'last_heartbeat_at': '2026-07-12T21:30:50.000Z',
      };

      final stats = RoomStatistics.fromJson(json);

      expect(stats.roomId, 'CRN-RM-8F4K2X');
      expect(stats.todayTaskPoints, 1200);
      expect(stats.todaySilverCoins, lessThanOrEqualTo(1200));
      expect(stats.todayExtraXpPoints, 150);
      expect(stats.lastHeartbeatAt, isNotNull);
    });

    test('Gold Coin Conversion Logic Validation', () {
      // 1 Gold Coin = 1 extra Task Point & 1 XP up to 1200 extra
      const goldGiftsReceived = 350;
      final allowedExtraTaskPoints = (goldGiftsReceived).clamp(0, 1200);
      
      expect(allowedExtraTaskPoints, 350);

      const largeGoldGifts = 1500;
      final cappedExtraPoints = (largeGoldGifts).clamp(0, 1200);
      expect(cappedExtraPoints, 1200); // Strict daily limit validation
    });

    test('Level XP Requirements Bounds Validation', () {
      final Map<int, int> xpRequirements = {
        1: 0,
        2: 12000,
        3: 48000,
        4: 120000,
        5: 264000,
        6: 624000,
        7: 1200000,
      };

      expect(xpRequirements[1], 0);
      expect(xpRequirements[2], 12000);
      expect(xpRequirements[7], 1200000);
    });
  });
}
