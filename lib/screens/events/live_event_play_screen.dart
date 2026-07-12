import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../models/event_model.dart';
import '../../models/user_model.dart';
import '../profile/user_profile_screen.dart';
import 'live_event_winner_screen.dart';

class LiveEventPlayScreen extends StatefulWidget {
  const LiveEventPlayScreen({Key? key, required this.event}) : super(key: key);
  final Event event;

  @override
  State<LiveEventPlayScreen> createState() => _LiveEventPlayScreenState();
}

class _LiveEventPlayScreenState extends State<LiveEventPlayScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  int _currentQuestionIndex = 0;
  int _currentRoundIndex = 0;
  bool _isInBreakMode = false;
  int _breakCountdownSeconds = 10;
  Timer? _breakTimer;
  bool _isEliminated = false;
  bool _showResultDetails = false;
  bool _showLeaderboardPopup = false;
  bool _buzzerPressed = false;
  bool _isBuzzerActive = true;
  String? _whoBuzzed;
  Timer? _buzzerCompetitorTimer;
  int _score = 0;
  int _rank = 12;
  int _correctCount = 0;
  int _streak = 0;
  double _totalResponseTime = 0.0;
  int _earnedCoins = 0;

  // Proctoring
  int _proctoringViolations = 0;
  final int _maxAllowedViolations = 3;
  bool _isDisqualified = false;

  // Timing
  int _questionTimer = 20; // 20s timer per question
  Timer? _countdownTimer;
  double _responseTimerElapsed = 0.0;
  Timer? _responseStopwatch;

  // Selected option
  String? _selectedOption;
  bool _isSubmitted = false;

  // Screen Share mock
  bool _isScreenSharing = false;

  // Chat messages mock
  final List<Map<String, String>> _chatMessages = [
    {'sender': 'Rahul22', 'msg': 'Let\'s go! First question is easy'},
    {'sender': 'SonalG', 'msg': 'Is this live mark-sheet checked?'},
    {'sender': 'Admin', 'msg': '💡 Focus! AI Anti-cheat screen proctoring is enabled.'},
  ];
  final _chatInputCtrl = TextEditingController();

  // Animations
  late AnimationController _rankAnimCtrl;
  late Animation<double> _rankScaleAnim;
  String _rankChangeText = '';
  Color _rankChangeColor = Colors.green;

  // Mock Questions database
  final List<Map<String, dynamic>> _mockQuestions = [
    {
      'question': 'Which of the following is not a state management approach in Flutter?',
      'options': ['Provider', 'Bloc', 'GetX', 'LayoutBuilder'],
      'answer': 'LayoutBuilder',
      'difficulty': 'Easy',
      'timer': 15,
    },
    {
      'question': 'What is the time complexity of searching in a balanced Binary Search Tree (BST)?',
      'options': ['O(1)', 'O(log N)', 'O(N)', 'O(N log N)'],
      'answer': 'O(log N)',
      'difficulty': 'Medium',
      'timer': 25,
    },
    {
      'question': 'Which Dart feature is used to create a generator function that yields values asynchronously?',
      'options': ['async*', 'yield*', 'StreamController', 'Future.async'],
      'answer': 'async*',
      'difficulty': 'Hard',
      'timer': 40,
    },
    {
      'question': 'Which widget is used to overlay elements stack-like on top of each other?',
      'options': ['Row', 'Column', 'Stack', 'Wrap'],
      'answer': 'Stack',
      'difficulty': 'Easy',
      'timer': 15,
    },
  ];

  // Leaderboard data
  final List<Map<String, dynamic>> _leaderboard = [
    {'rank': 1, 'name': 'AdityaK', 'score': 30, 'correct': 3, 'time': '4.2s', 'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde'},
    {'rank': 2, 'name': 'SnehaP', 'score': 28, 'correct': 3, 'time': '5.1s', 'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330'},
    {'rank': 3, 'name': 'KunalR', 'score': 20, 'correct': 2, 'time': '3.9s', 'avatar': 'https://images.unsplash.com/photo-1599566150163-29194dcaad36'},
    {'rank': 4, 'name': 'RohanM', 'score': 20, 'correct': 2, 'time': '5.5s', 'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d'},
    {'rank': 5, 'name': 'TanyaS', 'score': 18, 'correct': 2, 'time': '6.2s', 'avatar': 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2'},
    {'rank': 6, 'name': 'AmitB', 'score': 10, 'correct': 1, 'time': '3.1s', 'avatar': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e'},
    {'rank': 7, 'name': 'VikramS', 'score': 10, 'correct': 1, 'time': '4.8s', 'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _rankAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _rankScaleAnim = CurvedAnimation(parent: _rankAnimCtrl, curve: Curves.elasticOut);

    _startQuestion(_currentQuestionIndex);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _responseStopwatch?.cancel();
    _chatInputCtrl.dispose();
    _rankAnimCtrl.dispose();
    super.dispose();
  }

  // ── Proctoring Focus Alerts ────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.event.antiCheat.screenMonitoring && !_isDisqualified) {
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        _triggerProctoringViolation('App Minimized / Switched Tab');
      }
    }
  }

  void _triggerProctoringViolation(String reason) {
    setState(() {
      _proctoringViolations++;
      if (_proctoringViolations >= _maxAllowedViolations) {
        _isDisqualified = true;
        _countdownTimer?.cancel();
        _responseStopwatch?.cancel();
      }
    });

    HapticFeedback.heavyImpact();
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.bgLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 24),
            const SizedBox(width: 8),
            const Text('Secure Mode Alert 🛡️', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          _isDisqualified
              ? 'You have been disqualified for switching screens/tabs $_proctoringViolations times.'
              : 'Violation detected: $reason.\nLeaving the exam screen is prohibited.\n\nWarnings: $_proctoringViolations/$_maxAllowedViolations',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () {
              Get.back();
              if (_isDisqualified) {
                Get.off(() => LiveEventWinnerScreen(event: widget.event, wasDisqualified: true));
              }
            },
            child: Text(_isDisqualified ? 'View Results' : 'Acknowledge', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  // ── Question Control flow ──────────────────────────────────────────────────
  void _startQuestion(int index) {
    if (index >= _mockQuestions.length) {
      // Completed, check if there is a next round
      if (widget.event.isMultiRound && _currentRoundIndex < widget.event.rounds.length - 1) {
        _startBreakMode();
      } else {
        _finishEvent();
      }
      return;
    }

    final q = _mockQuestions[index];
    final isBuzzer = widget.event.isMultiRound &&
        _currentRoundIndex < widget.event.rounds.length &&
        widget.event.rounds[_currentRoundIndex].isBuzzerMode;

    setState(() {
      _currentQuestionIndex = index;
      _questionTimer = q['timer'] as int;
      _selectedOption = null;
      _isSubmitted = false;
      _showResultDetails = false;
      _showLeaderboardPopup = false;
      _responseTimerElapsed = 0.0;
      if (isBuzzer) {
        _buzzerPressed = false;
        _whoBuzzed = null;
        _isBuzzerActive = true;
      }
    });

    if (isBuzzer) {
      _buzzerCompetitorTimer?.cancel();
      _buzzerCompetitorTimer = Timer(const Duration(seconds: 3), () {
        if (!_buzzerPressed && _whoBuzzed == null && mounted) {
          setState(() {
            _whoBuzzed = 'Vikram Singh';
            _isBuzzerActive = false;
          });
          Get.snackbar(
            '🔔 Vikram Singh Buzzed First!',
            'Vikram has 5 seconds to answer. Please wait...',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange.withOpacity(0.9),
            colorText: Colors.white,
          );
          Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _whoBuzzed = null;
                _isBuzzerActive = true;
              });
              Get.snackbar(
                '❌ Wrong Answer by Vikram!',
                'Buzzer is open again! Tap buzzer now to lock.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.red.withOpacity(0.9),
                colorText: Colors.white,
              );
            }
          });
        }
      });
    }

    // Timing stopwatch
    _responseStopwatch?.cancel();
    _responseStopwatch = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _responseTimerElapsed += 0.1;
    });

    // Real-time release countdown
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_questionTimer > 0) {
        setState(() {
          _questionTimer--;
        });
      } else {
        _countdownTimer?.cancel();
        _onQuestionTimerExpired();
      }
    });
  }

  void _startBreakMode() {
    setState(() {
      _isInBreakMode = true;
      _breakCountdownSeconds = widget.event.rounds[_currentRoundIndex].breakTimeMinutes > 0
          ? widget.event.rounds[_currentRoundIndex].breakTimeMinutes
          : 10;
    });

    _breakTimer?.cancel();
    _breakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_breakCountdownSeconds > 0) {
        setState(() {
          _breakCountdownSeconds--;
        });
      } else {
        _breakTimer?.cancel();
        setState(() {
          _isInBreakMode = false;
          _currentRoundIndex++;
          _currentQuestionIndex = 0;
        });
        _startQuestion(0);
      }
    });
  }

  void _submitAnswer() {
    if (_isSubmitted) return;
    _responseStopwatch?.cancel();
    setState(() {
      _isSubmitted = true;
    });
  }

  void _onQuestionTimerExpired() {
    _countdownTimer?.cancel();
    _responseStopwatch?.cancel();
    _buzzerCompetitorTimer?.cancel();

    // If they didn't select any option by the time timer expired, auto-submit empty
    if (!_isSubmitted) {
      _selectedOption = '';
      _isSubmitted = true;
    }

    final q = _mockQuestions[_currentQuestionIndex];
    final isCorrect = _selectedOption == q['answer'];
    int pointsEarned = 0;

    setState(() {
      if (isCorrect) {
        pointsEarned = 10;
        // Streak bonus
        _streak++;
        if (_streak >= 3) {
          pointsEarned += 2;
        }
        // Speed bonus
        if (_responseTimerElapsed < 3.0) {
          pointsEarned += 2;
        }

        _score += pointsEarned;
        _correctCount++;
        _totalResponseTime += _responseTimerElapsed;
        _earnedCoins += widget.event.isPaid ? 5 : 1;

        // Simulate rank up
        if (_rank > 2) {
          _rank -= Random().nextInt(2) + 1;
          _showRankAnimation('RANK UP! ↑', Colors.green);
        }
      } else {
        _streak = 0;
        // Negative marking
        if (widget.event.negativeMarking) {
          _score = max(0, _score - 2);
        }
        // Simulate rank down
        if (_rank < 25) {
          _rank += Random().nextInt(2) + 1;
          _showRankAnimation('RANK DOWN ↓', Colors.red);
        }
      }
      _showResultDetails = true;
      _showLeaderboardPopup = true;
    });

    // Wait 4 seconds showing leaderboard popup, then advance
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showLeaderboardPopup = false;
          _showResultDetails = false;
        });
        _startQuestion(_currentQuestionIndex + 1);
      }
    });
  }

  void _showRankAnimation(String text, Color color) {
    setState(() {
      _rankChangeText = text;
      _rankChangeColor = color;
    });
    _rankAnimCtrl.forward(from: 0.0);
  }

  void _finishEvent() {
    _countdownTimer?.cancel();
    _responseStopwatch?.cancel();
    Get.off(() => LiveEventWinnerScreen(
          event: widget.event,
          finalScore: _score,
          correctCount: _correctCount,
          averageTime: _correctCount > 0 ? _totalResponseTime / _correctCount : 0.0,
          accruedCoins: _earnedCoins,
        ));
  }

  void _navigateToUserProfile(String name) {
    // Navigate mock
    final targetUser = User(
      id: 'uid_${name.toLowerCase()}',
      username: name.toLowerCase(),
      email: '${name.toLowerCase()}@creania.app',
      displayName: name,
      interests: ['Flutter', 'Competitions'],
      communities: [widget.event.organizer],
      followers: 120,
      following: 40,
      isVerified: false,
      isPremium: false,
      reputation: 240,
      sid: '984024',
    );
    Get.to(() => UserProfileScreen(user: targetUser));
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisqualified) {
      return const Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isInBreakMode) {
      return _buildBreakScreen();
    }

    final q = _mockQuestions[_currentQuestionIndex];
    final isBuzzerRound = widget.event.isMultiRound &&
        _currentRoundIndex < widget.event.rounds.length &&
        widget.event.rounds[_currentRoundIndex].isBuzzerMode;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: SafeArea(
            child: Column(
              children: [
                // ── Top Info Bar ──────────────────────────────────────────────────
                _buildTopBar(q),

                // ── Screen Share Overlay (Host Side) ──────────────────────────────
                if (_isScreenSharing) _buildScreenShareOverlay(),

                // ── Main Layout (Question Area Full Width) ────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Question Card
                        Expanded(
                          child: _buildQuestionCard(q),
                        ),
                        const SizedBox(height: 16),

                        if (isBuzzerRound) ...[
                          if (_whoBuzzed != null && _whoBuzzed != 'me')
                            _buildCompetitorBuzzedCard()
                          else if (!_buzzerPressed)
                            _buildBuzzerWidget()
                          else ...[
                            ...List.generate(4, (i) {
                              final opt = q['options'][i] as String;
                              return _buildOptionButton(opt);
                            }),
                            const SizedBox(height: 12),
                            _buildSubmitButton(),
                          ],
                        ] else ...[
                          // Option Buttons
                          ...List.generate(4, (i) {
                            final opt = q['options'][i] as String;
                            return _buildOptionButton(opt);
                          }),
                          const SizedBox(height: 12),
                          _buildSubmitButton(),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Bottom Info Bar ───────────────────────────────────────────────
                _buildBottomStatsBar(),
              ],
            ),
          ),
        ),
        if (_showLeaderboardPopup)
          _buildLeaderboardPopupOverlay(),
      ],
    );
  }

  // ── Top Bar Widget ─────────────────────────────────────────────────────────
  Widget _buildTopBar(Map<String, dynamic> q) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.event.title,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: AppTheme.accentColor, size: 14),
                  const SizedBox(width: 4),
                  Text('$_questionTimer s left', style: const TextStyle(color: AppTheme.accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Timer Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _questionTimer / (q['timer'] as int),
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                _questionTimer < 5 ? Colors.red : AppTheme.primaryColor,
              ),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Question Card Widget ───────────────────────────────────────────────────
  Widget _buildQuestionCard(Map<String, dynamic> q) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Question ${_currentQuestionIndex + 1}/${_mockQuestions.length}',
                  style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                'Difficulty: ${q['difficulty']}',
                style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                q['question'] as String,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, height: 1.4),
              ),
            ),
          ),
          if (_showResultDetails) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.bgDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedOption == q['answer'] ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                        color: _selectedOption == q['answer'] ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedOption == q['answer'] ? 'Correct! 🎉' : 'Incorrect ❌',
                        style: TextStyle(
                          color: _selectedOption == q['answer'] ? Colors.green : Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Rank: #$_rank • Score: $_score pts',
                    style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Option Button Widget ───────────────────────────────────────────────────
  Widget _buildOptionButton(String optionText) {
    final isSelected = _selectedOption == optionText;
    final q = _mockQuestions[_currentQuestionIndex];
    final isCorrectOpt = q['answer'] == optionText;

    Color containerColor = Colors.white.withOpacity(0.05);
    Color borderColor = Colors.white.withOpacity(0.1);
    Color textColor = Colors.white;

    if (_showResultDetails) {
      if (isCorrectOpt) {
        containerColor = Colors.green.withOpacity(0.15);
        borderColor = Colors.green;
        textColor = Colors.green;
      } else if (isSelected) {
        containerColor = Colors.red.withOpacity(0.15);
        borderColor = Colors.red;
        textColor = Colors.red;
      }
    } else if (isSelected) {
      containerColor = AppTheme.primaryColor.withOpacity(0.15);
      borderColor = AppTheme.primaryColor;
      textColor = AppTheme.primaryColor;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: _isSubmitted
            ? null
            : () {
                setState(() {
                  _selectedOption = optionText;
                });
                HapticFeedback.lightImpact();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Text(
            optionText,
            style: TextStyle(color: textColor, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ),
    );
  }

  // ── Submit Button Widget ───────────────────────────────────────────────────
  Widget _buildSubmitButton() {
    final hasSelected = _selectedOption != null;
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasSelected ? AppTheme.accentColor : Colors.grey.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: (hasSelected && !_isSubmitted) ? _submitAnswer : null,
        child: Text(
          _isSubmitted ? 'SUBMITTED' : 'LOCK ANSWER',
          style: TextStyle(color: hasSelected ? Colors.white : Colors.white30, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ── Tab contents right side ────────────────────────────────────────────────
  int _activeRightTab = 0; // 0=Leaderboard, 1=Chat, 2=Stats

  Widget _buildRightTabHeader() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          _rightTabItem('Leaderboard', 0),
          _rightTabItem('Chat', 1),
          _rightTabItem('Host Room', 2),
        ],
      ),
    );
  }

  Widget _rightTabItem(String label, int idx) {
    final isSel = _activeRightTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeRightTab = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isSel ? AppTheme.primaryColor : Colors.transparent, width: 2)),
          ),
          child: Text(
            label,
            style: TextStyle(color: isSel ? Colors.white : AppTheme.textTertiary, fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildRightContentTab() {
    if (_activeRightTab == 1) {
      return _buildChatTab();
    }
    if (_activeRightTab == 2) {
      return _buildHostRoomTab();
    }
    return _buildLeaderboardTab();
  }

  // Leaderboard tab widget
  Widget _buildLeaderboardTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _leaderboard.length,
      itemBuilder: (context, index) {
        final entry = _leaderboard[index];
        final isTop3 = index < 3;
        final medal = index == 0 ? '🥇' : index == 1 ? '🥈' : index == 2 ? '🥉' : '';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: InkWell(
            onTap: () => _navigateToUserProfile(entry['name'] as String),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    medal.isNotEmpty ? medal : '${entry['rank']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                CircleAvatar(radius: 12, backgroundImage: NetworkImage(entry['avatar'] as String)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry['name'] as String,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${entry['score']} pts',
                  style: TextStyle(color: isTop3 ? const Color(0xFFFBBF24) : Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Chat tab widget
  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) {
              final chat = _chatMessages[index];
              final isAdmin = chat['sender'] == 'Admin';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${chat['sender']}: ',
                      style: TextStyle(color: isAdmin ? AppTheme.accentColor : AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(
                        chat['msg']!,
                        style: TextStyle(color: isAdmin ? Colors.white : AppTheme.textSecondary, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.borderColor.withOpacity(0.3))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatInputCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: const InputDecoration(
                    hintText: 'Type message...',
                    hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppTheme.primaryColor, size: 16),
                onPressed: () {
                  final text = _chatInputCtrl.text.trim();
                  if (text.isEmpty) return;
                  setState(() {
                    _chatMessages.add({'sender': 'Me', 'msg': text});
                  });
                  _chatInputCtrl.clear();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Host room settings tab widget
  Widget _buildHostRoomTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📽️ Host Live Broadcast', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Community Owners can stream screens during tests for classes.',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 10),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isScreenSharing ? Colors.red.withOpacity(0.2) : AppTheme.primaryColor.withOpacity(0.2),
                    side: BorderSide(color: _isScreenSharing ? Colors.red : AppTheme.primaryColor),
                  ),
                  onPressed: () {
                    setState(() {
                      _isScreenSharing = !_isScreenSharing;
                    });
                  },
                  icon: Icon(_isScreenSharing ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded, color: _isScreenSharing ? Colors.red : AppTheme.primaryColor, size: 14),
                  label: Text(_isScreenSharing ? 'Stop Share' : 'Share Screen', style: TextStyle(color: _isScreenSharing ? Colors.red : AppTheme.primaryColor, fontSize: 11)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Pinned user rank card at bottom
  Widget _buildPinnedRankBar() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        border: Border(top: BorderSide(color: AppTheme.borderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _rankScaleAnim,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _rankAnimCtrl.value > 0 ? (1.0 + (_rankScaleAnim.value * 0.15)) : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _rankChangeText.contains('UP') ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '#$_rank',
                        style: TextStyle(color: _rankChangeColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              const Text('My Live Rank', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          Text('$_score pts', style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  // Screen share view mock
  Widget _buildScreenShareOverlay() {
    return Container(
      height: 120,
      width: double.infinity,
      color: Colors.black,
      child: const Stack(
        children: [
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.live_tv_rounded, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text('Broadcasting Live Stream...', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Bottom Stats Bar Widget
  Widget _buildBottomStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        border: Border(top: BorderSide(color: AppTheme.borderColor.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Streak', '$_streak 🔥'),
          _statItem('Correct', '$_correctCount'),
          _statItem('Earned Coins', '🪙 $_earnedCoins'),
          _statItem('Violations', '$_proctoringViolations/$_maxAllowedViolations ⚠️'),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 9)),
      ],
    );
  }

  Widget _buildBreakScreen() {
    final hasNextRound = widget.event.rounds.length > _currentRoundIndex + 1;
    final nextRound = hasNextRound ? widget.event.rounds[_currentRoundIndex + 1] : widget.event.rounds[0];

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Qualified Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text('QUALIFIED! 🎖️', style: TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Congratulations!',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'You passed the qualification cut for ${widget.event.rounds[_currentRoundIndex].name}!',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Countdown timer to next round
              const Text(
                'NEXT ROUND STARTS IN',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  '00:${_breakCountdownSeconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 40),

              // Next Round details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Next: ${nextRound.name}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Format: ${nextRound.format} • Qs: ${nextRound.totalQuestions} • Criteria: ${nextRound.qualifyingCriteria}',
                      style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardPopupOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              const Text(
                '📊 Live Rankings Standings',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Top participants leaderboard after this question',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
              ),
              const SizedBox(height: 24),
              // Leaders list
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
                ),
                child: ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  children: [
                    _leaderboardRow(1, '🥇 Rahul Verma', '120 pts', 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde'),
                    _leaderboardRow(2, '🥈 Priya Sharma', '110 pts', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330'),
                    _leaderboardRow(3, '🥉 Amit Patel', '95 pts', 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61'),
                    _leaderboardRow(4, '4. Rohan Sen', '90 pts', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d'),
                    _leaderboardRow(5, '5. Meera Nair', '80 pts', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // User's own Rank Status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('YOUR STANDING:', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('Rank #$_rank (Score: $_score pts)', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Closing in 3 seconds...', style: TextStyle(color: AppTheme.textTertiary, fontSize: 10, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leaderboardRow(int rank, String name, String score, String img) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('$rank', style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          CircleAvatar(
            radius: 12,
            backgroundImage: NetworkImage(img),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          Text(score, style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBuzzerWidget() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '🔴 BUZZER ROUND',
              style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 6),
            const Text(
              'First to press the buzzer gets to answer!',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 10),
            ),
            const SizedBox(height: 30),
            GestureDetector(
              onTap: !_isBuzzerActive
                  ? null
                  : () {
                      _buzzerCompetitorTimer?.cancel();
                      HapticFeedback.vibrate();
                      setState(() {
                        _buzzerPressed = true;
                        _whoBuzzed = 'me';
                        _isBuzzerActive = false;
                      });
                      Get.snackbar(
                        '🔔 Buzzer Pressed!',
                        'You locked the buzzer! Tap your option now.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.green.withOpacity(0.9),
                        colorText: Colors.white,
                      );
                    },
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isBuzzerActive ? Colors.red : Colors.grey.shade800,
                  boxShadow: [
                    if (_isBuzzerActive)
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                  ],
                  border: Border.all(color: Colors.white24, width: 3),
                ),
                child: const Center(
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetitorBuzzedCard() {
    return Expanded(
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_rounded, color: Colors.orange, size: 40),
              const SizedBox(height: 16),
              Text(
                '🔒 Buzzer Locked by $_whoBuzzed',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please wait for the competitor to finish speaking/answering...',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.orange)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
