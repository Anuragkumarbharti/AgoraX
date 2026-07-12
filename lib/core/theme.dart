import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light Theme Colors (WWDC Liquid Glass Redesign)
  static const Color lightBg = Color(0xFFFAFBFF);
  static const Color lightSecBg = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF5E5CFF);
  static const Color lightAccent = Color(0xFF7B61FF);
  static const Color lightSuccess = Color(0xFF22C55E);
  static const Color lightWarning = Color(0xFFF59E0B);
  static const Color lightError = Color(0xFFEF4444);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF4B5563);
  static const Color lightTextTertiary = Color(0xFF9CA3AF);
  static final Color lightGlass = Colors.white.withOpacity(0.72);
  static final Color lightBorder = Colors.white.withOpacity(0.30);
  static const Color lightShadow = Color(0x0A000000); // rgba(0,0,0,0.04)

  // Dark Theme Colors (WWDC Liquid Glass Redesign)
  static const Color darkBg = Color(0xFF0B1020);
  static const Color darkSecBg = Color(0xFF12131A);
  static const Color darkPrimary = Color(0xFF7A6EFF);
  static const Color darkAccent = Color(0xFF5E5CFF);
  static const Color darkSuccess = Color(0xFF22C55E);
  static const Color darkWarning = Color(0xFFF59E0B);
  static const Color darkError = Color(0xFFF87171);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFD1D5DB);
  static const Color darkTextTertiary = Color(0xFF9CA3AF);
  static final Color darkGlass = const Color(0xFF181A22).withOpacity(0.70);
  static final Color darkBorder = Colors.white.withOpacity(0.10);
  static const Color darkShadow = Color(0x66000000); // rgba(0,0,0,0.40)

  // Fallbacks / Legacy static fields to ensure backward compatibility
  static const Color primaryColor = darkPrimary;
  static const Color secondaryColor = darkPrimary;
  static const Color accentColor = darkAccent;
  static const Color bgDark = darkBg;
  static const Color bgLight = darkSecBg;
  static const Color cardBg = darkSecBg;
  static const Color borderColor = Colors.white24;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textTertiary = darkTextTertiary;
  static const Color errorColor = darkError;
  static const Color successColor = darkSuccess;
  static const Color warningColor = darkWarning;

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBg,
    primaryColor: lightPrimary,
    colorScheme: const ColorScheme.light(
      primary: lightPrimary,
      secondary: lightPrimary,
      surface: lightSecBg,
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
      displayLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w700, color: lightTextPrimary),
      displayMedium: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w700, color: lightTextPrimary),
      headlineLarge: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, color: lightTextPrimary),
      headlineSmall: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: lightTextPrimary),
      titleMedium: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: lightTextPrimary),
      bodyLarge: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: lightTextPrimary),
      bodyMedium: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: lightTextSecondary),
      bodySmall: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400, color: lightTextTertiary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18), // Enforces WWDC 18px input radius
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: lightPrimary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.poppins(
        fontSize: 14,
        color: lightTextTertiary,
        fontWeight: FontWeight.w400,
      ),
    ),
    cardTheme: CardThemeData(
      color: lightSecBg,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), // Enforces WWDC 24px card radius
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: lightSecBg,
      selectedItemColor: lightPrimary,
      unselectedItemColor: lightTextSecondary,
      elevation: 8,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    primaryColor: darkPrimary,
    colorScheme: const ColorScheme.dark(
      primary: darkPrimary,
      secondary: darkPrimary,
      surface: darkSecBg,
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
      displayLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w700, color: darkTextPrimary),
      displayMedium: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w700, color: darkTextPrimary),
      headlineLarge: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, color: darkTextPrimary),
      headlineSmall: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: darkTextPrimary),
      titleMedium: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: darkTextPrimary),
      bodyLarge: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: darkTextPrimary),
      bodyMedium: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: darkTextSecondary),
      bodySmall: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400, color: darkTextTertiary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSecBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18), // Enforces WWDC 18px input radius
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: darkPrimary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.poppins(
        fontSize: 14,
        color: darkTextTertiary,
        fontWeight: FontWeight.w400,
      ),
    ),
    cardTheme: CardThemeData(
      color: darkSecBg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), // Enforces WWDC 24px card radius
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
  
  Color get primaryColor => isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
  Color get accentColor => isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
  Color get successColor => isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
  Color get warningColor => isDark ? AppTheme.darkWarning : AppTheme.lightWarning;
  Color get errorColor => isDark ? AppTheme.darkError : AppTheme.lightError;
  
  Color get scaffoldBackgroundColor => isDark ? AppTheme.darkBg : AppTheme.lightBg;
  Color get secondaryBackgroundColor => isDark ? AppTheme.darkSecBg : AppTheme.lightSecBg;
  
  Color get textPrimary => isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
  Color get textSecondary => isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
  Color get textTertiary => isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary;
  
  Color get glassSurfaceColor => isDark ? AppTheme.darkGlass : AppTheme.lightGlass;
  Color get borderColor => isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
}
