import 'dart:math' as math;
import 'package:flutter/material.dart';

class VipAvatarDecorator extends StatefulWidget {
  final int level;
  final double size;
  final Widget child;

  const VipAvatarDecorator({
    Key? key,
    required this.level,
    this.size = 90,
    required this.child,
  }) : super(key: key);

  @override
  State<VipAvatarDecorator> createState() => _VipAvatarDecoratorState();
}

class _VipAvatarDecoratorState extends State<VipAvatarDecorator> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant VipAvatarDecorator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_rotationController.isAnimating) _rotationController.repeat();
    if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.level <= 0) {
      return Container(
        width: widget.size,
        height: widget.size,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: widget.child,
      );
    }

    Widget mainAvatar = ClipRRect(
      borderRadius: BorderRadius.circular(widget.size),
      child: widget.child,
    );

    // Apply specific level styling
    switch (widget.level) {
      case 1:
        // Royal Blue Animated Border
        return AnimatedBuilder(
          animation: Listenable.merge([_rotationController, _pulseController]),
          builder: (context, child) {
            final pulseVal = 0.8 + (0.2 * _pulseController.value);
            return Container(
              width: widget.size,
              height: widget.size,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    const Color(0xFF2563EB),
                    const Color(0xFF1E40AF).withOpacity(pulseVal),
                    const Color(0xFF2563EB),
                  ],
                  transform: GradientRotation(_rotationController.value * 2 * math.pi),
                ),
              ),
              child: Container(
                decoration: const BoxDecoration(color: Color(0xFF09090B), shape: BoxShape.circle),
                padding: const EdgeInsets.all(1),
                child: mainAvatar,
              ),
            );
          },
        );

      case 2:
        // Animated Purple ring
        return AnimatedBuilder(
          animation: Listenable.merge([_rotationController, _pulseController]),
          builder: (context, child) {
            final pulseVal = 0.7 + (0.3 * _pulseController.value);
            return Container(
              width: widget.size,
              height: widget.size,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    const Color(0xFF8B5CF6),
                    const Color(0xFFC084FC).withOpacity(pulseVal),
                    const Color(0xFF8B5CF6),
                  ],
                  transform: GradientRotation(_rotationController.value * 2 * math.pi),
                ),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF09090B),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: mainAvatar,
              ),
            );
          },
        );

      case 3:
        // Gold Glow Border
        return AnimatedBuilder(
          animation: Listenable.merge([_rotationController, _pulseController]),
          builder: (context, child) {
            final glowVal = 8.0 + (6.0 * _pulseController.value);
            return Container(
              width: widget.size,
              height: widget.size,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: const [
                    Color(0xFFFFD700),
                    Color(0xFFB45309),
                    Color(0xFFFFD700),
                  ],
                  transform: GradientRotation(_rotationController.value * 2 * math.pi),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.35 + (0.15 * _pulseController.value)),
                    blurRadius: glowVal,
                    spreadRadius: 1.5,
                  )
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(color: Color(0xFF09090B), shape: BoxShape.circle),
                padding: const EdgeInsets.all(2),
                child: mainAvatar,
              ),
            );
          },
        );

      case 4:
        // Diamond White Border
        return AnimatedBuilder(
          animation: Listenable.merge([_rotationController, _pulseController]),
          builder: (context, child) {
            return Container(
              width: widget.size,
              height: widget.size,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: const [
                    Color(0xFFF1F5F9),
                    Colors.white,
                    Color(0xFFCBD5E1),
                    Color(0xFFF1F5F9),
                  ],
                  transform: GradientRotation(_rotationController.value * 2 * math.pi),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.20 + (0.15 * _pulseController.value)),
                    blurRadius: 7.0 + (5.0 * _pulseController.value),
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(color: Color(0xFF09090B), shape: BoxShape.circle),
                padding: const EdgeInsets.all(2),
                child: mainAvatar,
              ),
            );
          },
        );

      case 5:
        // Crystal Cyan Border
        return AnimatedBuilder(
          animation: Listenable.merge([_rotationController, _pulseController]),
          builder: (context, child) {
            return Container(
              width: widget.size,
              height: widget.size,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: const [
                    Color(0xFF06B6D4),
                    Colors.white,
                    Color(0xFF0891B2),
                    Color(0xFF06B6D4),
                  ],
                  transform: GradientRotation(_rotationController.value * 2 * math.pi),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withOpacity(0.35 + (0.15 * _pulseController.value)),
                    blurRadius: 10.0 + (6.0 * _pulseController.value),
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(color: Color(0xFF09090B), shape: BoxShape.circle),
                padding: const EdgeInsets.all(2),
                child: mainAvatar,
              ),
            );
          },
        );

      case 6:
        // Rainbow Animated Border
        return AnimatedBuilder(
          animation: Listenable.merge([_rotationController, _pulseController]),
          builder: (context, child) {
            return Container(
              width: widget.size,
              height: widget.size,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: const [
                    Color(0xFFFF007F),
                    Color(0xFFFFBF00),
                    Color(0xFF00F0FF),
                    Color(0xFFFF007F),
                  ],
                  transform: GradientRotation(_rotationController.value * 2 * math.pi),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3 + (0.2 * _pulseController.value)),
                    blurRadius: 10.0 + (8.0 * _pulseController.value),
                  )
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF09090B),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: mainAvatar,
              ),
            );
          },
        );

      case 7:
        // Legendary Black + Gold with Floating Crown
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Rotating Gold Aura
            AnimatedBuilder(
              animation: Listenable.merge([_rotationController, _pulseController]),
              builder: (context, child) {
                return Container(
                  width: widget.size,
                  height: widget.size,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: const [
                        Color(0xFFFFD700),
                        Color(0xFF1C1917),
                        Color(0xFFFFD700),
                      ],
                      transform: GradientRotation(_rotationController.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.55 + (0.15 * _pulseController.value)),
                        blurRadius: 14 + (6 * _pulseController.value),
                        spreadRadius: 2.5,
                      )
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF09090B),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: mainAvatar,
                  ),
                );
              },
            ),
            // Floating Crown on Top Left
            Positioned(
              top: -18,
              left: -6,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final angle = -0.22 + (0.05 * math.sin(_pulseController.value * math.pi));
                  return Transform.rotate(
                    angle: angle,
                    child: const Text(
                      '👑',
                      style: TextStyle(
                        fontSize: 28,
                        shadows: [
                          Shadow(color: Color(0xFFFFD700), blurRadius: 10),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );

      default:
        return mainAvatar;
    }
  }
}
