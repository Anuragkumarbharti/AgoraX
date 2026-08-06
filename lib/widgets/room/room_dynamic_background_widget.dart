import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/room/room_background_model.dart';

class RoomDynamicBackgroundWidget extends StatefulWidget {
  final RoomBackgroundItem background;
  final Widget? child;

  const RoomDynamicBackgroundWidget({
    Key? key,
    required this.background,
    this.child,
  }) : super(key: key);

  @override
  State<RoomDynamicBackgroundWidget> createState() =>
      _RoomDynamicBackgroundWidgetState();
}

class _RoomDynamicBackgroundWidgetState
    extends State<RoomDynamicBackgroundWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_animController.isAnimating) {
        _animController.stop(canceled: false);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_animController.isAnimating) {
        _animController.repeat();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.background;
    final double overlayAlpha = bg.isLightBackground
        ? bg.overlayDarkness.clamp(0.40, 0.70)
        : bg.overlayDarkness.clamp(0.15, 0.40);
    final ambientColor = (bg.gradientColors != null && bg.gradientColors!.isNotEmpty)
        ? bg.gradientColors!.first
        : const Color(0xFF8B5CF6);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1 & Layer 3: Base Wallpaper with Selective Background Gaussian Blur
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: KeyedSubtree(
            key: ValueKey(bg.id),
            child: SizedBox.expand(
              child: _buildBaseLayer(bg),
            ),
          ),
        ),

        // Layer 2. Brightness-Adaptive Dark Scrim Overlay
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(overlayAlpha),
          ),
        ),

        // Layer 4. Readability Scrim Gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF000000).withOpacity(0.35),
                  Colors.transparent,
                  const Color(0xFF0A081E).withOpacity(0.70),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // Layer 5. Procedural GPU Particle FX Canvas Layer
        if (bg.type == RoomBackgroundType.animatedBackground &&
            bg.animatedType != null)
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _getParticlePainter(bg.animatedType!, _animController.value),
                  );
                },
              ),
            ),
          ),

        // Layer 6. Soft Ambient Center Glow
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.2),
                  radius: 0.85,
                  colors: [
                    ambientColor.withOpacity(0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Child UI content
        if (widget.child != null) widget.child!,
      ],
    );
  }

  Widget _buildBaseLayer(RoomBackgroundItem bg) {
    final List<Color> colors = bg.gradientColors ??
        const [Color(0xFF0F172A), Color(0xFF020617)];
    final double blurSigma = (bg.blurOpacity * 20).clamp(0.0, 12.0);

    Widget backdrop;
    if (bg.wallpaperUrl != null && bg.wallpaperUrl!.isNotEmpty) {
      backdrop = Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: bg.gradientBegin,
                end: bg.gradientEnd,
              ),
            ),
          ),
          CachedNetworkImage(
            imageUrl: bg.wallpaperUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: bg.gradientBegin,
                  end: bg.gradientEnd,
                ),
              ),
            ),
            errorWidget: (context, url, err) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: bg.gradientBegin,
                  end: bg.gradientEnd,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      backdrop = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: bg.gradientBegin,
            end: bg.gradientEnd,
          ),
        ),
      );
    }

    if (blurSigma > 0.5) {
      return ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: backdrop,
      );
    }

    return backdrop;
  }

  CustomPainter _getParticlePainter(AnimatedBackgroundType type, double progress) {
    switch (type) {
      case AnimatedBackgroundType.stars:
        return _StarsPainter(progress: progress);
      case AnimatedBackgroundType.floatingLights:
        return _FloatingLightsPainter(progress: progress);
      case AnimatedBackgroundType.snow:
        return _SnowPainter(progress: progress);
      case AnimatedBackgroundType.rain:
        return _RainPainter(progress: progress);
      case AnimatedBackgroundType.bubbles:
        return _BubblesPainter(progress: progress);
      case AnimatedBackgroundType.fireflies:
        return _FirefliesPainter(progress: progress);
      case AnimatedBackgroundType.aurora:
        return _AuroraPainter(progress: progress);
      case AnimatedBackgroundType.animatedGradient:
        return _AnimatedGradientPainter(progress: progress);
      case AnimatedBackgroundType.particles:
      default:
        return _ParticlesPainter(progress: progress);
    }
  }
}

// ==========================================
// PROCEDURAL GPU-ACCELERATED CUSTOM PAINTERS
// ==========================================

class _ParticlesPainter extends CustomPainter {
  final double progress;
  _ParticlesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(42);

    for (int i = 0; i < 40; i++) {
      final double startX = random.nextDouble() * size.width;
      final double startY = random.nextDouble() * size.height;
      final double speed = 0.2 + random.nextDouble() * 0.5;

      final double currentY = (startY - (progress * size.height * speed)) % size.height;
      final double currentX = startX + sin(progress * 2 * pi + i) * 12;
      final double radius = 1.5 + random.nextDouble() * 2.5;

      paint.color = Colors.white.withOpacity(0.15 + 0.25 * sin(progress * 2 * pi + i));
      canvas.drawCircle(Offset(currentX, currentY), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) => true;
}

class _StarsPainter extends CustomPainter {
  final double progress;
  _StarsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(101);

