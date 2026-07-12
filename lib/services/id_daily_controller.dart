import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_progress_model.dart';
import 'store_controller.dart';
import 'user_profile_cache_manager.dart';

class IdDailyController extends GetxController {
  static IdDailyController get to => Get.find();
  
  static String get currentUserId => UserProfileCacheManager.currentUserId;

  final RxInt idLevel = 1.obs;
  final RxInt idXp = 0.obs;
  final RxList<TaskProgress> tasks = <TaskProgress>[].obs;
  final RxBool isLoading = false.obs;
  final RxInt idStreak = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadIdState();
  }

  Future<void> loadIdState() async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('level, experience, progress_metadata')
          .eq('id', currentUserId)
          .maybeSingle();

      if (profile != null) {
        idLevel.value = profile['level'] ?? 1;
        idXp.value = profile['experience'] ?? 0;
        final metadata = profile['progress_metadata'] as Map<String, dynamic>?;
        idStreak.value = metadata?['id_streak'] ?? 0;
      }
    } catch (_) {}
    await fetchAndRotateIdTasks();
  }

  int xpRequiredForIdLevel(int lvl) {
    if (lvl <= 1) return 0;
    final int lm1 = lvl - 1;
    return 10 * lm1 * lm1 * lm1 + 250 * lm1 * lm1 + 500 * lm1;
  }

  double getLevelProgress() {
    int currentXpThreshold = xpRequiredForIdLevel(idLevel.value);
    int nextXpThreshold = xpRequiredForIdLevel(idLevel.value + 1);
    int range = nextXpThreshold - currentXpThreshold;
    if (range <= 0) return 0.0;
    return ((idXp.value - currentXpThreshold) / range).clamp(0.0, 1.0);
  }

  int get completedTasksCount => tasks.where((t) => t.completed).length;
  int get totalTasksCount => tasks.length;
  int get remainingTasksCount => tasks.where((t) => !t.completed).length;
  int get todayXpEarned => tasks.where((t) => t.claimed).fold(0, (sum, t) => sum + t.xp);
  int get todayCoinsEarned => tasks.where((t) => t.claimed).fold(0, (sum, t) => sum + t.silverCoin);

  Future<void> fetchAndRotateIdTasks() async {
    try {
      isLoading.value = true;
      final response = await Supabase.instance.client.rpc(
        'rotate_id_tasks',
        params: {'p_user_id': currentUserId},
      );

      if (response != null) {
        final List<dynamic> list = response as List<dynamic>;
        tasks.assignAll(list.map((item) {
          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
          itemMap['task_type'] = 'id';
          itemMap['xp'] = itemMap['id_xp'] ?? itemMap['xp'] ?? 50;
          return TaskProgress.fromJson(itemMap);
        }).toList());
      }
    } catch (e) {
      debugPrint('Error fetching ID tasks: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> claimTaskReward(String progressId) async {
    try {
      final res = await Supabase.instance.client.rpc(
        'claim_id_task_reward',
        params: {'p_progress_id': progressId},
      );

      if (res != null) {
        final data = Map<String, dynamic>.from(res);
        final xpEarned = data['xp_earned'] ?? 0;
        final coinsEarned = data['coins_earned'] ?? 0;
        final newXp = data['new_xp'] ?? 0;
        final newLevel = data['new_level'] ?? 1;
        final newCoins = data['new_coins'] ?? 0;

        int idx = tasks.indexWhere((t) => t.id == progressId);
        if (idx != -1) {
          tasks[idx] = tasks[idx].copyWith(claimed: true);
          tasks.refresh();
          idXp.value = newXp;
          idLevel.value = newLevel;
        }

        if (Get.isRegistered<StoreController>()) {
          Get.find<StoreController>().coinsBalance.value = newCoins.toInt();
        }

        UserProfileCacheManager.invalidateCache(currentUserId);

        Get.snackbar(
          'ID Reward Claimed! 🏆',
          'Earned $xpEarned XP & $coinsEarned Silver Coins.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFFFD700),
          colorText: Colors.black,
        );
      }
    } catch (e) {
      Get.snackbar('Claim Failed ⚠️', 'Error: $e');
    }
  }

  Future<bool> incrementTaskProgress(String taskCode, {int amount = 1}) async {
    try {
      final bool success = await Supabase.instance.client.rpc(
        'increment_id_task_progress',
        params: {
          'p_task_code': taskCode,
          'p_amount': amount,
        },
      );
      if (success) {
        await fetchAndRotateIdTasks();
        return true;
      }
    } catch (e) {
      debugPrint('Error incrementing ID task progress: $e');
    }
    return false;
  }
}
