import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/room/room_dual_progress_controller.dart';
import '../../models/progression/room_dual_progress_model.dart';

class CreaniaVpProgressBar extends StatefulWidget {
  final int roomLevel;
  final int freeXp;
  final int freeTarget;
  final int extraXp;
  final int extraTarget;
  final bool isGoldMember;
  final String? roomId;
  final String? roomName;
  final String? coverUrl;
  final String label;
  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onPlusTap;

  const CreaniaVpProgressBar({
    Key? key,
    this.roomLevel = 1,
    this.freeXp = 0,
    this.freeTarget = 700,
    this.extraXp = 0,
    this.extraTarget = 1000,
    this.isGoldMember = true,
    this.roomId,
    this.roomName,
    this.coverUrl,
    this.label = "Today AP",
    this.width = 110.0,
    this.onTap,
    this.onPlusTap,
  }) : super(key: key);

  @override
  State<CreaniaVpProgressBar> createState() => _CreaniaVpProgressBarState();
}

class _CreaniaVpProgressBarState extends State<CreaniaVpProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatNumber(int num) {
    return '$num';
  }

  @override
  Widget build(BuildContext context) {
    final String rId = widget.roomId ?? '';
    if (rId.isEmpty) {
      return _buildContent(null);
    }

    return Obx(() {
      final dualCtrl = RoomDualProgressController.to;
      final int _ = dualCtrl.dualProgresses.length;
      final RoomDualProgress? dualModel = dualCtrl.dualProgresses[rId];
      return _buildContent(dualModel);
    });
  }

  Widget _buildContent(RoomDualProgress? dualModel) {
    final int freeVal =
        dualModel != null ? dualModel.normalPoints : widget.freeXp;
    final int freeTargetLimit = dualModel != null
        ? dualModel.normalTarget
        : (widget.freeTarget > 0 ? widget.freeTarget : 700);

    final int extraVal =
        dualModel != null ? dualModel.goldPoints : widget.extraXp;
    final int extraTargetLimit = dualModel != null
        ? dualModel.goldTarget
        : (widget.extraTarget > 0 ? widget.extraTarget : 1000);

    final double freeRatio = (freeVal / freeTargetLimit).clamp(0.0, 1.0);
    final double extraRatio = (extraVal / extraTargetLimit).clamp(0.0, 1.0);

    final int totalEarned = freeVal + extraVal;
    final int totalTarget = freeTargetLimit + extraTargetLimit;

    final String earnedStr = _formatNumber(totalEarned);
    final String targetStr = _formatNumber(totalTarget);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildHexagonLevelBadge(
                dualModel != null ? dualModel.roomLevel : widget.roomLevel),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: widget.width,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.label,
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: earnedStr,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: '/',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 8.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: targetStr,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFFB800),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return SizedBox(
                      width: widget.width,
                      height: 7.0,
                      child: CustomPaint(
                        size: Size(widget.width, 7.0),
                        painter: _LiquidProgressBarPainter(
                          freeRatio: freeRatio,
                          extraRatio: extraRatio,
                          isGoldMember: widget.isGoldMember,
                          animValue: _animController.value,
                        ),
                      ),
                    );
                  },
                ),
                _buildSubtitleRow(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleRow() {
    if (widget.roomName == null || widget.roomName!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 3.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 100),
        child: Text(
          widget.roomName!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHexagonLevelBadge(int level) {
    return SizedBox(
      width: 24,
      height: 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(24, 26),
            painter: _HexagonBadgePainter(),
          ),
          Positioned(
            top: 3.0,
            child: Text(
              '$level',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 11.0,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(
                      color: Colors.black87,
                      blurRadius: 3,
                      offset: Offset(0, 1))
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidProgressBarPainter extends CustomPainter {
  final double freeRatio;
  final double extraRatio;
  final bool isGoldMember;
  final double animValue;

  _LiquidProgressBarPainter({
    required this.freeRatio,
    required this.extraRatio,
    required this.isGoldMember,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double radius = height / 2.0; // Fully pill rounded
    const double dividerPercent = 0.50;
    final double dividerX = width * dividerPercent;
    final double phase = animValue * 2 * math.pi;

    final RRect capsuleRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      Radius.circular(radius),
    );
    final Path capsulePath = Path()..addRRect(capsuleRRect);

    // 1. Translucent Low-Opacity Glass Background Tube ("opisity thoda kam")
    final Paint bgGlassPaint = Paint()
      ..color = const Color(0xFF030712).withValues(alpha: 0.35);
    canvas.drawPath(capsulePath, bgGlassPaint);

    // Inner shadow track for glass tube feel
    final Paint innerShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(capsulePath, innerShadowPaint);

    canvas.save();
    canvas.clipPath(capsulePath);

    // 1. Calculate liquid fill widths for Free AP (left 50%) and Gold XP (right 50%)
    final double freeFillWidth = (dividerX * freeRatio).clamp(0.0, dividerX);
    final double extraFillWidth = ((width - dividerX) * extraRatio).clamp(0.0, width - dividerX);

    // Render Free AP Liquid (Cyan/Blue on Left 50%)
    if (freeFillWidth > 0) {
      final Path freeWavePath = Path()..moveTo(0, height);
      const int steps = 24;
      final double stepWidth = freeFillWidth / steps;
      final double waveBaseY = height * 0.32;
      final double amplitude = height * 0.20;

      double getWaveY(double x) {
        final double waveAngle = (x / width) * 3 * math.pi + phase;
        return (waveBaseY + math.sin(waveAngle) * amplitude).clamp(0.0, height);
      }

      freeWavePath.lineTo(0, getWaveY(0));
      for (int i = 0; i <= steps; i++) {
        final double x = i * stepWidth;
        freeWavePath.lineTo(x, getWaveY(x));
      }
      freeWavePath.lineTo(freeFillWidth, height);
      freeWavePath.close();

      final Rect freeRect = Rect.fromLTWH(0, 0, freeFillWidth, height);
      final Paint freePaint = Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF0052D4),
            Color(0xFF0072FF),
            Color(0xFF00C6FF),
            Color(0xFF38BDF8),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(freeRect);

      canvas.drawPath(freeWavePath, freePaint);
    }

    // Render Gold XP Liquid (Gold/Amber on Right 50%)
    if (extraFillWidth > 0) {
      final Path goldWavePath = Path()..moveTo(dividerX, height);
      const int steps = 24;
      final double stepWidth = extraFillWidth / steps;
      final double waveBaseY = height * 0.32;
      final double amplitude = height * 0.20;

      double getWaveY(double x) {
        final double waveAngle = (x / width) * 3 * math.pi + phase;
        return (waveBaseY + math.sin(waveAngle) * amplitude).clamp(0.0, height);
      }

      goldWavePath.lineTo(dividerX, getWaveY(dividerX));
      for (int i = 0; i <= steps; i++) {
        final double x = dividerX + (i * stepWidth);
        goldWavePath.lineTo(x, getWaveY(x));
      }
      goldWavePath.lineTo(dividerX + extraFillWidth, height);
      goldWavePath.close();

      final Rect goldRect = Rect.fromLTWH(dividerX, 0, extraFillWidth, height);
      final Paint goldPaint = Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFD97706),
            Color(0xFFF59E0B),
            Color(0xFFFFB800),
            Color(0xFFFFF176),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(goldRect);

      canvas.drawPath(goldWavePath, goldPaint);
    }

    // Glossy Upper Glass Reflection Highlight (Glass Capsule reflection)
    final Path glossyPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, width, height * 0.40));
    final Paint glossyPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.30),
          Colors.white.withValues(alpha: 0.05),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, width, height * 0.40));
    canvas.drawPath(glossyPath, glossyPaint);

    canvas.restore();

    // Glowing Central BLEND POINT Vertical Seam (Subtle indicator without breaking liquid)
    final Paint glowDivider = Paint()
      ..color = Colors.white.withValues(alpha: 0.50)
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.5);
    canvas.drawLine(Offset(dividerX, 0), Offset(dividerX, height), glowDivider);

    // Glowing Blend Point top indicator dot
    final Paint blendPointDotGlow = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0);
    canvas.drawCircle(Offset(dividerX, 0.5), 1.6, blendPointDotGlow);

    final Paint blendPointDot = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(dividerX, 0.5), 0.9, blendPointDot);

    // Sleek Outer Metallic Rim Glass Border
    final Paint glassRimBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF38BDF8),
          Color(0xFF818CF8),
          Color(0xFFFBBF24),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawPath(capsulePath, glassRimBorder);
  }

  @override
  bool shouldRepaint(covariant _LiquidProgressBarPainter oldDelegate) {
    return oldDelegate.freeRatio != freeRatio ||
        oldDelegate.extraRatio != extraRatio ||
        oldDelegate.isGoldMember != isGoldMember ||
        oldDelegate.animValue != animValue;
  }
}

