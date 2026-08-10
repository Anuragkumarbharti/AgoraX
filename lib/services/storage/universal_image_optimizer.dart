import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import './asset_cache_manager.dart';

/// Supported image usage categories with defined maximum dimensions & quality targets
enum ImageCategoryType {
  avatar,         // 512x512 max (sizes: 64, 128, 256, 512)
  profileCover,   // 1080px max (sizes: 480, 720, 1080)
  roomBackground, // 1440px max (sizes: 720, 1080, 1440)
  chatImage,      // 1280px max
  gallery,        // 2048px max
  storyPost,      // 1440px max
  giftImage,      // 512x512 max
  general,        // 2048px max
}

/// Result metadata for an optimized image
class OptimizedImageResult {
  final String publicUrl;
  final String sha256Hash;
  final int originalSizeBytes;
  final int optimizedSizeBytes;
  final int width;
  final int height;

  const OptimizedImageResult({
    required this.publicUrl,
    required this.sha256Hash,
    required this.originalSizeBytes,
    required this.optimizedSizeBytes,
    required this.width,
    required this.height,
  });

  double get compressionRatio => originalSizeBytes > 0
      ? (1.0 - (optimizedSizeBytes / originalSizeBytes)) * 100.0
      : 0.0;
}

class UniversalImageOptimizer {
  /// Maximum allowed raw upload size before rejection (50 MB)
  static const int maxRawFileSizeBytes = 50 * 1024 * 1024;

  /// Max long-side dimensions for each ImageCategoryType
  static int getMaxDimension(ImageCategoryType type) {
    switch (type) {
      case ImageCategoryType.avatar:
      case ImageCategoryType.giftImage:
        return 512;
      case ImageCategoryType.chatImage:
        return 1280;
      case ImageCategoryType.storyPost:
      case ImageCategoryType.roomBackground:
        return 1440;
      case ImageCategoryType.profileCover:
        return 1080;
      case ImageCategoryType.gallery:
      case ImageCategoryType.general:
      default:
        return 2048;
    }
  }

  /// Quality target based on image category
  static int getTargetQuality(ImageCategoryType type) {
    switch (type) {
      case ImageCategoryType.avatar:
        return 60; // 55-65 range
      case ImageCategoryType.profileCover:
        return 65; // 60-70 range
      case ImageCategoryType.roomBackground:
      case ImageCategoryType.storyPost:
      case ImageCategoryType.gallery:
        return 70; // 65-75 range
      default:
        return 75;
    }
  }

  /// Bucket names corresponding to category
  static String getBucketName(ImageCategoryType type) {
    switch (type) {
      case ImageCategoryType.avatar:
        return 'avatars';
      case ImageCategoryType.profileCover:
      case ImageCategoryType.roomBackground:
        return 'banners';
      case ImageCategoryType.chatImage:
        return 'chat-media';
      case ImageCategoryType.storyPost:
      case ImageCategoryType.gallery:
        return 'posts';
      case ImageCategoryType.giftImage:
      case ImageCategoryType.general:
      default:
        return 'avatars';
    }
  }

  /// Calculates SHA-256 hash of raw byte payload for duplicate detection
  static String calculateSha256(Uint8List bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Validates image bytes format
  static bool isValidImageBytes(Uint8List bytes) {
    if (bytes.length < 32) return false;
    try {
      return img.decodeImage(bytes) != null;
    } catch (_) {
      return false;
    }
  }

  /// 100% Pure Dart isolate worker using `package:image`
  /// Strips EXIF metadata, bakes orientation, resizes, and encodes to compressed bytes cleanly!
  static Map<String, dynamic> _processAndCompressImageInIsolate(Map<String, dynamic> params) {
    final Uint8List rawBytes = params['bytes'] as Uint8List;
    final int maxDimension = params['maxDimension'] as int;
    final int quality = params['quality'] as int;
    final String storagePath = (params['storagePath'] as String? ?? '').toLowerCase();

    img.Image? decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      throw Exception('Failed to decode image file bytes');
    }

    // Bake EXIF orientation & strip EXIF metadata
    decoded = img.bakeOrientation(decoded);

    int originalW = decoded.width;
    int originalH = decoded.height;

    int targetW = originalW;
    int targetH = originalH;

    if (originalW > maxDimension || originalH > maxDimension) {
      if (originalW >= originalH && originalW > 0) {
        targetW = maxDimension;
        final double calcH = (originalH * maxDimension) / originalW;
        targetH = (calcH.isNaN || calcH.isInfinite) ? maxDimension : calcH.round();
      } else if (originalH > 0) {
        targetH = maxDimension;
        final double calcW = (originalW * maxDimension) / originalH;
        targetW = (calcW.isNaN || calcW.isInfinite) ? maxDimension : calcW.round();
      }
    }

    if (targetW != originalW || targetH != originalH) {
      decoded = img.copyResize(
        decoded,
        width: targetW,
        height: targetH,
        interpolation: img.Interpolation.average,
      );
    }

    final String lowerPath = storagePath.toLowerCase();
    String mimeType = 'image/png';
    Uint8List encoded;

    if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')) {
      mimeType = 'image/jpeg';
      try {
        encoded = Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
      } catch (_) {
        encoded = Uint8List.fromList(img.encodePng(decoded));
      }
    } else {
      mimeType = 'image/png';
      try {
        encoded = Uint8List.fromList(img.encodePng(decoded));
      } catch (_) {
        encoded = Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
      }
    }

