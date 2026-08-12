import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/room/room_model.dart';
import 'room_discovery_controller.dart';
import 'room_member_controller.dart';

class RoomPermissionController extends GetxController {
  static RoomPermissionController get to =>
      Get.find<RoomPermissionController>();

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

  bool isAssignedRole(String role) {
    final l = role.toLowerCase().trim().replaceAll('-', '').replaceAll(' ', '');
    return l == 'creator' ||
        l == 'owner' ||
        l == 'founder' ||
        l == 'coowner' ||
        l == 'admin' ||
        l == 'mod' ||
        l == 'moderator' ||
        l == 'host';
  }

  String getUserRole(VoiceRoom room, String userId,
      {List<Map<String, dynamic>>? seatsInfo}) {
    if ((room.ownerUserId.isNotEmpty && room.ownerUserId == userId) ||
        (room.hostId.isNotEmpty && room.hostId == userId)) {
      return 'Owner';
    }

    // Check active assigned roles from DB room_members via RoomMemberController
    if (Get.isRegistered<RoomMemberController>()) {
      final member = RoomMemberController.to.activeMembers
          .firstWhereOrNull((m) => m.userId == userId);
      if (member != null && member.role.isNotEmpty) {
        final r = member.role.trim();
        final l = r.toLowerCase().replaceAll('-', '').replaceAll(' ', '');
        if (l == 'coowner') return 'Co-Owner';
        if (l == 'admin') return 'Admin';
        if (l == 'mod' || l == 'moderator' || l == 'host') return 'Mod';
      }
    }

    if (room.coOwnerIds.contains(userId) == true) return 'Co-Owner';
    if (room.adminIds.contains(userId) == true) return 'Admin';
    if (room.hostIds.contains(userId) == true ||
        room.moderatorIds.contains(userId) == true) return 'Mod';

    return 'Audience';
  }

  int getRoleWeight(String role) {
    switch (role.toLowerCase().trim().replaceAll('-', '').replaceAll(' ', '')) {
      case 'creator':
      case 'owner':
      case 'founder':
      case 'arenaowner':
        return 10;
      case 'coowner':
        return 8;
      case 'admin':
        return 7;
      case 'mod':
      case 'moderator':
      case 'host':
        return 5;
      case 'audience':
      case 'listener':
      case 'speaker':
      case 'guest':
      case 'member':
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
    return role == 'Owner' || role == 'Co-Owner';
  }

  bool isOwner(String roomId, String userId, {VoiceRoom? room}) {
    final r = room ??
        (Get.isRegistered<RoomDiscoveryController>()
            ? RoomDiscoveryController.to.rooms
                .firstWhereOrNull((item) => item.id == roomId)
            : null);
    if (r != null) {
      return (r.ownerUserId.isNotEmpty && r.ownerUserId == userId) ||
          (r.hostId.isNotEmpty && r.hostId == userId);
    }
    return currentPermissions['is_owner'] == true || currentPermissions['is_host'] == true;
  }

  bool isCoOwner(String roomId, String userId, {VoiceRoom? room}) {
    final r = room ??
        (Get.isRegistered<RoomDiscoveryController>()
            ? RoomDiscoveryController.to.rooms
                .firstWhereOrNull((item) => item.id == roomId)
            : null);
    if (r != null) {
      final role = getUserRole(r, userId);
      return role == 'Owner' || role == 'Co-Owner';
    }
    return currentPermissions['is_coowner'] == true || currentPermissions['is_cohost'] == true;
  }

  bool isAdmin(String roomId, String userId, {VoiceRoom? room}) {
    final r = room ??
        (Get.isRegistered<RoomDiscoveryController>()
            ? RoomDiscoveryController.to.rooms
                .firstWhereOrNull((item) => item.id == roomId)
            : null);
    if (r != null) {
      final role = getUserRole(r, userId);
      return role == 'Owner' || role == 'Co-Owner' || role == 'Admin';
    }
    return currentPermissions['is_admin'] == true;
  }

  bool isMod(String roomId, String userId, {VoiceRoom? room}) {
    final r = room ??
        (Get.isRegistered<RoomDiscoveryController>()
            ? RoomDiscoveryController.to.rooms
                .firstWhereOrNull((item) => item.id == roomId)
            : null);
    if (r != null) {
      final role = getUserRole(r, userId);
      return role == 'Owner' || role == 'Co-Owner' || role == 'Admin' || role == 'Mod';
    }
    return currentPermissions['is_mod'] == true || currentPermissions['is_moderator'] == true;
  }

  // Backward compatibility alias methods
  bool isHost(String roomId, String userId, {VoiceRoom? room}) => isOwner(roomId, userId, room: room);
  bool isCoHost(String roomId, String userId, {VoiceRoom? room}) => isCoOwner(roomId, userId, room: room);
  bool isModerator(String roomId, String userId, {VoiceRoom? room}) => isMod(roomId, userId, room: room);
}