class _HexagonBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Green Ribbon Wings at Bottom
    final Path greenRibbonLeft = Path()
      ..moveTo(w * 0.2, h * 0.65)
      ..lineTo(0, h * 0.88)
      ..lineTo(w * 0.28, h * 0.82)
      ..lineTo(w * 0.38, h * 0.95)
      ..lineTo(w * 0.45, h * 0.75)
      ..close();

    final Path greenRibbonRight = Path()
      ..moveTo(w * 0.8, h * 0.65)
      ..lineTo(w, h * 0.88)
      ..lineTo(w * 0.72, h * 0.82)
      ..lineTo(w * 0.62, h * 0.95)
      ..lineTo(w * 0.55, h * 0.75)
      ..close();

    final Paint greenPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF047857)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(greenRibbonLeft, greenPaint);
    canvas.drawPath(greenRibbonRight, greenPaint);

    // Purple 3D Hexagon Frame
    final Path hexPath = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.96, h * 0.22)
      ..lineTo(w * 0.96, h * 0.65)
      ..lineTo(w * 0.5, h * 0.87)
      ..lineTo(w * 0.04, h * 0.65)
      ..lineTo(w * 0.04, h * 0.22)
      ..close();

    final Paint hexFill = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9), Color(0xFF4C1D95)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(hexPath, hexFill);

    final Paint hexBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..shader = const LinearGradient(
        colors: [Color(0xFFDDD6FE), Color(0xFFA78BFA), Color(0xFF60EFFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(hexPath, hexBorder);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
