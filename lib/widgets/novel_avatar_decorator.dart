import 'dart:math' as math;
import 'package:flutter/material.dart';

class NovelAvatarDecorator extends StatefulWidget {
  final int level;
  final double size;
  final Widget child;

  const NovelAvatarDecorator({
    Key? key,
    required this.level,
    this.size = 90,
    required this.child,
  }) : super(key: key);

  @override
  State<NovelAvatarDecorator> createState() => _NovelAvatarDecoratorState();
}

class _NovelAvatarDecoratorState extends State<NovelAvatarDecorator> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant NovelAvatarDecorator oldWidget) {
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

    switch (widget.level) {
      case 1:
        // Novel 1 (Classic Royal Blue Border with rotating soft sweep)
        return AnimatedBuilder(
          animation: Listenable.merge([_rotationController, _pulseController]),
          builder: (context, child) {
            final pulseVal = 0.8 + (0.2 * _pulseController.value);
            return Container(
              width: widget.size,
              height: widget.size,
              padding: const EdgeInsets.all(3.5),
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
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.2 + 0.15 * _pulseController.value),
                    blurRadius: 6.0 + (4.0 * _pulseController.value),
                    spreadRadius: 1,
                  )
                ],
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
        // Novel 2 (Purple Galaxy Orbit with stars)
        return Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
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
                        Color(0xFF7C3AED),
                        Color(0xFFC084FC),
                        Color(0xFF4C1D95),
                        Color(0xFF7C3AED),
                      ],
                      transform: GradientRotation(_rotationController.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withOpacity(0.35 + 0.15 * _pulseController.value),
                        blurRadius: 10 + 5 * _pulseController.value,
                        spreadRadius: 1.5,
                      )
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF09090B),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: mainAvatar,
                  ),
                );
              },
            ),
            // Floating Orbiting Star
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                final angle = _rotationController.value * 2 * math.pi;
                final radius = widget.size / 2;
                return Positioned(
                  left: radius + (radius - 2) * math.cos(angle) - 6,
                  top: radius + (radius - 2) * math.sin(angle) - 6,
                  child: const Text('⭐', style: TextStyle(fontSize: 10)),
                );
              },
            ),
          ],
        );

      case 3:
        // Novel 3 (Royal Gold Palace + Floating Crown)
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Golden Aura pulsing + rotating sweep
            AnimatedBuilder(
              animation: Listenable.merge([_rotationController, _pulseController]),
              builder: (context, child) {
                final pulse = _pulseController.value;
                return Container(
                  width: widget.size,
                  height: widget.size,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: const [
                        Color(0xFFFFD700),
                        Color(0xFFD97706),
                        Color(0xFFFFD700),
                      ],
                      transform: GradientRotation(_rotationController.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withOpacity(0.25 + 0.20 * pulse),
                        blurRadius: 10 + 6 * pulse,
                        spreadRadius: 1 + 2 * pulse,
                      )
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(color: Color(0xFF09090B), shape: BoxShape.circle),
                    padding: const EdgeInsets.all(2.5),
                    child: mainAvatar,
                  ),
                );
              },
            ),
            // Floating Gold Crown
            Positioned(
              top: -18,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (0.08 * _pulseController.value);
                  return Transform.scale(
                    scale: scale,
                    child: const Text(
                      '👑',
                      style: TextStyle(
                        fontSize: 26,
                        shadows: [
                          Shadow(color: Color(0xFFFFD700), blurRadius: 12),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );

      case 4:
        // Novel 4 (Dragon Fire Red Border + Wings + Fire Aura)
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Left Wing Pulsing
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final offset = -14.0 - (3.0 * _pulseController.value);
                return Positioned(
                  left: offset,
                  child: const Text('🔥', style: TextStyle(fontSize: 20)),
                );
              },
            ),
            // Right Wing Pulsing
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final offset = -14.0 - (3.0 * _pulseController.value);
                return Positioned(
                  right: offset,
                  child: Transform.scale(
                    scaleX: -1,
                    child: const Text('🔥', style: TextStyle(fontSize: 20)),
                  ),
                );
              },
            ),
            // Crimson Flame Border
            AnimatedBuilder(
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
                        Color(0xFFDC2626),
                        Color(0xFFEF4444),
                        Color(0xFF7F1D1D),
                        Color(0xFFDC2626),
                      ],
                      transform: GradientRotation(_rotationController.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withOpacity(0.4 + 0.20 * _pulseController.value),
                        blurRadius: 12.0 + (6.0 * _pulseController.value),
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(color: Color(0xFF09090B), shape: BoxShape.circle),
                    padding: const EdgeInsets.all(2.5),
                    child: mainAvatar,
                  ),
                );
              },
            ),
          ],
        );

      case 5:
        // Novel 5 (Phoenix Wings + Pulse flame + Orbiting particles)
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Phoenix feather wing decoration
            Positioned(
              left: -16,
              child: const Text('🪶', style: TextStyle(fontSize: 24, color: Colors.orangeAccent)),
            ),
            Positioned(
              right: -16,
              child: Transform.scale(
                scaleX: -1,
                child: const Text('🪶', style: TextStyle(fontSize: 24, color: Colors.orangeAccent)),
              ),
            ),
            AnimatedBuilder(
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
                        Color(0xFFEA580C),
                        Color(0xFFF97316),
                        Color(0xFFFDBA74),
                        Color(0xFFEA580C),
                      ],
                      transform: GradientRotation(_rotationController.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF97316).withOpacity(0.45 + (0.15 * _pulseController.value)),
                        blurRadius: 12.0 + (6.0 * _pulseController.value),
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF09090B),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: mainAvatar,
                  ),
                );
              },
            ),
          ],
        );

      case 6:
        // Novel 6 (Celestial Diamond Sky with rotating light and twinkles)
        return AnimatedBuilder(
          animation: Listenable.merge([_rotationController, _pulseController]),
          builder: (context, child) {
            return Container(
              width: widget.size,
              height: widget.size,
              padding: const EdgeInsets.all(4.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: const [
                    Color(0xFF06B6D4),
                    Colors.white,
                    Color(0xFF22D3EE),
                    Color(0xFF06B6D4),
                  ],
                  transform: GradientRotation(_rotationController.value * 2 * math.pi),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withOpacity(0.45 + (0.15 * _pulseController.value)),
                    blurRadius: 16.0 + (6.0 * _pulseController.value),
                    spreadRadius: 3,
                  ),
                  const BoxShadow(
                    color: Colors.white24,
                    blurRadius: 6,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  mainAvatar,
                  // Twinkling stars overlay
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Opacity(
                      opacity: _pulseController.value,
                      child: const Text('✨', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ),
            );
          },
        );

      case 7:
        // Novel 7 (Immortal Cosmic Black-Gold + Rotate Aura with Twinkles)
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Sweeping aura background
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
                        Color(0xFF000000),
                        Color(0xFFFFD700),
                      ],
                      transform: GradientRotation(_rotationController.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.55 + 0.15 * _pulseController.value),
                        blurRadius: 20 + 8 * _pulseController.value,
                        spreadRadius: 4,
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
              left: -8,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final angle = -0.22 + (0.05 * math.sin(_pulseController.value * math.pi));
                  return Transform.rotate(
                    angle: angle,
                    child: const Text(
                      '👑',
                      style: TextStyle(
                        fontSize: 30,
                        shadows: [
                          Shadow(color: Color(0xFFFFD700), blurRadius: 14),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Sparkle stars
            Positioned(
              bottom: 4,
              right: -6,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Opacity(
                    opacity: 0.5 + 0.5 * _pulseController.value,
                    child: const Text('✨', style: TextStyle(fontSize: 16)),
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
