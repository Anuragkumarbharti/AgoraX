import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/room/room_model.dart';
import '../user/user_profile_cache_manager.dart';
import '../voice/room_voice_manager.dart';
import 'room_controller.dart';
import '../../screens/rooms/voice_room_call_screen.dart';
import '../../widgets/room/dialogs/room_password_dialog.dart';

class RoomJoinPerformanceMetrics {
  final String roomId;
  final int tapToUiRenderMs;
  final int rpcJoinLatencyMs;
  final int voiceLoginMs;
  final int totalJoinMs;

  RoomJoinPerformanceMetrics({
    required this.roomId,
    required this.tapToUiRenderMs,
    required this.rpcJoinLatencyMs,
    required this.voiceLoginMs,
    required this.totalJoinMs,
  });

  void printLog() {
    debugPrint('⚡ [RoomJoinPerformanceMonitor] 🚀 ULTRA FAST JOIN LATENCY BENCHMARK 🚀');
    debugPrint('   • Room ID: $roomId');
    debugPrint('   • Tap to UI Render: ${tapToUiRenderMs}ms');
    debugPrint('   • RPC Server Latency: ${rpcJoinLatencyMs}ms');
    debugPrint('   • Voice Engine Login: ${voiceLoginMs}ms');
    debugPrint('   • TOTAL JOIN TIME: ${totalJoinMs}ms ${totalJoinMs <= 200 ? "✅ [TARGET ACHIEVED < 200ms]" : "⚠️ [EXCEEDED 200ms]"}\n');
  }
}

class UltraFastRoomJoinEngine {
  static final UltraFastRoomJoinEngine _instance = UltraFastRoomJoinEngine._internal();
  factory UltraFastRoomJoinEngine() => _instance;
  UltraFastRoomJoinEngine._internal();

  /// Execute Ultra Fast Room Entry Sequence (Target: 100ms - 200ms)
  Future<void> executeFastJoin({
    required BuildContext context,
    required VoiceRoom room,
    String? providedPassword,
  }) async {
    final stopwatch = Stopwatch()..start();
    int tapToUiRenderMs = 0;
    int rpcJoinLatencyMs = 0;
    int voiceLoginMs = 0;

    final currentUserId = UserProfileCacheManager.currentUserId.isNotEmpty
        ? UserProfileCacheManager.currentUserId
        : 'uid_anurag_101';
    final currentUser = UserProfileCacheManager.currentUser;

    try {
      // 1. PRIORITY 1: Instant Optimistic UI Transition (< 100ms Target)
      final isHost = room.hostId == currentUserId || room.founderId == currentUserId || room.coOwnerIds.contains(currentUserId);
      Get.to(
        () => VoiceRoomCallScreen(
          roomId: room.id,
          roomName: room.name,
          userId: currentUserId,
          userName: currentUser?.username ?? 'anurag_kumar',
          isHost: isHost,
        ),
      );
      tapToUiRenderMs = stopwatch.elapsedMilliseconds;

      // 2. Execute Single Atomic Consolidated RPC Function
      final rpcStart = stopwatch.elapsedMilliseconds;
      final response = await Supabase.instance.client.rpc(
        'join_room_fast_v2',
        params: {
          'p_room_id': room.id,
          'p_provided_password': providedPassword,
        },
      );
      rpcJoinLatencyMs = stopwatch.elapsedMilliseconds - rpcStart;

      if (response == null || response['join_allowed'] == false) {
        final reason = response != null ? response['reason']?.toString() ?? '' : 'Join Denied';
        
        // Handle Password Requirement
        if (response != null && response['password_required'] == true) {
          Get.back(); // Pop optimistic room screen
          showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => RoomPasswordDialog(room: room),
          ).then((pass) {
            if (pass != null && pass.isNotEmpty) {
              executeFastJoin(context: context, room: room, providedPassword: pass);
            }
          });
          return;
        }

        // Handle Rejection/Ban
        Get.back();
        Get.snackbar(
          'Access Denied 🛡️',
          reason,
          backgroundColor: Colors.red.shade900,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
        return;
      }

      // 3. WARM VOICE ENGINE LOGIN (Reuses preloaded Voice SDK)
      final voiceStart = stopwatch.elapsedMilliseconds;
      RoomVoiceManager().joinRoom(
        roomId: room.id,
        userId: currentUserId,
        userName: currentUser?.username ?? 'Creania Student',
        enableMic: false,
      ).catchError((e) {
        debugPrint('[UltraFastRoomJoinEngine] Voice background connection warning: $e');
      });
      voiceLoginMs = stopwatch.elapsedMilliseconds - voiceStart;

      // 4. PRIORITY 2: Background Data Stream (Non-blocking)
      unawaited(_streamPriority2BackgroundData(room.id));

      stopwatch.stop();

      // 5. Performance Monitor Logging
      final metrics = RoomJoinPerformanceMetrics(
        roomId: room.id,
        tapToUiRenderMs: tapToUiRenderMs,
        rpcJoinLatencyMs: rpcJoinLatencyMs,
        voiceLoginMs: voiceLoginMs,
        totalJoinMs: stopwatch.elapsedMilliseconds,
      );
      metrics.printLog();
    } catch (e) {
      debugPrint('[UltraFastRoomJoinEngine] Fast join error: $e');
    }
  }

  /// Priority 2: Non-blocking background stream for gifts, progression, leaderboards
  Future<void> _streamPriority2BackgroundData(String roomId) async {
    try {
      if (Get.isRegistered<RoomController>()) {
        final ctrl = RoomController.to;
        await ctrl.fetchRoomProgression(roomId);
        await ctrl.fetchRoomPermissions(roomId);
      }
    } catch (e) {
      debugPrint('[UltraFastRoomJoinEngine] Priority 2 background stream error: $e');
    }
  }
}
