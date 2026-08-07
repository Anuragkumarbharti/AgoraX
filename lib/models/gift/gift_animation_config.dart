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
  static GiftConfig getConfig(String giftIdOrName) {
    final meta = GiftMetadataRegistry.getMetadata(giftIdOrName);
    return GiftConfig(
      giftId: meta.giftId,
      animationKey: meta.giftName.toLowerCase().replaceAll(' ', '_'),
      name: meta.giftName,
      emoji: meta.giftIcon,
      tier: meta.tier,
      showcaseAnimation: ShowcaseType.custom,
      showcaseDuration: meta.duration,
      themeColor: meta.themeColor,
      cameraEffect: meta.tier == GiftTier.tier4 || meta.tier == GiftTier.tier5
          ? const CameraEffectConfig(type: CameraEffectType.screenShake, intensity: 1.5)
          : const CameraEffectConfig(),
      layerPriority: meta.tier == GiftTier.tier5
          ? LayerPriority.exclusive
          : meta.tier == GiftTier.tier4
              ? LayerPriority.high
              : LayerPriority.normal,
    );
  }
}
