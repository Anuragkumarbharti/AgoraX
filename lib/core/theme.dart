import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import '../services/room/room_controller.dart';
import './theme/adaptive_seat_theme.dart';
export './responsive.dart';
export './theme/adaptive_seat_theme.dart';

class AppTheme {
  // ── LIGHT THEME COLS (Creania Premium Design System v2.0) ──
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSecBg = Color(0xFFF1F5F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightFloatingCard = Color(0xFFFFFFFF);

  // Glass colors
  static final Color lightGlassSurface =
      const Color(0xFFFFFFFF).withOpacity(0.88);
  static final Color lightGlassHighlight =
      const Color(0xFFFFFFFF).withOpacity(0.60);
  static final Color lightGlassReflection =
      const Color(0xFFFFFFFF).withOpacity(0.40);

  // Typography
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF374151);
  static const Color lightTextBody = Color(0xFF4B5563);
  static const Color lightCaption = Color(0xFF6B7280);
  static const Color lightPlaceholder = Color(0xFF9CA3AF);
  static const Color lightDisabled = Color(0xFFD1D5DB);

  // Dividers, Borders, Shadows
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightDivider = Color(0xFFE2E8F0);
  static const Color lightShadow = Color(0x0A0F172A); // rgba(15,23,42,0.04)

  // Brand & Accents
  static const Color lightPrimary = Color(0xFF6D5DF6); // Royal Purple
  static const Color lightPrimaryHover = Color(0xFF5B4BE3);
  static const Color lightPrimaryPressed = Color(0xFF4C3CD2);
  static const Color lightSecondaryBrand = Color(0xFF4EA8FF); // Blue

  static const Color lightAccentPurple = Color(0xFF6D5DF6);
  static const Color lightAccentBlue = Color(0xFF4EA8FF);
  static const Color lightAccentCyan = Color(0xFF38BDF8);
  static const Color lightAccentPink = Color(0xFFEC4899);
  static const Color lightAccentOrange = Color(0xFFF97316);
  static const Color lightAccentGold = Color(0xFFF4B400); // Gold Accent

  // Statuses
  static const Color lightSuccess = Color(0xFF22C55E);
  static const Color lightWarning = Color(0xFFF59E0B);
  static const Color lightError = Color(0xFFEF4444);
  static const Color lightInfo = Color(0xFF3B82F6);

  // Gamification & Badges
  static const Color lightVipGold = Color(0xFFF4B400);
  static const Color lightSilver = Color(0xFF94A3B8);
  static const Color lightBronze = Color(0xFFB87333);

  // Legacy/Fallback Light Fields
  static const Color lightAccent = lightAccentPurple;
  static const Color lightTextTertiary = lightCaption;
  static final Color lightGlass = lightGlassSurface;

  // ── DARK THEME COLS (Creania Premium Design System v2.0 - Flagship Dark Mode) ──
  static const Color darkBg = Color(0xFF0F1115);
  static const Color darkSecBg = Color(0xFF161B22);
  static const Color darkSurface = Color(0xFF1C212B);
  static const Color darkElevatedSurface = Color(0xFF242B38);
  static const Color darkCardBg = Color(0xFF1A1F28);
  static const Color darkFloatingCard = Color(0xFF1A1F28);
  static const Color darkPopupDialog = Color(0xFF202733);
  static const Color darkBottomNav = Color(0xFF12161D);
  static const Color darkAppBar = Color(0xFF12161D);

  // Glass colors
  static final Color darkGlassSurface =
      const Color(0xFF1C212B).withOpacity(0.85);
  static final Color darkGlassHighlight =
      const Color(0xFFFFFFFF).withOpacity(0.08);
  static final Color darkGlassReflection =
      const Color(0xFFFFFFFF).withOpacity(0.05);

