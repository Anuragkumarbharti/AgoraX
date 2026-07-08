import 'dart:math' as math;
import 'package:flutter/material.dart';

class NovelAvatarDecorator extends StatefulWidget {
  final int level;
  final double size;
  final Widget child;

  const NovelAvatarDecorator({
    Key? key,
    required this.level,
    this.size = 90,
    required this.child,
  }) : super(key: key);

  @override
  State<NovelAvatarDecorator> createState() => _NovelAvatarDecoratorState();
}

class _NovelAvatarDecoratorState extends State<NovelAvatarDecorator> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant NovelAvatarDecorator oldWidget) {
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

    switch (widget.level) {
      case 1:
        // Novel 1 (Classic Royal Blue Border with rotating soft sweep)
        return AnimatedBuilder(
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
                    const Color(0xFF2563EB),
                  ],
                  transform: GradientRotation(_rotationController.value * 2 * math.pi),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.2 + 0.15 * _pulseController.value),
                    blurRadius: 6.0 + (4.0 * _pulseController.value),
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(color: Color(0xFF09090B), shape: BoxShape.circle),
                padding: const EdgeInsets.all(1),
                child: mainAvatar,
              ),
            );
          },
        );

      case 2:
        // Novel II: Galaxy Collection - Purple Nebula Orbit
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
                        Color(0xFF3B0764), // Deep Purple
                        Color(0xFFD946EF), // Nebula Pink
                        Color(0xFF0F172A), // Midnight Blue
                        Color(0xFF3B0764),
                      ],
                      transform: GradientRotation(_rotationController.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD946EF).withOpacity(0.35 + 0.15 * _pulseController.value),
                        blurRadius: 10 + 5 * _pulseController.value,
                        spreadRadius: 1.5,
                      )
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF09090B),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: mainAvatar,
                  ),
                );
              },
            ),
            // Orbiting Galaxy Rings
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: GalaxyOrbitPainter(
                        animationValue: _rotationController.value,
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
        // Novel III: Royal Palace Collection - Marble and Emerald Palace
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: widget.size,
              height: widget.size,
              padding: const EdgeInsets.all(6),
              child: mainAvatar,
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: MarblePalacePainter(pulseValue: _pulseController.value),
                    );
                  },
                ),
              ),
            ),
          ],
        );

      case 4:
        // Novel IV: Dragon Collection - Obsidian Dragon Wings & Molten Magma
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Glowing lava border
            AnimatedBuilder(
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
                        Color(0xFFDC2626), // Crimson
                        Color(0xFFF97316), // Molten Orange
                        Color(0xFF09090B), // Obsidian
                        Color(0xFFDC2626),
                      ],
                      transform: GradientRotation(_rotationController.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF97316).withOpacity(0.4 + 0.20 * _pulseController.value),
                        blurRadius: 12.0 + (6.0 * _pulseController.value),
                        spreadRadius: 2.5,
                      )
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(color: Color(0xFF09090B), shape: BoxShape.circle),
                    padding: const EdgeInsets.all(2.5),
                    child: mainAvatar,
                  ),
                );
              },
            ),
            // Flapping Dragon Wings on sides
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: DragonWingsPainter(pulseValue: _pulseController.value),
                    );
                  },
                ),
              ),
            ),
          ],
        );

      case 5:
        // Novel V: Phoenix Collection - Feather Wings & Rising Feather Embers
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Solar Sweep Border
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
                        Color(0xFFEA580C), // Phoenix Orange
                        Color(0xFF4C1D95), // Violet
                        Color(0xFFFACC15), // Solar Yellow
                        Color(0xFFEA580C),
                      ],
                      transform: GradientRotation(_rotationController.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEA580C).withOpacity(0.45 + (0.15 * _pulseController.value)),
                        blurRadius: 12.0 + (6.0 * _pulseController.value),
                        spreadRadius: 2.5,
                      )
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF09090B),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: mainAvatar,
                  ),
                );
              },
            ),
            // Phoenix Wings and Feathers
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_rotationController, _pulseController]),
                  builder: (context, child) {
                    return CustomPaint(
                      painter: PhoenixWingsPainter(
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

      case 6:
        // Novel VI: Celestial Collection - Platinum Wings and Twinkling Stars
        return Stack(
          alignment: Alignment.center,
          children: [
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
                        Color(0xFF60A5FA), // Pearlescent Blue
                        Color(0xFFF1F5F9), // Platinum White
                        Color(0xFF312E81), // Cosmic Indigo
                        Color(0xFF60A5FA),
                      ],
                      transform: GradientRotation(_rotationController.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF60A5FA).withOpacity(0.45 + (0.15 * _pulseController.value)),
                        blurRadius: 16.0 + (6.0 * _pulseController.value),
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(color: Color(0xFF09090B), shape: BoxShape.circle),
                    padding: const EdgeInsets.all(2.5),
                    child: mainAvatar,
                  ),
                );
              },
            ),
            // Angel wings & stardust sparkles
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: CelestialTemplePainter(pulseValue: _pulseController.value),
                    );
                  },
                ),
              ),
            ),
          ],
        );

      case 7:
        // Novel VII: Cosmic Emperor - Rotating Void & Constellation Star Gate
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Black hole void sphere
            AnimatedBuilder(
              animation: Listenable.merge([_rotationController, _pulseController]),
              builder: (context, child) {
                return Container(
                  width: widget.size,
                  height: widget.size,
                  padding: const EdgeInsets.all(5.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: const [
                        Color(0xFFF59E0B), // Star Gold
                        Color(0xFF030712), // Space Void Black
                        Color(0xFF1E1B4B), // Void Indigo
                        Color(0xFFF59E0B),
                      ],
                      transform: GradientRotation(_rotationController.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.55 + 0.15 * _pulseController.value),
                        blurRadius: 20 + 8 * _pulseController.value,
                        spreadRadius: 4,
                      )
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF030712), // Deeper void black
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: mainAvatar,
                  ),
                );
              },
            ),
            // Golden star constellation lines
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_rotationController, _pulseController]),
                  builder: (context, child) {
                    return CustomPaint(
                      painter: CosmicEmperorVoidPainter(
                        rotationValue: _rotationController.value,
                        pulseValue: _pulseController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
            // Floating Crown on Top Left
            Positioned(
              top: -18,
              left: -8,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final angle = -0.22 + (0.05 * math.sin(_pulseController.value * math.pi));
                  return Transform.rotate(
                    angle: angle,
                    child: const Text(
                      '👑',
                      style: TextStyle(
                        fontSize: 30,
                        shadows: [
                          Shadow(color: Color(0xFFF59E0B), blurRadius: 14),
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
// Custom Painters for Premium Novel Effects
// ==========================================

class GalaxyOrbitPainter extends CustomPainter {
  final double animationValue;
  final double pulseValue;

  GalaxyOrbitPainter({required this.animationValue, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD946EF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    // Draw an elliptical orbit ring
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-math.pi / 6);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 2 + 8, height: (r * 2 + 8) * 0.4),
      paint,
    );

    // Draw an orbiting star/planet along the path
    final double angle = animationValue * 2 * math.pi;
    final double px = (r + 4) * math.cos(angle);
    final double py = (r + 4) * 0.4 * math.sin(angle);

    final starPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(px, py), 3.0 + (1.0 * pulseValue), starPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GalaxyOrbitPainter oldDelegate) => true;
}

class MarblePalacePainter extends CustomPainter {
  final double pulseValue;
  MarblePalacePainter({required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    final borderPaint = Paint()
      ..color = const Color(0xFFF8FAFC) // Marble White
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(Offset(cx, cy), r - 2, borderPaint);

    final goldPaint = Paint()
      ..color = const Color(0xFFFCD34D) // Champagne Gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), r + 0.5, goldPaint);

    // Draw 4 emerald gemstones on the corners
    final emeraldPaint = Paint()
      ..color = const Color(0xFF10B981) // Emerald Green
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final double angle = (i * math.pi / 2) + (math.pi / 4);
      final double ex = cx + (r - 2) * math.cos(angle);
      final double ey = cy + (r - 2) * math.sin(angle);

      // Draw diamond-shaped emerald gem
      final path = Path()
        ..moveTo(ex, ey - 4)
        ..lineTo(ex + 4, ey)
        ..lineTo(ex, ey + 4)
        ..lineTo(ex - 4, ey)
        ..close();
      canvas.drawPath(path, emeraldPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MarblePalacePainter oldDelegate) => false;
}

class DragonWingsPainter extends CustomPainter {
  final double pulseValue;
  DragonWingsPainter({required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    final wingPaint = Paint()
      ..color = const Color(0xFFDC2626) // Crimson Red
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = const Color(0xFFF97316) // Magma Orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Flapping amount using pulseValue
    final double flap = 2.0 * math.sin(pulseValue * math.pi);

    // Left Wing
    final leftWing = Path()
      ..moveTo(cx - r + 3, cy - 10)
      ..quadraticBezierTo(cx - r - 15 - flap, cy - 25, cx - r - 25 - flap, cy - 10)
      ..quadraticBezierTo(cx - r - 18 - flap, cy, cx - r - 22 - flap, cy + 12)
      ..quadraticBezierTo(cx - r - 8, cy + 5, cx - r + 3, cy + 10)
      ..close();

    // Right Wing
    final rightWing = Path()
      ..moveTo(cx + r - 3, cy - 10)
      ..quadraticBezierTo(cx + r + 15 + flap, cy - 25, cx + r + 25 + flap, cy - 10)
      ..quadraticBezierTo(cx + r + 18 + flap, cy, cx + r + 22 + flap, cy + 12)
      ..quadraticBezierTo(cx + r + 8, cy + 5, cx + r - 3, cy + 10)
      ..close();

    canvas.drawPath(leftWing, wingPaint);
    canvas.drawPath(leftWing, outlinePaint);
    canvas.drawPath(rightWing, wingPaint);
    canvas.drawPath(rightWing, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant DragonWingsPainter oldDelegate) => true;
}

class PhoenixWingsPainter extends CustomPainter {
  final double rotationValue;
  final double pulseValue;

  PhoenixWingsPainter({required this.rotationValue, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    // Draw flowing golden-orange phoenix feathers floating around
    final paint = Paint()
      ..color = const Color(0xFFEA580C).withOpacity(0.5 + 0.3 * pulseValue)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 6; i++) {
      final double angle = (rotationValue * 2 * math.pi) + (i * math.pi / 3);
      final double fx = cx + (r - 2) * math.cos(angle);
      final double fy = cy + (r - 2) * math.sin(angle);

      // Feather shape
      canvas.save();
      canvas.translate(fx, fy);
      canvas.rotate(angle + math.pi / 2);
      final feather = Path()
        ..moveTo(0, -6)
        ..quadraticBezierTo(-4, 0, 0, 8)
        ..quadraticBezierTo(4, 0, 0, -6)
        ..close();
      canvas.drawPath(feather, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant PhoenixWingsPainter oldDelegate) => true;
}

class CelestialTemplePainter extends CustomPainter {
  final double pulseValue;
  CelestialTemplePainter({required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    final wingPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    final goldPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double stretch = pulseValue * 3.0;

    // Ethereal Angel Wings
    // Left Wing
    final leftWing = Path()
      ..moveTo(cx - r + 4, cy - 12)
      ..quadraticBezierTo(cx - r - 22, cy - 22 - stretch, cx - r - 20, cy - 2)
      ..quadraticBezierTo(cx - r - 12, cy + 10, cx - r + 4, cy + 12)
      ..close();

    // Right Wing
    final rightWing = Path()
      ..moveTo(cx + r - 4, cy - 12)
      ..quadraticBezierTo(cx + r + 22, cy - 22 - stretch, cx + r + 20, cy - 2)
      ..quadraticBezierTo(cx + r + 12, cy + 10, cx + r - 4, cy + 12)
      ..close();

    canvas.drawPath(leftWing, wingPaint);
    canvas.drawPath(leftWing, goldPaint);
    canvas.drawPath(rightWing, wingPaint);
    canvas.drawPath(rightWing, goldPaint);

    // Stardust Sparkles on the border
    final sparklePaint = Paint()
      ..color = Colors.white.withOpacity(0.4 + 0.6 * pulseValue)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx + r - 8, cy - r + 8), 2.0, sparklePaint);
    canvas.drawCircle(Offset(cx - r + 8, cy - r + 8), 1.5, sparklePaint);
  }

  @override
  bool shouldRepaint(covariant CelestialTemplePainter oldDelegate) => true;
}

class CosmicEmperorVoidPainter extends CustomPainter {
  final double rotationValue;
  final double pulseValue;

  CosmicEmperorVoidPainter({required this.rotationValue, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    final paint = Paint()
      ..color = const Color(0xFFF59E0B).withOpacity(0.5 + (0.5 * pulseValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw golden constellation lines connecting points
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotationValue * 2 * math.pi);

    final points = <Offset>[
      Offset((r + 2) * math.cos(0), (r + 2) * math.sin(0)),
      Offset((r + 2) * math.cos(math.pi / 3), (r + 2) * math.sin(math.pi / 3)),
      Offset((r + 2) * math.cos(2 * math.pi / 3), (r + 2) * math.sin(2 * math.pi / 3)),
      Offset((r + 2) * math.cos(math.pi), (r + 2) * math.sin(math.pi)),
      Offset((r + 2) * math.cos(4 * math.pi / 3), (r + 2) * math.sin(4 * math.pi / 3)),
      Offset((r + 2) * math.cos(5 * math.pi / 3), (r + 2) * math.sin(5 * math.pi / 3)),
    ];

    // Draw constellation lines
    for (int i = 0; i < points.length; i++) {
      final next = points[(i + 2) % points.length];
      canvas.drawLine(points[i], next, paint);
    }

    // Draw star nodes
    final nodePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    for (final pt in points) {
      canvas.drawCircle(pt, 2.0, nodePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CosmicEmperorVoidPainter oldDelegate) => true;
}
