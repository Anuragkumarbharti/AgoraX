import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/user/user_model.dart';
import '../../models/room/room_model.dart';

import '../network/adaptive_media_manager.dart';

enum ImageQuality { thumbnail, medium, original }

/// Standard app-wide media size presets
enum MediaSizePreset {
  xs,       // 48px - Arena recipient, chat avatar
  sm,       // 64px - Arena seat, gift icon, list avatar
  md,       // 128px - Profile card, dialog header, post thumbnail
  lg,       // 256px - Banner preview, cover thumbnail
  xl,       // 512px - High-res avatar, header banner
  original, // Unchanged full resolution
}

class CreaniaAssetCacheManager {
  static const String key = 'creania_asset_cache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 90),
      maxNrOfCacheObjects: 3000,
    ),
  );
}

class AssetCacheManager {
  static final _prefetchQueue = <String>[];
  static bool _isPrefetching = false;
  static final Connectivity _connectivity = Connectivity();

  /// Map MediaSizePreset to target physical pixel width
  static int getDimensionForPreset(MediaSizePreset preset, {double devicePixelRatio = 1.0}) {
    final scale = devicePixelRatio > 0 ? devicePixelRatio : 1.0;
    int baseLogical;
    switch (preset) {
      case MediaSizePreset.xs:
        baseLogical = 48;
        break;
      case MediaSizePreset.sm:
        baseLogical = 64;
        break;
      case MediaSizePreset.md:
        baseLogical = 128;
        break;
      case MediaSizePreset.lg:
        baseLogical = 256;
        break;
      case MediaSizePreset.xl:
        baseLogical = 512;
        break;
      case MediaSizePreset.original:
        return 0; // 0 means original width
    }
    final calc = baseLogical * scale * 1.25;
    return (calc.isNaN || calc.isInfinite) ? baseLogical : calc.round();
  }

  /// Returns the valid public CDN URL transformed into optimized WebP format matching target preset
  static String getOptimizedUrl(
    String url,
    ImageQuality quality, {
    MediaSizePreset? preset,
    int? customWidth,
    int? customHeight,
    double devicePixelRatio = 1.0,
  }) {
    if (url.isEmpty || url.startsWith('assets/') || url.startsWith('file://')) return url;

    int? width = customWidth;
    if (width == null || width <= 0) {
      if (preset != null) {
        width = getDimensionForPreset(preset, devicePixelRatio: devicePixelRatio);
      } else {
        switch (quality) {
          case ImageQuality.thumbnail:
            width = getDimensionForPreset(MediaSizePreset.sm, devicePixelRatio: devicePixelRatio);
            break;
          case ImageQuality.medium:
            width = getDimensionForPreset(MediaSizePreset.md, devicePixelRatio: devicePixelRatio);
            break;
          case ImageQuality.original:
            width = 0;
            break;
        }
      }
    }

    if (width == 0) return url; // Full resolution requested

    return AdaptiveMediaManager.getAdaptiveImageUrl(
      url,
      targetWidth: width,
      targetHeight: customHeight,
      format: 'webp',
      quality: 80,
    );
  }

  /// Remove a cached image file from disk and memory cache
  static Future<void> evictUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final baseUrl = url.split('?')[0];
      await CreaniaAssetCacheManager.instance.removeFile(url);
      await CreaniaAssetCacheManager.instance.removeFile(baseUrl);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}
  }


  /// Add url to prefetch queue (only downloads on high speed network states)
  static void queuePrefetch(String url, ImageQuality quality) {
    if (url.isEmpty) return;
    final optimized = getOptimizedUrl(url, quality);
    if (!_prefetchQueue.contains(optimized)) {
      _prefetchQueue.add(optimized);
      _startPrefetchLoop();
    }
  }

  static void _startPrefetchLoop() async {
    if (_isPrefetching) return;
    _isPrefetching = true;

    while (_prefetchQueue.isNotEmpty) {
      try {
        final connectivityResult = await _connectivity.checkConnectivity();
        final hasGoodConnection = connectivityResult == ConnectivityResult.wifi || 
                                  connectivityResult == ConnectivityResult.mobile;

        if (hasGoodConnection) {
          final url = _prefetchQueue.removeAt(0);
          await CreaniaAssetCacheManager.instance.downloadFile(url);
          debugPrint('[AssetCacheManager] Background prefetched: $url');
        } else {
          // Pause and wait if network state deteriorates
          await Future.delayed(const Duration(seconds: 4));
        }
      } catch (_) {
        if (_prefetchQueue.isNotEmpty) {
          _prefetchQueue.removeAt(0); // Pop failing URLs to prevent stuck queues
        }
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
    _isPrefetching = false;
  }

  /// Prefetch essential assets of a User profile
  static void prefetchProfileAssets(User user) {
    if (user.avatar != null && user.avatar!.isNotEmpty) {
      queuePrefetch(user.avatar!, ImageQuality.thumbnail);
      queuePrefetch(user.avatar!, ImageQuality.medium);
    }
    if (user.coverPhoto != null && user.coverPhoto!.isNotEmpty) {
      queuePrefetch(user.coverPhoto!, ImageQuality.medium);
    }
  }

  /// Prefetch assets of a VoiceRoom/Arena
  static void prefetchRoomAssets(VoiceRoom room) {
    if (room.avatar != null && room.avatar!.isNotEmpty) {
      queuePrefetch(room.avatar!, ImageQuality.thumbnail);
    }
    if (room.roomCoverUrl != null && room.roomCoverUrl!.isNotEmpty) {
      queuePrefetch(room.roomCoverUrl!, ImageQuality.medium);
    }
  }
}
