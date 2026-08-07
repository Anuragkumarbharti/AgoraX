import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/progression/room_dual_progress_model.dart';
import '../../services/room/room_dual_progress_controller.dart';

class StarMakerDualProgressBar extends StatefulWidget {
  final String roomId;
  final String? roomName;
  final int roomLevel;
  final String label;
  final double width;
  final VoidCallback? onTap;

  const StarMakerDualProgressBar({
    Key? key,
    required this.roomId,
    this.roomName,
    this.roomLevel = 1,
    this.label = "Dual AP",
    this.width = 160.0,
    this.onTap,
  }) : super(key: key);

  @override
  State<StarMakerDualProgressBar> createState() => _StarMakerDualProgressBarState();
}

class _StarMakerDualProgressBarState extends State<StarMakerDualProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Fetch initial dual progress
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.roomId.isNotEmpty) {
        final ctrl = Get.put(RoomDualProgressController());
        ctrl.fetchDualProgress(widget.roomId);
        ctrl.subscribeToRealtimeDualProgress(widget.roomId);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(RoomDualProgressController());

    return Obx(() {
      final dualProg = ctrl.getDualProgress(widget.roomId);
      final isOverflowing = ctrl.isOverflowing(widget.roomId);

      final double goldRatio = dualProg.goldRatio;
      final double normalRatio = dualProg.normalRatio;
      final int level = dualProg.roomLevel > widget.roomLevel ? dualProg.roomLevel : widget.roomLevel;

      final int totalEarned = dualProg.totalPoints;
      final int totalTarget = dualProg.totalTarget;

      return GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. 3D Purple/Gold Hexagon Level Badge
              _buildHexagonLevelBadge(level),
              const SizedBox(width: 6),

              // 2. Central Dual Progress Section
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Label & Points Ratio
                  SizedBox(
                    width: widget.width,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.label,
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 9.0,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            if (dualProg.isGoldFull) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'OVERFLOW ⚡',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black,
                                    fontSize: 6.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$totalEarned',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: '/',
                                style: GoogleFonts.poppins(
                                  color: Colors.white54,
                                  fontSize: 8.0,
                                ),
                              ),
                              TextSpan(
                                text: '$totalTarget',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFFB800),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Dual Progress Fluid Painter Bar (Height: 9.0px)
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return SizedBox(
                        width: widget.width,
                        height: 9.0,
                        child: CustomPaint(
                          size: Size(widget.width, 9.0),
                          painter: _StarMakerDualPainter(
                            goldRatio: goldRatio,
                            normalRatio: normalRatio,
                            isOverflowing: isOverflowing,
                            animValue: _animController.value,
                          ),
                        ),
                      );
                    },
                  ),

                  // Bottom Subtitle Row: Gold vs Normal breakdown
                  const SizedBox(height: 2),
                  SizedBox(
                    width: widget.width,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Gold: ${dualProg.goldPoints}/${dualProg.goldTarget}',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFFD700),
                            fontSize: 7.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Normal: ${dualProg.normalPoints}/${dualProg.normalTarget}',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF38BDF8),
                            fontSize: 7.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
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
            painter: _DualHexagonPainter(),
          ),
          Positioned(
            top: 3.5,
            child: Text(
              '$level',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(0, 1))
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarMakerDualPainter extends CustomPainter {
  final double goldRatio;
  final double normalRatio;
  final bool isOverflowing;
  final double animValue;

  _StarMakerDualPainter({
    required this.goldRatio,
    required this.normalRatio,
    required this.isOverflowing,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double radius = height / 2.0;

    // Dual Bar Splits: 45% Gold Track, 55% Normal Track
    final double goldBarWidth = width * 0.45;
    final double gap = 4.0;
    final double normalBarWidth = width * 0.55 - gap;
    final double normalBarStartX = goldBarWidth + gap;

    final double phase = animValue * 2 * math.pi;

    // ──────────────────────────────────────────────
    // 1. DRAW GOLD PROGRESS TRACK (PREMIUM TRACK)
    // ──────────────────────────────────────────────
    final RRect goldCapsuleRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, goldBarWidth, height),
      Radius.circular(radius),
    );
    final Path goldCapsulePath = Path()..addRRect(goldCapsuleRRect);

    // Track Background (Dark Gold Tinted Glass)
    final Paint goldBgPaint = Paint()..color = const Color(0xFF1E1702).withValues(alpha: 0.7);
    canvas.drawPath(goldCapsulePath, goldBgPaint);

    canvas.save();
    canvas.clipPath(goldCapsulePath);

    final double goldFillWidth = goldBarWidth * goldRatio;
    if (goldFillWidth > 0) {
      final Path goldWavePath = Path()..moveTo(0, height);
      const int steps = 24;
      final double stepW = goldFillWidth / steps;
      final double waveBaseY = height * 0.30;
      final double amplitude = height * 0.18;

      double getWaveY(double x) {
        final double angle = (x / goldBarWidth) * 3 * math.pi + phase;
        return (waveBaseY + math.sin(angle) * amplitude).clamp(0.0, height);
      }

      goldWavePath.lineTo(0, getWaveY(0));
      for (int i = 0; i <= steps; i++) {
        final double x = i * stepW;
        goldWavePath.lineTo(x, getWaveY(x));
      }
      goldWavePath.lineTo(goldFillWidth, height);
      goldWavePath.close();

      // Liquid Gold Metallic Shader
      final Paint goldLiquidPaint = Paint()
        ..shader = LinearGradient(
          colors: const [
            Color(0xFFB7791F),
            Color(0xFFD69E2E),
            Color(0xFFFFD700),
            Color(0xFFFFF176),
            Color(0xFFFBBF24),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromLTWH(0, 0, goldFillWidth, height));

      canvas.drawPath(goldWavePath, goldLiquidPaint);

      // Gold Sparkle Top Crest
      final Path goldCrest = Path();
      for (int i = 0; i <= steps; i++) {
        final double x = i * stepW;
        final double y = getWaveY(x);
        if (i == 0) goldCrest.moveTo(x, y); else goldCrest.lineTo(x, y);
      }
      final Paint crestPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFFFFFDE7);
      canvas.drawPath(goldCrest, crestPaint);
    }

    canvas.restore();

    // Metallic Gold Outer Rim Border
    final Paint goldRimBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = const LinearGradient(
        colors: [Color(0xFFFBBF24), Color(0xFFFFD700), Color(0xFFB7791F)],
      ).createShader(Rect.fromLTWH(0, 0, goldBarWidth, height));
    canvas.drawPath(goldCapsulePath, goldRimBorder);

    // ──────────────────────────────────────────────
    // 2. DRAW NORMAL PROGRESS TRACK (FREE TRACK)
    // ──────────────────────────────────────────────
    final RRect normalCapsuleRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(normalBarStartX, 0, normalBarWidth, height),
      Radius.circular(radius),
    );
    final Path normalCapsulePath = Path()..addRRect(normalCapsuleRRect);

    // Track Background (Dark Cyan Tinted Glass)
    final Paint normalBgPaint = Paint()..color = const Color(0xFF031926).withValues(alpha: 0.7);
    canvas.drawPath(normalCapsulePath, normalBgPaint);

    canvas.save();
    canvas.clipPath(normalCapsulePath);

    final double normalFillWidth = normalBarWidth * normalRatio;
    if (normalFillWidth > 0) {
      final Path normalWavePath = Path()..moveTo(normalBarStartX, height);
      const int steps = 24;
      final double stepW = normalFillWidth / steps;
      final double waveBaseY = height * 0.30;
      final double amplitude = height * 0.18;

      double getWaveY(double x) {
        final double angle = (x / normalBarWidth) * 3 * math.pi + phase + 1.0;
        return (waveBaseY + math.sin(angle) * amplitude).clamp(0.0, height);
      }

      normalWavePath.lineTo(normalBarStartX, getWaveY(normalBarStartX));
      for (int i = 0; i <= steps; i++) {
        final double x = normalBarStartX + i * stepW;
        normalWavePath.lineTo(x, getWaveY(x));
      }
      normalWavePath.lineTo(normalBarStartX + normalFillWidth, height);
      normalWavePath.close();

      // Liquid Cyan/Indigo Shader
      final Paint normalLiquidPaint = Paint()
        ..shader = LinearGradient(
          colors: const [
            Color(0xFF0052D4),
            Color(0xFF0072FF),
            Color(0xFF00C6FF),
            Color(0xFF38BDF8),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromLTWH(normalBarStartX, 0, normalFillWidth, height));

      canvas.drawPath(normalWavePath, normalLiquidPaint);
    }

    canvas.restore();

    // Metallic Cyan Outer Rim Border
    final Paint normalRimBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = const LinearGradient(
        colors: [Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFF60EFFF)],
      ).createShader(Rect.fromLTWH(normalBarStartX, 0, normalBarWidth, height));
    canvas.drawPath(normalCapsulePath, normalRimBorder);

    // ──────────────────────────────────────────────
    // 3. OVERFLOW LIQUID STREAM BEAM ANIMATION
    // ──────────────────────────────────────────────
    if (goldRatio >= 1.0 || isOverflowing) {
      final double beamStartX = goldBarWidth - 2.0;
      final double beamEndX = normalBarStartX + 2.0;
      final double beamCenterY = height / 2.0;

      // Pulsing Flow Energy Beam Connecting Gold Bar -> Normal Bar
      final double beamPulse = (math.sin(phase * 2) + 1.0) / 2.0; // 0.0 to 1.0
      final Paint energyBeamPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.9),
            const Color(0xFFFFA500).withValues(alpha: 0.9),
            const Color(0xFF38BDF8).withValues(alpha: 0.9),
          ],
        ).createShader(Rect.fromLTRB(beamStartX, 0, beamEndX, height))
        ..strokeWidth = 2.0 + beamPulse * 1.5
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0);

      canvas.drawLine(
        Offset(beamStartX, beamCenterY),
        Offset(beamEndX, beamCenterY),
        energyBeamPaint,
      );

      // Flowing Micro Particles (Gold -> Normal direction)
      final Paint particlePaint = Paint()..color = const Color(0xFFFFF176);
      for (int p = 0; p < 3; p++) {
        final double particleProgress = ((animValue + (p * 0.33)) % 1.0);
        final double px = beamStartX + (beamEndX - beamStartX) * particleProgress;
        final double py = beamCenterY + math.sin(phase + p) * 1.0;
        canvas.drawCircle(Offset(px, py), 1.2, particlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarMakerDualPainter oldDelegate) {
    return oldDelegate.goldRatio != goldRatio ||
        oldDelegate.normalRatio != normalRatio ||
        oldDelegate.isOverflowing != isOverflowing ||
        oldDelegate.animValue != animValue;
  }
}

class _DualHexagonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Green Wings
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
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(greenRibbonLeft, greenPaint);
    canvas.drawPath(greenRibbonRight, greenPaint);

    // Purple Hexagon Body
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
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(hexPath, hexFill);

    final Paint hexBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFA78BFA), Color(0xFF60EFFF)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(hexPath, hexBorder);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
