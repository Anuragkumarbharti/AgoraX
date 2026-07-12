import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_learning_model.dart';
import '../models/study_category_model.dart';
import '../models/user_model.dart';
import '../widgets/level_up_dialog.dart';
import 'career_progression_controller.dart';
import 'store_controller.dart';
import 'user_progress_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RankTier {
  final String name;
  final Color color;
  final List<Color> gradientColors;
  final String icon;

  const RankTier({
    required this.name,
    required this.color,
    required this.gradientColors,
    required this.icon,
  });
}

class StudyCategoryController extends GetxController {
  // SharedPreferences Keys
  static const String _keySelectedCategory = 'study_selected_category';
  static const String _keyLockExpiry = 'study_lock_expiry';
  static const String _keySilverCoins = 'study_silver_coins';
  static const String _keyUserXp = 'study_user_xp';
  static const String _keyUserLevel = 'study_user_level';
  static const String _keyStreak = 'study_streak';
  static const String _keyLastCompletedDate = 'study_last_completed_date';
  static const String _keyBadges = 'study_badges';
  static const String _keyCustomPacks = 'study_custom_packs';
  static const String _keyCompletionRates = 'study_completion_rates';
  static const String _keyProgress = 'study_day_progress_'; // study_day_progress_<category>_<day>
  static const String _keyXpEarnedToday = 'study_xp_earned_today';
  static const String _keyXpEarnedThisWeek = 'study_xp_earned_this_week';
  static const String _keyXpEarnedThisMonth = 'study_xp_earned_this_month';
  static const String _keyLastDailyReset = 'study_last_daily_reset';
  static const String _keyLastWeeklyReset = 'study_last_weekly_reset';
  static const String _keyLastMonthlyReset = 'study_last_monthly_reset';

  // Observables
  final RxnString selectedCategory = RxnString();
  final Rxn<DateTime> lockExpiry = Rxn<DateTime>();
  RxInt get silverCoins => Get.find<StoreController>().silverCoinsBalance;
  final RxInt userXp = 0.obs;
  final RxInt userLevel = 1.obs;
  final RxInt learningStreak = 0.obs;
  final RxList<String> unlockedBadges = <String>[].obs;
  final RxList<String> completedTaskIds = <String>[].obs;

  final RxInt xpEarnedToday = 0.obs;
  final RxInt xpEarnedThisWeek = 0.obs;
  final RxInt xpEarnedThisMonth = 0.obs;
  final Rxn<DateTime> lastDailyReset = Rxn<DateTime>();
  final Rxn<DateTime> lastWeeklyReset = Rxn<DateTime>();
  final Rxn<DateTime> lastMonthlyReset = Rxn<DateTime>();

  static final List<int> levelXpRequirements = _generateLevelXpRequirements();

  static List<int> _generateLevelXpRequirements() {
    final milestones = <int, int>{
      1: 0,
      2: 50,
      3: 120,
      4: 220,
      5: 360,
      6: 540,
      7: 760,
      8: 1020,
      9: 1330,
      10: 1700,
      15: 6000,
      20: 18000,
      25: 45000,
      30: 100000,
      35: 220000,
      40: 450000,
      45: 850000,
      50: 1500000,
      55: 2500000,
      60: 4000000,
      65: 6000000,
      70: 9000000,
      75: 13000000,
      80: 18000000,
      85: 24000000,
      90: 31000000,
      95: 39000000,
      100: 48000000,
    };

    final list = List<int>.filled(101, 0);
    list[1] = 0;

    final sortedKeys = milestones.keys.toList()..sort();
    for (int i = 0; i < sortedKeys.length - 1; i++) {
      int startL = sortedKeys[i];
      int endL = sortedKeys[i + 1];
      int startXp = milestones[startL]!;
      int endXp = milestones[endL]!;

      list[startL] = startXp;
      list[endL] = endXp;

      int levelDiff = endL - startL;
      int xpDiff = endXp - startXp;

      for (int l = startL + 1; l < endL; l++) {
        double ratio = (l - startL) / levelDiff;
        list[l] = (startXp + ratio * xpDiff).round();
      }
    }
    return list;
  }

