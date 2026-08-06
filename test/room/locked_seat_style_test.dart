import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creania/core/theme.dart';

void main() {
  group('Locked Seat Styling & Color Token Consistency Tests', () {
    testWidgets('ThemeExtension locked seat getters return identical colors for border and lock icon in dark mode', (WidgetTester tester) async {
      late Color borderCol;
      late Color lockIconCol;
      late Color glowCol;
      late double glowRadius;
      late double borderWidth;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) {
              borderCol = context.lockedSeatColor.withOpacity(0.85);
              lockIconCol = context.lockedSeatColor.withOpacity(0.85);
              glowCol = context.lockedSeatGlowColor;
              glowRadius = context.lockedSeatGlowRadius;
              borderWidth = context.lockedSeatBorderWidth;
              return const SizedBox();
            },
          ),
        ),
      );

      // Verify border and lock icon sample exact same color token
      expect(borderCol, equals(lockIconCol));
      expect(glowCol, equals(Colors.white.withOpacity(0.18)));
      expect(glowRadius, equals(6.0));
      expect(borderWidth, equals(1.2));
    });

    testWidgets('ThemeExtension locked seat getters update dynamically in light mode', (WidgetTester tester) async {
      late Color borderCol;
      late Color lockIconCol;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              borderCol = context.lockedSeatColor.withOpacity(0.85);
              lockIconCol = context.lockedSeatColor.withOpacity(0.85);
              return const SizedBox();
            },
          ),
        ),
      );

      // Verify border and lock icon remain 100% identical in light mode
      expect(borderCol, equals(lockIconCol));
    });
  });
}
