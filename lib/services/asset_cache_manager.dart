import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/user_model.dart';
import '../models/room_model.dart';

enum ImageQuality { thumbnail, medium, original }

class CreaniaAssetCacheManager {
  static const String key = 'creania_asset_cache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 500,
    ),
  );
}

class AssetCacheManager {
  static final _prefetchQueue = <String>[];
  static bool _isPrefetching = false;
  static final Connectivity _connectivity = Connectivity();

  /// Returns the valid public URL for loading images safely
  static String getOptimizedUrl(String url, ImageQuality quality) {
    if (url.isEmpty) return url;
    return url;
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
