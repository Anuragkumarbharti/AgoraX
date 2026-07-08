import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';

class AiMentorScreen extends StatefulWidget {
  const AiMentorScreen({Key? key}) : super(key: key);

  @override
  State<AiMentorScreen> createState() => _AiMentorScreenState();
}

class _AiMentorScreenState extends State<AiMentorScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _typingController;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _chatMessages = [
    {
      'isAi': true,
      'text':
          '👋 Namaste Anurag! Main tumhara personal AI Mentor hoon.\n\nAaj ka plan ready hai. Shuru karte hain! 🚀',
      'time': '9:00 AM',
    },
  ];

  bool _isTyping = false;

  final Map<String, dynamic> _todayPlan = {
    'studyToday': [
      '📖 Graph BFS/DFS — 45 min',
      '💡 2 Medium LeetCode problems — 60 min',
      '📝 System Design: Load Balancer — 30 min',
    ],
    'reviseYesterday': [
      '🔄 Tree Traversals — 15 min',
      '🔄 Binary Search variations — 10 min',
    ],
    'weakTopics': [
      ('Dynamic Programming', 38),
      ('System Design', 52),
      ('SQL Joins', 45),
    ],
    'strongTopics': [
      ('Arrays & Strings', 92),
      ('OOP Concepts', 88),
      ('Recursion', 81),
    ],
    'interviewReady': 72,
    'companyReady': 68,
    'govtExamReady': 35,
  };

  final List<String> _quickQuestions = [
    'Aaj kya padhna hai?',
    'Meri weak topics kya hain?',
    'Interview ke liye ready hoon?',
    'Company readiness score?',
    'Kal ka revision plan?',
  ];

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _typingController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Column(
        children: [
          _buildMentorHeader(),
          _buildTodaySnapshot(),
          const Divider(color: AppTheme.borderColor, height: 1),
          Expanded(child: _buildChatArea()),
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildMentorHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1).withOpacity(0.2),
            AppTheme.bgDark,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Get.back(),
          ),
          // AI Avatar
          Stack(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                ),
                child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 22)),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.bgDark, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Mentor',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Online • Personalized for you',
                  style: TextStyle(
                    color: AppTheme.accentColor.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppTheme.textTertiary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySnapshot() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _snapshotCard('📚 Study Today',
              '${(_todayPlan['studyToday'] as List).length} topics',
              const Color(0xFF6366F1), () => _scrollToStudyPlan()),
          const SizedBox(width: 10),
          _snapshotCard('🔄 Revise',
              '${(_todayPlan['reviseYesterday'] as List).length} topics',
              const Color(0xFF10B981), () => _addQuickMessage('Kal ka revision plan?')),
          const SizedBox(width: 10),
          _snapshotCard('💼 Interview',
              '${_todayPlan['interviewReady']}% ready',
              const Color(0xFFF59E0B), () => _addQuickMessage('Interview ke liye ready hoon?')),
          const SizedBox(width: 10),
          _snapshotCard('🏢 Company',
              '${_todayPlan['companyReady']}% ready',
              const Color(0xFFEC4899), () => _addQuickMessage('Company readiness score?')),
        ],
      ),
    );
  }

  Widget _snapshotCard(
      String title, String value, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        ..._chatMessages.map((msg) => _buildChatBubble(msg)),
        if (_isTyping) _buildTypingIndicator(),
        const SizedBox(height: 8),
        // Quick questions
        if (_chatMessages.length < 3) _buildQuickQuestions(),
      ],
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg) {
    final isAi = msg['isAi'] as bool;
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isAi
              ? LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.15),
                    const Color(0xFF8B5CF6).withOpacity(0.08),
                  ],
                )
              : null,
          color: isAi ? null : AppTheme.primaryColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isAi ? 4 : 16),
            bottomRight: Radius.circular(isAi ? 16 : 4),
          ),
          border: isAi
              ? Border.all(
                  color: const Color(0xFF6366F1).withOpacity(0.2))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAi) ...[
              const Row(
                children: [
                  Text('🤖', style: TextStyle(fontSize: 12)),
                  SizedBox(width: 4),
                  Text(
                    'AI Mentor',
                    style: TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              msg['text'] as String,
              style: TextStyle(
                color: isAi ? AppTheme.textPrimary : Colors.white,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                msg['time'] as String,
                style: TextStyle(
                  color: isAi
                      ? AppTheme.textTertiary
                      : Colors.white.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(
              color: const Color(0xFF6366F1).withOpacity(0.2)),
        ),
        child: AnimatedBuilder(
          animation: _typingController,
          builder: (ctx, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6366F1).withOpacity(
                    i == 0
                        ? _typingController.value
                        : i == 1
                            ? (0.3 + 0.7 * _typingController.value)
                            : (1.0 - _typingController.value),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickQuestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Questions',
          style: TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickQuestions.map((q) {
            return GestureDetector(
              onTap: () => _addQuickMessage(q),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.3)),
                ),
                child: Text(q,
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 10,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        border: Border(top: BorderSide(color: AppTheme.borderColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.bgLight,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: TextField(
                controller: _chatController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Mentor se poocho kuch bhi...',
                  hintStyle: TextStyle(
                      color: AppTheme.textTertiary, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) _addMessage(v.trim());
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              final text = _chatController.text.trim();
              if (text.isNotEmpty) _addMessage(text);
            },
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _addQuickMessage(String question) {
    _addMessage(question);
  }

  void _scrollToStudyPlan() {
    _addMessage('Aaj kya padhna hai?');
  }

  void _addMessage(String text) {
    final now = TimeOfDay.now();
    final timeStr =
        '${now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}';

    setState(() {
      _chatMessages.add({'isAi': false, 'text': text, 'time': timeStr});
      _chatController.clear();
      _isTyping = true;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _chatMessages.add({
            'isAi': true,
            'text': _getMentorResponse(text),
            'time': timeStr,
          });
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  String _getMentorResponse(String question) {
    final q = question.toLowerCase();
    if (q.contains('aaj') || q.contains('today') || q.contains('padhna')) {
      return '📅 Aaj ka study plan:\n\n'
          '1. ${(_todayPlan['studyToday'] as List)[0]}\n'
          '2. ${(_todayPlan['studyToday'] as List)[1]}\n'
          '3. ${(_todayPlan['studyToday'] as List)[2]}\n\n'
          'Pehle Graph se shuru karo — teri DP weak hai, baad me connect karenge. 💪';
    } else if (q.contains('weak') || q.contains('problem')) {
      final weakTopics = _todayPlan['weakTopics'] as List;
      final firstWeak = weakTopics[0] as (String, int);
      return '⚠️ Teri weak topics:\n\n'
          '1. ${firstWeak.$1} — focus karo\n\n'
          'DP pe daily 20 min do. Har roz 1 medium problem solve karo. Improvement 2 hafte me dikhega! 📈';
    } else if (q.contains('interview')) {
      return '💼 Interview Readiness: ${_todayPlan['interviewReady']}%\n\n'
          '✅ Strong: Arrays, OOP, Recursion\n'
          '⚠️ Work on: DP, System Design\n\n'
          'Mock interview schedule karo is week. Tera coding speed acha hai, communication thoda improve karo. 🎯';
    } else if (q.contains('company') || q.contains('job')) {
      return '🏢 Company Readiness: ${_todayPlan['companyReady']}%\n\n'
          'Top companies ke liye:\n'
          '• 2 more projects add karo portfolio me\n'
          '• GitHub contributions badho\n'
          '• 50 more LeetCode solve karo\n\n'
          '3 months me tum ready ho jaoge! 🚀';
    } else if (q.contains('revision') || q.contains('kal')) {
      return '🔄 Kal ka revision:\n\n'
          '${(_todayPlan['reviseYesterday'] as List)[0]}\n'
          '${(_todayPlan['reviseYesterday'] as List)[1]}\n\n'
          'Flashcards use karo revision ke liye — 70% zyada retention hoga. ⚡';
    }
    return '🤖 Great question! Main analyze kar raha hoon...\n\n'
        'Based on teri progress:\n'
        '• Aaj: Graph + 2 LeetCode problems\n'
        '• Kal: System Design revision\n\n'
        'Consistently 2 hours daily se tu 3 months me top 10% me hoga! 💪🔥';
  }
}
