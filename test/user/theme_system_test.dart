import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:creania/services/storage/theme_controller.dart';
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
    test('Default theme preference should be light mode', () {
      expect(themeController.currentThemePreference.value, equals('light'));
      expect(themeController.activeThemeMode, equals(ThemeMode.light));
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
      expect(AppTheme.lightBg, equals(const Color(0xFFF8FAFC)));
      expect(AppTheme.lightSecBg, equals(const Color(0xFFF1F5F9)));
      expect(AppTheme.lightPrimary, equals(const Color(0xFF6D5DF6)));
      expect(AppTheme.lightAccent, equals(const Color(0xFF6D5DF6)));
      expect(AppTheme.lightTextPrimary, equals(const Color(0xFF111827)));
      expect(AppTheme.lightTextSecondary, equals(const Color(0xFF374151)));
    });

    test('Dark Theme matches specification hex colors', () {
      expect(AppTheme.darkBg, equals(const Color(0xFF0F1115)));
      expect(AppTheme.darkSecBg, equals(const Color(0xFF161B22)));
      expect(AppTheme.darkPrimary, equals(const Color(0xFF7C6BFF)));
      expect(AppTheme.darkAccent, equals(const Color(0xFF7C6BFF)));
      expect(AppTheme.darkTextPrimary, equals(const Color(0xFFFFFFFF)));
      expect(AppTheme.darkTextSecondary, equals(const Color(0xFFE5E7EB)));
    });
  });
}
