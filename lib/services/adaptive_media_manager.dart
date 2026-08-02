import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import 'network_adaptive_manager.dart';

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

  /// Transform standard Supabase URL to use CDN image resizing and WebP formats adaptively.
  static String getAdaptiveImageUrl(String url, {int? targetWidth}) {
    if (url.isEmpty || !url.contains('storage/v1/object/public/')) return url;

    MediaQualitySetting qualitySetting = MediaQualitySetting.medium;
    if (Get.isRegistered<NetworkAdaptiveManager>()) {
      qualitySetting = NetworkAdaptiveManager.to.activePolicy.value.mediaQuality;
    }

    final transformed = url.replaceAll('storage/v1/object/public/', 'storage/v1/render/image/public/');

    int width = targetWidth ?? 300;
    int quality = 80;

    switch (qualitySetting) {
      case MediaQualitySetting.low:
        width = targetWidth ?? 120;
        quality = 50;
        break;
      case MediaQualitySetting.medium:
        width = targetWidth ?? 300;
        quality = 70;
        break;
      case MediaQualitySetting.high:
        width = targetWidth ?? 600;
        quality = 85;
        break;
      case MediaQualitySetting.original:
        return url; // Raw uncompressed original
    }

    return '$transformed?width=$width&quality=$quality&resize=contain&format=origin';
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
