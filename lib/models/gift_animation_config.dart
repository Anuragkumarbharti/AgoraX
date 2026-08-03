// lib/models/gift_animation_config.dart

import 'package:flutter/material.dart';

enum ParticleEffectType {
  emojiBurst,
  rosePetals,
  heartBurst,
  risingSteam,
  confettiPop,
  diamondPrism,
  goldenCrown,
  butterflyFlight,
  sportsCarDrive,
  privateJetFly,
}

class GiftAnimationConfig {
  final String animationKey; // Identifier for developer mapping (e.g. 'gift_sports_car')
  final String name; // Human-readable animation name
  final String emoji; // Default emoji representation
  final Color color; // Ambient theme glow color
  final ParticleEffectType effectType; // High-FPS native canvas effect fallback
  final String? customLottiePath; // Optional path (e.g. 'assets/animations/gifts/gift_sports_car.json')
  final String? customPagPath; // Optional PAG path (e.g. 'assets/animations/gifts/gift_sports_car.pag')
  final Duration duration; // Duration of overlay animation

  const GiftAnimationConfig({
    required this.animationKey,
    required this.name,
    required this.emoji,
    required this.color,
    required this.effectType,
    this.customLottiePath,
    this.customPagPath,
    this.duration = const Duration(milliseconds: 3200),
  });
}

