// lib/models/gift/gift_animation_config.dart

import 'package:flutter/material.dart';
import 'gift_animation_metadata.dart';

enum LaunchType { linear, bezierArc, spiralRise, teleportPulse }

enum ShowcaseType {
  bloomRotate,
  vehicleDrive,
  rocketLaunch,
  buildingRise,
  dragonFlyaround,
  universeGalaxy,
  custom,
}

enum DeliveryType { smoothCurve, spiralDrop, straightDash, splitScatter }

enum SplitEffectType {
  magicBurst,
  crystalExplosion,
  energyPulse,
  lightBeam,
  fireRing,
  goldenFlash,
}

enum LandingEffectType {
  sparkleExplosion,
  heartBurst,
  goldenPulse,
  starRing,
}

enum CameraEffectType {
  none,
  zoomIn,
  screenShake,
  ambientDim,
  flashBurst,
  spaceDistortion,
}

enum LayerPriority { normal, high, exclusive }

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
  fireStars,
  cosmicMeteors,
  goldenShine,
}

class ParticleEffectConfig {
  final ParticleEffectType type;
  final int quantity;
  final List<Color> colorPalette;
  final double speed;
  final bool hasTail;

  const ParticleEffectConfig({
    required this.type,
    this.quantity = 32,
    this.colorPalette = const [Colors.amber, Colors.orangeAccent],
    this.speed = 1.0,
    this.hasTail = false,
  });
}

class CameraEffectConfig {
  final CameraEffectType type;
  final double intensity;
  final int durationMs;

  const CameraEffectConfig({
    this.type = CameraEffectType.none,
    this.intensity = 1.0,
    this.durationMs = 500,
  });
}

class SoundEffectConfig {
  final String soundKey;
  final String? assetPath;
  final double volume;

  const SoundEffectConfig({
    required this.soundKey,
    this.assetPath,
    this.volume = 1.0,
  });
}

class GiftConfig {
  final String giftId;
  final String animationKey;
  final String name;
  final String emoji;
  final GiftTier tier;
  final LaunchType launchAnimation;
  final ShowcaseType showcaseAnimation;
  final Duration showcaseDuration;
  final ParticleEffectConfig particleEffect;
  final CameraEffectConfig cameraEffect;
  final SoundEffectConfig? soundEffect;
  final DeliveryType deliveryAnimation;
  final SplitEffectType splitEffect;
  final LandingEffectType landingEffect;
  final bool allowSplit;
  final int maxCopies;
  final LayerPriority layerPriority;
  final Color themeColor;
  final String? customLottiePath;
  final String? customAssetPath;

  const GiftConfig({
    required this.giftId,
    required this.animationKey,
    required this.name,
    required this.emoji,
    required this.tier,
    this.launchAnimation = LaunchType.bezierArc,
    required this.showcaseAnimation,
    required this.showcaseDuration,
    this.particleEffect = const ParticleEffectConfig(type: ParticleEffectType.emojiBurst),
    this.cameraEffect = const CameraEffectConfig(),
    this.soundEffect,
    this.deliveryAnimation = DeliveryType.smoothCurve,
    this.splitEffect = SplitEffectType.magicBurst,
    this.landingEffect = LandingEffectType.sparkleExplosion,
    this.allowSplit = true,
    this.maxCopies = 10,
    this.layerPriority = LayerPriority.normal,
    this.themeColor = Colors.amber,
    this.customLottiePath,
    this.customAssetPath,
  });
}

