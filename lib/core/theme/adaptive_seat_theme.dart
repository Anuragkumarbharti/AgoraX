import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/room/room_background_model.dart';
import '../theme.dart';

/// Immutable design tokens for room and seat components in voice rooms.
class AdaptiveSeatThemeTokens {
  final bool isLightBackground;

  // Seat Tokens
  final Color seatBorderColor;
  final Color seatFillColor;
  final Color seatGlowColor;
  final double seatGlowRadius;
  final double seatBorderWidth;
  final Color lockIconColor;
  final Color emptySeatIconColor;
  final Color occupiedSeatRingColor;
  final Color speakingRingColor;
  final Color speakingGlowColor;

  // Text & Label Tokens
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color usernameColor;
  final FontWeight usernameFontWeight;
  final List<Shadow> usernameShadows;
  final Color seatNumberColor;
  final Color starIconColor;
  final Color starTextColor;
  final Color micOffBadgeBg;
  final Color micOffIconColor;

  // Icon Tokens
  final Color iconColor;
  final Color secondaryIconColor;

  // Chat Box & Glass Surface Tokens
  final Color chatBoxFillColor;
  final Color chatBoxBorderColor;
  final Color chatBoxPlaceholderColor;
  final Color chatBoxTextColor;
  final Color chatBoxIconColor;
  final double chatBoxBlur;
  final double chatBoxCornerRadius;

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
    required this.occupiedSeatRingColor,
    required this.speakingRingColor,
    required this.speakingGlowColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.usernameColor,
    required this.usernameFontWeight,
    required this.usernameShadows,
    required this.seatNumberColor,
    required this.starIconColor,
    required this.starTextColor,
    required this.micOffBadgeBg,
    required this.micOffIconColor,
    required this.iconColor,
    required this.secondaryIconColor,
    required this.chatBoxFillColor,
    required this.chatBoxBorderColor,
    required this.chatBoxPlaceholderColor,
    required this.chatBoxTextColor,
    required this.chatBoxIconColor,
    required this.chatBoxBlur,
    required this.chatBoxCornerRadius,
    required this.glassBlurSigma,
    required this.seatBoxShadows,
  });

  /// Dark mode fallback seat theme tokens.
  factory AdaptiveSeatThemeTokens.darkFallback({Color? lockedAccent}) {
    return AdaptiveSeatThemeTokens(
      isLightBackground: false,
      seatBorderColor: Colors.white.withOpacity(0.28),
      seatFillColor: Colors.white.withOpacity(0.12),
      seatGlowColor: Colors.white.withOpacity(0.18),
      seatGlowRadius: 6.0,
      seatBorderWidth: 1.2,
      lockIconColor: Colors.white.withOpacity(0.85),
      emptySeatIconColor: Colors.white.withOpacity(0.40),
      occupiedSeatRingColor: Colors.white.withOpacity(0.85),
      speakingRingColor: const Color(0xFF22C55E),
      speakingGlowColor: const Color(0xFF22C55E).withOpacity(0.40),
      primaryTextColor: Colors.white.withOpacity(0.95),
      secondaryTextColor: Colors.white.withOpacity(0.70),
      usernameColor: Colors.white,
      usernameFontWeight: FontWeight.w600,
      usernameShadows: const [
        Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
      ],
      seatNumberColor: Colors.white.withOpacity(0.90),
      starIconColor: const Color(0xFFFBBF24),
      starTextColor: Colors.white.withOpacity(0.90),
      micOffBadgeBg: Colors.white.withOpacity(0.15),
      micOffIconColor: const Color(0xFFF87171),
      iconColor: Colors.white.withOpacity(0.95),
      secondaryIconColor: Colors.white.withOpacity(0.70),
      chatBoxFillColor: Colors.white.withOpacity(0.12),
      chatBoxBorderColor: Colors.white.withOpacity(0.28),
      chatBoxPlaceholderColor: Colors.white.withOpacity(0.60),
      chatBoxTextColor: Colors.white.withOpacity(0.95),
      chatBoxIconColor: Colors.white.withOpacity(0.95),
      chatBoxBlur: 20.0,
      chatBoxCornerRadius: 30.0,
      glassBlurSigma: 8.0,
      seatBoxShadows: [
        BoxShadow(
          color: Colors.white.withOpacity(0.15),
          blurRadius: 6.0,
          spreadRadius: 0.5,
        ),
      ],
    );
  }

  /// Light mode fallback seat theme tokens.
  factory AdaptiveSeatThemeTokens.lightFallback({Color? lockedAccent}) {
    return AdaptiveSeatThemeTokens(
      isLightBackground: true,
      seatBorderColor: const Color(0xFF111111).withOpacity(0.28),
      seatFillColor: const Color(0xFF111111).withOpacity(0.12),
      seatGlowColor: Colors.transparent,
      seatGlowRadius: 0.0,
      seatBorderWidth: 1.2,
      lockIconColor: const Color(0xFF111111).withOpacity(0.85),
      emptySeatIconColor: const Color(0xFF111111).withOpacity(0.40),
      occupiedSeatRingColor: const Color(0xFF111111).withOpacity(0.85),
      speakingRingColor: const Color(0xFF16A34A),
      speakingGlowColor: const Color(0xFF16A34A).withOpacity(0.25),
      primaryTextColor: const Color(0xFF111111).withOpacity(0.95),
      secondaryTextColor: const Color(0xFF111111).withOpacity(0.70),
      usernameColor: const Color(0xFF111111),
      usernameFontWeight: FontWeight.w600,
      usernameShadows: const [
        Shadow(color: Colors.white70, blurRadius: 4, offset: Offset(0, 1)),
      ],
      seatNumberColor: const Color(0xFF111111).withOpacity(0.90),
      starIconColor: const Color(0xFFD97706),
      starTextColor: const Color(0xFF111111).withOpacity(0.90),
      micOffBadgeBg: const Color(0xFF111111).withOpacity(0.15),
      micOffIconColor: const Color(0xFFEF4444),
      iconColor: const Color(0xFF111111).withOpacity(0.95),
      secondaryIconColor: const Color(0xFF111111).withOpacity(0.70),
      chatBoxFillColor: const Color(0xFF111111).withOpacity(0.12),
      chatBoxBorderColor: const Color(0xFF111111).withOpacity(0.28),
      chatBoxPlaceholderColor: const Color(0xFF111111).withOpacity(0.60),
      chatBoxTextColor: const Color(0xFF111111).withOpacity(0.95),
      chatBoxIconColor: const Color(0xFF111111).withOpacity(0.95),
      chatBoxBlur: 20.0,
      chatBoxCornerRadius: 30.0,
      glassBlurSigma: 6.0,
      seatBoxShadows: [
        BoxShadow(
          color: const Color(0xFF111111).withOpacity(0.15),
          blurRadius: 4.0,
          spreadRadius: 0.5,
        ),
      ],
    );
  }
}

