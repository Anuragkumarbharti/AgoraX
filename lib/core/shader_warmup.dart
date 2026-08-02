import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Eliminates first-frame shader compilation stutter by pre-drawing
/// the most expensive gradient, border, and clip combinations used
/// throughout the app (badges, avatar frames, room backgrounds, etc.).
///
/// Call [ShaderWarmup.warm] once inside the first frame via
/// [SchedulerBinding.addPostFrameCallback].
class AppShaderWarmup extends ShaderWarmUp {
  const AppShaderWarmup();

  @override
  double get canvasSize => 150.0;

  @override
  Future<void> warmUpOnCanvas(Canvas canvas) async {
    final paint = Paint()..isAntiAlias = true;

    // ── 1. Gradient pill (VIP / Novel badges) ───────────────────────
    final gradientPaints = [
      [const Color(0xFF2563EB), const Color(0xFF1E40AF)],   // VIP 1
      [const Color(0xFF7C3AED), const Color(0xFF4C1D95)],   // VIP 2
      [const Color(0xFFD97706), const Color(0xFF92400E)],   // VIP 3
      [const Color(0xFFDC2626), const Color(0xFF991B1B)],   // VIP 4
      [const Color(0xFF000000), const Color(0xFF1F2937)],   // VIP 5+
      [const Color(0xFF059669), const Color(0xFF065F46)],   // Novel
    ];

    for (final colors in gradientPaints) {
      paint.shader = LinearGradient(colors: colors).createShader(
        const Rect.fromLTWH(0, 0, 80, 19),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 80, 19),
          const Radius.circular(10),
        ),
        paint,
      );
    }

    // ── 2. Avatar circle clip (all seat avatars) ─────────────────────
    paint
      ..shader = null
      ..color = const Color(0xFF1D1F29);
    canvas.drawCircle(const Offset(48, 48), 48, paint);

    // ── 3. Rounded-rect card (room background, gift card) ────────────
    paint.color = const Color(0xFF16171F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 150, 100),
        const Radius.circular(20),
      ),
      paint,
    );

    // ── 4. Shine sweep gradient (badge animations) ───────────────────
    paint.shader = LinearGradient(
      colors: [
        Colors.white.withOpacity(0.0),
        Colors.white.withOpacity(0.4),
        Colors.white.withOpacity(0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(const Rect.fromLTWH(0, 0, 150, 30));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 150, 30), paint);

    // ── 5. Border stroke (identity tag borders) ──────────────────────
    paint
      ..shader = null
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 80, 19),
        const Radius.circular(10),
      ),
      paint,
    );
    paint.style = PaintingStyle.fill;
  }
}
