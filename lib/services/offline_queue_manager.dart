import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'network_adaptive_manager.dart';

class OfflineActionItem {
  final String id;
  final String actionType; // 'table_insert', 'table_update', 'rpc_call'
  final String target;     // Table or RPC name
  final Map<String, dynamic> payload;
  final int retryCount;
  final DateTime createdAt;

  OfflineActionItem({
    required this.id,
    required this.actionType,
    required this.target,
    required this.payload,
    this.retryCount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'actionType': actionType,
        'target': target,
        'payload': payload,
        'retryCount': retryCount,
        'createdAt': createdAt.toIso8601String(),
      };

  factory OfflineActionItem.fromJson(Map<String, dynamic> json) => OfflineActionItem(
        id: json['id'],
        actionType: json['actionType'],
        target: json['target'],
        payload: Map<String, dynamic>.from(json['payload']),
        retryCount: json['retryCount'] ?? 0,
        createdAt: DateTime.parse(json['createdAt']),
      );
}

class OfflineQueueManager extends GetxService {
  static OfflineQueueManager get to => Get.find();

  static const String _queueStorageKey = 'offline_queue_actions_v1';
  final List<OfflineActionItem> _queue = [];
  bool _isProcessing = false;
  SharedPreferences? _prefs;
  Worker? _onlineWorker;

  @override
  void onInit() {
    super.onInit();
    _loadQueueFromStorage();

    // Replay queue automatically when online status transitions to true
    if (Get.isRegistered<NetworkAdaptiveManager>()) {
      _onlineWorker = ever(NetworkAdaptiveManager.to.isOnline, (bool online) {
        if (online) {
          processOfflineQueue();
        }
      });
    }
  }

  @override
  void onClose() {
    _onlineWorker?.dispose();
    super.onClose();
  }

  Future<void> _loadQueueFromStorage() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final jsonString = _prefs?.getString(_queueStorageKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _queue.clear();
        _queue.addAll(decoded.map((item) => OfflineActionItem.fromJson(item)));
        debugPrint('[OfflineQueueManager] Loaded ${_queue.length} pending offline actions from storage.');
      }
    } catch (e) {
      debugPrint('[OfflineQueueManager] Error loading queue from storage: $e');
    }
  }

  Future<void> _saveQueueToStorage() async {
    try {
      final jsonString = jsonEncode(_queue.map((item) => item.toJson()).toList());
      await _prefs?.setString(_queueStorageKey, jsonString);
    } catch (e) {
      debugPrint('[OfflineQueueManager] Error saving queue to storage: $e');
    }
  }

  /// Queue an action to execute now or when online connectivity is restored.
  Future<void> enqueueAction({
    required String actionType,
    required String target,
    required Map<String, dynamic> payload,
  }) async {
    final item = OfflineActionItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_${payload.hashCode}',
      actionType: actionType,
      target: target,
      payload: payload,
    );

    _queue.add(item);
    await _saveQueueToStorage();
    debugPrint('[OfflineQueueManager] Enqueued offline action: $actionType -> $target (Queue size: ${_queue.length})');

    // Attempt processing immediately if online
    if (Get.isRegistered<NetworkAdaptiveManager>() && NetworkAdaptiveManager.to.isOnline.value) {
      processOfflineQueue();
    }
  }

  /// Replay pending queue items sequentially.
  Future<void> processOfflineQueue() async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;

    debugPrint('[OfflineQueueManager] Processing ${_queue.length} offline queued actions...');

    final List<OfflineActionItem> itemsToProcess = List.from(_queue);

    for (final item in itemsToProcess) {
      bool success = false;

      try {
        if (item.actionType == 'table_insert') {
          await Supabase.instance.client.from(item.target).insert(item.payload);
          success = true;
        } else if (item.actionType == 'table_update') {
          final idVal = item.payload['id'];
          if (idVal != null) {
            await Supabase.instance.client.from(item.target).update(item.payload).eq('id', idVal);
            success = true;
          }
        } else if (item.actionType == 'rpc_call') {
          await Supabase.instance.client.rpc(item.target, params: item.payload);
          success = true;
        }
      } catch (e) {
        debugPrint('[OfflineQueueManager] Failed to process action ${item.id}: $e');
      }

      if (success) {
        _queue.removeWhere((q) => q.id == item.id);
        await _saveQueueToStorage();
      } else {
        // Increment retry or drop if max retries exceeded
        if (item.retryCount >= 5) {
          _queue.removeWhere((q) => q.id == item.id);
          await _saveQueueToStorage();
          debugPrint('[OfflineQueueManager] Dropped action ${item.id} after exceeding 5 retries.');
        }
      }
    }

    _isProcessing = false;
  }
}