  static RankTier getTierForLevel(int level) {
    if (level <= 10) {
      return const RankTier(
        name: 'Explorer',
        color: Color(0xFF10B981),
        gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
        icon: '🌱',
      );
    } else if (level <= 20) {
      return const RankTier(
        name: 'Learner',
        color: Color(0xFF3B82F6),
        gradientColors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        icon: '📘',
      );
    } else if (level <= 30) {
      return const RankTier(
        name: 'Scholar',
        color: Color(0xFF8B5CF6),
        gradientColors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
        icon: '🔮',
      );
    } else if (level <= 40) {
      return const RankTier(
        name: 'Master',
        color: Color(0xFFF59E0B),
        gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        icon: '👑',
      );
    } else if (level <= 50) {
      return const RankTier(
        name: 'Legend',
        color: Color(0xFFEF4444),
        gradientColors: [Color(0xFFEF4444), Color(0xFFDC2626)],
        icon: '🔥',
      );
    } else if (level <= 60) {
      return const RankTier(
        name: 'Immortal',
        color: Color(0xFF06B6D4),
        gradientColors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
        icon: '💎',
      );
    } else {
      return const RankTier(
        name: 'Transcendent',
        color: Color(0xFFEC4899),
        gradientColors: [Color(0xFFEC4899), Color(0xFFD946EF), Color(0xFF8B5CF6)],
        icon: '🌌',
      );
    }
  }

  int getLevelForXp(int xp) {
    for (int l = 100; l >= 1; l--) {
      if (xp >= levelXpRequirements[l]) {
        return l;
      }
    }
    return 1;
  }

  int getXpForNextLevel(int currentLevel) {
    if (currentLevel >= 100) return levelXpRequirements[100];
    return levelXpRequirements[currentLevel + 1];
  }

  int getXpRequiredInCurrentLevel(int currentLevel) {
    return levelXpRequirements[currentLevel];
  }

  double getLevelProgress(int xp) {
    final l = getLevelForXp(xp);
    if (l >= 100) return 1.0;
    final currentThreshold = levelXpRequirements[l];
    final nextThreshold = levelXpRequirements[l + 1];
    final range = nextThreshold - currentThreshold;
    if (range <= 0) return 0.0;
    return ((xp - currentThreshold) / range).clamp(0.0, 1.0);
  }

  // Day specific states
  final RxBool videoWatchedToday = false.obs;
  final RxBool quizCompletedToday = false.obs;
  final RxInt quizScoreToday = 0.obs;
  final RxInt quizWrongToday = 0.obs;
  final RxBool rewardsClaimedToday = false.obs;

  // Active playing states
  final RxDouble currentVideoWatchProgress = 0.0.obs; // 0.0 to 1.0

  // Category list grouping
  final Map<String, List<String>> categoriesHierarchy = {
    'Engineering': [
      'Computer Science Engineering (CSE)',
      'Information Technology',
      'Artificial Intelligence & Machine Learning',
      'Data Science',
      'Cyber Security',
      'Electronics & Communication',
      'Electrical Engineering',
      'Mechanical Engineering',
      'Civil Engineering',
      'Chemical Engineering',
      'Biotechnology',
      'Automobile Engineering'
    ],
    'Medical': [
      'MBBS',
      'BDS',
      'Nursing',
      'Pharmacy',
      'Physiotherapy'
    ],
    'Management': [
      'MBA',
      'BBA',
      'Finance',
      'HR',
      'Marketing'
    ],
    'Government Exams': [
      'UPSC',
      'SSC',
      'Banking',
      'Railway',
      'State PSC',
      'Police',
      'Defence',
      'Teaching Exams'
    ],
    'Entrance Exams': [
      'JEE',
      'NEET',
      'GATE',
      'CAT',
      'CUET',
      'CLAT'
    ],
    'Coding & Technology': [
      'DSA',
      'Programming',
      'Web Development',
      'App Development',
      'Competitive Programming',
      'Cloud Computing'
    ],
    'School': [
      'Class 9',
      'Class 10',
      'Class 11',
      'Class 12'
    ],
    'General Learning': [
      'Current Affairs',
      'Reasoning',
      'Aptitude',
      'English',
      'Mathematics'
    ]
  };

  // Memory cache of learning packs
  final RxMap<String, CategoryLearningPack> learningPacks = <String, CategoryLearningPack>{}.obs;
  final RxList<Map<String, dynamic>> completionAnalytics = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadState();
    
    try {
      final progCtrl = Get.find<CareerProgressionController>();
      selectedCategory.value = progCtrl.selectedCareer.value;
      userXp.value = progCtrl.idXp.value;
      userLevel.value = progCtrl.idLevel.value;

      progCtrl.selectedCareer.listen((val) {
        selectedCategory.value = val;
        _checkTodayProgress();
      });

      progCtrl.idXp.listen((val) {
        userXp.value = val;
      });

      progCtrl.idLevel.listen((val) {
        userLevel.value = val;
      });
    } catch (_) {}

