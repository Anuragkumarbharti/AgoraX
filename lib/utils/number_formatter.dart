import 'dart:math';

/// Global standard number formatter for compact numeric notation across the app.
///
/// Rules:
/// - 0 to 999: Exact number (e.g. 0, 1, 56, 999)
/// - 1,000 to 999,999: K suffix (rounded to 1 decimal place, trailing .0 omitted)
/// - 1,000,000 to 999,999,999: M suffix (rounded to 1 decimal place, trailing .0 omitted)
/// - 1,000,000,000+: B suffix (rounded to 1 decimal place, trailing .0 omitted)
///
/// Applies consistently for Coins, Gold, Silver, Diamonds, Followers, Following,
/// Friends, Likes, Views, Downloads, XP, Stars, Gifts, Members, etc.
String formatCompactNumber(num value) {
  if (value.isNaN || value.isInfinite) return '0';

  if (value < 0) {
    return '-${formatCompactNumber(-value)}';
  }

  final double val = value.toDouble();

  if (val < 1000) {
    if (value is int || val % 1 == 0) {
      return val.toInt().toString();
    }
    return _stripTrailingZero(val.toStringAsFixed(1));
  }

  // Threshold check to avoid rounding artifacts like 999.95K -> 1000K instead of 1M
  if (val >= 999950000) {
    final double b = val / 1000000000.0;
    final double rounded = (b * 10).round() / 10.0;
    return _formatWithSuffix(rounded, 'B');
  }

  if (val >= 999950) {
    final double m = val / 1000000.0;
    final double rounded = (m * 10).round() / 10.0;
    if (rounded >= 1000) {
      return _formatWithSuffix(rounded / 1000.0, 'B');
    }
    return _formatWithSuffix(rounded, 'M');
  }

  final double k = val / 1000.0;
  final double rounded = (k * 10).round() / 10.0;
  if (rounded >= 1000) {
    return _formatWithSuffix(rounded / 1000.0, 'M');
  }
  return _formatWithSuffix(rounded, 'K');
}

String _formatWithSuffix(double roundedVal, String suffix) {
  final String str = roundedVal.toStringAsFixed(1);
  return '${_stripTrailingZero(str)}$suffix';
}

String _stripTrailingZero(String formattedNumber) {
  if (formattedNumber.endsWith('.0')) {
    return formattedNumber.substring(0, formattedNumber.length - 2);
  }
  return formattedNumber;
}
