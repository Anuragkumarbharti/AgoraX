import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

enum NetworkTier {
  offline,
  tier2G,
  tier3G,
  tier4G,
  tier5G,
  wifi,
}

enum MediaQualitySetting {
  low,       // WebP 100-150px, aggressive compression
  medium,    // WebP 300-450px
  high,      // WebP 600-800px
  original,  // Raw high res
}

class DynamicNetworkPolicy {
  final NetworkTier tier;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final int maxConcurrentRequests;
  final MediaQualitySetting mediaQuality;
  final int batchWindowMs;
  final bool backgroundPrefetchEnabled;
  final double cacheTtlMultiplier;
  final bool enableBrotliCompression;

  const DynamicNetworkPolicy({
    required this.tier,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.maxConcurrentRequests,
    required this.mediaQuality,
    required this.batchWindowMs,
    required this.backgroundPrefetchEnabled,
    required this.cacheTtlMultiplier,
    required this.enableBrotliCompression,
  });

  static const DynamicNetworkPolicy offlinePolicy = DynamicNetworkPolicy(
    tier: NetworkTier.offline,
    connectTimeout: Duration(seconds: 3),
    receiveTimeout: Duration(seconds: 3),
    maxConcurrentRequests: 0,
    mediaQuality: MediaQualitySetting.low,
    batchWindowMs: 5000,
    backgroundPrefetchEnabled: false,
    cacheTtlMultiplier: 10.0,
    enableBrotliCompression: true,
  );

  static const DynamicNetworkPolicy tier2GPolicy = DynamicNetworkPolicy(
    tier: NetworkTier.tier2G,
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 60),
    maxConcurrentRequests: 2,
    mediaQuality: MediaQualitySetting.low,
    batchWindowMs: 1500,
    backgroundPrefetchEnabled: false,
    cacheTtlMultiplier: 5.0,
    enableBrotliCompression: true,
  );

  static const DynamicNetworkPolicy tier3GPolicy = DynamicNetworkPolicy(
    tier: NetworkTier.tier3G,
    connectTimeout: Duration(seconds: 15),
    receiveTimeout: Duration(seconds: 30),
    maxConcurrentRequests: 4,
    mediaQuality: MediaQualitySetting.medium,
    batchWindowMs: 800,
    backgroundPrefetchEnabled: false,
    cacheTtlMultiplier: 2.0,
    enableBrotliCompression: true,
  );

  static const DynamicNetworkPolicy tier4GPolicy = DynamicNetworkPolicy(
    tier: NetworkTier.tier4G,
    connectTimeout: Duration(seconds: 8),
    receiveTimeout: Duration(seconds: 15),
    maxConcurrentRequests: 8,
    mediaQuality: MediaQualitySetting.high,
    batchWindowMs: 400,
    backgroundPrefetchEnabled: true,
    cacheTtlMultiplier: 1.0,
    enableBrotliCompression: true,
  );

  static const DynamicNetworkPolicy tier5GPolicy = DynamicNetworkPolicy(
    tier: NetworkTier.tier5G,
    connectTimeout: Duration(seconds: 4),
    receiveTimeout: Duration(seconds: 8),
    maxConcurrentRequests: 16,
    mediaQuality: MediaQualitySetting.original,
    batchWindowMs: 200,
    backgroundPrefetchEnabled: true,
    cacheTtlMultiplier: 0.8,
    enableBrotliCompression: true,
  );

  static const DynamicNetworkPolicy wifiPolicy = DynamicNetworkPolicy(
    tier: NetworkTier.wifi,
    connectTimeout: Duration(seconds: 5),
    receiveTimeout: Duration(seconds: 10),
    maxConcurrentRequests: 16,
    mediaQuality: MediaQualitySetting.original,
    batchWindowMs: 250,
    backgroundPrefetchEnabled: true,
    cacheTtlMultiplier: 1.0,
    enableBrotliCompression: true,
  );
}

