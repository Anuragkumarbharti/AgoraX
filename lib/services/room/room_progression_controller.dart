import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/progression/room_progression_models.dart';
import '../user/user_profile_cache_manager.dart';
import '../progression/progression_controller.dart';

class RoomProgressionController extends GetxController {
  static RoomProgressionController get to => Get.find<RoomProgressionController>();

  final RxMap<String, RoomLevelProgress> roomLevelProgresses =
      <String, RoomLevelProgress>{}.obs;
  final RxMap<String, RoomStatistics> roomStats =
      <String, RoomStatistics>{}.obs;
  final RxMap<String, List<RoomDailyTask>> roomDailyTaskLists =
      <String, List<RoomDailyTask>>{}.obs;
  final RxList<String> marqueeAnnouncementsQueue = <String>[].obs;

  Timer? _progressionTimer;
  int _minutesInRoom = 0;

  int calculateActiveStageVpRate(int occupantCount) {
    if (occupantCount <= 0) return 0;
    switch (occupantCount) {
      case 1:
        return 4;
      case 2:
        return 8;
      case 3:
        return 14;
      case 4:
        return 20;
      case 5:
        return 28;
      case 6:
        return 36;
      case 7:
        return 44;
      case 8:
        return 50;
      case 9:
        return 55;
      case 10:
      default:
        return 60;
    }
  }

  int getXpForNextLevel(int level) {
    return level * 1000;
  }

  int getRoomFreeVp(String roomId) {
    final _ = roomDailyTaskLists.length;
    final tasks = roomDailyTaskLists[roomId];
    if (tasks == null || tasks.isEmpty) return 700;
    final freeTasks = tasks.where((t) => !t.taskKey.contains('gold'));
    if (freeTasks.isEmpty) return 700;
    return freeTasks.fold(0, (sum, t) => sum + t.currentValue).clamp(0, 700);
  }

  int getRoomGoldVp(String roomId) {
    final _ = roomDailyTaskLists.length;
    final tasks = roomDailyTaskLists[roomId];
    if (tasks == null || tasks.isEmpty) return 1000;
    final goldTasks = tasks.where((t) => t.taskKey.contains('gold'));
    if (goldTasks.isEmpty) return 1000;
    return goldTasks.fold(0, (sum, t) => sum + t.currentValue).clamp(0, 1000);
  }

  void startProgressionTimer(
    String roomId, {
    required String? activeRoomId,
    required List<Map<String, dynamic>>? seats,
  }) {
    _progressionTimer?.cancel();
    _minutesInRoom = 0;
    _progressionTimer =
        Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (activeRoomId != roomId) {
        timer.cancel();
        return;
      }

      final currentUserId = UserProfileCacheManager.currentUserId;
      bool isSitting = false;
      if (seats != null) {
        isSitting = seats.any((s) => s['userId'] == currentUserId);
      }

      try {
        final progCtrl = Get.put(ProgressionController());
        if (isSitting) {
          await progCtrl.triggerXpEvent('room_hosted_minute');
        } else {
          await progCtrl.triggerXpEvent('room_joined_minute');
        }
      } catch (e) {
        debugPrint('RoomProgressionController progression timer error: $e');
      }

      _minutesInRoom++;
    });
  }

  void stopProgressionTimer() {
    _progressionTimer?.cancel();
    _progressionTimer = null;
  }

  Future<void> fetchRoomProgression(
    String roomId, {
    required Function(Map<String, List<Map<String, dynamic>>>) onUpdateSeats,
    required Function(Map<String, int>) onUpdateSeatGifts,
  }) async {
    try {
      final client = Supabase.instance.client;

      final results = await Future.wait<dynamic>([
        client.from('room_level_progress').select().eq('room_id', roomId).maybeSingle(),
        client.from('room_statistics').select().eq('room_id', roomId).maybeSingle(),
        client.from('room_daily_tasks').select(),
        client.from('room_daily_task_progress').select().eq('room_id', roomId),
        client.from('room_seats').select().eq('room_id', roomId).order('seat_index', ascending: true),
        client.from('room_seat_gifts').select().eq('room_id', roomId),
      ]);

      final progressResp = results[0];
      if (progressResp != null) {
        roomLevelProgresses[roomId] = RoomLevelProgress.fromJson(progressResp as Map<String, dynamic>);
      }

      final statsResp = results[1];
      if (statsResp != null) {
        roomStats[roomId] = RoomStatistics.fromJson(statsResp as Map<String, dynamic>);
      }

      final tasksResp = results[2] as List;
      final progressListResp = results[3] as List;

      final progressMap = {
        for (var p in progressListResp) p['task_key'] as String: p
      };

      final List<RoomDailyTask> mergedTasks = (tasksResp).map((t) {
        final key = t['task_key'] as String;
        final prog = progressMap[key];
        return RoomDailyTask(
          taskKey: key,
          description: t['description'] ?? '',
          targetValue: t['target_value'] ?? 0,
          currentValue: prog != null ? (prog['current_value'] ?? 0) : 0,
          taskPoints: t['task_points'] ?? 0,
          xpReward: t['xp_reward'] ?? 0,
          silverReward: t['silver_reward'] ?? 0,
          goldReward: t['gold_reward'] ?? 0,
          isCompleted: prog != null ? (prog['is_completed'] ?? false) : false,
        );
      }).toList();

      roomDailyTaskLists[roomId] = mergedTasks;

      final seatsResp = results[4] as List;
      final giftsResp = results[5] as List;

      final giftMap = {
        for (var g in giftsResp)
          g['seat_index'] as int: g['silver_gift_count'] as int
      };

      final Set<String> userIdsToFetch = {};
      for (var s in seatsResp) {
        final uId = s['user_id'] as String?;
        if (uId != null && uId.isNotEmpty) {
          if (UserProfileCacheManager.getCachedUser(uId) == null) {
            userIdsToFetch.add(uId);
          }
        }
      }

      if (userIdsToFetch.isNotEmpty) {
        await Future.wait(
          userIdsToFetch.map((id) => UserProfileCacheManager.fetchUserProfile(id)),
        );
      }

      final List<Map<String, dynamic>> seatsList = [];
      final Map<String, int> giftsCounters = {};

      for (var s in seatsResp) {
        final seatIdx = s['seat_index'] as int;
        final uId = s['user_id'] as String?;
        final profile = uId != null ? UserProfileCacheManager.getCachedUser(uId) : null;
        final count = giftMap[seatIdx] ?? 0;

        seatsList.add({
          'seatIndex': seatIdx,
          'userId': uId,
          'name': profile?.username ?? (uId != null ? 'Member' : 'Seat ${seatIdx + 1}'),
          'avatar': profile?.avatar,
          'level': profile?.level ?? 1,
          'vipLevel': profile?.vipLevel ?? 0,
          'nobleLevel': profile?.novelLevel ?? 0,
          'isMuted': s['is_muted'] ?? false,
          'isLocked': s['is_locked'] ?? false,
          'isSpeaking': false,
        });

        giftsCounters['$roomId:$seatIdx'] = count;
      }

      onUpdateSeats({roomId: seatsList});
      onUpdateSeatGifts(giftsCounters);
    } catch (e) {
      debugPrint('Error fetching room progression: $e');
    }
  }
}
