import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/progression/progression_models.dart';
import '../user/user_profile_cache_manager.dart';
import '../user/user_progress_sync_service.dart';
import '../storage/fcm_notification_service.dart';

class ProgressionController extends GetxController {
  static String get currentUserId {
    try {
      final _ = Supabase.instance;
      return UserProfileCacheManager.currentUserId;
    } catch (_) {
      return '';
    }
  }

  // State Observables
  final Rxn<UserProgressModel> userProgress = Rxn<UserProgressModel>();
  final RxList<TaskModel> tasks = <TaskModel>[].obs;
  final Rxn<CheckinStatusModel> checkinStatus = Rxn<CheckinStatusModel>();
  final RxList<SpinRewardModel> spinRewards = <SpinRewardModel>[].obs;
  final RxList<AchievementModel> achievements = <AchievementModel>[].obs;
  final Rxn<LoyaltyStatusModel> loyaltyStatus = Rxn<LoyaltyStatusModel>();

  // Helper level requirements map (level -> xp_required)
  final RxMap<int, int> levelRequirements = <int, int>{}.obs;

  final RxBool isLoading = false.obs;
  final RxBool isSpinning = false.obs;
  final Rxn<SpinResultModel> wonReward = Rxn<SpinResultModel>();
  final RxBool isAdmin = false.obs;
  final RxInt dailyAdCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  // Refresh everything from backend
  Future<void> refreshAll() async {
    if (currentUserId.isEmpty) return;
    isLoading.value = true;
    try {
      // Auto-trigger daily login task completion on app open
      triggerXpEvent('daily_login');

      await Future.wait([
        fetchLevelRequirements(),
        fetchUserProgress(),
        fetchTasks(),
        fetchCheckinStatus(),
        fetchAchievements(),
        fetchLoyaltyStatus(),
        fetchSpinRewards(),
        fetchAdminStatus(),
      ]);
    } catch (e) {
      debugPrint('ProgressionController Error refreshAll: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchAdminStatus() async {
    try {
      final response = await Supabase.instance.client
          .from('admins')
          .select('role')
          .eq('id', currentUserId)
          .maybeSingle();
      isAdmin.value = response != null;
    } catch (e) {
      isAdmin.value = false;
    }
  }

  // Fetch XP required per level
  Future<void> fetchLevelRequirements() async {
    try {
      final response = await Supabase.instance.client
          .from('level_requirements')
          .select('level, xp_required');
      if (response != null) {
        final Map<int, int> reqs = {};
        for (var row in response) {
          reqs[row['level'] as int] = row['xp_required'] as int;
        }
        levelRequirements.value = reqs;
      }
    } catch (e) {
      debugPrint('ProgressionController: Error fetching level requirements: $e');
    }
  }

  // Fetch User Level progress
  Future<void> fetchUserProgress() async {
    try {
      final response = await Supabase.instance.client
          .from('user_levels')
          .select()
          .eq('id', currentUserId)
          .maybeSingle();

      if (response != null) {
        userProgress.value = UserProgressModel.fromJson(response);
      }

      // Fetch daily ad watch count (using local date string format YYYY-MM-DD)
      final localDateStr = DateTime.now().toIso8601String().split('T')[0];
      final adResponse = await Supabase.instance.client
          .from('daily_limits')
          .select('ad_count')
          .eq('user_id', currentUserId)
          .eq('date', localDateStr)
          .maybeSingle();
      if (adResponse != null) {
        dailyAdCount.value = adResponse['ad_count'] as int? ?? 0;
      } else {
        dailyAdCount.value = 0;
      }
    } catch (e) {
      debugPrint('ProgressionController: Error fetching user progress: $e');
    }
  }

  // Fetch task lists & progress
  Future<void> fetchTasks() async {
    try {
      final response = await Supabase.instance.client
          .rpc('get_user_tasks');
      if (response != null) {
        final List<dynamic> list = response as List;
        tasks.value = list.map((item) => TaskModel.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('ProgressionController: Error fetching tasks: $e');
    }
  }

  // Fetch Check-in calendar status
  Future<void> fetchCheckinStatus() async {
    try {
      final response = await Supabase.instance.client
          .rpc('get_checkin_status');
      if (response != null) {
        checkinStatus.value = CheckinStatusModel.fromJson(response);
      }
    } catch (e) {
      debugPrint('ProgressionController: Error fetching checkin status: $e');
    }
  }

  // Fetch Achievements progress
  Future<void> fetchAchievements() async {
    try {
      final response = await Supabase.instance.client
          .rpc('get_user_achievements');
      if (response != null) {
        final List<dynamic> list = response as List;
        achievements.value = list.map((item) => AchievementModel.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('ProgressionController: Error fetching achievements: $e');
    }
  }

  // Fetch Loyalty active days & milestones
  Future<void> fetchLoyaltyStatus() async {
    try {
      final response = await Supabase.instance.client
          .rpc('get_loyalty_status');
      if (response != null) {
        loyaltyStatus.value = LoyaltyStatusModel.fromJson(response);
      }
    } catch (e) {
      debugPrint('ProgressionController: Error fetching loyalty status: $e');
    }
  }

  // Fetch Spin Rewards probability configurations
  Future<void> fetchSpinRewards() async {
    try {
      final response = await Supabase.instance.client
          .from('spin_rewards')
          .select()
          .eq('is_active', true);
      if (response != null) {
        final List<dynamic> list = response as List;
        spinRewards.value = list.map((item) => SpinRewardModel.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('ProgressionController: Error fetching spin rewards: $e');
    }
  }

  // Trigger XP event (from other client screens)
  Future<Map<String, dynamic>> triggerXpEvent(String eventType, {
    String? recipientId,
    String? giftId,
    String? recipientIp,
    String? recipientDeviceId,
  }) async {
    try {
      final metadata = {
        'ip': '192.168.1.1', // Mock or replace with actual in production
        'device_id': 'device_agora_123',
        if (recipientId != null) 'recipient_id': recipientId,
        if (giftId != null) 'gift_id': giftId,
        if (recipientIp != null) 'recipient_ip': recipientIp,
        if (recipientDeviceId != null) 'recipient_device_id': recipientDeviceId,
      };

      final response = await Supabase.instance.client.rpc(
        'process_xp_event',
        params: {
          'p_event_type': eventType,
          'p_metadata': metadata,
        },
      );

      await fetchUserProgress(); // reload progress
      await fetchTasks(); // reload tasks to update count progress
      
      // Sync client profiles cache
      UserProgressSyncService.syncFromSupabase();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('ProgressionController: Error triggering XP event: $e');
      return {'success': false, 'reason': e.toString()};
    }
  }

  // Claim Task Reward
  Future<bool> claimTask(String taskId, String taskType) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'claim_task_reward',
        params: {
          'p_task_id': taskId,
          'p_task_type': taskType,
        },
      );

      if (response != null && response['success'] == true) {
        await refreshAll();
        
        final String taskTitle = taskType[0].toUpperCase() + taskType.substring(1);
        FCMNotificationService.to.sendNotification(
          targetUserId: currentUserId,
          title: '$taskTitle Task Completed! 🏆',
          body: 'You successfully claimed your reward for the $taskType task.',
          type: 'reward_claimed',
        );

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('ProgressionController: Error claiming task reward: $e');
      return false;
    }
  }

  // Claim Daily Checkin
  Future<Map<String, dynamic>> claimDailyCheckin() async {
    try {
      final response = await Supabase.instance.client.rpc('claim_checkin');
      await refreshAll();

      if (response != null && response['success'] == true) {
        FCMNotificationService.to.sendNotification(
          targetUserId: currentUserId,
          title: 'Daily Reward Claimed! 📅',
          body: 'You claimed your daily check-in login reward.',
          type: 'daily_reward',
        );
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('ProgressionController: Error claiming checkin: $e');
      return {'success': false, 'reason': e.toString()};
    }
  }

  // Claim Achievement Reward
  Future<bool> claimAchievement(String achievementId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'claim_achievement_reward',
        params: {
          'p_achievement_id': achievementId,
        },
      );

      if (response != null && response['success'] == true) {
        await refreshAll();
        
        FCMNotificationService.to.sendNotification(
          targetUserId: currentUserId,
          title: 'Achievement Unlocked! 🏆',
          body: 'You successfully unlocked an achievement and claimed your reward.',
          type: 'achievement_unlocked',
        );

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('ProgressionController: Error claiming achievement: $e');
      return false;
    }
  }

  // Claim Loyalty Reward
  Future<bool> claimLoyalty(int activeDays) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'claim_loyalty_reward',
        params: {
          'p_active_days': activeDays,
        },
      );

      if (response != null && response['success'] == true) {
        await refreshAll();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('ProgressionController: Error claiming loyalty reward: $e');
      return false;
    }
  }

  // Spin Lucky Wheel
  Future<SpinResultModel> spinWheel(String spinType) async {
    if (isSpinning.value) return SpinResultModel(success: false, wonAmount: 0, reason: 'Already spinning');
    isSpinning.value = true;
    wonReward.value = null;

    try {
      final response = await Supabase.instance.client.rpc(
        'execute_lucky_spin',
        params: {
          'p_spin_type': spinType,
        },
      );

      final result = SpinResultModel.fromJson(Map<String, dynamic>.from(response));
      wonReward.value = result;
      await refreshAll();
      return result;
    } catch (e) {
      debugPrint('ProgressionController: Error executing spin: $e');
      final result = SpinResultModel(success: false, wonAmount: 0, reason: e.toString().replaceFirst('Exception: ', ''));
      wonReward.value = result;
      return result;
    } finally {
      isSpinning.value = false;
    }
  }

  // First Community Join Welcome Reward claim
  Future<Map<String, dynamic>> claimFirstCommunityJoin() async {
    try {
      final response = await Supabase.instance.client.rpc('claim_first_community_join_reward');
      await refreshAll();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('ProgressionController: Error claiming first community welcome: $e');
      return {'success': false, 'reason': e.toString().replaceFirst('Exception: ', '')};
    }
  }

  // Calculate current level XP progress percentage (0.0 to 1.0)
  double getXpProgress() {
    final progress = userProgress.value;
    if (progress == null) return 0.0;
    
    final nextLevel = progress.level + 1;
    final xpNeeded = levelRequirements[nextLevel];
    if (xpNeeded == null || xpNeeded <= 0) return 0.0;

    return (progress.xp / xpNeeded).clamp(0.0, 1.0);
  }

  // Title for ID levels
  String getIdTitleForLevel(int lvl) {
    if (lvl <= 7) return '🌱 Newcomer';
    if (lvl <= 15) return '🚀 Explorer';
    if (lvl <= 25) return '📘 Pathfinder';
    if (lvl <= 40) return '⭐ Trailblazer';
    if (lvl <= 50) return '🔥 Rising Star';
    return '👑 Legendary';
  }
}