  // Typography
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFE5E7EB);
  static const Color darkTextBody = Color(0xFFD1D5DB);
  static const Color darkCaption = Color(0xFFB5BECF);
  static const Color darkPlaceholder = Color(0xFF9CA3AF);
  static const Color darkDisabled = Color(0xFF6B7280);

  // Dividers, Borders, Shadows
  static const Color darkBorder = Color(0xFF2C3442);
  static const Color darkSecBorder = Color(0xFF323B4A);
  static const Color darkDivider = Color(0xFF2C3442);
  static const Color darkShadow = Color(0x66000000); // rgba(0,0,0,0.4)

  // Brand & Accents
  static const Color darkPrimary = Color(0xFF7C6BFF);
  static const Color darkPrimaryHover = Color(0xFF9F8DFF);
  static const Color darkPrimaryPressed = Color(0xFF6A5DF4);
  static const Color darkSecondaryBrand = Color(0xFF9F8DFF);

  static const Color darkAccentPurple = Color(0xFF7C6BFF);
  static const Color darkAccentBlue = Color(0xFF4EA8FF);
  static const Color darkAccentCyan = Color(0xFF38BDF8);
  static const Color darkAccentPink = Color(0xFFEC4899);
  static const Color darkAccentOrange = Color(0xFFF97316);
  static const Color darkAccentGold = Color(0xFFF4B400);

  // Statuses
  static const Color darkSuccess = Color(0xFF22C55E);
  static const Color darkWarning = Color(0xFFF59E0B);
  static const Color darkError = Color(0xFFEF4444);
  static const Color darkInfo = Color(0xFF4EA8FF);

  // Gamification & Badges
  static const Color darkVipGold = Color(0xFFF4B400);
  static const Color darkSilver = Color(0xFF94A3B8);
  static const Color darkBronze = Color(0xFFB87333);

  // Legacy/Fallback Dark Fields
  static const Color darkAccent = darkAccentPurple;
  static const Color darkTextTertiary = darkCaption;
  static final Color darkGlass = darkGlassSurface;

  // ── Fallbacks / Legacy static fields to ensure backward compatibility ──
  static const Color primaryColor = lightPrimary;
  static const Color secondaryColor = lightPrimary;
  static const Color accentColor = lightAccentPurple;
  static const Color bgDark = lightBg;
  static const Color bgLight = lightSecBg;
  static const Color cardBg = lightSurface;
  static const Color borderColor = lightBorder;
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;
  static const Color textTertiary = lightCaption;
  static const Color errorColor = lightError;
  static const Color successColor = lightSuccess;
  static const Color warningColor = lightWarning;

  // ThemeData lightTheme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBg,
    primaryColor: lightPrimary,
    colorScheme: const ColorScheme.light(
      primary: lightPrimary,
      secondary: lightPrimary,
      surface: lightSurface,
      error: lightError,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: lightTextPrimary),
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: lightTextPrimary,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 34, fontWeight: FontWeight.bold, color: lightTextPrimary),
      displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 28, fontWeight: FontWeight.bold, color: lightTextPrimary),
      headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 22, fontWeight: FontWeight.bold, color: lightTextPrimary),
      headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.bold, color: lightTextPrimary),
      titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 17, fontWeight: FontWeight.bold, color: lightTextPrimary),
      bodyLarge: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.normal, color: lightTextSecondary, height: 1.5),
      bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.normal, color: lightCaption, height: 1.5),
      bodySmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500, color: lightCaption),
      labelLarge: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
      labelMedium: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.bold, color: lightTextPrimary),
      labelSmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500, color: lightCaption),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDCE3ED)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDCE3ED)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF8B5CFF), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
      ),
      contentPadding: const EdgeInsets.all(16),
      hintStyle: GoogleFonts.inter(
        fontSize: 15,
        color: lightPlaceholder,
        fontWeight: FontWeight.normal,
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 15,
        color: lightTextPrimary,
        fontWeight: FontWeight.w500,
      ),
    ),
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: lightSurface,
      selectedItemColor: lightPrimary,
      unselectedItemColor: lightTextSecondary,
      elevation: 8,
    ),
  );

  // ThemeData darkTheme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    primaryColor: darkPrimary,
    colorScheme: const ColorScheme.dark(
      primary: darkPrimary,
      secondary: darkSecondaryBrand,
      surface: darkSurface,
      error: darkError,
      background: darkBg,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkAppBar,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: darkTextSecondary),
      actionsIconTheme: const IconThemeData(color: darkPrimary),
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: darkTextPrimary,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 34, fontWeight: FontWeight.bold, color: darkTextPrimary),
      displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 28, fontWeight: FontWeight.bold, color: darkTextPrimary),
      headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 22, fontWeight: FontWeight.bold, color: darkTextPrimary),
      headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.bold, color: darkTextPrimary),
      titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 17, fontWeight: FontWeight.bold, color: darkTextPrimary),
      bodyLarge: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.normal, color: darkTextSecondary, height: 1.5),
      bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.normal, color: darkCaption, height: 1.5),
      bodySmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500, color: darkCaption),
      labelLarge: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
      labelMedium: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.bold, color: darkTextPrimary),
      labelSmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500, color: darkCaption),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkElevatedSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: darkPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: darkError, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: darkError, width: 2),
      ),
      contentPadding: const EdgeInsets.all(16),
      hintStyle: GoogleFonts.inter(
        fontSize: 15,
        color: darkPlaceholder,
        fontWeight: FontWeight.normal,
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 15,
        color: darkTextPrimary,
        fontWeight: FontWeight.w500,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: darkPopupDialog,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: darkPopupDialog,
      modalBackgroundColor: darkPopupDialog,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    cardTheme: CardThemeData(
      color: darkCardBg,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkBottomNav,
      selectedItemColor: darkPrimary,
      unselectedItemColor: darkPlaceholder,
      elevation: 8,
    ),
  );
}