    return {
      'bytes': encoded,
      'mimeType': mimeType,
    };
  }

  /// List and delete any previous avatar files in the user's avatars folder in storage
  static Future<void> deleteOldAvatars(String userId) async {
    if (userId.trim().isEmpty) return;
    try {
      final List<FileObject> existing = await Supabase.instance.client.storage.from('avatars').list(path: userId);
      if (existing.isNotEmpty) {
        final List<String> pathsToDelete = existing.map((f) => '$userId/${f.name}').toList();
        await Supabase.instance.client.storage.from('avatars').remove(pathsToDelete);
        debugPrint('[UniversalImageOptimizer] Cleaned up ${pathsToDelete.length} old avatar file(s) for user $userId');
      }
    } catch (e) {
      debugPrint('[UniversalImageOptimizer] Warning: Could not delete old avatar files: $e');
    }
  }

  /// List and delete any previous banner/cover files in the user's banners folder in storage
  static Future<void> deleteOldCovers(String userId) async {
    if (userId.trim().isEmpty) return;
    try {
      final List<FileObject> existing = await Supabase.instance.client.storage.from('banners').list(path: userId);
      if (existing.isNotEmpty) {
        final List<String> pathsToDelete = existing.map((f) => '$userId/${f.name}').toList();
        await Supabase.instance.client.storage.from('banners').remove(pathsToDelete);
        debugPrint('[UniversalImageOptimizer] Cleaned up ${pathsToDelete.length} old cover file(s) for user $userId');
      }
    } catch (e) {
      debugPrint('[UniversalImageOptimizer] Warning: Could not delete old cover files: $e');
    }
  }

  /// Core high-level entrypoint: Optimizes an image file/bytes and uploads it to Supabase Storage.
  static Future<OptimizedImageResult> optimizeAndUpload({
    io.File? file,
    Uint8List? rawBytes,
    required ImageCategoryType category,
    required String storagePath,
    String? customBucket,
  }) async {
    Uint8List inputBytes;
    if (rawBytes != null && rawBytes.isNotEmpty) {
      inputBytes = rawBytes;
    } else if (file != null && await file.exists()) {
      inputBytes = await file.readAsBytes();
    } else {
      throw Exception('Invalid image input: File or bytes required');
    }

    // 1. Validation Checks
    if (inputBytes.length > maxRawFileSizeBytes) {
      throw Exception('File size (${(inputBytes.length / (1024 * 1024)).toStringAsFixed(1)} MB) exceeds maximum 50 MB limit');
    }

    final int originalSize = inputBytes.length;
    final String hash = calculateSha256(inputBytes);
    final int maxDim = getMaxDimension(category);
    final int quality = getTargetQuality(category);

    // 2. Offload decoding, resizing & metadata stripping to isolate using pure Dart `image` package
    final Map<String, dynamic> processed = await compute(_processAndCompressImageInIsolate, {
      'bytes': inputBytes,
      'maxDimension': maxDim,
      'quality': quality,
      'storagePath': storagePath,
    });

    final Uint8List optimizedBytes = processed['bytes'] as Uint8List;
    final String mimeType = processed['mimeType'] as String? ?? 'image/png';

    final int optimizedSize = optimizedBytes.length;
    debugPrint('[UniversalImageOptimizer] Pure Dart compression complete: $originalSize bytes -> $optimizedSize bytes (${(100 - (optimizedSize / originalSize * 100)).toStringAsFixed(1)}% saved, mime=$mimeType)');

    // 3. Select bucket & upload to Supabase Storage
    final String bucket = customBucket ?? getBucketName(category);

    try {
      await Supabase.instance.client.storage.from(bucket).uploadBinary(
        storagePath,
        optimizedBytes,
        fileOptions: FileOptions(
          cacheControl: '3600',
          contentType: mimeType,
          upsert: true,
        ),
      );
    } catch (uploadError) {
      debugPrint('[UniversalImageOptimizer] Storage upload error: $uploadError');
      rethrow;
    }

    final String rawPublicUrl = Supabase.instance.client.storage.from(bucket).getPublicUrl(storagePath);
    final int ts = DateTime.now().millisecondsSinceEpoch;
    final String versionedPublicUrl = '$rawPublicUrl?v=$ts';

    // 4. Invalidate local asset cache for this URL
    AssetCacheManager.evictUrl(rawPublicUrl);
    AssetCacheManager.evictUrl(versionedPublicUrl);

    return OptimizedImageResult(
      publicUrl: versionedPublicUrl,
      sha256Hash: hash,
      originalSizeBytes: originalSize,
      optimizedSizeBytes: optimizedSize,
      width: maxDim,
      height: maxDim,
    );
  }
}
