import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/room/room_model.dart';
import '../user/user_profile_cache_manager.dart';

class RoomModerationController extends GetxController {
  static RoomModerationController get to => Get.find<RoomModerationController>();

  final RxMap<String, List<String>> mutedUsers = <String, List<String>>{}.obs;
  final RxMap<String, List<String>> mutedChatUsers =
      <String, List<String>>{}.obs;
  final RxMap<String, List<String>> bannedUsers = <String, List<String>>{}.obs;

  final RxMap<String, Map<String, Map<String, dynamic>>>
      roomBannedUsersDetailed =
      <String, Map<String, Map<String, dynamic>>>{}.obs;

  Future<void> moderateMuteUser(
    String roomId,
    String userId,
    bool mute, {
    required List<VoiceRoom> rooms,
    required Function(String, String, String) onEmitActivity,
  }) async {
    try {
      final currentUserId = UserProfileCacheManager.currentUserId;
      final room = rooms.firstWhereOrNull((r) => r.id == roomId);
      if (room == null) return;

      if (room.hostId != currentUserId &&
          room.coOwnerIds.contains(currentUserId) != true &&
          room.moderatorIds.contains(currentUserId) != true) {
        throw Exception(
            'Only Room Host, Co-Owners, and Admins can mute members.');
      }

      await Supabase.instance.client.rpc('moderate_mute_user', params: {
        'p_room_id': roomId,
        'p_target_user_id': userId,
        'p_mute': mute,
      });

      final targetProfile =
          await UserProfileCacheManager.fetchUserProfile(userId);
      final targetName = targetProfile?.username ?? 'Member';

      if (mutedUsers[roomId] == null) mutedUsers[roomId] = [];
      if (mute) {
        if (!mutedUsers[roomId]!.contains(userId)) {
          mutedUsers[roomId]!.add(userId);
        }
      } else {
        mutedUsers[roomId]!.remove(userId);
      }

      final message = mute
          ? '🔇 $targetName was muted by a moderator.'
          : '🔊 $targetName was unmuted.';

      await onEmitActivity(
        mute ? 'user_muted' : 'user_unmuted',
        userId,
        message,
      );
    } catch (e) {
      Get.snackbar(
        'Action Failed',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  Future<void> moderateKickUser(
    String roomId,
    String userId, {
    required List<VoiceRoom> rooms,
    required List<RoomMember> activeMembers,
    required Function(String, String, String) onEmitActivity,
  }) async {
    try {
      final currentUserId = UserProfileCacheManager.currentUserId;
      final room = rooms.firstWhereOrNull((r) => r.id == roomId);
      if (room == null) return;

      if (room.hostId != currentUserId &&
          room.coOwnerIds.contains(currentUserId) != true &&
          room.moderatorIds.contains(currentUserId) != true) {
        throw Exception(
            'Only Room Host, Co-Owners, and Admins can kick members.');
      }

      final targetMember =
          activeMembers.firstWhereOrNull((m) => m.userId == userId);
      final targetRole = targetMember?.role ?? 'Guest';

      final callerMember =
          activeMembers.firstWhereOrNull((m) => m.userId == currentUserId);
      final callerRole = callerMember?.role ?? 'Guest';

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
          default:
            return 1;
        }
      }

      if (getRoleWeight(callerRole) <= getRoleWeight(targetRole)) {
        throw Exception(
            'You cannot kick a member with equal or higher authority.');
      }

      await Supabase.instance.client.rpc('moderate_kick_user', params: {
        'p_room_id': roomId,
        'p_target_user_id': userId,
      });

      final targetProfile =
          await UserProfileCacheManager.fetchUserProfile(userId);
      final targetName = targetProfile?.username ?? 'Member';

      await onEmitActivity(
        'user_kicked',
        userId,
        '🥾 $targetName was kicked out of the room.',
      );
    } catch (e) {
      Get.snackbar(
        'Action Failed',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  Future<void> moderateBanUser(
    String roomId,
    String userId,
    String reason, {
    String? duration,
  }) async {
    try {
      await Supabase.instance.client.rpc('moderate_ban_user', params: {
        'p_room_id': roomId,
        'p_target_user_id': userId,
        'p_reason': reason,
        'p_duration': duration ?? '24_hours',
      });

      if (bannedUsers[roomId] == null) bannedUsers[roomId] = [];
      if (!bannedUsers[roomId]!.contains(userId)) {
        bannedUsers[roomId]!.add(userId);
      }

      Get.snackbar(
        'Member Banned 🚫',
        'User was banned from room.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Action Failed', e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> toggleMuteUser(String roomId, String userId, {List<VoiceRoom> rooms = const []}) async {
    final isMuted = mutedUsers[roomId]?.contains(userId) == true;
    await moderateMuteUser(roomId, userId, !isMuted, rooms: rooms, onEmitActivity: (_, __, ___) {});
  }

  Future<void> toggleMuteUserChat(String roomId, String userId) async {
    if (mutedChatUsers[roomId] == null) mutedChatUsers[roomId] = [];
    if (mutedChatUsers[roomId]!.contains(userId)) {
      mutedChatUsers[roomId]!.remove(userId);
    } else {
      mutedChatUsers[roomId]!.add(userId);
    }
  }

  Future<void> banUserWithDuration(
    String roomId,
    String userId,
    String reason, [
    String duration = '24_hours',
  ]) async {
    await moderateBanUser(roomId, userId, reason, duration: duration);
  }

  Future<void> unbanUser(String roomId, String userId) async {
    try {
      await Supabase.instance.client.rpc('moderate_unban_user', params: {
        'p_room_id': roomId,
        'p_target_user_id': userId,
      });
      bannedUsers[roomId]?.remove(userId);
      roomBannedUsersDetailed[roomId]?.remove(userId);
    } catch (e) {
      debugPrint('Error unbanning user: $e');
    }
  }

  Future<void> updateRoomSettings(
    String roomId, {
    String? name,
    String? bulletin,
    String? greetings,
    String? theme,
    String? whoCanJoin,
    String? whoCanSpeak,
    String? seatPermissions,
    List<String>? wordFilter,
    bool? muteAll,
    String? avatar,
    String? banner,
    String? roomCoverUrl,
    bool? coHostCanEditCover,
    bool? adminCanEditCover,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (bulletin != null) updates['bulletin'] = bulletin;
      if (greetings != null) updates['greetings'] = greetings;
      if (theme != null) updates['room_theme'] = theme;
      if (whoCanJoin != null) updates['who_can_join'] = whoCanJoin;
      if (whoCanSpeak != null) updates['who_can_speak'] = whoCanSpeak;
      if (seatPermissions != null) updates['seat_permissions'] = seatPermissions;
      if (wordFilter != null) updates['word_filter'] = wordFilter;
      if (muteAll != null) updates['mute_all'] = muteAll;
      if (avatar != null) updates['avatar'] = avatar;
      if (banner != null) updates['banner'] = banner;
      if (roomCoverUrl != null) updates['room_cover_url'] = roomCoverUrl;
      if (coHostCanEditCover != null) updates['cohost_can_edit_cover'] = coHostCanEditCover;
      if (adminCanEditCover != null) updates['admin_can_edit_cover'] = adminCanEditCover;

      if (updates.isNotEmpty) {
        await Supabase.instance.client.from('rooms').update(updates).eq('id', roomId);
      }
    } catch (e) {
      debugPrint('Error updating room settings: $e');
    }
  }

  Future<void> transferHost(String roomId, String newHostId) async {
    try {
      await Supabase.instance.client.rpc('transfer_room_host', params: {
        'p_room_id': roomId,
        'p_new_host_id': newHostId,
      });
    } catch (e) {
      debugPrint('Error transferring room host: $e');
    }
  }

  Future<void> changeMemberRole(
    String roomId,
    String userId,
    String newRole,
  ) async {
    try {
      await Supabase.instance.client.rpc('promote_room_member_role', params: {
        'p_room_id': roomId,
        'p_target_user_id': userId,
        'p_new_role': newRole,
      });
    } catch (e) {
      debugPrint('Error changing member role: $e');
    }
  }

  Future<bool> promoteRoomMember(String roomId, String userId, String targetRole) =>
      promoteRoomMemberRole(roomId, userId, targetRole);

  Future<bool> promoteRoomMemberRole(
    String roomId,
    String userId,
    String targetRole,
  ) async {
    try {
      await changeMemberRole(roomId, userId, targetRole);

      Get.snackbar(
        'Role Updated 🎉',
        'User assigned to $targetRole.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981).withOpacity(0.9),
        colorText: Colors.white,
      );
      return true;
    } catch (e) {
      Get.snackbar('Promotion Failed', e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> demoteRoomMemberRole(
    String roomId,
    String userId, [
    String? currentRole,
  ]) async {
    try {
      await Supabase.instance.client.rpc('demote_room_member_role', params: {
        'p_room_id': roomId,
        'p_target_user_id': userId,
      });
      Get.snackbar(
        'Role Demoted 👤',
        'User demoted to Audience.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orangeAccent.withOpacity(0.9),
        colorText: Colors.white,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> transferRoomOwnership(
    String roomId,
    String newOwnerUserId,
  ) async {
    try {
      await transferHost(roomId, newOwnerUserId);
      Get.snackbar(
        'Ownership Transferred 👑',
        'Room ownership was successfully transferred.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.9),
        colorText: Colors.white,
      );
      return true;
    } catch (e) {
      Get.snackbar('Transfer Failed', e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<void> endRoom(String roomId, {required Function() onLeaveLocal}) async {
    try {
      await Supabase.instance.client.rpc('end_room', params: {
        'p_room_id': roomId,
      });
      onLeaveLocal();
      Get.snackbar(
        'Room Ended',
        'The host has ended this room session.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.shade700,
        colorText: Colors.white,
      );
    } catch (e) {
      debugPrint('Error ending room: $e');
    }
  }

  String resolveRoomUuid(String roomId, List<VoiceRoom> rooms) {
    if (roomId.contains('-')) return roomId;
    final r = rooms.firstWhereOrNull((room) => room.id == roomId);
    return r?.id ?? roomId;
  }
}
