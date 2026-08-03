import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Network Connectivity Service
/// Listens to network state transitions (online/offline) and handles auto-recovery.
class NetworkConnectivityService extends GetxService {
  static NetworkConnectivityService get to => Get.find<NetworkConnectivityService>();

  final Connectivity _connectivity = Connectivity();
  final RxBool isOnline = true.obs;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final List<VoidCallback> _onReconnectedCallbacks = <VoidCallback>[];
  final List<VoidCallback> _onDisconnectedCallbacks = <VoidCallback>[];

  @override
  void onInit() {
    super.onInit();
    _initConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _initConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      debugPrint('[NetworkConnectivityService] Check connectivity error: $e');
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final bool wasOnline = isOnline.value;
    final bool currentlyOnline = results.any((r) => r != ConnectivityResult.none);

    isOnline.value = currentlyOnline;

    if (!wasOnline && currentlyOnline) {
      debugPrint('[NetworkConnectivityService] Network connection restored! Triggering auto-recovery callbacks.');
      for (final callback in List<VoidCallback>.from(_onReconnectedCallbacks)) {
        try {
          callback();
        } catch (e) {
          debugPrint('[NetworkConnectivityService] Callback error: $e');
        }
      }
    } else if (wasOnline && !currentlyOnline) {
      debugPrint('[NetworkConnectivityService] Network connection lost! Triggering disconnect callbacks.');
      for (final callback in List<VoidCallback>.from(_onDisconnectedCallbacks)) {
        try {
          callback();
        } catch (e) {
          debugPrint('[NetworkConnectivityService] Disconnect callback error: $e');
        }
      }
    }
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

  @override
  void onClose() {
    _subscription?.cancel();
    _onReconnectedCallbacks.clear();
    _onDisconnectedCallbacks.clear();
    super.onClose();
  }
}
