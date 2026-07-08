import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/career_progression_controller.dart';

class ProgressionRewardsScreen extends StatefulWidget {
  const ProgressionRewardsScreen({Key? key}) : super(key: key);

  @override
  State<ProgressionRewardsScreen> createState() => _ProgressionRewardsScreenState();
}

class _ProgressionRewardsScreenState extends State<ProgressionRewardsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CareerProgressionController _progCtrl = Get.find<CareerProgressionController>();

  final List<Map<String, dynamic>> _idMilestones = [
    {'level': 5, 'name': 'Premium Name Border', 'type': 'Border Upgrade', 'desc': 'Unlocks a stylish neon blue name frame'},
    {'level': 10, 'name': 'Animated Avatar Ring', 'type': 'Ring Effect', 'desc': 'Glowing pulsing ring around your avatar picture'},
    {'level': 15, 'name': 'Silver Profile Medal', 'type': 'Reputation Medal', 'desc': 'Adds a Silver Pathfinder medal to your profile tag list'},
    {'level': 20, 'name': 'Achievement Frame', 'type': 'Frame Style', 'desc': 'Unlocks the golden Trophy hunter profile card border'},
    {'level': 30, 'name': 'Vanguard Title Badge', 'type': 'Title Effect', 'desc': 'Exclusive red badge showing Vanguard status'},
    {'level': 45, 'name': 'Legend Border', 'type': 'Frame Style', 'desc': 'Ultimate cosmic particle boarder style'},
    {'level': 60, 'name': 'Immortal Crown Theme', 'type': 'Theme & Border', 'desc': 'Maximum prestige layout, crowns and rainbow highlights'},
  ];

  final List<Map<String, dynamic>> _careerMilestones = [
    {'level': 5, 'name': 'Apprentice Tag Decorator', 'type': 'Tag Effect', 'desc': 'Adds bronze star embellishments to your career badge'},
    {'level': 12, 'name': 'Professional Title Badge', 'type': 'Badge Style', 'desc': 'Unlocks premium title tag backgrounds'},
    {'level': 25, 'name': 'Custom Career Theme', 'type': 'Profile Color', 'desc': 'Unlocks personalized HSL color customizers'},
    {'level': 40, 'name': 'Grandmaster Aura Ring', 'type': 'VFX Effect', 'desc': 'Special fire ring around your profile card'},
    {'level': 50, 'name': 'Sovereign Legend Medal', 'type': 'Prestige Badge', 'desc': 'The highest career tag with royal crown symbols'},
  ];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Milestone Rewards',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF8B5CF6),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
          tabs: const [
            Tab(text: '🌱 ID Level Rewards'),
            Tab(text: '🎓 Career Level Rewards'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMilestoneList(_idMilestones, false),
          _buildMilestoneList(_careerMilestones, true),
        ],
      ),
    );
  }

  Widget _buildMilestoneList(List<Map<String, dynamic>> milestones, bool isCareer) {
    return Obx(() {
      final currentLevel = isCareer ? _progCtrl.careerLevel.value : _progCtrl.idLevel.value;

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: milestones.length,
        itemBuilder: (context, index) {
          final m = milestones[index];
          final milestoneLevel = m['level'] as int;
          final name = m['name'] as String;
          final type = m['type'] as String;
          final desc = m['desc'] as String;

          final isUnlocked = currentLevel >= milestoneLevel;
          final isClaimed = _progCtrl.claimedMilestones.contains(milestoneLevel);

          Color statusColor;
          if (isClaimed) {
            statusColor = const Color(0xFF10B981);
          } else if (isUnlocked) {
            statusColor = const Color(0xFFF59E0B);
          } else {
            statusColor = Colors.white24;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUnlocked ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.01),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isUnlocked
                    ? statusColor.withOpacity(0.3)
                    : AppTheme.borderColor.withOpacity(0.2),
                width: isUnlocked ? 1.5 : 1,
              ),
              boxShadow: isUnlocked && !isClaimed
                  ? [
                      BoxShadow(
                        color: statusColor.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Level Circle Indicator
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isUnlocked
                          ? [statusColor, statusColor.withOpacity(0.6)]
                          : [Colors.white10, Colors.white24],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Lvl\n$milestoneLevel',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: isUnlocked ? Colors.black : Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Texts Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isUnlocked ? statusColor.withOpacity(0.15) : Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              type.toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: isUnlocked ? statusColor : Colors.white38,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          color: isUnlocked ? Colors.white : Colors.white38,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: GoogleFonts.poppins(
                          color: Colors.white24,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action Buttons
                if (isClaimed)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981)),
                    child: const Icon(Icons.check, size: 14, color: Colors.black),
                  )
                else if (isUnlocked)
                  ElevatedButton(
                    onPressed: () {
                      _progCtrl.claimMilestone(milestoneLevel, isCareer);
                      Get.dialog(
                        AlertDialog(
                          backgroundColor: AppTheme.bgLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Center(
                            child: Text('🎉 Reward Claimed!', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🏆', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text(
                                'You successfully claimed the $name!\nIt is now active on your profile.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(),
                              child: Text('Confirm', style: GoogleFonts.poppins(color: const Color(0xFF8B5CF6))),
                            )
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                    ),
                    child: Text(
                      'Claim',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  )
                else
                  const Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 20),
              ],
            ),
          );
        },
      );
    });
  }
}
