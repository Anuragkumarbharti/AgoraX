import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── LIGHT THEME COLS (Creania Premium Design System v1.0) ──
  static const Color lightBg = Color(0xFFF5F7FB);
  static const Color lightSecBg = Color(0xFFEEF3F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightFloatingCard = Color(0xFFFFFFFF);

  // Glass colors
  static final Color lightGlassSurface =
      const Color(0xFFFFFFFF).withOpacity(0.82);
  static final Color lightGlassHighlight =
      const Color(0xFFFFFFFF).withOpacity(0.52);
  static final Color lightGlassReflection =
      const Color(0xFFFFFFFF).withOpacity(0.35);

  // Typography
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextBody = Color(0xFF334155);
  static const Color lightCaption = Color(0xFF64748B);
  static const Color lightPlaceholder = Color(0xFF94A3B8);
  static const Color lightDisabled = Color(0xFFB6C2D1);

  // Dividers, Borders, Shadows
  static const Color lightBorder = Color(0xFFD6DEE8);
  static const Color lightDivider = Color(0xFFE7EDF5);
  static const Color lightShadow = Color(0x140F172A); // rgba(15,23,42,0.08)

  // Brand & Accents
  static const Color lightPrimary = Color(0xFF5B5CF0);
  static const Color lightPrimaryHover = Color(0xFF4C4DD9);
  static const Color lightPrimaryPressed = Color(0xFF4142C9);
  static const Color lightSecondaryBrand = Color(0xFF2AA8FF);

  static const Color lightAccentPurple = Color(0xFF7C4DFF);
  static const Color lightAccentBlue = Color(0xFF3B82F6);
  static const Color lightAccentCyan = Color(0xFF06B6D4);
  static const Color lightAccentPink = Color(0xFFEC4899);
  static const Color lightAccentOrange = Color(0xFFF97316);
  static const Color lightAccentGold = Color(0xFFF4B400);

  // Statuses
  static const Color lightSuccess = Color(0xFF16A34A);
  static const Color lightWarning = Color(0xFFF59E0B);
  static const Color lightError = Color(0xFFEF4444);
  static const Color lightInfo = Color(0xFF2563EB);

  // Gamification & Badges
  static const Color lightVipGold = Color(0xFFD4AF37);
  static const Color lightSilver = Color(0xFFAEB8C2);
  static const Color lightBronze = Color(0xFFB87333);

  // Legacy/Fallback Light Fields
  static const Color lightAccent = lightAccentPurple;
  static const Color lightTextTertiary = lightCaption;
  static final Color lightGlass = lightGlassSurface;

  // ── DARK THEME COLS (Creania Premium Design System v1.0) ──
  static const Color darkBg = Color(0xFF090B12);
  static const Color darkSecBg = Color(0xFF10131B);
  static const Color darkSurface = Color(0xFF151923);
  static const Color darkFloatingCard = Color(0xFF191E29);

  // Glass colors
  static final Color darkGlassSurface =
      const Color(0xFF1A1E2A).withOpacity(0.78);
  static final Color darkGlassHighlight =
      const Color(0xFFFFFFFF).withOpacity(0.08);
  static final Color darkGlassReflection =
      const Color(0xFFFFFFFF).withOpacity(0.05);

  // Typography
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFD7DFEA);
  static const Color darkTextBody = Color(0xFFC7D0DB);
  static const Color darkCaption = Color(0xFF9AA7B8);
  static const Color darkPlaceholder = Color(0xFF7D8CA2);
  static const Color darkDisabled = Color(0xFF617085);

  // Dividers, Borders, Shadows
  static const Color darkBorder = Color(0xFF2D3645);
  static const Color darkDivider = Color(0xFF26303D);
  static const Color darkShadow = Color(0x6B000000); // rgba(0,0,0,0.42)

  // Brand & Accents
  static const Color darkPrimary = Color(0xFF7A6DFF);
  static const Color darkPrimaryHover = Color(0xFF8B80FF);
  static const Color darkPrimaryPressed = Color(0xFF6A5DF4);
  static const Color darkSecondaryBrand = Color(0xFF4AB8FF);

  static const Color darkAccentPurple = Color(0xFF9B7DFF);
  static const Color darkAccentBlue = Color(0xFF60A5FA);
  static const Color darkAccentCyan = Color(0xFF3EE8FF);
  static const Color darkAccentPink = Color(0xFFFF6AC1);
  static const Color darkAccentOrange = Color(0xFFFF9A3D);
  static const Color darkAccentGold = Color(0xFFFFD54A);

  // Statuses
  static const Color darkSuccess = Color(0xFF22C55E);
  static const Color darkWarning = Color(0xFFFBBF24);
  static const Color darkError = Color(0xFFF87171);
  static const Color darkInfo = Color(0xFF60A5FA);

  // Gamification & Badges
  static const Color darkVipGold = Color(0xFFF6D365);
  static const Color darkSilver = Color(0xFFD3D8DF);
  static const Color darkBronze = Color(0xFFCD8B62);

  // Legacy/Fallback Dark Fields
  static const Color darkAccent = darkAccentPurple;
  static const Color darkTextTertiary = darkCaption;
  static final Color darkGlass = darkGlassSurface;

  // ── Fallbacks / Legacy static fields to ensure backward compatibility ──
  static const Color primaryColor = darkPrimary;
  static const Color secondaryColor = darkPrimary;
  static const Color accentColor = darkAccentPurple;
  static const Color bgDark = darkBg;
  static const Color bgLight = darkSecBg;
  static const Color cardBg = darkSecBg;
  static const Color borderColor = darkBorder;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textTertiary = darkCaption;
  static const Color errorColor = darkError;
  static const Color successColor = darkSuccess;
  static const Color warningColor = darkWarning;

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
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: lightTextPrimary),
      titleTextStyle: TextStyle(
        color: lightTextPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.outfit(
          fontSize: 32, fontWeight: FontWeight.w700, color: lightTextPrimary),
      displayMedium: GoogleFonts.outfit(
          fontSize: 28, fontWeight: FontWeight.w700, color: lightTextPrimary),
      headlineLarge: GoogleFonts.outfit(
          fontSize: 24, fontWeight: FontWeight.w700, color: lightTextPrimary),
      headlineSmall: GoogleFonts.outfit(
          fontSize: 20, fontWeight: FontWeight.w700, color: lightTextPrimary),
      titleMedium: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w700, color: lightTextPrimary),
      bodyLarge: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w500, color: lightTextPrimary),
      bodyMedium: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w500, color: lightTextSecondary),
      bodySmall: GoogleFonts.poppins(
          fontSize: 12, fontWeight: FontWeight.w400, color: lightCaption),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: lightPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: lightError, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: lightError, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.poppins(
        fontSize: 14,
        color: lightPlaceholder,
        fontWeight: FontWeight.w400,
      ),
    ),
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
      secondary: darkPrimary,
      surface: darkSurface,
      error: darkError,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: darkTextPrimary),
      titleTextStyle: TextStyle(
        color: darkTextPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.outfit(
          fontSize: 32, fontWeight: FontWeight.w700, color: darkTextPrimary),
      displayMedium: GoogleFonts.outfit(
          fontSize: 28, fontWeight: FontWeight.w700, color: darkTextPrimary),
      headlineLarge: GoogleFonts.outfit(
          fontSize: 24, fontWeight: FontWeight.w700, color: darkTextPrimary),
      headlineSmall: GoogleFonts.outfit(
          fontSize: 20, fontWeight: FontWeight.w700, color: darkTextPrimary),
      titleMedium: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w700, color: darkTextPrimary),
      bodyLarge: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w500, color: darkTextPrimary),
      bodyMedium: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w500, color: darkTextSecondary),
      bodySmall: GoogleFonts.poppins(
          fontSize: 12, fontWeight: FontWeight.w400, color: darkCaption),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: darkPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: darkError, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: darkError, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.poppins(
        fontSize: 14,
        color: darkPlaceholder,
        fontWeight: FontWeight.w400,
      ),
    ),
    cardTheme: CardThemeData(
      color: darkFloatingCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkSecBg,
      selectedItemColor: darkPrimary,
      unselectedItemColor: darkTextSecondary,
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
  Color get floatingCardColor =>
      isDark ? AppTheme.darkFloatingCard : AppTheme.lightFloatingCard;

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
  Color get dividerColor =>
      isDark ? AppTheme.darkDivider : AppTheme.lightDivider;
  Color get shadowColor => isDark ? AppTheme.darkShadow : AppTheme.lightShadow;

  Color get glassSurfaceColor =>
      isDark ? AppTheme.darkGlassSurface : AppTheme.lightGlassSurface;
  Color get glassHighlight =>
      isDark ? AppTheme.darkGlassHighlight : AppTheme.lightGlassHighlight;
  Color get glassReflection =>
      isDark ? AppTheme.darkGlassReflection : AppTheme.lightGlassReflection;

  Color get vipGold => isDark ? AppTheme.darkVipGold : AppTheme.lightVipGold;
  Color get silver => isDark ? AppTheme.darkSilver : AppTheme.lightSilver;
  Color get bronze => isDark ? AppTheme.darkBronze : AppTheme.lightBronze;
}