/// Intelligent engine that analyzes room background in real time and computes
/// ultra transparent, high-contrast, Apple Liquid Glass / iOS 26 style adaptive seat theme tokens.
class AdaptiveSeatThemeEngine {
  static final Map<String, AdaptiveSeatThemeTokens> _tokenCache = {};

  /// Clear token cache when background catalog reloads or resets.
  static void clearCache() {
    _tokenCache.clear();
  }

  /// Calculate relative luminance according to WCAG specifications (0.0 to 1.0).
  static double calculateRelativeLuminance(Color c) {
    double transform(int channel) {
      final double s = channel / 255.0;
      return s <= 0.04045
          ? s / 12.92
          : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
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
        candidate = Color.lerp(foreground, const Color(0xFF111111), factor)!;
        if (calculateContrastRatio(candidate, background) >= minRatio) {
          return candidate;
        }
      }
      return const Color(0xFF111111);
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

    final String cacheKey = '${bg.id}_$isDarkMode';
    if (_tokenCache.containsKey(cacheKey)) {
      return _tokenCache[cacheKey]!;
    }

    final bool isLight = bg.isLightBackground;

    final AdaptiveSeatThemeTokens tokens;
    if (isLight) {
      // Light background -> Black UI (#111111) with adaptive glass transparency
      tokens = AdaptiveSeatThemeTokens(
        isLightBackground: true,
        seatBorderColor: const Color(0xFF111111).withOpacity(0.28),
        seatFillColor: const Color(0xFF111111).withOpacity(0.12),
        seatGlowColor: Colors.transparent,
        seatGlowRadius: 0.0,
        seatBorderWidth: 1.2,
        lockIconColor: const Color(0xFF111111).withOpacity(0.85),
        emptySeatIconColor: const Color(0xFF111111).withOpacity(0.40),
        occupiedSeatRingColor: const Color(0xFF111111).withOpacity(0.85),
        speakingRingColor: const Color(0xFF16A34A),
        speakingGlowColor: const Color(0xFF16A34A).withOpacity(0.25),
        primaryTextColor: const Color(0xFF111111).withOpacity(0.95),
        secondaryTextColor: const Color(0xFF111111).withOpacity(0.70),
        usernameColor: const Color(0xFF111111),
        usernameFontWeight: FontWeight.w600,
        usernameShadows: const [
          Shadow(color: Colors.white70, blurRadius: 4, offset: Offset(0, 1)),
        ],
        seatNumberColor: const Color(0xFF111111).withOpacity(0.90),
        starIconColor: const Color(0xFFD97706),
        starTextColor: const Color(0xFF111111).withOpacity(0.90),
        micOffBadgeBg: const Color(0xFF111111).withOpacity(0.15),
        micOffIconColor: const Color(0xFFEF4444),
        iconColor: const Color(0xFF111111).withOpacity(0.95),
        secondaryIconColor: const Color(0xFF111111).withOpacity(0.70),
        chatBoxFillColor: const Color(0xFF111111).withOpacity(0.12),
        chatBoxBorderColor: const Color(0xFF111111).withOpacity(0.28),
        chatBoxPlaceholderColor: const Color(0xFF111111).withOpacity(0.60),
        chatBoxTextColor: const Color(0xFF111111).withOpacity(0.95),
        chatBoxIconColor: const Color(0xFF111111).withOpacity(0.95),
        chatBoxBlur: 20.0,
        chatBoxCornerRadius: 30.0,
        glassBlurSigma: 6.0,
        seatBoxShadows: [
          BoxShadow(
            color: const Color(0xFF111111).withOpacity(0.15),
            blurRadius: 4.0,
            spreadRadius: 0.5,
          ),
        ],
      );
    } else {
      // Dark background -> White UI (#FFFFFF) with adaptive glass transparency
      tokens = AdaptiveSeatThemeTokens(
        isLightBackground: false,
        seatBorderColor: Colors.white.withOpacity(0.28),
        seatFillColor: Colors.white.withOpacity(0.12),
        seatGlowColor: Colors.white.withOpacity(0.18),
        seatGlowRadius: 6.0,
        seatBorderWidth: 1.2,
        lockIconColor: Colors.white.withOpacity(0.85),
        emptySeatIconColor: Colors.white.withOpacity(0.40),
        occupiedSeatRingColor: Colors.white.withOpacity(0.85),
        speakingRingColor: const Color(0xFF22C55E),
        speakingGlowColor: const Color(0xFF22C55E).withOpacity(0.40),
        primaryTextColor: Colors.white.withOpacity(0.95),
        secondaryTextColor: Colors.white.withOpacity(0.70),
        usernameColor: Colors.white,
        usernameFontWeight: FontWeight.w600,
        usernameShadows: const [
          Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
        ],
        seatNumberColor: Colors.white.withOpacity(0.90),
        starIconColor: const Color(0xFFFBBF24),
        starTextColor: Colors.white.withOpacity(0.90),
        micOffBadgeBg: Colors.white.withOpacity(0.15),
        micOffIconColor: const Color(0xFFF87171),
        iconColor: Colors.white.withOpacity(0.95),
        secondaryIconColor: Colors.white.withOpacity(0.70),
        chatBoxFillColor: Colors.white.withOpacity(0.12),
        chatBoxBorderColor: Colors.white.withOpacity(0.28),
        chatBoxPlaceholderColor: Colors.white.withOpacity(0.60),
        chatBoxTextColor: Colors.white.withOpacity(0.95),
        chatBoxIconColor: Colors.white.withOpacity(0.95),
        chatBoxBlur: 20.0,
        chatBoxCornerRadius: 30.0,
        glassBlurSigma: 8.0,
        seatBoxShadows: [
          BoxShadow(
            color: Colors.white.withOpacity(0.15),
            blurRadius: 6.0,
            spreadRadius: 0.5,
          ),
        ],
      );
    }

    _tokenCache[cacheKey] = tokens;
    return tokens;
  }
}