    for (int i = 0; i < 60; i++) {
      final double x = random.nextDouble() * size.width;
      final double y = random.nextDouble() * size.height;
      final double baseAlpha = 0.2 + 0.6 * random.nextDouble();
      final double twinkle = sin((progress * 4 * pi) + (i * 0.5));
      final double opacity = (baseAlpha + twinkle * 0.3).clamp(0.1, 0.9);

      paint.color = (i % 5 == 0 ? Colors.amberAccent : Colors.cyanAccent)
          .withOpacity(opacity);
      final double radius = 1.0 + (i % 3) * 0.8;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) => true;
}

class _FloatingLightsPainter extends CustomPainter {
  final double progress;
  _FloatingLightsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(888);

    for (int i = 0; i < 20; i++) {
      final double startX = random.nextDouble() * size.width;
      final double startY = random.nextDouble() * size.height;
      final double speed = 0.1 + random.nextDouble() * 0.3;

      final double y = (startY - (progress * size.height * speed)) % size.height;
      final double x = startX + sin(progress * 2 * pi + i) * 20;
      final double radius = 8.0 + random.nextDouble() * 16.0;

      final color = i % 2 == 0 ? Colors.amber : Colors.purpleAccent;
      paint.color = color.withOpacity(0.12 + 0.15 * sin(progress * 2 * pi + i));

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingLightsPainter oldDelegate) => true;
}

class _SnowPainter extends CustomPainter {
  final double progress;
  _SnowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill..color = Colors.white;
    final random = Random(333);

    for (int i = 0; i < 50; i++) {
      final double startX = random.nextDouble() * size.width;
      final double startY = random.nextDouble() * size.height;
      final double speed = 0.3 + random.nextDouble() * 0.5;

      final double y = (startY + (progress * size.height * speed)) % size.height;
      final double x = startX + sin(progress * 3 * pi + i) * 15;
      final double radius = 1.5 + random.nextDouble() * 2.5;

      paint.color = Colors.white.withOpacity(0.4 + 0.4 * random.nextDouble());
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) => true;
}

class _RainPainter extends CustomPainter {
  final double progress;
  _RainPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final random = Random(555);

    for (int i = 0; i < 60; i++) {
      final double startX = random.nextDouble() * size.width;
      final double startY = random.nextDouble() * size.height;
      final double speed = 0.8 + random.nextDouble() * 0.6;

      final double y = (startY + (progress * size.height * speed)) % size.height;
      final double x = startX - (progress * 50);

      paint.color = Colors.cyanAccent.withOpacity(0.25 + 0.3 * random.nextDouble());
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 4, y + 14),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) => true;
}

class _BubblesPainter extends CustomPainter {
  final double progress;
  _BubblesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paintStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final paintFill = Paint()..style = PaintingStyle.fill;
    final random = Random(999);

    for (int i = 0; i < 25; i++) {
      final double startX = random.nextDouble() * size.width;
      final double startY = random.nextDouble() * size.height;
      final double speed = 0.2 + random.nextDouble() * 0.4;

      final double y = (startY - (progress * size.height * speed)) % size.height;
      final double x = startX + sin(progress * 2 * pi + i) * 18;
      final double radius = 4.0 + random.nextDouble() * 10.0;

      paintStroke.color = Colors.cyanAccent.withOpacity(0.35);
      paintFill.color = Colors.lightBlueAccent.withOpacity(0.08);

      canvas.drawCircle(Offset(x, y), radius, paintFill);
      canvas.drawCircle(Offset(x, y), radius, paintStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) => true;
}

class _FirefliesPainter extends CustomPainter {
  final double progress;
  _FirefliesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(777);

    for (int i = 0; i < 30; i++) {
      final double startX = random.nextDouble() * size.width;
      final double startY = random.nextDouble() * size.height;

      final double x = startX + cos((progress * 2 * pi) + i) * 25;
      final double y = startY + sin((progress * 2 * pi) + i) * 25;
      final double alpha = (0.2 + 0.7 * sin((progress * 4 * pi) + i)).clamp(0.0, 1.0);

      paint.color = Colors.amberAccent.withOpacity(alpha);
      canvas.drawCircle(Offset(x, y), 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FirefliesPainter oldDelegate) => true;
}

class _AuroraPainter extends CustomPainter {
  final double progress;
  _AuroraPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final double waveShift = sin(progress * 2 * pi) * 40;

    path.moveTo(0, size.height * 0.3);
    path.cubicTo(
      size.width * 0.3,
      size.height * 0.2 + waveShift,
      size.width * 0.6,
      size.height * 0.4 - waveShift,
      size.width,
      size.height * 0.25,
    );
    path.lineTo(size.width, size.height * 0.6);
    path.cubicTo(
      size.width * 0.6,
      size.height * 0.5 - waveShift,
      size.width * 0.3,
      size.height * 0.4 + waveShift,
      0,
      size.height * 0.5,
    );
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.tealAccent.withOpacity(0.20),
          Colors.purpleAccent.withOpacity(0.25),
          Colors.blueAccent.withOpacity(0.15),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => true;
}

class _AnimatedGradientPainter extends CustomPainter {
  final double progress;
  _AnimatedGradientPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final double shiftX = sin(progress * 2 * pi) * (size.width * 0.3);
    final double shiftY = cos(progress * 2 * pi) * (size.height * 0.3);

    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(shiftX / size.width, shiftY / size.height),
        radius: 1.2,
        colors: [
          Colors.pinkAccent.withOpacity(0.18),
          Colors.purpleAccent.withOpacity(0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _AnimatedGradientPainter oldDelegate) => true;
}
