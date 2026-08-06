import 'package:flutter/material.dart';

class FloatingReaction {
  final Key key;
  final String emoji;
  final double startX;
  final double speed;
  final double size;

  FloatingReaction({
    required this.key,
    required this.emoji,
    required this.startX,
    required this.speed,
    required this.size,
  });
}
