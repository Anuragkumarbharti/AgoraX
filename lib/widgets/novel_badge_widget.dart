import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SparklePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  SparklePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (animationValue <= 0.0 || animationValue >= 1.0) return;
    
    final paint = Paint()
      ..color = color.withOpacity((1.0 - animationValue) * 0.8)
      ..style = PaintingStyle.fill;

    // Sparkle 1: Top-Left
    double x1 = -4.0 - (8.0 * animationValue);
    double y1 = -2.0 - (4.0 * animationValue);
    canvas.drawCircle(Offset(x1, y1), 1.5 * (1.0 - animationValue), paint);

    // Sparkle 2: Top-Right
    double x2 = size.width + 4.0 + (8.0 * animationValue);
    double y2 = -4.0 - (6.0 * animationValue);
    canvas.drawCircle(Offset(x2, y2), 2.0 * (1.0 - animationValue), paint);

    // Sparkle 3: Bottom-Left
    double x3 = -6.0 - (6.0 * animationValue);
    double y3 = size.height + 4.0 + (5.0 * animationValue);
    canvas.drawCircle(Offset(x3, y3), 1.2 * (1.0 - animationValue), paint);

    // Sparkle 4: Bottom-Right
    double x4 = size.width + 6.0 + (7.0 * animationValue);
    double y4 = size.height + 2.0 + (6.0 * animationValue);
    canvas.drawCircle(Offset(x4, y4), 1.8 * (1.0 - animationValue), paint);
  }

  @override
  bool shouldRepaint(covariant SparklePainter oldDelegate) => true;
}

class NovelBadgeWidget extends StatefulWidget {
  final int level;
  final double fontSize;

  const NovelBadgeWidget({
    Key? key,
    required this.level,
    this.fontSize = 10,
  }) : super(key: key);

  @override
  State<NovelBadgeWidget> createState() => _NovelBadgeWidgetState();
}

class _NovelBadgeWidgetState extends State<NovelBadgeWidget>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _sparkleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _breathController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.level < 1 || widget.level > 7) return const SizedBox.shrink();

    String badgeText = 'NOVEL ${widget.level}';
    Color startColor = const Color(0xFF2563EB);
    Color endColor = const Color(0xFF1E40AF);
    Color textColor = Colors.white;
    List<Shadow> shadows = [];
    BoxBorder? border = Border.all(color: Colors.white24, width: 0.5);
    List<BoxShadow> boxShadows = [];

    switch (widget.level) {
      case 1:
        badgeText = 'Novel I';
        startColor = const Color(0xFF1E40AF);
        endColor = const Color(0xFF1D4ED8);
        border = Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 0.8);
        break;
      case 2:
        badgeText = 'Novel II';
        startColor = const Color(0xFF7C3AED);
        endColor = const Color(0xFF4C1D95);
        border = Border.all(color: Colors.purpleAccent.withOpacity(0.5), width: 0.8);
        boxShadows = [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.3),
            blurRadius: 4,
            spreadRadius: 0.5,
          )
        ];
        break;
      case 3:
        badgeText = 'Novel III';
        startColor = const Color(0xFFFBBF24);
        endColor = const Color(0xFFD97706);
        textColor = const Color(0xFF451A03);
        border = Border.all(color: const Color(0xFFFCD34D), width: 1.0);
        shadows = [const Shadow(color: Colors.white70, blurRadius: 1, offset: Offset(0, 0.5))];
        break;
      case 4:
        badgeText = 'Novel IV';
        startColor = const Color(0xFFDC2626);
        endColor = const Color(0xFF7F1D1D);
        border = Border.all(color: Colors.redAccent.withOpacity(0.6), width: 1.0);
        boxShadows = [
          BoxShadow(
            color: const Color(0xFFDC2626).withOpacity(0.4),
            blurRadius: 6,
            spreadRadius: 1,
          )
        ];
        break;
      case 5:
        badgeText = 'Novel V';
        startColor = const Color(0xFFF97316);
        endColor = const Color(0xFFEA580C);
        border = Border.all(color: const Color(0xFFFDBA74), width: 1.0);
        boxShadows = [
          BoxShadow(
            color: const Color(0xFFF97316).withOpacity(0.45),
            blurRadius: 6,
            spreadRadius: 1,
          )
        ];
        break;
      case 6:
        badgeText = 'Novel VI';
        startColor = const Color(0xFF06B6D4);
        endColor = const Color(0xFF0891B2);
        border = Border.all(color: const Color(0xFF22D3EE), width: 1.2);
        boxShadows = [
          BoxShadow(
            color: const Color(0xFF06B6D4).withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 1.5,
          )
        ];
        break;
      case 7:
        badgeText = 'NOVEL VII';
        startColor = const Color(0xFF1C1917);
        endColor = const Color(0xFF09090B);
        textColor = const Color(0xFFFFD700);
        border = Border.all(color: const Color(0xFFFFD700), width: 1.2);
        shadows = [
          const Shadow(
            color: Color(0xFFFFD700),
            blurRadius: 4,
          )
        ];
        boxShadows = [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.35),
            blurRadius: 8,
            spreadRadius: 1.0,
          )
        ];
        break;
    }

    String getEmojiPrefix() {
      switch (widget.level) {
        case 3: return '👑 ';
        case 4: return '🔥 ';
        case 5: return '🦅 ';
        case 6: return '💎 ';
        case 7: return '🔮 ';
        default: return '✦ ';
      }
    }

    final badgeChild = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        border: border,
        boxShadow: boxShadows,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            getEmojiPrefix(),
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
              letterSpacing: 0.6,
              shadows: shadows,
            ),
          ),
        ],
      ),
    );

    // Apply Breathing scale + Sparkle particle overlay
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_breathController, _sparkleController]),
        builder: (context, child) {
          final scaleVal = 1.0 + (0.05 * _breathController.value);
          final opacityVal = 0.85 + (0.15 * _breathController.value);
          
          return Opacity(
            opacity: opacityVal,
            child: Transform.scale(
              scale: scaleVal,
              child: CustomPaint(
                foregroundPainter: SparklePainter(
                  animationValue: _sparkleController.value,
                  color: widget.level == 7
                      ? const Color(0xFFFFD700)
                      : widget.level == 4
                          ? Colors.redAccent
                          : const Color(0xFFFBBF24),
                ),
                child: badgeChild,
              ),
            ),
          );
        },
      ),
    );
  }
}
