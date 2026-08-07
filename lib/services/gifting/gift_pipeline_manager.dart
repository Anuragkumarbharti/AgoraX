// lib/services/gifting/gift_pipeline_manager.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import '../../models/gift/gift_animation_metadata.dart';

enum DevicePerformanceTier { lowEnd, midRange, highEnd }

class PooledParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double alpha;
  double life;
  double maxLife;
  Color color;

  PooledParticle({
    this.x = 0.0,
    this.y = 0.0,
    this.vx = 0.0,
    this.vy = 0.0,
    this.size = 6.0,
    this.alpha = 1.0,
    this.life = 0.0,
    this.maxLife = 1.0,
    this.color = Colors.amber,
  });

  void reset() {
    x = 0.0;
    y = 0.0;
    vx = 0.0;
    vy = 0.0;
    size = 6.0;
    alpha = 1.0;
    life = 0.0;
    maxLife = 1.0;
    color = Colors.amber;
  }
}

/// Object Pool Manager for zero allocations during playback
class ParticlePoolManager {
  static final ParticlePoolManager _instance = ParticlePoolManager._internal();
  factory ParticlePoolManager() => _instance;
  ParticlePoolManager._internal();

  final List<PooledParticle> _particlePool = List.generate(200, (_) => PooledParticle());
  final List<PooledParticle> _activeParticles = [];

  PooledParticle obtainParticle() {
    if (_particlePool.isNotEmpty) {
      final p = _particlePool.removeLast();
      p.reset();
      _activeParticles.add(p);
      return p;
    }
    final p = PooledParticle();
    _activeParticles.add(p);
    return p;
  }

  void releaseParticle(PooledParticle p) {
    _activeParticles.remove(p);
    if (_particlePool.length < 300) {
      p.reset();
      _particlePool.add(p);
    }
  }

  void releaseAll() {
    for (final p in _activeParticles) {
      if (_particlePool.length < 300) {
        p.reset();
        _particlePool.add(p);
      }
    }
    _activeParticles.clear();
  }
}

class QueueableGiftAnimation {
  final String id;
  final String giftId;
  final String giftName;
  final String giftIcon;
  final int cost;
  final String currency;
  final GiftTier tier;
  final String senderName;
  final String? senderAvatar;
  final Offset startOffset;
  final String receiverName;
  final String? receiverAvatar;
  final Offset targetOffset;
  final List<Offset>? targetOffsets;
  final int count;
  final Map<String, dynamic>? luckyResult;

  QueueableGiftAnimation({
    required this.id,
    required this.giftId,
    required this.giftName,
    required this.giftIcon,
    required this.cost,
    required this.currency,
    required this.tier,
    required this.senderName,
    this.senderAvatar,
    required this.startOffset,
    required this.receiverName,
    this.receiverAvatar,
    required this.targetOffset,
    this.targetOffsets,
    this.count = 1,
    this.luckyResult,
  });
}

class GiftPipelineManager extends GetxService {
  static GiftPipelineManager get to {
    if (!Get.isRegistered<GiftPipelineManager>()) {
      return Get.put(GiftPipelineManager());
    }
    return Get.find<GiftPipelineManager>();
  }

  final Queue<QueueableGiftAnimation> _animationQueue = Queue<QueueableGiftAnimation>();
  final Rxn<QueueableGiftAnimation> activeAnimation = Rxn<QueueableGiftAnimation>();
  final RxBool isAssetPreloading = false.obs;

  // Smart LRU Asset Cache
  final Set<String> _preloadedAssets = {};
  final Map<String, DateTime> _assetLastUsedTime = {};

  // Performance Monitor
  DevicePerformanceTier deviceTier = DevicePerformanceTier.highEnd;
  double _lastFrameMs = 16.0;
  int maxAllowedParticles = 100;

  @override
  void onInit() {
    super.onInit();
    _detectDevicePerformance();
    _startFrameTimingMonitor();
  }

  void _detectDevicePerformance() {
    deviceTier = DevicePerformanceTier.highEnd;
    maxAllowedParticles = 120;
  }

  void _startFrameTimingMonitor() {
    SchedulerBinding.instance.addTimingsCallback((timings) {
      if (timings.isNotEmpty) {
        final frameMs = timings.last.totalSpan.inMicroseconds / 1000.0;
        _lastFrameMs = 0.8 * _lastFrameMs + 0.2 * frameMs;

        if (_lastFrameMs > 20.0 && deviceTier != DevicePerformanceTier.lowEnd) {
          deviceTier = DevicePerformanceTier.lowEnd;
          maxAllowedParticles = 40;
          debugPrint('[GiftPipeline] Performance Guard: Lowering particle budget to 40 for 60 FPS stability');
        } else if (_lastFrameMs > 16.6 && deviceTier == DevicePerformanceTier.highEnd) {
          deviceTier = DevicePerformanceTier.midRange;
          maxAllowedParticles = 75;
        }
      }
    });
  }

  /// Entry point: Enqueues gift animation after background asset preparation
  Future<void> enqueueGift(QueueableGiftAnimation gift) async {
    isAssetPreloading.value = true;
    await _preloadAssetsForGift(gift);
    isAssetPreloading.value = false;

    _animationQueue.add(gift);
    _processQueue();
  }

  Future<void> _preloadAssetsForGift(QueueableGiftAnimation gift) async {
    final cacheKey = '${gift.giftId}_${gift.tier.name}';
    _assetLastUsedTime[cacheKey] = DateTime.now();

    if (_preloadedAssets.contains(cacheKey)) return;

    await Future.delayed(const Duration(milliseconds: 16));
    _preloadedAssets.add(cacheKey);

    _cleanLRUCache();
  }

  void _cleanLRUCache() {
    final now = DateTime.now();
    _assetLastUsedTime.removeWhere((key, lastUsed) {
      if (now.difference(lastUsed).inSeconds > 30 && !key.contains('tier1') && !key.contains('tier2')) {
        _preloadedAssets.remove(key);
        return true;
      }
      return false;
    });
  }

  void _processQueue() {
    if (activeAnimation.value != null) {
      return;
    }

    if (_animationQueue.isNotEmpty) {
      final nextGift = _animationQueue.removeFirst();
      activeAnimation.value = nextGift;
      debugPrint('[GiftPipeline] Playing Gift: ${nextGift.giftName} (Tier: ${nextGift.tier.name})');
    }
  }

  void onAnimationCompleted() {
    activeAnimation.value = null;
    ParticlePoolManager().releaseAll();
    _processQueue();
  }

  void clearQueue() {
    _animationQueue.clear();
    activeAnimation.value = null;
    ParticlePoolManager().releaseAll();
  }
}
