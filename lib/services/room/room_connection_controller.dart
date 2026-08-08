import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../models/room/room_model.dart';
import '../../models/user/user_model.dart';
import '../user/user_profile_cache_manager.dart';
import '../user/customization_controller.dart';
import '../chat/chat_socket_service.dart';
import 'room_chat_controller.dart';
import 'room_seat_controller.dart';
import 'room_member_controller.dart';
import 'room_realtime_controller.dart';
import 'room_progression_controller.dart';
import 'room_permission_controller.dart';
import 'room_activity_controller.dart';
import 'room_discovery_controller.dart';
import '../voice/room_voice_manager.dart';
import 'room_gift_controller.dart';
import 'room_background_controller.dart';
import 'room_moderation_controller.dart';

import '../network/network_connectivity_service.dart';
import '../network/network_guard.dart';

enum RoomNetworkState {
  connected,
  networkIssue,
  networkLost,
  leftRoom,
}

class RoomConnectionController extends GetxController {
  static RoomConnectionController get to => Get.find<RoomConnectionController>();

  String? activeRoomId;

  final Rx<RoomNetworkState> roomNetworkState = RoomNetworkState.connected.obs;
  final RxBool isReconnecting = false.obs;

  final RxBool isRoomDisconnecting = false.obs;
  final RxString disconnectTitle = ''.obs;
  final RxString disconnectReason = ''.obs;

