import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'study_category_controller.dart';

class CareerProgressionController extends GetxController {
  static const String _keyIdXp = 'prog_id_xp';
  static const String _keyIdLevel = 'prog_id_level';
  static const String _keyIsCareerSelected = 'prog_is_career_selected';
  static const String _keySelectedCareer = 'prog_selected_career';
  static const String _keyCareerXp = 'prog_career_xp';
  static const String _keyCareerLevel = 'prog_career_level';
  static const String _keyCareerChanges = 'prog_career_changes';
  static const String _keyLastChangeDate = 'prog_last_change_date';
  static const String _keyRollbackExpiry = 'prog_rollback_expiry';
  static const String _keyClaimedMilestones = 'prog_claimed_milestones';
  
  static const String _keyPrevCareerName = 'prog_prev_career_name';
  static const String _keyPrevCareerLevel = 'prog_prev_career_level';
  static const String _keyPrevCareerXp = 'prog_prev_career_xp';
  static const String _keyPrevCareerBadges = 'prog_prev_career_badges';

  static const String _keyActiveFrame = 'prog_active_frame';
  static const String _keyActiveRing = 'prog_active_ring';
  static const String _keyActiveTheme = 'prog_active_theme';
  static const String _keyGlobalTaskProgress = 'prog_global_task_progress';

  // State Observables
  final RxInt idXp = 1850.obs;
  final RxInt idLevel = 25.obs;

  final RxBool isCareerSelected = false.obs;
  final RxnString selectedCareer = RxnString();
  final RxInt careerXp = 0.obs;
  final RxInt careerLevel = 1.obs;
  final RxInt careerChangesCount = 0.obs;
  final Rxn<DateTime> lastCareerChangeDate = Rxn<DateTime>();
  final Rxn<DateTime> rollbackExpiryDate = Rxn<DateTime>();

  // Global Daily Tasks Progress (taskId -> currentCount)
  final RxMap<String, int> globalTaskProgress = <String, int>{}.obs;

  // List of task definitions
  final List<Map<String, dynamic>> globalTasksList = [
    {'id': 'check_in', 'title': 'Daily Check In', 'icon': Icons.today_rounded, 'target': 1, 'xp': 50, 'coins': 20},
    {'id': 'watch_ads', 'title': 'Watch 5 Ads', 'icon': Icons.play_circle_outline_rounded, 'target': 5, 'xp': 100, 'coins': 50},
    {'id': 'like_posts', 'title': 'Like 3 Posts', 'icon': Icons.thumb_up_alt_outlined, 'target': 3, 'xp': 40, 'coins': 10},
    {'id': 'share_profile', 'title': 'Share Profile', 'icon': Icons.share_rounded, 'target': 1, 'xp': 30, 'coins': 10},
    {'id': 'create_post', 'title': 'Create 1 Post', 'icon': Icons.add_circle_outline_rounded, 'target': 1, 'xp': 60, 'coins': 20},
    {'id': 'voice_room', 'title': 'Voice Room (10m)', 'icon': Icons.mic_none_rounded, 'target': 1, 'xp': 80, 'coins': 30},
    {'id': 'invite_friend', 'title': 'Invite 1 Friend', 'icon': Icons.person_add_alt_1_rounded, 'target': 1, 'xp': 120, 'coins': 100},
    {'id': 'join_community', 'title': 'Join Community', 'icon': Icons.group_add_rounded, 'target': 1, 'xp': 50, 'coins': 20},
  ];

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

  // Support Override Toggle for testing 1-year lock
  final RxBool isSupportOverrideActive = false.obs;

  // Anti-Grind trackers (Action ID -> Timestamps of recent executions)
  final Map<String, List<DateTime>> _actionTimestamps = {};

