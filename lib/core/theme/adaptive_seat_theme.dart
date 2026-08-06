import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/room/room_background_model.dart';
import '../theme.dart';

/// Immutable design tokens for seat components in voice rooms.
class AdaptiveSeatThemeTokens {
  final bool isLightBackground;
  final Color seatBorderColor;
  final Color seatFillColor;
  final Color seatGlowColor;
  final double seatGlowRadius;
  final double seatBorderWidth;
  final Color lockIconColor;
  final Color emptySeatIconColor;
  final Color speakingRingColor;
  final Color speakingGlowColor;
  final Color usernameColor;
  final List<Shadow> usernameShadows;
  final Color starIconColor;
  final Color starTextColor;
  final Color micOffBadgeBg;
  final Color micOffIconColor;
  final double glassBlurSigma;
  final List<BoxShadow> seatBoxShadows;

  const AdaptiveSeatThemeTokens({
    required this.isLightBackground,
    required this.seatBorderColor,
    required this.seatFillColor,
    required this.seatGlowColor,
    required this.seatGlowRadius,
    required this.seatBorderWidth,
    required this.lockIconColor,
    required this.emptySeatIconColor,
    required this.speakingRingColor,
    required this.speakingGlowColor,
    required this.usernameColor,
    required this.usernameShadows,
    required this.starIconColor,
    required this.starTextColor,
    required this.micOffBadgeBg,
    required this.micOffIconColor,
    required this.glassBlurSigma,
    required this.seatBoxShadows,
  });

  /// Dark mode fallback seat theme tokens.
  factory AdaptiveSeatThemeTokens.darkFallback({Color? lockedAccent}) {
    final accent = lockedAccent ?? AppTheme.darkAccentPurple;
    return AdaptiveSeatThemeTokens(
      isLightBackground: false,
      seatBorderColor: accent.withOpacity(0.60),
      seatFillColor: Colors.white.withOpacity(0.08),
      seatGlowColor: accent.withOpacity(0.25),
      seatGlowRadius: 6.0,
      seatBorderWidth: 1.5,
      lockIconColor: accent.withOpacity(0.85),
      emptySeatIconColor: Colors.white24,
      speakingRingColor: const Color(0xFF22C55E),
      speakingGlowColor: const Color(0xFF22C55E).withOpacity(0.40),
      usernameColor: Colors.white,
      usernameShadows: const [
        Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
      ],
      starIconColor: const Color(0xFFFBBF24),
      starTextColor: Colors.white70,
      micOffBadgeBg: const Color(0xFF0F172A).withOpacity(0.85),
      micOffIconColor: const Color(0xFFF87171),
      glassBlurSigma: 8.0,
      seatBoxShadows: [
        BoxShadow(
          color: accent.withOpacity(0.20),
          blurRadius: 8.0,
          spreadRadius: 1.0,
        ),
      ],
    );
  }

  /// Light mode fallback seat theme tokens.
  factory AdaptiveSeatThemeTokens.lightFallback({Color? lockedAccent}) {
    final accent = lockedAccent ?? AppTheme.lightAccentPurple;
    return AdaptiveSeatThemeTokens(
      isLightBackground: true,
      seatBorderColor: const Color(0xFF1E293B).withOpacity(0.45),
      seatFillColor: const Color(0xFF0F172A).withOpacity(0.08),
      seatGlowColor: accent.withOpacity(0.12),
      seatGlowRadius: 2.0,
      seatBorderWidth: 1.5,
      lockIconColor: accent.withOpacity(0.90),
      emptySeatIconColor: const Color(0xFF334155).withOpacity(0.65),
      speakingRingColor: const Color(0xFF16A34A),
      speakingGlowColor: const Color(0xFF16A34A).withOpacity(0.25),
      usernameColor: const Color(0xFF0F172A),
      usernameShadows: const [
        Shadow(color: Colors.white70, blurRadius: 4, offset: Offset(0, 1)),
      ],
      starIconColor: const Color(0xFFD97706),
      starTextColor: const Color(0xFF334155),
      micOffBadgeBg: const Color(0xFFE2E8F0).withOpacity(0.90),
      micOffIconColor: const Color(0xFFEF4444),
      glassBlurSigma: 6.0,
      seatBoxShadows: [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.08),
          blurRadius: 4.0,
          spreadRadius: 0.5,
        ),
      ],
    );
  }
}

