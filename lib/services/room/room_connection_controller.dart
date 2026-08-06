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
import 'room_moderation_controller.dart';

class RoomConnectionController extends GetxController {
  static RoomConnectionController get to => Get.find<RoomConnectionController>();

  String? activeRoomId;

  final RxBool isRoomDisconnecting = false.obs;
  final RxString disconnectTitle = ''.obs;
  final RxString disconnectReason = ''.obs;

  Timer? _activeHeartbeatTimer;
  int _consecutiveHeartbeatFailures = 0;

  Map<String, dynamic> validate12StepRoomEntry(String roomId, String userId) {
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

  void startHeartbeatLoop(String roomId, bool Function() isMicOnGetter) {
    _activeHeartbeatTimer?.cancel();
    _consecutiveHeartbeatFailures = 0;
    _activeHeartbeatTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (activeRoomId != roomId) {
        timer.cancel();
        return;
      }
      final bool success = await heartbeatRoomMember(roomId, isMicOnGetter());
      if (!success) {
        _consecutiveHeartbeatFailures++;
        debugPrint(
            '[RoomConnectionController] Heartbeat failed ($_consecutiveHeartbeatFailures/4 - ${_consecutiveHeartbeatFailures * 2}s)');
        if (_consecutiveHeartbeatFailures >= 4) {
          debugPrint(
              '[RoomConnectionController] 8s network timeout reached. Leaving room & redirecting to Arena page.');
          timer.cancel();
          triggerInRoomDisconnectOverlay(
            title: 'Network Issue Detected 📡',
            reason:
                'Network disconnect: Redirected to Arena main page (8s timeout)',
          );
        }
      } else {
        _consecutiveHeartbeatFailures = 0;
      }
      await repairRoomState(roomId);
    });
  }

  Future<bool> heartbeatRoomMember(String roomId, bool isSpeaking) async {
    try {
      await Supabase.instance.client
          .rpc('heartbeat_room_member', params: {
        'p_room_id': roomId,
        'p_is_speaking': isSpeaking,
      });
      return true;
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
      _activeHeartbeatTimer?.cancel();
      _activeHeartbeatTimer = null;
      _consecutiveHeartbeatFailures = 0;

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
      final currentUserId = UserProfileCacheManager.currentUserId;
      if (activeRoomId != null && activeRoomId != roomId) {
        debugPrint('[RoomConnectionController] Auto-leaving previous active room $activeRoomId before entering $roomId');
        await exitRoom(activeRoomId!);
      }

      activeRoomId = roomId;

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

      final response = await Supabase.instance.client.rpc('join_room', params: {
        'p_room_id': roomId,
        'p_password': password,
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
