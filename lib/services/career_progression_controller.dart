import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'study_category_controller.dart';
import 'user_profile_cache_manager.dart';
import 'store_controller.dart';
import '../models/index.dart';

class CareerProgressionController extends GetxController {
  static String get currentUserId => UserProfileCacheManager.currentUserId;

  // SharedPreferences keys for visual local/caching preferences
  static const String _keyIsCareerSelected = 'prog_is_career_selected';
  static const String _keySelectedCareer = 'prog_selected_career';
  static const String _keyCareerXp = 'prog_career_xp';
  static const String _keyCareerChanges = 'prog_career_changes';
  static const String _keyLastChangeDate = 'prog_last_change_date';
  static const String _keyRollbackExpiry = 'prog_rollback_expiry';
  
  static const String _keyPrevCareerName = 'prog_prev_career_name';
  static const String _keyPrevCareerLevel = 'prog_prev_career_level';
  static const String _keyPrevCareerXp = 'prog_prev_career_xp';
  static const String _keyPrevCareerBadges = 'prog_prev_career_badges';

  // State Observables
  final RxInt idXp = 0.obs;
  final RxInt idLevel = 1.obs;

  final RxBool isCareerSelected = false.obs;
  final RxnString selectedCareer = RxnString();
  final RxInt careerXp = 0.obs;
  final RxInt careerLevel = 1.obs;
  final RxInt careerChangesCount = 0.obs;
  final Rxn<DateTime> lastCareerChangeDate = Rxn<DateTime>();
  final Rxn<DateTime> rollbackExpiryDate = Rxn<DateTime>();

  // Dynamic daily task lists
  final RxList<TaskProgress> careerTasks = <TaskProgress>[].obs;
  final RxList<TaskProgress> idTasks = <TaskProgress>[].obs;
  final RxBool isLoadingTasks = false.obs;

  // Rollback Backup Data
  final RxnString previousCareerName = RxnString();
  final RxInt previousCareerLevel = 1.obs;
  final RxInt previousCareerXp = 0.obs;
  final RxList<String> previousCareerBadges = <String>[].obs;

  // Visual Customizations from Milestones
  final RxList<int> claimedMilestones = <int>[].obs;
  final RxString activeFrame = 'Normal'.obs;
  final RxBool activeAvatarRing = false.obs;
  final RxString activeTheme = 'Default'.obs;
  final RxBool isSupportOverrideActive = false.obs;

  final Map<String, List<DateTime>> _actionTimestamps = {};

  @override
  void onInit() {
    super.onInit();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load from database profiles
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('level, experience, career_level, career_xp')
          .eq('id', currentUserId)
          .maybeSingle();

      if (profile != null) {
        idLevel.value = profile['level'] ?? 1;
        idXp.value = profile['experience'] ?? 0;
        careerLevel.value = profile['career_level'] ?? 1;
        careerXp.value = profile['career_xp'] ?? 0;
      }
    } catch (_) {}

    isCareerSelected.value = prefs.getBool(_keyIsCareerSelected) ?? false;
    selectedCareer.value = prefs.getString(_keySelectedCareer);
    careerChangesCount.value = prefs.getInt(_keyCareerChanges) ?? 0;

    final dateStr = prefs.getString(_keyLastChangeDate);
    if (dateStr != null) lastCareerChangeDate.value = DateTime.tryParse(dateStr);

    final rollbackStr = prefs.getString(_keyRollbackExpiry);
    if (rollbackStr != null) rollbackExpiryDate.value = DateTime.tryParse(rollbackStr);

    previousCareerName.value = prefs.getString(_keyPrevCareerName);
    previousCareerLevel.value = prefs.getInt(_keyPrevCareerLevel) ?? 1;
    previousCareerXp.value = prefs.getInt(_keyPrevCareerXp) ?? 0;

