import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:creania/services/theme_controller.dart';
import 'package:creania/core/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ThemeController themeController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
    themeController = ThemeController();
    Get.put(themeController);
  });

  tearDown(() {
    Get.reset();
  });

  group('Theme Controller State Transition Tests', () {
    test('Default theme preference should be system mode', () {
      expect(themeController.currentThemePreference.value, equals('system'));
      expect(themeController.activeThemeMode, equals(ThemeMode.system));
    });

    test('Switching to Light preference updates ThemeMode and SharedPreferences', () async {
      await themeController.updateThemePreference('light');
      expect(themeController.currentThemePreference.value, equals('light'));
      expect(themeController.activeThemeMode, equals(ThemeMode.light));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_preference'), equals('light'));
    });

    test('Switching to Dark preference updates ThemeMode and SharedPreferences', () async {
      await themeController.updateThemePreference('dark');
      expect(themeController.currentThemePreference.value, equals('dark'));
      expect(themeController.activeThemeMode, equals(ThemeMode.dark));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_preference'), equals('dark'));
    });

    test('Switching to System preference updates ThemeMode and SharedPreferences', () async {
      // Set to light first
      await themeController.updateThemePreference('light');
      
      // Toggle back to system
      await themeController.updateThemePreference('system');
      expect(themeController.currentThemePreference.value, equals('system'));
      expect(themeController.activeThemeMode, equals(ThemeMode.system));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_preference'), equals('system'));
    });
  });

  group('AppTheme Color Specifications Verification', () {
    test('Light Theme matches specification hex colors', () {
      expect(AppTheme.lightBg, equals(const Color(0xFFFAFBFF)));
      expect(AppTheme.lightSecBg, equals(const Color(0xFFFFFFFF)));
      expect(AppTheme.lightPrimary, equals(const Color(0xFF5E5CFF)));
      expect(AppTheme.lightAccent, equals(const Color(0xFF7B61FF)));
      expect(AppTheme.lightTextPrimary, equals(const Color(0xFF111827)));
      expect(AppTheme.lightTextSecondary, equals(const Color(0xFF4B5563)));
    });

    test('Dark Theme matches specification hex colors', () {
      expect(AppTheme.darkBg, equals(const Color(0xFF0B1020)));
      expect(AppTheme.darkSecBg, equals(const Color(0xFF12131A)));
      expect(AppTheme.darkPrimary, equals(const Color(0xFF7A6EFF)));
      expect(AppTheme.darkAccent, equals(const Color(0xFF5E5CFF)));
      expect(AppTheme.darkTextPrimary, equals(const Color(0xFFFFFFFF)));
      expect(AppTheme.darkTextSecondary, equals(const Color(0xFFD1D5DB)));
    });
  });
}
