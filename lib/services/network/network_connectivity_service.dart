import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../room/room_controller.dart';

enum NetworkState {
  wifi,
  mobile,
  weak,
  noInternet,
  airplaneMode,
}

/// Production-Grade Network Connectivity Service
/// Provides instant client-side network detection, actual internet IP ping verification,
/// weak network latency monitoring, analytics logging, and auto-recovery events.
class NetworkConnectivityService extends GetxService {
  static NetworkConnectivityService get to {
    if (!Get.isRegistered<NetworkConnectivityService>()) {
      Get.put(NetworkConnectivityService());
    }
    return Get.find<NetworkConnectivityService>();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _periodicPingTimer;
  Timer? _reconnect8sTimer;

  // Observables for real-time UI reactions
  final RxBool isOnline = true.obs;
  final RxBool isWeak = false.obs;
  final RxBool isCheckingInternet = false.obs;
  final Rx<NetworkState> networkState = NetworkState.wifi.obs;
  final RxInt pingLatencyMs = 50.obs;

  final List<VoidCallback> _onReconnectedCallbacks = <VoidCallback>[];
  final List<VoidCallback> _onDisconnectedCallbacks = <VoidCallback>[];

  // DNS endpoints for actual connectivity validation (1.1.1.1, 8.8.8.8)
  static const String _primaryDns = '1.1.1.1';
  static const String _secondaryDns = '8.8.8.8';
  static const int _dnsPort = 53;
  static const Duration _pingTimeout = Duration(seconds: 2);

  @override
  void onInit() {
    super.onInit();
    _initConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChanged);
    _startPeriodicPing();
  }

