import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:creania/services/network/network_adaptive_manager.dart';
import 'package:creania/services/network/adaptive_media_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Network Adaptive Manager Tests', () {
    late NetworkAdaptiveManager manager;

    setUp(() {
      Get.reset();
      manager = NetworkAdaptiveManager();
      Get.put(manager);
    });

    tearDown(() {
      Get.reset();
    });

    test('Initial policy defaults to WiFi', () {
      expect(manager.currentTier.value, NetworkTier.wifi);
      expect(manager.activePolicy.value.maxConcurrentRequests, 16);
      expect(manager.activePolicy.value.batchWindowMs, 250);
      expect(manager.activePolicy.value.backgroundPrefetchEnabled, true);
    });

    test('2G Tier Policy applies low concurrency and high timeouts', () {
      final policy = DynamicNetworkPolicy.tier2GPolicy;
      expect(policy.tier, NetworkTier.tier2G);
      expect(policy.maxConcurrentRequests, 2);
      expect(policy.connectTimeout.inSeconds, 30);
      expect(policy.mediaQuality, MediaQualitySetting.low);
      expect(policy.cacheTtlMultiplier, 5.0);
    });

    test('Adaptive CDN image URL transformation under 4G/Medium policy', () {
      manager.activePolicy.value = DynamicNetworkPolicy.tier4GPolicy;
      const originalUrl = 'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/avatars/user1.png';
      final transformed = AdaptiveMediaManager.getAdaptiveImageUrl(originalUrl, targetWidth: 200);

      expect(transformed.contains('/storage/v1/render/image/public/'), true);
      expect(transformed.contains('format=origin'), true);
      expect(transformed.contains('quality='), true);
    });
  });
}
