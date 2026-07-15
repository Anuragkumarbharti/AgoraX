import 'package:creania/core/theme.dart';
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
          insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.secondaryBackgroundColor,
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
                      style: TextStyle(fontSize: 48),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                
                // Gradient Title
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: tier.gradientColors,
                  ).createShader(bounds),
                  child: Text(
                    'LEVEL UP!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                
                // Explorer / Learner / Scholar Rank Title display
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                SizedBox(height: 24),

                // Level Change Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _levelBadge(widget.oldLevel, Colors.white30),
                    SizedBox(width: 14),
                    Icon(Icons.arrow_forward_rounded, color: context.caption, size: 24),
                    SizedBox(width: 14),
                    _levelBadge(widget.newLevel, tier.color),
                  ],
                ),
                SizedBox(height: 28),

                // Rewards breakdown
                Text(
                  'YOUR REWARDS',
                  style: TextStyle(
                    color: context.caption,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 12),
                
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Column(
                    children: [
                      // Silver Coins Earned Row
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFFFBBF24).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Text('🪙', style: TextStyle(fontSize: 16)),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Silver Coins', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                Text('Level milestone reward', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                              ],
                            ),
                          ),
                          Text(
                            '+${widget.coinsEarned}',
                            style: TextStyle(color: Color(0xFFFBBF24), fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      
                      if (widget.unlockedItems.isNotEmpty) ...[
                        SizedBox(height: 12),
                        Divider(color: context.borderColor),
                        SizedBox(height: 8),
                        
                        // Custom items unlocked
                        ...widget.unlockedItems.map((item) => Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(Icons.stars_rounded, color: tier.color, size: 16),
                              SizedBox(width: 10),
                              Text(
                                item,
                                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )).toList(),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 32),

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
                    child: Text(
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
          color: color == Colors.white30 ? context.textSecondary : color,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
