// lib/services/gifting/gift_media_manager.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../storage/asset_cache_manager.dart';

/// High-performance central manager for Gift Animation & Static Asset Caching.
///
/// Features:
/// 1. Two-Level Caching: Memory Cache (RAM) + Disk Cache (CreaniaAssetCacheManager).
/// 2. In-Flight Request Deduplication: Rapid requests for the same asset perform EXACTLY 1 network download.
/// 3. Non-Blocking: Download & decoding tasks run asynchronously without interrupting UI/audio looper.
class GiftMediaManager {
  static final GiftMediaManager instance = GiftMediaManager._internal();
  GiftMediaManager._internal();

  /// Memory Cache for cached Files on disk (RAM mapping)
  final Map<String, File> _memoryFileCache = {};

  /// In-Flight network request deduplication tracker: key -> Future<File>
  final Map<String, Future<File?>> _inFlightDownloads = {};

  /// Maximum items to hold in memory cache
  static const int maxMemoryItems = 60;

  /// Gets a cached File for a given animation asset URL/path, or downloads it with deduplication.
  Future<File?> getOrFetchAnimationFile(String assetUrlOrPath) async {
    if (assetUrlOrPath.trim().isEmpty) return null;

    final String cleanKey = _getCleanKey(assetUrlOrPath);

    // 1. Check Memory Cache (Instant RAM lookup)
    if (_memoryFileCache.containsKey(cleanKey)) {
      final cached = _memoryFileCache[cleanKey]!;
      if (await cached.exists()) {
        if (kDebugMode) {
          debugPrint('[GiftMedia] Cache HIT (Memory): $cleanKey');
        }
        return cached;
      } else {
        _memoryFileCache.remove(cleanKey);
      }
    }

    // 2. Local asset path
    if (assetUrlOrPath.startsWith('assets/')) {
      return null; // Handled directly by Image.asset / Lottie.asset
    }

    // 3. Check Disk Cache
    try {
      final FileInfo? fileInfo = await CreaniaAssetCacheManager.instance.getFileFromCache(cleanKey);
      if (fileInfo != null && await fileInfo.file.exists()) {
        _putMemoryCache(cleanKey, fileInfo.file);
        if (kDebugMode) {
          debugPrint('[GiftMedia] Cache HIT (Disk): $cleanKey');
        }
        return fileInfo.file;
      }
    } catch (_) {}

    // 4. In-Flight Request Deduplication: check if another caller is already fetching this exact URL
    if (_inFlightDownloads.containsKey(cleanKey)) {
      if (kDebugMode) {
        debugPrint('[GiftMedia] Deduplicated Network Request (In-flight joined): $cleanKey');
      }
      return await _inFlightDownloads[cleanKey]!;
    }

    // 5. Initiate Single Network Download
    final fetchFuture = _downloadAndCache(assetUrlOrPath, cleanKey);
    _inFlightDownloads[cleanKey] = fetchFuture;

    try {
      final file = await fetchFuture;
      return file;
    } finally {
      _inFlightDownloads.remove(cleanKey);
    }
  }

  Future<File?> _downloadAndCache(String url, String cacheKey) async {
    final Stopwatch sw = Stopwatch()..start();
    try {
      final File downloadedFile = await CreaniaAssetCacheManager.instance.getSingleFile(url, key: cacheKey);
      if (await downloadedFile.exists()) {
        _putMemoryCache(cacheKey, downloadedFile);
        sw.stop();
        if (kDebugMode) {
          debugPrint('[GiftMedia] Network Download Complete: $cacheKey (${downloadedFile.lengthSync()} bytes in ${sw.elapsedMilliseconds}ms)');
        }
        return downloadedFile;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GiftMedia] Network Download Failed for $url: $e');
      }
    }
    return null;
  }

  /// Pre-warms gift assets in background without blocking UI
  Future<void> prewarmGiftAssets(List<String> assetUrls) async {
    for (final url in assetUrls) {
      if (url.isEmpty || url.startsWith('assets/')) continue;
      unawaited(getOrFetchAnimationFile(url));
    }
  }

  void _putMemoryCache(String key, File file) {
    if (_memoryFileCache.length >= maxMemoryItems) {
      // LRU Eviction: remove oldest key
      final oldestKey = _memoryFileCache.keys.first;
      _memoryFileCache.remove(oldestKey);
    }
    _memoryFileCache[key] = file;
  }

  String _getCleanKey(String url) {
    if (url.isEmpty) return 'empty';
    final Uri uri = Uri.parse(url);
    final String path = uri.path;
    return path.replaceAll('/', '_');
  }

  /// Evicts memory cache (useful during low memory warnings)
  void clearMemoryCache() {
    _memoryFileCache.clear();
    if (kDebugMode) {
      debugPrint('[GiftMedia] Memory cache cleared.');
    }
  }
}