    ever(selectedCategory, (String? val) async {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'selected_study_category': val})
            .eq('id', CareerProgressionController.currentUserId);
      } catch (_) {}
      UserProgressSyncService.syncToSupabase();
    });

    ever(learningStreak, (int val) async {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'learning_streak': val})
            .eq('id', CareerProgressionController.currentUserId);
      } catch (_) {}
      UserProgressSyncService.syncToSupabase();
    });

    ever(completedTaskIds, (_) => UserProgressSyncService.syncToSupabase());

    ever(unlockedBadges, (List<String> val) async {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'badges': val})
            .eq('id', CareerProgressionController.currentUserId);
      } catch (_) {}
      UserProgressSyncService.syncToSupabase();
    });
  }

  // Load persistence state
  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Sync values from CareerProgressionController if available
    try {
      final progCtrl = Get.find<CareerProgressionController>();
      selectedCategory.value = progCtrl.selectedCareer.value;
      userXp.value = progCtrl.idXp.value;
      userLevel.value = progCtrl.idLevel.value;
    } catch (_) {
      selectedCategory.value = prefs.getString(_keySelectedCategory);
      userXp.value = prefs.getInt(_keyUserXp) ?? 0;
      userLevel.value = prefs.getInt(_keyUserLevel) ?? 1;
    }

    final expiryStr = prefs.getString(_keyLockExpiry);
    if (expiryStr != null) {
      lockExpiry.value = DateTime.tryParse(expiryStr);
    }

    learningStreak.value = prefs.getInt(_keyStreak) ?? 0;
    unlockedBadges.value = prefs.getStringList(_keyBadges) ?? [];

    final List<String>? loadedTaskIds = prefs.getStringList('study_completed_task_ids');
    if (loadedTaskIds != null) {
      completedTaskIds.assignAll(loadedTaskIds);
      // Initialize the status of tasks in memory
      for (final cat in StudyCategoryData.allCategories) {
        for (int i = 0; i < cat.dailyTasks.length; i++) {
          if (completedTaskIds.contains(cat.dailyTasks[i].id)) {
            cat.dailyTasks[i] = cat.dailyTasks[i].copyWith(isCompleted: true);
          }
        }
      }
    }

    xpEarnedToday.value = prefs.getInt(_keyXpEarnedToday) ?? 0;
    xpEarnedThisWeek.value = prefs.getInt(_keyXpEarnedThisWeek) ?? 0;
    xpEarnedThisMonth.value = prefs.getInt(_keyXpEarnedThisMonth) ?? 0;

    final lastDailyStr = prefs.getString(_keyLastDailyReset);
    if (lastDailyStr != null) lastDailyReset.value = DateTime.tryParse(lastDailyStr);
    final lastWeeklyStr = prefs.getString(_keyLastWeeklyReset);
    if (lastWeeklyStr != null) lastWeeklyReset.value = DateTime.tryParse(lastWeeklyStr);
    final lastMonthlyStr = prefs.getString(_keyLastMonthlyReset);
    if (lastMonthlyStr != null) lastMonthlyReset.value = DateTime.tryParse(lastMonthlyStr);

    _checkAndResetXpCaps(prefs);

    // Load custom learning packs
    final customPacksJson = prefs.getString(_keyCustomPacks);
    if (customPacksJson != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(customPacksJson);
        decoded.forEach((key, val) {
          learningPacks[key] = CategoryLearningPack.fromJson(val);
        });
      } catch (_) {}
    }

    // Load completion analytics
    final analyticsJson = prefs.getString(_keyCompletionRates);
    if (analyticsJson != null) {
      try {
        final List<dynamic> list = json.decode(analyticsJson);
        completionAnalytics.assignAll(list.cast<Map<String, dynamic>>());
      } catch (_) {}
    }

    // Check today's progress
    _checkTodayProgress();
  }

  void _checkAndResetXpCaps(SharedPreferences prefs) {
    final now = DateTime.now();

    // 1. Daily Reset Check (resets if day changes)
    if (lastDailyReset.value == null ||
        now.year != lastDailyReset.value!.year ||
        now.month != lastDailyReset.value!.month ||
        now.day != lastDailyReset.value!.day) {
      xpEarnedToday.value = 0;
      lastDailyReset.value = now;
      prefs.setInt(_keyXpEarnedToday, 0);
      prefs.setString(_keyLastDailyReset, now.toIso8601String());

      // Clear completed daily tasks for the new day
      completedTaskIds.clear();
      prefs.setStringList('study_completed_task_ids', []);
      for (final cat in StudyCategoryData.allCategories) {
        for (int i = 0; i < cat.dailyTasks.length; i++) {
          cat.dailyTasks[i] = cat.dailyTasks[i].copyWith(isCompleted: false);
        }
      }
    }

    // 2. Weekly Reset Check (resets if week changes or >= 7 days)
    bool resetWeekly = false;
    if (lastWeeklyReset.value == null) {
      resetWeekly = true;
    } else {
      final daysDiff = now.difference(lastWeeklyReset.value!).inDays;
      if (daysDiff >= 7) {
        resetWeekly = true;
      } else {
        int oldWeekDay = lastWeeklyReset.value!.weekday;
        int newWeekDay = now.weekday;
        if (newWeekDay < oldWeekDay) {
          resetWeekly = true;
        }
      }
    }
    if (resetWeekly) {
      xpEarnedThisWeek.value = 0;
      lastWeeklyReset.value = now;
      prefs.setInt(_keyXpEarnedThisWeek, 0);
      prefs.setString(_keyLastWeeklyReset, now.toIso8601String());
    }

    // 3. Monthly Reset Check (resets if year or month changes)
    if (lastMonthlyReset.value == null ||
        now.year != lastMonthlyReset.value!.year ||
        now.month != lastMonthlyReset.value!.month) {
      xpEarnedThisMonth.value = 0;
      lastMonthlyReset.value = now;
      prefs.setInt(_keyXpEarnedThisMonth, 0);
      prefs.setString(_keyLastMonthlyReset, now.toIso8601String());
    }
  }

  // Check and verify progress for the selected category today
  Future<void> _checkTodayProgress() async {
    final cat = selectedCategory.value;
    if (cat == null) return;

    final prefs = await SharedPreferences.getInstance();
    final dayNum = getActiveDayNumber();
    final prefix = '${_keyProgress}${cat}_$dayNum';

    videoWatchedToday.value = prefs.getBool('${prefix}_video') ?? false;
    quizCompletedToday.value = prefs.getBool('${prefix}_quiz') ?? false;
    quizScoreToday.value = prefs.getInt('${prefix}_score') ?? 0;
    quizWrongToday.value = prefs.getInt('${prefix}_wrong') ?? 0;
    rewardsClaimedToday.value = prefs.getBool('${prefix}_claimed') ?? false;

    // Check if streak was broken (no activity for > 1 day)
    final lastDateStr = prefs.getString(_keyLastCompletedDate);
    if (lastDateStr != null) {
      final lastDate = DateTime.tryParse(lastDateStr);
      if (lastDate != null) {
        final diff = DateTime.now().difference(lastDate).inDays;
        if (diff > 1) {
          learningStreak.value = 0;
          await prefs.setInt(_keyStreak, 0);
        }
      }
    }
  }

  // Get active day index (1-7) based on days since selecting the category
  int getActiveDayNumber() {
    final expiry = lockExpiry.value;
    if (expiry == null) return 1;

    // Select category date = expiry date - 30 days
    final selectDate = expiry.subtract(const Duration(days: 30));
    final diffDays = DateTime.now().difference(selectDate).inDays;
    
    // Cycle between day 1 to 7
    return (diffDays % 7) + 1;
  }

  // Select study category and lock it for 30 days
  Future<void> selectCategoryAndLock(String categoryName) async {
    final prefs = await SharedPreferences.getInstance();
    
    selectedCategory.value = categoryName;
    final expiry = DateTime.now().add(const Duration(days: 30));
    lockExpiry.value = expiry;

    await prefs.setString(_keySelectedCategory, categoryName);
    await prefs.setString(_keyLockExpiry, expiry.toIso8601String());

    // Reset daily progress for new category
    await _checkTodayProgress();
    update();
  }

  // Simulated server time check - Returns time remaining in category change
  Duration get timeUntilCategoryChange {
    final expiry = lockExpiry.value;
    if (expiry == null) return Duration.zero;
    final diff = expiry.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  // Check if category selection is currently locked
  bool get isCategoryLocked {
    if (selectedCategory.value == null) return false;
    final expiry = lockExpiry.value;
    if (expiry == null) return false;
    return expiry.isAfter(DateTime.now());
  }

  // Get today's daily task pack based on active category
  DailyLearningDay getTodayLearningDay() {
    final catName = selectedCategory.value ?? 'General Learning';
    final dayNum = getActiveDayNumber();

    // Check if custom or cache has it
    if (learningPacks.containsKey(catName)) {
      final pack = learningPacks[catName]!;
      final day = pack.days.firstWhereOrNull((d) => d.dayNumber == dayNum);
      if (day != null) return day;
    }

    // Prepopulated or generated fallback
    return _getOrGenerateLearningDay(catName, dayNum);
  }

  // Prepopulated content or smart generator
  DailyLearningDay _getOrGenerateLearningDay(String category, int dayNum) {
    // Generate contents customized to category name
    String youtubeLink = 'https://assets.mixkit.co/videos/preview/mixkit-animation-of-a-man-in-front-of-a-screen-42999-large.mp4'; // fallback mp4
    String title = '$category: Fundamental Concepts';
    String difficulty = 'Medium';
    int xp = 50;
    int coins = 15;

    // Hardcode matching for CSE, NEET, SSC, MBA
    if (category.contains('CSE') || category.toLowerCase() == 'dsa' || category.toLowerCase().contains('computer')) {
      if (dayNum == 1) {
        title = 'Data Structures & Algorithms - Arrays & Hashing';
        difficulty = 'Easy';
        youtubeLink = 'https://assets.mixkit.co/videos/preview/mixkit-writing-computer-code-one-finger-typing-43022-large.mp4';
      } else if (dayNum == 2) {
        title = 'Operating System - CPU Process Scheduling';
        difficulty = 'Medium';
      } else {
        title = 'DBMS - Database Indexing & B-Trees';
        difficulty = 'Hard';
      }
    } else if (category.contains('NEET') || category.toLowerCase() == 'biology' || category.contains('Medical')) {
      title = '$category: Physiology and Bio-Systems';
      youtubeLink = 'https://assets.mixkit.co/videos/preview/mixkit-microscopic-cells-under-a-laser-light-41584-large.mp4';
      difficulty = 'Medium';
    } else if (category.contains('SSC') || category.contains('Government')) {
      title = 'General Studies & Quantitative Reasoning Tricks';
      youtubeLink = 'https://assets.mixkit.co/videos/preview/mixkit-holding-and-showing-a-wooden-pencil-41982-large.mp4';
      difficulty = 'Easy';
    } else if (category.contains('MBA') || category.contains('Management') || category.contains('Finance')) {
      title = 'Business Strategy & Marketing 4Ps Case Study';
      youtubeLink = 'https://assets.mixkit.co/videos/preview/mixkit-businesswoman-analyzing-data-on-a-digital-tablet-42289-large.mp4';
      difficulty = 'Hard';
    }

    final questions = _generateQuestionsFor(category, dayNum);

    return DailyLearningDay(
      dayNumber: dayNum,
      youtubeUrl: youtubeLink,
      videoTitle: title,
      videoDurationSeconds: 300 + (dayNum * 45), // 5 to 10 minutes
      questions: questions,
      xpReward: xp,
      coinReward: coins,
      difficultyLevel: difficulty,
      publishDate: DateTime.now().subtract(Duration(days: dayNum - 1)),
    );
  }

  // Smart question generator
  List<MCQQuestion> _generateQuestionsFor(String category, int dayNum) {
    if (category.contains('CSE') || category.toLowerCase() == 'dsa' || category.toLowerCase().contains('computer')) {
      return [
        MCQQuestion(
          questionText: 'What is the time complexity to access an element in an Array by index?',
          options: ['O(1)', 'O(n)', 'O(log n)', 'O(n log n)'],
          correctAnswerIndex: 0,
          explanation: 'Arrays store elements contiguously in memory, allowing constant time O(1) access via index multiplication.',
        ),
        MCQQuestion(
          questionText: 'Which data structure follows the Last-In-First-Out (LIFO) principle?',
          options: ['Queue', 'Linked List', 'Stack', 'Tree'],
          correctAnswerIndex: 2,
          explanation: 'A Stack is a LIFO data structure where the last element inserted is the first one to be removed.',
        ),
        MCQQuestion(
          questionText: 'What is the worst-case time complexity of Quick Sort?',
          options: ['O(n)', 'O(n log n)', 'O(n²)', 'O(2^n)'],
          correctAnswerIndex: 2,
          explanation: 'Quick Sort degrades to O(n²) worst-case when the pivot chosen is consistently the smallest or largest element.',
        ),
        MCQQuestion(
          questionText: 'Which of the following is NOT a dynamic memory data structure?',
          options: ['Singly Linked List', 'Static Array', 'Binary Search Tree', 'Hash Map'],
          correctAnswerIndex: 1,
          explanation: 'Static Arrays have their sizes defined at compile-time and cannot dynamically expand or shrink.',
        ),
        MCQQuestion(
          questionText: 'What is the main advantage of a Hash Table?',
          options: ['Elements are sorted', 'Memory efficient', 'Fast Search/Insert O(1)', 'Uses recursion'],
          correctAnswerIndex: 2,
          explanation: 'A hash table maps keys to values using a hashing function, allowing search, insertion, and deletion in average O(1) time.',
        ),
      ];
    }

    if (category.contains('NEET') || category.toLowerCase() == 'biology' || category.contains('Medical')) {
      return [
        MCQQuestion(
          questionText: 'Which cell organelle is known as the Powerhouse of the Cell?',
          options: ['Golgi Apparatus', 'Mitochondria', 'Nucleus', 'Ribosome'],
          correctAnswerIndex: 1,
          explanation: 'Mitochondria are responsible for cellular respiration and producing ATP, the energy currency of cells.',
        ),
        MCQQuestion(
          questionText: 'What is the primary function of Red Blood Cells (RBCs)?',
          options: ['Produce antibodies', 'Clot blood', 'Transport oxygen', 'Synthesize proteins'],
          correctAnswerIndex: 2,
          explanation: 'Hemoglobin in red blood cells binds to oxygen and transports it from lungs to tissues throughout the body.',
        ),
        MCQQuestion(
          questionText: 'How many chambers does a human heart have?',
          options: ['Two', 'Three', 'Four', 'Five'],
          correctAnswerIndex: 2,
          explanation: 'The human heart has 4 chambers: two atria (upper chambers) and two ventricles (lower chambers).',
        ),
        MCQQuestion(
          questionText: 'Which hormone regulates glucose levels in human blood?',
          options: ['Adrenaline', 'Thyroxine', 'Insulin', 'Estrogen'],
          correctAnswerIndex: 2,
          explanation: 'Insulin, secreted by the beta cells of pancreas, allows cells to take in glucose, lowering blood sugar.',
        ),
        MCQQuestion(
          questionText: 'What is the functional unit of the human kidney?',
          options: ['Neuron', 'Nephron', 'Axon', 'Alveolus'],
          correctAnswerIndex: 1,
          explanation: 'The nephron is the microscopic structural and functional unit of the kidney, responsible for filtering blood.',
        ),
      ];
    }

    // Default general learning questions
    return [
      MCQQuestion(
        questionText: 'Which country is the largest by land area?',
        options: ['Canada', 'China', 'Russia', 'United States'],
        correctAnswerIndex: 2,
        explanation: 'Russia is the largest country in the world, covering over 17 million square kilometers.',
      ),
      MCQQuestion(
        questionText: 'What is the value of Pi (up to 2 decimal places)?',
        options: ['3.12', '3.14', '3.16', '3.18'],
        correctAnswerIndex: 1,
        explanation: 'Pi is a mathematical constant defined as ratio of circle\'s circumference to its diameter, approx 3.14159...',
      ),
      MCQQuestion(
        questionText: 'Identify the odd one out in this list.',
        options: ['Apple', 'Carrot', 'Banana', 'Orange'],
        correctAnswerIndex: 1,
        explanation: 'Carrot is a root vegetable, whereas Apple, Banana, and Orange are fruits.',
      ),
      MCQQuestion(
        questionText: 'Which gaseous element makes up about 78% of Earth\'s atmosphere?',
        options: ['Oxygen', 'Carbon Dioxide', 'Hydrogen', 'Nitrogen'],
        correctAnswerIndex: 3,
        explanation: 'Earth\'s atmosphere is composed of approx 78% Nitrogen, 21% Oxygen, and small amounts of other gases.',
      ),
      MCQQuestion(
        questionText: 'What is the synonym of the word "Meticulous"?',
        options: ['Careless', 'Speedy', 'Extremely Precise', 'Friendly'],
        correctAnswerIndex: 2,
        explanation: 'Meticulous means showing great attention to detail; very careful and precise.',
      ),
    ];
  }

  // Mark video as watched today
  Future<void> markVideoWatched() async {
    final cat = selectedCategory.value;
    if (cat == null) return;

    final prefs = await SharedPreferences.getInstance();
    final dayNum = getActiveDayNumber();
    final prefix = '${_keyProgress}${cat}_$dayNum';

    videoWatchedToday.value = true;
    await prefs.setBool('${prefix}_video', true);
    update();
  }

  // Complete Quiz submission
  Future<void> submitQuiz(int score, int wrong) async {
    final cat = selectedCategory.value;
    if (cat == null) return;

    final prefs = await SharedPreferences.getInstance();
    final dayNum = getActiveDayNumber();
    final prefix = '${_keyProgress}${cat}_$dayNum';

    quizCompletedToday.value = true;
    quizScoreToday.value = score;
    quizWrongToday.value = wrong;

    await prefs.setBool('${prefix}_quiz', true);
    await prefs.setInt('${prefix}_score', score);
    await prefs.setInt('${prefix}_wrong', wrong);

    // Calculate Rewards
    int xpEarned = score * 10;
    int coinsEarned = score * 5;
    bool perfectScore = (score == 5);

    if (perfectScore) {
      xpEarned += 20; // perfect score bonus
      coinsEarned += 25; // perfect score bonus
      // Unlock badge
      if (!unlockedBadges.contains('perfect_learner')) {
        unlockedBadges.add('perfect_learner');
        await prefs.setStringList(_keyBadges, unlockedBadges);
      }
    }

    // Apply Rewards
    final actualXpGranted = await addXp(xpEarned, source: 'Daily Quiz');
    silverCoins.value += coinsEarned;

    // Update streak
    final lastDateStr = prefs.getString(_keyLastCompletedDate);
    final todayStr = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    
    if (lastDateStr == null) {
      learningStreak.value = 1;
    } else {
      final lastDate = DateTime.parse(lastDateStr);
      final daysDiff = DateTime.now().difference(lastDate).inDays;
      if (daysDiff == 1) {
        learningStreak.value += 1;
      } else if (daysDiff > 1) {
        learningStreak.value = 1;
      }
    }
    
    await prefs.setInt(_keyStreak, learningStreak.value);
    await prefs.setString(_keyLastCompletedDate, DateTime.now().toIso8601String());

    rewardsClaimedToday.value = true;
    await prefs.setBool('${prefix}_claimed', true);

    // Save analytics
    final analyticsRecord = {
      'date': DateTime.now().toIso8601String(),
      'category': cat,
      'day': dayNum,
      'score': score,
      'wrong': wrong,
      'xpGained': xpEarned,
      'coinsGained': coinsEarned,
      'perfect': perfectScore
    };
    completionAnalytics.add(analyticsRecord);
    await prefs.setString(_keyCompletionRates, json.encode(completionAnalytics));

    update();
  }

  // Secure XP addition with daily, weekly, and monthly limits
  Future<int> addXp(int amount, {required String source}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Ensure limits are reset if calendar day/week/month changed
    _checkAndResetXpCaps(prefs);

    // Calculate how much XP we can add based on limits
    int allowedToday = 300 - xpEarnedToday.value;
    int allowedThisWeek = 2000 - xpEarnedThisWeek.value;
    int allowedThisMonth = 8000 - xpEarnedThisMonth.value;

    int maxAllowed = allowedToday;
    if (allowedThisWeek < maxAllowed) maxAllowed = allowedThisWeek;
    if (allowedThisMonth < maxAllowed) maxAllowed = allowedThisMonth;

    if (maxAllowed <= 0) {
      // Limit reached, user earns 0 XP but still gets badges / coins elsewhere
      return 0;
    }

    int xpToGained = amount;
    if (xpToGained > maxAllowed) {
      xpToGained = maxAllowed;
    }

    if (xpToGained <= 0) return 0;

    // Apply XP
    int oldLevel = userLevel.value;
    
    // Sync with CareerProgressionController
    try {
      final progCtrl = Get.find<CareerProgressionController>();
      final cleanActionId = source.toLowerCase().replaceAll(' ', '_');
      
      // Award both ID XP (Global) and Career XP!
      await progCtrl.addXp(cleanActionId, xpToGained, false); // ID Level
      await progCtrl.addXp(cleanActionId, xpToGained, true);  // Career Level
      
      userXp.value = progCtrl.idXp.value;
      userLevel.value = progCtrl.idLevel.value;
    } catch (_) {
      // Fallback
      userXp.value += xpToGained;
      userLevel.value = getLevelForXp(userXp.value);
    }
    
    xpEarnedToday.value += xpToGained;
    xpEarnedThisWeek.value += xpToGained;
    xpEarnedThisMonth.value += xpToGained;

    // Persist local reset states
    await prefs.setInt(_keyUserXp, userXp.value);
    await prefs.setInt(_keyUserLevel, userLevel.value);
    await prefs.setInt(_keyXpEarnedToday, xpEarnedToday.value);
    await prefs.setInt(_keyXpEarnedThisWeek, xpEarnedThisWeek.value);
    await prefs.setInt(_keyXpEarnedThisMonth, xpEarnedThisMonth.value);

    // Level up check (if synced ID Level increased)
    if (userLevel.value > oldLevel) {
      await prefs.setInt(_keyUserLevel, userLevel.value);
      _grantLevelUpRewards(oldLevel, userLevel.value);
    }

    update();
    return xpToGained;
  }

  Future<void> _grantLevelUpRewards(int oldLevel, int newLevel) async {
    final prefs = await SharedPreferences.getInstance();
    
    int totalCoinsGranted = 0;
    List<String> unlockedItems = [];

    for (int l = oldLevel + 1; l <= newLevel; l++) {
      // 1. Every Level reward
      totalCoinsGranted += l * 20;

      // 2. Every 5 Levels reward (but not 10 levels)
      if (l % 5 == 0 && l % 10 != 0) {
        totalCoinsGranted += 100;
        unlockedItems.add('Frame Upgrade Tier ${l ~/ 5}');
        unlockedItems.add('Chat Bubble Style $l');
        unlockedItems.add('Profile Decor $l');
      }

      // 3. Every 10 Levels reward
      if (l % 10 == 0) {
        totalCoinsGranted += 300;
        unlockedItems.add('Animated Frame Tier ${l ~/ 10}');
        unlockedItems.add('Exclusive Badge Level $l');
        unlockedItems.add('Username Effect $l');
        unlockedItems.add('Entrance Animation $l');
        unlockedItems.add('${getTierForLevel(l).name} Rank Title');
        
        final badgeId = 'level_badge_$l';
        if (!unlockedBadges.contains(badgeId)) {
          unlockedBadges.add(badgeId);
        }
      }
    }

    // Award silver coins
    silverCoins.value += totalCoinsGranted;
    await prefs.setStringList(_keyBadges, unlockedBadges);

    // Show Level Up Dialog
    Future.delayed(const Duration(milliseconds: 500), () {
      Get.dialog(
        LevelUpDialog(
          oldLevel: oldLevel,
          newLevel: newLevel,
          coinsEarned: totalCoinsGranted,
          unlockedItems: unlockedItems,
        ),
        barrierDismissible: false,
      );
    });
  }

  // Admin: Update/Create daily pack for a specific category
  Future<void> adminSavePack(String categoryId, DailyLearningDay day) async {
    final prefs = await SharedPreferences.getInstance();
    
    CategoryLearningPack pack = learningPacks[categoryId] ?? CategoryLearningPack(categoryId: categoryId, days: []);
    
    // Remove existing day if matching
    final List<DailyLearningDay> updatedDays = List.from(pack.days);
    updatedDays.removeWhere((d) => d.dayNumber == day.dayNumber);
    updatedDays.add(day);
    
    final updatedPack = CategoryLearningPack(categoryId: categoryId, days: updatedDays);
    learningPacks[categoryId] = updatedPack;

    // Serialize all custom packs
    final Map<String, dynamic> serialized = {};
    learningPacks.forEach((key, val) {
      serialized[key] = val.toJson();
    });
    await prefs.setString(_keyCustomPacks, json.encode(serialized));
    
    // Refresh today's progress if active category is edited
    if (selectedCategory.value == categoryId) {
      await _checkTodayProgress();
    }
    
    update();
  }

  // Get Analytics stats
  int get totalCompletedMissions => completionAnalytics.length;
  
  double get averageScore {
    if (completionAnalytics.isEmpty) return 0.0;
    final total = completionAnalytics.fold<int>(0, (sum, r) => sum + (r['score'] as int));
    return total / completionAnalytics.length;
  }
  
  double get completionRatePercentage {
    // Simulated based on total entries out of 7 days
    if (completionAnalytics.isEmpty) return 0.0;
    return (completionAnalytics.length / 7.0 * 100).clamp(0, 100);
  }

  int get perfectScoreCount => completionAnalytics.where((r) => r['perfect'] == true).length;

  Future<void> completeDailyTask(String categoryId, String taskId, int xpReward, int coinReward) async {
    if (!completedTaskIds.contains(taskId)) {
      completedTaskIds.add(taskId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('study_completed_task_ids', completedTaskIds);
      
      // Update the static allCategories in memory
      for (final cat in StudyCategoryData.allCategories) {
        final idx = cat.dailyTasks.indexWhere((t) => t.id == taskId);
        if (idx != -1) {
          cat.dailyTasks[idx] = cat.dailyTasks[idx].copyWith(isCompleted: true);
        }
      }
      
      // Add XP via CareerProgressionController (if available)
      try {
        final progCtrl = Get.find<CareerProgressionController>();
        await progCtrl.addXp(taskId, xpReward, false);
      } catch (_) {
        // Fallback if not registered
        userXp.value += xpReward;
        while (userLevel.value < levelXpRequirements.length - 1 &&
               userXp.value >= levelXpRequirements[userLevel.value + 1]) {
          userLevel.value += 1;
        }
        await prefs.setInt('study_user_xp', userXp.value);
        await prefs.setInt('study_user_level', userLevel.value);
      }
      
      // Add Coins (Syncing to StoreController's silverCoinsBalance)
      final storeCtrl = Get.find<StoreController>();
      storeCtrl.silverCoinsBalance.value += coinReward;
    }
  }
}
