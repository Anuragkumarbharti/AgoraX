import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'novel_badge_widget.dart';

class EntryParticlePainter extends CustomPainter {
  final double progress;
  final Color color;

  EntryParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.55)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 12; i++) {
      final double localProgress = (progress + (i * 0.12)) % 1.0;
      final double x = size.width * localProgress;
      // Beautiful wavy magic portal particles trail
      final double y = (size.height / 2) + 16 * math.sin(localProgress * 4 * math.pi + i);
      final double radius = 1.0 + 2.5 * (1.0 - localProgress);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant EntryParticlePainter oldDelegate) => true;
}

class NovelEntryAnimation extends StatefulWidget {
  final String username;
  final int novelLevel;
  final VoidCallback? onFinished;

  const NovelEntryAnimation({
    Key? key,
    required this.username,
    required this.novelLevel,
    this.onFinished,
  }) : super(key: key);

  @override
  State<NovelEntryAnimation> createState() => _NovelEntryAnimationState();
}

class _NovelEntryAnimationState extends State<NovelEntryAnimation>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _shineController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _shineController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.3, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeIn,
    ));

    // Slide in, pause, then slide out
    _slideController.forward().then((_) async {
      await Future.delayed(const Duration(milliseconds: 3000));
      if (mounted) {
        _slideController.reverse().then((_) {
          if (widget.onFinished != null) {
            widget.onFinished!();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  Color _getNovelAccentColor() {
    switch (widget.novelLevel) {
      case 1:
        return const Color(0xFF2563EB); // Royal Blue
      case 2:
        return const Color(0xFF8B5CF6); // Galaxy Purple
      case 3:
        return const Color(0xFFFFD700); // Gold Palace
      case 4:
        return const Color(0xFFDC2626); // Dragon Red
      case 5:
        return const Color(0xFFF97316); // Phoenix Orange
      case 6:
        return const Color(0xFF06B6D4); // Celestial Cyan
      case 7:
        return const Color(0xFFFFD700); // Immortal Gold/Black
      default:
        return Colors.grey;
    }
  }

  String _getNovelTitle() {
    switch (widget.novelLevel) {
      case 1: return 'Classic Novel';
      case 2: return 'Galaxy Novel';
      case 3: return 'Royal Palace Novel';
      case 4: return 'Dragon Fire Novel';
      case 5: return 'Phoenix Flame Novel';
      case 6: return 'Celestial Diamond Novel';
      case 7: return 'IMMORTAL NOVEL';
      default: return 'Novel Member';
    }
  }

  String _getJoinMessage() {
    if (widget.novelLevel == 7) {
      return 'The Cosmic Legend is here! 👑';
    } else if (widget.novelLevel >= 5) {
      return 'Flames of prestige have entered!';
    } else {
      return 'Has entered the room.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.novelLevel < 1 || widget.novelLevel > 7) {
      return const SizedBox.shrink();
    }

    final accentColor = _getNovelAccentColor();
    final String title = _getNovelTitle();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 64,
          child: Stack(
            children: [
              // 1. Background Card Glassmorphism
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: widget.novelLevel == 7 ? const Color(0xFF09090B) : Colors.black.withOpacity(0.85),
                  border: Border.all(
                    color: accentColor.withOpacity(0.75),
                    width: widget.novelLevel >= 6 ? 2.0 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.35),
                      blurRadius: 14,
                      spreadRadius: 2.5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    children: [
                      // Particles background animation
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _shineController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: EntryParticlePainter(
                                progress: _shineController.value,
                                color: accentColor,
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12, right: 24, top: 4, bottom: 4),
                        child: Row(
                    children: [
                      // Embellished Avatar Emblem
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: widget.novelLevel == 7
                                ? const [Color(0xFFFFD700), Color(0xFF1C1917), Color(0xFFFFD700)]
                                : [accentColor, Colors.black, accentColor],
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            '🔮',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Text Info
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                NovelBadgeWidget(level: widget.novelLevel, fontSize: 10),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ShaderMask(
                                    shaderCallback: (bounds) {
                                      return LinearGradient(
                                        colors: widget.novelLevel >= 6
                                            ? const [
                                                Color(0xFFFFD700),
                                                Color(0xFFE2E8F0),
                                                Color(0xFFFFD700),
                                              ]
                                            : [Colors.white, accentColor],
                                      ).createShader(bounds);
                                    },
                                    child: Text(
                                      widget.username,
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getJoinMessage(),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                    ],
                  ),
                ),
              ),

              // 2. Animated Shine Sweeper overlay
              AnimatedBuilder(
                animation: _shineController,
                builder: (context, child) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: FractionallySizedBox(
                      widthFactor: 1.0,
                      heightFactor: 1.0,
                      child: ShaderMask(
                        shaderCallback: (bounds) {
                          final double slideVal = _shineController.value * 2 - 0.5;
                          return LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: [
                              math.max(0.0, slideVal - 0.2),
                              math.max(0.0, slideVal),
                              math.min(1.0, slideVal + 0.2),
                            ],
                            colors: [
                              Colors.transparent,
                              accentColor.withOpacity(0.5),
                              Colors.transparent,
                            ],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcATop,
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