  @override
  void onInit() {
    super.onInit();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    idXp.value = prefs.getInt(_keyIdXp) ?? 1850;
    idLevel.value = prefs.getInt(_keyIdLevel) ?? 25;
    isCareerSelected.value = prefs.getBool(_keyIsCareerSelected) ?? false;
    selectedCareer.value = prefs.getString(_keySelectedCareer);
    careerXp.value = prefs.getInt(_keyCareerXp) ?? 0;
    careerLevel.value = prefs.getInt(_keyCareerLevel) ?? 1;
    careerChangesCount.value = prefs.getInt(_keyCareerChanges) ?? 0;

    final dateStr = prefs.getString(_keyLastChangeDate);
    if (dateStr != null) lastCareerChangeDate.value = DateTime.tryParse(dateStr);

    final rollbackStr = prefs.getString(_keyRollbackExpiry);
    if (rollbackStr != null) rollbackExpiryDate.value = DateTime.tryParse(rollbackStr);

    final List<String>? claimedStr = prefs.getStringList(_keyClaimedMilestones);
    if (claimedStr != null) {
      claimedMilestones.assignAll(claimedStr.map((e) => int.parse(e)));
    }

    previousCareerName.value = prefs.getString(_keyPrevCareerName);
    previousCareerLevel.value = prefs.getInt(_keyPrevCareerLevel) ?? 1;
    previousCareerXp.value = prefs.getInt(_keyPrevCareerXp) ?? 0;
    previousCareerBadges.assignAll(prefs.getStringList(_keyPrevCareerBadges) ?? []);

    activeFrame.value = prefs.getString(_keyActiveFrame) ?? 'Normal';
    activeAvatarRing.value = prefs.getBool(_keyActiveRing) ?? false;
    activeTheme.value = prefs.getString(_keyActiveTheme) ?? 'Default';

    // Load global daily tasks
    final String? progressJson = prefs.getString(_keyGlobalTaskProgress);
    if (progressJson != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(progressJson);
        decoded.forEach((key, value) {
          globalTaskProgress[key] = value as int;
        });
      } catch (_) {}
    }

