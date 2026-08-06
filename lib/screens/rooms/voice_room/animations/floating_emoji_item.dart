import 'dart:math';
import 'package:flutter/material.dart';
import '../models/floating_reaction.dart';

class FloatingEmojiItem extends StatefulWidget {
  final FloatingReaction reaction;
  const FloatingEmojiItem({required this.reaction, Key? key})
      : super(key: key);

  @override
  State<FloatingEmojiItem> createState() => _FloatingEmojiItemState();
}

class _FloatingEmojiItemState extends State<FloatingEmojiItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _yAnim;
  late Animation<double> _xAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _yAnim = Tween<double>(begin: 0.0, end: 320.0).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _xAnim = Tween<double>(begin: 0.0, end: 25.0).animate(
        CurvedAnimation(parent: _animController, curve: Curves.elasticOut));
    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
        parent: _animController, curve: const Interval(0.6, 1.0)));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Positioned(
          bottom: 120 + _yAnim.value,
          left: widget.reaction.startX +
              sin(_animController.value * pi * 2.5) * _xAnim.value,
          child: Opacity(
            opacity: _fadeAnim.value,
            child: Text(
              widget.reaction.emoji,
              style: TextStyle(fontSize: widget.reaction.size),
            ),
          ),
        );
      },
    );
  }
}