  Timer? _activeHeartbeatTimer;
  Timer? _reconnectGraceTimer;
  Timer? _offlineConfirmTimer;
  int _consecutiveHeartbeatFailures = 0;
  Worker? _onlineStateWorker;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<NetworkConnectivityService>()) {
      _onlineStateWorker = ever(NetworkConnectivityService.to.isOnline, (bool isOnline) {
        _handleNetworkConnectivityChange(isOnline);
      });
    }
  }

  @override
  void onClose() {
    _onlineStateWorker?.dispose();
    _cancelAllTimers();
    super.onClose();
  }

  void _cancelAllTimers() {
    _activeHeartbeatTimer?.cancel();
    _reconnectGraceTimer?.cancel();
    _offlineConfirmTimer?.cancel();
    _activeHeartbeatTimer = null;
    _reconnectGraceTimer = null;
    _offlineConfirmTimer = null;
  }

  /// Entry Protection Validation (Step 1)
  Map<String, dynamic> validate12StepRoomEntry(String roomId, String userId) {
    if (!NetworkConnectivityService.to.isOnline.value) {
      NetworkConnectivityService.to.logAnalyticsEvent('failed_room_join_offline', {'room_id': roomId});
      return {'canJoin': false, 'reason': "No internet connection. Please check your network."};
    }

    final rooms = Get.isRegistered<RoomDiscoveryController>()
        ? RoomDiscoveryController.to.rooms
        : <VoiceRoom>[];
    final room = rooms.firstWhereOrNull((r) => r.id == roomId);

    if (room != null && (room.hostId == userId || room.founderId == userId || room.coOwnerIds.contains(userId))) {
      return {'canJoin': true, 'reason': 'Management Priority Access'};
    }

    final isBanned = Get.isRegistered<RoomModerationController>() &&
        (RoomModerationController.to.bannedUsers[roomId]?.contains(userId) == true);
    if (isBanned) {
      return {'canJoin': false, 'reason': 'Permanently Banned from Room'};
    }

    return {'canJoin': true, 'reason': 'Allowed'};
  }

  /// Network State Engine & Connectivity Event Receiver
  void _handleNetworkConnectivityChange(bool isOnline) {
    if (activeRoomId == null) {
      // User is outside any room. Reconnected event here does NOT force-navigate user into a room.
      return;
    }

    if (!isOnline) {
      // Device lost internet connection.
      // Trigger short 2.5-second confirmation window to prevent false drop eviction (Step 3)
      _startOfflineConfirmationTimer();
    } else {
      // Internet connection restored!
      _handleInternetRestored();
    }
  }

  /// Step 3: Short 2 to 3 second confirmation window for complete internet loss
  void _startOfflineConfirmationTimer() {
    if (roomNetworkState.value == RoomNetworkState.networkLost) return;
    debugPrint('[RoomConnectionController] 📶 Internet lost detected! Starting 2.5s confirmation timer...');

    roomNetworkState.value = RoomNetworkState.networkLost;
    _offlineConfirmTimer?.cancel();
    _offlineConfirmTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!NetworkConnectivityService.to.isOnline.value && activeRoomId != null) {
        debugPrint('[RoomConnectionController] ❌ 2.5s confirmed complete network loss timeout reached. Leaving room.');
        leaveActiveRoomLocally(
          reason: 'No internet connection. Please check your network.',
          navigateToArena: true,
        );
        roomNetworkState.value = RoomNetworkState.leftRoom;
      }
    });
  }

  /// Step 2: Unstable connection / Socket drop -> 10s frontend grace period
  void handleSocketOrNetworkDrop() {
    if (activeRoomId == null || roomNetworkState.value == RoomNetworkState.leftRoom) return;

    if (roomNetworkState.value == RoomNetworkState.connected) {
      debugPrint('[RoomConnectionController] ⚠️ Network issue/socket drop detected! Starting 10s frontend grace period.');
      roomNetworkState.value = RoomNetworkState.networkIssue;
      isReconnecting.value = true;

      _reconnectGraceTimer?.cancel();
      _reconnectGraceTimer = Timer(const Duration(seconds: 10), () {
        if (roomNetworkState.value == RoomNetworkState.networkIssue && activeRoomId != null) {
          debugPrint('[RoomConnectionController] ⏱️ 10s frontend grace period expired. Leaving room.');
          leaveActiveRoomLocally(
            reason: 'Network issue. Could not reconnect within 10s.',
            navigateToArena: true,
          );
          roomNetworkState.value = RoomNetworkState.leftRoom;
        }
      });
    }
  }

  /// Step 4: Automatic Reconnection when internet recovers within grace period
  void _handleInternetRestored() {
    debugPrint('[RoomConnectionController] 📶 Internet restored! Restoring room session...');
    _offlineConfirmTimer?.cancel();
    _offlineConfirmTimer = null;

    if (roomNetworkState.value == RoomNetworkState.networkIssue ||
        roomNetworkState.value == RoomNetworkState.networkLost) {
      _performBackgroundReconnection();
    }
  }

  Future<void> _performBackgroundReconnection() async {
    final roomId = activeRoomId;
    if (roomId == null) return;

    try {
      debugPrint('[RoomConnectionController] Attempting background session & socket auto-reconnect...');
      
      // 1. Reconnect Heartbeat RPC
      final bool hbSuccess = await heartbeatRoomMember(roomId, false);
      if (hbSuccess) {
        // 2. Repair room state from snapshot
        await repairRoomState(roomId);

        // 3. Restore clean connected state
        _reconnectGraceTimer?.cancel();
        _reconnectGraceTimer = null;
        roomNetworkState.value = RoomNetworkState.connected;
        isReconnecting.value = false;

        debugPrint('[RoomConnectionController] 🟢 Background reconnection completed cleanly for room $roomId!');
      } else {
        debugPrint('[RoomConnectionController] Background heartbeat failed during reconnect attempt.');
      }
    } catch (e) {
      debugPrint('[RoomConnectionController] Background reconnection error: $e');
    }
  }

  void triggerInRoomDisconnectOverlay({
    required String title,
    required String reason,
    bool navigateToArena = true,
  }) {
    if (isRoomDisconnecting.value) return;
    isRoomDisconnecting.value = true;
    disconnectTitle.value = title;
    disconnectReason.value = reason;

    Timer(const Duration(milliseconds: 1500), () {
      leaveActiveRoomLocally(
        reason: reason,
        navigateToArena: navigateToArena,
      );
      isRoomDisconnecting.value = false;
      disconnectTitle.value = '';
      disconnectReason.value = '';
    });
  }

  /// Step 5: 10s Heartbeat Loop with 30s Server Grace Period (3 failures = 30s)
  void startHeartbeatLoop(String roomId, bool Function() isMicOnGetter) {
    _activeHeartbeatTimer?.cancel();
    _consecutiveHeartbeatFailures = 0;
    roomNetworkState.value = RoomNetworkState.connected;
    isReconnecting.value = false;

    _activeHeartbeatTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (activeRoomId != roomId) {
        timer.cancel();
        return;
      }
      final bool success = await heartbeatRoomMember(roomId, isMicOnGetter());
      if (!success) {
        _consecutiveHeartbeatFailures++;
        debugPrint(
            '[RoomConnectionController] 10s Heartbeat failed ($_consecutiveHeartbeatFailures/3 - ${_consecutiveHeartbeatFailures * 10}s grace period)');
        
        handleSocketOrNetworkDrop();

        if (_consecutiveHeartbeatFailures >= 3) {
          debugPrint(
              '[RoomConnectionController] 30s server grace period expired. Leaving room & redirecting to Arena.');
          timer.cancel();
          leaveActiveRoomLocally(
            reason: 'Disconnected due to no internet (30s server grace period expired)',
            navigateToArena: true,
          );
          roomNetworkState.value = RoomNetworkState.leftRoom;
        }
      } else {
        _consecutiveHeartbeatFailures = 0;
        if (roomNetworkState.value == RoomNetworkState.networkIssue ||
            roomNetworkState.value == RoomNetworkState.networkLost) {
          _reconnectGraceTimer?.cancel();
          _reconnectGraceTimer = null;
          roomNetworkState.value = RoomNetworkState.connected;
          isReconnecting.value = false;
        }
      }
      await repairRoomState(roomId);
    });
  }

  Future<bool> heartbeatRoomMember(String roomId, bool isSpeaking) async {
    try {
      final sessionId = UserProfileCacheManager.currentSessionId;
      final response = await Supabase.instance.client
          .rpc('heartbeat_room_member', params: {
        'p_room_id': roomId,
        'p_session_id': sessionId.isNotEmpty ? sessionId : null,
        'p_is_speaking': isSpeaking,
      });

      if (response != null && response is Map && response['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[RoomConnectionController] Heartbeat RPC error: $e');
      return false;
    }
  }

  Future<void> repairRoomState(String roomId) async {
    try {
      final response = await Supabase.instance.client
          .rpc('get_room_state_snapshot', params: {
        'p_room_id': roomId,
      });
      if (response != null && response is Map<String, dynamic>) {
        if (response['seats'] != null && response['seats'] is List && Get.isRegistered<RoomSeatController>()) {
          final List<dynamic> seatsJson = response['seats'];
          final List<Map<String, dynamic>> seatsList = [];
          for (final s in seatsJson) {
            seatsList.add(Map<String, dynamic>.from(s as Map));
          }
          RoomSeatController.to.roomSeatsInfo[roomId] = seatsList;
        }

        if (response['members'] != null && response['members'] is List && Get.isRegistered<RoomMemberController>()) {
          final List<dynamic> mems = response['members'];
          RoomMemberController.to.activeMembers.assignAll(mems
              .map((m) =>
                  RoomMember.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList());
        }

        if (response['requests'] != null && response['requests'] is List && Get.isRegistered<RoomMemberController>()) {
          final List<dynamic> reqs = response['requests'];
          RoomMemberController.to.activeRequests.assignAll(
              reqs.map((r) => Map<String, dynamic>.from(r as Map)).toList());
        }

        if (response['chat_history'] != null &&
            response['chat_history'] is List && Get.isRegistered<RoomChatController>()) {
          final chatCtrl = RoomChatController.to;
          chatCtrl.initializeChatForRoom(roomId);
          final chatList = chatCtrl.roomChats[roomId]!;
          final List<dynamic> history = response['chat_history'];
          for (final item in history) {
            final map = Map<String, dynamic>.from(item as Map);
            final msg = RoomChatMessage(
              id: map['id'].toString(),
              senderId: map['senderId'].toString(),
              senderName: map['senderName'] ?? 'Member',
              text: map['content'] ?? '',
              senderAvatar: map['senderAvatar'],
              timestamp: map['createdAt'] != null
                  ? DateTime.parse(map['createdAt'])
                  : DateTime.now(),
              messageType: map['messageType'] ?? 'text',
            );
            if (!chatList.any((m) => m.id == msg.id)) {
              chatList.add(msg);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[RoomConnectionController] repairRoomState error: $e');
    }
  }

  void leaveActiveRoomLocally({String? reason, bool navigateToArena = false}) {
    try {
      _cancelAllTimers();
      _consecutiveHeartbeatFailures = 0;
      roomNetworkState.value = RoomNetworkState.leftRoom;
      isReconnecting.value = false;

      String currentUserId = '';
      try {
        currentUserId = UserProfileCacheManager.currentUserId;
      } catch (_) {}
      final roomId = activeRoomId;
      if (roomId != null) {
        try {
          if (Get.isRegistered<RoomSeatController>()) {
            final seats = RoomSeatController.to.roomSeatsInfo[roomId];
            if (seats != null) {
              final seat =
                  seats.firstWhereOrNull((s) => s['userId'] == currentUserId);
              if (seat != null) {
                final seatIdx = seat['seatIndex'] as int;
                try {
                  Supabase.instance.client
                      .rpc('leave_room_seat', params: {
                        'p_room_id': roomId,
                        'p_seat_index': seatIdx,
                      })
                      .then((_) => null)
                      .catchError((_) => null);
                } catch (_) {}
              }
            }
          }

          try {
            Supabase.instance.client
                .rpc('leave_room', params: {
                  'p_room_id': roomId,
                })
                .then((_) => null)
                .catchError((_) => null);
          } catch (_) {}
        } catch (_) {}
      }

      RoomVoiceManager().leaveRoom();

      activeRoomId = null;
      if (Get.isRegistered<RoomRealtimeController>()) {
        RoomRealtimeController.to.unsubscribeRoomRealtime();
      }

      if (Get.isRegistered<RoomPermissionController>()) {
        RoomPermissionController.to.currentPermissions.clear();
      }
      if (Get.isRegistered<RoomMemberController>()) {
        RoomMemberController.to.activeMembers.clear();
        RoomMemberController.to.activeRequests.clear();
        RoomMemberController.to.isMutedByModerator.value = false;
      }
      if (Get.isRegistered<RoomActivityController>()) {
        RoomActivityController.to.activePolls.clear();
      }
      if (Get.isRegistered<RoomChatController>()) {
        RoomChatController.to.typingUsers.clear();
        if (roomId != null) {
          RoomChatController.to.roomChats[roomId]?.clear();
          RoomChatController.to.roomChats.remove(roomId);
        }
        RoomChatController.to.bottomSystemNotifications.clear();
        RoomChatController.to.activeSystemNotification.value = null;
      }
      if (Get.isRegistered<RoomGiftController>()) {
        RoomGiftController.to.activeGiftNotification.value = null;
        RoomGiftController.to.activeGiftAnimation.value = null;
      }
      if (Get.isRegistered<RoomProgressionController>()) {
        RoomProgressionController.to.stopProgressionTimer();
      }

      if (navigateToArena) {
        try {
          if (Get.context != null) {
            Get.until((route) => route.isFirst);
          }
        } catch (e) {
          debugPrint('Error popping route to Arena main page: $e');
        }
      }

      if (reason != null && Get.context != null) {
        Get.snackbar(
          'Room Disconnected',
          reason,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent.shade700,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      debugPrint('Error in leaveActiveRoomLocally: $e');
    }
  }

  Future<void> enterRoom(String roomId, {String? password}) async {
    try {
      final bool hasNet = await NetworkConnectivityService.to.verifyInternetAccess();
      if (!hasNet || !NetworkGuard.checkInternet(actionName: 'room_entry', customOfflineMessage: 'No internet connection. Please check your network.')) {
        NetworkConnectivityService.to.logAnalyticsEvent('failed_room_join_offline', {'room_id': roomId});
        throw Exception('No internet connection. Please check your network.');
      }

      roomNetworkState.value = RoomNetworkState.connected;
      isReconnecting.value = false;

      final currentUserId = UserProfileCacheManager.currentUserId;
      if (activeRoomId != null && activeRoomId != roomId) {
        debugPrint('[RoomConnectionController] Auto-leaving previous active room $activeRoomId before entering $roomId');
        await exitRoom(activeRoomId!);
      }

      activeRoomId = roomId;

      if (Get.isRegistered<RoomBackgroundController>()) {
        RoomBackgroundController.to.loadRoomBackgroundForRoom(roomId);
      }

      if (Get.isRegistered<RoomChatController>()) {
        final chatCtrl = RoomChatController.to;
        chatCtrl.initializeChatForRoom(roomId);
        chatCtrl.typingUsers.clear();
        chatCtrl.bottomSystemNotifications.clear();
        chatCtrl.activeSystemNotification.value = null;
      }
      if (Get.isRegistered<RoomMemberController>()) {
        RoomMemberController.to.activeRequests.clear();
      }
      if (Get.isRegistered<RoomActivityController>()) {
        RoomActivityController.to.activePolls.clear();
      }
      if (Get.isRegistered<RoomProgressionController>()) {
        RoomProgressionController.to.marqueeAnnouncementsQueue.clear();
      }
      if (Get.isRegistered<RoomGiftController>()) {
        RoomGiftController.to.activeGiftNotification.value = null;
        RoomGiftController.to.activeGiftAnimation.value = null;
      }

      final sessionId = UserProfileCacheManager.currentSessionId;
      final response = await Supabase.instance.client.rpc('join_room', params: {
        'p_room_id': roomId,
        'p_password': password,
        'p_session_id': sessionId.isNotEmpty ? sessionId : null,
      });

      debugPrint('Join room response: $response');

      final parallelResults = await Future.wait<dynamic>([
        RoomPermissionController.to.fetchRoomPermissions(roomId),
        RoomMemberController.to.fetchRoomMembers(
          roomId,
          activeRoomId: activeRoomId,
          onDisconnect: (t, r) => triggerInRoomDisconnectOverlay(title: t, reason: r),
          onSyncRoom: (rid, mems) {
            if (Get.isRegistered<RoomDiscoveryController>()) {
              RoomDiscoveryController.to.syncRoomFromMembers(rid, mems);
            }
          },
        ),
        RoomMemberController.to.fetchRoomRequests(roomId),
        RoomActivityController.to.fetchRoomPolls(roomId),
        UserProfileCacheManager.fetchUserProfile(currentUserId),
      ]);

      final profile = parallelResults[4] as User?;
      final uName = profile?.username ?? 'Creaniaa Student';
      final uLevel = profile?.level ?? 1;
      final vipLevel = profile?.vipLevel ?? 0;
      final nobleLevel = profile?.novelLevel ?? 0;

      final roomsList = Get.isRegistered<RoomDiscoveryController>() ? RoomDiscoveryController.to.rooms : <VoiceRoom>[];
      final activeRoom = roomsList.firstWhereOrNull((r) => r.id == roomId);
      final isOwner = activeRoom?.hostId == currentUserId;

      String greetingMsg = '👋 Welcome $uName! Enjoy your time in this arena.';
      if (isOwner) {
        greetingMsg = '🏠 Arena Owner $uName joined.';
      } else if (nobleLevel > 0) {
        greetingMsg = '👑 Noble $uName has arrived.';
      } else if (vipLevel > 0) {
        greetingMsg =
            '💎 VIP $uName entered the arena. Give them a warm welcome!';
      } else if (uLevel >= 50) {
        greetingMsg = '🔥 Level $uLevel $uName entered the arena.';
      }

      String? equippedEntryEffect;
      try {
        if (Get.isRegistered<CustomizationController>()) {
          equippedEntryEffect = Get.find<CustomizationController>().activeEntryEffect.value;
        }
      } catch (_) {}

      await RoomActivityController.to.emitRoomActivityEvent(
        roomId: roomId,
        eventType: 'room_join',
        userId: currentUserId,
        username: uName,
        message: greetingMsg,
        metadata: {
          'level': uLevel,
          'vip_level': vipLevel,
          'noble_level': nobleLevel,
          'entry_effect': equippedEntryEffect,
        },
      );

      if (Get.isRegistered<RoomRealtimeController>()) {
        RoomRealtimeController.to.subscribeToRoomRealtime(
          roomId,
          activeRoomId: activeRoomId,
          onFetchMembers: (rid) => RoomMemberController.to.fetchRoomMembers(
            rid,
            activeRoomId: activeRoomId,
            onDisconnect: (t, r) => triggerInRoomDisconnectOverlay(title: t, reason: r),
            onSyncRoom: (rid, mems) {
              if (Get.isRegistered<RoomDiscoveryController>()) {
                RoomDiscoveryController.to.syncRoomFromMembers(rid, mems);
              }
            },
          ),
          onFetchPermissions: (rid) => RoomPermissionController.to.fetchRoomPermissions(rid),
          onFetchRequests: (rid) => RoomMemberController.to.fetchRoomRequests(rid),
          onFetchPolls: (rid) => RoomActivityController.to.fetchRoomPolls(rid),
          onFetchProgression: (rid) => RoomProgressionController.to.fetchRoomProgression(
            rid,
            onUpdateSeats: (m) => RoomSeatController.to.roomSeatsInfo.addAll(m),
            onUpdateSeatGifts: (m) => RoomSeatController.to.roomSeatGiftsCounters.addAll(m),
          ),
          onCleanupResources: leaveActiveRoomLocally,
        );
      }

      await RoomProgressionController.to.fetchRoomProgression(
        roomId,
        onUpdateSeats: (m) => RoomSeatController.to.roomSeatsInfo.addAll(m),
        onUpdateSeatGifts: (m) => RoomSeatController.to.roomSeatGiftsCounters.addAll(m),
      );
      RoomProgressionController.to.startProgressionTimer(
        roomId,
        activeRoomId: activeRoomId,
        seats: RoomSeatController.to.roomSeatsInfo[roomId],
      );

      try {
        ChatSocketService.to.emitRoomJoinStatus(roomId);
      } catch (err) {
        debugPrint('Socket join status notify failed: $err');
      }
    } catch (e) {
      debugPrint('Error entering room: $e');
      Get.snackbar(
        'Join Failed',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      rethrow;
    }
  }

  Future<void> exitRoom(String roomId) async {
    try {
      final currentUserId = UserProfileCacheManager.currentUserId;
      RoomVoiceManager().leaveRoom();
      if (Get.isRegistered<RoomProgressionController>()) {
        RoomProgressionController.to.stopProgressionTimer();
      }

      if (Get.isRegistered<RoomSeatController>()) {
        final seats = RoomSeatController.to.roomSeatsInfo[roomId];
        if (seats != null) {
          final seat =
              seats.firstWhereOrNull((s) => s['userId'] == currentUserId);
          if (seat != null) {
            final seatIdx = seat['seatIndex'] as int;
            await Supabase.instance.client.rpc('leave_room_seat', params: {
              'p_room_id': roomId,
              'p_seat_index': seatIdx,
            });
          }
        }
      }

      try {
        ChatSocketService.to.emitRoomLeaveStatus(roomId);
      } catch (err) {
        debugPrint('Socket leave status notify failed: $err');
      }

      activeRoomId = null;
      if (Get.isRegistered<RoomRealtimeController>()) {
        RoomRealtimeController.to.unsubscribeRoomRealtime();
      }
      if (Get.isRegistered<RoomPermissionController>()) {
        RoomPermissionController.to.currentPermissions.clear();
      }
      if (Get.isRegistered<RoomMemberController>()) {
        RoomMemberController.to.activeMembers.clear();
        RoomMemberController.to.activeRequests.clear();
        RoomMemberController.to.isMutedByModerator.value = false;
      }
      if (Get.isRegistered<RoomActivityController>()) {
        RoomActivityController.to.activePolls.clear();
      }
      if (Get.isRegistered<RoomChatController>()) {
        RoomChatController.to.roomChats[roomId]?.clear();
      }

      final profile =
          await UserProfileCacheManager.fetchUserProfile(currentUserId);
      final uName = profile?.username ?? 'Creaniaa Student';

      if (Get.isRegistered<RoomActivityController>()) {
        await RoomActivityController.to.emitRoomActivityEvent(
          roomId: roomId,
          eventType: 'room_leave',
          userId: currentUserId,
          username: uName,
          message: '👋 $uName left the arena.',
        );
      }

      await Supabase.instance.client.rpc('leave_room', params: {
        'p_room_id': roomId,
      });
    } catch (e) {
      debugPrint('Error leaving room: $e');
    }
  }
}
