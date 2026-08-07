// lib/models/gift/gift_animation_metadata.dart

import 'package:flutter/material.dart';

enum GiftAnimationMode {
  roomSeat, // Audio Rooms, PK Rooms, Study Rooms, Live Rooms
  chat,     // Private Chat, Group Chat, Community Chat
}

enum GiftTier {
  tier1, // Tier 1: 2-4s (Rose, Heart, Coffee, Sakura, Lucky Star, etc.)
  tier2, // Tier 2: 4-6s (Bouquet, Birthday Cake, Diamond Ring, Crown, Golden Mic, Trophy, Crystal Diamond)
  tier3, // Tier 3: 6-8.5s (Fireworks, Super Car, Rocket, Private Jet, Treasure Chest)
  tier4, // Tier 4: 8-10s (Golden Dragon, Phoenix, Galaxy Portal, Crystal Castle)
  tier5, // Tier 5: 10s Premium Cinematic Showcase (Celestial Emperor, Planet Creation, World Tree, Infinity Cosmos)
}

enum FlightPathType {
  straight,
  curve,
  wave,
  spiral,
  infinity,
  orbit,
  bounce,
  zigzag,
}

enum ShowcaseAnimationType {
  popGlow,          // 🌹 Rose
  floatingHearts,   // ❤️ Heart
  steamFade,        // ☕ Coffee
  petalsBurst,      // 🌸 Sakura
  starTrail,        // ⭐ Lucky Star
  sweetSparkles,    // 🍫 Chocolate
  floatUp,          // 🎈 Balloon
  candleShine,      // 🍰 Cake
  butterflyTrail,   // 🦋 Butterfly
  heartTrail,       // 💌 Love Letter
  openShine,        // 🎁 Gift Box
  bounceHug,        // 🧸 Teddy
  greenGlow,        // 🍀 Lucky Clover
  moonlightEffect,  // 🌙 Moon
  sunRays,          // ☀️ Sunshine
  flowersBloom,     // 💐 Bouquet
  candleCelebration,// 🎂 Birthday Cake
  ringSpinShine,    // 💍 Diamond Ring
  goldenAura,       // 👑 Crown
  musicWaves,       // 🎤 Golden Mic
  trophyRise,       // 🏆 Champion Trophy
  crystalExplosion, // 💎 Crystal Diamond
  fireworksShow,    // 🎆 Fireworks
  driveAcrossScreen,// 🏎️ Super Car
  rocketLaunch,     // 🚀 Rocket
  flyOverScreen,    // ✈️ Private Jet
  goldBurst,        // 💰 Treasure Chest
  dragonFlies,      // 🐉 Golden Dragon
  phoenixFlames,    // 🔥 Phoenix
  galaxyPortal,     // 🌌 Galaxy Portal
  crystalCastle,    // 🏰 Crystal Castle
  celestialEmperor, // 👑 Celestial Emperor
  planetCreation,   // 🌍 Planet Creation
  worldTree,        // 🌳 World Tree
  infinityCosmos,   // 🌠 Infinity Cosmos
  genericGlow,
}

enum SeatEffectType {
  none,
  glow,
  pulse,
  bounce,
  fire,
  ice,
  lightning,
  flowerBloom,
  heartExplosion,
  steamPuff,
  sweetSparkle,
  popConfetti,
  swarmFlutter,
  candleFlare,
  prismBurst,
  ringSparkle,
  royalAura,
  goldenThroneGlow,
  fireAura,
  starRing,
  wheelSkid,
  windBurst,
  waterSplash,
  crystal,
  musicNotes,
  sparkles,
  boxExplosion,
  phoenixFlames,
  spacePortal,
  cosmicAurora,
}

enum ChatEffectType {
  none,
  hearts,
  sparkles,
  confetti,
  smallGlow,
  bubblePop,
  miniFireworks,
}

class GiftStackingConfig {
  final String stackedEffectName;
  final int minComboThreshold;
  final Duration stackedDuration;

  const GiftStackingConfig({
    required this.stackedEffectName,
    required this.minComboThreshold,
    this.stackedDuration = const Duration(milliseconds: 5500),
  });

  Map<String, dynamic> toJson() => {
        'stacked_effect_name': stackedEffectName,
        'min_combo_threshold': minComboThreshold,
        'stacked_duration_ms': stackedDuration.inMilliseconds,
      };
}

