import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';

class BrainTrainingScreen extends StatefulWidget {
  const BrainTrainingScreen({Key? key}) : super(key: key);

  @override
  State<BrainTrainingScreen> createState() => _BrainTrainingScreenState();
}

class _BrainTrainingScreenState extends State<BrainTrainingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _breatheController;

  final List<Map<String, dynamic>> _games = [
    {
      'id': 'memory',
      'name': 'Memory Game',
      'emoji': '🧠',
      'desc': 'Remember and match patterns',
      'duration': '60s',
      'score': 840,
      'bestScore': 1200,
      'done': true,
      'color': const Color(0xFF6366F1),
      'category': 'Memory',
    },
    {
      'id': 'iq',
      'name': 'IQ Test',
      'emoji': '💡',
      'desc': 'Logical pattern questions',
      'duration': '3 min',
      'score': 0,
      'bestScore': 118,
      'done': false,
      'color': const Color(0xFFF59E0B),
      'category': 'Intelligence',
    },
    {
      'id': 'mental_math',
      'name': 'Mental Math',
      'emoji': '🔢',
      'desc': 'Rapid arithmetic challenges',
      'duration': '60s',
      'score': 920,
      'bestScore': 1050,
      'done': true,
      'color': const Color(0xFF10B981),
      'category': 'Math',
    },
    {
      'id': 'visual_puzzle',
      'name': 'Visual Puzzle',
      'emoji': '🔷',
      'desc': 'Spatial reasoning tasks',
      'duration': '90s',
      'score': 0,
      'bestScore': 780,
      'done': false,
      'color': const Color(0xFF8B5CF6),
      'category': 'Spatial',
    },
    {
      'id': 'pattern',
      'name': 'Pattern Recognition',
      'emoji': '🌀',
      'desc': 'Identify sequence patterns',
      'duration': '60s',
      'score': 0,
      'bestScore': 960,
      'done': false,
      'color': const Color(0xFFEC4899),
      'category': 'Cognition',
    },
    {
      'id': 'reaction',
      'name': 'Reaction Test',
      'emoji': '⚡',
      'desc': 'Test your reaction speed',
      'duration': '30s',
      'score': 0,
      'bestScore': 240,
      'done': false,
      'color': const Color(0xFFF97316),
      'category': 'Speed',
    },
    {
      'id': 'typing',
      'name': 'Typing Test',
      'emoji': '⌨️',
      'desc': 'Words per minute challenge',
      'duration': '60s',
      'score': 0,
      'bestScore': 68,
      'done': false,
      'color': const Color(0xFF3B82F6),
      'category': 'Speed',
    },
    {
      'id': 'decision',
      'name': 'Decision Making',
      'emoji': '🎯',
      'desc': 'Quick logical choices',
      'duration': '90s',
      'score': 0,
      'bestScore': 820,
      'done': false,
      'color': const Color(0xFF14B8A6),
      'category': 'Cognition',
    },
  ];

  final int _brainScore = 72;
  final int _streakDays = 12;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  int get _completedCount =>
      _games.where((g) => g['done'] as bool).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: CustomScrollView(
        slivers: [
          _buildHeader(),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildBrainScore(),
                const SizedBox(height: 20),
                _buildDailyProgress(),
                const SizedBox(height: 20),
                _buildGamesGrid(),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppTheme.bgDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      title: const Text(
        'Brain Training',
        style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF97316).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFFF97316).withOpacity(0.35)),
          ),
          child: Text(
            '🔥 $_streakDays days',
            style: const TextStyle(
              color: Color(0xFFF97316),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrainScore() {
    return AnimatedBuilder(
      animation: _breatheController,
      builder: (ctx, _) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              const Color(0xFF6366F1)
                  .withOpacity(0.15 + 0.05 * _breatheController.value),
              AppTheme.bgLight.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF6366F1).withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1)
                  .withOpacity(0.05 + 0.08 * _breatheController.value),
              blurRadius: 20,
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Brain Score',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_brainScore',
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const Text(
                  '/ 100',
                  style: TextStyle(
                      color: AppTheme.textTertiary, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _scoreDimension('Memory', 84, const Color(0xFF6366F1)),
                  const SizedBox(height: 8),
                  _scoreDimension(
                      'Processing', 76, const Color(0xFF10B981)),
                  const SizedBox(height: 8),
                  _scoreDimension('Speed', 68, const Color(0xFFF97316)),
                  const SizedBox(height: 8),
                  _scoreDimension('Logic', 80, const Color(0xFFF59E0B)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreDimension(String label, int value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label,
              style: const TextStyle(
                  color: AppTheme.textTertiary, fontSize: 10)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 5,
              backgroundColor: AppTheme.borderColor,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('$value',
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildDailyProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Games",
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$_completedCount/${_games.length} done',
                style: const TextStyle(
                    color: AppTheme.primaryColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _completedCount / _games.length,
              minHeight: 10,
              backgroundColor: AppTheme.borderColor,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '🏆 Complete all 8 games to earn 500 Brain XP today!',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildGamesGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily Games',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.0,
          children: _games.map((g) => _buildGameCard(g)).toList(),
        ),
      ],
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game) {
    final isDone = game['done'] as bool;
    final color = game['color'] as Color;
    return GestureDetector(
      onTap: () => _startGame(game),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDone ? color.withOpacity(0.1) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone
                ? color.withOpacity(0.35)
                : AppTheme.borderColor.withOpacity(0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(game['emoji'] as String,
                    style: const TextStyle(fontSize: 26)),
                if (isDone)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 14),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              game['name'] as String,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '⏱ ${game['duration']}',
              style: const TextStyle(
                  color: AppTheme.textTertiary, fontSize: 10),
            ),
            const SizedBox(height: 4),
            if (isDone)
              Text(
                '🏆 ${game['score']}',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Text(
                'Best: ${game['bestScore']}',
                style: const TextStyle(
                    color: AppTheme.textTertiary, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  void _startGame(Map<String, dynamic> game) {
    final color = game['color'] as Color;
    final isDone = game['done'] as bool;
    Get.dialog(
      Dialog(
        backgroundColor: AppTheme.bgLight,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(game['emoji'] as String,
                  style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(game['name'] as String,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(game['desc'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _dialogChip('⏱ ${game['duration']}', color),
                  const SizedBox(width: 8),
                  _dialogChip('🏆 Best: ${game['bestScore']}', color),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Get.back();
                    if (!isDone) {
                      setState(() {
                        game['done'] = true;
                        game['score'] =
                            (game['bestScore'] as int) - 50 +
                                (50 * 0.8).toInt();
                      });
                    }
                    Get.snackbar(
                      '🧠 Game Complete!',
                      '${game['name']}: Score ${game['score']} • +50 Brain XP',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: color.withOpacity(0.9),
                      colorText: Colors.white,
                    );
                  },
                  child: Text(
                    isDone ? '▶️ Play Again' : '▶️ Start Game',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
