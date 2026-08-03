// lib/models/gift_animation_metadata.dart

import 'package:flutter/material.dart';

enum GiftAnimationMode {
  roomSeat, // Audio Rooms, PK Rooms, Study Rooms, Live Rooms
  chat,     // Private Chat, Group Chat, Community Chat
}

enum GiftTier {
  basic,     // Tier 1: 2s, 20% screen, seat animation only
  premium,   // Tier 2: 3s, 35% screen, seat transformation & mini explosion
  epic,      // Tier 3: 4-5s, 60% screen, cinematic landing & aura
  legendary, // Tier 4: 6s, 80% screen, entire seat transform & camera movement
  mythic,    // Tier 5: 8-10s, 100% screen, full room takeover & cinematic background
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
  roseBloom,
  heartPulse,
  coffeeSteam,
  chocolateUnwrap,
  balloonFloat,
  butterflyWings,
  cakeSparkle,
  diamondPrism,
  ringSparkle,
  crownShine,
  carEngine,
  jetIgnition,
  yachtSplash,
  dragonFire,
  galaxyRotate,
  castleBuild,
  phoenixFlames,
  likePop,
  flowerBloom,
  giftBoxExplode,
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
  magicCircle,
  flowerBloom,
  heartRain,
  heartExplosion,
  steamPuff,
  sweetSparkle,
  popConfetti,
  swarmFlutter,
  candleFlare,
  prismBurst,
  ringSparkle,
  goldenAura,
  royalAura,
  royalThrone,
  goldenThroneGlow,
  dragonWings,
  fireAura,
  galaxyRing,
  starRing,
  wheelSkid,
  windBurst,
  rainbow,
  snow,
  cloud,
  stars,
  waterSplash,
  crystal,
  musicNotes,
  butterflies,
  leaves,
  sparkles,
  energyWaves,
  smoke,
  flames,
  thumbsUpBurst,
  boxExplosion,
  phoenixFlames,
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
  final String currency; // 'Gold' or 'Silver'
  final int price;
  final GiftTier tier;
  final FlightPathType flightPath;
  final SeatEffectType seatEffect;
  final ShowcaseAnimationType showcaseType;
  final ChatEffectType chatEffect;
  final double screenCoverage; // e.g. 0.20, 0.35, 0.60, 0.80, 1.00
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
        'gift_name': giftName,
        'currency': currency,
        'price': price,
        'tier': tier.index + 1,
        'flight_path': flightPath.name,
        'room_animation': roomAnimation,
        'chat_animation': chatAnimation,
        'showcase_type': showcaseType.name,
        'seat_effect': seatEffect.name,
        'chat_effect': chatEffect.name,
        'screen_coverage': '${(screenCoverage * 100).toInt()}%',
        'duration': '${duration.inSeconds}s',
        'auto_close': autoClose,
        if (stackingConfig != null) 'stacking': stackingConfig!.toJson(),
      };
}

