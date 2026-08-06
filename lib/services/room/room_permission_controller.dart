import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/room/room_model.dart';

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
    return currentPermissions[action] == true;
  }

  String getUserRole(VoiceRoom room, String userId) {
    if (room.hostId == userId) return 'Owner';
    if (room.founderId == userId) return 'Founder';
    if (room.coOwnerIds.contains(userId) == true) return 'Co-Owner';
    if (room.moderatorIds.contains(userId) == true) return 'Admin';
    if (room.speakerIds.contains(userId) == true) return 'Speaker';
    return 'Guest';
  }

  int getRoleWeight(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
      case 'founder':
        return 10;
      case 'co-owner':
      case 'co-host':
        return 9;
      case 'admin':
      case 'moderator':
        return 8;
      case 'speaker':
        return 5;
      case 'listener':
      case 'guest':
      default:
        return 1;
    }
  }

  bool isHost(String roomId, String userId, {VoiceRoom? room}) {
    if (room != null) {
      return room.hostId == userId || room.founderId == userId;
    }
    return currentPermissions['is_host'] == true;
  }

  bool isCoHost(String roomId, String userId, {VoiceRoom? room}) {
    if (room != null) {
      return room.coOwnerIds.contains(userId) == true;
    }
    return currentPermissions['is_cohost'] == true;
  }

  bool isModerator(String roomId, String userId, {VoiceRoom? room}) {
    if (room != null) {
      return room.moderatorIds?.contains(userId) == true;
    }
    return currentPermissions['is_moderator'] == true;
  }
}
