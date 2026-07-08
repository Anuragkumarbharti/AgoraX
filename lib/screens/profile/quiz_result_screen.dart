import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../models/daily_learning_model.dart';
import '../../services/study_category_controller.dart';

class QuizResultScreen extends StatelessWidget {
  final DailyLearningDay dailyDay;
  final Map<int, int?> userAnswers;
  final bool cheated;

  const QuizResultScreen({
    Key? key,
    required this.dailyDay,
    required this.userAnswers,
    this.cheated = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final StudyCategoryController controller = Get.find<StudyCategoryController>();
    
    // Evaluate scores
    int correctCount = 0;
    int wrongCount = 0;

    if (!cheated) {
      for (int i = 0; i < dailyDay.questions.length; i++) {
        final selected = userAnswers[i];
        final correct = dailyDay.questions[i].correctAnswerIndex;
        if (selected == correct) {
          correctCount++;
        } else {
          wrongCount++;
        }
      }
    } else {
      wrongCount = dailyDay.questions.length;
    }

    final accuracy = dailyDay.questions.isNotEmpty 
        ? (correctCount / dailyDay.questions.length * 100).toInt()
        : 0;

    final earnedXp = cheated ? 0 : (correctCount * 10) + (correctCount == 5 ? 20 : 0);
    final earnedCoins = cheated ? 0 : (correctCount * 5) + (correctCount == 5 ? 25 : 0);
    final isPerfect = correctCount == 5;

    return PopScope(
      canPop: false, // Prevent physical back button pop out
      onPopInvoked: (didPop) {
        if (didPop) return;
        Get.back(); // custom back
      },
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                
                // Result Banner (Alert/Perfect/Scorecard)
                if (cheated)
                  _buildCheatedBanner()
                else if (isPerfect)
                  _buildPerfectBanner()
                else
                  _buildScoreBanner(correctCount, dailyDay.questions.length),
                
                const SizedBox(height: 24),
                
                // Stats Row Grid
                Row(
                  children: [
                    _buildStatCard('Accuracy', '$accuracy%', AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    _buildStatCard('XP Gained', '⚡ +$earnedXp', const Color(0xFF6366F1)),
                    const SizedBox(width: 12),
                    _buildStatCard('Coins Gained', '🪙 +$earnedCoins', const Color(0xFFFBBF24)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatCard('Streak', '🔥 ${controller.learningStreak} Days', const Color(0xFFF97316)),
                    const SizedBox(width: 12),
                    _buildStatCard('Your Level', '⭐ Level ${controller.userLevel}', const Color(0xFFA78BFA)),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Detailed QA review
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Questions Review & Explanation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                ...dailyDay.questions.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final q = entry.value;
                  final selectedOpt = cheated ? null : userAnswers[idx];
                  final isCorrect = selectedOpt == q.correctAnswerIndex;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cheated 
                            ? AppTheme.errorColor.withOpacity(0.3)
                            : isCorrect 
                                ? AppTheme.accentColor.withOpacity(0.3)
                                : AppTheme.errorColor.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question Header
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: cheated
                                    ? AppTheme.errorColor.withOpacity(0.12)
                                    : isCorrect 
                                        ? AppTheme.accentColor.withOpacity(0.12)
                                        : AppTheme.errorColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Q${idx + 1}',
                                style: TextStyle(
                                  color: cheated 
                                      ? AppTheme.errorColor
                                      : isCorrect 
                                          ? AppTheme.accentColor
                                          : AppTheme.errorColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                q.questionText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Options Review
                        ...q.options.asMap().entries.map((optEntry) {
                          final optIdx = optEntry.key;
                          final optText = optEntry.value;
                          final isThisSelected = selectedOpt == optIdx;
                          final isThisCorrect = q.correctAnswerIndex == optIdx;
                          
                          Color optColor = Colors.white70;
                          IconData? icon;
                          BoxDecoration boxDec = BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white10),
                          );

                          if (isThisCorrect) {
                            optColor = AppTheme.accentColor;
                            icon = Icons.check_circle_outline;
                            boxDec = BoxDecoration(
                              color: AppTheme.accentColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
                            );
                          } else if (isThisSelected) {
                            optColor = AppTheme.errorColor;
                            icon = Icons.cancel_outlined;
                            boxDec = BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                            );
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: boxDec,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    optText,
                                    style: TextStyle(
                                      color: optColor,
                                      fontSize: 12,
                                      fontWeight: (isThisSelected || isThisCorrect) ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (icon != null) Icon(icon, color: optColor, size: 16),
                              ],
                            ),
                          );
                        }).toList(),
                        
                        const SizedBox(height: 12),
                        
                        // Explanation Box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.borderColor.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Explanation:',
                                style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                q.explanation,
                                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),

                const SizedBox(height: 24),
                
                // Done Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Get.back(),
                    child: const Text(
                      'Back to Daily Tasks',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
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

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildCheatedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.4)),
      ),
      child: const Column(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 48),
          SizedBox(height: 12),
          Text(
            'Quiz Voided',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'Backgrounding the app is not allowed. Zero rewards granted.',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPerfectBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFBBF24).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 12),
          const Text(
            'PERFECT LEARNER!',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Score: 5 / 5 Correct Answers',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🏆 Perfect Learner Badge Unlocked', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBanner(int score, int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.stars_rounded, color: AppTheme.primaryColor, size: 44),
          const SizedBox(height: 10),
          const Text('Quiz Completed!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'You answered $score out of $total questions correctly.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