extension ThemeExtension on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get primaryColor =>
      isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
  Color get primaryHover =>
      isDark ? AppTheme.darkPrimaryHover : AppTheme.lightPrimaryHover;
  Color get primaryPressed =>
      isDark ? AppTheme.darkPrimaryPressed : AppTheme.lightPrimaryPressed;
  Color get secondaryBrand =>
      isDark ? AppTheme.darkSecondaryBrand : AppTheme.lightSecondaryBrand;

  Color get accentPurple =>
      isDark ? AppTheme.darkAccentPurple : AppTheme.lightAccentPurple;
  Color get accentBlue =>
      isDark ? AppTheme.darkAccentBlue : AppTheme.lightAccentBlue;
  Color get accentCyan =>
      isDark ? AppTheme.darkAccentCyan : AppTheme.lightAccentCyan;
  Color get accentPink =>
      isDark ? AppTheme.darkAccentPink : AppTheme.lightAccentPink;
  Color get accentOrange =>
      isDark ? AppTheme.darkAccentOrange : AppTheme.lightAccentOrange;
  Color get accentGold =>
      isDark ? AppTheme.darkAccentGold : AppTheme.lightAccentGold;

  AdaptiveSeatThemeTokens get adaptiveSeatTheme {
    try {
      if (Get.isRegistered<RoomController>()) {
        final bg = RoomController.to.activeRoomBackground.value;
        return AdaptiveSeatThemeEngine.resolve(bg, isDarkMode: isDark);
      }
    } catch (_) {}
    return isDark
        ? AdaptiveSeatThemeTokens.darkFallback(lockedAccent: accentPurple)
        : AdaptiveSeatThemeTokens.lightFallback(lockedAccent: accentPurple);
  }

  Color get lockedSeatColor => adaptiveSeatTheme.lockIconColor;
  Color get lockedSeatGlowColor => adaptiveSeatTheme.seatGlowColor;
  double get lockedSeatGlowRadius => adaptiveSeatTheme.seatGlowRadius;
  double get lockedSeatBorderWidth => adaptiveSeatTheme.seatBorderWidth;

  Color get successColor =>
      isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
  Color get warningColor =>
      isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
  Color get errorColor => isDark ? AppTheme.darkError : AppTheme.lightError;
  Color get infoColor => isDark ? AppTheme.darkInfo : AppTheme.lightInfo;

  Color get scaffoldBackgroundColor =>
      isDark ? AppTheme.darkBg : AppTheme.lightBg;
  Color get secondaryBackgroundColor =>
      isDark ? AppTheme.darkSecBg : AppTheme.lightSecBg;
  Color get surfaceColor =>
      isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
  Color get elevatedSurfaceColor =>
      isDark ? AppTheme.darkElevatedSurface : AppTheme.lightSecBg;
  Color get cardColor =>
      isDark ? AppTheme.darkCardBg : AppTheme.lightSurface;
  Color get floatingCardColor =>
      isDark ? AppTheme.darkCardBg : AppTheme.lightFloatingCard;
  Color get dialogBackgroundColor =>
      isDark ? AppTheme.darkPopupDialog : AppTheme.lightSurface;
  Color get bottomNavBackgroundColor =>
      isDark ? AppTheme.darkBottomNav : AppTheme.lightSurface;
  Color get appBarBackgroundColor =>
      isDark ? AppTheme.darkAppBar : AppTheme.lightSurface;

  Color get textPrimary =>
      isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
  Color get textSecondary =>
      isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
  Color get textBody => isDark ? AppTheme.darkTextBody : AppTheme.lightTextBody;
  Color get caption => isDark ? AppTheme.darkCaption : AppTheme.lightCaption;
  Color get placeholder =>
      isDark ? AppTheme.darkPlaceholder : AppTheme.lightPlaceholder;
  Color get disabled => isDark ? AppTheme.darkDisabled : AppTheme.lightDisabled;

  Color get borderColor => isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
  Color get secondaryBorderColor =>
      isDark ? AppTheme.darkSecBorder : AppTheme.lightBorder;
  Color get focusedBorderColor =>
      isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;

  Color get dividerColor =>
      isDark ? AppTheme.darkDivider : AppTheme.lightDivider;
  Color get shadowColor => isDark ? AppTheme.darkShadow : AppTheme.lightShadow;

  Color get iconPrimary => isDark ? Colors.white : AppTheme.lightTextPrimary;
  Color get iconSecondary =>
      isDark ? AppTheme.darkPlaceholder : AppTheme.lightTextSecondary;
  Color get iconSelected => isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
  Color get iconCoin => AppTheme.darkAccentGold;
  Color get iconVip => AppTheme.darkAccentGold;
  Color get iconNotification => AppTheme.darkError;

  Color get chatBubbleIncoming =>
      isDark ? AppTheme.darkElevatedSurface : const Color(0xFFF1F5F9);
  Color get chatBubbleOutgoing =>
      isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
  Color get searchBarBg =>
      isDark ? AppTheme.darkElevatedSurface : const Color(0xFFF1F5F9);
  Color get unreadHighlightColor =>
      isDark ? const Color(0xFF242038) : const Color(0xFFF3E8FF);

  Color get glassSurfaceColor =>
      isDark ? AppTheme.darkGlassSurface : AppTheme.lightGlassSurface;
  Color get glassHighlight =>
      isDark ? AppTheme.darkGlassHighlight : AppTheme.lightGlassHighlight;
  Color get glassReflection =>
      isDark ? AppTheme.darkGlassReflection : AppTheme.lightGlassReflection;

  Color get vipGold => isDark ? AppTheme.darkVipGold : AppTheme.lightVipGold;
  Color get silver => isDark ? AppTheme.darkSilver : AppTheme.lightSilver;
  Color get bronze => isDark ? AppTheme.darkBronze : AppTheme.lightBronze;

  List<BoxShadow> get smallShadow => [
        BoxShadow(
          color: isDark ? Colors.black.withOpacity(0.42) : const Color(0xFF0F172A).withOpacity(0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  List<BoxShadow> get largeShadow => [
        BoxShadow(
          color: isDark ? Colors.black.withOpacity(0.55) : const Color(0xFF0F172A).withOpacity(0.08),
          blurRadius: 40,
          offset: const Offset(0, 16),
        ),
      ];

  LinearGradient get pinkToPurpleGradient => const LinearGradient(
        colors: [Color(0xFFFF4D8D), Color(0xFF8B5CFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get purpleToBlueGradient => const LinearGradient(
        colors: [Color(0xFF8B5CFF), Color(0xFF00C2FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get orangeToGoldGradient => const LinearGradient(
        colors: [Color(0xFFFF7A09), Color(0xFFFFB020)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get premiumGradient => const LinearGradient(
        colors: [Color(0xFFFF4D8D), Color(0xFF8B5CFF), Color(0xFF00C2FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  TextStyle get logoStyle => GoogleFonts.plusJakartaSans(
        fontSize: 34,
        fontWeight: FontWeight.bold,
      );

  TextStyle get splashTitleStyle => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      );

  TextStyle get pageTitleStyle => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      );

  TextStyle get sectionHeadingStyle => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w600, // SemiBold
        color: textPrimary,
      );

  TextStyle get cardTitleStyle => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600, // SemiBold
        color: textPrimary,
      );

  TextStyle get roomTitleStyle => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      );

  TextStyle get userNameStyle => GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      );

  TextStyle get profileNameStyle => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      );

  TextStyle get buttonTextStyle => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600, // SemiBold
      );

  TextStyle get bodyTextStyle => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.normal, // Regular
        color: textSecondary,
        height: 1.5,
      );

  TextStyle get descriptionStyle => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal, // Regular
        color: caption,
        height: 1.5,
      );

  TextStyle get inputTextStyle => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500, // Medium
        color: textPrimary,
      );

  TextStyle get placeholderStyle => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.normal, // Regular
        color: placeholder,
      );

  TextStyle get captionStyle => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500, // Medium
        color: caption,
      );

  TextStyle get smallTextStyle => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500, // Medium
        color: caption,
      );

  TextStyle get tinyLabelStyle => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500, // Medium
        color: caption,
      );

  TextStyle get statsNumbersStyle => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      );

  TextStyle get followersLabelStyle => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500, // Medium
        color: caption,
      );

  TextStyle get walletBalanceStyle => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      );

  TextStyle get coinsStyle => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      );

  TextStyle get otpDigitsStyle => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      );

  TextStyle get levelTextStyle => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600, // SemiBold
        color: textPrimary,
      );

  TextStyle get badgeTextStyle => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600, // SemiBold
        color: textPrimary,
      );

  TextStyle get notificationTimeStyle => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500, // Medium
        color: caption,
      );

  TextStyle get chatMessageStyle => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.normal, // Regular
        color: textPrimary,
      );

  TextStyle get chatTimeStyle => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500, // Medium
        color: caption,
      );

  TextStyle get menuTextStyle => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500, // Medium
        color: textPrimary,
      );

  TextStyle get settingsTitleStyle => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600, // SemiBold
        color: textPrimary,
      );

  TextStyle get settingsDescriptionStyle => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.normal, // Regular
        color: caption,
      );

  TextStyle get bottomNavTextStyle => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500, // Medium
      );

  TextStyle get tabTextStyle => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600, // SemiBold
      );

  TextStyle get searchHintStyle => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.normal, // Regular
        color: placeholder,
      );
}
