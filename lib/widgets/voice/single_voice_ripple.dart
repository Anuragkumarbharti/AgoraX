import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A unified, visual-only circular voice ripple effect (StarMaker style).
///
/// This widget MUST be rendered inside a [Stack] with [Positioned.fill] or
/// [Positioned] with negative offsets so that it NEVER participates in
/// layout sizing or causes parent seat movement/recalculation.
class SingleVoiceRipple extends StatefulWidget {
  final bool isSpeaking;
  final double soundLevel;
  final double baseSize;
  final Color rippleColor;

  const SingleVoiceRipple({
    Key? key,
    required this.isSpeaking,
    this.soundLevel = 0.0,
    required this.baseSize,
    this.rippleColor = const Color(0xFF00FF66),
  }) : super(key: key);

  @override
  State<SingleVoiceRipple> createState() => _SingleVoiceRippleState();
}

class _SingleVoiceRippleState extends State<SingleVoiceRipple>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isSpeaking) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SingleVoiceRipple oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isSpeaking && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSpeaking) {
      return const SizedBox.shrink();
    }

    final double normalizedVolume =
        (widget.soundLevel / 40.0).clamp(0.2, 1.0);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double progress = _controller.value;

        return CustomPaint(
          size: Size(widget.baseSize, widget.baseSize),
          painter: _StarMakerRipplePainter(
            progress: progress,
            volumeFactor: normalizedVolume,
            color: widget.rippleColor,
          ),
        );
      },
    );
  }
}

class _StarMakerRipplePainter extends CustomPainter {
  final double progress;
  final double volumeFactor;
  final Color color;

  _StarMakerRipplePainter({
    required this.progress,
    required this.volumeFactor,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double baseRadius = math.min(size.width, size.height) / 2;
    // Ripple expands up to 14px outward beyond base radius based on volume
    final double maxExpand = 12.0 + (6.0 * volumeFactor);
    final double currentRadius = baseRadius + (maxExpand * progress);

    // Opacity fades gracefully as ripple expands outward
    final double opacity = (1.0 - progress) * 0.65 * volumeFactor;

    // 1. Soft Outer Glow Aura
    final Paint auraPaint = Paint()
      ..color = color.withOpacity(opacity * 0.35)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6.0 * progress + 2.0);

    canvas.drawCircle(center, currentRadius, auraPaint);

    // 2. Single Smooth Circular Ripple Ring (StarMaker Style)
    final Paint ringPaint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * (1.0 - (progress * 0.4));

    canvas.drawCircle(center, currentRadius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _StarMakerRipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.volumeFactor != volumeFactor ||
        oldDelegate.color != color;
  }
}
