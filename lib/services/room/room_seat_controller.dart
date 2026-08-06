import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../user/user_profile_cache_manager.dart';
import 'room_permission_controller.dart';

class RoomSeatController extends GetxController {
  static RoomSeatController get to => Get.find<RoomSeatController>();

  final RxMap<String, List<Map<String, dynamic>>> roomSeatsInfo =
      <String, List<Map<String, dynamic>>>{}.obs;
  final RxMap<String, int> roomSeatGiftsCounters =
      <String, int>{}.obs;

  bool canOccupySeat(String roomId, int seatIndex, String userId) {
    if (seatIndex < 0 || seatIndex >= 10) return false;
    if (seatIndex == 0 || seatIndex == 1) {
      if (Get.isRegistered<RoomPermissionController>()) {
        final perm = RoomPermissionController.to;
        return perm.isHost(roomId, userId) ||
            perm.isCoHost(roomId, userId) ||
            perm.isModerator(roomId, userId);
      }
      return true;
    }
    return true;
  }

  Future<void> joinRoomSeat(String roomId, int seatIndex, {
    required Function(String, String, int, String, Map<String, dynamic>) onEmitActivity,
    required Future<void> Function() onRefreshProgression,
    required Future<void> Function() onRepairState,
  }) async {
    final currentUserId = UserProfileCacheManager.currentUserId;

    if (!canOccupySeat(roomId, seatIndex, currentUserId)) {
      Get.snackbar(
        'Seat Access Locked 🔒',
        'Seat ${seatIndex + 1} is reserved for Room Host, Co-Owners, and Admins.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    final seats = roomSeatsInfo[roomId];
    List<Map<String, dynamic>>? backupSeats;

    try {
      if (seats != null) {
        backupSeats = List<Map<String, dynamic>>.from(
            seats.map((s) => Map<String, dynamic>.from(s)));
        final List<Map<String, dynamic>> updatedSeats = List.from(backupSeats);

        final prevIdx =
            updatedSeats.indexWhere((s) => s['userId'] == currentUserId);
        if (prevIdx != -1) {
          updatedSeats[prevIdx] = {
            ...updatedSeats[prevIdx],
            'userId': null,
            'name': 'Seat ${prevIdx + 1}',
            'avatar': null,
            'isSpeaking': false,
          };
        }

        final profile = UserProfileCacheManager.currentUser;

        final targetIdx =
            updatedSeats.indexWhere((s) => s['seatIndex'] == seatIndex);
        if (targetIdx != -1) {
          updatedSeats[targetIdx] = {
            ...updatedSeats[targetIdx],
            'userId': currentUserId,
            'name': profile?.username ?? 'Creaniaa Student',
            'avatar': profile?.avatar,
            'level': profile?.level ?? 1,
            'vipLevel': profile?.vipLevel ?? 0,
            'nobleLevel': profile?.novelLevel ?? 0,
            'isSpeaking': false,
          };
        }

        roomSeatsInfo[roomId] = updatedSeats;
      }

      await Supabase.instance.client.rpc('join_room_seat', params: {
        'p_room_id': roomId,
        'p_seat_index': seatIndex,
      });

      final profile =
          await UserProfileCacheManager.fetchUserProfile(currentUserId);
      final uName = profile?.username ?? 'Creaniaa Student';

      final seatJoinMsgs = [
        '🎤 $uName took Seat #${seatIndex + 1}.',
        '👑 $uName is now sitting on Seat #${seatIndex + 1}.',
        '🎙️ $uName joined Seat #${seatIndex + 1}.'
      ];
      final message = seatJoinMsgs[Random().nextInt(seatJoinMsgs.length)];

      await onEmitActivity(
        'seat_join',
        currentUserId,
        seatIndex + 1,
        message,
        {
          'vip_level': profile?.vipLevel ?? 0,
          'noble_level': profile?.novelLevel ?? 0,
          'level': profile?.level ?? 1,
        },
      );

      await onRefreshProgression();
      await onRepairState();
    } catch (e) {
      debugPrint('Join seat failed, rolling back local optimistic state: $e');
      if (backupSeats != null) {
        roomSeatsInfo[roomId] = backupSeats;
      }
      rethrow;
    }
  }

  Future<void> leaveRoomSeat(String roomId, int seatIndex, {
    required Function(String, String, int, String, Map<String, dynamic>) onEmitActivity,
    required Future<void> Function() onRefreshProgression,
    required Future<void> Function() onRepairState,
  }) async {
    final currentUserId = UserProfileCacheManager.currentUserId;
    final seats = roomSeatsInfo[roomId];
    List<Map<String, dynamic>>? backupSeats;

    try {
      if (seats != null) {
        backupSeats = List<Map<String, dynamic>>.from(
            seats.map((s) => Map<String, dynamic>.from(s)));
        final List<Map<String, dynamic>> updatedSeats = List.from(backupSeats);
        final targetIdx =
            updatedSeats.indexWhere((s) => s['seatIndex'] == seatIndex);
        if (targetIdx != -1) {
          updatedSeats[targetIdx] = {
            ...updatedSeats[targetIdx],
            'userId': null,
            'name': 'Seat ${seatIndex + 1}',
            'avatar': null,
            'isSpeaking': false,
          };
        }
        roomSeatsInfo[roomId] = updatedSeats;
      }

      await Supabase.instance.client.rpc('leave_room_seat', params: {
        'p_room_id': roomId,
        'p_seat_index': seatIndex,
      });

      final profile =
          await UserProfileCacheManager.fetchUserProfile(currentUserId);
      final uName = profile?.username ?? 'Creaniaa Student';

      final seatLeaveMsgs = [
        '📤 $uName left Seat #${seatIndex + 1}.',
        '🎤 Seat #${seatIndex + 1} is now available.',
        '🚪 $uName left the microphone.'
      ];
      final message = seatLeaveMsgs[Random().nextInt(seatLeaveMsgs.length)];

      await onEmitActivity(
        'seat_leave',
        currentUserId,
        seatIndex + 1,
        message,
        {
          'vip_level': profile?.vipLevel ?? 0,
          'noble_level': profile?.novelLevel ?? 0,
          'level': profile?.level ?? 1,
        },
      );

      await onRefreshProgression();
      await onRepairState();
    } catch (e) {
      debugPrint('Leave seat failed, rolling back local optimistic state: $e');
      if (backupSeats != null) {
        roomSeatsInfo[roomId] = backupSeats;
      }
      rethrow;
    }
  }

  Future<bool> removeUserFromSeat(
    String roomId,
    int seatIndex,
    String targetUserId, {
    required Function(String, String, int, String) onEmitActivity,
  }) async {
    final seats = roomSeatsInfo[roomId];
    List<Map<String, dynamic>>? backupSeats;

    try {
      if (seats != null) {
        backupSeats = List<Map<String, dynamic>>.from(
            seats.map((s) => Map<String, dynamic>.from(s)));
        final List<Map<String, dynamic>> updatedSeats = List.from(backupSeats);
        final targetIdx =
            updatedSeats.indexWhere((s) => s['seatIndex'] == seatIndex);
        if (targetIdx != -1) {
          updatedSeats[targetIdx] = {
            ...updatedSeats[targetIdx],
            'userId': null,
            'name': 'Seat ${seatIndex + 1}',
            'avatar': null,
            'isSpeaking': false,
          };
        }
        roomSeatsInfo[roomId] = updatedSeats;
      }

      await Supabase.instance.client.rpc('leave_room_seat', params: {
        'p_room_id': roomId,
        'p_seat_index': seatIndex,
      });

      await onEmitActivity(
        'seat_removed',
        targetUserId,
        seatIndex + 1,
        '🚫 User was removed from Seat #${seatIndex + 1}.',
      );

      Get.snackbar(
        'User Removed 🚪',
        'Member removed from Seat ${seatIndex + 1}.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFF59E0B).withOpacity(0.9),
        colorText: Colors.white,
      );
      return true;
    } catch (e) {
      if (backupSeats != null) {
        roomSeatsInfo[roomId] = backupSeats;
      }
      debugPrint('Error removing user from seat: $e');
      Get.snackbar('Action Failed', e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> toggleSeatLock(String roomId, int seatIndex) async {
    try {
      final seats = roomSeatsInfo[roomId];
      if (seats == null) return false;

      final idx = seats.indexWhere((s) => s['seatIndex'] == seatIndex);
      if (idx == -1) return false;

      final currentLock = seats[idx]['isLocked'] == true;
      final newLockState = !currentLock;

      final updatedSeats = List<Map<String, dynamic>>.from(
          seats.map((s) => Map<String, dynamic>.from(s)));
      updatedSeats[idx]['isLocked'] = newLockState;
      roomSeatsInfo[roomId] = updatedSeats;

      await Supabase.instance.client.rpc('toggle_seat_lock', params: {
        'p_room_id': roomId,
        'p_seat_index': seatIndex,
        'p_is_locked': newLockState,
      });

      return true;
    } catch (e) {
      debugPrint('Error toggling seat lock: $e');
      return false;
    }
  }
}