class GiftAnimationRegistry {
  static final Map<String, GiftAnimationConfig> _registry = {
    // Gold Gifts
    'a2000000-0000-0000-0000-000000000001': const GiftAnimationConfig(
      animationKey: 'gift_like',
      name: 'Thumbs Up Pop',
      emoji: '👍',
      color: Colors.blueAccent,
      effectType: ParticleEffectType.emojiBurst,
      customLottiePath: 'assets/animations/gifts/gift_like.json',
    ),
    'a2000000-0000-0000-0000-000000000002': const GiftAnimationConfig(
      animationKey: 'gift_flower',
      name: 'Floral Bloom',
      emoji: '🌼',
      color: Colors.orange,
      effectType: ParticleEffectType.rosePetals,
      customLottiePath: 'assets/animations/gifts/gift_flower.json',
    ),
    'a2000000-0000-0000-0000-000000000003': const GiftAnimationConfig(
      animationKey: 'gift_rose',
      name: 'Rose Bloom & Petals Cascade',
      emoji: '🌹',
      color: Colors.pinkAccent,
      effectType: ParticleEffectType.rosePetals,
      customLottiePath: 'assets/animations/gifts/gift_rose.json',
    ),
    'a2000000-0000-0000-0000-000000000004': const GiftAnimationConfig(
      animationKey: 'gift_heart',
      name: 'Heart Pulsing Burst',
      emoji: '❤️',
      color: Colors.redAccent,
      effectType: ParticleEffectType.heartBurst,
      customLottiePath: 'assets/animations/gifts/gift_heart.json',
    ),
    'a2000000-0000-0000-0000-000000000005': const GiftAnimationConfig(
      animationKey: 'gift_coffee',
      name: 'Warm Steam Coffee',
      emoji: '☕',
      color: Colors.brown,
      effectType: ParticleEffectType.risingSteam,
      customLottiePath: 'assets/animations/gifts/gift_coffee.json',
    ),
    'a2000000-0000-0000-0000-000000000006': const GiftAnimationConfig(
      animationKey: 'gift_chocolate',
      name: 'Sweet Chocolate Burst',
      emoji: '🍫',
      color: Colors.amber,
      effectType: ParticleEffectType.emojiBurst,
      customLottiePath: 'assets/animations/gifts/gift_chocolate.json',
    ),
    'a2000000-0000-0000-0000-000000000007': const GiftAnimationConfig(
      animationKey: 'gift_cake',
      name: 'Birthday Candles & Confetti',
      emoji: '🎂',
      color: Colors.pink,
      effectType: ParticleEffectType.confettiPop,
      customLottiePath: 'assets/animations/gifts/gift_cake.json',
    ),
    'a2000000-0000-0000-0000-000000000008': const GiftAnimationConfig(
      animationKey: 'gift_balloon',
      name: 'Floating Balloons Upward Flight',
      emoji: '🎈',
      color: Colors.purpleAccent,
      effectType: ParticleEffectType.emojiBurst,
      customLottiePath: 'assets/animations/gifts/gift_balloon.json',
    ),
    'a2000000-0000-0000-0000-000000000009': const GiftAnimationConfig(
      animationKey: 'gift_box',
      name: 'Gift Box Open Explosion',
      emoji: '🎁',
      color: Colors.red,
      effectType: ParticleEffectType.confettiPop,
      customLottiePath: 'assets/animations/gifts/gift_box.json',
    ),
    'a2000000-0000-0000-0000-000000000010': const GiftAnimationConfig(
      animationKey: 'gift_diamond',
      name: 'Crystalline Prism Rays',
      emoji: '💎',
      color: Colors.cyan,
      effectType: ParticleEffectType.diamondPrism,
      customLottiePath: 'assets/animations/gifts/gift_diamond.json',
    ),
    'a2000000-0000-0000-0000-000000000011': const GiftAnimationConfig(
      animationKey: 'gift_crown',
      name: 'Golden Royalty Halo',
      emoji: '👑',
      color: Colors.amber,
      effectType: ParticleEffectType.goldenCrown,
      customLottiePath: 'assets/animations/gifts/gift_crown.json',
    ),
    'a2000000-0000-0000-0000-000000000012': const GiftAnimationConfig(
      animationKey: 'gift_butterfly',
      name: 'Fluttering Wing Trail',
      emoji: '🦋',
      color: Colors.deepPurpleAccent,
      effectType: ParticleEffectType.butterflyFlight,
      customLottiePath: 'assets/animations/gifts/gift_butterfly.json',
    ),
    'a2000000-0000-0000-0000-000000000013': const GiftAnimationConfig(
      animationKey: 'gift_sports_car',
      name: 'Neon Supercar Speed Drive',
      emoji: '🏎️',
      color: Colors.deepOrange,
      effectType: ParticleEffectType.sportsCarDrive,
      customLottiePath: 'assets/animations/gifts/gift_sports_car.json',
    ),
    'a2000000-0000-0000-0000-000000000014': const GiftAnimationConfig(
      animationKey: 'gift_private_jet',
      name: 'Jet Altitude Vapor Pass',
      emoji: '✈️',
      color: Colors.cyanAccent,
      effectType: ParticleEffectType.privateJetFly,
      customLottiePath: 'assets/animations/gifts/gift_private_jet.json',
    ),

    // Silver Gifts
    'a2000000-0000-0000-0000-000000000021': const GiftAnimationConfig(
      animationKey: 'gift_like_silver',
      name: 'Silver Like Pop',
      emoji: '👍',
      color: Colors.blueAccent,
      effectType: ParticleEffectType.emojiBurst,
    ),
    'a2000000-0000-0000-0000-000000000022': const GiftAnimationConfig(
      animationKey: 'gift_flower_silver',
      name: 'Silver Flower Bloom',
      emoji: '🌼',
      color: Colors.orange,
      effectType: ParticleEffectType.rosePetals,
    ),
    'a2000000-0000-0000-0000-000000000023': const GiftAnimationConfig(
      animationKey: 'gift_rose_silver',
      name: 'Silver Rose Cascade',
      emoji: '🌹',
      color: Colors.pink,
      effectType: ParticleEffectType.rosePetals,
    ),
    'a2000000-0000-0000-0000-000000000024': const GiftAnimationConfig(
      animationKey: 'gift_heart_silver',
      name: 'Silver Heart Pulsing',
      emoji: '❤️',
      color: Colors.redAccent,
      effectType: ParticleEffectType.heartBurst,
    ),
    'a2000000-0000-0000-0000-000000000025': const GiftAnimationConfig(
      animationKey: 'gift_coffee_silver',
      name: 'Silver Coffee Steam',
      emoji: '☕',
      color: Colors.brown,
      effectType: ParticleEffectType.risingSteam,
    ),
    'a2000000-0000-0000-0000-000000000026': const GiftAnimationConfig(
      animationKey: 'gift_chocolate_silver',
      name: 'Silver Chocolate Burst',
      emoji: '🍫',
      color: Colors.amber,
      effectType: ParticleEffectType.emojiBurst,
    ),
    'a2000000-0000-0000-0000-000000000027': const GiftAnimationConfig(
      animationKey: 'gift_cake_silver',
      name: 'Silver Cake Confetti',
      emoji: '🎂',
      color: Colors.pink,
      effectType: ParticleEffectType.confettiPop,
    ),
    'a2000000-0000-0000-0000-000000000028': const GiftAnimationConfig(
      animationKey: 'gift_balloon_silver',
      name: 'Silver Balloons Float',
      emoji: '🎈',
      color: Colors.purpleAccent,
      effectType: ParticleEffectType.emojiBurst,
    ),
    'a2000000-0000-0000-0000-000000000029': const GiftAnimationConfig(
      animationKey: 'gift_box_silver',
      name: 'Silver Gift Box Open',
      emoji: '🎁',
      color: Colors.red,
      effectType: ParticleEffectType.confettiPop,
    ),
    'a2000000-0000-0000-0000-000000000030': const GiftAnimationConfig(
      animationKey: 'gift_diamond_silver',
      name: 'Silver Diamond Light Beam',
      emoji: '💎',
      color: Colors.cyan,
      effectType: ParticleEffectType.diamondPrism,
    ),
  };

  /// Gets the animation configuration for a gift ID or gift name.
  static GiftAnimationConfig getConfig(String giftIdOrName) {
    if (_registry.containsKey(giftIdOrName)) {
      return _registry[giftIdOrName]!;
    }
    // Search by name fallback
    final nameMatch = _registry.values.firstWhere(
      (c) => c.name.toLowerCase().contains(giftIdOrName.toLowerCase()) || c.animationKey.contains(giftIdOrName.toLowerCase()),
      orElse: () => GiftAnimationConfig(
        animationKey: 'gift_generic',
        name: giftIdOrName,
        emoji: '🎁',
        color: const Color(0xFF8B5CF6),
        effectType: ParticleEffectType.emojiBurst,
      ),
    );
    return nameMatch;
  }
}
