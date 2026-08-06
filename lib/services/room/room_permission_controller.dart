import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/room/room_model.dart';
import 'room_discovery_controller.dart';

class RoomPermissionController extends GetxController {
  static RoomPermissionController get to => Get.find<RoomPermissionController>();

  final RxMap<String, bool> currentPermissions = <String, bool>{}.obs;

  Future<void> fetchRoomPermissions(String roomId) async {
    try {
      final response =
          await Supabase.instance.client.rpc('get_room_permissions', params: {
        'p_room_id': roomId,
      });
      if (response != null) {
        final Map<String, bool> permissions = {};
        (response as Map<String, dynamic>).forEach((key, value) {
          permissions[key] = value == true;
        });
        currentPermissions.assignAll(permissions);
      }
    } catch (e) {
      debugPrint('Error fetching room permissions: $e');
    }
  }

  bool canPerformAction(String action) {
    final _ = currentPermissions.length;
    return currentPermissions[action] == true;
  }

  String getUserRole(VoiceRoom room, String userId, {List<Map<String, dynamic>>? seatsInfo}) {
    if (room.hostId == userId || room.founderId == userId) return 'Creator';
    if (room.coOwnerIds.contains(userId) == true) return 'Co-Owner';
    if (room.adminIds.contains(userId) == true || room.moderatorIds.contains(userId) == true) return 'Admin';

    // Check if user is currently occupying Seat 1 (Seat Index 0)
    if (seatsInfo != null && seatsInfo.isNotEmpty) {
      final seat1 = seatsInfo.firstWhereOrNull((s) => s['seatIndex'] == 0 || s['seatNumber'] == 0 || seatsInfo.indexOf(s) == 0);
      if (seat1 != null && seat1['userId'] == userId) {
        return 'Host';
      }
    }

    return 'Audience';
  }

  int getRoleWeight(String role) {
    switch (role.toLowerCase()) {
      case 'creator':
      case 'owner':
      case 'founder':
        return 10;
      case 'co-owner':
      case 'co owner':
      case 'co-host':
        return 8;
      case 'admin':
      case 'moderator':
        return 7;
      case 'host':
        return 6;
      case 'audience':
      case 'listener':
      case 'guest':
      default:
        return 1;
    }
  }

  Map<String, int> getRoomRoleLimits(int roomLevel) {
    final level = roomLevel < 1 ? 1 : roomLevel;
    if (level == 1) return {'co_owners': 1, 'admins': 4};
    if (level == 2) return {'co_owners': 1, 'admins': 10};
    if (level == 3) return {'co_owners': 2, 'admins': 15};
    if (level == 4) return {'co_owners': 2, 'admins': 20};
    if (level == 5) return {'co_owners': 3, 'admins': 25};
    if (level == 6) return {'co_owners': 4, 'admins': 35};
    return {'co_owners': 5, 'admins': 50};
  }

  bool canChangeEntryRules(VoiceRoom room, String userId) {
    final role = getUserRole(room, userId);
    return role == 'Creator' || role == 'Owner' || role == 'Co-Owner' || role == 'Co Owner';
  }

  bool isHost(String roomId, String userId, {VoiceRoom? room}) {
    final r = room ??
        (Get.isRegistered<RoomDiscoveryController>()
            ? RoomDiscoveryController.to.rooms
                .firstWhereOrNull((item) => item.id == roomId)
            : null);
    if (r != null) {
      return r.hostId == userId || r.founderId == userId;
    }
    return currentPermissions['is_host'] == true;
  }

  bool isCoHost(String roomId, String userId, {VoiceRoom? room}) {
    final r = room ??
        (Get.isRegistered<RoomDiscoveryController>()
            ? RoomDiscoveryController.to.rooms
                .firstWhereOrNull((item) => item.id == roomId)
            : null);
    if (r != null) {
      return r.coOwnerIds.contains(userId) == true;
    }
    return currentPermissions['is_cohost'] == true;
  }

  bool isModerator(String roomId, String userId, {VoiceRoom? room}) {
    final r = room ??
        (Get.isRegistered<RoomDiscoveryController>()
            ? RoomDiscoveryController.to.rooms
                .firstWhereOrNull((item) => item.id == roomId)
            : null);
    if (r != null) {
      return r.adminIds.contains(userId) == true ||
          r.moderatorIds.contains(userId) == true;
    }
    return currentPermissions['is_moderator'] == true;
  }
}
