import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import './network_adaptive_manager.dart';

class AdaptiveMediaManager extends GetxService {
  static AdaptiveMediaManager get to => Get.find();

  Worker? _policyWorker;

  @override
  void onInit() {
    super.onInit();

    if (Get.isRegistered<NetworkAdaptiveManager>()) {
      _policyWorker = ever(NetworkAdaptiveManager.to.activePolicy, (DynamicNetworkPolicy policy) {
        _applyAudioBitratePolicy(policy);
      });
    }
  }

  @override
  void onClose() {
    _policyWorker?.dispose();
    super.onClose();
  }

  /// Returns valid public image URL safely with Supabase WebP CDN transformation
  static String getAdaptiveImageUrl(
    String url, {
    int? targetWidth,
    int? targetHeight,
    int? quality,
    String format = 'webp',
    String resize = 'cover',
  }) {
    if (url.isEmpty) return url;

    // Handle Supabase Storage render transformation
    if (url.contains('/storage/v1/object/public/')) {
      final renderUrl = url.replaceAll('/storage/v1/object/public/', '/storage/v1/render/image/public/');
      final uri = Uri.parse(renderUrl);
      final queryParams = Map<String, String>.from(uri.queryParameters);

      if (targetWidth != null && targetWidth > 0) {
        queryParams['width'] = targetWidth.toString();
      }
      if (targetHeight != null && targetHeight > 0) {
        queryParams['height'] = targetHeight.toString();
      }
      queryParams['format'] = format;
      queryParams['quality'] = (quality ?? 80).clamp(30, 100).toString();
      queryParams['resize'] = resize;

      return uri.replace(queryParameters: queryParams).toString();
    }

    // Handle Unsplash image dynamic sizing
    if (url.contains('images.unsplash.com')) {
      final uri = Uri.parse(url);
      final queryParams = Map<String, String>.from(uri.queryParameters);
      if (targetWidth != null && targetWidth > 0) {
        queryParams['w'] = targetWidth.toString();
      }
      if (targetHeight != null && targetHeight > 0) {
        queryParams['h'] = targetHeight.toString();
      }
      queryParams['fm'] = format;
      queryParams['q'] = (quality ?? 80).clamp(30, 100).toString();
      queryParams['fit'] = 'crop';
      return uri.replace(queryParameters: queryParams).toString();
    }

    return url;
  }

  /// Adapt Zego Voice Engine audio bitrate & sample rate dynamically to active NetworkTier.
  Future<void> _applyAudioBitratePolicy(DynamicNetworkPolicy policy) async {
    try {
      ZegoAudioConfig audioConfig;

      switch (policy.tier) {
        case NetworkTier.offline:
        case NetworkTier.tier2G:
          // Low bandwidth Mono 16kHz for 2G networks
          audioConfig = ZegoAudioConfig(16000, ZegoAudioChannel.Mono, ZegoAudioCodecID.Default);
          break;
        case NetworkTier.tier3G:
          // Medium bandwidth Mono 32kHz
          audioConfig = ZegoAudioConfig(32000, ZegoAudioChannel.Mono, ZegoAudioCodecID.Default);
          break;
        case NetworkTier.tier4G:
        case NetworkTier.tier5G:
        case NetworkTier.wifi:
        default:
          // High-fidelity Stereo 48kHz for 4G/5G/WiFi
          audioConfig = ZegoAudioConfig(48000, ZegoAudioChannel.Stereo, ZegoAudioCodecID.Default);
          break;
      }

      await ZegoExpressEngine.instance.setAudioConfig(audioConfig);
      debugPrint('[AdaptiveMediaManager] Dynamically applied Zego Audio profile for tier ${policy.tier}');
    } catch (e) {
      // Ignore if Zego engine is not initialized in current screen context
    }
  }
}
