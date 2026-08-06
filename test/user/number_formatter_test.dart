import 'package:flutter_test/flutter_test.dart';
import 'package:creania/utils/number_formatter.dart';

void main() {
  group('formatCompactNumber Tests', () {
    test('Exact numbers below 1000', () {
      expect(formatCompactNumber(0), equals('0'));
      expect(formatCompactNumber(1), equals('1'));
      expect(formatCompactNumber(56), equals('56'));
      expect(formatCompactNumber(999), equals('999'));
    });

    test('Thousands (K) rounding and formatting', () {
      expect(formatCompactNumber(1000), equals('1K'));
      expect(formatCompactNumber(1249), equals('1.2K'));
      expect(formatCompactNumber(1250), equals('1.3K'));
      expect(formatCompactNumber(1450), equals('1.5K'));
      expect(formatCompactNumber(1500), equals('1.5K'));
      expect(formatCompactNumber(9999), equals('10K'));
      expect(formatCompactNumber(12300), equals('12.3K'));
      expect(formatCompactNumber(12400), equals('12.4K'));
      expect(formatCompactNumber(99999), equals('100K'));
      expect(formatCompactNumber(100000), equals('100K'));
    });

    test('Boundary 999,999 rolls over to 1M', () {
      expect(formatCompactNumber(999999), equals('1M'));
    });

    test('Millions (M) rounding and formatting', () {
      expect(formatCompactNumber(1000000), equals('1M'));
      expect(formatCompactNumber(1200000), equals('1.2M'));
      expect(formatCompactNumber(1250000), equals('1.3M'));
      expect(formatCompactNumber(15000000), equals('15M'));
      expect(formatCompactNumber(15600000), equals('15.6M'));
    });

    test('Boundary 999,999,999 rolls over to 1B', () {
      expect(formatCompactNumber(999999999), equals('1B'));
    });

    test('Billions (B) rounding and formatting', () {
      expect(formatCompactNumber(1000000000), equals('1B'));
      expect(formatCompactNumber(1500000000), equals('1.5B'));
      expect(formatCompactNumber(12700000000), equals('12.7B'));
    });
  });
}