/// Fully data-driven registry matching production Creania gift catalog (24 Unique Items + Dynamic Fallbacks)
class GiftMetadataRegistry {
  static ShowcaseAnimationType getShowcaseTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('rose')) return ShowcaseAnimationType.roseBloom;
    if (lower.contains('flower')) return ShowcaseAnimationType.flowerBloom;
    if (lower.contains('heart')) return ShowcaseAnimationType.heartPulse;
    if (lower.contains('coffee')) return ShowcaseAnimationType.coffeeSteam;
    if (lower.contains('choco')) return ShowcaseAnimationType.chocolateUnwrap;
    if (lower.contains('balloon')) return ShowcaseAnimationType.balloonFloat;
    if (lower.contains('butter')) return ShowcaseAnimationType.butterflyWings;
    if (lower.contains('cake')) return ShowcaseAnimationType.cakeSparkle;
    if (lower.contains('diamond')) return ShowcaseAnimationType.diamondPrism;
    if (lower.contains('ring')) return ShowcaseAnimationType.ringSparkle;
    if (lower.contains('crown')) return ShowcaseAnimationType.crownShine;
    if (lower.contains('car')) return ShowcaseAnimationType.carEngine;
    if (lower.contains('jet')) return ShowcaseAnimationType.jetIgnition;
    if (lower.contains('yacht')) return ShowcaseAnimationType.yachtSplash;
    if (lower.contains('dragon')) return ShowcaseAnimationType.dragonFire;
    if (lower.contains('galaxy')) return ShowcaseAnimationType.galaxyRotate;
    if (lower.contains('castle')) return ShowcaseAnimationType.castleBuild;
    if (lower.contains('phoenix')) return ShowcaseAnimationType.phoenixFlames;
    if (lower.contains('like')) return ShowcaseAnimationType.likePop;
    if (lower.contains('box')) return ShowcaseAnimationType.giftBoxExplode;
    return ShowcaseAnimationType.genericGlow;
  }

  static SeatEffectType getSeatEffectForName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('rose') || lower.contains('flower')) return SeatEffectType.flowerBloom;
    if (lower.contains('heart')) return SeatEffectType.heartExplosion;
    if (lower.contains('coffee')) return SeatEffectType.steamPuff;
    if (lower.contains('choco')) return SeatEffectType.sweetSparkle;
    if (lower.contains('balloon')) return SeatEffectType.popConfetti;
    if (lower.contains('butter')) return SeatEffectType.swarmFlutter;
    if (lower.contains('cake')) return SeatEffectType.candleFlare;
    if (lower.contains('diamond')) return SeatEffectType.prismBurst;
    if (lower.contains('ring')) return SeatEffectType.ringSparkle;
    if (lower.contains('crown')) return SeatEffectType.royalAura;
    if (lower.contains('car')) return SeatEffectType.wheelSkid;
    if (lower.contains('jet')) return SeatEffectType.windBurst;
    if (lower.contains('yacht')) return SeatEffectType.waterSplash;
    if (lower.contains('dragon')) return SeatEffectType.fireAura;
    if (lower.contains('galaxy')) return SeatEffectType.starRing;
    if (lower.contains('castle')) return SeatEffectType.goldenThroneGlow;
    if (lower.contains('phoenix')) return SeatEffectType.phoenixFlames;
    if (lower.contains('like')) return SeatEffectType.thumbsUpBurst;
    if (lower.contains('box')) return SeatEffectType.boxExplosion;
    return SeatEffectType.glow;
  }

  static final Map<String, GiftAnimationMetadata> _registry = {
    // 1. Like (2 Gold)
    'a2000000-0000-0000-0000-000000000001': const GiftAnimationMetadata(
      giftId: 'a2000000-0000-0000-0000-000000000001',
      giftName: 'Like',
      giftIcon: '👍',
      currency: 'Gold',
      price: 2,
      tier: GiftTier.basic,
      flightPath: FlightPathType.bounce,
      showcaseType: ShowcaseAnimationType.likePop,
      seatEffect: SeatEffectType.thumbsUpBurst,
      chatEffect: ChatEffectType.bubblePop,
      screenCoverage: 0.20,
      duration: Duration(milliseconds: 5000),
      autoClose: true,
      roomAnimation: 'like_room.json',
      chatAnimation: 'like_chat.lottie',
      themeColor: Colors.blueAccent,
    ),

    // 2. Flower (5 Gold)
    'a2000000-0000-0000-0000-000000000002': const GiftAnimationMetadata(
      giftId: 'a2000000-0000-0000-0000-000000000002',
      giftName: 'Flower',
      giftIcon: '🌼',
      currency: 'Gold',
      price: 5,
      tier: GiftTier.basic,
      flightPath: FlightPathType.curve,
      showcaseType: ShowcaseAnimationType.flowerBloom,
      seatEffect: SeatEffectType.flowerBloom,
      chatEffect: ChatEffectType.sparkles,
      screenCoverage: 0.20,
      duration: Duration(milliseconds: 5000),
      autoClose: true,
      roomAnimation: 'flower_room.json',
      chatAnimation: 'flower_chat.lottie',
      themeColor: Colors.orangeAccent,
    ),

    // 3. Rose (10 Gold)
    'a2000000-0000-0000-0000-000000000003': const GiftAnimationMetadata(
      giftId: 'a2000000-0000-0000-0000-000000000003',
      giftName: 'Rose',
      giftIcon: '🌹',
      currency: 'Gold',
      price: 10,
      tier: GiftTier.basic,
      flightPath: FlightPathType.curve,
      showcaseType: ShowcaseAnimationType.roseBloom,
      seatEffect: SeatEffectType.flowerBloom,
      chatEffect: ChatEffectType.hearts,
      screenCoverage: 0.20,
      duration: Duration(milliseconds: 5000),
      autoClose: true,
      roomAnimation: 'rose_room.json',
      chatAnimation: 'rose_chat.lottie',
      stackingConfig: GiftStackingConfig(
        stackedEffectName: 'Rose Garden Bloom',
        minComboThreshold: 10,
        stackedDuration: Duration(milliseconds: 6000),
      ),
      themeColor: Colors.pinkAccent,
    ),

    // 4. Heart (15 Gold)
    'a2000000-0000-0000-0000-000000000004': const GiftAnimationMetadata(
      giftId: 'a2000000-0000-0000-0000-000000000004',
      giftName: 'Heart',
      giftIcon: '❤️',
      currency: 'Gold',
      price: 15,
      tier: GiftTier.basic,
      flightPath: FlightPathType.straight,
      showcaseType: ShowcaseAnimationType.heartPulse,
      seatEffect: SeatEffectType.heartExplosion,
      chatEffect: ChatEffectType.hearts,
      screenCoverage: 0.20,
      duration: Duration(milliseconds: 5000),
      autoClose: true,
      roomAnimation: 'heart_room.json',
      chatAnimation: 'heart_chat.lottie',
      stackingConfig: GiftStackingConfig(
        stackedEffectName: 'Heart Rain Shower',
        minComboThreshold: 50,
        stackedDuration: Duration(milliseconds: 7000),
      ),
      themeColor: Colors.redAccent,
    ),

    // 5. Coffee (20 Gold)
    'a2000000-0000-0000-0000-000000000005': const GiftAnimationMetadata(
      giftId: 'a2000000-0000-0000-0000-000000000005',
      giftName: 'Coffee',
      giftIcon: '☕',
      currency: 'Gold',
      price: 20,
      tier: GiftTier.basic,
      flightPath: FlightPathType.bounce,
      showcaseType: ShowcaseAnimationType.coffeeSteam,
      seatEffect: SeatEffectType.steamPuff,
      chatEffect: ChatEffectType.smallGlow,
      screenCoverage: 0.20,
      duration: Duration(milliseconds: 5000),
      autoClose: true,
      roomAnimation: 'coffee_room.json',
      chatAnimation: 'coffee_chat.lottie',
      themeColor: Colors.brown,
    ),

    // 6. Chocolate (25 Gold)
    'a2000000-0000-0000-0000-000000000006': const GiftAnimationMetadata(
      giftId: 'a2000000-0000-0000-0000-000000000006',
      giftName: 'Chocolate',
      giftIcon: '🍫',
      currency: 'Gold',
      price: 25,
      tier: GiftTier.premium,
      flightPath: FlightPathType.curve,
      showcaseType: ShowcaseAnimationType.chocolateUnwrap,
      seatEffect: SeatEffectType.sweetSparkle,
      chatEffect: ChatEffectType.confetti,
      screenCoverage: 0.35,
      duration: Duration(milliseconds: 5000),
      autoClose: true,
      roomAnimation: 'chocolate_room.json',
      chatAnimation: 'chocolate_chat.lottie',
      themeColor: Colors.amber,
    ),

    // 7. Cake (30 Gold)
    'a2000000-0000-0000-0000-000000000007': const GiftAnimationMetadata(
      giftId: 'a2000000-0000-0000-0000-000000000007',
      giftName: 'Cake',
      giftIcon: '🎂',
      currency: 'Gold',
      price: 30,
      tier: GiftTier.premium,
      flightPath: FlightPathType.curve,
      showcaseType: ShowcaseAnimationType.cakeSparkle,
      seatEffect: SeatEffectType.candleFlare,
      chatEffect: ChatEffectType.miniFireworks,
      screenCoverage: 0.35,
      duration: Duration(milliseconds: 5000),
      autoClose: true,
      roomAnimation: 'cake_room.json',
      chatAnimation: 'cake_chat.lottie',
      themeColor: Colors.pink,
    ),

    // 8. Balloon (35 Gold)
    'a2000000-0000-0000-0000-000000000008': const GiftAnimationMetadata(
      giftId: 'a2000000-0000-0000-0000-000000000008',
      giftName: 'Balloon',
      giftIcon: '🎈',
      currency: 'Gold',
      price: 35,
      tier: GiftTier.premium,
      flightPath: FlightPathType.wave,
      showcaseType: ShowcaseAnimationType.balloonFloat,
      seatEffect: SeatEffectType.popConfetti,
      chatEffect: ChatEffectType.bubblePop,
      screenCoverage: 0.35,
      duration: Duration(milliseconds: 5000),
      autoClose: true,
      roomAnimation: 'balloon_room.json',
      chatAnimation: 'balloon_chat.lottie',
      stackingConfig: GiftStackingConfig(
        stackedEffectName: 'Sky Balloons Parade',
        minComboThreshold: 20,
        stackedDuration: Duration(milliseconds: 6000),
      ),
      themeColor: Colors.purpleAccent,
    ),

    // 9. Gift Box (40 Gold)
    'a2000000-0000-0000-0000-000000000009': const GiftAnimationMetadata(
      giftId: 'a2000000-0000-0000-0000-000000000009',
      giftName: 'Gift Box',
      giftIcon: '🎁',
      currency: 'Gold',
      price: 40,
      tier: GiftTier.premium,
      flightPath: FlightPathType.curve,
      showcaseType: ShowcaseAnimationType.giftBoxExplode,
      seatEffect: SeatEffectType.boxExplosion,
      chatEffect: ChatEffectType.confetti,
      screenCoverage: 0.35,
      duration: Duration(milliseconds: 5000),
      autoClose: true,
      roomAnimation: 'gift_box_room.json',
      chatAnimation: 'gift_box_chat.lottie',
      themeColor: Colors.red,
    ),

    // 10. Diamond (50 Gold)
    'a2000000-0000-0000-0000-000000000010': const GiftAnimationMetadata(
      giftId: 'a2000000-0000-0000-0000-000000000010',
      giftName: 'Diamond',
      giftIcon: '💎',
      currency: 'Gold',
      price: 50,
      tier: GiftTier.premium,
      flightPath: FlightPathType.spiral,
      showcaseType: ShowcaseAnimationType.diamondPrism,
      seatEffect: SeatEffectType.prismBurst,
      chatEffect: ChatEffectType.sparkles,
      screenCoverage: 0.35,
      duration: Duration(milliseconds: 5000),
      autoClose: true,
      roomAnimation: 'diamond_room.json',
      chatAnimation: 'diamond_chat.lottie',
      themeColor: Colors.cyan,
    ),

    // 11. Crown (99 Gold)
    'a2000000-0000-0000-0000-000000000011': const GiftAnimationMetadata(
      giftId: 'a2000000-0000-0000-0000-000000000011',
      giftName: 'Crown',
      giftIcon: '👑',
      currency: 'Gold',
      price: 99,
      tier: GiftTier.premium,
      flightPath: FlightPathType.curve,
      showcaseType: ShowcaseAnimationType.crownShine,
      seatEffect: SeatEffectType.royalAura,
      chatEffect: ChatEffectType.sparkles,
      screenCoverage: 0.35,
      duration: Duration(milliseconds: 5000),
      autoClose: true,
      roomAnimation: 'crown_room.json',
      chatAnimation: 'crown_chat.lottie',
      themeColor: Colors.amber,
    ),

    // 12. Butterfly (99 Gold)
    'a2000000-0000-0000-0000-000000000012': const GiftAnimationMetadata(
      giftId: 'a2000000-0000-0000-0000-000000000012',
      giftName: 'Butterfly',
      giftIcon: '🦋',
      currency: 'Gold',
      price: 99,
      tier: GiftTier.premium,
      flightPath: FlightPathType.orbit,
      showcaseType: ShowcaseAnimationType.butterflyWings,
      seatEffect: SeatEffectType.swarmFlutter,
      chatEffect: ChatEffectType.sparkles,
      screenCoverage: 0.35,
      duration: Duration(milliseconds: 5000),
      autoClose: true,
      roomAnimation: 'butterfly_room.json',
      chatAnimation: 'butterfly_chat.lottie',
      stackingConfig: GiftStackingConfig(
        stackedEffectName: 'Butterfly Orbit Swarm',
        minComboThreshold: 5,
        stackedDuration: Duration(milliseconds: 6000),
      ),
      themeColor: Colors.deepPurpleAccent,
    ),

    // 13. Sports Car (499 Gold)
    'a2000000-0000-0000-0000-000000000013': const GiftAnimationMetadata(
      giftId: 'a2000000-0000-0000-0000-000000000013',
      giftName: 'Sports Car',
      giftIcon: '🏎️',
      currency: 'Gold',
      price: 499,
      tier: GiftTier.epic,
      flightPath: FlightPathType.zigzag,
      showcaseType: ShowcaseAnimationType.carEngine,
      seatEffect: SeatEffectType.wheelSkid,
      chatEffect: ChatEffectType.miniFireworks,
      screenCoverage: 0.60,
      duration: Duration(milliseconds: 5500),
      autoClose: true,
      roomAnimation: 'sports_car_room.json',
      chatAnimation: 'sports_car_chat.lottie',
      themeColor: Colors.deepOrange,
    ),

    // 14. Private Jet (499 Gold)
    'a2000000-0000-0000-0000-000000000014': const GiftAnimationMetadata(
      giftId: 'a2000000-0000-0000-0000-000000000014',
      giftName: 'Private Jet',
      giftIcon: '✈️',
      currency: 'Gold',
      price: 499,
      tier: GiftTier.epic,
      flightPath: FlightPathType.infinity,
      showcaseType: ShowcaseAnimationType.jetIgnition,
      seatEffect: SeatEffectType.windBurst,
      chatEffect: ChatEffectType.sparkles,
      screenCoverage: 0.60,
      duration: Duration(milliseconds: 6000),
      autoClose: true,
      roomAnimation: 'private_jet_room.json',
      chatAnimation: 'private_jet_chat.lottie',
      themeColor: Colors.cyanAccent,
    ),

    // ── SILVER GIFTS ──
    'a2000000-0000-0000-0000-000000000021': const GiftAnimationMetadata(
      giftId: 'a2000000-0000-0000-0000-000000000021',
      giftName: 'Like',
      giftIcon: '👍',
      currency: 'Silver',
      price: 200,
      tier: GiftTier.basic,
      flightPath: FlightPathType.bounce,
      showcaseType: ShowcaseAnimationType.likePop,
      seatEffect: SeatEffectType.thumbsUpBurst,
      chatEffect: ChatEffectType.bubblePop,
      screenCoverage: 0.20,
      duration: Duration(milliseconds: 5000),
      autoClose: true,
      roomAnimation: 'like_silver.json',
      chatAnimation: 'like_silver.lottie',
      themeColor: Colors.blueAccent,
    ),
    'a2000000-0000-0000-0000-000000000030': const GiftAnimationMetadata(
      giftId: 'a2000000-0000-0000-0000-000000000030',
      giftName: 'Diamond',
      giftIcon: '💎',
      currency: 'Silver',
      price: 5000,
      tier: GiftTier.premium,
      flightPath: FlightPathType.spiral,
      showcaseType: ShowcaseAnimationType.diamondPrism,
      seatEffect: SeatEffectType.prismBurst,
      chatEffect: ChatEffectType.sparkles,
      screenCoverage: 0.35,
      duration: Duration(milliseconds: 5000),
      autoClose: true,
      roomAnimation: 'diamond_silver.json',
      chatAnimation: 'diamond_silver.lottie',
      themeColor: Colors.cyan,
    ),
  };

  static GiftAnimationMetadata getMetadata(String giftIdOrName) {
    if (_registry.containsKey(giftIdOrName)) {
      return _registry[giftIdOrName]!;
    }
    // Search by name match
    final nameMatch = _registry.values.firstWhere(
      (m) => m.giftName.toLowerCase() == giftIdOrName.toLowerCase(),
      orElse: () {
        final derivedShowcase = getShowcaseTypeForName(giftIdOrName);
        final derivedSeatEffect = getSeatEffectForName(giftIdOrName);
        return GiftAnimationMetadata(
          giftId: giftIdOrName,
          giftName: giftIdOrName,
          giftIcon: _getIconForName(giftIdOrName),
          currency: 'Gold',
          price: 10,
          tier: GiftTier.basic,
          flightPath: FlightPathType.curve,
          showcaseType: derivedShowcase,
          seatEffect: derivedSeatEffect,
          chatEffect: ChatEffectType.sparkles,
          screenCoverage: 0.20,
          duration: const Duration(milliseconds: 5000),
          autoClose: true,
          roomAnimation: 'generic_room.json',
          chatAnimation: 'generic_chat.lottie',
          themeColor: _getThemeColorForName(giftIdOrName),
        );
      },
    );
    return nameMatch;
  }

  static Color _getThemeColorForName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('rose')) return Colors.pinkAccent;
    if (lower.contains('flower')) return Colors.orangeAccent;
    if (lower.contains('heart')) return Colors.redAccent;
    if (lower.contains('coffee')) return Colors.brown;
    if (lower.contains('choco')) return Colors.amber;
    if (lower.contains('cake')) return Colors.pink;
    if (lower.contains('balloon')) return Colors.purpleAccent;
    if (lower.contains('box')) return Colors.red;
    if (lower.contains('diamond')) return Colors.cyan;
    if (lower.contains('ring')) return Colors.amberAccent;
    if (lower.contains('crown')) return Colors.amber;
    if (lower.contains('butter')) return Colors.deepPurpleAccent;
    if (lower.contains('car')) return Colors.deepOrange;
    if (lower.contains('jet')) return Colors.cyanAccent;
    if (lower.contains('yacht')) return Colors.lightBlueAccent;
    if (lower.contains('dragon')) return Colors.red;
    if (lower.contains('galaxy')) return Colors.indigoAccent;
    if (lower.contains('castle')) return Colors.yellowAccent;
    if (lower.contains('phoenix')) return Colors.orange;
    if (lower.contains('like')) return Colors.blueAccent;
    return const Color(0xFF8B5CF6);
  }

  static String _getIconForName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('rose')) return '🌹';
    if (lower.contains('flower')) return '🌼';
    if (lower.contains('heart')) return '❤️';
    if (lower.contains('coffee')) return '☕';
    if (lower.contains('choco')) return '🍫';
    if (lower.contains('cake')) return '🎂';
    if (lower.contains('balloon')) return '🎈';
    if (lower.contains('box') || lower.contains('chest') || lower.contains('mystery') || lower.contains('surprise')) return '🎁';
    if (lower.contains('diamond')) return '💎';
    if (lower.contains('ring')) return '💍';
    if (lower.contains('crown')) return '👑';
    if (lower.contains('butter')) return '🦋';
    if (lower.contains('car')) return '🏎️';
    if (lower.contains('jet')) return '✈️';
    if (lower.contains('yacht')) return '🛥️';
    if (lower.contains('dragon')) return '🐉';
    if (lower.contains('galaxy')) return '🌌';
    if (lower.contains('castle')) return '🏰';
    if (lower.contains('phoenix')) return '🔥';
    if (lower.contains('like')) return '👍';
    return '✨';
  }
}
