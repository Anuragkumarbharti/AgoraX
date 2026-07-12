import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/index.dart';
import '../../services/study_category_controller.dart';
import '../../services/career_progression_controller.dart';
import '../../services/career_daily_controller.dart';
import '../../services/id_daily_controller.dart';
import '../../widgets/custom_youtube_player.dart';
import 'category_selection_screen.dart';
import 'mcq_quiz_screen.dart';
import 'quiz_result_screen.dart';

class DailyTaskScreen extends StatefulWidget {
  final String? initialCategory;
  const DailyTaskScreen({Key? key, this.initialCategory}) : super(key: key);

  @override
  State<DailyTaskScreen> createState() => _DailyTaskScreenState();
}

class _DailyTaskScreenState extends State<DailyTaskScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  final StudyCategoryController _studyCtrl = Get.find<StudyCategoryController>();
  final CareerProgressionController _progressCtrl = Get.find<CareerProgressionController>();
  final CareerDailyController _careerDailyCtrl = Get.find<CareerDailyController>();
  final IdDailyController _idDailyCtrl = Get.find<IdDailyController>();
  final List<StudyCategory> _categories = StudyCategoryData.allCategories;
  StudyCategory? _activeCategory;
  String _selectedTab = 'daily'; // daily | weekly | monthly | leaderboard | roadmap
  String _taskCategory = 'career'; // career | id

  late Timer _resetTimer;
  final RxString _resetTimerText = ''.obs;


  String _getResetTimerString() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final diff = midnight.difference(now);
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _taskCategory = widget.initialCategory!;
    }
    _resetTimerText.value = _getResetTimerString();
    _resetTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _resetTimerText.value = _getResetTimerString();
    });
    _tabController = TabController(length: 5, vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _activeCategory = _categories.firstWhereOrNull((c) => c.isSelected);
    _activeCategory ??= _categories.first;
  }

  @override
  void dispose() {
    _resetTimer.cancel();
    _tabController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  StudyCategory _getActiveCategory() {
    final selectedName = _studyCtrl.selectedCategory.value;
    final cat = _categories.firstWhereOrNull((c) => c.name == selectedName || c.id == selectedName);
    if (cat != null) {
      cat.level = _studyCtrl.userLevel.value;
      cat.xp = _studyCtrl.userXp.value % 1000;
      cat.coins = _studyCtrl.silverCoins.value;
      cat.streak = _studyCtrl.learningStreak.value;
      return cat;
    }
    return StudyCategory(
      id: 'custom_cat',
      name: selectedName ?? 'General Learning',
      icon: 'school',
      emoji: '🧠',
      color: AppTheme.primaryColor,
      gradientColors: [AppTheme.primaryColor, AppTheme.secondaryColor],
      description: 'Your personalized study path',
      tags: [],
      levelTitles: [const LevelTitle(minLevel: 1, title: 'Learner', icon: '🌱')],
      badges: [],
      level: _studyCtrl.userLevel.value,
      xp: _studyCtrl.userXp.value % 1000,
      totalXpForNextLevel: 1000,
      coins: _studyCtrl.silverCoins.value,
      streak: _studyCtrl.learningStreak.value,
      isSelected: true,
    );
  }

  Widget _buildLockedView() {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppTheme.primaryColor,
                  size: 48,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Daily Learning Locked',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Please select your study category first to unlock personalized videos, quizzes, current affairs, XP rewards, Silver Coins, and learning progress.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Get.to(() => const CategorySelectionScreen(canGoBack: false));
                  },
                  child: const Text(
                    'Select Study Category',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rewardBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasSelected = _studyCtrl.selectedCategory.value != null;
      if (!hasSelected) {
        return _buildLockedView();
      }

      // Load active category
      _activeCategory = _getActiveCategory();

      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: NestedScrollView(
          headerSliverBuilder: (ctx, _) => [
            _buildSliverHeader(),
          ],
          body: Column(
            children: [
              _buildCategoryScroll(),
              _buildSubTabBar(),
              Expanded(child: _buildTabContent()),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 260,
      backgroundColor: AppTheme.bgDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _buildHeaderBanner(),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    final isCareer = _taskCategory == 'career';
    final level = isCareer ? _careerDailyCtrl.careerLevel.value : _idDailyCtrl.idLevel.value;
    final streak = isCareer ? _careerDailyCtrl.careerStreak.value : _idDailyCtrl.idStreak.value;
    
    final tier = StudyCategoryController.getTierForLevel(level);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tier.color.withOpacity(0.9),
            tier.color.withOpacity(0.5),
            AppTheme.bgDark,
          ],
          stops: const [0, 0.6, 1],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(isCareer ? '🎓' : '🌱', style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCareer ? 'Career Daily Hub' : 'ID Daily Hub',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          isCareer
                              ? 'Skill development and academic progression'
                              : 'Community interaction and engagement levels',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _headerStat('⚡ Level', '$level', tier.color),
                  const SizedBox(width: 8),
                  _headerStat('🔥 Streak', '${streak}d', const Color(0xFFF97316)),
                  const SizedBox(width: 8),
                  _headerStat('🪙 Coins', '${_studyCtrl.silverCoins.value}', const Color(0xFFFBBF24)),
                  const SizedBox(width: 8),
                  Obx(() => _headerStat('⏳ Reset', _resetTimerText.value, const Color(0xFF10B981))),
                ],
              ),
              const SizedBox(height: 14),
              _buildXpBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildXpBar() {
    final isCareer = _taskCategory == 'career';
    final xp = isCareer ? _careerDailyCtrl.careerXp.value : _idDailyCtrl.idXp.value;
    final level = isCareer ? _careerDailyCtrl.careerLevel.value : _idDailyCtrl.idLevel.value;
    
    final currentThreshold = isCareer 
        ? _careerDailyCtrl.xpRequiredForCareerLevel(level)
        : _idDailyCtrl.xpRequiredForIdLevel(level);
        
    final nextThreshold = isCareer 
        ? _careerDailyCtrl.xpRequiredForCareerLevel(level + 1)
        : _idDailyCtrl.xpRequiredForIdLevel(level + 1);
        
    final range = nextThreshold - currentThreshold;
    final progress = range > 0 ? ((xp - currentThreshold) / range).clamp(0.0, 1.0) : 0.0;
    final tier = StudyCategoryController.getTierForLevel(level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${tier.icon} ${tier.name} Tier',
              style: TextStyle(
                  color: tier.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
            Text(
              '${xp - currentThreshold} / ${nextThreshold - currentThreshold} XP',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AnimatedBuilder(
            animation: _shimmerController,
            builder: (ctx, _) {
              return Stack(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation(tier.color),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Category Scroll ──────────────────────────────────────────────────────

  Widget _buildCategoryScroll() {
    final activeCat = _getActiveCategory();
    final timeRemaining = _studyCtrl.timeUntilCategoryChange;
    final formattedTime = '${timeRemaining.inDays}d ${timeRemaining.inHours % 24}h remaining';

    return Container(
      height: 72,
      color: AppTheme.bgDark,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Active Locked Category Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: activeCat.gradientColors),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(activeCat.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  activeCat.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.lock_rounded, color: Colors.white, size: 14),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Timer card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, color: AppTheme.textSecondary, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Lock: $formattedTime',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sub Tab Bar ──────────────────────────────────────────────────────────

  Widget _buildSubTabBar() {
    final tabs = [
      ('daily', Icons.today_outlined, 'Daily'),
      ('weekly', Icons.calendar_view_week_outlined, 'Weekly'),
      ('monthly', Icons.calendar_month_outlined, 'Monthly'),
      ('leaderboard', Icons.leaderboard_outlined, 'Leaders'),
      ('roadmap', Icons.map_outlined, 'Roadmap'),
    ];
    return Container(
      height: 50,
      color: AppTheme.bgDark,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: tabs.map((t) {
            final isSelected = _selectedTab == t.$1;
            return GestureDetector(
              onTap: () => setState(() => _selectedTab = t.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.bgLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.borderColor,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.$2,
                        size: 14,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textTertiary),
                    const SizedBox(width: 5),
                    Text(
                      t.$3,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textTertiary,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Tab Content ──────────────────────────────────────────────────────────

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'daily':
        return _buildDailyTasks();
      case 'weekly':
        return _buildWeeklyContent();
      case 'monthly':
        return _buildMonthlyContent();
      case 'leaderboard':
        return _buildLeaderboard();
      case 'roadmap':
        return _buildRoadmap();
      default:
        return _buildDailyTasks();
    }
  }

  // ─── Daily Tasks ──────────────────────────────────────────────────────────

  Widget _buildDailyTasks() {
    final cat = _activeCategory!;
    final todayPack = _studyCtrl.getTodayLearningDay();

    return Obx(() {
      final isVideoWatched = _studyCtrl.videoWatchedToday.value;
      final isQuizDone = _studyCtrl.quizCompletedToday.value;
      final score = _studyCtrl.quizScoreToday.value;

      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Selector for Career Tasks vs ID Tasks
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _taskCategory = 'career'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _taskCategory == 'career'
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Career Daily Tasks',
                          style: TextStyle(
                            color: _taskCategory == 'career' ? Colors.white : AppTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _taskCategory = 'id'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _taskCategory == 'id'
                            ? AppTheme.accentColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'ID Daily Tasks',
                          style: TextStyle(
                            color: _taskCategory == 'id' ? Colors.white : AppTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Render backend dynamic tasks
          Obx(() {
            final isCareer = _taskCategory == 'career';
            final tasks = isCareer ? _careerDailyCtrl.tasks : _idDailyCtrl.tasks;
            final isLoading = isCareer ? _careerDailyCtrl.isLoading.value : _idDailyCtrl.isLoading.value;
            if (isLoading) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
              );
            }
            if (tasks.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'No tasks available for today.',
                    style: GoogleFonts.poppins(color: AppTheme.textTertiary, fontSize: 13),
                  ),
                ),
              );
            }

            return Column(
              children: tasks.map((t) => _buildTaskCard(t)).toList(),
            );
          }),
          const SizedBox(height: 24),
          const Divider(color: AppTheme.borderColor),
          const SizedBox(height: 16),
          // Step 1: Video Card
          const Text(
            'Step 1: Watch Today\'s YouTube Video',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          
          CustomYoutubePlayer(
            videoUrl: todayPack.youtubeUrl,
            videoTitle: todayPack.videoTitle,
            durationSeconds: todayPack.videoDurationSeconds,
            onWatchCompleted: () {
              _studyCtrl.markVideoWatched();
            },
          ),
          
          const SizedBox(height: 24),
          const Divider(color: AppTheme.borderColor),
          const SizedBox(height: 16),

          // Step 2: Timed Quiz Card
          const Text(
            'Step 2: Complete Today\'s Learning Quiz',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isQuizDone
                    ? AppTheme.accentColor.withOpacity(0.3)
                    : isVideoWatched
                        ? AppTheme.primaryColor.withOpacity(0.3)
                        : AppTheme.borderColor.withOpacity(0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isQuizDone
                            ? AppTheme.accentColor.withOpacity(0.12)
                            : isVideoWatched
                                ? AppTheme.primaryColor.withOpacity(0.12)
                                : Colors.white10,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isQuizDone
                            ? Icons.check_circle_outline
                            : isVideoWatched
                                ? Icons.quiz_outlined
                                : Icons.lock_outline_rounded,
                        color: isQuizDone
                            ? AppTheme.accentColor
                            : isVideoWatched
                                ? AppTheme.primaryColor
                                : AppTheme.textTertiary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isQuizDone ? 'Quiz Completed' : '5 MCQ Learning Quiz',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isQuizDone 
                                ? 'Score: $score / 5 Correct Answers' 
                                : 'Test your understanding of today\'s video lessons.',
                            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                if (isQuizDone) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.borderColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Get.to(() => QuizResultScreen(
                                    dailyDay: todayPack,
                                    userAnswers: const {},
                                    cheated: false,
                                  ));
                            },
                            child: const Text('Review Answers', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isVideoWatched ? AppTheme.primaryColor : AppTheme.borderColor.withOpacity(0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: isVideoWatched
                          ? () {
                              Get.to(() => MCQQuizScreen(dailyDay: todayPack));
                            }
                          : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isVideoWatched) ...[
                            const Icon(Icons.lock, size: 14, color: AppTheme.textTertiary),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            isVideoWatched ? 'Start Daily Task  →' : 'Watch Video to Unlock Quiz',
                            style: TextStyle(
                              color: isVideoWatched ? Colors.white : AppTheme.textTertiary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          const Divider(color: AppTheme.borderColor),
          const SizedBox(height: 16),
          
          // Difficulty / Reward summary bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardBg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _rewardBadge('⚡ +${todayPack.xpReward} XP', const Color(0xFF6366F1)),
                _rewardBadge('🪙 +${todayPack.coinReward} Coins', const Color(0xFFFBBF24)),
                _rewardBadge('Difficulty: ${todayPack.difficultyLevel}', AppTheme.primaryColor),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      );
    });
  }

  // ─── Weekly Content ───────────────────────────────────────────────────────

  Widget _buildWeeklyContent() {
    final weeklyChallenges = [
      {
        'title': 'LeetCode Weekly Sprint',
        'desc': 'Solve 7 coding problems this week — Easy to Hard progression',
        'progress': 3,
        'total': 7,
        'xp': 500,
        'coins': 100,
        'daysLeft': 4,
        'color': const Color(0xFF6366F1),
      },
      {
        'title': 'Mock Interview Marathon',
        'desc': 'Complete 5 mock interview sessions with AI feedback',
        'progress': 2,
        'total': 5,
        'xp': 350,
        'coins': 75,
        'daysLeft': 4,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'System Design Deep Dive',
        'desc': 'Study 3 real-world system designs: Netflix, Uber, Whatsapp',
        'progress': 1,
        'total': 3,
        'xp': 300,
        'coins': 60,
        'daysLeft': 4,
        'color': const Color(0xFFF59E0B),
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('📅 Weekly Challenges', 'Resets every Sunday'),
        const SizedBox(height: 12),
        ...weeklyChallenges.map((c) => _buildWeeklyCard(c)),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildWeeklyCard(Map<String, dynamic> c) {
    final progress = (c['progress'] as int) / (c['total'] as int);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: (c['color'] as Color).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (c['color'] as Color).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${c['daysLeft']}d left',
                  style: TextStyle(
                      color: c['color'] as Color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              Text('⚡${c['xp']} XP  🪙${c['coins']}',
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Text(c['title'] as String,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(c['desc'] as String,
              style: const TextStyle(
                  color: AppTheme.textTertiary, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppTheme.borderColor,
                    valueColor: AlwaysStoppedAnimation(c['color'] as Color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${c['progress']}/${c['total']}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Monthly Content ──────────────────────────────────────────────────────

  Widget _buildMonthlyContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('🏆 Monthly Grand Challenge', 'July 2026'),
        const SizedBox(height: 12),
        _buildMonthlyGrandCard(),
        const SizedBox(height: 20),
        _sectionHeader('📊 Monthly Stats', ''),
        const SizedBox(height: 12),
        _buildMonthlyStats(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildMonthlyGrandCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFD97706)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🏆', style: TextStyle(fontSize: 32)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Grand Challenge: Code War',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    Text('Compete with 10,000+ participants',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Complete 30 coding challenges this month. Top 100 win certificates, featured profiles & internship referrals.',
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _monthlyRewardChip('🎓 Certificate'),
              const SizedBox(width: 8),
              _monthlyRewardChip('💼 Internship'),
              const SizedBox(width: 8),
              _monthlyRewardChip('👑 VIP Badge'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text(
                'Join Challenge  →',
                style: TextStyle(
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w800,
                    fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthlyRewardChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildMonthlyStats() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _monthlyStatCard('Tasks Completed', '87', Icons.task_alt_rounded, const Color(0xFF10B981)),
        _monthlyStatCard('XP Earned', '4,350', Icons.bolt, const Color(0xFF6366F1)),
        _monthlyStatCard('Streak Record', '12 days', Icons.local_fire_department, const Color(0xFFF97316)),
        _monthlyStatCard('Rank Climbed', '+234', Icons.trending_up_rounded, const Color(0xFFFBBF24)),
      ],
    );
  }

  Widget _monthlyStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textTertiary, fontSize: 11)),
        ],
      ),
    );
  }

  // ─── Leaderboard ──────────────────────────────────────────────────────────

  Widget _buildLeaderboard() {
    final leaderboardData = List.generate(
      10,
      (i) => {
        'rank': i + 1,
        'name': [
          'Arjun Sharma', 'Priya Singh', 'Rahul Kumar', 'Sneha Gupta',
          'Aditya Dev', 'Riya Patel', 'Vikram Rao', 'Ananya Bose',
          'Karan Shah', 'Deepika Nair',
        ][i],
        'xp': 9800 - i * 780,
        'level': 15 - i,
        'streak': 20 - i * 2,
        'badge': ['👑', '🥈', '🥉', '⭐', '⭐', '⭐', '⭐', '⭐', '⭐', '⭐'][i],
        'isMe': i == 4,
      },
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('🏆 Leaderboard', _activeCategory!.name),
        const SizedBox(height: 12),
        // Top 3 podium
        _buildPodium(leaderboardData.take(3).toList()),
        const SizedBox(height: 16),
        // Rest of rankings
        ...leaderboardData.skip(3).map((d) => _buildRankRow(d)),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> top3) {
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd
          Expanded(child: _podiumItem(top3[1], 120, const Color(0xFF94A3B8))),
          // 1st
          Expanded(
            child: _podiumItem(top3[0], 155, const Color(0xFFFBBF24)),
          ),
          // 3rd
          Expanded(
              child: _podiumItem(top3[2], 100, const Color(0xFFCD7F32))),
        ],
      ),
    );
  }

  Widget _podiumItem(Map<String, dynamic> data, double height, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(data['badge'] as String,
            style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          (data['name'] as String).split(' ').first,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text('Lv.${data['level']}',
            style: const TextStyle(
                color: AppTheme.textTertiary, fontSize: 9)),
        const SizedBox(height: 6),
        Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Center(
            child: Text(
              '#${data['rank']}',
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankRow(Map<String, dynamic> data) {
    final isMe = data['isMe'] as bool;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe
            ? AppTheme.primaryColor.withOpacity(0.1)
            : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? AppTheme.primaryColor.withOpacity(0.3)
              : AppTheme.borderColor.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#${data['rank']}',
              style: TextStyle(
                color: isMe
                    ? AppTheme.primaryColor
                    : AppTheme.textTertiary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
            child: Text(
              (data['name'] as String).substring(0, 1),
              style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      data['name'] as String,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      const Text('(You)',
                          style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
                Text('Lv.${data['level']}  🔥${data['streak']}d streak',
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 11)),
              ],
            ),
          ),
          Text(
            '${data['xp']} XP',
            style: TextStyle(
              color: isMe
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Roadmap ──────────────────────────────────────────────────────────────

  Widget _buildRoadmap() {
    final cat = _activeCategory!;
    final roadmapSteps = cat.levelTitles;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('🗺️ Career Roadmap', cat.name),
        const SizedBox(height: 16),
        ...roadmapSteps.asMap().entries.map((e) {
          final idx = e.key;
          final step = e.value;
          final isUnlocked = cat.level >= step.minLevel;
          final isCurrent = idx < roadmapSteps.length - 1
              ? cat.level >= step.minLevel &&
                  cat.level < roadmapSteps[idx + 1].minLevel
              : cat.level >= step.minLevel;
          return _buildRoadmapStep(step, isUnlocked, isCurrent,
              idx < roadmapSteps.length - 1, cat.color);
        }),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildRoadmapStep(LevelTitle step, bool isUnlocked, bool isCurrent,
      bool hasConnector, Color color) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon column
            Column(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (ctx, _) {
                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isUnlocked
                            ? color.withOpacity(isCurrent
                                ? 0.3 + 0.1 * _pulseController.value
                                : 0.2)
                            : AppTheme.bgLight,
                        border: Border.all(
                          color: isUnlocked
                              ? color
                              : AppTheme.borderColor,
                          width: isCurrent ? 2.5 : 1.5,
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(
                                      0.3 * _pulseController.value),
                                  blurRadius: 12,
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(step.icon,
                            style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  },
                ),
                if (hasConnector)
                  Container(
                    width: 2,
                    height: 40,
                    color: isUnlocked
                        ? color.withOpacity(0.4)
                        : AppTheme.borderColor,
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? color.withOpacity(0.07)
                      : AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isUnlocked
                        ? color.withOpacity(0.25)
                        : AppTheme.borderColor.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          step.title,
                          style: TextStyle(
                            color: isUnlocked
                                ? AppTheme.textPrimary
                                : AppTheme.textTertiary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isUnlocked
                                ? color.withOpacity(0.15)
                                : AppTheme.bgLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isUnlocked
                                ? (isCurrent ? '📍 Current' : '✅ Unlocked')
                                : '🔒 Lv.${step.minLevel}',
                            style: TextStyle(
                              color: isUnlocked
                                  ? (isCurrent ? color : AppTheme.accentColor)
                                  : AppTheme.textTertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isCurrent) ...[
                      const SizedBox(height: 6),
                      Text(
                        'You are here! Keep going 🚀',
                        style: TextStyle(
                            color: color, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        if (subtitle.isNotEmpty)
          Text(subtitle,
              style: const TextStyle(
                  color: AppTheme.textTertiary, fontSize: 12)),
      ],
    );
  }

  void _openTask(DailyTask task, StudyCategory cat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgLight,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.borderColor,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: task.type.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(task.type.icon,
                      color: task.type.color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.type.label,
                          style: TextStyle(
                              color: task.type.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                      Text(task.title,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgDark,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(task.description,
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.6)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _rewardChip('⚡ +${task.xpReward} XP', const Color(0xFF6366F1)),
                const SizedBox(width: 10),
                _rewardChip('🪙 +${task.coinReward} Coins', const Color(0xFFFBBF24)),
                if (task.timeLimit != null) ...[
                  const SizedBox(width: 10),
                  _rewardChip('⏱ ${task.timeLimit}m Limit', const Color(0xFFEF4444)),
                ],
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: task.type.color,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _studyCtrl.completeDailyTask(cat.id, task.id, task.xpReward, task.coinReward).then((_) {
                    setState(() {});
                  });
                  Get.snackbar(
                    '🎉 Task Completed!',
                    'You earned ⚡${task.xpReward} XP & 🪙${task.coinReward} coins',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: task.type.color.withOpacity(0.9),
                    colorText: Colors.white,
                    duration: const Duration(seconds: 3),
                  );
                },
                child: const Text('Start Task  →',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rewardChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  void _showAiContentSheet(
      String title, IconData icon, Color color, StudyCategory cat) {
    Get.snackbar(
      '🤖 AI Content: $title',
      'AI is generating ${cat.name} content for you...',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: color.withOpacity(0.9),
      colorText: Colors.white,
      icon: Icon(icon, color: Colors.white),
    );
  }

  void _showCategorySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgLight,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scroll) {
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.borderColor,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text('Select Study Categories',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                  'AI generates daily challenges based on your selections',
                  style: TextStyle(
                      color: AppTheme.textTertiary, fontSize: 12)),
              const SizedBox(height: 20),
              ..._categories.map((cat) {
                return StatefulBuilder(builder: (ctx2, innerSet) {
                  return GestureDetector(
                    onTap: () {
                      innerSet(() => cat.isSelected = !cat.isSelected);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cat.isSelected
                            ? cat.color.withOpacity(0.1)
                            : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cat.isSelected
                              ? cat.color.withOpacity(0.4)
                              : AppTheme.borderColor.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(cat.emoji,
                              style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cat.name,
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                Text(cat.description,
                                    style: const TextStyle(
                                        color: AppTheme.textTertiary,
                                        fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: cat.isSelected
                                  ? cat.color
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: cat.isSelected
                                    ? cat.color
                                    : AppTheme.borderColor,
                              ),
                            ),
                            child: cat.isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 14)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                });
              }),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                  child: const Text('Save Selection',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(TaskProgress task) {
    final progressVal = task.progress / task.requiredProgress;
    final isCompleted = task.completed;
    final isClaimed = task.claimed;
    final categoryColor = _taskCategory == 'career' ? AppTheme.primaryColor : AppTheme.accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          // Animated Circular Progress Ring
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progressVal.clamp(0.0, 1.0),
                  strokeWidth: 4,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  valueColor: AlwaysStoppedAnimation(
                    isCompleted ? const Color(0xFF10B981) : categoryColor,
                  ),
                ),
                Icon(
                  _getIconForCode(task.taskCode),
                  size: 16,
                  color: isCompleted ? const Color(0xFF10B981) : Colors.white70,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Task Title & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  task.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Rewards Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '⚡ ${task.xp} XP',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '🪙 ${task.silverCoin}',
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Claim / Progress Action Button
          if (isClaimed) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Claimed',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isCompleted) ...[
            GestureDetector(
              onTap: () => _taskCategory == 'career'
                  ? _careerDailyCtrl.claimTaskReward(task.id)
                  : _idDailyCtrl.claimTaskReward(task.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Claim',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ] else ...[
            // Progress Indicator text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Text(
                '${task.progress}/${task.requiredProgress}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIconForCode(String code) {
    switch (code) {
      case 'watch_video':
        return Icons.play_circle_fill_rounded;
      case 'complete_quiz':
        return Icons.quiz_rounded;
      case 'read_article':
        return Icons.article_rounded;
      case 'voice_join':
      case 'voice_speak':
      case 'voice_room':
        return Icons.mic_rounded;
      case 'join_event':
        return Icons.event_rounded;
      case 'code_challenge':
        return Icons.code_rounded;
      case 'ask_question':
        return Icons.question_answer_rounded;
      case 'like_posts':
        return Icons.favorite_rounded;
      case 'comment_post':
        return Icons.comment_rounded;
      case 'follow_creator':
        return Icons.person_add_rounded;
      case 'send_gift':
        return Icons.card_giftcard_rounded;
      case 'invite_friend':
        return Icons.group_add_rounded;
      case 'watch_ads':
        return Icons.play_arrow_rounded;
      default:
        return Icons.star_rounded;
    }
  }
}

// ─── Ring Painter ─────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