    // Daily Reset check for global tasks
    final String? lastResetStr = prefs.getString('prog_last_daily_task_reset');
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month}-${now.day}';
    if (lastResetStr != todayStr) {
      globalTaskProgress.clear();
      await prefs.setString('prog_last_daily_task_reset', todayStr);
      await prefs.setString(_keyGlobalTaskProgress, json.encode(globalTaskProgress));
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyIdXp, idXp.value);
    await prefs.setInt(_keyIdLevel, idLevel.value);
    await prefs.setBool(_keyIsCareerSelected, isCareerSelected.value);
    if (selectedCareer.value != null) {
      await prefs.setString(_keySelectedCareer, selectedCareer.value!);
    } else {
      await prefs.remove(_keySelectedCareer);
    }
    await prefs.setInt(_keyCareerXp, careerXp.value);
    await prefs.setInt(_keyCareerLevel, careerLevel.value);
    await prefs.setInt(_keyCareerChanges, careerChangesCount.value);

    if (lastCareerChangeDate.value != null) {
      await prefs.setString(_keyLastChangeDate, lastCareerChangeDate.value!.toIso8601String());
    }
    if (rollbackExpiryDate.value != null) {
      await prefs.setString(_keyRollbackExpiry, rollbackExpiryDate.value!.toIso8601String());
    }

    await prefs.setStringList(_keyClaimedMilestones, claimedMilestones.map((e) => e.toString()).toList());

    if (previousCareerName.value != null) {
      await prefs.setString(_keyPrevCareerName, previousCareerName.value!);
    }
    await prefs.setInt(_keyPrevCareerLevel, previousCareerLevel.value);
    await prefs.setInt(_keyPrevCareerXp, previousCareerXp.value);
    await prefs.setStringList(_keyPrevCareerBadges, previousCareerBadges);

    await prefs.setString(_keyActiveFrame, activeFrame.value);
    await prefs.setBool(_keyActiveRing, activeAvatarRing.value);
    await prefs.setString(_keyActiveTheme, activeTheme.value);

    await prefs.setString(_keyGlobalTaskProgress, json.encode(globalTaskProgress));
  }

  // Dynamic Level Curves
  int xpRequiredForIdLevel(int lvl) {
    if (lvl <= 1) return 0;
    return (500 * (lvl - 1) * (lvl - 1) + 100 * (lvl - 1));
  }

  int xpRequiredForCareerLevel(int lvl) {
    if (lvl <= 1) return 0;
    return (800 * (lvl - 1) * (lvl - 1) + 200 * (lvl - 1));
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

  // Titles Mapping
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

  // Select Career
  Future<void> selectCareer(String careerName) async {
    selectedCareer.value = careerName;
    isCareerSelected.value = true;
    careerXp.value = 0;
    careerLevel.value = 1;
    await _saveState();
  }

  // Check Career Change Constraint
  String? getCareerChangeWarning() {
    if (isSupportOverrideActive.value) return null;
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

  // Change Career (Resets progress, creates rollback point)
  Future<void> changeCareer(String newCareerName) async {
    // 1. Back up previous career
    previousCareerName.value = selectedCareer.value;
    previousCareerLevel.value = careerLevel.value;
    previousCareerXp.value = careerXp.value;
    rollbackExpiryDate.value = DateTime.now().add(const Duration(days: 15));

    // 2. Update states
    selectedCareer.value = newCareerName;
    isCareerSelected.value = true;
    careerXp.value = 0;
    careerLevel.value = 1;
    
    if (!isSupportOverrideActive.value) {
      careerChangesCount.value += 1;
    }
    lastCareerChangeDate.value = DateTime.now();

    await _saveState();
  }

  // Rollback Career within 15 days
  bool isRollbackAvailable() {
    if (rollbackExpiryDate.value == null || previousCareerName.value == null) return false;
    return DateTime.now().isBefore(rollbackExpiryDate.value!);
  }

  Future<bool> rollbackCareer() async {
    if (!isRollbackAvailable()) return false;

    selectedCareer.value = previousCareerName.value;
    careerLevel.value = previousCareerLevel.value;
    careerXp.value = previousCareerXp.value;

    // Reset backup
    previousCareerName.value = null;
    rollbackExpiryDate.value = null;

    await _saveState();
    return true;
  }

  // Add XP with Anti-Grind Logic
  Future<Map<String, dynamic>> addXp(String actionId, int baseXp, bool isCareerXp) async {
    final now = DateTime.now();
    _actionTimestamps.putIfAbsent(actionId, () => []);

    // Filter executions in the last 5 minutes
    final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
    _actionTimestamps[actionId]!.retainWhere((t) => t.isAfter(fiveMinutesAgo));

    final repeatCount = _actionTimestamps[actionId]!.length;
    _actionTimestamps[actionId]!.add(now);

    // Exponential Decay multiplier for spamming: 100% -> 80% -> 60% -> 40% -> 20% -> 10% min
    final multiplier = (1.0 - (repeatCount * 0.2)).clamp(0.1, 1.0);
    final earnedXp = (baseXp * multiplier).round();

    if (isCareerXp && isCareerSelected.value) {
      careerXp.value += earnedXp;
      // Level Up Check
      while (careerXp.value >= xpRequiredForCareerLevel(careerLevel.value + 1)) {
        careerLevel.value += 1;
      }
    } else {
      idXp.value += earnedXp;
      // Level Up Check
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

  // Claim Reward Milestones
  Future<void> claimMilestone(int milestoneLvl, bool isCareerMilestone) async {
    if (!claimedMilestones.contains(milestoneLvl)) {
      claimedMilestones.add(milestoneLvl);

      // Apply specific visual rewards
      if (milestoneLvl == 5) activeFrame.value = 'Premium';
      if (milestoneLvl == 10) activeAvatarRing.value = true;
      if (milestoneLvl == 20) activeFrame.value = 'Achievement';
      if (milestoneLvl == 25) activeTheme.value = 'Custom';
      if (milestoneLvl == 40) activeFrame.value = 'Festival'; // Legend Frame
      if (milestoneLvl == 60) activeTheme.value = 'Immortal';
      await _saveState();
    }
  }

  Future<bool> incrementGlobalTaskProgress(String taskId) async {
    final task = globalTasksList.firstWhere((t) => t['id'] == taskId);
    final target = task['target'] as int;
    final current = globalTaskProgress[taskId] ?? 0;

    if (current >= target) return false; // Already completed

    final nextVal = current + 1;
    globalTaskProgress[taskId] = nextVal;
    
    // Save
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGlobalTaskProgress, json.encode(globalTaskProgress));

    if (nextVal == target) {
      // Award rewards!
      final xpReward = task['xp'] as int;
      final coinReward = task['coins'] as int;

      await addXp(taskId, xpReward, false); // Award to ID level
      await awardCoins(coinReward);         // Award coins

      return true; // Completed now
    }
    return false; // Incremented but not completed yet
  }

  Future<void> awardCoins(int amount) async {
    try {
      final studyCtrl = Get.find<StudyCategoryController>();
      studyCtrl.silverCoins.value += amount;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('study_silver_coins', studyCtrl.silverCoins.value);
    } catch (_) {}
  }
}
