// lib/services/gifting/particle_pool_manager.dart

import 'dart:math';
import 'package:flutter/material.dart';

class ParticleObject {
  Offset position;
  Offset velocity;
  double scale;
  double opacity;
  double rotation;
  Color color;
  double life; // 1.0 -> 0.0
  double maxLife;

  ParticleObject({
    required this.position,
    required this.velocity,
    required this.scale,
    required this.opacity,
    required this.rotation,
    required this.color,
    required this.life,
    required this.maxLife,
  });
}

/// Object pool for GPU-accelerated particle systems preventing GC spikes
class ParticlePoolManager {
  static final ParticlePoolManager instance = ParticlePoolManager._internal();
  ParticlePoolManager._internal();

  final List<ParticleObject> _pool = [];
  final Random _random = Random();

  ParticleObject getParticle({
    required Offset origin,
    required Color color,
    required double speedMultiplier,
  }) {
    final double angle = _random.nextDouble() * 2 * pi;
    final double speed = (_random.nextDouble() * 60 + 20) * speedMultiplier;
    final velocity = Offset(cos(angle) * speed, sin(angle) * speed);
    final double life = _random.nextDouble() * 0.5 + 0.5;

    if (_pool.isNotEmpty) {
      final p = _pool.removeLast();
      p.position = origin;
      p.velocity = velocity;
      p.scale = _random.nextDouble() * 10 + 4;
      p.opacity = 1.0;
      p.rotation = _random.nextDouble() * 2 * pi;
      p.color = color;
      p.life = life;
      p.maxLife = life;
      return p;
    } else {
      return ParticleObject(
        position: origin,
        velocity: velocity,
        scale: _random.nextDouble() * 10 + 4,
        opacity: 1.0,
        rotation: _random.nextDouble() * 2 * pi,
        color: color,
        life: life,
        maxLife: life,
      );
    }
  }

  void recycle(ParticleObject particle) {
    if (_pool.length < 200) {
      _pool.add(particle);
    }
  }

  void recycleAll(List<ParticleObject> particles) {
    for (final p in particles) {
      recycle(p);
    }
    particles.clear();
  }
}
