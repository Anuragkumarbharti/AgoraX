import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? blur;
  final double borderWidth;
  final List<BoxShadow>? customShadows;

  const GlassCard({
    Key? key,
    required this.child,
    this.borderRadius = 24.0, // Enforces WWDC 24px card radius
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.blur, // Dynamic based on theme if null
    this.borderWidth = 1.0,
    this.customShadows,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final double resolvedBlur = blur ?? (isDark ? 25.0 : 28.0); // Enforces WWDC 25-28px blur
    
    // Resolve dynamic shadow based on specified styling rules
    final List<BoxShadow> resolvedShadows = customShadows ?? [
      if (isDark)
        BoxShadow(
          color: AppTheme.darkShadow, // rgba(0,0,0,0.40)
          blurRadius: 24,
          spreadRadius: -4,
          offset: const Offset(0, 12),
        )
      else
        BoxShadow(
          color: AppTheme.lightShadow, // rgba(0,0,0,0.04)
          blurRadius: 20,
          spreadRadius: -4,
          offset: const Offset(0, 10),
        ),
    ];

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: resolvedShadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: resolvedBlur, sigmaY: resolvedBlur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: context.glassSurfaceColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: context.borderColor,
                width: borderWidth,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isDark 
                      ? AppTheme.darkReflection 
                      : AppTheme.lightReflection,
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
