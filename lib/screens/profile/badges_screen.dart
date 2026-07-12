import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({Key? key}) : super(key: key);

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _pinnedBadges = {'badge_top_contrib', 'badge_voice_host', 'badge_premium'};

  static const int _maxPinned = 6;

  final List<Map<String, dynamic>> _allBadges = [
    // Achievement badges
    {
      'id': 'badge_top_contrib',
      'name': 'Top Contributor',
      'desc': 'Posted 50+ high-quality content pieces',
      'icon': '🏆',
      'category': 'Achievement',
      'rarity': 'Legendary',
      'rarityColor': const Color(0xFFFBBF24),
      'isUnlocked': true,
      'unlocksAt': 'Post 50 times',
      'xpBonus': 200,
    },
    {
      'id': 'badge_voice_host',
      'name': 'Voice Host',
      'desc': 'Hosted 10+ voice rooms with 50+ listeners',
      'icon': '🎤',
      'category': 'Achievement',
      'rarity': 'Epic',
      'rarityColor': const Color(0xFF8B5CF6),
      'isUnlocked': true,
      'unlocksAt': 'Host 10 rooms',
      'xpBonus': 150,
    },
    {
      'id': 'badge_problem_solver',
      'name': 'Problem Solver',
      'desc': 'Answered 25+ questions with accepted solutions',
      'icon': '💡',
      'category': 'Achievement',
      'rarity': 'Rare',
      'rarityColor': const Color(0xFF3B82F6),
      'isUnlocked': true,
      'unlocksAt': 'Answer 25 questions',
      'xpBonus': 100,
    },
    {
      'id': 'badge_streak_master',
      'name': 'Streak Master',
      'desc': 'Maintained a 30-day activity streak',
      'icon': '🔥',
      'category': 'Achievement',
      'rarity': 'Epic',
      'rarityColor': const Color(0xFFF97316),
      'isUnlocked': true,
      'unlocksAt': '30-day streak',
      'xpBonus': 180,
    },
    {
      'id': 'badge_rising_star',
      'name': 'Rising Star',
      'desc': 'Gained 500 followers in first month',
      'icon': '⭐',
      'category': 'Achievement',
      'rarity': 'Rare',
      'rarityColor': const Color(0xFF3B82F6),
      'isUnlocked': true,
      'unlocksAt': '500 followers in 30 days',
      'xpBonus': 120,
    },
    {
      'id': 'badge_early_adopter',
      'name': 'Early Adopter',
      'desc': 'Joined Creania in the first 1000 users',
      'icon': '🚀',
      'category': 'Achievement',
      'rarity': 'Legendary',
      'rarityColor': const Color(0xFFFBBF24),
      'isUnlocked': true,
      'unlocksAt': 'First 1000 users',
      'xpBonus': 300,
    },
    // VIP badges
    {
      'id': 'badge_premium',
      'name': 'Premium',
      'desc': 'Active Creania Premium member',
      'icon': '💎',
      'category': 'VIP',
      'rarity': 'Epic',
      'rarityColor': const Color(0xFF8B5CF6),
      'isUnlocked': true,
      'unlocksAt': 'Subscribe to Premium',
      'xpBonus': 100,
    },
    {
      'id': 'badge_vip_gold',
      'name': 'VIP Gold',
      'desc': 'VIP Gold tier membership holder',
      'icon': '👑',
      'category': 'VIP',
      'rarity': 'Legendary',
      'rarityColor': const Color(0xFFFBBF24),
      'isUnlocked': false,
      'unlocksAt': 'Subscribe to VIP Gold',
      'xpBonus': 250,
    },
    {
      'id': 'badge_noble',
      'name': 'Noble',
      'desc': 'Achieved Noble rank in the community',
      'icon': '🏅',
      'category': 'VIP',
      'rarity': 'Legendary',
      'rarityColor': const Color(0xFFFBBF24),
      'isUnlocked': false,
      'unlocksAt': 'Reach Noble rank',
      'xpBonus': 350,
    },
    // Study badges
    {
      'id': 'badge_code_master',
      'name': 'Code Master',
      'desc': 'Reached Level 30 in Engineering & CS',
      'icon': '💻',
      'category': 'Study',
      'rarity': 'Epic',
      'rarityColor': const Color(0xFF6366F1),
      'isUnlocked': false,
      'unlocksAt': 'CS Level 30',
      'xpBonus': 200,
    },
    {
      'id': 'badge_exam_warrior',
      'name': 'Exam Warrior',
      'desc': 'Completed 50 mock tests',
      'icon': '⚔️',
      'category': 'Study',
      'rarity': 'Rare',
      'rarityColor': const Color(0xFFF59E0B),
      'isUnlocked': false,
      'unlocksAt': 'Complete 50 mock tests',
      'xpBonus': 150,
    },
    {
      'id': 'badge_quiz_king',
      'name': 'Quiz King',
      'desc': 'Scored 100% on 10 consecutive quizzes',
      'icon': '🎯',
      'category': 'Study',
      'rarity': 'Epic',
      'rarityColor': const Color(0xFF10B981),
      'isUnlocked': false,
      'unlocksAt': '10 perfect quiz scores',
      'xpBonus': 180,
    },
    // Community badges
    {
      'id': 'badge_community_admin',
      'name': 'Community Admin',
      'desc': 'Admin of a community with 1000+ members',
      'icon': '🌍',
      'category': 'Community',
      'rarity': 'Rare',
      'rarityColor': const Color(0xFF3B82F6),
      'isUnlocked': true,
      'unlocksAt': 'Admin of 1K+ member community',
      'xpBonus': 130,
    },
    {
      'id': 'badge_mentor',
      'name': 'Mentor',
      'desc': 'Mentored 10+ members on the platform',
      'icon': '🧑‍🏫',
      'category': 'Community',
      'rarity': 'Rare',
      'rarityColor': const Color(0xFF10B981),
      'isUnlocked': false,
      'unlocksAt': 'Mentor 10 members',
      'xpBonus': 140,
    },
    // Career badges
    {
      'id': 'badge_hired',
      'name': 'Got Hired',
      'desc': 'Landed a job through Creania referral',
      'icon': '💼',
      'category': 'Career',
      'rarity': 'Legendary',
      'rarityColor': const Color(0xFFFBBF24),
      'isUnlocked': false,
      'unlocksAt': 'Get hired via Creania',
      'xpBonus': 500,
    },
    {
      'id': 'badge_100_hiring',
      'name': '100% Hiring Score',
      'desc': 'Achieved maximum hiring score across all skills',
      'icon': '🎖️',
      'category': 'Career',
      'rarity': 'Legendary',
      'rarityColor': const Color(0xFFFBBF24),
      'isUnlocked': false,
      'unlocksAt': 'Reach 100% hiring score',
      'xpBonus': 400,
    },
  ];

  String _activeCategory = 'All';
  final List<String> _categories = ['All', 'Achievement', 'VIP', 'Study', 'Community', 'Career'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredBadges {
    if (_activeCategory == 'All') return _allBadges;
    return _allBadges.where((b) => b['category'] == _activeCategory).toList();
  }

  List<Map<String, dynamic>> get _pinnedBadgesList =>
      _allBadges.where((b) => _pinnedBadges.contains(b['id'])).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Badges & Achievements',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textTertiary,
          tabs: const [
            Tab(text: 'All Badges'),
            Tab(text: 'My Profile'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllBadgesTab(),
          _buildProfileBadgesTab(),
        ],
      ),
    );
  }

  // ─── All Badges Tab ───────────────────────────────────────────────────────

  Widget _buildAllBadgesTab() {
    return Column(
      children: [
        _buildCategoryFilter(),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _filteredBadges.length,
            itemBuilder: (ctx, i) => _buildBadgeCard(_filteredBadges[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _categories.map((cat) {
          final isActive = _activeCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _activeCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primaryColor : AppTheme.bgLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? AppTheme.primaryColor : AppTheme.borderColor,
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: isActive ? Colors.white : AppTheme.textTertiary,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> badge) {
    final isUnlocked = badge['isUnlocked'] as bool;
    final isPinned = _pinnedBadges.contains(badge['id']);
    final rarityColor = badge['rarityColor'] as Color;

    return GestureDetector(
      onTap: () => _showBadgeDetail(badge),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnlocked
              ? rarityColor.withOpacity(0.08)
              : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isPinned
                ? AppTheme.primaryColor.withOpacity(0.5)
                : isUnlocked
                    ? rarityColor.withOpacity(0.3)
                    : AppTheme.borderColor.withOpacity(0.3),
            width: isPinned ? 2 : 1,
          ),
          boxShadow: isPinned
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.15),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Rarity chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: rarityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge['rarity'] as String,
                    style: TextStyle(
                      color: rarityColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isPinned)
                  const Icon(Icons.push_pin_rounded,
                      color: AppTheme.primaryColor, size: 14),
              ],
            ),
            const SizedBox(height: 12),
            // Badge icon
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isUnlocked
                          ? rarityColor.withOpacity(0.15)
                          : AppTheme.bgLight,
                      border: Border.all(
                        color: isUnlocked
                            ? rarityColor.withOpacity(0.4)
                            : AppTheme.borderColor,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isUnlocked ? (badge['icon'] as String) : '🔒',
                        style: TextStyle(
                            fontSize: isUnlocked ? 28 : 22),
                      ),
                    ),
                  ),
                  if (!isUnlocked)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              badge['name'] as String,
              style: TextStyle(
                color: isUnlocked
                    ? AppTheme.textPrimary
                    : AppTheme.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              isUnlocked ? '⚡+${badge['xpBonus']} XP' : badge['unlocksAt'] as String,
              style: TextStyle(
                color: isUnlocked ? rarityColor : AppTheme.textTertiary,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Profile Badges Tab ───────────────────────────────────────────────────

  Widget _buildProfileBadgesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pinned badges preview
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withOpacity(0.15),
                AppTheme.secondaryColor.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile Badge Display',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${_pinnedBadges.length}/$_maxPinned pinned',
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'These badges show on your public profile',
                style: TextStyle(
                    color: AppTheme.textTertiary, fontSize: 11),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ..._pinnedBadgesList.map((b) => _buildPinnedChip(b)),
                  if (_pinnedBadges.length < _maxPinned)
                    GestureDetector(
                      onTap: () => _tabController.animateTo(0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded,
                                color: AppTheme.primaryColor, size: 14),
                            SizedBox(width: 4),
                            Text('Add Badge',
                                style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Unlocked badges list
        const Text(
          'Your Unlocked Badges',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ..._allBadges
            .where((b) => b['isUnlocked'] as bool)
            .map((b) => _buildUnlockedBadgeRow(b)),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildPinnedChip(Map<String, dynamic> badge) {
    return GestureDetector(
      onTap: () {
        setState(() => _pinnedBadges.remove(badge['id']));
        Get.snackbar(
          'Badge Removed',
          '${badge['name']} removed from profile',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.bgLight,
          colorText: AppTheme.textPrimary,
          duration: const Duration(seconds: 2),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: (badge['rarityColor'] as Color).withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (badge['rarityColor'] as Color).withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge['icon'] as String,
                style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              badge['name'] as String,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.close, size: 12, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockedBadgeRow(Map<String, dynamic> badge) {
    final isPinned = _pinnedBadges.contains(badge['id']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPinned
              ? AppTheme.primaryColor.withOpacity(0.3)
              : AppTheme.borderColor.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Text(badge['icon'] as String,
              style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(badge['name'] as String,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text(badge['desc'] as String,
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              if (isPinned) {
                setState(() => _pinnedBadges.remove(badge['id']));
                Get.snackbar('Badge Unpinned',
                    '${badge['name']} removed from profile',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppTheme.bgLight,
                    colorText: AppTheme.textPrimary,
                    duration: const Duration(seconds: 2));
              } else if (_pinnedBadges.length < _maxPinned) {
                setState(() => _pinnedBadges.add(badge['id'] as String));
                Get.snackbar('Badge Pinned! 📌',
                    '${badge['name']} is now on your profile',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.9),
                    colorText: Colors.white,
                    duration: const Duration(seconds: 2));
              } else {
                Get.snackbar('Max Badges Reached',
                    'Unpin a badge first (max $_maxPinned)',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppTheme.bgLight,
                    colorText: AppTheme.textPrimary);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isPinned
                    ? AppTheme.primaryColor.withOpacity(0.15)
                    : AppTheme.bgLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isPinned
                      ? AppTheme.primaryColor.withOpacity(0.4)
                      : AppTheme.borderColor,
                ),
              ),
              child: Text(
                isPinned ? '📌 Pinned' : 'Pin',
                style: TextStyle(
                  color: isPinned
                      ? AppTheme.primaryColor
                      : AppTheme.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBadgeDetail(Map<String, dynamic> badge) {
    final isUnlocked = badge['isUnlocked'] as bool;
    final isPinned = _pinnedBadges.contains(badge['id']);
    final rarityColor = badge['rarityColor'] as Color;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgLight,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, innerSet) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.borderColor,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                // Badge icon big
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnlocked
                        ? rarityColor.withOpacity(0.15)
                        : AppTheme.cardBg,
                    border: Border.all(
                        color: isUnlocked
                            ? rarityColor.withOpacity(0.5)
                            : AppTheme.borderColor,
                        width: 3),
                    boxShadow: isUnlocked
                        ? [
                            BoxShadow(
                                color: rarityColor.withOpacity(0.3),
                                blurRadius: 20)
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      isUnlocked ? (badge['icon'] as String) : '🔒',
                      style: const TextStyle(fontSize: 44),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: rarityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(badge['rarity'] as String,
                      style: TextStyle(
                          color: rarityColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 10),
                Text(badge['name'] as String,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(badge['desc'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 13)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _detailChip('Category', badge['category'] as String,
                        AppTheme.primaryColor),
                    const SizedBox(width: 10),
                    _detailChip('XP Bonus', '+${badge['xpBonus']}',
                        const Color(0xFFFBBF24)),
                  ],
                ),
                if (!isUnlocked) ...[
                  const SizedBox(height: 10),
                  _detailChip(
                      'Unlock Condition', badge['unlocksAt'] as String, AppTheme.accentColor),
                ],
                const SizedBox(height: 24),
                if (isUnlocked)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPinned
                            ? AppTheme.bgDark
                            : AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        side: isPinned
                            ? const BorderSide(color: AppTheme.borderColor)
                            : null,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (isPinned) {
                          setState(() => _pinnedBadges.remove(badge['id']));
                        } else if (_pinnedBadges.length < _maxPinned) {
                          setState(() => _pinnedBadges.add(badge['id'] as String));
                        }
                      },
                      child: Text(
                        isPinned ? 'Unpin from Profile' : '📌 Pin to Profile',
                        style: TextStyle(
                            color: isPinned
                                ? AppTheme.textPrimary
                                : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textTertiary, fontSize: 10)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
