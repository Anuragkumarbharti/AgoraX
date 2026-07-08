import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';

class HiringScoreScreen extends StatefulWidget {
  const HiringScoreScreen({Key? key}) : super(key: key);

  @override
  State<HiringScoreScreen> createState() => _HiringScoreScreenState();
}

class _HiringScoreScreenState extends State<HiringScoreScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scoreController;
  bool _isPublic = true;

  final int _totalScore = 74;

  final List<Map<String, dynamic>> _factors = [
    {
      'label': 'Problems Solved',
      'icon': '💡',
      'value': 82,
      'detail': '482 problems • 340 AC',
      'color': const Color(0xFF6366F1),
      'weight': 20,
    },
    {
      'label': 'Contest Rank',
      'icon': '🏆',
      'value': 68,
      'detail': 'Best rank: #142 (LeetCode Weekly)',
      'color': const Color(0xFFF59E0B),
      'weight': 15,
    },
    {
      'label': 'Projects',
      'icon': '🏗️',
      'value': 70,
      'detail': '3 projects • 2 deployed',
      'color': const Color(0xFF10B981),
      'weight': 18,
    },
    {
      'label': 'Portfolio',
      'icon': '📁',
      'value': 65,
      'detail': 'GitHub: 48 repos • 230 contributions',
      'color': const Color(0xFF8B5CF6),
      'weight': 12,
    },
    {
      'label': 'Consistency',
      'icon': '🔥',
      'value': 88,
      'detail': '28-day streak • 4.2 avg/week',
      'color': const Color(0xFFF97316),
      'weight': 15,
    },
    {
      'label': 'Communication',
      'icon': '🗣️',
      'value': 72,
      'detail': 'Community posts: 48 • Rating: 4.2',
      'color': const Color(0xFF3B82F6),
      'weight': 8,
    },
    {
      'label': 'Leadership',
      'icon': '👑',
      'value': 55,
      'detail': 'Community admin: 1 • Mentored: 3',
      'color': const Color(0xFFFBBF24),
      'weight': 7,
    },
    {
      'label': 'AI Review',
      'icon': '🤖',
      'value': 78,
      'detail': 'Code quality: 82 • Readability: 74',
      'color': const Color(0xFFEC4899),
      'weight': 5,
    },
  ];

  final List<Map<String, dynamic>> _tips = [
    {
      'icon': '🏗️',
      'tip': 'Add 2 more deployed projects (+8 points)',
      'impact': 'HIGH',
    },
    {
      'icon': '🏆',
      'tip': 'Participate in 3 more contests (+5 points)',
      'impact': 'MEDIUM',
    },
    {
      'icon': '👑',
      'tip': 'Mentor 5 more users to improve leadership',
      'impact': 'MEDIUM',
    },
    {
      'icon': '📁',
      'tip': 'Add README to all GitHub repos',
      'impact': 'LOW',
    },
  ];

  @override
  void initState() {
    super.initState();
    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

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
          'Hiring Score',
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700),
        ),
        actions: [
          Row(
            children: [
              const Text('Public',
                  style: TextStyle(
                      color: AppTheme.textTertiary, fontSize: 12)),
              Switch(
                value: _isPublic,
                activeColor: AppTheme.primaryColor,
                onChanged: (v) => setState(() => _isPublic = v),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildScoreGauge(),
          const SizedBox(height: 20),
          _buildVisibilityBanner(),
          const SizedBox(height: 20),
          _buildFactorsSection(),
          const SizedBox(height: 20),
          _buildTipsSection(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildScoreGauge() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _scoreColor().withOpacity(0.15),
            AppTheme.bgLight.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _scoreColor().withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'Your Hiring Score',
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          // Gauge
          AnimatedBuilder(
            animation: _scoreController,
            builder: (ctx, _) {
              final animatedScore =
                  (_totalScore * _scoreController.value).toInt();
              return SizedBox(
                width: 180,
                height: 100,
                child: CustomPaint(
                  painter: _GaugePainter(
                    score: animatedScore,
                    color: _scoreColor(),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 30),
                        Text(
                          '$animatedScore',
                          style: TextStyle(
                            color: _scoreColor(),
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          _scoreLabel(),
                          style: TextStyle(
                            color: _scoreColor(),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            '📈 Top ${100 - _totalScore}% better than this week',
            style: const TextStyle(
                color: AppTheme.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _scoreColor() {
    if (_totalScore >= 85) return const Color(0xFF10B981);
    if (_totalScore >= 65) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _scoreLabel() {
    if (_totalScore >= 85) return '🌟 Excellent';
    if (_totalScore >= 65) return '✅ Good';
    if (_totalScore >= 45) return '⚡ Average';
    return '🔴 Needs Work';
  }

  Widget _buildVisibilityBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (_isPublic
            ? AppTheme.accentColor
            : AppTheme.textTertiary)
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (_isPublic
              ? AppTheme.accentColor
              : AppTheme.textTertiary)
              .withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isPublic
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            color: _isPublic
                ? AppTheme.accentColor
                : AppTheme.textTertiary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isPublic
                  ? '👀 Companies can see your hiring score'
                  : '🔒 Your score is hidden from companies',
              style: TextStyle(
                color: _isPublic
                    ? AppTheme.accentColor
                    : AppTheme.textTertiary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Score Breakdown',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ..._factors.map((f) => _buildFactorRow(f)),
      ],
    );
  }

  Widget _buildFactorRow(Map<String, dynamic> factor) {
    final color = factor['color'] as Color;
    final value = factor['value'] as int;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(factor['icon'] as String,
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(factor['label'] as String,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    Text(factor['detail'] as String,
                        style: const TextStyle(
                            color: AppTheme.textTertiary, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$value/100',
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Weight: ${factor['weight']}%',
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AnimatedBuilder(
              animation: _scoreController,
              builder: (ctx, _) => LinearProgressIndicator(
                value: (value / 100) * _scoreController.value,
                minHeight: 6,
                backgroundColor: AppTheme.borderColor,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🚀 Improve Your Score',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ..._tips.map((tip) {
          final impactColor = tip['impact'] == 'HIGH'
              ? const Color(0xFFEF4444)
              : tip['impact'] == 'MEDIUM'
                  ? const Color(0xFFF59E0B)
                  : AppTheme.textTertiary;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: impactColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: impactColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Text(tip['icon'] as String,
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(tip['tip'] as String,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: impactColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(tip['impact'] as String,
                      style: TextStyle(
                          color: impactColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.score, required this.color});
  final int score;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.85;
    final r = size.width / 2 - 8;
    const startAngle = 3.14159;
    final sweepAngle = 3.14159 * score / 100;

    // Background arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle,
      3.14159,
      false,
      Paint()
        ..color = Colors.white.withOpacity(0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );

    // Score arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.score != score;
}