class GiftAnimationMetadata {
  final String giftId;
  final String giftName;
  final String giftIcon;
  final String currency; // 'gold' or 'silver'
  final int price;
  final GiftTier tier;
  final bool isLucky;
  final FlightPathType flightPath;
  final SeatEffectType seatEffect;
  final ShowcaseAnimationType showcaseType;
  final ChatEffectType chatEffect;
  final double screenCoverage; // e.g. 0.20, 0.40, 0.65, 0.85, 1.00
  final Duration duration;
  final bool autoClose;
  final String roomAnimation;
  final String chatAnimation;
  final String? soundEffect;
  final GiftStackingConfig? stackingConfig;
  final Color themeColor;

  const GiftAnimationMetadata({
    required this.giftId,
    required this.giftName,
    required this.giftIcon,
    required this.currency,
    required this.price,
    required this.tier,
    this.isLucky = false,
    required this.flightPath,
    required this.seatEffect,
    required this.showcaseType,
    required this.chatEffect,
    required this.screenCoverage,
    required this.duration,
    this.autoClose = true,
    required this.roomAnimation,
    required this.chatAnimation,
    this.soundEffect,
    this.stackingConfig,
    this.themeColor = Colors.amber,
  });

  Map<String, dynamic> toJson() => {
        'gift_id': giftId,
        'gift_name': giftName,
        'currency': currency,
        'price': price,
        'tier': tier.index + 1,
        'is_lucky': isLucky,
        'flight_path': flightPath.name,
        'showcase_type': showcaseType.name,
        'seat_effect': seatEffect.name,
        'chat_effect': chatEffect.name,
        'screen_coverage': '${(screenCoverage * 100).toInt()}%',
        'duration': '${duration.inMilliseconds}ms',
        'auto_close': autoClose,
      };
}

