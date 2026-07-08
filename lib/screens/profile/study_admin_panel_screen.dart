import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../models/daily_learning_model.dart';
import '../../services/study_category_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudyAdminPanelScreen extends StatefulWidget {
  const StudyAdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<StudyAdminPanelScreen> createState() => _StudyAdminPanelScreenState();
}

class _StudyAdminPanelScreenState extends State<StudyAdminPanelScreen> {
  final StudyCategoryController _controller = Get.find<StudyCategoryController>();
  
  String? _selectedCategory;
  int _selectedDay = 1;
  
  // Controllers
  final TextEditingController _youtubeUrlController = TextEditingController();
  final TextEditingController _videoTitleController = TextEditingController();
  final TextEditingController _xpRewardController = TextEditingController(text: '50');
  final TextEditingController _coinRewardController = TextEditingController(text: '15');
  
  String _difficulty = 'Medium';
  DateTime _publishDate = DateTime.now();

  // Questions state
  final List<TextEditingController> _qTextControllers = List.generate(5, (_) => TextEditingController());
  final List<List<TextEditingController>> _qOptionControllers = List.generate(5, (_) => List.generate(4, (_) => TextEditingController()));
  final List<int> _correctAnswerIndices = List.generate(5, (_) => 0);
  final List<TextEditingController> _qExplanationControllers = List.generate(5, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    // Default select first subcategory in hierarchy
    final firstGroup = _controller.categoriesHierarchy.values.first;
    _selectedCategory = firstGroup.first;
    _loadDayContent();
  }

  @override
  void dispose() {
    _youtubeUrlController.dispose();
    _videoTitleController.dispose();
    _xpRewardController.dispose();
    _coinRewardController.dispose();
    for (var c in _qTextControllers) {
      c.dispose();
    }
    for (var row in _qOptionControllers) {
      for (var c in row) {
        c.dispose();
      }
    }
    for (var c in _qExplanationControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // Load existing content of selected category/day to populate form
  void _loadDayContent() {
    if (_selectedCategory == null) return;
    
    // Fetch day from controller if exists, otherwise load defaults
    final pack = _controller.learningPacks[_selectedCategory!];
    final day = pack?.days.firstWhereOrNull((d) => d.dayNumber == _selectedDay);

    if (day != null) {
      _youtubeUrlController.text = day.youtubeUrl;
      _videoTitleController.text = day.videoTitle;
      _xpRewardController.text = day.xpReward.toString();
      _coinRewardController.text = day.coinReward.toString();
      _difficulty = day.difficultyLevel;
      _publishDate = day.publishDate;

      for (int i = 0; i < 5; i++) {
        if (i < day.questions.length) {
          _qTextControllers[i].text = day.questions[i].questionText;
          _correctAnswerIndices[i] = day.questions[i].correctAnswerIndex;
          _qExplanationControllers[i].text = day.questions[i].explanation;
          for (int j = 0; j < 4; j++) {
            if (j < day.questions[i].options.length) {
              _qOptionControllers[i][j].text = day.questions[i].options[j];
            } else {
              _qOptionControllers[i][j].text = '';
            }
          }
        }
      }
    } else {
      // Set default dummy values
      _youtubeUrlController.text = 'https://assets.mixkit.co/videos/preview/mixkit-writing-computer-code-one-finger-typing-43022-large.mp4';
      _videoTitleController.text = 'Introduction to $_selectedCategory';
      _xpRewardController.text = '50';
      _coinRewardController.text = '15';
      _difficulty = 'Medium';
      _publishDate = DateTime.now();

      for (int i = 0; i < 5; i++) {
        _qTextControllers[i].text = 'Sample Question ${i + 1} for $_selectedCategory?';
        _correctAnswerIndices[i] = 0;
        _qExplanationControllers[i].text = 'This is the explanation for question ${i + 1}.';
        _qOptionControllers[i][0].text = 'Option A (Correct)';
        _qOptionControllers[i][1].text = 'Option B';
        _qOptionControllers[i][2].text = 'Option C';
        _qOptionControllers[i][3].text = 'Option D';
      }
    }
    setState(() {});
  }

  Future<void> _selectPublishDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _publishDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _publishDate) {
      setState(() {
        _publishDate = picked;
      });
    }
  }

