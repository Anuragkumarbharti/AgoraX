import 'package:flutter/material.dart';

/// Categorization of device screens based on logical pixel width
enum DeviceType {
  smallPhone, // < 360dp
  phone,      // 360dp - 414dp
  largePhone, // 414dp - 600dp
  tablet,     // 600dp - 900dp
  desktop,    // > 900dp
}

/// Breakpoint Constants
abstract class AppBreakpoints {
  static const double smallPhone = 360.0;
  static const double phone = 414.0;
  static const double largePhone = 600.0;
  static const double tablet = 900.0;
}

/// Spacing System Tokens
abstract class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

/// Border Radius System Tokens
abstract class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double round = 999.0;
}

/// Dimensions & Touch Target System Tokens
abstract class AppDimensions {
  static const double minTouchTarget = 48.0;
  static const double minButtonHeight = 48.0;
  static const double minIconSize = 20.0;
  static const double minFontSize = 12.0;
  static const double avatarRadiusNormal = 48.0;
  static const double avatarSizeFrame = 96.0;
}

/// Fixed Typography Scale Rules (No aggressive dynamic font shrinking below scale)
abstract class AppTypography {
  static const double display = 32.0;
  static const double h1 = 28.0;
  static const double h2 = 24.0;
  static const double h3 = 20.0;
  static const double title = 18.0;
  static const double subtitle = 16.0;
  static const double body = 15.0;
  static const double secondaryBody = 14.0;
  static const double caption = 12.5;
  static const double badge = 11.5;
  static const double button = 15.0;
}

/// Context Extensions for Responsive Categorization and Spacing Calculations
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  DeviceType get deviceType {
    final width = screenWidth;
    if (width < AppBreakpoints.smallPhone) return DeviceType.smallPhone;
    if (width < AppBreakpoints.phone) return DeviceType.phone;
    if (width < AppBreakpoints.largePhone) return DeviceType.largePhone;
    if (width < AppBreakpoints.tablet) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  bool get isSmallPhone => deviceType == DeviceType.smallPhone;
  bool get isTablet => deviceType == DeviceType.tablet || deviceType == DeviceType.desktop;

  /// Responsive horizontal margin scaling (increases margin on larger devices instead of shrinking text)
  double get horizontalPadding {
    switch (deviceType) {
      case DeviceType.smallPhone:
        return AppSpacing.md;
      case DeviceType.phone:
        return AppSpacing.lg;
      case DeviceType.largePhone:
        return AppSpacing.xl;
      case DeviceType.tablet:
      case DeviceType.desktop:
        return AppSpacing.xxl;
    }
  }

  /// Adaptive Grid Column counts for feeds, rooms, and card showcases
  int get gridColumnCount {
    switch (deviceType) {
      case DeviceType.smallPhone:
      case DeviceType.phone:
        return 2;
      case DeviceType.largePhone:
        return 3;
      case DeviceType.tablet:
        return 4;
      case DeviceType.desktop:
        return 6;
    }
  }
}

/// Widget Builder for adaptive layout switching based on device type
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({Key? key, required this.builder}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return builder(context, context.deviceType);
      },
    );
  }
}

/// Adaptive Grid Layout Widget that automatically adjusts columns without text shrinking
class ResponsiveGrid extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;

  const ResponsiveGrid({
    Key? key,
    required this.itemCount,
    required this.itemBuilder,
    this.mainAxisSpacing = AppSpacing.md,
    this.crossAxisSpacing = AppSpacing.md,
    this.childAspectRatio = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final columns = context.gridColumnCount;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