/// Centralized Data Registry containing the exact 35 Gifts
class GiftMetadataRegistry {
  static final Map<String, GiftAnimationMetadata> _registry = {
    // 🥈 TIER 1 (15 GIFTS: 3 Silver, 12 Gold)
    // Silver (3)
    'f1000001-0000-0000-0000-000000000001': const GiftAnimationMetadata(
      giftId: 'f1000001-0000-0000-0000-000000000001', giftName: 'Rose', giftIcon: '🌹', currency: 'silver', price: 100,
      tier: GiftTier.tier1, flightPath: FlightPathType.bounce, seatEffect: SeatEffectType.flowerBloom, showcaseType: ShowcaseAnimationType.popGlow,
      chatEffect: ChatEffectType.hearts, screenCoverage: 0.20, duration: Duration(milliseconds: 2000), roomAnimation: 'rose.json', chatAnimation: 'rose_chat.lottie', themeColor: Colors.pink,
    ),
    'f1000001-0000-0000-0000-000000000002': const GiftAnimationMetadata(
      giftId: 'f1000001-0000-0000-0000-000000000002', giftName: 'Heart', giftIcon: '❤️', currency: 'silver', price: 300,
      tier: GiftTier.tier1, flightPath: FlightPathType.straight, seatEffect: SeatEffectType.heartExplosion, showcaseType: ShowcaseAnimationType.floatingHearts,
      chatEffect: ChatEffectType.hearts, screenCoverage: 0.20, duration: Duration(milliseconds: 2500), roomAnimation: 'heart.json', chatAnimation: 'heart_chat.lottie', themeColor: Colors.redAccent,
    ),
    'f1000001-0000-0000-0000-000000000003': const GiftAnimationMetadata(
      giftId: 'f1000001-0000-0000-0000-000000000003', giftName: 'Coffee', giftIcon: '☕', currency: 'silver', price: 800,
      tier: GiftTier.tier1, flightPath: FlightPathType.bounce, seatEffect: SeatEffectType.steamPuff, showcaseType: ShowcaseAnimationType.steamFade,
      chatEffect: ChatEffectType.smallGlow, screenCoverage: 0.20, duration: Duration(milliseconds: 3000), roomAnimation: 'coffee.json', chatAnimation: 'coffee_chat.lottie', themeColor: Colors.brown,
    ),

    // Gold (12)
    'f1000001-0000-0000-0000-000000000004': const GiftAnimationMetadata(
      giftId: 'f1000001-0000-0000-0000-000000000004', giftName: 'Sakura', giftIcon: '🌸', currency: 'gold', price: 2, isLucky: true,
      tier: GiftTier.tier1, flightPath: FlightPathType.curve, seatEffect: SeatEffectType.flowerBloom, showcaseType: ShowcaseAnimationType.petalsBurst,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 0.25, duration: Duration(milliseconds: 2000), roomAnimation: 'sakura.json', chatAnimation: 'sakura_chat.lottie', themeColor: Colors.pinkAccent,
    ),
    'f1000001-0000-0000-0000-000000000005': const GiftAnimationMetadata(
      giftId: 'f1000001-0000-0000-0000-000000000005', giftName: 'Lucky Star', giftIcon: '⭐', currency: 'gold', price: 2,
      tier: GiftTier.tier1, flightPath: FlightPathType.straight, seatEffect: SeatEffectType.starRing, showcaseType: ShowcaseAnimationType.starTrail,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 0.25, duration: Duration(milliseconds: 2200), roomAnimation: 'star.json', chatAnimation: 'star_chat.lottie', themeColor: Colors.amberAccent,
    ),
    'f1000001-0000-0000-0000-000000000006': const GiftAnimationMetadata(
      giftId: 'f1000001-0000-0000-0000-000000000006', giftName: 'Chocolate', giftIcon: '🍫', currency: 'gold', price: 4,
      tier: GiftTier.tier1, flightPath: FlightPathType.curve, seatEffect: SeatEffectType.sweetSparkle, showcaseType: ShowcaseAnimationType.sweetSparkles,
      chatEffect: ChatEffectType.confetti, screenCoverage: 0.25, duration: Duration(milliseconds: 2500), roomAnimation: 'chocolate.json', chatAnimation: 'chocolate_chat.lottie', themeColor: Colors.amber,
    ),
    'f1000001-0000-0000-0000-000000000007': const GiftAnimationMetadata(
      giftId: 'f1000001-0000-0000-0000-000000000007', giftName: 'Balloon', giftIcon: '🎈', currency: 'gold', price: 4,
      tier: GiftTier.tier1, flightPath: FlightPathType.wave, seatEffect: SeatEffectType.popConfetti, showcaseType: ShowcaseAnimationType.floatUp,
      chatEffect: ChatEffectType.bubblePop, screenCoverage: 0.25, duration: Duration(milliseconds: 2500), roomAnimation: 'balloon.json', chatAnimation: 'balloon_chat.lottie', themeColor: Colors.purpleAccent,
    ),
    'f1000001-0000-0000-0000-000000000008': const GiftAnimationMetadata(
      giftId: 'f1000001-0000-0000-0000-000000000008', giftName: 'Cake', giftIcon: '🍰', currency: 'gold', price: 5,
      tier: GiftTier.tier1, flightPath: FlightPathType.bounce, seatEffect: SeatEffectType.candleFlare, showcaseType: ShowcaseAnimationType.candleShine,
      chatEffect: ChatEffectType.miniFireworks, screenCoverage: 0.25, duration: Duration(milliseconds: 3000), roomAnimation: 'cake.json', chatAnimation: 'cake_chat.lottie', themeColor: Colors.pink,
    ),
    'f1000001-0000-0000-0000-000000000009': const GiftAnimationMetadata(
      giftId: 'f1000001-0000-0000-0000-000000000009', giftName: 'Butterfly', giftIcon: '🦋', currency: 'gold', price: 5,
      tier: GiftTier.tier1, flightPath: FlightPathType.orbit, seatEffect: SeatEffectType.swarmFlutter, showcaseType: ShowcaseAnimationType.butterflyTrail,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 0.25, duration: Duration(milliseconds: 3000), roomAnimation: 'butterfly.json', chatAnimation: 'butterfly_chat.lottie', themeColor: Colors.deepPurpleAccent,
    ),
    'f1000001-0000-0000-0000-000000000010': const GiftAnimationMetadata(
      giftId: 'f1000001-0000-0000-0000-000000000010', giftName: 'Love Letter', giftIcon: '💌', currency: 'gold', price: 8,
      tier: GiftTier.tier1, flightPath: FlightPathType.curve, seatEffect: SeatEffectType.heartExplosion, showcaseType: ShowcaseAnimationType.heartTrail,
      chatEffect: ChatEffectType.hearts, screenCoverage: 0.30, duration: Duration(milliseconds: 3200), roomAnimation: 'love_letter.json', chatAnimation: 'love_letter_chat.lottie', themeColor: Colors.redAccent,
    ),
    'f1000001-0000-0000-0000-000000000011': const GiftAnimationMetadata(
      giftId: 'f1000001-0000-0000-0000-000000000011', giftName: 'Gift Box', giftIcon: '🎁', currency: 'gold', price: 9, isLucky: true,
      tier: GiftTier.tier1, flightPath: FlightPathType.bounce, seatEffect: SeatEffectType.boxExplosion, showcaseType: ShowcaseAnimationType.openShine,
      chatEffect: ChatEffectType.confetti, screenCoverage: 0.30, duration: Duration(milliseconds: 3500), roomAnimation: 'gift_box.json', chatAnimation: 'gift_box_chat.lottie', themeColor: Colors.red,
    ),
    'f1000001-0000-0000-0000-000000000012': const GiftAnimationMetadata(
      giftId: 'f1000001-0000-0000-0000-000000000012', giftName: 'Teddy', giftIcon: '🧸', currency: 'gold', price: 9,
      tier: GiftTier.tier1, flightPath: FlightPathType.bounce, seatEffect: SeatEffectType.pulse, showcaseType: ShowcaseAnimationType.bounceHug,
      chatEffect: ChatEffectType.hearts, screenCoverage: 0.30, duration: Duration(milliseconds: 3500), roomAnimation: 'teddy.json', chatAnimation: 'teddy_chat.lottie', themeColor: Colors.orange,
    ),
    'f1000001-0000-0000-0000-000000000013': const GiftAnimationMetadata(
      giftId: 'f1000001-0000-0000-0000-000000000013', giftName: 'Lucky Clover', giftIcon: '🍀', currency: 'gold', price: 15,
      tier: GiftTier.tier1, flightPath: FlightPathType.curve, seatEffect: SeatEffectType.glow, showcaseType: ShowcaseAnimationType.greenGlow,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 0.30, duration: Duration(milliseconds: 3800), roomAnimation: 'clover.json', chatAnimation: 'clover_chat.lottie', themeColor: Colors.greenAccent,
    ),
    'f1000001-0000-0000-0000-000000000014': const GiftAnimationMetadata(
      giftId: 'f1000001-0000-0000-0000-000000000014', giftName: 'Moon', giftIcon: '🌙', currency: 'gold', price: 19,
      tier: GiftTier.tier1, flightPath: FlightPathType.orbit, seatEffect: SeatEffectType.starRing, showcaseType: ShowcaseAnimationType.moonlightEffect,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 0.35, duration: Duration(milliseconds: 4000), roomAnimation: 'moon.json', chatAnimation: 'moon_chat.lottie', themeColor: Colors.indigoAccent,
    ),
    'f1000001-0000-0000-0000-000000000015': const GiftAnimationMetadata(
      giftId: 'f1000001-0000-0000-0000-000000000015', giftName: 'Sunshine', giftIcon: '☀️', currency: 'gold', price: 19,
      tier: GiftTier.tier1, flightPath: FlightPathType.straight, seatEffect: SeatEffectType.glow, showcaseType: ShowcaseAnimationType.sunRays,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 0.35, duration: Duration(milliseconds: 4000), roomAnimation: 'sunshine.json', chatAnimation: 'sunshine_chat.lottie', themeColor: Colors.amber,
    ),

    // 🥇 TIER 2 (7 GIFTS: 2 Silver, 5 Gold)
    // Silver (2)
    'f1000002-0000-0000-0000-000000000001': const GiftAnimationMetadata(
      giftId: 'f1000002-0000-0000-0000-000000000001', giftName: 'Bouquet', giftIcon: '💐', currency: 'silver', price: 2000,
      tier: GiftTier.tier2, flightPath: FlightPathType.curve, seatEffect: SeatEffectType.flowerBloom, showcaseType: ShowcaseAnimationType.flowersBloom,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 0.40, duration: Duration(milliseconds: 4000), roomAnimation: 'bouquet.json', chatAnimation: 'bouquet_chat.lottie', themeColor: Colors.purple,
    ),
    'f1000002-0000-0000-0000-000000000002': const GiftAnimationMetadata(
      giftId: 'f1000002-0000-0000-0000-000000000002', giftName: 'Birthday Cake', giftIcon: '🎂', currency: 'silver', price: 5000,
      tier: GiftTier.tier2, flightPath: FlightPathType.bounce, seatEffect: SeatEffectType.candleFlare, showcaseType: ShowcaseAnimationType.candleCelebration,
      chatEffect: ChatEffectType.miniFireworks, screenCoverage: 0.45, duration: Duration(milliseconds: 5000), roomAnimation: 'birthday_cake.json', chatAnimation: 'bday_chat.lottie', themeColor: Colors.pinkAccent,
    ),
    // Gold (5)
    'f1000002-0000-0000-0000-000000000003': const GiftAnimationMetadata(
      giftId: 'f1000002-0000-0000-0000-000000000003', giftName: 'Diamond Ring', giftIcon: '💍', currency: 'gold', price: 29, isLucky: true,
      tier: GiftTier.tier2, flightPath: FlightPathType.spiral, seatEffect: SeatEffectType.ringSparkle, showcaseType: ShowcaseAnimationType.ringSpinShine,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 0.45, duration: Duration(milliseconds: 4000), roomAnimation: 'ring.json', chatAnimation: 'ring_chat.lottie', themeColor: Colors.cyanAccent,
    ),
    'f1000002-0000-0000-0000-000000000004': const GiftAnimationMetadata(
      giftId: 'f1000002-0000-0000-0000-000000000004', giftName: 'Crown', giftIcon: '👑', currency: 'gold', price: 49,
      tier: GiftTier.tier2, flightPath: FlightPathType.curve, seatEffect: SeatEffectType.royalAura, showcaseType: ShowcaseAnimationType.goldenAura,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 0.50, duration: Duration(milliseconds: 4500), roomAnimation: 'crown.json', chatAnimation: 'crown_chat.lottie', themeColor: Colors.amber,
    ),
    'f1000002-0000-0000-0000-000000000005': const GiftAnimationMetadata(
      giftId: 'f1000002-0000-0000-0000-000000000005', giftName: 'Golden Mic', giftIcon: '🎤', currency: 'gold', price: 79,
      tier: GiftTier.tier2, flightPath: FlightPathType.wave, seatEffect: SeatEffectType.musicNotes, showcaseType: ShowcaseAnimationType.musicWaves,
      chatEffect: ChatEffectType.miniFireworks, screenCoverage: 0.50, duration: Duration(milliseconds: 5000), roomAnimation: 'mic.json', chatAnimation: 'mic_chat.lottie', themeColor: Colors.amber,
    ),
    'f1000002-0000-0000-0000-000000000006': const GiftAnimationMetadata(
      giftId: 'f1000002-0000-0000-0000-000000000006', giftName: 'Champion Trophy', giftIcon: '🏆', currency: 'gold', price: 119, isLucky: true,
      tier: GiftTier.tier2, flightPath: FlightPathType.straight, seatEffect: SeatEffectType.royalAura, showcaseType: ShowcaseAnimationType.trophyRise,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 0.55, duration: Duration(milliseconds: 5500), roomAnimation: 'trophy.json', chatAnimation: 'trophy_chat.lottie', themeColor: Colors.amber,
    ),
    'f1000002-0000-0000-0000-000000000007': const GiftAnimationMetadata(
      giftId: 'f1000002-0000-0000-0000-000000000007', giftName: 'Crystal Diamond', giftIcon: '💎', currency: 'gold', price: 149,
      tier: GiftTier.tier2, flightPath: FlightPathType.spiral, seatEffect: SeatEffectType.crystal, showcaseType: ShowcaseAnimationType.crystalExplosion,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 0.60, duration: Duration(milliseconds: 6000), roomAnimation: 'diamond.json', chatAnimation: 'diamond_chat.lottie', themeColor: Colors.cyan,
    ),

    // 👑 TIER 3 (5 GIFTS: 1 Silver, 4 Gold)
    // Silver (1)
    'f1000003-0000-0000-0000-000000000001': const GiftAnimationMetadata(
      giftId: 'f1000003-0000-0000-0000-000000000001', giftName: 'Fireworks', giftIcon: '🎆', currency: 'silver', price: 10000,
      tier: GiftTier.tier3, flightPath: FlightPathType.straight, seatEffect: SeatEffectType.sparkles, showcaseType: ShowcaseAnimationType.fireworksShow,
      chatEffect: ChatEffectType.miniFireworks, screenCoverage: 0.65, duration: Duration(milliseconds: 6000), roomAnimation: 'fireworks.json', chatAnimation: 'fireworks_chat.lottie', themeColor: Colors.deepPurpleAccent,
    ),
    // Gold (4)
    'f1000003-0000-0000-0000-000000000002': const GiftAnimationMetadata(
      giftId: 'f1000003-0000-0000-0000-000000000002', giftName: 'Super Car', giftIcon: '🏎️', currency: 'gold', price: 299, isLucky: true,
      tier: GiftTier.tier3, flightPath: FlightPathType.zigzag, seatEffect: SeatEffectType.wheelSkid, showcaseType: ShowcaseAnimationType.driveAcrossScreen,
      chatEffect: ChatEffectType.miniFireworks, screenCoverage: 0.70, duration: Duration(milliseconds: 6000), roomAnimation: 'super_car.json', chatAnimation: 'car_chat.lottie', themeColor: Colors.deepOrange,
    ),
    'f1000003-0000-0000-0000-000000000003': const GiftAnimationMetadata(
      giftId: 'f1000003-0000-0000-0000-000000000003', giftName: 'Rocket', giftIcon: '🚀', currency: 'gold', price: 499,
      tier: GiftTier.tier3, flightPath: FlightPathType.straight, seatEffect: SeatEffectType.fire, showcaseType: ShowcaseAnimationType.rocketLaunch,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 0.75, duration: Duration(milliseconds: 7000), roomAnimation: 'rocket.json', chatAnimation: 'rocket_chat.lottie', themeColor: Colors.redAccent,
    ),
    'f1000003-0000-0000-0000-000000000004': const GiftAnimationMetadata(
      giftId: 'f1000003-0000-0000-0000-000000000004', giftName: 'Private Jet', giftIcon: '✈️', currency: 'gold', price: 799,
      tier: GiftTier.tier3, flightPath: FlightPathType.infinity, seatEffect: SeatEffectType.windBurst, showcaseType: ShowcaseAnimationType.flyOverScreen,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 0.75, duration: Duration(milliseconds: 8000), roomAnimation: 'jet.json', chatAnimation: 'jet_chat.lottie', themeColor: Colors.cyanAccent,
    ),
    'f1000003-0000-0000-0000-000000000005': const GiftAnimationMetadata(
      giftId: 'f1000003-0000-0000-0000-000000000005', giftName: 'Treasure Chest', giftIcon: '💰', currency: 'gold', price: 999,
      tier: GiftTier.tier3, flightPath: FlightPathType.bounce, seatEffect: SeatEffectType.goldenThroneGlow, showcaseType: ShowcaseAnimationType.goldBurst,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 0.80, duration: Duration(milliseconds: 8500), roomAnimation: 'treasure.json', chatAnimation: 'treasure_chat.lottie', themeColor: Colors.amber,
    ),

    // 💎 TIER 4 (4 GIFTS: 0 Silver, 4 Gold)
    'f1000004-0000-0000-0000-000000000001': const GiftAnimationMetadata(
      giftId: 'f1000004-0000-0000-0000-000000000001', giftName: 'Golden Dragon', giftIcon: '🐉', currency: 'gold', price: 1999, isLucky: true,
      tier: GiftTier.tier4, flightPath: FlightPathType.orbit, seatEffect: SeatEffectType.fireAura, showcaseType: ShowcaseAnimationType.dragonFlies,
      chatEffect: ChatEffectType.miniFireworks, screenCoverage: 0.90, duration: Duration(milliseconds: 8000), roomAnimation: 'dragon.json', chatAnimation: 'dragon_chat.lottie', themeColor: Colors.red,
    ),
    'f1000004-0000-0000-0000-000000000002': const GiftAnimationMetadata(
      giftId: 'f1000004-0000-0000-0000-000000000002', giftName: 'Phoenix', giftIcon: '🔥', currency: 'gold', price: 2999,
      tier: GiftTier.tier4, flightPath: FlightPathType.infinity, seatEffect: SeatEffectType.phoenixFlames, showcaseType: ShowcaseAnimationType.phoenixFlames,
      chatEffect: ChatEffectType.miniFireworks, screenCoverage: 0.90, duration: Duration(milliseconds: 8500), roomAnimation: 'phoenix.json', chatAnimation: 'phoenix_chat.lottie', themeColor: Colors.orange,
    ),
    'f1000004-0000-0000-0000-000000000003': const GiftAnimationMetadata(
      giftId: 'f1000004-0000-0000-0000-000000000003', giftName: 'Galaxy Portal', giftIcon: '🌌', currency: 'gold', price: 4499,
      tier: GiftTier.tier4, flightPath: FlightPathType.spiral, seatEffect: SeatEffectType.spacePortal, showcaseType: ShowcaseAnimationType.galaxyPortal,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 0.95, duration: Duration(milliseconds: 9000), roomAnimation: 'galaxy.json', chatAnimation: 'galaxy_chat.lottie', themeColor: Colors.indigoAccent,
    ),
    'f1000004-0000-0000-0000-000000000004': const GiftAnimationMetadata(
      giftId: 'f1000004-0000-0000-0000-000000000004', giftName: 'Crystal Castle', giftIcon: '🏰', currency: 'gold', price: 6999,
      tier: GiftTier.tier4, flightPath: FlightPathType.curve, seatEffect: SeatEffectType.goldenThroneGlow, showcaseType: ShowcaseAnimationType.crystalCastle,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 0.95, duration: Duration(milliseconds: 10000), roomAnimation: 'castle.json', chatAnimation: 'castle_chat.lottie', themeColor: Colors.yellowAccent,
    ),

    // ⚡ TIER 5 (4 GIFTS: 0 Silver, 4 Gold - Premium Showcase)
    'f1000005-0000-0000-0000-000000000001': const GiftAnimationMetadata(
      giftId: 'f1000005-0000-0000-0000-000000000001', giftName: 'Celestial Emperor', giftIcon: '👑', currency: 'gold', price: 7999,
      tier: GiftTier.tier5, flightPath: FlightPathType.straight, seatEffect: SeatEffectType.goldenThroneGlow, showcaseType: ShowcaseAnimationType.celestialEmperor,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 1.00, duration: Duration(milliseconds: 10000), roomAnimation: 'emperor.json', chatAnimation: 'emperor_chat.lottie', themeColor: Colors.amber,
    ),
    'f1000005-0000-0000-0000-000000000002': const GiftAnimationMetadata(
      giftId: 'f1000005-0000-0000-0000-000000000002', giftName: 'Planet Creation', giftIcon: '🌍', currency: 'gold', price: 19999,
      tier: GiftTier.tier5, flightPath: FlightPathType.orbit, seatEffect: SeatEffectType.spacePortal, showcaseType: ShowcaseAnimationType.planetCreation,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 1.00, duration: Duration(milliseconds: 10000), roomAnimation: 'planets.json', chatAnimation: 'planets_chat.lottie', themeColor: Colors.lightBlueAccent,
    ),
    'f1000005-0000-0000-0000-000000000003': const GiftAnimationMetadata(
      giftId: 'f1000005-0000-0000-0000-000000000003', giftName: 'World Tree', giftIcon: '🌳', currency: 'gold', price: 19999,
      tier: GiftTier.tier5, flightPath: FlightPathType.curve, seatEffect: SeatEffectType.flowerBloom, showcaseType: ShowcaseAnimationType.worldTree,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 1.00, duration: Duration(milliseconds: 10000), roomAnimation: 'tree.json', chatAnimation: 'tree_chat.lottie', themeColor: Colors.greenAccent,
    ),
    'f1000005-0000-0000-0000-000000000004': const GiftAnimationMetadata(
      giftId: 'f1000005-0000-0000-0000-000000000004', giftName: 'Infinity Cosmos', giftIcon: '🌠', currency: 'gold', price: 29999,
      tier: GiftTier.tier5, flightPath: FlightPathType.infinity, seatEffect: SeatEffectType.cosmicAurora, showcaseType: ShowcaseAnimationType.infinityCosmos,
      chatEffect: ChatEffectType.sparkles, screenCoverage: 1.00, duration: Duration(milliseconds: 10000), roomAnimation: 'cosmos.json', chatAnimation: 'cosmos_chat.lottie', themeColor: Colors.purpleAccent,
    ),
  };

  static Map<String, GiftAnimationMetadata> get registry => _registry;

  static GiftAnimationMetadata getMetadata(String giftIdOrName) {
    if (_registry.containsKey(giftIdOrName)) {
      return _registry[giftIdOrName]!;
    }

    final match = _registry.values.firstWhere(
      (m) => m.giftName.toLowerCase() == giftIdOrName.toLowerCase(),
      orElse: () => _registry.values.first,
    );
    return match;
  }
}
