import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import 'career_dna_screen.dart';
import 'skill_tree_screen.dart';
import 'ai_mentor_screen.dart';
import 'hiring_score_screen.dart';
import 'live_battle_screen.dart';
import 'brain_training_screen.dart';
import '../../services/career_progression_controller.dart';
import '../../services/study_category_controller.dart';
import '../profile/mcq_quiz_screen.dart';
import '../../widgets/video_player_dialog.dart';
import '../profile/daily_task_screen.dart';

// Stub screens for remaining features
class _StubScreen extends StatelessWidget {
  const _StubScreen({required this.title, required this.emoji, required this.desc});
  final String title;
  final String emoji;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(title,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(desc,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textTertiary, fontSize: 13)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: const Text('🚀 Coming Soon',
                  style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class CareerHubScreen extends StatefulWidget {
  const CareerHubScreen({Key? key}) : super(key: key);

  @override
  State<CareerHubScreen> createState() => _CareerHubScreenState();
}

class _CareerHubScreenState extends State<CareerHubScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  final List<Map<String, dynamic>> _features = [
    // Priority: unique features first
    {
      'id': 'career_dna',
      'name': 'Career DNA',
      'emoji': '🧬',
      'desc': 'Your AI-powered career identity',
      'color': const Color(0xFF6366F1),
      'isUnique': true,
      'badge': 'UNIQUE',
      'screen': () => const CareerDnaScreen(),
    },
    {
      'id': 'skill_tree',
      'name': 'Skill Tree',
      'emoji': '🌲',
      'desc': 'Game-style skill progression',
      'color': const Color(0xFF10B981),
      'isUnique': false,
      'badge': 'GAME',
      'screen': () => const SkillTreeScreen(),
    },
    {
      'id': 'ai_mentor',
      'name': 'AI Mentor',
      'emoji': '🤖',
      'desc': 'Personal study coach',
      'color': const Color(0xFF8B5CF6),
      'isUnique': false,
      'badge': 'AI',
      'screen': () => const AiMentorScreen(),
    },
    {
      'id': 'hiring_score',
      'name': 'Hiring Score',
      'emoji': '📊',
      'desc': 'Real skill-based score',
      'color': const Color(0xFFF59E0B),
      'isUnique': false,
      'badge': 'LIVE',
      'screen': () => const HiringScoreScreen(),
    },
    {
      'id': 'live_battle',
      'name': 'Live Battle',
      'emoji': '⚔️',
      'desc': '8 battle modes, AI judge',
      'color': const Color(0xFFEF4444),
      'isUnique': false,
      'badge': 'LIVE',
      'screen': () => const LiveBattleScreen(),
    },
    {
      'id': 'brain_training',
      'name': 'Brain Training',
      'emoji': '🧠',
      'desc': '8 daily cognitive games',
      'color': const Color(0xFF6366F1),
      'isUnique': false,
      'badge': 'DAILY',
      'screen': () => const BrainTrainingScreen(),
    },
    {
      'id': 'skill_verify',
      'name': 'Skill Verification',
      'emoji': '✅',
      'desc': 'Earn verified skill tags',
      'color': const Color(0xFF10B981),
      'isUnique': false,
      'badge': 'NEW',
      'screen': () => const _StubScreen(
        title: 'Skill Verification',
        emoji: '✅',
        desc: 'Complete challenges to earn verified skill badges',
      ),
    },
    {
      'id': 'seasonal',
      'name': 'Seasonal Events',
      'emoji': '🎪',
      'desc': 'Monthly competitions',
      'color': const Color(0xFFEC4899),
      'isUnique': false,
      'badge': 'LIVE',
      'screen': () => const _StubScreen(
        title: 'Seasonal Events',
        emoji: '🎪',
        desc: 'AI Week, Hackathon, Math Marathon & more',
      ),
    },
    {
      'id': 'university',
      'name': 'University Rank',
      'emoji': '🎓',
      'desc': 'College leaderboard',
      'color': const Color(0xFF3B82F6),
      'isUnique': false,
      'badge': null,
      'screen': () => const _StubScreen(
        title: 'University Ranking',
        emoji: '🎓',
        desc: 'Represent your college on the national leaderboard',
      ),
    },
    {
      'id': 'company',
      'name': 'Company Challenges',
      'emoji': '🏢',
      'desc': 'Google, TCS, Infosys tests',
      'color': const Color(0xFFF97316),
      'isUnique': false,
      'badge': 'HOT',
      'screen': () => const _StubScreen(
        title: 'Company Challenges',
        emoji: '🏢',
        desc: 'Top performers get interview invites from leading companies',
      ),
    },
    {
      'id': 'research',
      'name': 'Research Hub',
      'emoji': '🔬',
      'desc': 'Papers, patents, peer review',
      'color': const Color(0xFF14B8A6),
      'isUnique': false,
      'badge': null,
      'screen': () => const _StubScreen(
        title: 'Research Hub',
        emoji: '🔬',
        desc: 'Publish papers, connect with professors, earn research score',
      ),
    },
    {
      'id': 'resume',
      'name': 'AI Resume Builder',
      'emoji': '📄',
      'desc': 'One-click resume & CV',
      'color': const Color(0xFF64748B),
      'isUnique': false,
      'badge': 'AI',
      'screen': () => const _StubScreen(
        title: 'AI Resume Builder',
        emoji: '📄',
        desc: 'Auto-generate resume, CV, portfolio and LinkedIn summary',
      ),
    },
    {
      'id': 'personality',
      'name': 'Personality Score',
      'emoji': '🧩',
      'desc': 'Leadership, creativity score',
      'color': const Color(0xFFEC4899),
      'isUnique': false,
      'badge': 'AI',
      'screen': () => const _StubScreen(
        title: 'Personality Score',
        emoji: '🧩',
        desc: 'AI measures your leadership, creativity, teamwork & more',
      ),
    },
    {
      'id': 'streaks',
      'name': 'Knowledge Streaks',
      'emoji': '🔥',
      'desc': '7 separate streak trackers',
      'color': const Color(0xFFF97316),
      'isUnique': false,
      'badge': 'DAILY',
      'screen': () => const _StubScreen(
        title: 'Knowledge Streaks',
        emoji: '🔥',
        desc: 'Coding, Math, GK, Interview, Reasoning & more streaks',
      ),
    },
    {
      'id': 'achievement',
      'name': 'Achievement Gallery',
      'emoji': '🏆',
      'desc': 'Trophies, medals, effects',
      'color': const Color(0xFFFBBF24),
      'isUnique': false,
      'badge': null,
      'screen': () => const _StubScreen(
        title: 'Achievement Gallery',
        emoji: '🏆',
        desc: 'Animated trophies, 3D medals, profile effects & rare collectibles',
      ),
    },
    {
      'id': 'reputation',
      'name': 'AI Reputation',
      'emoji': '⭐',
      'desc': 'Community trust score',
      'color': const Color(0xFF6366F1),
      'isUnique': false,
      'badge': 'AI',
      'screen': () => const _StubScreen(
        title: 'AI Reputation',
        emoji: '⭐',
        desc: 'Trust score from helping, mentoring & winning contests',
      ),
    },
    {
      'id': 'marketplace',
      'name': 'Skill Marketplace',
      'emoji': '🛒',
      'desc': 'Teach, sell, earn coins',
      'color': const Color(0xFF10B981),
      'isUnique': false,
      'badge': 'EARN',
      'screen': () => const _StubScreen(
        title: 'Skill Marketplace',
        emoji: '🛒',
        desc: 'Sell notes, mock interviews, mentorship & earn inside Creania',
      ),
    },
  ];

  final CareerProgressionController _progCtrl = Get.find<CareerProgressionController>();
  String? _onboardingSelectedCareer;

  // Anti-grind simulation alerts
  final RxDouble _simMultiplier = 1.0.obs;
  final RxInt _simEarnedXp = 0.obs;
  final RxBool _simGrindActive = false.obs;

  final List<Map<String, dynamic>> _allCareers = [
    {'name': 'Computer Science', 'emoji': '💻', 'color': const Color(0xFF6366F1), 'skills': ['Coding', 'Algorithms', 'DSA', 'System Design']},
    {'name': 'Doctor', 'emoji': '🩺', 'color': const Color(0xFF10B981), 'skills': ['Anatomy', 'Biology', 'Medicine', 'First Aid']},
    {'name': 'Engineer', 'emoji': '🏗️', 'color': const Color(0xFFF59E0B), 'skills': ['Math', 'Physics', 'CAD', 'Design']},
    {'name': 'Teacher', 'emoji': '🍎', 'color': const Color(0xFFEF4444), 'skills': ['Pedagogy', 'Communication', 'Psychology']},
    {'name': 'UPSC', 'emoji': '🏛️', 'color': const Color(0xFFEC4899), 'skills': ['Polity', 'History', 'Current Affairs', 'GS']},
    {'name': 'SSC', 'emoji': '📝', 'color': const Color(0xFF06B6D4), 'skills': ['Quant', 'Reasoning', 'English', 'GS']},
    {'name': 'Banking', 'emoji': '💰', 'color': const Color(0xFF8B5CF6), 'skills': ['Finance', 'Aptitude', 'Accounts', 'Banking']},
    {'name': 'Law', 'emoji': '⚖️', 'color': const Color(0xFFE2E8F0), 'skills': ['Constitution', 'IPC', 'Contracts', 'Torts']},
    {'name': 'Business', 'emoji': '💼', 'color': const Color(0xFFD946EF), 'skills': ['Strategy', 'Leadership', 'Sales', 'Finance']},
    {'name': 'Marketing', 'emoji': '📢', 'color': const Color(0xFF38BDF8), 'skills': ['SEO', 'Content', 'Ads', 'Branding']},
    {'name': 'Designer', 'emoji': '🎨', 'color': const Color(0xFFF472B6), 'skills': ['Graphics', 'Illustration', 'Figma', 'Colors']},
    {'name': 'UI/UX', 'emoji': '📱', 'color': const Color(0xFF10B981), 'skills': ['Wireframing', 'User Research', 'Figma']},
    {'name': 'Cyber Security', 'emoji': '🛡️', 'color': const Color(0xFF06B6D4), 'skills': ['Networking', 'Linux', 'Ethical Hacking']},
    {'name': 'AI Engineer', 'emoji': '🤖', 'color': const Color(0xFF8B5CF6), 'skills': ['Python', 'Machine Learning', 'PyTorch']},
    {'name': 'Photographer', 'emoji': '📷', 'color': const Color(0xFFF97316), 'skills': ['Lighting', 'Composition', 'Editing']},
    {'name': 'Musician', 'emoji': '🎵', 'color': const Color(0xFFEC4899), 'skills': ['Theory', 'Instrument', 'Vocals', 'DAW']},
    {'name': 'Content Creator', 'emoji': '📹', 'color': const Color(0xFFEF4444), 'skills': ['Video', 'Scripts', 'Editing', 'Socials']},
    {'name': 'Video Editor', 'emoji': '🎞️', 'color': const Color(0xFF38BDF8), 'skills': ['Premiere Pro', 'After Effects', 'Cuts']},
    {'name': 'Game Developer', 'emoji': '🎮', 'color': const Color(0xFF6366F1), 'skills': ['Unity', 'C#', '3D Math', 'Design']},
    {'name': 'Animation', 'emoji': '🎬', 'color': const Color(0xFFF59E0B), 'skills': ['2D/3D', 'Keyframes', 'Blender', 'Maya']},
    {'name': 'Architecture', 'emoji': '📐', 'color': const Color(0xFF14B8A6), 'skills': ['Drafting', 'Structures', 'Sketching']},
    {'name': 'Data Science', 'emoji': '📊', 'color': const Color(0xFF64748B), 'skills': ['SQL', 'R/Python', 'Statistics']},
    {'name': 'Machine Learning', 'emoji': '🧠', 'color': const Color(0xFF8B5CF6), 'skills': ['Math', 'Supervised Learning', 'DL']},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_progCtrl.isCareerSelected.value) {
        _showCareerSelectionBottomSheet(isChange: false);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _activeCategoryData {
    final careerName = _progCtrl.selectedCareer.value ?? 'Computer Science';
    final raw = _allCareers.firstWhere(
      (cat) => cat['name'] == careerName,
      orElse: () => _allCareers[0],
    );
    final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
    if (!data.containsKey('stats')) {
      data['stats'] = {
        'score': '74/100',
        'statName': 'Hiring Score',
        'label': '${raw['name'].toString().split(' ')[0]} Level',
      };
    }
    return data;
  }

  void _showCareerSelectionBottomSheet({bool isChange = false}) {
    String? selectedTemp = _progCtrl.selectedCareer.value;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final warning = isChange ? _progCtrl.getCareerChangeWarning() : null;

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isChange ? '🔄 Change Career Pathway' : '🎯 Choose Your Career Track',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isChange 
                      ? 'Warning: Changing your career track resets all Career levels, XP, and badges. Old progress can be restored within 15 days.' 
                      : 'AI will automatically customize daily challenges, quizzes, roadmaps, and battles based on your track.',
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                  if (warning != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                      ),
                      child: Text(
                        warning,
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _allCareers.length,
                      itemBuilder: (context, index) {
                        final cat = _allCareers[index];
                        final isSelected = selectedTemp == cat['name'];
                        final color = cat['color'] as Color;
                        return GestureDetector(
                          onTap: warning != null ? null : () {
                            setModalState(() {
                              selectedTemp = cat['name'] as String;
                            });
                          },
                          child: Opacity(
                            opacity: warning != null ? 0.5 : 1.0,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? color.withOpacity(0.12) : AppTheme.cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? color : AppTheme.borderColor.withOpacity(0.4),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(cat['emoji'] as String, style: const TextStyle(fontSize: 22)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cat['name'] as String,
                                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                                        ),
                                        Text(
                                          'Focus: ${(cat['skills'] as List<String>).join(", ")}',
                                          style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected) Icon(Icons.check_circle_rounded, color: color, size: 20),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedTemp != null && warning == null
                            ? const Color(0xFF8B5CF6)
                            : AppTheme.borderColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: selectedTemp == null || warning != null
                          ? null
                          : () {
                              Navigator.pop(context);
                              if (isChange) {
                                _progCtrl.changeCareer(selectedTemp!);
                                Get.snackbar(
                                  '🎉 Track Changed!',
                                  'Your career track is now ${selectedTemp!}. Previous progress backed up for 15 days.',
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.9),
                                  colorText: Colors.white,
                                );
                              } else {
                                _progCtrl.selectCareer(selectedTemp!);
                              }
                              setState(() {});
                            },
                      child: Text(
                        isChange ? 'Confirm Change' : 'Confirm Track',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activeCat = _activeCategoryData;
      final color = activeCat['color'] as Color;

      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildHeroStats(),
                  const SizedBox(height: 20),
                  _buildCareerDnaHero(),
                  const SizedBox(height: 20),
                  
                  // Daily Missions (Video Watch & Quiz Solver)
                  _buildSectionTitle('📅 Daily Missions', 'Earn both Global and Career XP today'),
                  const SizedBox(height: 12),
                  _buildDailyMissionsSection(),
                  const SizedBox(height: 20),

                  // Interactive Activity Simulator
                  _buildSectionTitle('🕹️ Activity Simulator (Anti-Grind)', 'Earn XP by completing daily actions'),
                  const SizedBox(height: 12),
                  _buildActivitySimulator(),
                  const SizedBox(height: 20),

                  // Career Track Settings (Rollback & Switch Limits)
                  _buildSectionTitle('⚙️ Track Settings & Rollbacks', 'Manage pathway shifts & undo options'),
                  const SizedBox(height: 12),
                  _buildTrackManager(),
                  const SizedBox(height: 24),

                  _buildSectionTitle('🎮 Learn & Compete', 'Develop skills & battle'),
                  const SizedBox(height: 12),
                  _buildFeaturesGrid(_features.sublist(1, 6)),
                  const SizedBox(height: 20),
                  _buildSectionTitle('🏆 Track & Prove', 'Verify and showcase'),
                  const SizedBox(height: 12),
                  _buildFeaturesGrid(_features.sublist(6, 11)),
                  const SizedBox(height: 20),
                  _buildSectionTitle('🌐 Build & Earn', 'Connect and grow'),
                  const SizedBox(height: 12),
                  _buildFeaturesGrid(_features.sublist(11)),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildOnboardingSelectionScreen() {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '✨ Unlock Your Career Hub',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a professional path to customize your learning tree, unlock daily assignments, leaderboards, and enter skill battles.',
                style: GoogleFonts.poppins(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: StatefulBuilder(
                  builder: (context, setInnerState) {
                    return GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.15,
                      ),
                      itemCount: _allCareers.length,
                      itemBuilder: (context, index) {
                        final c = _allCareers[index];
                        final isSel = _onboardingSelectedCareer == c['name'];
                        final color = c['color'] as Color;
                        return GestureDetector(
                          onTap: () {
                            setInnerState(() {
                              _onboardingSelectedCareer = c['name'] as String;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSel ? color.withOpacity(0.12) : AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSel ? color : AppTheme.borderColor.withOpacity(0.4),
                                width: isSel ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(c['emoji'] as String, style: const TextStyle(fontSize: 22)),
                                    if (isSel) Icon(Icons.check_circle_rounded, color: color, size: 18),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  c['name'] as String,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (c['skills'] as List<String>).take(2).join(', '),
                                  style: GoogleFonts.poppins(
                                    color: AppTheme.textTertiary,
                                    fontSize: 9,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _onboardingSelectedCareer != null ? const Color(0xFF8B5CF6) : AppTheme.borderColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _onboardingSelectedCareer == null
                      ? null
                      : () {
                          _progCtrl.selectCareer(_onboardingSelectedCareer!);
                          Get.snackbar(
                            '🎉 Pathway Unlocked!',
                            'Creania has configured challenges for ${_onboardingSelectedCareer!}. Welcome to level 1!',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.9),
                            colorText: Colors.white,
                          );
                        },
                  child: Text(
                    'Unlock Career Pathway',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final activeCat = _activeCategoryData;
    final color = activeCat['color'] as Color;

    return SliverAppBar(
      pinned: true,
      expandedHeight: 180,
      backgroundColor: AppTheme.bgDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
          onPressed: () {
            Get.snackbar(
              'Career Path Progression 📈',
              'Perform Career hub tasks to increase Career level. Perform general platform activities to increase ID level.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.95),
              colorText: Colors.white,
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.8),
                color.withOpacity(0.4),
                const Color(0xFF09090B),
              ],
              stops: const [0, 0.4, 1],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(60, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(
                        '${activeCat['emoji']} ${activeCat['name']} Hub',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Career Path',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'AI Custom Focus: ${(activeCat['skills'] as List<String>).join(", ")}',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _headerChip('🔥 Streak Active', Colors.white),
                      const SizedBox(width: 8),
                      _headerChip('🎯 Level ${_progCtrl.careerLevel.value}', Colors.white),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHeroStats() {
    final activeCat = _activeCategoryData;
    final color = activeCat['color'] as Color;
    final stats = activeCat['stats'] as Map<String, dynamic>;

    return GestureDetector(
      onTap: () => Get.to(() => const DailyTaskScreen()),
      child: Row(
        children: [
          Expanded(child: _statCard('🏆', stats['statName'] as String, stats['score'] as String, color)),
          const SizedBox(width: 8),
          Expanded(child: _statCard('🧠', 'Brain Score', '72/100', const Color(0xFF8B5CF6))),
          const SizedBox(width: 8),
          Obx(() => Expanded(
            child: _statCard(
              '⚡', 
              stats['label'] as String, 
              'Lv.${_progCtrl.careerLevel.value}', 
              AppTheme.accentColor
            )
          )),
        ],
      ),
    );
  }

  Widget _buildDailyMissionsSection() {
    final StudyCategoryController studyCtrl = Get.find<StudyCategoryController>();
    final todayPack = studyCtrl.getTodayLearningDay();

    return Obx(() {
      final isVideoWatched = studyCtrl.videoWatchedToday.value;
      final isQuizDone = studyCtrl.quizCompletedToday.value;
      final score = studyCtrl.quizScoreToday.value;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          children: [
            // Task 1: Watch Video
            _buildMissionRow(
              title: 'Watch Today\'s Video Lesson',
              desc: todayPack.videoTitle,
              icon: isVideoWatched ? Icons.check_circle_rounded : Icons.play_circle_fill_rounded,
              iconColor: isVideoWatched ? const Color(0xFF10B981) : const Color(0xFF8B5CF6),
              xpText: '+150 Career XP',
              buttonText: isVideoWatched ? 'Completed' : 'Play Video',
              isCompleted: isVideoWatched,
              onTap: isVideoWatched
                  ? null
                  : () {
                      studyCtrl.markVideoWatched();
                      _progCtrl.addXp('daily_video', 150, true);
                      showDialog(
                        context: context,
                        builder: (context) => const VideoPlayerDialog(
                          videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
                        ),
                      );
                      Get.snackbar(
                        '🎥 Video Task Completed!',
                        'You watched today\'s video and earned 150 Career XP!',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: const Color(0xFF22C55E).withOpacity(0.9),
                        colorText: Colors.white,
                      );
                    },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Colors.white10, height: 1),
            ),
            // Task 2: Solve Quiz
            _buildMissionRow(
              title: 'Solve Daily MCQ Quiz',
              desc: isQuizDone ? 'Score: $score / 5 Correct Answers' : 'Test your learning from the video',
              icon: isQuizDone ? Icons.check_circle_rounded : Icons.quiz_rounded,
              iconColor: isQuizDone ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
              xpText: '+250 Career XP',
              buttonText: isQuizDone
                  ? 'Done'
                  : isVideoWatched
                      ? 'Solve Quiz'
                      : 'Locked 🔒',
              isCompleted: isQuizDone,
              onTap: !isVideoWatched || isQuizDone
                  ? null
                  : () async {
                      await Get.to(() => MCQQuizScreen(dailyDay: todayPack));
                      if (studyCtrl.quizCompletedToday.value) {
                        _progCtrl.addXp('daily_quiz', 250, true);
                        Get.snackbar(
                          '🎉 Quiz Completed!',
                          'You completed today\'s quiz and earned 250 Career XP!',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: const Color(0xFF22C55E).withOpacity(0.9),
                          colorText: Colors.white,
                        );
                      }
                    },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildMissionRow({
    required String title,
    required String desc,
    required IconData icon,
    required Color iconColor,
    required String xpText,
    required String buttonText,
    required bool isCompleted,
    required VoidCallback? onTap,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.poppins(color: Colors.white30, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              xpText,
              style: GoogleFonts.poppins(color: const Color(0xFFFFC107), fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 28,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCompleted ? Colors.white12 : const Color(0xFF8B5CF6),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Text(
                  buttonText,
                  style: GoogleFonts.poppins(
                    color: isCompleted ? Colors.white38 : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String emoji, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(color: color, fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCareerDnaHero() {
    final activeCat = _activeCategoryData;
    final color = activeCat['color'] as Color;

    return GestureDetector(
      onTap: () => Get.to(() => const DailyTaskScreen()),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (ctx, _) => Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2 + 0.1 * _pulseController.value),
                blurRadius: 12 + 6 * _pulseController.value,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(activeCat['emoji'] as String, style: const TextStyle(fontSize: 26))
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${activeCat['name'].toString().split(' ')[0]} DNA',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '⭐ UNIQUE',
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AI Custom Focus: ${(activeCat['skills'] as List<String>).take(3).join(", ")}',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivitySimulator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle_outline, color: Color(0xFF8B5CF6), size: 18),
              const SizedBox(width: 8),
              Text(
                'Simulate Learning Activities',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _simulatorPill(
                label: 'Solve Assignment',
                xpText: '+150 Career XP',
                color: const Color(0xFF6366F1),
                onTap: () => _simulateAction('assignment', 150, true),
              ),
              _simulatorPill(
                label: 'Career Quiz',
                xpText: '+80 Career XP',
                color: const Color(0xFFEC4899),
                onTap: () => _simulateAction('quiz', 80, true),
              ),
              _simulatorPill(
                label: 'Voice Room Host',
                xpText: '+120 ID XP',
                color: const Color(0xFF10B981),
                onTap: () => _simulateAction('voice_room', 120, false),
              ),
            ],
          ),
          Obx(() {
            if (!_simGrindActive.value && _simEarnedXp.value == 0) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _simGrindActive.value ? const Color(0xFFEF4444).withOpacity(0.08) : const Color(0xFF22C55E).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _simGrindActive.value ? const Color(0xFFEF4444).withOpacity(0.2) : const Color(0xFF22C55E).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _simGrindActive.value ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                    color: _simGrindActive.value ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _simGrindActive.value
                          ? 'Anti-Grind Active: Action repeated! XP payout decayed to ${(_simMultiplier.value * 100).toInt()}% (+${_simEarnedXp.value} XP).'
                          : 'Success: Action completed! Full XP awarded (+${_simEarnedXp.value} XP).',
                      style: GoogleFonts.poppins(
                        color: _simGrindActive.value ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _simulatorPill({required String label, required String xpText, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                Text(xpText, style: GoogleFonts.poppins(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _simulateAction(String actionId, int baseXp, bool isCareerXp) async {
    final result = await _progCtrl.addXp(actionId, baseXp, isCareerXp);
    _simEarnedXp.value = result['xpEarned'] as int;
    _simMultiplier.value = result['multiplier'] as double;
    _simGrindActive.value = result['antiGrindActive'] as bool;
    setState(() {});
  }

  Widget _buildTrackManager() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current track: ${_progCtrl.selectedCareer.value}',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_progCtrl.careerChangesCount.value}/3 Changes',
                style: GoogleFonts.poppins(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Developer Support Override',
                style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Obx(() => Switch(
                value: _progCtrl.isSupportOverrideActive.value,
                onChanged: (val) {
                  _progCtrl.isSupportOverrideActive.value = val;
                },
                activeColor: const Color(0xFF8B5CF6),
              )),
            ],
          ),
          const Divider(color: Colors.white10, height: 18),
          Row(
            children: [
              // Change track button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showCareerSelectionBottomSheet(isChange: true),
                  icon: const Icon(Icons.swap_horiz, size: 14),
                  label: Text('Switch Track', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.05),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (_progCtrl.isRollbackAvailable()) ...[
                const SizedBox(width: 8),
                // Rollback button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final ok = await _progCtrl.rollbackCareer();
                      if (ok) {
                        Get.snackbar(
                          '↩️ Career Restored!',
                          'Previous career progress successfully restored!',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: const Color(0xFF22C55E).withOpacity(0.9),
                          colorText: Colors.white,
                        );
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.history, size: 14, color: Color(0xFFF59E0B)),
                    label: Text('Undo Switch', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B).withOpacity(0.12),
                      foregroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        Text(
          subtitle,
          style: GoogleFonts.poppins(color: AppTheme.textTertiary, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildFeaturesGrid(List<Map<String, dynamic>> features) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 0.82,
      children: features.map((f) => _buildFeatureCard(f)).toList(),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    final color = feature['color'] as Color;
    return GestureDetector(
      onTap: () => Get.to(() => const DailyTaskScreen()),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(feature['emoji'] as String, style: const TextStyle(fontSize: 22)),
                if (feature['badge'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      feature['badge'] as String,
                      style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              feature['name'] as String,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              feature['desc'] as String,
              style: GoogleFonts.poppins(color: AppTheme.textTertiary, fontSize: 9),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