  void _savePack() {
    if (_selectedCategory == null) return;

    // Build MCQ questions list
    final List<MCQQuestion> questions = [];
    for (int i = 0; i < 5; i++) {
      final List<String> options = [
        _qOptionControllers[i][0].text.trim(),
        _qOptionControllers[i][1].text.trim(),
        _qOptionControllers[i][2].text.trim(),
        _qOptionControllers[i][3].text.trim(),
      ];
      questions.add(
        MCQQuestion(
          questionText: _qTextControllers[i].text.trim(),
          options: options,
          correctAnswerIndex: _correctAnswerIndices[i],
          explanation: _qExplanationControllers[i].text.trim(),
        ),
      );
    }

    // Build day object
    final dayObj = DailyLearningDay(
      dayNumber: _selectedDay,
      youtubeUrl: _youtubeUrlController.text.trim(),
      videoTitle: _videoTitleController.text.trim(),
      videoDurationSeconds: 400, // mock duration
      questions: questions,
      xpReward: int.tryParse(_xpRewardController.text.trim()) ?? 50,
      coinReward: int.tryParse(_coinRewardController.text.trim()) ?? 15,
      difficultyLevel: _difficulty,
      publishDate: _publishDate,
    );

    // Save to controller
    _controller.adminSavePack(_selectedCategory!, dayObj);

    Get.snackbar(
      '💾 Pack Saved!',
      'Successfully published Day $_selectedDay for $_selectedCategory.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.accentColor.withOpacity(0.9),
      colorText: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get flat subcategory list for dropdown selection
    final List<String> flatSubcategories = [];
    _controller.categoriesHierarchy.values.forEach((list) {
      flatSubcategories.addAll(list);
    });

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppTheme.bgLight,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.edit_note), text: 'Manage Content'),
                Tab(icon: Icon(Icons.analytics_outlined), text: 'User Analytics'),
                Tab(icon: Icon(Icons.psychology_outlined), text: 'Level Simulator'),
              ],
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textTertiary,
              indicatorColor: AppTheme.primaryColor,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Form Tab
                  _buildManageContentTab(flatSubcategories),
                  // Analytics Tab
                  _buildAnalyticsTab(),
                  // Level Simulator Tab
                  _buildLevelSimulatorTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageContentTab(List<String> flatSubcategories) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Selection details
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Category', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          dropdownColor: AppTheme.bgLight,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: flatSubcategories.map((sub) {
                            return DropdownMenuItem<String>(
                              value: sub,
                              child: Text(sub, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedCategory = val;
                              _loadDayContent();
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Day Number', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedDay,
                          dropdownColor: AppTheme.bgLight,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: List.generate(7, (i) => i + 1).map((day) {
                            return DropdownMenuItem<int>(
                              value: day,
                              child: Text('Day $day'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedDay = val;
                                _loadDayContent();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          const Divider(color: AppTheme.borderColor),
          const SizedBox(height: 12),
          
          // Section: YouTube Link Info
          const Text('YouTube Video Settings', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildTextField(_videoTitleController, 'Video Title', 'e.g., Intro to Binary Search'),
          const SizedBox(height: 12),
          _buildTextField(_youtubeUrlController, 'YouTube URL / Stream Link', 'e.g., https://youtube.com/watch?...'),
          
          const SizedBox(height: 16),
          
          // Row: Rewards & Difficulty
          Row(
            children: [
              Expanded(child: _buildTextField(_xpRewardController, 'XP Reward', 'e.g., 50', keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField(_coinRewardController, 'Coins Reward', 'e.g., 15', keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Difficulty', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _difficulty,
                          dropdownColor: AppTheme.bgLight,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: ['Easy', 'Medium', 'Hard'].map((d) {
                            return DropdownMenuItem<String>(value: d, child: Text(d));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _difficulty = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Publish Date', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _selectPublishDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_publishDate.day}/${_publishDate.month}/${_publishDate.year}',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                            const Icon(Icons.calendar_month, color: AppTheme.textTertiary, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          const Divider(color: AppTheme.borderColor),
          const SizedBox(height: 12),
          
          // Section: 5 MCQ Questions
          const Text('Manage 5 MCQ Questions', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          ...List.generate(5, (qIdx) {
            return Card(
              color: AppTheme.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUESTION ${qIdx + 1}',
                      style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(_qTextControllers[qIdx], 'Question Text', 'What is...?'),
                    const SizedBox(height: 12),
                    
                    // Options text fields
                    ...List.generate(4, (optIdx) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildTextField(
                          _qOptionControllers[qIdx][optIdx],
                          'Option ${String.fromCharCode(65 + optIdx)}',
                          'Value for option...',
                        ),
                      );
                    }),
                    
                    const SizedBox(height: 12),
                    
                    // Correct Answer Selector
                    Row(
                      children: [
                        const Text('Correct Option: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _correctAnswerIndices[qIdx],
                              dropdownColor: AppTheme.bgLight,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              items: List.generate(4, (i) => i).map((i) {
                                return DropdownMenuItem<int>(
                                  value: i,
                                  child: Text('Option ${String.fromCharCode(65 + i)}'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _correctAnswerIndices[qIdx] = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    _buildTextField(_qExplanationControllers[qIdx], 'Short Explanation', 'Explain why correct option is...'),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),
          
          // Action Button: Save Pack
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _savePack,
              child: const Text('Publish Daily Pack', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            fillColor: AppTheme.bgDark.withOpacity(0.8),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsTab() {
    return Obx(() {
      final totalCompletions = _controller.totalCompletedMissions;
      final avgScore = _controller.averageScore;
      final perfectCount = _controller.perfectScoreCount;
      final completionRate = _controller.completionRatePercentage;

      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Global Completion Analytics',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Overview of student performance and completion rates',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Completion rate card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: completionRate / 100,
                    strokeWidth: 6,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.accentColor),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${completionRate.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('User Completion Rate', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Row Stats
          Row(
            children: [
              _analyticsStatCard('Total Submissions', '$totalCompletions users', Icons.people_outline, const Color(0xFF6366F1)),
              const SizedBox(width: 12),
              _analyticsStatCard('Average MCQ Score', '${avgScore.toStringAsFixed(2)} / 5', Icons.quiz_outlined, const Color(0xFF8B5CF6)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _analyticsStatCard('Perfect Scores (5/5)', '$perfectCount times', Icons.star_outline, const Color(0xFFFBBF24)),
              const SizedBox(width: 12),
              _analyticsStatCard('Active Study Paths', '${_controller.learningPacks.length} active', Icons.auto_stories_outlined, const Color(0xFF10B981)),
            ],
          ),

          const SizedBox(height: 32),
          const Text(
            'User Completion Feed',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (_controller.completionAnalytics.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('No submissions logged yet.', style: TextStyle(color: AppTheme.textTertiary.withOpacity(0.7), fontSize: 13)),
              ),
            )
          else
            ..._controller.completionAnalytics.reversed.map((record) {
              final date = DateTime.parse(record['date']);
              final dateStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} - ${date.day}/${date.month}';
              final category = record['category'] ?? '';
              final score = record['score'] ?? 0;
              final perfect = record['perfect'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Time: $dateStr  |  Day ${record['day']}', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: perfect ? const Color(0xFFFBBF24).withOpacity(0.12) : AppTheme.borderColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Score: $score/5',
                            style: TextStyle(
                              color: perfect ? const Color(0xFFFBBF24) : AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      );
    });
  }

  Widget _analyticsStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelSimulatorTab() {
    final TextEditingController xpInputController = TextEditingController(text: '100');

    return Obx(() {
      final xp = _controller.userXp.value;
      final lvl = _controller.userLevel.value;
      final tier = StudyCategoryController.getTierForLevel(lvl);
      final coins = _controller.silverCoins.value;

      final nextThreshold = _controller.getXpForNextLevel(lvl);
      final progressFraction = _controller.getLevelProgress(xp);

      final todayXp = _controller.xpEarnedToday.value;
      final weekXp = _controller.xpEarnedThisWeek.value;
      final monthXp = _controller.xpEarnedThisMonth.value;

      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: tier.gradientColors),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: tier.color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tier.icon} ${tier.name}',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('Current Level: $lvl', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                    Text('🪙 $coins Coins', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$xp XP', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('$nextThreshold XP', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progressFraction,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Caps & Limits breakdown
          const Text(
            'XP LIMITS STATUS',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              children: [
                _limitRow('Daily Cap', todayXp, 300, Colors.green),
                const SizedBox(height: 14),
                _limitRow('Weekly Cap', weekXp, 2000, Colors.blue),
                const SizedBox(height: 14),
                _limitRow('Monthly Cap', monthXp, 8000, Colors.purple),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Simulation controls
          const Text(
            'SIMULATE XP GRANTS',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              children: [
                TextField(
                  controller: xpInputController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'XP Amount to Grant',
                    labelStyle: const TextStyle(color: AppTheme.textTertiary),
                    filled: true,
                    fillColor: AppTheme.bgDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          final amt = int.tryParse(xpInputController.text.trim()) ?? 0;
                          if (amt <= 0) return;
                          final gained = await _controller.addXp(amt, source: 'Admin Simulation');
                          Get.snackbar(
                            gained > 0 ? '✨ XP Granted!' : '⚠️ Cap Blocked XP!',
                            gained > 0 
                              ? 'Successfully granted $gained XP (Requested $amt XP).'
                              : 'Cannot earn more XP. You reached the active limits!',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: gained > 0 ? AppTheme.accentColor.withOpacity(0.9) : AppTheme.errorColor.withOpacity(0.9),
                            colorText: Colors.white,
                          );
                        },
                        child: const Text('Simulate Add XP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Danger zone
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.errorColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.refresh, color: AppTheme.errorColor, size: 18),
                  label: const Text('Reset Level, XP & Limits', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    _controller.userXp.value = 0;
                    _controller.userLevel.value = 1;
                    _controller.xpEarnedToday.value = 0;
                    _controller.xpEarnedThisWeek.value = 0;
                    _controller.xpEarnedThisMonth.value = 0;
                    _controller.silverCoins.value = 0;
                    _controller.unlockedBadges.clear();

                    await prefs.setInt('study_user_xp', 0);
                    await prefs.setInt('study_user_level', 1);
                    await prefs.setInt('study_silver_coins', 0);
                    await prefs.setInt('study_xp_earned_today', 0);
                    await prefs.setInt('study_xp_earned_this_week', 0);
                    await prefs.setInt('study_xp_earned_this_month', 0);
                    await prefs.remove('study_badges');

                    Get.snackbar(
                      '🧹 Reset Completed',
                      'Level, XP, coins, and limit counters have been cleared.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppTheme.errorColor.withOpacity(0.9),
                      colorText: Colors.white,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      );
    });
  }

  Widget _limitRow(String title, int earned, int cap, Color color) {
    final ratio = cap > 0 ? earned / cap : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            Text('$earned / $cap XP', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