class GiftConfigRegistry {
  static final Map<String, GiftConfig> _registry = {
    // 🌹 Rose (Common - 2 sec Showcase)
    'gift_rose': const GiftConfig(
      giftId: 'a2000000-0000-0000-0000-000000000003',
      animationKey: 'gift_rose',
      name: 'Rose Bloom & Petals Cascade',
      emoji: '🌹',
      tier: GiftTier.basic,
      launchAnimation: LaunchType.bezierArc,
      showcaseAnimation: ShowcaseType.bloomRotate,
      showcaseDuration: Duration(seconds: 2),
      particleEffect: ParticleEffectConfig(
        type: ParticleEffectType.rosePetals,
        quantity: 24,
        colorPalette: [Colors.pinkAccent, Colors.redAccent],
      ),
      cameraEffect: CameraEffectConfig(type: CameraEffectType.none),
      splitEffect: SplitEffectType.magicBurst,
      landingEffect: LandingEffectType.heartBurst,
      themeColor: Colors.pinkAccent,
      customLottiePath: 'assets/animations/gifts/gift_rose.json',
    ),

    // 🏎️ Car (Rare / Premium - 3 sec Showcase)
    'gift_sports_car': const GiftConfig(
      giftId: 'a2000000-0000-0000-0000-000000000013',
      animationKey: 'gift_sports_car',
      name: 'Neon Supercar Speed Drive',
      emoji: '🏎️',
      tier: GiftTier.premium,
      launchAnimation: LaunchType.linear,
      showcaseAnimation: ShowcaseType.vehicleDrive,
      showcaseDuration: Duration(seconds: 3),
      particleEffect: ParticleEffectConfig(
        type: ParticleEffectType.sportsCarDrive,
        quantity: 36,
        colorPalette: [Colors.deepOrange, Colors.yellowAccent],
      ),
      cameraEffect: CameraEffectConfig(type: CameraEffectType.zoomIn, intensity: 1.2),
      soundEffect: SoundEffectConfig(soundKey: 'car_horn', volume: 0.8),
      splitEffect: SplitEffectType.energyPulse,
      landingEffect: LandingEffectType.goldenPulse,
      themeColor: Colors.deepOrange,
      customLottiePath: 'assets/animations/gifts/gift_sports_car.json',
    ),

    // 🚀 Rocket (Epic - 4 sec Showcase)
    'gift_rocket': const GiftConfig(
      giftId: 'a2000000-0000-0000-0000-000000000015',
      animationKey: 'gift_rocket',
      name: 'Cosmic Rocket Launch',
      emoji: '🚀',
      tier: GiftTier.epic,
      launchAnimation: LaunchType.spiralRise,
      showcaseAnimation: ShowcaseType.rocketLaunch,
      showcaseDuration: Duration(seconds: 4),
      particleEffect: ParticleEffectConfig(
        type: ParticleEffectType.fireStars,
        quantity: 48,
        colorPalette: [Colors.orange, Colors.red, Colors.yellow],
        hasTail: true,
      ),
      cameraEffect: CameraEffectConfig(type: CameraEffectType.screenShake, intensity: 1.5),
      soundEffect: SoundEffectConfig(soundKey: 'rocket_launch', volume: 1.0),
      splitEffect: SplitEffectType.fireRing,
      landingEffect: LandingEffectType.starRing,
      themeColor: Colors.orangeAccent,
    ),

    // 🏰 Castle (Legendary - 5 sec Showcase)
    'gift_castle': const GiftConfig(
      giftId: 'a2000000-0000-0000-0000-000000000016',
      animationKey: 'gift_castle',
      name: 'Royal Palace Kingdom',
      emoji: '🏰',
      tier: GiftTier.legendary,
      launchAnimation: LaunchType.teleportPulse,
      showcaseAnimation: ShowcaseType.buildingRise,
      showcaseDuration: Duration(seconds: 5),
      particleEffect: ParticleEffectConfig(
        type: ParticleEffectType.goldenShine,
        quantity: 60,
        colorPalette: [Colors.amber, Colors.yellow, Colors.white],
      ),
      cameraEffect: CameraEffectConfig(type: CameraEffectType.ambientDim, intensity: 0.6),
      soundEffect: SoundEffectConfig(soundKey: 'castle_fanfare', volume: 1.0),
      splitEffect: SplitEffectType.goldenFlash,
      landingEffect: LandingEffectType.goldenPulse,
      layerPriority: LayerPriority.exclusive,
      themeColor: Colors.amber,
    ),

    // 🐉 Dragon (Mythic - 6 sec Showcase)
    'gift_dragon': const GiftConfig(
      giftId: 'a2000000-0000-0000-0000-000000000017',
      animationKey: 'gift_dragon',
      name: 'Imperial Fire Dragon',
      emoji: '🐉',
      tier: GiftTier.mythic,
      launchAnimation: LaunchType.spiralRise,
      showcaseAnimation: ShowcaseType.dragonFlyaround,
      showcaseDuration: Duration(seconds: 6),
      particleEffect: ParticleEffectConfig(
        type: ParticleEffectType.fireStars,
        quantity: 72,
        colorPalette: [Colors.red, Colors.deepOrange, Colors.amber],
        hasTail: true,
      ),
      cameraEffect: CameraEffectConfig(type: CameraEffectType.screenShake, intensity: 2.0),
      soundEffect: SoundEffectConfig(soundKey: 'dragon_roar', volume: 1.0),
      splitEffect: SplitEffectType.crystalExplosion,
      landingEffect: LandingEffectType.sparkleExplosion,
      layerPriority: LayerPriority.exclusive,
      themeColor: Colors.redAccent,
    ),

    // 🌌 Universe (Mythic / Ultra - 7 sec Showcase)
    'gift_universe': const GiftConfig(
      giftId: 'a2000000-0000-0000-0000-000000000018',
      animationKey: 'gift_universe',
      name: 'Universal Galaxy Nexus',
      emoji: '🌌',
      tier: GiftTier.mythic,
      launchAnimation: LaunchType.teleportPulse,
      showcaseAnimation: ShowcaseType.universeGalaxy,
      showcaseDuration: Duration(seconds: 7),
      particleEffect: ParticleEffectConfig(
        type: ParticleEffectType.cosmicMeteors,
        quantity: 90,
        colorPalette: [Colors.purpleAccent, Colors.cyanAccent, Colors.white],
        hasTail: true,
      ),
      cameraEffect: CameraEffectConfig(type: CameraEffectType.spaceDistortion, intensity: 2.5),
      soundEffect: SoundEffectConfig(soundKey: 'cosmic_hum', volume: 1.0),
      splitEffect: SplitEffectType.lightBeam,
      landingEffect: LandingEffectType.starRing,
      layerPriority: LayerPriority.exclusive,
      themeColor: Colors.deepPurpleAccent,
    ),
  };