    // Load tasks from Supabase via rotate_daily_tasks RPC
    await fetchAndRotateTasks();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsCareerSelected, isCareerSelected.value);
    if (selectedCareer.value != null) {
      await prefs.setString(_keySelectedCareer, selectedCareer.value!);
    }
    await prefs.setInt(_keyCareerXp, careerXp.value);
    await prefs.setInt(_keyCareerChanges, careerChangesCount.value);

    if (lastCareerChangeDate.value != null) {
      await prefs.setString(_keyLastChangeDate, lastCareerChangeDate.value!.toIso8601String());
    }
    if (rollbackExpiryDate.value != null) {
      await prefs.setString(_keyRollbackExpiry, rollbackExpiryDate.value!.toIso8601String());
    }

    if (previousCareerName.value != null) {
      await prefs.setString(_keyPrevCareerName, previousCareerName.value!);
    }
    await prefs.setInt(_keyPrevCareerLevel, previousCareerLevel.value);
    await prefs.setInt(_keyPrevCareerXp, previousCareerXp.value);

    // Sync XP and Level to profiles table
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'level': idLevel.value,
            'experience': idXp.value,
            'career_level': careerLevel.value,
            'career_xp': careerXp.value,
          })
          .eq('id', currentUserId);
    } catch (_) {}
  }

  int xpRequiredForIdLevel(int lvl) {
    if (lvl <= 1) return 0;
    final int lm1 = lvl - 1;
    return 10 * lm1 * lm1 * lm1 + 250 * lm1 * lm1 + 500 * lm1;
  }

  int xpRequiredForCareerLevel(int lvl) {
    if (lvl <= 1) return 0;
    final int lm1 = lvl - 1;
    return 10 * lm1 * lm1 * lm1 + 250 * lm1 * lm1 + 500 * lm1;
  }

  double getIdLevelProgress() {
    int currentXpThreshold = xpRequiredForIdLevel(idLevel.value);
    int nextXpThreshold = xpRequiredForIdLevel(idLevel.value + 1);
    int range = nextXpThreshold - currentXpThreshold;
    if (range <= 0) return 0.0;
    return ((idXp.value - currentXpThreshold) / range).clamp(0.0, 1.0);
  }

  double getCareerLevelProgress() {
    int currentXpThreshold = xpRequiredForCareerLevel(careerLevel.value);
    int nextXpThreshold = xpRequiredForCareerLevel(careerLevel.value + 1);
    int range = nextXpThreshold - currentXpThreshold;
    if (range <= 0) return 0.0;
    return ((careerXp.value - currentXpThreshold) / range).clamp(0.0, 1.0);
  }

  String getIdTitleForLevel(int lvl) {
    if (lvl <= 5) return '🌱 Newcomer';
    if (lvl <= 10) return '🚀 Explorer';
    if (lvl <= 15) return '📘 Pathfinder';
    if (lvl <= 20) return '⭐ Trailblazer';
    if (lvl <= 25) return '🔥 Rising Star';
    if (lvl <= 30) return '💎 Elite';
    if (lvl <= 35) return '⚔️ Vanguard';
    if (lvl <= 40) return '👑 Champion';
    if (lvl <= 45) return '🏆 Legend';
    if (lvl <= 50) return '🌟 Mythic';
    if (lvl <= 55) return '💠 Grandmaster';
    return '👑 Immortal';
  }

  String getCareerTitleForLevel(int lvl) {
    if (lvl <= 5) return 'Student';
    if (lvl <= 10) return 'Apprentice';
    if (lvl <= 15) return 'Learner';
    if (lvl <= 20) return 'Practitioner';
    if (lvl <= 25) return 'Specialist';
    if (lvl <= 30) return 'Professional';
    if (lvl <= 35) return 'Expert';
    if (lvl <= 40) return 'Senior Expert';
    if (lvl <= 45) return 'Master';
    return 'Grandmaster';
  }

  Future<void> selectCareer(String careerName) async {
    selectedCareer.value = careerName;
    isCareerSelected.value = true;
    careerXp.value = 0;
    careerLevel.value = 1;
    await _saveState();
  }

  String? getCareerChangeWarning() {
    if (careerChangesCount.value >= 3) {
      return 'You have reached the maximum limit of 3 career changes. Official support approval is required for further changes.';
    }
    if (lastCareerChangeDate.value != null) {
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      if (lastCareerChangeDate.value!.isAfter(oneYearAgo)) {
        final remainingDays = 365 - DateTime.now().difference(lastCareerChangeDate.value!).inDays;
        return 'Career can only be changed once every year. Next change available in $remainingDays days.';
      }
    }
    return null;
  }

  Future<void> changeCareer(String newCareerName) async {
    previousCareerName.value = selectedCareer.value;
    previousCareerLevel.value = careerLevel.value;
    previousCareerXp.value = careerXp.value;
    rollbackExpiryDate.value = DateTime.now().add(const Duration(days: 15));

    selectedCareer.value = newCareerName;
    isCareerSelected.value = true;
    careerXp.value = 0;
    careerLevel.value = 1;
    careerChangesCount.value += 1;
    lastCareerChangeDate.value = DateTime.now();

    await _saveState();
  }

  bool isRollbackAvailable() {
    if (rollbackExpiryDate.value == null || previousCareerName.value == null) return false;
    return DateTime.now().isBefore(rollbackExpiryDate.value!);
  }

  Future<bool> rollbackCareer() async {
    if (!isRollbackAvailable()) return false;

    selectedCareer.value = previousCareerName.value;
    careerLevel.value = previousCareerLevel.value;
    careerXp.value = previousCareerXp.value;

    previousCareerName.value = null;
    rollbackExpiryDate.value = null;

    await _saveState();
    return true;
  }

  Future<Map<String, dynamic>> addXp(String actionId, int baseXp, bool isCareerXp) async {
    final now = DateTime.now();
    _actionTimestamps.putIfAbsent(actionId, () => []);

    final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
    _actionTimestamps[actionId]!.retainWhere((t) => t.isAfter(fiveMinutesAgo));

    final repeatCount = _actionTimestamps[actionId]!.length;
    _actionTimestamps[actionId]!.add(now);

    final multiplier = (1.0 - (repeatCount * 0.2)).clamp(0.1, 1.0);
    final earnedXp = (baseXp * multiplier).round();

    if (isCareerXp && isCareerSelected.value) {
      careerXp.value += earnedXp;
      while (careerXp.value >= xpRequiredForCareerLevel(careerLevel.value + 1)) {
        careerLevel.value += 1;
      }
    } else {
      idXp.value += earnedXp;
      while (idXp.value >= xpRequiredForIdLevel(idLevel.value + 1)) {
        idLevel.value += 1;
      }
    }

    await _saveState();

    return {
      'xpEarned': earnedXp,
      'multiplier': multiplier,
      'antiGrindActive': multiplier < 1.0,
      'newLevel': isCareerXp ? careerLevel.value : idLevel.value
    };
  }

  Future<void> claimMilestone(int milestoneLvl, bool isCareerMilestone) async {
    if (!claimedMilestones.contains(milestoneLvl)) {
      claimedMilestones.add(milestoneLvl);
      await _saveState();
    }
  }

  Future<void> fetchAndRotateTasks() async {
    try {
      isLoadingTasks.value = true;
      final response = await Supabase.instance.client.rpc(
        'rotate_daily_tasks',
        params: {'p_user_id': currentUserId},
      );

      if (response != null) {
        final List<dynamic> list = response as List<dynamic>;
        final allTasks = list.map((item) => TaskProgress.fromJson(item as Map<String, dynamic>)).toList();

        careerTasks.assignAll(allTasks.where((t) => t.taskType == 'career').toList());
        idTasks.assignAll(allTasks.where((t) => t.taskType == 'id').toList());
      }
    } catch (e) {
      debugPrint('Error rotating/fetching tasks: $e');
    } finally {
      isLoadingTasks.value = false;
    }
  }

  Future<void> claimTaskReward(String progressId) async {
    try {
      final res = await Supabase.instance.client.rpc(
        'claim_task_reward',
        params: {'p_progress_id': progressId},
      );

      if (res != null) {
        final data = Map<String, dynamic>.from(res);
        final xpEarned = data['xp_earned'] ?? 0;
        final coinsEarned = data['coins_earned'] ?? 0;
        final newXp = data['new_xp'] ?? 0;
        final newLevel = data['new_level'] ?? 1;
        final newCoins = data['new_coins'] ?? 0;

        // Find progress record and mark it claimed locally
        int idx = careerTasks.indexWhere((t) => t.id == progressId);
        if (idx != -1) {
          careerTasks[idx] = careerTasks[idx].copyWith(claimed: true);
          careerTasks.refresh();
          careerXp.value = newXp;
          careerLevel.value = newLevel;
        } else {
          idx = idTasks.indexWhere((t) => t.id == progressId);
          if (idx != -1) {
            idTasks[idx] = idTasks[idx].copyWith(claimed: true);
            idTasks.refresh();
            idXp.value = newXp;
            idLevel.value = newLevel;
          }
        }

        // Update local wallet balance
        final storeCtrl = Get.find<StoreController>();
        storeCtrl.coinsBalance.value = newCoins.toInt();

        // Invalidate profile cache
        UserProfileCacheManager.invalidateCache(currentUserId);

        Get.snackbar(
          'Reward Claimed! 🎉',
          'Earned $xpEarned XP & $coinsEarned Silver Coins.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar('Claim Failed ⚠️', 'Error claiming reward: $e');
    }
  }

  Future<bool> incrementGlobalTaskProgress(String taskCode, {int amount = 1}) async {
    try {
      final bool success = await Supabase.instance.client.rpc(
        'increment_task_progress',
        params: {
          'p_task_code': taskCode,
          'p_amount': amount,
        },
      );
      if (success) {
        await fetchAndRotateTasks();
        return true;
      }
    } catch (e) {
      debugPrint('Error incrementing task progress: $e');
    }
    return false;
  }
}
