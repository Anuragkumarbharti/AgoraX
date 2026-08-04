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

  /// Returns valid public image URL safely
  static String getAdaptiveImageUrl(String url, {int? targetWidth}) {
    if (url.isEmpty) return url;
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
