import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VipBadgeWidget extends StatefulWidget {
  final int level;
  final double fontSize;

  const VipBadgeWidget({
    Key? key,
    required this.level,
    this.fontSize = 10,
  }) : super(key: key);

  @override
  State<VipBadgeWidget> createState() => _VipBadgeWidgetState();
}

class _VipBadgeWidgetState extends State<VipBadgeWidget>
    with TickerProviderStateMixin {
  late AnimationController _shineController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shineController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.level <= 0) return const SizedBox.shrink();

    String badgeText = 'VIP ${widget.level}';
    Color startColor = const Color(0xFF2563EB);
    Color endColor = const Color(0xFF1D4ED8);
    Color textColor = Colors.white;
    List<Shadow> shadows = [];

    switch (widget.level) {
      case 1:
        startColor = const Color(0xFF2563EB);
        endColor = const Color(0xFF1E40AF);
        break;
      case 2:
        startColor = const Color(0xFF8B5CF6);
        endColor = const Color(0xFF6D28D9);
        break;
      case 3:
        startColor = const Color(0xFFFFD700);
        endColor = const Color(0xFFB45309);
        textColor = Colors.white;
        shadows = [const Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1))];
        break;
      case 4:
        startColor = const Color(0xFFF8FAFC);
        endColor = const Color(0xFFCBD5E1);
        textColor = const Color(0xFF0F172A);
        break;
      case 5:
        startColor = const Color(0xFF06B6D4);
        endColor = const Color(0xFF0891B2);
        break;
      case 6:
        startColor = const Color(0xFFEC4899);
        endColor = const Color(0xFF3B82F6);
        break;
      case 7:
        startColor = const Color(0xFF1C1917);
        endColor = const Color(0xFF000000);
        textColor = const Color(0xFFFFD700);
        shadows = [const Shadow(color: Color(0xFFFFD700), blurRadius: 4)];
        break;
    }

    final badgeChild = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: widget.level == 7 ? const Color(0xFFFFD700) : Colors.white24,
          width: widget.level == 7 ? 1.0 : 0.5,
        ),
        boxShadow: widget.level >= 5
            ? [
                BoxShadow(
                  color: startColor.withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.level == 7 ? '👑 ' : '✦ ',
            style: TextStyle(
              fontSize: widget.fontSize - 1,
              color: textColor,
            ),
          ),
          Text(
            badgeText,
            style: GoogleFonts.outfit(
              color: textColor,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              shadows: shadows,
            ),
          ),
        ],
      ),
    );

    // Apply Shining Sweep & Gold Shine Pulsing animations
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_shineController, _pulseController]),
        builder: (context, child) {
          final pulseVal = 1.0 + (0.04 * _pulseController.value);
          
          return Transform.scale(
            scale: pulseVal,
            child: ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.4),
                    Colors.white.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                  begin: const Alignment(-2.0, -1.0),
                  end: const Alignment(2.0, 1.0),
                  transform: GradientRotation(_shineController.value * 2 * math.pi),
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcATop,
              child: badgeChild,
            ),
          );
        },
      ),
    );
  }
}
