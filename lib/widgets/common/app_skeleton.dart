import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme.dart';

/// Centralized universal skeleton loader system.
/// Adaptive shimmer colors, 60 FPS performance, no layout shift.
class AppSkeleton extends StatelessWidget {
  final Widget child;

  const AppSkeleton({Key? key, required this.child}) : super(key: key);

  static Widget shimmer({
    required Widget child,
    required BuildContext context,
    Color? baseColor,
    Color? highlightColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBase = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final defaultHighlight = isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC);

    return Shimmer.fromColors(
      baseColor: baseColor ?? defaultBase,
      highlightColor: highlightColor ?? defaultHighlight,
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }

  static Widget circle({
    required double size,
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
      ),
    );
  }

  static Widget line({
    required double width,
    required double height,
    required BuildContext context,
    double borderRadius = 6.0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
      ),
    );
  }

  static Widget box({
    required double width,
    required double height,
    required BuildContext context,
    double borderRadius = 12.0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSkeleton.shimmer(context: context, child: child);
  }
}
