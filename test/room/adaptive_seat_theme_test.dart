import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creania/core/theme.dart';
import 'package:creania/models/room/room_background_model.dart';

void main() {
  group('Adaptive Seat Theme Engine & Dynamic Token Tests', () {
    test('Dark room background generates high contrast, bright border, and high glow tokens', () {
      final bgDark = RoomBackgroundCatalog.allBackgrounds.firstWhere((b) => b.id == 'theme_1');
      final tokens = AdaptiveSeatThemeEngine.resolve(bgDark, isDarkMode: true);

      expect(tokens.isLightBackground, isFalse);
      expect(tokens.seatGlowRadius, greaterThanOrEqualTo(6.0));
      expect(tokens.usernameColor, equals(Colors.white));
      expect(tokens.usernameShadows, isNotEmpty);
      expect(tokens.lockIconColor.opacity, greaterThan(0.5));

      // Calculate WCAG contrast against typical dark background
      final contrast = AdaptiveSeatThemeEngine.calculateContrastRatio(tokens.usernameColor, const Color(0xFF0F172A));
      expect(contrast, greaterThanOrEqualTo(4.5));
    });

    test('Light room background automatically reduces glow and uses dark text & borders', () {
      const bgLight = RoomBackgroundItem(
        id: 'light_test',
        title: 'Light Test',
        assetPath: 'assets/backgroundroom/1.webp',
        isLightBackground: true,
      );
      final tokens = AdaptiveSeatThemeEngine.resolve(bgLight, isDarkMode: false);

      expect(tokens.isLightBackground, isTrue);
      expect(tokens.seatGlowRadius, lessThanOrEqualTo(3.0));
      expect(tokens.usernameColor, equals(const Color(0xFF111111)));
      expect(tokens.starIconColor, equals(const Color(0xFFD97706)));

      // Calculate WCAG contrast against light background
      final contrast = AdaptiveSeatThemeEngine.calculateContrastRatio(tokens.usernameColor, const Color(0xFFE2E8F0));
      expect(contrast, greaterThanOrEqualTo(4.5));
    });

    test('WCAG contrast enforcement helper guarantees minimum 4.5:1 ratio', () {
      final darkBg = const Color(0xFF020617);
      final lightBg = const Color(0xFFF8FAFC);

      final safeOnDark = AdaptiveSeatThemeEngine.ensureWcagContrast(const Color(0xFF1E293B), darkBg);
      final safeOnLight = AdaptiveSeatThemeEngine.ensureWcagContrast(const Color(0xFFE2E8F0), lightBg);

      expect(AdaptiveSeatThemeEngine.calculateContrastRatio(safeOnDark, darkBg), greaterThanOrEqualTo(4.5));
      expect(AdaptiveSeatThemeEngine.calculateContrastRatio(safeOnLight, lightBg), greaterThanOrEqualTo(4.5));
    });

    testWidgets('BuildContext.adaptiveSeatTheme returns dynamic tokens in widget hierarchy', (WidgetTester tester) async {
      late AdaptiveSeatThemeTokens resolvedTokens;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) {
              resolvedTokens = context.adaptiveSeatTheme;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedTokens, isNotNull);
      expect(resolvedTokens.isLightBackground, isFalse);
      expect(resolvedTokens.seatGlowRadius, equals(6.0));
    });
  });
}
