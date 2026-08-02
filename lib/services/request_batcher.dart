import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'network_adaptive_manager.dart';

class BatchItem {
  final String action;
  final Map<String, dynamic> payload;
  final Completer<dynamic> completer;
  final DateTime queuedAt;

  BatchItem({
    required this.action,
    required this.payload,
    required this.completer,
    DateTime? queuedAt,
  }) : queuedAt = queuedAt ?? DateTime.now();
}

class RequestBatcher extends GetxService {
  static RequestBatcher get to => Get.find();

  final List<BatchItem> _queue = [];
  Timer? _batchTimer;

  @override
  void onInit() {
    super.onInit();
    _scheduleNextFlush();
  }

  @override
  void onClose() {
    _batchTimer?.cancel();
    _flushQueue();
    super.onClose();
  }

  /// Add a request to the batch queue. Returns a Future that resolves when the batch executes.
  Future<dynamic> enqueue(String action, Map<String, dynamic> payload) {
    final completer = Completer<dynamic>();
    _queue.add(BatchItem(action: action, payload: payload, completer: completer));

    // Force flush if queue reaches max chunk size
    if (_queue.length >= 25) {
      _flushQueue();
    }

    return completer.future;
  }

  void _scheduleNextFlush() {
    _batchTimer?.cancel();

    int windowMs = 300;
    if (Get.isRegistered<NetworkAdaptiveManager>()) {
      windowMs = NetworkAdaptiveManager.to.activePolicy.value.batchWindowMs;
    }

    _batchTimer = Timer(Duration(milliseconds: windowMs), () async {
      await _flushQueue();
      _scheduleNextFlush();
    });
  }

  Future<void> _flushQueue() async {
    if (_queue.isEmpty) return;

    final batchToProcess = List<BatchItem>.from(_queue);
    _queue.clear();

    try {
      final payloadList = batchToProcess.map((item) => {
        'action': item.action,
        'payload': item.payload,
        'queued_at': item.queuedAt.toIso8601String(),
      }).toList();

      debugPrint('[RequestBatcher] Flushing batch of ${batchToProcess.length} queued operations...');

      // RPC call to Supabase batch handler
      final response = await Supabase.instance.client.rpc(
        'batch_execute_operations',
        params: {'p_operations': payloadList},
      );

      final List<dynamic> results = response is List ? response : [];

      for (int i = 0; i < batchToProcess.length; i++) {
        final item = batchToProcess[i];
        if (i < results.length) {
          item.completer.complete(results[i]);
        } else {
          item.completer.complete({'status': 'success'});
        }
      }
    } catch (e) {
      debugPrint('[RequestBatcher] Batch flush failed: $e');
      for (final item in batchToProcess) {
        if (!item.completer.isCompleted) {
          item.completer.completeError(e);
        }
      }
    }
  }

  /// Parallel Request Executor with concurrency limit derived from NetworkAdaptiveManager
  Future<List<T>> executeParallel<T>(List<Future<T> Function()> tasks) async {
    if (tasks.isEmpty) return [];

    int maxConcurrency = 8;
    if (Get.isRegistered<NetworkAdaptiveManager>()) {
      maxConcurrency = NetworkAdaptiveManager.to.activePolicy.value.maxConcurrentRequests;
    }
    if (maxConcurrency <= 0) maxConcurrency = 1;

    final results = List<T?>.filled(tasks.length, null);
    int index = 0;

    Future<void> worker() async {
      while (index < tasks.length) {
        final currentIndex = index++;
        try {
          results[currentIndex] = await tasks[currentIndex]();
        } catch (e) {
          debugPrint('[ParallelExecutor] Task $currentIndex failed: $e');
        }
      }
    }

    final workers = List.generate(
      min(maxConcurrency, tasks.length),
      (_) => worker(),
    );

    await Future.wait(workers);
    return results.whereType<T>().toList();
  }

  int min(int a, int b) => a < b ? a : b;
}
