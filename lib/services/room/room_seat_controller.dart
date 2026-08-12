import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/room/room_activity_event.dart';
import '../user/user_profile_cache_manager.dart';
import 'room_permission_controller.dart';
import 'room_dual_progress_controller.dart';


class RoomSeatController extends GetxController {
  static RoomSeatController get to => Get.find<RoomSeatController>();

  final RxMap<String, List<Map<String, dynamic>>> roomSeatsInfo =
      <String, List<Map<String, dynamic>>>{}.obs;
  final RxMap<String, int> roomSeatGiftsCounters = <String, int>{}.obs;

  static String getSeatName(int seatIndex) {
    switch (seatIndex) {
      case 0:
        return 'Host';
      case 1:
        return 'Co-Host';
      case 2:
        return 'No.1';
      case 3:
        return 'No.2';
      case 4:
        return 'No.3';
      case 5:
        return 'No.4';
      case 6:
        return 'No.5';
      case 7:
        return 'No.6';
      case 8:
        return 'No.7';
      case 9:
        return 'No.8';
      default:
        return 'No.${seatIndex - 1}';
    }
  }

  static String getSeatNameByNumber(int seatNumber) {
    return getSeatName(seatNumber - 1);
  }

  bool canOccupySeat(String roomId, int seatIndex, String userId) {
    return seatIndex >= 0 && seatIndex < 10;
  }

  bool isUserReconnectingOnSeat(String roomId, int seatIndex) {
    final seats = roomSeatsInfo[roomId];
    if (seats == null) return false;
    final idx = seats.indexWhere((s) => s['seatIndex'] == seatIndex);
    if (idx == -1) return false;
    return seats[idx]['isReconnecting'] == true || seats[idx]['is_reconnecting'] == true;
  }

  Future<void> joinRoomSeat(
    String roomId,
    int seatIndex, {
    required Function(String, String, int, String, Map<String, dynamic>)
        onEmitActivity,
    required Future<void> Function() onRefreshProgression,
    required Future<void> Function() onRepairState,
  }) async {
    final currentUserId = UserProfileCacheManager.currentUserId;

    if (!canOccupySeat(roomId, seatIndex, currentUserId)) {
      return;
    }

    final seats = roomSeatsInfo[roomId];
    List<Map<String, dynamic>>? backupSeats;
    int prevIdx = -1;

    try {
      if (seats != null) {
        backupSeats = List<Map<String, dynamic>>.from(
            seats.map((s) => Map<String, dynamic>.from(s)));
        final List<Map<String, dynamic>> updatedSeats = List.from(backupSeats);

        final targetIdx =
            updatedSeats.indexWhere((s) => s['seatIndex'] == seatIndex);

        final bool isAlreadyOnSeat =
            targetIdx != -1 && updatedSeats[targetIdx]['userId'] == currentUserId;
        final int existingGems = isAlreadyOnSeat
            ? ((updatedSeats[targetIdx]['seatSessionGems'] as num?)?.toInt() ?? 0)
            : 0;
        final String? existingSessionId = isAlreadyOnSeat
            ? updatedSeats[targetIdx]['seatSessionId'] as String?
            : null;

        prevIdx = updatedSeats.indexWhere((s) => s['userId'] == currentUserId && s['seatIndex'] != seatIndex);
        if (prevIdx != -1) {
          updatedSeats[prevIdx] = {
            ...updatedSeats[prevIdx],
            'userId': null,
            'seatSessionId': null,
            'seatSessionGems': 0,
            'seatTotalStars': 0,
            'seatTotalGems': 0,
            'name': getSeatName(prevIdx),
            'avatar': null,
            'isSpeaking': false,
          };
        }

        final profile = UserProfileCacheManager.currentUser;

        if (targetIdx != -1) {
          updatedSeats[targetIdx] = {
            ...updatedSeats[targetIdx],
            'userId': currentUserId,
            'seatSessionId': existingSessionId ?? 'ss_local_${DateTime.now().microsecondsSinceEpoch}',
            'seatSessionGems': existingGems,
            'seatTotalStars': existingGems,
            'seatTotalGems': existingGems,
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

      String eventType;
      String message;

      if (prevIdx != -1) {
        eventType = ArenaEventTypes.seatChanged;
        message = ArenaEventFormatter.formatSeatMoveMessage(uName, prevIdx, seatIndex);
      } else {
        eventType = ArenaEventTypes.seatTaken;
        message = ArenaEventFormatter.formatSeatTakeMessage(uName, seatIndex);
      }

      await onEmitActivity(
        eventType,
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

      // Trigger 1-time daily unique user seat occupancy join bonus (+20 Normal AP, max 5 users/day)
      try {
        if (Get.isRegistered<RoomDualProgressController>()) {
          await RoomDualProgressController.to.claimUniqueSeatBonus(roomId, currentUserId);
        }
      } catch (e) {
        debugPrint('Claim unique seat bonus error: $e');
      }
    } catch (e) {
      debugPrint('Join seat failed, rolling back local optimistic state: $e');
      if (backupSeats != null) {
        roomSeatsInfo[roomId] = backupSeats;
      }
      rethrow;
    }
  }

  Future<void> leaveRoomSeat(
    String roomId,
    int seatIndex, {
    required Function(String, String, int, String, Map<String, dynamic>)
        onEmitActivity,
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
            'seatSessionId': null,
            'seatSessionGems': 0,
            'seatTotalStars': 0,
            'seatTotalGems': 0,
            'name': getSeatName(seatIndex),
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

      final String eventType = ArenaEventTypes.seatLeft;
      final message = ArenaEventFormatter.formatSeatLeaveMessage(uName, seatIndex);

      await onEmitActivity(
        eventType,
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
            'seatSessionId': null,
            'seatSessionGems': 0,
            'seatTotalStars': 0,
            'seatTotalGems': 0,
            'name': getSeatName(seatIndex),
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

      final seatName = getSeatName(seatIndex);
      await onEmitActivity(
        'seat_removed',
        targetUserId,
        seatIndex + 1,
        '🚫 User was removed from $seatName.',
      );

      Get.snackbar(
        'User Removed 🚪',
        'Member removed from $seatName.',
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
