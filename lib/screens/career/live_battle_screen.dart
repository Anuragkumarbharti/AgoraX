import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';

class LiveBattleScreen extends StatefulWidget {
  const LiveBattleScreen({Key? key}) : super(key: key);

  @override
  State<LiveBattleScreen> createState() => _LiveBattleScreenState();
}

class _LiveBattleScreenState extends State<LiveBattleScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _matchmakingController;
  bool _isMatchmaking = false;
  String? _selectedMode;

  final List<Map<String, dynamic>> _battleModes = [
    {
      'id': 'coding',
      'name': 'Coding Battle',
      'emoji': '💻',
      'desc': 'Solve problems faster',
      'color': const Color(0xFF6366F1),
      'players': '2.4K',
      'duration': '30 min',
    },
    {
      'id': 'math',
      'name': 'Math Battle',
      'emoji': '📐',
      'desc': 'Speed arithmetic & logic',
      'color': const Color(0xFF3B82F6),
      'players': '1.8K',
      'duration': '15 min',
    },
    {
      'id': 'reasoning',
      'name': 'Reasoning Battle',
      'emoji': '🧩',
      'desc': 'IQ & logical puzzles',
      'color': const Color(0xFF8B5CF6),
      'players': '1.2K',
      'duration': '20 min',
    },
    {
      'id': 'quiz',
      'name': 'Quiz Battle',
      'emoji': '❓',
      'desc': 'GK & current affairs',
      'color': const Color(0xFFF59E0B),
      'players': '3.1K',
      'duration': '10 min',
    },
    {
      'id': 'typing',
      'name': 'Typing Battle',
      'emoji': '⌨️',
      'desc': 'WPM speed competition',
      'color': const Color(0xFF10B981),
      'players': '950',
      'duration': '5 min',
    },
    {
      'id': 'design',
      'name': 'Design Battle',
      'emoji': '🎨',
      'desc': 'UI/logo challenge',
      'color': const Color(0xFFEC4899),
      'players': '430',
      'duration': '45 min',
    },
    {
      'id': 'debate',
      'name': 'Debate Battle',
      'emoji': '🗣️',
      'desc': 'Timed argument sessions',
      'color': const Color(0xFFF97316),
      'players': '280',
      'duration': '20 min',
    },
    {
      'id': 'chess',
      'name': 'Chess Battle',
      'emoji': '♟️',
      'desc': 'Classic chess match',
      'color': const Color(0xFF64748B),
      'players': '670',
      'duration': '15 min',
    },
  ];

  final List<Map<String, dynamic>> _recentBattles = [
    {
      'mode': 'Coding',
      'opponent': 'ArjunS',
      'result': 'Won',
      'score': '3/3',
      'xp': '+120',
      'time': '2h ago',
    },
    {
      'mode': 'Math',
      'opponent': 'PriyaK',
      'result': 'Lost',
      'score': '2/3',
      'xp': '+30',
      'time': '5h ago',
    },
    {
      'mode': 'Quiz',
      'opponent': 'RahulM',
      'result': 'Won',
      'score': '8/10',
      'xp': '+85',
      'time': 'Yesterday',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _matchmakingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _matchmakingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverHeader(),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildBattleStats(),
                    const SizedBox(height: 20),
                    _buildModeSection(),
                    const SizedBox(height: 20),
                    _buildRecentBattles(),
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          ),
          if (_isMatchmaking) _buildMatchmakingOverlay(),
        ],
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 160,
      backgroundColor: AppTheme.bgDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFEF4444),
                Color(0xFFF97316),
                Color(0xFF0F172A),
              ],
              stops: [0, 0.5, 1],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    '⚔️ Live Battle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (ctx, _) => Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(
                                0.6 + 0.4 * _pulseController.value),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '11,240 players online • AI Judge Active',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBattleStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFEF4444).withOpacity(0.12),
            const Color(0xFFF97316).withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFEF4444).withOpacity(0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _battleStat('38', 'Battles', '⚔️'),
          _battleStat('24', 'Wins', '🏆'),
          _battleStat('14', 'Losses', '💀'),
          _battleStat('63%', 'Win Rate', '📊'),
          _battleStat('#142', 'Rank', '🎖️'),
        ],
      ),
    );
  }

  Widget _battleStat(String value, String label, String emoji) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textTertiary, fontSize: 10)),
      ],
    );
  }

  Widget _buildModeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Battle Mode',
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
          childAspectRatio: 1.6,
          children: _battleModes
              .map((mode) => _buildModeCard(mode))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildModeCard(Map<String, dynamic> mode) {
    final isSelected = _selectedMode == mode['id'];
    final color = mode['color'] as Color;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedMode = mode['id'] as String);
        _startMatchmaking(mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? color : AppTheme.borderColor.withOpacity(0.4),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 8)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(mode['emoji'] as String,
                    style: const TextStyle(fontSize: 22)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${mode['players']}',
                    style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              mode['name'] as String,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '⏱ ${mode['duration']}',
              style: const TextStyle(
                  color: AppTheme.textTertiary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentBattles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Battles',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ..._recentBattles.map((b) => _buildBattleRow(b)),
      ],
    );
  }

  Widget _buildBattleRow(Map<String, dynamic> battle) {
    final isWin = battle['result'] == 'Won';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isWin
              ? AppTheme.accentColor.withOpacity(0.25)
              : AppTheme.borderColor.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isWin
                  ? AppTheme.accentColor.withOpacity(0.12)
                  : AppTheme.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(isWin ? '🏆' : '💀',
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${battle['mode']} vs ${battle['opponent']}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Score: ${battle['score']} • ${battle['time']}',
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isWin
                      ? AppTheme.accentColor.withOpacity(0.15)
                      : AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  battle['result'] as String,
                  style: TextStyle(
                    color: isWin
                        ? AppTheme.accentColor
                        : AppTheme.errorColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                battle['xp'] as String,
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchmakingOverlay() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Spinning battle icon
              AnimatedBuilder(
                animation: _matchmakingController,
                builder: (ctx, _) => Transform.rotate(
                  angle: _matchmakingController.value * 2 * math.pi,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [
                          Color(0xFFEF4444),
                          Color(0xFFF97316),
                          Color(0xFFFBBF24),
                          Color(0xFFEF4444),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 0),
              Container(
                width: 90,
                height: 90,
                margin: const EdgeInsets.only(top: -95),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('⚔️', style: TextStyle(fontSize: 42)),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Finding Opponent...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Matching you with a player of similar skill',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 13),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFEF4444)),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  _matchmakingController.stop();
                  setState(() {
                    _isMatchmaking = false;
                    _selectedMode = null;
                  });
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startMatchmaking(Map<String, dynamic> mode) {
    setState(() => _isMatchmaking = true);
    _matchmakingController.repeat();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _matchmakingController.stop();
        setState(() => _isMatchmaking = false);
        Get.snackbar(
          '⚔️ Match Found!',
          'Opponent: RahulK (Rank #138) — ${mode['name']} starting!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: (mode['color'] as Color).withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    });
  }
}
