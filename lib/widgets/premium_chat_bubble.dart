import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BubblePainter extends CustomPainter {
  final bool isMe;
  final List<Color> colors;
  final Color shadowColor;
  final double radius;

  BubblePainter({
    required this.isMe,
    required this.colors,
    this.shadowColor = Colors.black45,
    this.radius = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0)
      ..style = PaintingStyle.fill;

    final path = Path();
    if (isMe) {
      path.moveTo(radius, 0);
      path.lineTo(size.width - radius, 0);
      path.arcToPoint(Offset(size.width - 4, 4), radius: Radius.circular(radius));
      path.lineTo(size.width - 4, size.height - radius);
      
      // Curved social media tail on the right
      path.quadraticBezierTo(size.width - 4, size.height - 2, size.width + 2, size.height);
      path.quadraticBezierTo(size.width - 4, size.height, size.width - 10, size.height);
      
      path.lineTo(radius, size.height);
      path.arcToPoint(Offset(0, size.height - radius), radius: Radius.circular(radius));
      path.lineTo(0, radius);
      path.arcToPoint(Offset(radius, 0), radius: Radius.circular(radius));
    } else {
      path.moveTo(radius + 4, 0);
      path.lineTo(size.width - radius, 0);
      path.arcToPoint(Offset(size.width, radius), radius: Radius.circular(radius));
      path.lineTo(size.width, size.height - radius);
      path.arcToPoint(Offset(size.width - radius, size.height), radius: Radius.circular(radius));
      path.lineTo(10, size.height);
      
      // Curved social media tail on the left
      path.quadraticBezierTo(4, size.height, -2, size.height);
      path.quadraticBezierTo(4, size.height - 2, 4, size.height - radius);
      
      path.lineTo(4, radius);
      path.arcToPoint(Offset(radius + 4, 0), radius: Radius.circular(radius));
    }

    // Draw shadow first
    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);
    // Draw bubble
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PremiumChatBubble extends StatefulWidget {
  final Widget child;
  final bool isMe;
  final String theme; // Default, VIP, Novel, Luxury, Event, Official
  final bool isSending;
  final bool isDeleted;

  const PremiumChatBubble({
    Key? key,
    required this.child,
    required this.isMe,
    this.theme = 'Default',
    this.isSending = false,
    this.isDeleted = false,
  }) : super(key: key);

  @override
  State<PremiumChatBubble> createState() => _PremiumChatBubbleState();
}

class _PremiumChatBubbleState extends State<PremiumChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _appearController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _appearController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _appearController, curve: Curves.easeOutBack),
    );
    _appearController.forward();
  }

  @override
  void dispose() {
    _appearController.dispose();
    super.dispose();
  }

  List<Color> _getBubbleColors() {
    if (widget.isDeleted) {
      return [Colors.grey.shade900, const Color(0xFF0C0A09)];
    }

    switch (widget.theme) {
      case 'VIP':
        return [const Color(0xFFFFD700), const Color(0xFFD97706)];
      case 'Novel':
        return [const Color(0xFF8B5CF6), const Color(0xFFD946EF)];
      case 'Luxury':
        return [const Color(0xFF10B981), const Color(0xFF047857)];
      case 'Event':
        return [const Color(0xFFEF4444), const Color(0xFFF97316)];
      case 'Official':
        return [const Color(0xFF1E293B), const Color(0xFF0F172A)];
      case 'Default':
      default:
        return widget.isMe
            ? [const Color(0xFF6366F1), const Color(0xFF4F46E5)] // Indigo gradient
            : [const Color(0xFF334155), const Color(0xFF1E293B)]; // Dark slate
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getBubbleColors();
    final isSpecialTheme = widget.theme != 'Default' && !widget.isDeleted;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: widget.isSending ? 0.7 : 1.0,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: CustomPaint(
            painter: BubblePainter(
              isMe: widget.isMe,
              colors: colors,
              shadowColor: isSpecialTheme
                  ? colors[0].withOpacity(0.35)
                  : Colors.black38,
            ),
            child: Container(
              padding: EdgeInsets.only(
                left: widget.isMe ? 14 : 18,
                right: widget.isMe ? 18 : 14,
                top: 10,
                bottom: 10,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
