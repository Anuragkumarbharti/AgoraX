import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CreaniaVpProgressBar extends StatelessWidget {
  final int roomLevel;
  final int freeXp;
  final int freeTarget;
  final int extraXp;
  final int extraTarget;
  final bool isGoldMember;
  final String? roomId;
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
    this.coverUrl,
    this.label = "Today' AP",
    this.onTap,
    this.onPlusTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double freeRatio = (freeXp / (freeTarget > 0 ? freeTarget : 700)).clamp(0.0, 1.0);
    final double extraRatio = (extraXp / (extraTarget > 0 ? extraTarget : 1000)).clamp(0.0, 1.0);

    final int totalEarned = freeXp + extraXp;
    final int totalTarget = freeTarget + (isGoldMember ? extraTarget : 0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Purple 3D Hexagon Room Level Badge (Far Left)
            _buildHexagonLevelBadge(roomLevel),
            const SizedBox(width: 8),

            // 2. Center Column: Header (Title & Numbers), Progress Bar, ID Row
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row: "Today' AP" on left, "1700/1700" on right
                SizedBox(
                  width: 120,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 10.0,
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
                                fontSize: 10.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: '/',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: '$totalTarget',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFFFB800),
                                fontSize: 10.0,
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

                // Dual Cyan & Gold Wave Progress Bar with Metallic Flare
                SizedBox(
                  width: 120,
                  height: 10.0,
                  child: CustomPaint(
                    size: const Size(120, 10.0),
                    painter: _CreaniaBarPainter(
                      freeRatio: freeRatio,
                      extraRatio: isGoldMember ? extraRatio : 0.0,
                      isGoldMember: isGoldMember,
                    ),
                  ),
                ),

                // Subtitle Row: ID: 88533076 • [Avatar Badge] (NO ROOM NAME)
                if (roomId != null && roomId!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ID: $roomId',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 9.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (coverUrl != null && coverUrl!.isNotEmpty) ...[
                        Text(
                          '  •  ',
                          style: GoogleFonts.poppins(
                            color: Colors.white38,
                            fontSize: 9.0,
                          ),
                        ),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFFB800), width: 1),
                            image: DecorationImage(
                              image: NetworkImage(coverUrl!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),

            const SizedBox(width: 8),

            // 3. Pink Plus (+) Button (Far Right)
            GestureDetector(
              onTap: onPlusTap,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF2D55), // Pink Accent
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66FF2D55),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 14),
              ),
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

class _CreaniaBarPainter extends CustomPainter {
  final double freeRatio;
  final double extraRatio;
  final bool isGoldMember;

  _CreaniaBarPainter({
    required this.freeRatio,
    required this.extraRatio,
    required this.isGoldMember,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    const double radius = 5.0;
    const double dividerPercent = 0.50; // 50/50 split matching image
    final double dividerX = width * dividerPercent;

    final Path framePath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        const Radius.circular(radius),
      ));

    // Dark Background Interior Track
    final Paint bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF030712), Color(0xFF0F172A), Color(0xFF030712)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawPath(framePath, bgPaint);

    canvas.save();
    canvas.clipPath(framePath);

    // 1. Left Half: Electric Cyan Wave Fill
    final double freeFillWidth = dividerX * freeRatio;
    if (freeFillWidth > 0) {
      final Rect freeRect = Rect.fromLTWH(0, 0, freeFillWidth, height);
      final Paint freePaint = Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF0284C7),
            Color(0xFF06B6D4),
            Color(0xFF38BDF8),
            Color(0xFF60EFFF),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(freeRect);
      canvas.drawRect(freeRect, freePaint);
    }

    // 2. Right Half: Gold Wave Fill
    if (extraRatio > 0 && isGoldMember) {
      final double goldSpan = (width - dividerX);
      final double goldFillWidth = goldSpan * extraRatio;
      final Rect goldRect = Rect.fromLTWH(dividerX, 0, goldFillWidth, height);
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
      canvas.drawRect(goldRect, goldPaint);
    }

    // Glossy Overlay Highlight
    final Path glossyPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, width, height * 0.45));
    final Paint glossyPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.25),
          Colors.white.withOpacity(0.05),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, width, height * 0.45));
    canvas.drawPath(glossyPath, glossyPaint);

    canvas.restore();

    // 3. Glowing Metallic Divider Line in Center
    final Paint glowDivider = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
    canvas.drawLine(Offset(dividerX, 0), Offset(dividerX, height), glowDivider);

    final Paint coreDivider = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(dividerX, 0), Offset(dividerX, height), coreDivider);

    // Outer Border Frame
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF38BDF8).withOpacity(0.5);
    canvas.drawPath(framePath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CreaniaBarPainter oldDelegate) {
    return oldDelegate.freeRatio != freeRatio ||
        oldDelegate.extraRatio != extraRatio ||
        oldDelegate.isGoldMember != isGoldMember;
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
