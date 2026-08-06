import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  final VoidCallback? onTap;
  final VoidCallback? onPlusTap;

  const CreaniaVpProgressBar({
    Key? key,
    this.roomLevel = 1,
    this.freeXp = 700,
    this.freeTarget = 700,
    this.extraXp = 1000,
    this.extraTarget = 1000,
    this.isGoldMember = true,
    this.roomId,
    this.roomName,
    this.coverUrl,
    this.label = "Today' AP",
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

  @override
  Widget build(BuildContext context) {
    final double freeRatio =
        (widget.freeXp / (widget.freeTarget > 0 ? widget.freeTarget : 700))
            .clamp(0.0, 1.0);
    final double extraRatio =
        (widget.extraXp / (widget.extraTarget > 0 ? widget.extraTarget : 1000))
            .clamp(0.0, 1.0);

    final int totalEarned = widget.freeXp + widget.extraXp;
    final int totalTarget =
        widget.freeTarget + (widget.isGoldMember ? widget.extraTarget : 0);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Purple 3D Hexagon Room Level Badge (Far Left)
            _buildHexagonLevelBadge(widget.roomLevel),
            const SizedBox(width: 8),

            // 2. Center Column: Header (Title & Numbers), Liquid Progress Bar, Subtitle Row
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row: "Today' AP" on left, "1700/1700" on right
                SizedBox(
                  width: 124,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.label,
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$totalEarned',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: '/',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 9.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: '$totalTarget',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFFFB800),
                                fontSize: 9.5,
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

                // Animated Liquid Fluid Glass Progress Bar (Slim height: 7.0px, Low opacity)
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return SizedBox(
                      width: 124,
                      height: 7.0,
                      child: CustomPaint(
                        size: const Size(124, 7.0),
                        painter: _LiquidProgressBarPainter(
                          freeRatio: freeRatio,
                          extraRatio: widget.isGoldMember ? extraRatio : 0.0,
                          isGoldMember: widget.isGoldMember,
                          animValue: _animController.value,
                        ),
                      ),
                    );
                  },
                ),

                // Subtitle Row: ID: 88533076 • roomName
                if (widget.roomId != null && widget.roomId!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ID: ${widget.roomId}',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (widget.roomName != null &&
                          widget.roomName!.isNotEmpty) ...[
                        Text(
                          '  •  ',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 8.5,
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 62),
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
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ],
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

    // 2. Left Half Liquid Fluid Wave (Electric Cyan/Blue)
    final double freeFillWidth = dividerX * freeRatio;
    if (freeFillWidth > 0) {
      final Path wavePath = Path();
      wavePath.moveTo(0, height);

      const int waveSteps = 24;
      final double stepWidth = freeFillWidth / waveSteps;
      final double waveBaseY = height * 0.30;
      final double amplitude = height * 0.22;

      final double startY = waveBaseY + math.sin(phase) * amplitude;
      wavePath.lineTo(0, startY);

      for (int i = 0; i <= waveSteps; i++) {
        final double x = i * stepWidth;
        final double waveAngle = (x / width) * 4 * math.pi + phase;
        final double y =
            (waveBaseY + math.sin(waveAngle) * amplitude).clamp(0.0, height);
        wavePath.lineTo(x, y);
      }

      wavePath.lineTo(freeFillWidth, height);
      wavePath.close();

      // Liquid Gradient Fill
      final Rect freeRect = Rect.fromLTWH(0, 0, freeFillWidth, height);
      final Paint cyanLiquidPaint = Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF0052D4),
            Color(0xFF0072FF),
            Color(0xFF00C6FF),
            Color(0xFF6FB1FC),
          ],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ).createShader(freeRect);
      canvas.drawPath(wavePath, cyanLiquidPaint);

      // Glowing liquid crest line (Highlight top edge of wave)
      final Path crestPath = Path();
      for (int i = 0; i <= waveSteps; i++) {
        final double x = i * stepWidth;
        final double waveAngle = (x / width) * 4 * math.pi + phase;
        final double y =
            (waveBaseY + math.sin(waveAngle) * amplitude).clamp(0.0, height);
        if (i == 0) {
          crestPath.moveTo(x, y);
        } else {
          crestPath.lineTo(x, y);
        }
      }
      final Paint cyanCrestPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFFE0F7FA).withValues(alpha: 0.95);
      canvas.drawPath(crestPath, cyanCrestPaint);

      // Micro floating liquid bubbles in cyan section
      final Paint bubblePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill;
      final double b1X =
          (freeFillWidth * 0.3 + math.sin(phase) * 4).clamp(1.0, freeFillWidth - 1);
      final double b1Y = height * 0.6 + math.cos(phase) * 1.5;
      canvas.drawCircle(Offset(b1X, b1Y), 0.8, bubblePaint);

      final double b2X =
          (freeFillWidth * 0.7 + math.cos(phase * 1.3) * 5).clamp(1.0, freeFillWidth - 1);
      final double b2Y = height * 0.5 + math.sin(phase * 1.3) * 1.2;
      canvas.drawCircle(Offset(b2X, b2Y), 0.6, bubblePaint);
    }

    // 3. Right Half Liquid Fluid Wave (Gold/Amber)
    if (extraRatio > 0 && isGoldMember) {
      final double goldSpan = (width - dividerX);
      final double goldFillWidth = goldSpan * extraRatio;
      final double startGoldX = dividerX;
      final double endGoldX = dividerX + goldFillWidth;

      final Path goldWavePath = Path();
      goldWavePath.moveTo(startGoldX, height);

      const int waveSteps = 24;
      final double stepWidth = goldFillWidth / waveSteps;
      final double waveBaseY = height * 0.30;
      final double amplitude = height * 0.22;

      // Inverse phase shift for dynamic multi-liquid flow effect
      final double goldPhase = phase + math.pi / 2;

      for (int i = 0; i <= waveSteps; i++) {
        final double x = startGoldX + i * stepWidth;
        final double waveAngle = (x / width) * 4 * math.pi + goldPhase;
        final double y =
            (waveBaseY + math.cos(waveAngle) * amplitude).clamp(0.0, height);
        if (i == 0) {
          goldWavePath.lineTo(startGoldX, y);
        }
        goldWavePath.lineTo(x, y);
      }

      goldWavePath.lineTo(endGoldX, height);
      goldWavePath.close();

      // Gold Liquid Gradient Fill
      final Rect goldRect = Rect.fromLTWH(dividerX, 0, goldFillWidth, height);
      final Paint goldLiquidPaint = Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFB45309),
            Color(0xFFD97706),
            Color(0xFFF59E0B),
            Color(0xFFFFD700),
          ],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ).createShader(goldRect);
      canvas.drawPath(goldWavePath, goldLiquidPaint);

      // Glowing gold liquid crest line
      final Path goldCrestPath = Path();
      for (int i = 0; i <= waveSteps; i++) {
        final double x = startGoldX + i * stepWidth;
        final double waveAngle = (x / width) * 4 * math.pi + goldPhase;
        final double y =
            (waveBaseY + math.cos(waveAngle) * amplitude).clamp(0.0, height);
        if (i == 0) {
          goldCrestPath.moveTo(x, y);
        } else {
          goldCrestPath.lineTo(x, y);
        }
      }
      final Paint goldCrestPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFFFFFDE7).withValues(alpha: 0.95);
      canvas.drawPath(goldCrestPath, goldCrestPaint);

      // Micro floating liquid bubbles in gold section
      final Paint goldBubblePaint = Paint()
        ..color = const Color(0xFFFFF59D).withValues(alpha: 0.7)
        ..style = PaintingStyle.fill;
      final double gb1X =
          (startGoldX + goldFillWidth * 0.4 + math.cos(goldPhase) * 3).clamp(startGoldX, endGoldX);
      final double gb1Y = height * 0.55 + math.sin(goldPhase) * 1.5;
      canvas.drawCircle(Offset(gb1X, gb1Y), 0.7, goldBubblePaint);
    }

    // 4. Glossy Upper Glass Reflection Highlight (Glass Capsule reflection)
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

    // 5. Glowing Central BLEND POINT Vertical Divider
    final Paint glowDivider = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.8
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0);
    canvas.drawLine(Offset(dividerX, 0), Offset(dividerX, height), glowDivider);

    final Paint coreDivider = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(dividerX, 0), Offset(dividerX, height), coreDivider);

    // Glowing Blend Point top indicator dot (matching Image 2 "BLEND POINT")
    final Paint blendPointDotGlow = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0);
    canvas.drawCircle(Offset(dividerX, 0.5), 1.8, blendPointDotGlow);

    final Paint blendPointDot = Paint()
      ..color = Colors.white;
    canvas.drawCircle(Offset(dividerX, 0.5), 1.0, blendPointDot);

    // 6. Sleek Outer Metallic Rim Glass Border
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