  /// Gets the animation configuration for a gift ID or gift key or name.
  static GiftConfig getConfig(String giftIdOrKey) {
    if (_registry.containsKey(giftIdOrKey)) {
      return _registry[giftIdOrKey]!;
    }

    final keyMatch = _registry.values.firstWhere(
      (c) => c.giftId == giftIdOrKey || c.animationKey == giftIdOrKey,
      orElse: () {
        final meta = GiftMetadataRegistry.getMetadata(giftIdOrKey);
        return GiftConfig(
          giftId: meta.giftId,
          animationKey: meta.giftName,
          name: meta.giftName,
          emoji: meta.giftIcon,
          tier: meta.tier,
          showcaseAnimation: _getShowcaseTypeByTier(meta.tier),
          showcaseDuration: _getShowcaseDurationByTier(meta.tier),
          themeColor: meta.themeColor,
        );
      },
    );

    return keyMatch;
  }

  static ShowcaseType _getShowcaseTypeByTier(GiftTier tier) {
    switch (tier) {
      case GiftTier.basic:
        return ShowcaseType.bloomRotate;
      case GiftTier.premium:
        return ShowcaseType.vehicleDrive;
      case GiftTier.epic:
        return ShowcaseType.rocketLaunch;
      case GiftTier.legendary:
        return ShowcaseType.buildingRise;
      case GiftTier.mythic:
        return ShowcaseType.dragonFlyaround;
    }
  }

  static Duration _getShowcaseDurationByTier(GiftTier tier) {
    switch (tier) {
      case GiftTier.basic:
        return const Duration(seconds: 2);
      case GiftTier.premium:
        return const Duration(seconds: 3);
      case GiftTier.epic:
        return const Duration(seconds: 4);
      case GiftTier.legendary:
        return const Duration(seconds: 5);
      case GiftTier.mythic:
        return const Duration(seconds: 6);
    }
  }
}
