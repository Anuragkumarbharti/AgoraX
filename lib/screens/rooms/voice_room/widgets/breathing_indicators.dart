import 'package:flutter/material.dart';

class PulsingOnlineIndicator extends StatefulWidget {
  const PulsingOnlineIndicator({Key? key}) : super(key: key);
  @override
  State<PulsingOnlineIndicator> createState() => _PulsingOnlineIndicatorState();
}

class _PulsingOnlineIndicatorState extends State<PulsingOnlineIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF10B981),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981)
                    .withOpacity(0.2 + 0.6 * _animationController.value),
                blurRadius: 4 + 4 * _animationController.value,
                spreadRadius: 1 + 2 * _animationController.value,
              )
            ],
            border: Border.all(color: const Color(0xFF1F1B2C), width: 2),
          ),
        );
      },
    );
  }
}

class BreathingVTag extends StatefulWidget {
  final String level;
  final VoidCallback? onTap;

  const BreathingVTag({
    Key? key,
    required this.level,
    this.onTap,
  }) : super(key: key);

  @override
  State<BreathingVTag> createState() => _BreathingVTagState();
}

class _BreathingVTagState extends State<BreathingVTag>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.15), weight: 50),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.15, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _startPeriodicTimer();
  }

  void _startPeriodicTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return false;
      _controller.forward(from: 0.0);
      return true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String checkIcon = '✓';

    switch (widget.level.toLowerCase()) {
      case 'diamond':
        badgeColor = const Color(0xFFE2E8F0);
        break;
      case 'gold':
        badgeColor = const Color(0xFFFFB020);
        break;
      case 'purple':
        badgeColor = const Color(0xFF8B5CFF);
        break;
      case 'blue':
      default:
        badgeColor = const Color(0xFF00C2FF);
        break;
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: 'Verified ${widget.level.toUpperCase()}',
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badgeColor.withOpacity(0.2),
              border: Border.all(color: badgeColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                )
              ],
            ),
            child: Center(
              child: Text(
                checkIcon,
                style: TextStyle(
                  color: widget.level.toLowerCase() == 'diamond'
                      ? Colors.cyanAccent
                      : badgeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BreathingWidget extends StatefulWidget {
  final Widget child;
  const BreathingWidget({Key? key, required this.child}) : super(key: key);

  @override
  State<BreathingWidget> createState() => _BreathingWidgetState();
}

class _BreathingWidgetState extends State<BreathingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scaleAnimation, child: widget.child);
  }
}

class PulseWidget extends StatefulWidget {
  final Widget child;
  const PulseWidget({Key? key, required this.child}) : super(key: key);

  @override
  State<PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<PulseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacityAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacityAnimation, child: widget.child);
  }
}