  Future<void> _initConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      await _handleConnectivityChanged(results);
    } catch (e) {
      debugPrint('[NetworkConnectivityService] Check connectivity error: $e');
      // Default to online check fallback
      await verifyInternetAccess();
    }
  }

  void _startPeriodicPing() {
    _periodicPingTimer?.cancel();
    _periodicPingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (networkState.value != NetworkState.noInternet && networkState.value != NetworkState.airplaneMode) {
        verifyInternetAccess();
      }
    });
  }

  /// Handles platform connectivity state changes instantly
  Future<void> _handleConnectivityChanged(List<ConnectivityResult> results) async {
    final bool hasInterface = results.isNotEmpty && !results.contains(ConnectivityResult.none);

    if (!hasInterface) {
      _setOfflineState(isAirplaneMode: false);
      return;
    }

    // Determine network type (WiFi vs Mobile)
    NetworkState detectedState = NetworkState.wifi;
    if (results.contains(ConnectivityResult.mobile)) {
      detectedState = NetworkState.mobile;
    } else if (results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.ethernet)) {
      detectedState = NetworkState.wifi;
    }

    // Perform actual IP ping to verify internet reachability behind interface
    final bool hasActualInternet = await verifyInternetAccess();
    if (hasActualInternet) {
      if (isWeak.value) {
        networkState.value = NetworkState.weak;
      } else {
        networkState.value = detectedState;
      }
    }
  }

  /// Verifies actual internet access by attempting a low-latency socket handshake
  Future<bool> verifyInternetAccess() async {
    if (isCheckingInternet.value) return isOnline.value;
    isCheckingInternet.value = true;

    bool reachability = false;
    final stopwatch = Stopwatch()..start();

    try {
      // Primary check to 1.1.1.1
      Socket socket = await Socket.connect(_primaryDns, _dnsPort, timeout: _pingTimeout);
      stopwatch.stop();
      await socket.close();
      reachability = true;
    } catch (_) {
      // Fallback check to 8.8.8.8
      try {
        stopwatch.reset();
        stopwatch.start();
        Socket socket = await Socket.connect(_secondaryDns, _dnsPort, timeout: _pingTimeout);
        stopwatch.stop();
        await socket.close();
        reachability = true;
      } catch (_) {
        reachability = false;
      }
    } finally {
      isCheckingInternet.value = false;
    }

    final int rtt = stopwatch.elapsedMilliseconds;
    pingLatencyMs.value = rtt;

    // Detect weak network if RTT > 400ms
    final bool weakSignal = reachability && rtt > 400;
    isWeak.value = weakSignal;

    final bool wasOnline = isOnline.value;

    if (reachability) {
      isOnline.value = true;
      if (!wasOnline) {
        _handleRestoredConnection();
      }
    } else {
      _setOfflineState(isAirplaneMode: false);
    }

    return reachability;
  }

  void _setOfflineState({required bool isAirplaneMode}) {
    final bool wasOnline = isOnline.value;
    isOnline.value = false;
    isWeak.value = false;
    networkState.value = isAirplaneMode ? NetworkState.airplaneMode : NetworkState.noInternet;

    if (wasOnline) {
      _handleLostConnection();
    }
  }

  void _handleRestoredConnection() {
    debugPrint('[NetworkConnectivityService] 📶 Network connection restored! Cancelling 8s room disconnect timer.');
    _reconnect8sTimer?.cancel();
    _reconnect8sTimer = null;

    logAnalyticsEvent('internet_restored');

    for (final callback in List<VoidCallback>.from(_onReconnectedCallbacks)) {
      try {
        callback();
      } catch (e) {
        debugPrint('[NetworkConnectivityService] Reconnected callback error: $e');
      }
    }
  }

  void _handleLostConnection() {
    debugPrint('[NetworkConnectivityService] ❌ Network connection lost! Starting 8s grace period timer.');
    logAnalyticsEvent('internet_lost');

    for (final callback in List<VoidCallback>.from(_onDisconnectedCallbacks)) {
      try {
        callback();
      } catch (e) {
        debugPrint('[NetworkConnectivityService] Disconnected callback error: $e');
      }
    }

    _reconnect8sTimer?.cancel();
    _reconnect8sTimer = Timer(const Duration(seconds: 8), () {
      if (!isOnline.value && Get.isRegistered<RoomController>() && RoomController.to.activeRoomId != null) {
        debugPrint('[NetworkConnectivityService] 8s network disconnect timeout reached. Disconnecting room session.');
        logAnalyticsEvent('forced_room_exit_offline');
        RoomController.to.leaveActiveRoomLocally(
          reason: 'Network disconnect: Redirected to Arena main page (8s timeout)',
          navigateToArena: true,
        );
      }
    });
  }

  /// Manually force a re-check of internet connectivity (e.g. from Retry UI button)
  Future<bool> forceRetryCheck() async {
    debugPrint('[NetworkConnectivityService] Force retrying internet check...');
    try {
      final results = await _connectivity.checkConnectivity();
      await _handleConnectivityChanged(results);
    } catch (_) {
      await verifyInternetAccess();
    }
    return isOnline.value;
  }

  void addReconnectedCallback(VoidCallback callback) {
    if (!_onReconnectedCallbacks.contains(callback)) {
      _onReconnectedCallbacks.add(callback);
    }
  }

  void removeReconnectedCallback(VoidCallback callback) {
    _onReconnectedCallbacks.remove(callback);
  }

  void addDisconnectedCallback(VoidCallback callback) {
    if (!_onDisconnectedCallbacks.contains(callback)) {
      _onDisconnectedCallbacks.add(callback);
    }
  }

  void removeDisconnectedCallback(VoidCallback callback) {
    _onDisconnectedCallbacks.remove(callback);
  }

  /// Analytics Event Logger for Network System
  void logAnalyticsEvent(String eventName, [Map<String, dynamic>? parameters]) {
    debugPrint('[NetworkAnalytics] EVENT: $eventName | PARAMS: $parameters');
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _periodicPingTimer?.cancel();
    _reconnect8sTimer?.cancel();
    _onReconnectedCallbacks.clear();
    _onDisconnectedCallbacks.clear();
    super.onClose();
  }
}