/// Intelligent engine that analyzes room background in real time and computes
/// high-contrast, Material You / iOS style adaptive seat theme tokens.
class AdaptiveSeatThemeEngine {
  /// Calculate relative luminance according to WCAG specifications (0.0 to 1.0).
  static double calculateRelativeLuminance(Color c) {
    double transform(int channel) {
      final double s = channel / 255.0;
      return s <= 0.04045 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    final double r = transform(c.red);
    final double g = transform(c.green);
    final double b = transform(c.blue);

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Calculate WCAG contrast ratio between two colors (1.0 to 21.0).
  static double calculateContrastRatio(Color foreground, Color background) {
    final double l1 = calculateRelativeLuminance(foreground);
    final double l2 = calculateRelativeLuminance(background);
    final double lighter = math.max(l1, l2);
    final double darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Ensure foreground color satisfies a minimum WCAG contrast ratio against background.
  static Color ensureWcagContrast(
    Color foreground,
    Color background, {
    double minRatio = 4.5,
  }) {
    if (calculateContrastRatio(foreground, background) >= minRatio) {
      return foreground;
    }

    final double bgLum = calculateRelativeLuminance(background);
    // If background is dark, lighten foreground towards white; else darken towards dark navy.
    if (bgLum <= 0.45) {
      Color candidate = foreground;
      for (double factor = 0.1; factor <= 1.0; factor += 0.1) {
        candidate = Color.lerp(foreground, Colors.white, factor)!;
        if (calculateContrastRatio(candidate, background) >= minRatio) {
          return candidate;
        }
      }
      return Colors.white;
    } else {
      Color candidate = foreground;
      for (double factor = 0.1; factor <= 1.0; factor += 0.1) {
        candidate = Color.lerp(foreground, const Color(0xFF0F172A), factor)!;
        if (calculateContrastRatio(candidate, background) >= minRatio) {
          return candidate;
        }
      }
      return const Color(0xFF0F172A);
    }
  }

  /// Resolves dynamic [AdaptiveSeatThemeTokens] for the specified [RoomBackgroundItem].
  static AdaptiveSeatThemeTokens resolve(
    RoomBackgroundItem? bg, {
    bool isDarkMode = true,
  }) {
    if (bg == null) {
      return isDarkMode
          ? AdaptiveSeatThemeTokens.darkFallback()
          : AdaptiveSeatThemeTokens.lightFallback();
    }

    // 1. Analyze background luminance & light state
    double avgLuminance = 0.15;
    Color dominantColor = isDarkMode ? AppTheme.darkAccentPurple : AppTheme.lightAccentPurple;

    if (bg.gradientColors != null && bg.gradientColors!.isNotEmpty) {
      double totalLum = 0.0;
      for (final c in bg.gradientColors!) {
        totalLum += calculateRelativeLuminance(c);
      }
      avgLuminance = totalLum / bg.gradientColors!.length;
      dominantColor = bg.gradientColors!.first;
    }

    final bool isLight = bg.isLightBackground || avgLuminance > 0.45;

    // 2. Extract dynamic accent tone (Material You / iOS style tinting)
    HSLColor hsl = HSLColor.fromColor(dominantColor);
    final Color dynamicAccent = isLight
        ? HSLColor.fromAHSL(1.0, hsl.hue, math.min(hsl.saturation, 0.70), 0.35).toColor()
        : HSLColor.fromAHSL(1.0, hsl.hue, math.max(hsl.saturation, 0.60), 0.65).toColor();

    if (isLight) {
      // Light / White Background adaptation
      final Color seatFill = const Color(0xFF0F172A).withOpacity(0.08);
      final Color borderCol = dynamicAccent.withOpacity(0.55);
      final Color lockCol = ensureWcagContrast(dynamicAccent, const Color(0xFFF1F5F9), minRatio: 3.5);
      final Color userCol = ensureWcagContrast(const Color(0xFF0F172A), const Color(0xFFF8FAFC), minRatio: 4.5);

      return AdaptiveSeatThemeTokens(
        isLightBackground: true,
        seatBorderColor: borderCol,
        seatFillColor: seatFill,
        seatGlowColor: dynamicAccent.withOpacity(0.15),
        seatGlowRadius: 2.0,
        seatBorderWidth: 1.5,
        lockIconColor: lockCol,
        emptySeatIconColor: const Color(0xFF334155).withOpacity(0.70),
        speakingRingColor: const Color(0xFF16A34A),
        speakingGlowColor: const Color(0xFF16A34A).withOpacity(0.30),
        usernameColor: userCol,
        usernameShadows: const [
          Shadow(color: Color(0x99FFFFFF), blurRadius: 4, offset: Offset(0, 1)),
        ],
        starIconColor: const Color(0xFFD97706),
        starTextColor: const Color(0xFF334155),
        micOffBadgeBg: const Color(0xFFE2E8F0).withOpacity(0.90),
        micOffIconColor: const Color(0xFFEF4444),
        glassBlurSigma: 6.0,
        seatBoxShadows: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.10),
            blurRadius: 4.0,
            spreadRadius: 0.5,
          ),
        ],
      );
    } else {
      // Dark Background adaptation
      final Color seatFill = Colors.white.withOpacity(0.09);
      final Color borderCol = dynamicAccent.withOpacity(0.75);
      final Color lockCol = ensureWcagContrast(dynamicAccent, const Color(0xFF0F172A), minRatio: 3.5);
      final Color userCol = ensureWcagContrast(Colors.white, const Color(0xFF0F172A), minRatio: 4.5);

      return AdaptiveSeatThemeTokens(
        isLightBackground: false,
        seatBorderColor: borderCol,
        seatFillColor: seatFill,
        seatGlowColor: dynamicAccent.withOpacity(0.30),
        seatGlowRadius: 6.0,
        seatBorderWidth: 1.5,
        lockIconColor: lockCol,
        emptySeatIconColor: Colors.white38,
        speakingRingColor: const Color(0xFF22C55E),
        speakingGlowColor: const Color(0xFF22C55E).withOpacity(0.45),
        usernameColor: userCol,
        usernameShadows: const [
          Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
        ],
        starIconColor: const Color(0xFFFBBF24),
        starTextColor: Colors.white70,
        micOffBadgeBg: const Color(0xFF0F172A).withOpacity(0.85),
        micOffIconColor: const Color(0xFFF87171),
        glassBlurSigma: 8.0,
        seatBoxShadows: [
          BoxShadow(
            color: dynamicAccent.withOpacity(0.25),
            blurRadius: 8.0,
            spreadRadius: 1.0,
          ),
        ],
      );
    }
  }
}
