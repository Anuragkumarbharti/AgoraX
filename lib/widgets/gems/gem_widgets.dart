import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/number_formatter.dart';

enum GemIconSize {
  small(14.0),
  medium(20.0),
  large(32.0);

  final double value;
  const GemIconSize(this.value);
}

/// A centralized, high-performance, reusable Gem icon component.
/// Displays a stunning vector diamond gem with linear gradient shaders,
/// optional glow effect, and subtle scale pulse animation.
class GemIcon extends StatefulWidget {
  final double? size;
  final GemIconSize presetSize;
  final List<Color>? gradientColors;
  final bool animated;
  final bool showGlow;
  final Color? glowColor;

  const GemIcon({
    super.key,
    this.size,
    this.presetSize = GemIconSize.medium,
    this.gradientColors,
    this.animated = false,
    this.showGlow = true,
    this.glowColor,
  });

  @override
  State<GemIcon> createState() => _GemIconState();
}

class _GemIconState extends State<GemIcon> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scaleAnim;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
      _scaleAnim = Tween<double>(begin: 0.94, end: 1.06).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSize = widget.size ?? widget.presetSize.value;
    final defaultColors = widget.gradientColors ??
        const [
          Color(0xFF00F2FE), // Vivid Cyan
          Color(0xFF4FACFE), // Diamond Blue
          Color(0xFF00C6FF), // Deep Blue Gem
        ];
    final defaultGlow = widget.glowColor ?? const Color(0xFF00F2FE).withOpacity(0.45);

    Widget iconWidget = CustomPaint(
      size: Size(effectiveSize, effectiveSize),
      painter: _GemVectorPainter(
        gradientColors: defaultColors,
        showGlow: widget.showGlow,
        glowColor: defaultGlow,
      ),
    );

    if (widget.animated && _scaleAnim != null) {
      iconWidget = ScaleTransition(
        scale: _scaleAnim!,
        child: iconWidget,
      );
    }

    return SizedBox(
      width: effectiveSize,
      height: effectiveSize,
      child: Center(child: iconWidget),
    );
  }
}

/// Custom painter for a sharp, faceted vector gem with light reflection highlights.
class _GemVectorPainter extends CustomPainter {
  final List<Color> gradientColors;
  final bool showGlow;
  final Color glowColor;

  _GemVectorPainter({
    required this.gradientColors,
    required this.showGlow,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Optional subtle outer glow
    if (showGlow) {
      final glowPaint = Paint()
        ..color = glowColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.25);
      canvas.drawCircle(Offset(w / 2, h / 2), w * 0.4, glowPaint);
    }

    final rect = Rect.fromLTWH(0, 0, w, h);
    final mainGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: gradientColors,
    );

    final fillPaint = Paint()
      ..shader = mainGradient.createShader(rect)
      ..style = PaintingStyle.fill;

    // Multi-faceted Gem path (Brilliant cut diamond outline)
    final path = Path();
    path.moveTo(w * 0.22, h * 0.18); // top-left shoulder
    path.lineTo(w * 0.78, h * 0.18); // top-right shoulder
    path.lineTo(w * 1.00, h * 0.42); // right tip
    path.lineTo(w * 0.50, h * 0.96); // bottom culet
    path.lineTo(w * 0.00, h * 0.42); // left tip
    path.close();

    canvas.drawPath(path, fillPaint);

    // Facet Highlight Overlay (Top Table Facet)
    final tablePath = Path();
    tablePath.moveTo(w * 0.32, h * 0.18);
    tablePath.lineTo(w * 0.68, h * 0.18);
    tablePath.lineTo(w * 0.60, h * 0.42);
    tablePath.lineTo(w * 0.40, h * 0.42);
    tablePath.close();

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.fill;
    canvas.drawPath(tablePath, highlightPaint);

    // Inner facet line strokes for crisp metallic/gem depth
    final strokePaint = Paint()
      ..color = Colors.white.withOpacity(0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.75, w * 0.04);

    // Table line
    canvas.drawLine(Offset(w * 0.00, h * 0.42), Offset(w * 1.00, h * 0.42), strokePaint);
    // Left facet seam
    canvas.drawLine(Offset(w * 0.40, h * 0.42), Offset(w * 0.50, h * 0.96), strokePaint);
    // Right facet seam
    canvas.drawLine(Offset(w * 0.60, h * 0.42), Offset(w * 0.50, h * 0.96), strokePaint);
    // Outer border stroke
    canvas.drawPath(path, strokePaint..color = Colors.white.withOpacity(0.20));
  }

  @override
  bool shouldRepaint(covariant _GemVectorPainter oldDelegate) {
    return oldDelegate.gradientColors != gradientColors ||
        oldDelegate.showGlow != showGlow ||
        oldDelegate.glowColor != glowColor;
  }
}

/// A row widget combining [GemIcon] with dynamic or compact gem count text.
class GemCounter extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final double iconSize;
  final bool isCompact;
  final MainAxisAlignment mainAxisAlignment;

  const GemCounter({
    super.key,
    required this.amount,
    this.style,
    this.iconSize = 14.0,
    this.isCompact = true,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final formattedText = isCompact
        ? formatCompactNumber(amount)
        : (amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(1));

    final textStyle = style ??
        TextStyle(
          color: const Color(0xFF00F2FE),
          fontSize: iconSize * 0.95,
          fontWeight: FontWeight.bold,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GemIcon(size: iconSize),
        SizedBox(width: iconSize * 0.25),
        Text(formattedText, style: textStyle),
      ],
    );
  }
}

/// A compact pill badge displaying a Gem icon and formatted amount.
class GemBadge extends StatelessWidget {
  final double amount;
  final double iconSize;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;

  const GemBadge({
    super.key,
    required this.amount,
    this.iconSize = 12.0,
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? const Color(0xFF00F2FE).withOpacity(0.12);
    final border = borderColor ?? const Color(0xFF00F2FE).withOpacity(0.30);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 0.8),
      ),
      child: GemCounter(
        amount: amount,
        iconSize: iconSize,
        style: textStyle ??
            TextStyle(
              color: const Color(0xFF00F2FE),
              fontSize: iconSize * 0.9,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