class NetworkAdaptiveManager extends GetxService {
  static NetworkAdaptiveManager get to => Get.find();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  final Rx<NetworkTier> currentTier = NetworkTier.wifi.obs;
  final Rx<DynamicNetworkPolicy> activePolicy = DynamicNetworkPolicy.wifiPolicy.obs;
  final RxInt measuredLatencyMs = 50.obs;
  final RxBool isOnline = true.obs;

  Timer? _latencyPingTimer;
  static const String _pingTargetHost = '8.8.8.8';

  @override
  void onInit() {
    super.onInit();
    _initConnectivityListener();
    _startLatencyBenchmarkLoop();
  }

  @override
  void onClose() {
    _connectivitySub?.cancel();
    _latencyPingTimer?.cancel();
    super.onClose();
  }

  void _initConnectivityListener() {
    try {
      _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
        _evaluateNetworkState(results);
      }, onError: (e) {
        debugPrint('[NetworkAdaptiveManager] Connectivity listener error: $e');
      });

      _connectivity.checkConnectivity().then((results) {
        _evaluateNetworkState(results);
      }).catchError((e) {
        debugPrint('[NetworkAdaptiveManager] Check connectivity error: $e');
        _evaluateNetworkState([ConnectivityResult.wifi]);
      });
    } catch (e) {
      debugPrint('[NetworkAdaptiveManager] Platform channel unavailable: $e');
      _evaluateNetworkState([ConnectivityResult.wifi]);
    }
  }

  Future<void> _evaluateNetworkState(List<ConnectivityResult> results) async {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      _updateTierAndPolicy(NetworkTier.offline, DynamicNetworkPolicy.offlinePolicy);
      isOnline.value = false;
      return;
    }

    isOnline.value = true;

    if (results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.ethernet)) {
      _updateTierAndPolicy(NetworkTier.wifi, DynamicNetworkPolicy.wifiPolicy);
      return;
    }

    if (results.contains(ConnectivityResult.mobile)) {
      // Evaluate based on measured RTT ping latency
      final rtt = measuredLatencyMs.value;
      if (rtt > 800) {
        _updateTierAndPolicy(NetworkTier.tier2G, DynamicNetworkPolicy.tier2GPolicy);
      } else if (rtt > 300) {
        _updateTierAndPolicy(NetworkTier.tier3G, DynamicNetworkPolicy.tier3GPolicy);
      } else if (rtt > 100) {
        _updateTierAndPolicy(NetworkTier.tier4G, DynamicNetworkPolicy.tier4GPolicy);
      } else {
        _updateTierAndPolicy(NetworkTier.tier5G, DynamicNetworkPolicy.tier5GPolicy);
      }
    }
  }

  void _updateTierAndPolicy(NetworkTier tier, DynamicNetworkPolicy policy) {
    if (currentTier.value != tier) {
      currentTier.value = tier;
      activePolicy.value = policy;
      debugPrint('[NetworkAdaptiveManager] Active network tier updated to: $tier '
          '(Max concurrency: ${policy.maxConcurrentRequests}, Timeouts: ${policy.connectTimeout.inSeconds}s)');
    }
  }

  void _startLatencyBenchmarkLoop() {
    _runPingCheck();
    _latencyPingTimer = Timer.periodic(const Duration(seconds: 25), (_) => _runPingCheck());
  }

  Future<void> _runPingCheck() async {
    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(_pingTargetHost, 53, timeout: const Duration(seconds: 4));
      stopwatch.stop();
      await socket.close();

      final elapsed = stopwatch.elapsedMilliseconds;
      measuredLatencyMs.value = elapsed;

      // Re-evaluate policy with new RTT latency reading
      try {
        final connectivityResults = await _connectivity.checkConnectivity();
        _evaluateNetworkState(connectivityResults);
      } catch (_) {}
    } catch (_) {
      // High latency or packet drop fallback
      if (currentTier.value != NetworkTier.offline) {
        measuredLatencyMs.value = 1200; // Treat as high-latency fallback
      }
    }
  }
}
