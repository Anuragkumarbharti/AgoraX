import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../models/daily_learning_model.dart';
import '../../services/study_category_controller.dart';
import 'quiz_result_screen.dart';

class MCQQuizScreen extends StatefulWidget {
  final DailyLearningDay dailyDay;

  const MCQQuizScreen({
    Key? key,
    required this.dailyDay,
  }) : super(key: key);

  @override
  State<MCQQuizScreen> createState() => _MCQQuizScreenState();
}

class _MCQQuizScreenState extends State<MCQQuizScreen> with WidgetsBindingObserver {
  final StudyCategoryController _controller = Get.find<StudyCategoryController>();
  
  int _currentQuestionIndex = 0;
  int? _selectedOptionIndex;
  
  // Timer settings
  static const int _questionDuration = 25; // 20-30 seconds timer
  int _timerSecondsRemaining = _questionDuration;
  Timer? _questionTimer;
  
  // User answers tracking
  final Map<int, int?> _userAnswers = {}; // map of question index -> selected option index
  bool _quizSubmitted = false;
  bool _cheated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _questionTimer?.cancel();
    super.dispose();
  }

  // Quiz Security: Listen to app lifecycle.
  // If app goes to background (paused/inactive), auto-fail/submit the quiz.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!_quizSubmitted) {
        _handleCheatingDetected();
      }
    }
  }

  void _handleCheatingDetected() {
    _questionTimer?.cancel();
    setState(() {
      _cheated = true;
      _quizSubmitted = true;
    });
    
    Get.snackbar(
      '🚨 Quiz Voided',
      'Minimizing or leaving the app during a live quiz is forbidden. The quiz has been auto-submitted with a score of 0.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.errorColor.withOpacity(0.95),
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );

    // Auto submit to controller with 0 correct answers, 5 wrong
    _controller.submitQuiz(0, 5);

    // Redirect to results screen showing 0 score with cheated flag
    Get.off(
      () => QuizResultScreen(
        dailyDay: widget.dailyDay,
        userAnswers: const {},
        cheated: true,
      ),
    );
  }

  void _startTimer() {
    _questionTimer?.cancel();
    setState(() {
      _timerSecondsRemaining = _questionDuration;
      _selectedOptionIndex = null;
    });

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timerSecondsRemaining > 1) {
          _timerSecondsRemaining--;
        } else {
          // Timer expired - move to next question automatically
          _nextQuestion(isTimeout: true);
        }
      });
    });
  }

  void _nextQuestion({bool isTimeout = false}) {
    _questionTimer?.cancel();
    
    // Save current answer
    _userAnswers[_currentQuestionIndex] = _selectedOptionIndex;
    
    if (_currentQuestionIndex < widget.dailyDay.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
      _startTimer();
    } else {
      // Last question completed - submit quiz
      _submitQuiz();
    }
  }

  void _submitQuiz() {
    if (_quizSubmitted) return;
    _questionTimer?.cancel();
    setState(() {
      _quizSubmitted = true;
    });

    // Score evaluation
    int correctCount = 0;
    int wrongCount = 0;

    for (int i = 0; i < widget.dailyDay.questions.length; i++) {
      final selected = _userAnswers[i];
      final correct = widget.dailyDay.questions[i].correctAnswerIndex;
      if (selected == correct) {
        correctCount++;
      } else {
        wrongCount++;
      }
    }

    // Secure submission to local server/state controller
    _controller.submitQuiz(correctCount, wrongCount);

    // Navigate to results screen
    Get.off(
      () => QuizResultScreen(
        dailyDay: widget.dailyDay,
        userAnswers: _userAnswers,
        cheated: false,
      ),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.dailyDay.questions[_currentQuestionIndex];
    final totalQuestions = widget.dailyDay.questions.length;
    final progress = _timerSecondsRemaining / _questionDuration;

    return PopScope(
      canPop: false, // Security: Disable back button
      onPopInvoked: (didPop) {
        if (didPop) return;
        Get.snackbar(
          '🔒 Navigation Disabled',
          'You cannot return or exit until you finish the quiz. Back button is locked.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.errorColor.withOpacity(0.9),
          colorText: Colors.white,
        );
      },
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quiz Header info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAILY LEARNING QUIZ',
                          style: TextStyle(
                            color: AppTheme.primaryColor.withOpacity(0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          'Question ${_currentQuestionIndex + 1} of $totalQuestions',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    // Ticking timer clock
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _timerSecondsRemaining <= 5 
                            ? AppTheme.errorColor.withOpacity(0.12)
                            : AppTheme.primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _timerSecondsRemaining <= 5 
                              ? AppTheme.errorColor.withOpacity(0.4)
                              : AppTheme.primaryColor.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: _timerSecondsRemaining <= 5 ? AppTheme.errorColor : AppTheme.primaryColor,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_timerSecondsRemaining}s',
                            style: TextStyle(
                              color: _timerSecondsRemaining <= 5 ? AppTheme.errorColor : AppTheme.primaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Linear Timer Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _timerSecondsRemaining <= 5 ? AppTheme.errorColor : AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Question Display Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    question.questionText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 4 MCQ Options List
                Expanded(
                  child: ListView.builder(
                    itemCount: question.options.length,
                    itemBuilder: (ctx, index) {
                      final optionText = question.options[index];
                      final isSelected = _selectedOptionIndex == index;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedOptionIndex = index;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? AppTheme.primaryColor.withOpacity(0.12)
                                : AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected 
                                  ? AppTheme.primaryColor
                                  : AppTheme.borderColor.withOpacity(0.5),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Circular index tag (A, B, C, D)
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.primaryColor : Colors.white10,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    String.fromCharCode(65 + index), // A, B, C, D
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  optionText,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),
                
                // Bottom Actions: Next Question / Submit
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedOptionIndex != null ? AppTheme.primaryColor : AppTheme.cardBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: _selectedOptionIndex != null ? () => _nextQuestion() : null,
                    child: Text(
                      _currentQuestionIndex == totalQuestions - 1 ? 'Submit Quiz  ✓' : 'Next Question  →',
                      style: TextStyle(
                        color: _selectedOptionIndex != null ? Colors.white : AppTheme.textTertiary,
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
      ),
    );
  }
}
