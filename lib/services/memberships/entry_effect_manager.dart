// lib/services/memberships/entry_effect_manager.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../storage/asset_cache_manager.dart';

/// High-Performance Entry Effect Manager & Bounded Video Player Pool.
///
/// Features:
/// 1. Bounded Pool: Strict limit of maximum 2 active VideoPlayerControllers in RAM.
/// 2. In-Flight Request Deduplication: Rapid user room entries perform at most 1 video download per asset.
/// 3. Non-Blocking: Room join & voice connection complete immediately regardless of video download status.
/// 4. Auto-Release: Old or completed controllers are immediately disposed to prevent memory leaks.
class EntryEffectManager {
  static final EntryEffectManager instance = EntryEffectManager._internal();
  EntryEffectManager._internal();

  /// Maximum active video controllers allowed concurrently in RAM
  static const int maxActiveControllers = 2;

  /// Active controllers currently in use: Controller -> Key
  final Map<VideoPlayerController, String> _activeControllers = {};

  /// In-flight video downloads deduplication: key -> Future<File?>
  final Map<String, Future<File?>> _inFlightVideoDownloads = {};

  /// Pre-warmed cached files on disk
  final Map<String, File> _cachedVideoFiles = {};

  /// Aquire and initialize a VideoPlayerController for an entry effect asset.
  /// Bounded to maximum 2 active controllers in RAM.
  Future<VideoPlayerController?> acquireVideoController(String assetUrlOrPath) async {
    if (assetUrlOrPath.trim().isEmpty) return null;

    final String cleanKey = _getCleanKey(assetUrlOrPath);

    // Enforce pool limit: if pool is full, dispose the oldest active controller
    if (_activeControllers.length >= maxActiveControllers) {
      final oldestCtrl = _activeControllers.keys.first;
      await releaseVideoController(oldestCtrl);
      if (kDebugMode) {
        debugPrint('[EntryEffect] Bounded pool max reached ($maxActiveControllers). Evicted oldest controller.');
      }
    }

    try {
      VideoPlayerController controller;

      if (assetUrlOrPath.startsWith('assets/')) {
        // Asset-based video player
        controller = VideoPlayerController.asset(
          assetUrlOrPath,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else {
        // Network/Cached video file
        final File? videoFile = await getOrFetchVideoFile(assetUrlOrPath);
        if (videoFile != null && await videoFile.exists()) {
          controller = VideoPlayerController.file(
            videoFile,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        } else {
          // Direct network fallback
          controller = VideoPlayerController.networkUrl(
            Uri.parse(assetUrlOrPath),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        }
      }

      final Stopwatch sw = Stopwatch()..start();
      await controller.initialize();
      controller.setVolume(0.0);
      controller.setLooping(false);
      sw.stop();

      _activeControllers[controller] = cleanKey;

      if (kDebugMode) {
        debugPrint('[EntryEffect] Player Pool Acquired: $cleanKey (Init in ${sw.elapsedMilliseconds}ms, Active Pool: ${_activeControllers.length}/$maxActiveControllers)');
      }

      return controller;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EntryEffect] Failed to acquire video controller for $assetUrlOrPath: $e');
      }
      return null;
    }
  }

  /// Releases & disposes a VideoPlayerController back to the pool.
  Future<void> releaseVideoController(VideoPlayerController? controller) async {
    if (controller == null) return;

    final String? key = _activeControllers.remove(controller);
    try {
      if (controller.value.isInitialized) {
        await controller.pause();
        await controller.seekTo(Duration.zero);
      }
      await controller.dispose();
      if (kDebugMode) {
        debugPrint('[EntryEffect] Player Released & Disposed: ${key ?? "unknown"} (Remaining Pool: ${_activeControllers.length})');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EntryEffect] Error releasing video controller: $e');
      }
    }
  }

  /// Downloads & caches entry effect video file with in-flight deduplication.
  Future<File?> getOrFetchVideoFile(String videoUrl) async {
    if (videoUrl.isEmpty || videoUrl.startsWith('assets/')) return null;

    final String cleanKey = _getCleanKey(videoUrl);

    // 1. Memory check
    if (_cachedVideoFiles.containsKey(cleanKey)) {
      final file = _cachedVideoFiles[cleanKey]!;
      if (await file.exists()) {
        if (kDebugMode) {
          debugPrint('[EntryEffect] Video Cache HIT: $cleanKey');
        }
        return file;
      } else {
        _cachedVideoFiles.remove(cleanKey);
      }
    }

    // 2. Disk cache check
    try {
      final FileInfo? fileInfo = await CreaniaAssetCacheManager.instance.getFileFromCache(cleanKey);
      if (fileInfo != null && await fileInfo.file.exists()) {
        _cachedVideoFiles[cleanKey] = fileInfo.file;
        return fileInfo.file;
      }
    } catch (_) {}

    // 3. In-flight deduplication
    if (_inFlightVideoDownloads.containsKey(cleanKey)) {
      if (kDebugMode) {
        debugPrint('[EntryEffect] In-Flight Video Download Joined: $cleanKey');
      }
      return await _inFlightVideoDownloads[cleanKey]!;
    }

    // 4. Single Network Download
    final fetchFuture = _downloadVideo(videoUrl, cleanKey);
    _inFlightVideoDownloads[cleanKey] = fetchFuture;

    try {
      return await fetchFuture;
    } finally {
      _inFlightVideoDownloads.remove(cleanKey);
    }
  }

  Future<File?> _downloadVideo(String url, String cacheKey) async {
    try {
      final File downloaded = await CreaniaAssetCacheManager.instance.getSingleFile(url, key: cacheKey);
      if (await downloaded.exists()) {
        _cachedVideoFiles[cacheKey] = downloaded;
        if (kDebugMode) {
          debugPrint('[EntryEffect] Video Downloaded & Cached: $cacheKey (${downloaded.lengthSync()} bytes)');
        }
        return downloaded;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EntryEffect] Video Download Failed: $url - $e');
      }
    }
    return null;
  }

  String _getCleanKey(String url) {
    if (url.isEmpty) return 'empty';
    final Uri uri = Uri.parse(url);
    final String path = uri.path;
    return path.replaceAll('/', '_');
  }

  /// Evicts all active video controllers
  Future<void> disposeAll() async {
    final list = List<VideoPlayerController>.from(_activeControllers.keys);
    for (final ctrl in list) {
      await releaseVideoController(ctrl);
    }
    _activeControllers.clear();
    _cachedVideoFiles.clear();
  }
}
