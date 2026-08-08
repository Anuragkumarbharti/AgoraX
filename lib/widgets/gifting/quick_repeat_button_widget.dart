import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/gifting/quick_repeat_controller.dart';
import '../../services/gifting/gift_animation_controller.dart';
import '../../services/user/user_profile_cache_manager.dart';

/// Floating circular Quick Repeat button shown bottom-right in voice rooms.
///
/// Layout:
///   ┌─────────────────────────────┐
///   │                             │
///   │   [Nₓ] ← count pill above  │
///   │  ╭──────────────╮           │
///   │  │  GIFT IMAGE  │           │
///   │  ╰──────────────╯           │
///   └─────────────────────────────┘
///
/// • Circular glass/neon ring with blue-purple glow (Creania theme).
/// • Count pill floats above-left of the circle.
/// • Tapping immediately repeats the last gift to the same recipients.
/// • Auto-hides after 12s inactivity; timer resets on every successful repeat.
class QuickRepeatButtonWidget extends StatefulWidget {
  final String roomId;
  final String currentUserId;

  const QuickRepeatButtonWidget({
    Key? key,
    required this.roomId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<QuickRepeatButtonWidget> createState() => _QuickRepeatButtonWidgetState();
}

class _QuickRepeatButtonWidgetState extends State<QuickRepeatButtonWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  Worker? _tapPulseWorker;
  Worker? _showcaseWorker;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutBack),
    );

    // Register ever() worker for tap pulse animation
    _tapPulseWorker = ever(QuickRepeatController.to.tapPulse, (bool pulse) {
      if (pulse && mounted) {
        _pulseController.forward(from: 0).then((_) {
          if (mounted) _pulseController.reverse();
        });
      }
    });
  }

  @override
  void dispose() {
    _tapPulseWorker?.dispose();
    _showcaseWorker?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Dispatches a local-only showcase animation event through the standard
  /// GiftAnimationController pipeline. The overlay combo counter accumulates
  /// (×1, ×2, ×3...) and the gift animation plays at full tier duration.
  /// Quick Repeat widget remains visible for the remaining 10s window.
  void _fireShowcaseAnimation(QuickRepeatState state) {
    final user = UserProfileCacheManager.currentUser;
    final senderName = user?.username ?? user?.fullName ?? 'Me';
    final eventId = 'qr_showcase_${DateTime.now().microsecondsSinceEpoch}';

    debugPrint('[QuickRepeat] Auto-showcase: ${state.giftName} after inactivity threshold.');

    GiftAnimationController.to.dispatchBroadcastGiftEvent({
      'id': eventId,
      'giftId': state.giftId,
      'giftName': state.giftName,
      'giftIcon': state.giftIcon,
      'senderId': state.senderId,
      'senderName': senderName,
      'receiverIds': state.recipientIds,
      'receiverNames': state.recipientNames,
      'seat_indices': state.seatIndices,
      'count': 1,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = QuickRepeatController.to;

    return Obx(() {
      if (!controller.isVisible(widget.roomId, widget.currentUserId)) {
        return const SizedBox.shrink();
      }

      final state = controller.activeState.value!;
      final isProcessing = controller.isProcessing.value;
      final progressVal = controller.progress.value;
      final remainingSecs = controller.remainingSeconds.value;

      // Fade out last 2 seconds
      final opacity = remainingSecs <= 2
          ? (remainingSecs / 2.0).clamp(0.3, 1.0)
          : 1.0;

      return AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 300),
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseScale.value,
              child: child,
            );
          },
          child: _buildCircleButton(
            state: state,
            isProcessing: isProcessing,
            progressVal: progressVal,
            controller: controller,
          ),
        ),
      );
    });
  }

  Widget _buildCircleButton({
    required QuickRepeatState state,
    required bool isProcessing,
    required double progressVal,
    required QuickRepeatController controller,
  }) {
    const double circleSize = 72.0;
    const double ringStroke = 3.0;
    const double imageSize = 48.0;

    return GestureDetector(
      onTap: isProcessing
          ? null
          : () => controller.repeatGift(widget.roomId),
      child: SizedBox(
        width: circleSize + 8,
        // Extra height above for the count pill
        height: circleSize + 32,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // ── CIRCULAR BUTTON (bottom) ──────────────────────────────────
            Positioned(
              bottom: 0,
              child: _GlowCircle(
                size: circleSize,
                ringStroke: ringStroke,
                progress: progressVal,
                isProcessing: isProcessing,
                child: _buildGiftImage(
                  assetPath: state.giftImageAssetPath,
                  icon: state.giftIcon,
                  size: imageSize,
                ),
              ),
            ),

            // ── COUNT PILL (above, aligned left-center of circle) ────────
            Positioned(
              top: 0,
              left: 0,
              child: Obx(() => _CountPill(count: state.currentQuantity.value)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftImage({
    required String assetPath,
    required String icon,
    required double size,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          // Fallback: large emoji if GIF not found
          return Center(
            child: Text(
              icon.isNotEmpty ? icon : '🎁',
              style: TextStyle(fontSize: size * 0.6),
              textAlign: TextAlign.center,
            ),
          );
        },
      ),
    );
  }
}

// ── Glowing Neon Circle ────────────────────────────────────────────────────

class _GlowCircle extends StatelessWidget {
  final double size;
  final double ringStroke;
  final double progress;
  final bool isProcessing;
  final Widget child;

  const _GlowCircle({
    required this.size,
    required this.ringStroke,
    required this.progress,
    required this.isProcessing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Determine ring color based on remaining progress
    final Color ringColor = progress > 0.4
        ? const Color(0xFF7C3AED)  // vibrant purple
        : progress > 0.15
            ? const Color(0xFF2563EB) // blue
            : const Color(0xFFEC4899); // warn pink at < 2s

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow shadow
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.55),
                  blurRadius: 18,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.35),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

          // Glass background circle
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFF1E1040),
                  Color(0xFF0D0821),
                ],
                center: Alignment(-0.3, -0.3),
                radius: 0.85,
              ),
              border: Border.all(
                color: const Color(0xFF7C3AED).withOpacity(0.6),
                width: 1.5,
              ),
            ),
          ),

          // Countdown arc ring (Custom Painter)
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _ArcRingPainter(
                progress: progress,
                color: ringColor,
                strokeWidth: ringStroke,
              ),
            ),
          ),

          // Processing spinner overlay
          if (isProcessing)
            SizedBox(
              width: size * 0.55,
              height: size * 0.55,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA78BFA)),
              ),
            ),

          // Gift image (inside circle)
          if (!isProcessing) child,
        ],
      ),
    );
  }
}

// ── Arc Ring Painter ──────────────────────────────────────────────────────

class _ArcRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  const _ArcRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background ring (dim)
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5);

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      rect,
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ── Count Pill ─────────────────────────────────────────────────────────────

class _CountPill extends StatelessWidget {
  final int count;

  const _CountPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: Container(
        key: ValueKey('qr_count_$count'),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.6),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
            width: 1.0,
          ),
        ),
        child: Text(
          '${count}×',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
