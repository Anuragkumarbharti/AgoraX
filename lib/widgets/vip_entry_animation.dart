import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'vip_badge_widget.dart';

class EntryParticlePainter extends CustomPainter {
  final double progress;
  final Color color;

  EntryParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 10; i++) {
      final double localProgress = (progress + (i * 0.15)) % 1.0;
      final double x = size.width * localProgress;
      final double y = (size.height / 2) + 14 * math.sin(localProgress * 3 * math.pi + i);
      final double radius = 1.5 + 2.0 * (1.0 - localProgress);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant EntryParticlePainter oldDelegate) => true;
}

class VipEntryAnimation extends StatefulWidget {
  final String username;
  final String? avatarUrl;
  final int vipLevel;
  final VoidCallback? onFinished;

  const VipEntryAnimation({
    Key? key,
    required this.username,
    this.avatarUrl,
    required this.vipLevel,
    this.onFinished,
  }) : super(key: key);

  @override
  State<VipEntryAnimation> createState() => _VipEntryAnimationState();
}

class _VipEntryAnimationState extends State<VipEntryAnimation>
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
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _shineController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.2, 0.0),
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
      await Future.delayed(const Duration(milliseconds: 2500));
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

  Color _getVipAccentColor() {
    switch (widget.vipLevel) {
      case 1:
        return const Color(0xFF2563EB); // Royal Blue
      case 2:
        return const Color(0xFF8B5CF6); // Purple
      case 3:
        return const Color(0xFFFFD700); // Gold
      case 4:
        return Colors.white; // Diamond
      case 5:
        return const Color(0xFF06B6D4); // Crystal Cyan
      case 6:
        return const Color(0xFFEC4899); // Rainbow Pink/Orange
      case 7:
        return const Color(0xFFD4AF37); // Legendary Gold
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.vipLevel < 1 || widget.vipLevel > 7) {
      return const SizedBox.shrink();
    }

    final accentColor = _getVipAccentColor();

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
                    color: accentColor.withOpacity(0.6),
                    width: widget.vipLevel >= 6 ? 1.8 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.3),
                      blurRadius: 12,
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
                            // Avatar Circle
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
                                    ? const Center(
                                        child: Text(
                                          '🌟',
                                          style: TextStyle(fontSize: 22),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Text Info (Faded in after slide in)
                            Expanded(
                              child: FadeTransition(
                                opacity: _usernameOpacity,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        VipBadgeWidget(level: widget.vipLevel, fontSize: 10),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ShaderMask(
                                            shaderCallback: (bounds) {
                                              return LinearGradient(
                                                colors: widget.vipLevel >= 6
                                                    ? const [
                                                        Color(0xFFFF007F),
                                                        Color(0xFFFFBF00),
                                                        Color(0xFF00F0FF),
                                                      ]
                                                    : [Colors.white, accentColor],
                                              ).createShader(bounds);
                                            },
                                            child: Text(
                                              widget.username,
                                              style: GoogleFonts.outfit(
                                                fontSize: 15,
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
                                      widget.vipLevel == 7
                                          ? 'Entered the Room Legendarily! 👑'
                                          : 'Has entered the room.',
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

              // 2. Animated Shine Sweeper
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
                              accentColor.withOpacity(0.4),
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
