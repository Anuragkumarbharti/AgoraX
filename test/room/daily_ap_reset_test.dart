import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/progression/room_dual_progress_model.dart';

void main() {
  group('Room Dual Progress Automatic Daily AP Reset Tests', () {
    test('Stale day record from yesterday automatically resets Today AP to 0', () {
      final jsonFromYesterday = {
        'room_id': 'CRN-ROOM-101',
        'daily_free_progress': 1400,
        'free_task_limit': 1400,
        'daily_gold_progress': 2000,
        'gold_task_limit': 2000,
        'total_task': 3400,
        'total_task_target': 35500,
        'total_lifetime_task': 100000,
        'last_reset_date': '2026-08-10', // Yesterday
        'room_level': 1,
      };

      final model = RoomDualProgress.fromJson(jsonFromYesterday);

      // Verify Today AP progress reset to 0
      expect(model.dailyFreeProgress, equals(0));
      expect(model.dailyGoldProgress, equals(0));
      expect(model.totalDailyPoints, equals(0));
      expect(model.totalPoints, equals(0));
    });

    test('Current day record preserves active Today AP progress', () {
      final todayStr = RoomDualProgress.currentResetDateString;
      final jsonFromToday = {
        'room_id': 'CRN-ROOM-101',
        'daily_free_progress': 500,
        'free_task_limit': 700,
        'daily_gold_progress': 300,
        'gold_task_limit': 1000,
        'total_task': 800,
        'total_task_target': 35500,
        'total_lifetime_task': 100000,
        'last_reset_date': todayStr,
        'room_level': 1,
      };

      final model = RoomDualProgress.fromJson(jsonFromToday);

      expect(model.dailyFreeProgress, equals(500));
      expect(model.dailyGoldProgress, equals(300));
      expect(model.totalDailyPoints, equals(800));
    });
  });
}
