import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/theme.dart';
import '../services/study_category_controller.dart';

class LevelUpDialog extends StatefulWidget {
  final int oldLevel;
  final int newLevel;
  final int coinsEarned;
  final List<String> unlockedItems;

  const LevelUpDialog({
    Key? key,
    required this.oldLevel,
    required this.newLevel,
    required this.coinsEarned,
    required this.unlockedItems,
  }) : super(key: key);

  @override
  State<LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<LevelUpDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut),
    );
    _rotateAnim = Tween<double>(begin: -0.2, end: 0.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = StudyCategoryController.getTierForLevel(widget.newLevel);

    return ScaleTransition(
      scale: _scaleAnim,
      child: RotationTransition(
        turns: _rotateAnim,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: tier.color.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: tier.color.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Sparkly Header
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow background
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: tier.color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                    ),
                    // Emojis/Icons
                    Text(
                      tier.icon,
                      style: const TextStyle(fontSize: 48),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Gradient Title
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: tier.gradientColors,
                  ).createShader(bounds),
                  child: const Text(
                    'LEVEL UP!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Explorer / Learner / Scholar Rank Title display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: tier.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tier.color.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${tier.name} Rank Unlocked',
                    style: TextStyle(
                      color: tier.color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Level Change Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _levelBadge(widget.oldLevel, Colors.white30),
                    const SizedBox(width: 14),
                    const Icon(Icons.arrow_forward_rounded, color: AppTheme.textTertiary, size: 24),
                    const SizedBox(width: 14),
                    _levelBadge(widget.newLevel, tier.color),
                  ],
                ),
                const SizedBox(height: 28),

                // Rewards breakdown
                const Text(
                  'YOUR REWARDS',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    children: [
                      // Silver Coins Earned Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Text('🪙', style: TextStyle(fontSize: 16)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Silver Coins', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                Text('Level milestone reward', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                              ],
                            ),
                          ),
                          Text(
                            '+${widget.coinsEarned}',
                            style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      
                      if (widget.unlockedItems.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(color: AppTheme.borderColor),
                        const SizedBox(height: 8),
                        
                        // Custom items unlocked
                        ...widget.unlockedItems.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(Icons.stars_rounded, color: tier.color, size: 16),
                              const SizedBox(width: 10),
                              Text(
                                item,
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )).toList(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Action Dismiss Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tier.color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 5,
                      shadowColor: tier.color.withOpacity(0.3),
                    ),
                    onPressed: () => Get.back(),
                    child: const Text(
                      'Awesome!',
                      style: TextStyle(
                        color: Colors.white,
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

  Widget _levelBadge(int level, Color color) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        'Lvl $level',
        style: TextStyle(
          color: color == Colors.white30 ? AppTheme.textSecondary : color,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
