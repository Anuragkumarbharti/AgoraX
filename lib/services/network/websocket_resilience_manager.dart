import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './network_adaptive_manager.dart';

class WebSocketResilienceManager extends GetxService {
  static WebSocketResilienceManager get to => Get.find();

  final RxBool isRealtimeConnected = false.obs;
  final List<RealtimeChannel> _activeChannels = [];

  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  Worker? _onlineWorker;

  @override
  void onInit() {
    super.onInit();
    _startHeartbeatGuard();

    if (Get.isRegistered<NetworkAdaptiveManager>()) {
      _onlineWorker = ever(NetworkAdaptiveManager.to.isOnline, (bool online) {
        if (online) {
          reconnectAllChannels();
        }
      });
    }
  }

  @override
  void onClose() {
    _heartbeatTimer?.cancel();
    _onlineWorker?.dispose();
    super.onClose();
  }

  /// Register a Supabase Realtime Channel for resilience auto-reconnection monitoring.
  void registerChannel(RealtimeChannel channel) {
    if (!_activeChannels.contains(channel)) {
      _activeChannels.add(channel);
      debugPrint('[WebSocketResilienceManager] Registered Realtime channel: ${channel.topic}');
    }
  }

  /// Remove channel registration
  void unregisterChannel(RealtimeChannel channel) {
    _activeChannels.remove(channel);
  }

  void _startHeartbeatGuard() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      _verifyChannelHealth();
    });
  }

  Future<void> _verifyChannelHealth() async {
    if (!Get.isRegistered<NetworkAdaptiveManager>() || !NetworkAdaptiveManager.to.isOnline.value) {
      isRealtimeConnected.value = false;
      return;
    }

    try {
      final client = Supabase.instance.client;
      final connected = client.realtime.isConnected;

      if (connected) {
        isRealtimeConnected.value = true;
        _reconnectAttempts = 0;
      } else {
        isRealtimeConnected.value = false;
        debugPrint('[WebSocketResilienceManager] Realtime status degraded. Initiating auto-reconnect...');
        await _performExponentialReconnect();
      }
    } catch (e) {
      debugPrint('[WebSocketResilienceManager] Health check failed: $e');
    }
  }

  Future<void> _performExponentialReconnect() async {
    _reconnectAttempts++;
    final delayMs = min(30000, (pow(2, _reconnectAttempts) * 500).toInt() + Random().nextInt(300));
    debugPrint('[WebSocketResilienceManager] Reconnecting channels in ${delayMs}ms (Attempt #$_reconnectAttempts)...');

    await Future.delayed(Duration(milliseconds: delayMs));
    await reconnectAllChannels();
  }

  Future<void> reconnectAllChannels() async {
    try {
      final client = Supabase.instance.client;
      client.realtime.connect();

      for (final channel in List<RealtimeChannel>.from(_activeChannels)) {
        await channel.subscribe();
      }

      isRealtimeConnected.value = true;
      _reconnectAttempts = 0;
      debugPrint('[WebSocketResilienceManager] Successfully reconnected all active WebSocket & Realtime channels.');
    } catch (e) {
      debugPrint('[WebSocketResilienceManager] Reconnect error: $e');
    }
  }
}
