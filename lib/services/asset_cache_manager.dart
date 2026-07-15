import 'dart:async';
import 'package:flutter/foundation.dart';
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

  /// Transform standard Supabase URL to use CDN image resizing and WebP formats
  static String getOptimizedUrl(String url, ImageQuality quality) {
    if (url.isEmpty) return url;
    if (!url.contains('storage/v1/object/public/')) return url;
    if (quality == ImageQuality.original) return url;

    // Convert object URL to Supabase CDN render URL
    final transformed = url.replaceAll('storage/v1/object/public/', 'storage/v1/render/image/public/');

    if (quality == ImageQuality.thumbnail) {
      return '$transformed?width=150&height=150&resize=cover&format=origin';
    } else {
      return '$transformed?width=600&resize=contain&format=origin';
    }
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
