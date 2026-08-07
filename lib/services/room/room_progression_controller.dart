import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/progression/room_progression_models.dart';
import '../user/user_profile_cache_manager.dart';
import '../progression/progression_controller.dart';
import 'room_seat_controller.dart';
import 'room_dual_progress_controller.dart';

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

  bool get isWeekend {
    final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    return now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
  }

  int get maxFreeDailyVp => isWeekend ? 1400 : 700;
  int get maxGoldDailyVp => isWeekend ? 2400 : 1000;
  int get maxTotalDailyVp => maxFreeDailyVp + maxGoldDailyVp;

  final RxInt userTrustScore = 80.obs;
  final RxMap<String, DateTime> _lastActivityTime = <String, DateTime>{}.obs;
  final RxMap<String, DateTime> _lastRoomJoinTimes = <String, DateTime>{}.obs;
  final RxMap<String, DateTime> _lastSeatChangeTimes = <String, DateTime>{}.obs;
  final RxSet<String> _firstSeatBonusAwardedUsers = <String>{}.obs;

  void registerRoomActivity(String roomId) {
    _lastActivityTime[roomId] = DateTime.now();
  }

  void registerRoomJoin(String roomId) {
    _lastRoomJoinTimes[roomId] = DateTime.now();
    registerRoomActivity(roomId);
  }

  void registerSeatChange(String roomId) {
    _lastSeatChangeTimes[roomId] = DateTime.now();
    registerRoomActivity(roomId);
  }

  bool isRoomIdleFrozen(String roomId) {
    final lastAct = _lastActivityTime[roomId];
    if (lastAct == null) return false;
    return DateTime.now().difference(lastAct) > const Duration(minutes: 10);
  }

  bool isRoomSwitchCooldown(String roomId) {
    final lastJoin = _lastRoomJoinTimes[roomId];
    if (lastJoin == null) return false;
    return DateTime.now().difference(lastJoin) < const Duration(seconds: 60);
  }

  bool isJoinLeaveSpamCooldown(String roomId) {
    final lastJoin = _lastRoomJoinTimes[roomId];
    if (lastJoin == null) return false;
    return DateTime.now().difference(lastJoin) < const Duration(seconds: 30);
  }

  bool awardFirstSeatBonus(String userId) {
    if (_firstSeatBonusAwardedUsers.contains(userId)) return false;
    _firstSeatBonusAwardedUsers.add(userId);
    return true;
  }

  bool canEarnVp({
    required String roomId,
    required String userId,
    String? ownerId,
    String? deviceFingerprint,
    bool isSelfGift = false,
    bool isBannedDevice = false,
  }) {
    // Rule 17: Banned Device Guard
    if (isBannedDevice) return false;

    // Rule 20 & Hidden Trust Score Engine Guard (<30 Trust Score = 0 VP)
    if (userTrustScore.value < 30) return false;

    // Rule 2: 10-Minute Idle Freeze Guard
    if (isRoomIdleFrozen(roomId)) return false;

    // Rule 3 & 4: Self-Gifting / Same Account Protection
    if (isSelfGift || (ownerId != null && ownerId == userId && isSelfGift)) {
      userTrustScore.value = (userTrustScore.value - 30).clamp(0, 100);
      return false;
    }

    // Rule 11: Room Switch Cooldown (60s)
    if (isRoomSwitchCooldown(roomId)) return false;

    return true;
  }

  int getXpForNextLevel(int level) {
    return level * 1000;
  }

  int getRoomFreeVp(String roomId) {
    final _ = roomDailyTaskLists.length;
    final maxLimit = maxFreeDailyVp;
    final tasks = roomDailyTaskLists[roomId];
    if (tasks == null || tasks.isEmpty) return 0;
    final freeTasks = tasks.where((t) => !t.taskKey.contains('gold'));
    if (freeTasks.isEmpty) return 0;
    return freeTasks.fold(0, (sum, t) => sum + t.currentValue).clamp(0, maxLimit);
  }

  int getRoomGoldVp(String roomId) {
    final _ = roomDailyTaskLists.length;
    final maxLimit = maxGoldDailyVp;
    final tasks = roomDailyTaskLists[roomId];
    if (tasks == null || tasks.isEmpty) return 0;
    final goldTasks = tasks.where((t) => t.taskKey.contains('gold'));
    if (goldTasks.isEmpty) return 0;
    return goldTasks.fold(0, (sum, t) => sum + t.currentValue).clamp(0, maxLimit);
  }

  double calculateActiveMemberSurgeMultiplier(int activeMemberCount) {
    if (activeMemberCount < 5) return 1.0;
    if (activeMemberCount < 8) return 1.5;
    if (activeMemberCount < 10) return 2.0;
    if (activeMemberCount < 15) return 2.5;
    if (activeMemberCount < 20) return 3.5;
    return 4.0;
  }

  Future<Map<String, dynamic>> addRoomVp(String roomId, int vpAmount, String source, {bool isGoldMember = false}) async {
    try {
      final currentFree = getRoomFreeVp(roomId);
      final currentGold = getRoomGoldVp(roomId);
      final currentDailyTotal = currentFree + currentGold;
      final dailyMax = maxTotalDailyVp;

      // Capping check: If daily limit reached, grant 0 VP
      if (currentDailyTotal >= dailyMax) {
        return {
          'success': false,
          'reason': 'Daily limit reached (Reset at 04:00 AM IST)',
          'added_vp': 0,
        };
      }

      // Clamp VP addition to remaining daily allowance
      final int allowedVp = vpAmount.clamp(0, dailyMax - currentDailyTotal);
      if (allowedVp <= 0) {
        return {'success': false, 'reason': 'Daily limit capped', 'added_vp': 0};
      }

      final client = Supabase.instance.client;
      final resp = await client.rpc('add_room_vp', params: {
        'p_room_id': roomId,
        'p_vp': allowedVp,
        'p_source': source,
      });

      if (resp != null && resp['success'] == true) {
        final newTotalVp = resp['new_total_vp'] as int? ?? 0;
        final newLevel = resp['new_level'] as int? ?? 1;

        roomLevelProgresses[roomId] = RoomLevelProgress(
          roomId: roomId,
          currentLevel: newLevel,
          currentXp: newTotalVp,
          consecutiveDaysCompleted: roomLevelProgresses[roomId]?.consecutiveDaysCompleted ?? 0,
        );
      }
      return Map<String, dynamic>.from(resp as Map);
    } catch (e) {
      debugPrint('Error adding room VP: $e');
      return {'success': false, 'reason': e.toString()};
    }
  }

  Future<Map<String, dynamic>> validateAndAddRoomVp({
    required String roomId,
    required String userId,
    required int vpAmount,
    required String source,
    int staySeconds = 60,
    String? targetUserId,
    String? deviceFingerprint,
    bool isEmulator = false,
    bool isVpn = false,
  }) async {
    try {
      final client = Supabase.instance.client;
      final resp = await client.rpc('validate_and_add_room_vp', params: {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_vp': vpAmount,
        'p_source': source,
        'p_stay_seconds': staySeconds,
        'p_target_user_id': targetUserId,
        'p_device_fingerprint': deviceFingerprint,
        'p_is_emulator': isEmulator,
        'p_is_vpn': isVpn,
      });

      if (resp != null && resp['success'] == true) {
        final addedVp = resp['added_vp'] as int? ?? 0;
        final trustScore = resp['trust_score'] as int? ?? 80;
        userTrustScore.value = trustScore;

        if (resp['new_level'] != null) {
          final newTotalVp = resp['new_total_vp'] as int? ?? 0;
          final newLevel = resp['new_level'] as int? ?? 1;
          roomLevelProgresses[roomId] = RoomLevelProgress(
            roomId: roomId,
            currentLevel: newLevel,
            currentXp: newTotalVp,
            consecutiveDaysCompleted: roomLevelProgresses[roomId]?.consecutiveDaysCompleted ?? 0,
          );
        }
      }
      return Map<String, dynamic>.from(resp as Map);
    } catch (e) {
      debugPrint('Error validating and adding room VP: $e');
      return {'success': false, 'reason': e.toString(), 'added_vp': 0};
    }
  }

  Future<Map<String, dynamic>> claimTreasureBox(String boxTier) async {
    try {
      final client = Supabase.instance.client;
      final resp = await client.rpc('claim_treasure_box_reward', params: {
        'p_box_tier': boxTier,
      });
      return Map<String, dynamic>.from(resp as Map);
    } catch (e) {
      debugPrint('Error claiming treasure box: $e');
      return {'success': false, 'reason': e.toString()};
    }
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
        final isFrozen = isRoomIdleFrozen(roomId);

        int activeSeatedUsersCount = 0;
        if (seats != null) {
          activeSeatedUsersCount = seats.where((s) => s['userId'] != null && s['userId'].toString().isNotEmpty).length;
        }

        if (!isFrozen && activeSeatedUsersCount > 0) {
          // Rule 3: Active Seat Time Reward: 4 AP/min per active seated user
          if (Get.isRegistered<RoomDualProgressController>()) {
            await RoomDualProgressController.to.processActiveSeatTime(roomId, activeSeatedUsersCount);
          }
        }

        if (isSitting) {
          await progCtrl.triggerXpEvent('room_hosted_minute');
          await addRoomVp(roomId, 8, 'active_mic_time');
        } else {
          await progCtrl.triggerXpEvent('room_joined_minute');
          await addRoomVp(roomId, 5, 'user_stay_time');
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
      // Synchronize StarMaker Dual Progress System
      final dualCtrl = Get.put(RoomDualProgressController());
      await dualCtrl.fetchDualProgress(roomId);
      dualCtrl.subscribeToRealtimeDualProgress(roomId);

      final client = Supabase.instance.client;
      final todayDateStr = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 5, minutes: 30))
          .subtract(const Duration(hours: 4))
          .toIso8601String()
          .split('T')[0];

      final results = await Future.wait<dynamic>([
        client.from('room_level_progress').select().eq('room_id', roomId).maybeSingle(),
        client.from('room_statistics').select().eq('room_id', roomId).maybeSingle(),
        client.from('room_daily_task_catalog').select(),
        client.from('user_daily_task_progress').select().eq('task_date', todayDateStr),
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

      final catalogResp = results[2] as List;
      final userProgressResp = results[3] as List;

      final userProgMap = {
        for (var p in userProgressResp) p['task_key'] as String: p
      };

      final List<RoomDailyTask> mergedTasks = (catalogResp).map((t) {
        final key = t['task_key'] as String;
        final prog = userProgMap[key];
        return RoomDailyTask(
          taskKey: key,
          title: t['title'] ?? '',
          description: t['description'] ?? '',
          category: t['category'] ?? 'normal',
          targetValue: t['target_value'] ?? 1,
          currentValue: prog != null ? (prog['current_value'] ?? 0) : 0,
          minActiveMembers: t['min_active_members'] ?? 1,
          taskPoints: t['vp_reward'] ?? 50,
          xpReward: t['vp_reward'] ?? 50,
          coinReward: t['coin_reward'] ?? 0,
          silverReward: t['silver_reward'] ?? 0,
          goldReward: 0,
          treasureBoxTier: t['treasure_box_tier'] ?? 'normal',
          iconName: t['icon_name'] ?? 'task',
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
          'name': profile?.username ?? (uId != null ? 'Member' : RoomSeatController.getSeatName(seatIdx)),
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

