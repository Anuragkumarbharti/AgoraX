import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../room/room_controller.dart';

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

  Timer? _reconnect8sTimer;

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final bool wasOnline = isOnline.value;
    final bool currentlyOnline = results.any((r) => r != ConnectivityResult.none);

    isOnline.value = currentlyOnline;

    if (!wasOnline && currentlyOnline) {
      debugPrint('[NetworkConnectivityService] Network connection restored! Cancelling 8s disconnect timer.');
      _reconnect8sTimer?.cancel();
      _reconnect8sTimer = null;

      for (final callback in List<VoidCallback>.from(_onReconnectedCallbacks)) {
        try {
          callback();
        } catch (e) {
          debugPrint('[NetworkConnectivityService] Callback error: $e');
        }
      }
    } else if (wasOnline && !currentlyOnline) {
      debugPrint('[NetworkConnectivityService] Network connection lost! Starting 8s grace period timer.');
      for (final callback in List<VoidCallback>.from(_onDisconnectedCallbacks)) {
        try {
          callback();
        } catch (e) {
          debugPrint('[NetworkConnectivityService] Disconnect callback error: $e');
        }
      }

      _reconnect8sTimer?.cancel();
      _reconnect8sTimer = Timer(const Duration(seconds: 8), () {
        if (!isOnline.value && Get.isRegistered<RoomController>() && RoomController.to.activeRoomId != null) {
          debugPrint('[NetworkConnectivityService] 8s network disconnect timeout reached. Redirecting to Arena main page.');
          RoomController.to.leaveActiveRoomLocally(
            reason: 'Network disconnect: Redirected to Arena main page (8s timeout)',
            navigateToArena: true,
          );
        }
      });
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
