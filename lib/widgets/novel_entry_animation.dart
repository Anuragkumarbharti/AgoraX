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
  final String? avatarUrl;
  final int novelLevel;
  final VoidCallback? onFinished;

  const NovelEntryAnimation({
    Key? key,
    required this.username,
    this.avatarUrl,
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
  
  // Staggered Opacities & Scales
  late Animation<double> _usernameOpacity;
  late Animation<double> _avatarScale;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1500),
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
      curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    ));

    _usernameOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.4, 0.7, curve: Curves.easeIn),
    ));

    _avatarScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.7, 1.0, curve: Curves.elasticOut),
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
    if (widget.novelLevel >= 1 && widget.novelLevel <= 10) {
      return const Color(0xFFEF4444); // Mystic Ruby Red
    } else if (widget.novelLevel >= 11 && widget.novelLevel <= 20) {
      return const Color(0xFF3B82F6); // Sapphire Blue
    } else if (widget.novelLevel >= 21 && widget.novelLevel <= 30) {
      return const Color(0xFF10B981); // Emerald Green
    } else if (widget.novelLevel >= 31 && widget.novelLevel <= 40) {
      return const Color(0xFFF59E0B); // Amber Bronze
    } else if (widget.novelLevel >= 41 && widget.novelLevel <= 50) {
      return const Color(0xFFD946EF); // Fuchsia Amethyst
    } else if (widget.novelLevel >= 51 && widget.novelLevel <= 70) {
      return const Color(0xFFF97316); // Sun Flare Orange
    } else if (widget.novelLevel >= 71 && widget.novelLevel <= 99) {
      return const Color(0xFF8B5CF6); // Astral Indigo
    } else if (widget.novelLevel == 100) {
      return const Color(0xFFFFD700); // Divine Gold
    }
    return Colors.grey;
  }

  String _getJoinMessage() {
    if (widget.novelLevel == 100) return 'Ascended to the Room Divinely! ☄️';
    if (widget.novelLevel >= 71) return 'Materialized into the Room! ✨';
    if (widget.novelLevel >= 41) return 'Manifested into the Room! 🌟';
    return 'Has entered the room.';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.novelLevel < 1 || widget.novelLevel > 100) {
      return const SizedBox.shrink();
    }

    final accentColor = _getNovelAccentColor();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 60,
          child: Stack(
            children: [
              // 1. Background Card Glassmorphism
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.black.withOpacity(0.85),
                  border: Border.all(
                    color: accentColor.withOpacity(0.65),
                    width: widget.novelLevel >= 51 ? 2.0 : 1.3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.35),
                      blurRadius: 14,
                      spreadRadius: 2,
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
                            // Avatar circle or novel badge
                            ScaleTransition(
                              scale: _avatarScale,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: accentColor.withOpacity(0.6), width: 1.5),
                                  image: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(widget.avatarUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  gradient: widget.avatarUrl == null || widget.avatarUrl!.isEmpty
                                      ? SweepGradient(
                                          colors: [
                                            accentColor,
                                            Colors.black,
                                            accentColor,
                                          ],
                                        )
                                      : null,
                                ),
                                child: widget.avatarUrl == null || widget.avatarUrl!.isEmpty
                                    ? Center(
                                        child: Text(
                                          widget.novelLevel == 100 ? '👑' : '☄️',
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Text Info
                            Expanded(
                              child: FadeTransition(
                                opacity: _usernameOpacity,
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
                                                colors: widget.novelLevel >= 51
                                                    ? const [
                                                        Color(0xFFE0F2FE),
                                                        Color(0xFFC084FC),
                                                        Color(0xFFF472B6),
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
