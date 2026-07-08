import 'dart:math' as math;
import 'package:flutter/material.dart';

class VipAvatarDecorator extends StatefulWidget {
  final int level;
  final double size;
  final Widget child;

  const VipAvatarDecorator({
    Key? key,
    required this.level,
    this.size = 90,
    required this.child,
  }) : super(key: key);

  @override
  State<VipAvatarDecorator> createState() => _VipAvatarDecoratorState();
}

class _VipAvatarDecoratorState extends State<VipAvatarDecorator> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant VipAvatarDecorator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_rotationController.isAnimating) _rotationController.repeat();
    if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.level <= 0) {
      return Container(
        width: widget.size,
        height: widget.size,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: widget.child,
      );
    }

    Widget mainAvatar = ClipRRect(
      borderRadius: BorderRadius.circular(widget.size),
      child: widget.child,
    );

    // Apply specific level styling
    switch (widget.level) {
      case 1:
        // Royal Collection: Velvet Blue Sweep with Floating Gold Sparkles
        return Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_rotationController, _pulseController]),
              builder: (context, child) {
                final pulseVal = 0.8 + (0.2 * _pulseController.value);
                return Container(
                  width: widget.size,
                  height: widget.size,
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        const Color(0xFF2563EB),
                        const Color(0xFF1E40AF).withOpacity(pulseVal),
                        const Color(0xFFFFD700),
                        const Color(0xFF2563EB),
                      ],
                      transform: GradientRotation(_rotationController.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(color: Color(0xFF09090B), shape: BoxShape.circle),
                    padding: const EdgeInsets.all(1.5),
                    child: mainAvatar,
                  ),
                );
              },
            ),
            // Floating Gold Sparkles
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: RoyalSparklePainter(animationValue: _rotationController.value),
                    );
                  },
                ),
              ),
            ),
          ],
        );

      case 2:
        // Neon Collection: Glowing Neon Hexagon
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: widget.size,
              height: widget.size,
              padding: const EdgeInsets.all(8),
              child: mainAvatar,
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_rotationController, _pulseController]),
                  builder: (context, child) {
                    return CustomPaint(
                      painter: NeonHexagonPainter(
                        rotationValue: _rotationController.value,
                        pulseValue: _pulseController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );

      case 3:
        // Golden Collection: Gilded Ring with Pulsating Top Star
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_rotationController, _pulseController]),
              builder: (context, child) {
                final glowVal = 8.0 + (6.0 * _pulseController.value);
                return Container(
                  width: widget.size,
                  height: widget.size,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: const [
                        Color(0xFFFFD700),
                        Color(0xFFB45309),
                        Color(0xFFFFEA70),
                        Color(0xFFFFD700),
                      ],
                      transform: GradientRotation(_rotationController.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.35 + (0.15 * _pulseController.value)),
                        blurRadius: glowVal,
                        spreadRadius: 1.5,
                      )
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(color: Color(0xFF09090B), shape: BoxShape.circle),
                    padding: const EdgeInsets.all(2),
                    child: mainAvatar,
                  ),
                );
              },
            ),
            // Pulsating Gold Star on top center
            Positioned(
              top: -6,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (0.2 * _pulseController.value);
                  return Transform.scale(
                    scale: scale,
                    child: const Icon(
                      Icons.star,
                      color: Color(0xFFFFD700),
                      size: 16,
                      shadows: [
                        Shadow(color: Color(0xFFFFEA70), blurRadius: 12),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );

      case 4:
        // Diamond Collection: Crystalline White with Shimmer Sweep
        return Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_rotationController, _pulseController]),
              builder: (context, child) {
                return Container(
                  width: widget.size,
                  height: widget.size,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: const [
                        Color(0xFFF1F5F9),
                        Colors.white,
                        Color(0xFFCBD5E1),
                        Color(0xFFF1F5F9),
                      ],
                      transform: GradientRotation(_rotationController.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.20 + (0.15 * _pulseController.value)),
                        blurRadius: 7.0 + (5.0 * _pulseController.value),
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(color: Color(0xFF09090B), shape: BoxShape.circle),
                    padding: const EdgeInsets.all(2),
                    child: mainAvatar,
                  ),
                );
              },
            ),
            // Diamond Shimmer Sweep
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ShimmerSweepPainter(animationValue: _rotationController.value),
                    );
                  },
                ),
              ),
            ),
          ],
        );

      case 5:
        // Crystal Collection: Spikey Cool-Blue Ice Crystals
        return Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_rotationController, _pulseController]),
              builder: (context, child) {
                return Container(
                  width: widget.size,
                  height: widget.size,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: const [
                        Color(0xFF06B6D4),
                        Colors.white,
                        Color(0xFF0891B2),
                        Color(0xFF06B6D4),
                      ],
                      transform: GradientRotation(_rotationController.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF06B6D4).withOpacity(0.35 + (0.15 * _pulseController.value)),
                        blurRadius: 10.0 + (6.0 * _pulseController.value),
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(color: Color(0xFF09090B), shape: BoxShape.circle),
                    padding: const EdgeInsets.all(2),
                    child: mainAvatar,
                  ),
                );
              },
            ),
            // Icy Crystal Spikes
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: IceSpikePainter(pulseValue: _pulseController.value),
                    );
                  },
                ),
              ),
            ),
          ],
        );

      case 6:
        // Rainbow Collection: Active Spectrum Glow Loop
        return AnimatedBuilder(
          animation: Listenable.merge([_rotationController, _pulseController]),
          builder: (context, child) {
            return Container(
              width: widget.size,
              height: widget.size,
              padding: const EdgeInsets.all(4.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: const [
                    Color(0xFFFF007F),
                    Color(0xFFFFBF00),
                    Color(0xFF00F0FF),
                    Color(0xFFFF007F),
                  ],
                  transform: GradientRotation(_rotationController.value * 2 * math.pi),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3 + (0.25 * _pulseController.value)),
                    blurRadius: 12.0 + (8.0 * _pulseController.value),
                  )
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF09090B),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: mainAvatar,
              ),
            );
          },
        );

      case 7:
        // Emperor Collection: Obsidian Border with Gold-Plated Dragon body & Crown
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Rotating Fire Aura
            AnimatedBuilder(
              animation: Listenable.merge([_rotationController, _pulseController]),
              builder: (context, child) {
                return Container(
                  width: widget.size,
                  height: widget.size,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: const [
                        Color(0xFFFFD43F),
                        Color(0xFF1E1B4B), // Void
                        Color(0xFFFF3F3F),
                        Color(0xFFFFD43F),
                      ],
                      transform: GradientRotation(_rotationController.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF3F3F).withOpacity(0.45 + (0.15 * _pulseController.value)),
                        blurRadius: 14 + (6 * _pulseController.value),
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF09090B),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: mainAvatar,
                  ),
                );
              },
            ),
            // Procedural Obsidian Dragon details
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ObsidianDragonPainter(pulseValue: _pulseController.value),
                    );
                  },
                ),
              ),
            ),
            // Floating Crown on Top Left
            Positioned(
              top: -18,
              left: -6,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final angle = -0.22 + (0.05 * math.sin(_pulseController.value * math.pi));
                  return Transform.rotate(
                    angle: angle,
                    child: const Text(
                      '👑',
                      style: TextStyle(
                        fontSize: 28,
                        shadows: [
                          Shadow(color: Color(0xFFFFD700), blurRadius: 10),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );

      default:
        return mainAvatar;
    }
  }
}

// ==========================================
// Custom Painters for Premium VIP Effects
// ==========================================

class RoyalSparklePainter extends CustomPainter {
  final double animationValue;
  RoyalSparklePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    // Draw 4 rotating golden stars
    for (int i = 0; i < 4; i++) {
      final double angle = (animationValue * 2 * math.pi) + (i * math.pi / 2);
      final double sx = cx + r * math.cos(angle);
      final double sy = cy + r * math.sin(angle);
      canvas.drawCircle(Offset(sx, sy), 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RoyalSparklePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

class NeonHexagonPainter extends CustomPainter {
  final double rotationValue;
  final double pulseValue;

  NeonHexagonPainter({required this.rotationValue, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = (size.width / 2) - 2;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final double angle = (rotationValue * 2 * math.pi) + (i * math.pi / 3);
      final double x = cx + r * math.cos(angle);
      final double y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 + (1.5 * pulseValue)
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFF007F), // Neon Pink
          Color(0xFF00F0FF), // Neon Cyan
          Color(0xFFFF007F),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 + (2.0 * pulseValue));

    canvas.drawPath(path, glowPaint);

    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white;

    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(covariant NeonHexagonPainter oldDelegate) => true;
}

class IceSpikePainter extends CustomPainter {
  final double pulseValue;
  IceSpikePainter({required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF67E8F9).withOpacity(0.7 + (0.3 * pulseValue))
      ..style = PaintingStyle.fill;

    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    // Draw 8 crystal ice spikes pointing outward
    for (int i = 0; i < 8; i++) {
      final double angle = (i * math.pi / 4);
      final double startR = r - 4;
      final double endR = r + 3.0 + (3.0 * pulseValue);

      final double sx = cx + startR * math.cos(angle - 0.08);
      final double sy = cy + startR * math.sin(angle - 0.08);

      final double px = cx + endR * math.cos(angle);
      final double py = cy + endR * math.sin(angle);

      final double ex = cx + startR * math.cos(angle + 0.08);
      final double ey = cy + startR * math.sin(angle + 0.08);

      final spikePath = Path()
        ..moveTo(sx, sy)
        ..lineTo(px, py)
        ..lineTo(ex, ey)
        ..close();

      canvas.drawPath(spikePath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant IceSpikePainter oldDelegate) =>
      oldDelegate.pulseValue != pulseValue;
}

class ShimmerSweepPainter extends CustomPainter {
  final double animationValue;
  ShimmerSweepPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.65),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    // Sweeping angled shine line
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)));
    final double sweepX = -size.width + (animationValue * size.width * 2);
    canvas.translate(sweepX, 0);
    canvas.rotate(math.pi / 4);
    canvas.drawRect(Rect.fromLTWH(0, -size.height, 15, size.height * 2), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ShimmerSweepPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

class ObsidianDragonPainter extends CustomPainter {
  final double pulseValue;
  ObsidianDragonPainter({required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    // Gold scale ornaments (looks like dragon tails/wings) on the sides
    final paint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Left Wing
    final leftWing = Path()
      ..moveTo(cx - r + 3, cy - 8)
      ..quadraticBezierTo(cx - r - 6, cy, cx - r + 3, cy + 8)
      ..moveTo(cx - r - 2, cy - 14)
      ..quadraticBezierTo(cx - r - 12, cy, cx - r - 2, cy + 14);

    // Right Wing
    final rightWing = Path()
      ..moveTo(cx + r - 3, cy - 8)
      ..quadraticBezierTo(cx + r + 6, cy, cx + r - 3, cy + 8)
      ..moveTo(cx + r + 2, cy - 14)
      ..quadraticBezierTo(cx + r + 12, cy, cx + r + 2, cy + 14);

    canvas.drawPath(leftWing, paint);
    canvas.drawPath(rightWing, paint);

    // Volcanic Embers rising
    final emberPaint = Paint()
      ..color = const Color(0xFFFF4500).withOpacity(0.5 + (0.5 * pulseValue))
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final double factor = (i + 1) * 0.25;
      final double offset = math.sin((factor + pulseValue) * math.pi) * 8.0;
      final double ex = cx - 25.0 + (i * 18.0) + offset;
      final double ey = cy + r - 3 - (factor * 12.0);
      canvas.drawCircle(Offset(ex, ey), 1.5 + (1.0 * pulseValue), emberPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ObsidianDragonPainter oldDelegate) => true;
}
