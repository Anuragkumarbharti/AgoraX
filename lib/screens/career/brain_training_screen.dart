import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:creania/core/theme.dart';

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
      'color': Color(0xFF6366F1),
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
      'color': Color(0xFFF59E0B),
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
      'color': Color(0xFF10B981),
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
      'color': Color(0xFF8B5CF6),
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
      'color': Color(0xFFEC4899),
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
      'color': Color(0xFFF97316),
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
      'color': Color(0xFF3B82F6),
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
      'color': Color(0xFF14B8A6),
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
      backgroundColor: context.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildHeader(),
          SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildBrainScore(),
                SizedBox(height: 20),
                _buildDailyProgress(),
                SizedBox(height: 20),
                _buildGamesGrid(),
                SizedBox(height: 80),
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
      backgroundColor: context.scaffoldBackgroundColor,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      title: Text(
        'Brain Training',
        style: TextStyle(
            color: context.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700),
      ),
      actions: [
        Container(
          margin: EdgeInsets.only(right: 16, top: 8, bottom: 8),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Color(0xFFF97316).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Color(0xFFF97316).withOpacity(0.35)),
          ),
          child: Text(
            '🔥 $_streakDays days',
            style: TextStyle(
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
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Color(0xFF6366F1)
                  .withOpacity(0.15 + 0.05 * _breatheController.value),
              context.secondaryBackgroundColor.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Color(0xFF6366F1).withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF6366F1)
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
                Text(
                  'Brain Score',
                  style: TextStyle(
                    color: context.caption,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '$_brainScore',
                  style: TextStyle(
                    color: Color(0xFF6366F1),
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                Text(
                  '/ 100',
                  style: TextStyle(
                      color: context.caption, fontSize: 13),
                ),
              ],
            ),
            SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _scoreDimension('Memory', 84, Color(0xFF6366F1)),
                  SizedBox(height: 8),
                  _scoreDimension(
                      'Processing', 76, Color(0xFF10B981)),
                  SizedBox(height: 8),
                  _scoreDimension('Speed', 68, Color(0xFFF97316)),
                  SizedBox(height: 8),
                  _scoreDimension('Logic', 80, Color(0xFFF59E0B)),
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
              style: TextStyle(
                  color: context.caption, fontSize: 10)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 5,
              backgroundColor: context.borderColor,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        SizedBox(width: 6),
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Games",
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$_completedCount/${_games.length} done',
                style: TextStyle(
                    color: context.primaryColor, fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _completedCount / _games.length,
              minHeight: 10,
              backgroundColor: context.borderColor,
              valueColor: AlwaysStoppedAnimation(context.primaryColor),
            ),
          ),
          SizedBox(height: 6),
          Text(
            '🏆 Complete all 8 games to earn 500 Brain XP today!',
            style: TextStyle(color: context.caption, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildGamesGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Games',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 12),
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
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDone ? color.withOpacity(0.1) : context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone
                ? color.withOpacity(0.35)
                : context.borderColor.withOpacity(0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(game['emoji'] as String,
                    style: TextStyle(fontSize: 26)),
                if (isDone)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: context.accentOrange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check,
                        color: Colors.white, size: 14),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              game['name'] as String,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2),
            Text(
              '⏱ ${game['duration']}',
              style: TextStyle(
                  color: context.caption, fontSize: 10),
            ),
            SizedBox(height: 4),
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
                style: TextStyle(
                    color: context.caption, fontSize: 10),
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
        backgroundColor: context.secondaryBackgroundColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(game['emoji'] as String,
                  style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text(game['name'] as String,
                  style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text(game['desc'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: context.caption, fontSize: 13)),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _dialogChip('⏱ ${game['duration']}', color),
                  SizedBox(width: 8),
                  _dialogChip('🏆 Best: ${game['bestScore']}', color),
                ],
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: EdgeInsets.symmetric(vertical: 14),
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
                    style: TextStyle(
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
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
