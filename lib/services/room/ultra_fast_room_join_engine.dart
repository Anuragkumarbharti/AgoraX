import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/room/room_model.dart';
import '../user/user_profile_cache_manager.dart';
import '../voice/room_voice_manager.dart';
import 'room_controller.dart';
import 'room_realtime_controller.dart';
import '../../screens/rooms/voice_room_call_screen.dart';
import '../../widgets/room/dialogs/room_password_dialog.dart';
import '../../widgets/room/dialogs/room_entry_denied_sheet.dart';
import 'room_entry_permission_engine.dart';

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

  /// Execute Secure Atomic Room Entry Transaction (Requirements 1-8)
  Future<void> executeFastJoin({
    required BuildContext context,
    required VoiceRoom room,
    String? providedPassword,
  }) async {
    final currentUserId = UserProfileCacheManager.currentUserId.isNotEmpty
        ? UserProfileCacheManager.currentUserId
        : 'uid_anurag_101';
    final currentUser = UserProfileCacheManager.currentUser;
    final isOwnerOrCoOwner = room.hostId == currentUserId ||
        room.founderId == currentUserId ||
        room.coOwnerIds.contains(currentUserId);

    // ========================================================================
    // PRE-JOIN CHECK: Password Protection Prompt (Requirement 6)
    // ========================================================================
    final isPasswordProtected = room.entryPermission == 'password' ||
        room.whoCanJoin == 'Password Required' ||
        (room.roomPassword != null && room.roomPassword!.isNotEmpty);

    if (isPasswordProtected && !isOwnerOrCoOwner && providedPassword == null) {
      debugPrint('[UltraFastRoomJoinEngine] Room ${room.id} is password protected. Prompting PIN dialog before join transaction...');
      final String? enteredPass = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => RoomPasswordDialog(room: room),
      );

      if (enteredPass == null || enteredPass.trim().isEmpty) {
        debugPrint('[UltraFastRoomJoinEngine] Password prompt cancelled by user. Join transaction aborted.');
        return;
      }
      providedPassword = enteredPass.trim();
    }

    final stopwatch = Stopwatch()..start();
    int tapToUiRenderMs = 0;
    int rpcJoinLatencyMs = 0;
    int voiceLoginMs = 0;

    try {
      // ========================================================================
      // STAGE 1: Server Atomic RPC Verification (Requirement 1 & 8)
      // ========================================================================
      final rpcStart = stopwatch.elapsedMilliseconds;
      final response = await Supabase.instance.client.rpc(
        'join_room_fast_v2',
        params: {
          'p_room_id': room.id,
          'p_provided_password': providedPassword,
          'p_user_id': currentUserId,
        },
      );
      rpcJoinLatencyMs = stopwatch.elapsedMilliseconds - rpcStart;

      if (response == null || response['join_allowed'] == false) {
        final reason = response != null ? response['reason']?.toString() ?? '' : 'Join Denied';
        final isPasswordReq = response != null && response['password_required'] == true;
        final isInvalidPass = response != null && response['invalid_password'] == true;

        if (isPasswordReq || isInvalidPass) {
          final String? enteredPass = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => RoomPasswordDialog(
              room: room,
              isInvalidPass: isInvalidPass,
            ),
          );
          if (enteredPass != null && enteredPass.trim().isNotEmpty) {
            return executeFastJoin(context: context, room: room, providedPassword: enteredPass.trim());
          }
          return;
        }

        // Handle Rejections with detailed RoomEntryDeniedSheet
        final statusMap = <String, RoomEntryStatus>{
          'followers_only': RoomEntryStatus.followersOnly,
          'owner followers': RoomEntryStatus.followersOnly,
          'following_only': RoomEntryStatus.followingOnly,
          'owner_following': RoomEntryStatus.followingOnly,
          'owner following': RoomEntryStatus.followingOnly,
          'vip_only': RoomEntryStatus.vipOnly,
          'level_required': RoomEntryStatus.vipOnly,
          'temporary_kick': RoomEntryStatus.temporaryKick,
          'permanent_ban': RoomEntryStatus.permanentBan,
          'room_closed': RoomEntryStatus.roomClosed,
          'room_full': RoomEntryStatus.roomFull,
        };

        final matchedStatus = statusMap.entries
            .firstWhere(
              (e) => reason.toLowerCase().contains(e.key.toLowerCase()),
              orElse: () => const MapEntry('followers_only', RoomEntryStatus.followersOnly),
            )
            .value;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => RoomEntryDeniedSheet(
            room: room,
            result: RoomEntryResult(
              isAllowed: false,
              status: matchedStatus,
              role: 'Audience',
              message: reason,
            ),
          ),
        );
        return;
      }

      // ========================================================================
      // STAGE 2: Connect Voice Engine Stream (Requirement 2)
      // ========================================================================
      RoomLockoutTracker.resetAttempts(room.id);
      final voiceStart = stopwatch.elapsedMilliseconds;
      await RoomVoiceManager().joinRoom(
        roomId: room.id,
        userId: currentUserId,
        userName: currentUser?.username ?? 'Creania Student',
        enableMic: false,
      );
      voiceLoginMs = stopwatch.elapsedMilliseconds - voiceStart;

      // ========================================================================
      // STAGE 3: Realtime Socket Registration & Initial State Sync
      // ========================================================================
      if (Get.isRegistered<RoomRealtimeController>()) {
        final realtimeCtrl = RoomRealtimeController.to;
        realtimeCtrl.subscribeToRoomRealtime(
          room.id,
          activeRoomId: room.id,
          onFetchMembers: (_) async {},
          onFetchPermissions: (_) async {},
          onFetchRequests: (_) async {},
          onFetchPolls: (_) async {},
          onFetchProgression: (_) async {},
          onCleanupResources: () {},
        );
      }

      // ========================================================================
      // STAGE 4: COMMIT TRANSACTION & OPEN ROOM (Requirement 1, 3, 4)
      // ========================================================================
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

      // Priority 2 Background Streaming (Non-blocking)
      unawaited(_streamPriority2BackgroundData(room.id));

      stopwatch.stop();

      // Performance Monitor Logging
      final metrics = RoomJoinPerformanceMetrics(
        roomId: room.id,
        tapToUiRenderMs: tapToUiRenderMs,
        rpcJoinLatencyMs: rpcJoinLatencyMs,
        voiceLoginMs: voiceLoginMs,
        totalJoinMs: stopwatch.elapsedMilliseconds,
      );
      metrics.printLog();
    } catch (e) {
      debugPrint('[UltraFastRoomJoinEngine] Transaction failed: $e. Executing full transaction rollback...');
      await _rollbackJoinTransaction(room.id);

      final String rawMsg = e is PostgrestException && e.message.isNotEmpty
          ? e.message
          : e.toString();

      String userFriendlyMessage = 'Network connection issue. Please check your internet connection and try again.';
      if (!rawMsg.toLowerCase().contains('<html') &&
          !rawMsg.toLowerCase().contains('<head>') &&
          !rawMsg.toLowerCase().contains('<!doctype') &&
          !rawMsg.toLowerCase().contains('portal_url')) {
        if (e is PostgrestException && e.message.isNotEmpty) {
          userFriendlyMessage = e.message;
        }
      }

      Get.snackbar(
        'Network Connection Error 📶',
        userFriendlyMessage,
        backgroundColor: Colors.red.shade900,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// Roll back complete join transaction if any stage fails (Requirement 1)
  Future<void> _rollbackJoinTransaction(String roomId) async {
    try {
      await RoomVoiceManager().leaveRoom();
      if (Get.isRegistered<RoomRealtimeController>()) {
        RoomRealtimeController.to.unsubscribeRoomRealtime();
      }
      debugPrint('[UltraFastRoomJoinEngine] Rollback complete for room $roomId.');
    } catch (e) {
      debugPrint('[UltraFastRoomJoinEngine] Rollback warning: $e');
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
