import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import '../../services/progression/progression_controller.dart';
import '../../models/progression/progression_models.dart';
import './progression_admin_dashboard.dart';
import '../../services/user/user_profile_cache_manager.dart';
import '../../services/storage/admob_service.dart';

class ProgressionCenterScreen extends StatefulWidget {
  const ProgressionCenterScreen({Key? key}) : super(key: key);

  @override
  State<ProgressionCenterScreen> createState() => _ProgressionCenterScreenState();
}

class _ProgressionCenterScreenState extends State<ProgressionCenterScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ProgressionController _ctrl = Get.find<ProgressionController>();
  
  // For lucky spin wheel animation
  late AnimationController _spinAnimCtrl;
  late Animation<double> _spinAnimation;
  double _currentSpinAngle = 0.0;
  String _activeSpinType = 'silver';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    
    // Setup spin animation
    _spinAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _spinAnimation = CurvedAnimation(
      parent: _spinAnimCtrl,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _spinAnimCtrl.dispose();
    super.dispose();
  }

  // Visual helper widgets
  Widget _glassContainer({required Widget child, double borderRadius = 16, EdgeInsets? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      padding: padding,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: child,
      ),
    );
  }

  void _triggerWheelSpin(String spinType) async {
    if (_ctrl.isSpinning.value) return;
    setState(() {
      _activeSpinType = spinType;
    });

    // Execute backend spin first to get the result
    final result = await _ctrl.spinWheel(spinType);
    if (!result.success) {
      Get.snackbar(
        'Spin Failed',
        result.reason ?? 'Insufficient coins or error.',
        backgroundColor: const Color(0xFFEF4444).withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Run rotation animation
    final double targetRotation = _currentSpinAngle + (360 * 5) + Random().nextInt(360);
    _spinAnimation = Tween<double>(begin: _currentSpinAngle, end: targetRotation).animate(
      CurvedAnimation(parent: _spinAnimCtrl, curve: Curves.fastOutSlowIn),
    );
    _currentSpinAngle = targetRotation % 360;

    _spinAnimCtrl.reset();
    await _spinAnimCtrl.forward();

    // Show result popup
    _showWonRewardDialog(result);
  }

  void _showWonRewardDialog(SpinResultModel result) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: _glassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🎉 CONGRATULATIONS!',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFFDB3C),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You won:',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              if (result.wonRewardType == 'silver' || result.wonRewardType == 'gold' || result.wonRewardType == 'coupon' || result.wonRewardType == 'xp') ...[
                Text(
                  '${result.wonAmount} ${result.wonRewardType!.toUpperCase()}',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ] else ...[
                Text(
                  result.wonCosmeticId ?? 'Special Reward',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '(${result.wonRewardType!.replaceAll('_', ' ')})',
                  style: GoogleFonts.inter(color: const Color(0xFFBEC2FF), fontSize: 12),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                onPressed: () => Get.back(),
                child: Text(
                  'Awesome!',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = _ctrl.isAdmin.value;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Background Gradient highlights
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withOpacity(0.15),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                        onPressed: () => Get.back(),
                      ),
                      Expanded(
                        child: Text(
                          'PROGRESION HUB',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Top TabBar
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: const Color(0xFF8B5CF6),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(text: '🌱 Dashboard'),
                    Tab(text: '📋 Tasks'),
                    Tab(text: '📅 Check-in'),
                    Tab(text: '🎰 Spin'),
                    Tab(text: '🏆 Achievements'),
                    Tab(text: '👑 Loyalty'),
                  ],
                ),

                // TabBarView Content
                Expanded(
                  child: Obx(() {
                    if (_ctrl.isLoading.value) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                      );
                    }
                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDashboardTab(),
                        _buildTasksTab(),
                        _buildCheckinTab(),
                        _buildSpinTab(),
                        _buildAchievementsTab(),
                        _buildLoyaltyTab(),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. DASHBOARD TAB
  // =========================================================================
  Widget _buildDashboardTab() {
    final progress = _ctrl.userProgress.value;
    if (progress == null) {
      return const Center(child: Text('No progression data found.', style: TextStyle(color: Colors.white70)));
    }

    final int nextLvl = progress.level + 1;
    final int xpRequired = _ctrl.levelRequirements[nextLvl] ?? 1000;
    final double percent = _ctrl.getXpProgress();
    final String levelTitle = _ctrl.getIdTitleForLevel(progress.level);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // Level circle and XP card
        _glassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: percent,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'LEVEL',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${progress.level}',
                        style: GoogleFonts.poppins(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                levelTitle,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFBEC2FF),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${progress.xp} / $xpRequired XP',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Lifetime XP: ${progress.totalXp}',
                style: GoogleFonts.inter(color: Colors.white30, fontSize: 11),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Today's Limit progress indicators
        _glassContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⚡ TODAY\'S XP LIMITS',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white38),
              ),
              const SizedBox(height: 16),
              _buildProgressRow('Daily Tasks XP', progress.todayEarnedXp - progress.todayBonusXp, 250, const Color(0xFF10B981)),
              const SizedBox(height: 16),
              _buildProgressRow('Gift Bonus XP', progress.todayBonusXp, 250, const Color(0xFFFFDB3C)),
              const SizedBox(height: 16),
              _buildProgressRow('Total Combined XP', progress.todayEarnedXp, 500, const Color(0xFF8B5CF6)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressRow(String label, int current, int maxCount, Color color) {
    final double percent = (current / maxCount).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
            Text('$current / $maxCount XP', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.05),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 2. TASKS TAB
  // =========================================================================
  Widget _buildTasksTab() {
    // Categorize tasks
    final daily = _ctrl.tasks.where((t) => t.type == 'daily').toList();
    final weekly = _ctrl.tasks.where((t) => t.type == 'weekly').toList();
    final monthly = _ctrl.tasks.where((t) => t.type == 'monthly').toList();
    final seasonal = _ctrl.tasks.where((t) => t.type == 'season').toList();

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            indicatorColor: const Color(0xFF10B981),
            labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Daily'),
              Tab(text: 'Weekly'),
              Tab(text: 'Monthly'),
              Tab(text: 'Season'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTaskList(daily, 'daily'),
                _buildTaskList(weekly, 'weekly'),
                _buildTaskList(monthly, 'monthly'),
                _buildTaskList(seasonal, 'season'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(List<TaskModel> taskList, String type) {
    if (taskList.isEmpty) {
      return const Center(child: Text('No active tasks configured.', style: TextStyle(color: Colors.white38)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: taskList.length,
      itemBuilder: (context, index) {
        final task = taskList[index];
        final percent = (task.currentCount / task.requiredCount).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _glassContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          if (task.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              task.description!,
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                            ),
                          ]
                        ],
                      ),
                    ),
                    _buildTaskActionBtn(task),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 5,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            task.isCompleted ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${task.currentCount}/${task.requiredCount}',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Task rewards summary
                Wrap(
                  spacing: 8,
                  children: task.rewards.map((r) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            r.rewardType == 'xp'
                                ? Icons.flash_on_rounded
                                : r.rewardType == 'silver'
                                    ? Icons.monetization_on_rounded
                                    : Icons.stars_rounded,
                            size: 11,
                            color: r.rewardType == 'xp'
                                ? const Color(0xFF8B5CF6)
                                : r.rewardType == 'silver'
                                    ? Colors.grey
                                    : const Color(0xFFFFDB3C),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            r.rewardType == 'xp'
                                ? '${r.amount} XP'
                                : r.rewardType == 'silver'
                                    ? '${r.amount} Silver'
                                    : r.cosmeticId ?? '${r.amount} Gold',
                            style: GoogleFonts.inter(fontSize: 10, color: Colors.white70),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskActionBtn(TaskModel task) {
    if (task.isClaimed) {
      return Text(
        'Claimed',
        style: GoogleFonts.poppins(color: Colors.white30, fontSize: 12, fontWeight: FontWeight.bold),
      );
    }

    // Custom watch ad flow
    if (task.taskId == 'watch_ad') {
      final adCount = _ctrl.dailyAdCount.value;
      if (adCount >= 5) {
        return Text(
          'Ad Limit (5/5)',
          style: GoogleFonts.poppins(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold),
        );
      }
      return TextButton(
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFFFDB3C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        onPressed: () {
          AdmobService.showRewardedInterstitial(
            onRewardEarned: () async {
              final res = await _ctrl.triggerXpEvent('ad_watched');
              if (res['success'] == true) {
                Get.snackbar(
                  'Ad Reward Earned! 🎁',
                  'You won 500 Silver and Gold coins!',
                  backgroundColor: const Color(0xFF10B981).withOpacity(0.8),
                  colorText: Colors.white,
                );
              } else {
                Get.snackbar('Ad Watch Info', res['reason'] ?? 'Daily limit reached',
                    backgroundColor: Colors.orangeAccent, colorText: Colors.white);
              }
            },
            onAdFailedToLoad: () {
              Get.snackbar('Error', 'Ad failed to load. Please try again.',
                  backgroundColor: Colors.redAccent, colorText: Colors.white);
            },
          );
        },
        child: Text(
          'Watch ($adCount/5)',
          style: GoogleFonts.poppins(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (task.isCompleted) {
      return TextButton(
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        onPressed: () => _ctrl.claimTask(task.taskId, task.type),
        child: Text(
          'Claim',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Text(
      'In Progress',
      style: GoogleFonts.poppins(color: const Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.bold),
    );
  }

  // =========================================================================
  // 3. CHECK-IN TAB
  // =========================================================================
  Widget _buildCheckinTab() {
    final status = _ctrl.checkinStatus.value;
    if (status == null) {
      return const Center(child: Text('Loading Checkin Status...', style: TextStyle(color: Colors.white)));
    }

    final int weekFactor = ((status.nextDayToClaim - 1) ~/ 7) + 1;
    final int weekStart = status.weekStart;
    final int weekEnd = status.weekEnd;

    final List<Map<String, dynamic>> weekRewards = [
      {'name': 'Silver Coins', 'icon': Icons.monetization_on_rounded, 'amount': '${200 * weekFactor} Silver', 'color': Colors.grey},
      {'name': 'Silver Coins', 'icon': Icons.monetization_on_rounded, 'amount': '${300 * weekFactor} Silver', 'color': Colors.grey},
      {'name': 'XP Points', 'icon': Icons.flash_on_rounded, 'amount': '100 XP', 'color': const Color(0xFF8B5CF6)},
      {'name': 'Gold Coins', 'icon': Icons.stars_rounded, 'amount': '${1 * weekFactor} Gold', 'color': const Color(0xFFFFDB3C)},
      {'name': 'Silver Coins', 'icon': Icons.monetization_on_rounded, 'amount': '${600 * weekFactor} Silver', 'color': Colors.grey},
      {'name': 'Spin Ticket', 'icon': Icons.confirmation_number_rounded, 'amount': '1 Ticket', 'color': const Color(0xFF6366F1)},
      {'name': 'Gold Jackpot!', 'icon': Icons.stars_rounded, 'amount': '${15 * weekFactor} Gold', 'color': const Color(0xFFFFDB3C)},
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // Streak counter summary
        _glassContainer(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF8B5CF6),
                ),
                child: const Icon(Icons.date_range_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STREAK: ${status.streakCount} DAYS',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Resets if you miss a day. Keep consecutive check-ins to boost rewards!',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              if (status.canClaimToday) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final res = await _ctrl.claimDailyCheckin();
                    if (res['success'] == true) {
                      Get.snackbar(
                        'Checked In!',
                        'You successfully checked in Day ${res['day_claimed']} and won ${res['amount']} ${res['reward_type']}!',
                        backgroundColor: const Color(0xFF10B981).withOpacity(0.8),
                        colorText: Colors.white,
                      );
                    }
                  },
                  child: Text('Check In', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    'Checked',
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                )
              ]
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Rolling week subtitle
        Text(
          '📅 STREAK WEEK: DAYS $weekStart - $weekEnd',
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),

        // Horizontal Row showing calendar days (7 days only)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(7, (index) {
              final dayNumber = weekStart + index;
              final isClaimed = status.claimedDays.contains(dayNumber) || (dayNumber < status.nextDayToClaim);
              final isNext = status.canClaimToday && dayNumber == status.nextDayToClaim;

              Color boxBorder = Colors.white.withOpacity(0.08);
              Color boxFill = const Color(0xFF1E293B).withOpacity(0.2);
              Widget icon;

              if (isClaimed) {
                boxFill = const Color(0xFF8B5CF6).withOpacity(0.15);
                boxBorder = const Color(0xFF8B5CF6).withOpacity(0.6);
                icon = Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Day $dayNumber', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    const SizedBox(height: 4),
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF8B5CF6), size: 18),
                  ],
                );
              } else if (isNext) {
                boxFill = const Color(0xFF10B981).withOpacity(0.15);
                boxBorder = const Color(0xFF10B981);
                icon = Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Day $dayNumber', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    const SizedBox(height: 4),
                    const Icon(Icons.star_rounded, color: Color(0xFF10B981), size: 18),
                  ],
                );
              } else {
                icon = Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Day $dayNumber', style: GoogleFonts.poppins(color: Colors.white24, fontWeight: FontWeight.bold, fontSize: 11)),
                    const SizedBox(height: 4),
                    const Icon(Icons.lock_rounded, color: Colors.white24, size: 16),
                  ],
                );
              }

              return Container(
                width: 76,
                height: 76,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: boxFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: boxBorder, width: 1.5),
                ),
                child: Center(child: icon),
              );
            }),
          ),
        ),

        const SizedBox(height: 24),

        // Rewards detail header
        Text(
          '🎁 REWARDS FOR THIS WEEK',
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),

        // List showing reward details for each day
        ...List.generate(7, (index) {
          final dayNumber = weekStart + index;
          final isClaimed = status.claimedDays.contains(dayNumber) || (dayNumber < status.nextDayToClaim);
          final isNext = status.canClaimToday && dayNumber == status.nextDayToClaim;
          final reward = weekRewards[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isNext 
                  ? const Color(0xFF10B981).withOpacity(0.08)
                  : const Color(0xFF1E293B).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isNext 
                    ? const Color(0xFF10B981).withOpacity(0.3) 
                    : (isClaimed ? const Color(0xFF8B5CF6).withOpacity(0.15) : Colors.white.withOpacity(0.04)), 
                width: 1
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: (reward['color'] as Color).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(reward['icon'] as IconData, color: reward['color'] as Color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Day $dayNumber: ${reward['name']}',
                        style: GoogleFonts.poppins(
                          fontSize: 13, 
                          fontWeight: FontWeight.bold, 
                          color: isClaimed ? Colors.white60 : Colors.white
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Reward Value: ${reward['amount']}',
                        style: GoogleFonts.inter(fontSize: 11, color: isClaimed ? Colors.white24 : Colors.white38),
                      ),
                    ],
                  ),
                ),
                if (isClaimed) ...[
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF8B5CF6), size: 20),
                ] else if (isNext) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'Today',
                      style: GoogleFonts.poppins(color: const Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 18),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  // =========================================================================
  // 4. SPIN TAB
  // =========================================================================
  Widget _buildSpinTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        Text(
          '🎯 LUCKY SPIN WHEEL',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Deduct currency, spin, and win premium rewards!',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Interactive Wheel graphic using rotation animation
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _spinAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _spinAnimation.value * pi / 180,
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage('assets/images/lucky_wheel_bg.png'), // placeholder check
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: CustomPaint(
                        painter: WheelPainter(),
                      ),
                    ),
                  );
                },
              ),
              // Pointer indicator
              Positioned(
                top: 0,
                child: Container(
                  width: 24,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  transform: Matrix4.rotationZ(pi / 4),
                ),
              ),
              // Center spin button hub
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.flash_on_rounded, color: Color(0xFFFFDB3C), size: 28),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Cost actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSpinCostCard('Silver Spin', '500 Silver', () => _triggerWheelSpin('silver'), const Color(0xFF6B7280)),
            _buildSpinCostCard('Gold Spin', '50 Gold', () => _triggerWheelSpin('gold'), const Color(0xFFFFDB3C)),
            _buildSpinCostCard('Premium', '1 Ticket', () => _triggerWheelSpin('premium'), const Color(0xFF8B5CF6)),
          ],
        ),
      ],
    );
  }

  Widget _buildSpinCostCard(String label, String cost, VoidCallback onTap, Color themeColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: _glassContainer(
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              cost,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: themeColor),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 5. ACHIEVEMENTS TAB
  // =========================================================================
  Widget _buildAchievementsTab() {
    if (_ctrl.achievements.isEmpty) {
      return const Center(child: Text('No achievements listed.', style: TextStyle(color: Colors.white38)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _ctrl.achievements.length,
      itemBuilder: (context, index) {
        final ach = _ctrl.achievements[index];
        final percent = (ach.currentCount / ach.requiredCount).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _glassContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: ach.isCompleted ? const Color(0xFFFFDB3C).withOpacity(0.15) : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: ach.isCompleted ? const Color(0xFFFFDB3C) : Colors.white38,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ach.title,
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      if (ach.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          ach.description!,
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: percent,
                                minHeight: 4,
                                backgroundColor: Colors.white.withOpacity(0.05),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  ach.isCompleted ? const Color(0xFFFFDB3C) : const Color(0xFF6366F1),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${ach.currentCount}/${ach.requiredCount}',
                            style: GoogleFonts.inter(fontSize: 10, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildAchievementAction(ach),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAchievementAction(AchievementModel ach) {
    if (ach.isClaimed) {
      return const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24);
    }
    if (ach.isCompleted) {
      return TextButton(
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFFFDB3C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        onPressed: () => _ctrl.claimAchievement(ach.achievementId),
        child: Text(
          'Claim',
          style: GoogleFonts.poppins(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }
    return const SizedBox(width: 48);
  }

  // =========================================================================
  // 6. LOYALTY TAB
  // =========================================================================
  Widget _buildLoyaltyTab() {
    final status = _ctrl.loyaltyStatus.value;
    if (status == null) {
      return const Center(child: Text('Loading Loyalty status...', style: TextStyle(color: Colors.white)));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        _glassContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                '${status.totalActiveDays}',
                style: GoogleFonts.poppins(fontSize: 48, fontWeight: FontWeight.w900, color: const Color(0xFF8B5CF6)),
              ),
              Text(
                'TOTAL ACTIVE DAYS',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white38),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '🌟 LOYALTY MILESTONES',
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
        const SizedBox(height: 12),
        ...status.milestones.map((milestone) {
          final isClaimed = milestone.isClaimed;
          final isCompleted = status.totalActiveDays >= milestone.requiredDays;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _glassContainer(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${milestone.requiredDays} Days Club',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        milestone.cosmeticId ?? '${milestone.amount} ${milestone.rewardType.toUpperCase()}',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                      ),
                    ],
                  ),
                  _buildLoyaltyAction(milestone, isCompleted, isClaimed),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildLoyaltyAction(LoyaltyMilestoneModel milestone, bool isCompleted, bool isClaimed) {
    if (isClaimed) {
      return Text(
        'Claimed',
        style: GoogleFonts.poppins(color: Colors.white30, fontSize: 12, fontWeight: FontWeight.bold),
      );
    }
    if (isCompleted) {
      return TextButton(
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFF8B5CF6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        onPressed: () => _ctrl.claimLoyalty(milestone.requiredDays),
        child: Text(
          'Claim',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Text(
      'Locked',
      style: GoogleFonts.poppins(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.bold),
    );
  }
}

// Wheel of fortune graphic drawer
class WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final colors = [
      const Color(0xFF1E293B).withOpacity(0.8),
      const Color(0xFF8B5CF6).withOpacity(0.8),
      const Color(0xFF1E293B).withOpacity(0.8),
      const Color(0xFF10B981).withOpacity(0.8),
      const Color(0xFF1E293B).withOpacity(0.8),
      const Color(0xFFFFDB3C).withOpacity(0.8),
    ];

    const double sweepAngle = 2 * pi / 6;
    for (int i = 0; i < 6; i++) {
      paint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius),
        i * sweepAngle,
        sweepAngle,
        true,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
