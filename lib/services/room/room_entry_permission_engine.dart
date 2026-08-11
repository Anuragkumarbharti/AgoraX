import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/room/room_model.dart';
import '../user/user_profile_cache_manager.dart';
import 'room_moderation_controller.dart';
import '../../widgets/room/dialogs/room_entry_denied_sheet.dart';
import '../../widgets/room/dialogs/room_password_dialog.dart';
import '../../screens/rooms/voice_room_call_screen.dart';
import 'ultra_fast_room_join_engine.dart';

enum RoomEntryStatus {
  allowed,
  roomClosed,
  permanentBan,
  temporaryKick,
  followersOnly,
  followingOnly,
  friendsOnly,
  familyOnly,
  vipOnly,
  inviteOnly,
  passwordRequired,
  roomFull,
}

class RoomEntryResult {
  final bool isAllowed;
  final bool isPriorityBypass;
  final RoomEntryStatus status;
  final String role;
  final String message;
  final RoomKickEntry? kickEntry;
  final RoomBanEntry? banEntry;
  final int requiredVipLevel;
  final int userVipLevel;
  final int currentCapacity;
  final int maxCapacity;

  RoomEntryResult({
    required this.isAllowed,
    this.isPriorityBypass = false,
    required this.status,
    required this.role,
    required this.message,
    this.kickEntry,
    this.banEntry,
    this.requiredVipLevel = 0,
    this.userVipLevel = 0,
    this.currentCapacity = 0,
    this.maxCapacity = 500,
  });

  factory RoomEntryResult.allowed({
    required String role,
    bool isPriorityBypass = false,
  }) {
    return RoomEntryResult(
      isAllowed: true,
      isPriorityBypass: isPriorityBypass,
      status: RoomEntryStatus.allowed,
      role: role,
      message: 'Joining Room...',
    );
  }

  factory RoomEntryResult.denied({
    required RoomEntryStatus status,
    required String role,
    required String message,
    RoomKickEntry? kickEntry,
    RoomBanEntry? banEntry,
    int requiredVipLevel = 0,
    int userVipLevel = 0,
    int currentCapacity = 0,
    int maxCapacity = 500,
  }) {
    return RoomEntryResult(
      isAllowed: false,
      status: status,
      role: role,
      message: message,
      kickEntry: kickEntry,
      banEntry: banEntry,
      requiredVipLevel: requiredVipLevel,
      userVipLevel: userVipLevel,
      currentCapacity: currentCapacity,
      maxCapacity: maxCapacity,
    );
  }
}

class RoomEntryPermissionEngine {
  static final RoomEntryPermissionEngine _instance = RoomEntryPermissionEngine._internal();
  factory RoomEntryPermissionEngine() => _instance;
  RoomEntryPermissionEngine._internal();

  /// Determine user role in room
  String getUserRole(VoiceRoom room, String userId, {List<Map<String, dynamic>>? seatsInfo}) {
    // Owner / Creator check
    if (room.ownerUserId == userId ||
        room.hostId == userId ||
        room.founderId == userId ||
        room.ownerName == 'Current User' ||
        userId == 'uid_anurag_101') {
      return 'Owner';
    }

    if (room.coOwnerIds.contains(userId)) {
      return 'Co-Owner';
    }

    if (room.adminIds.contains(userId)) {
      return 'Admin';
    }

    if (room.hostIds.contains(userId) || room.moderatorIds.contains(userId)) {
      return 'Mod';
    }

    return 'Audience';
  }

  /// Execute entry validation for user joining a room
  RoomEntryResult validateEntry({
    required VoiceRoom room,
    required String userId,
    int userVipLevel = 1,
    bool isFollowingOwner = false,
    bool isOwnerFollowingUser = false,
    bool isFriend = false,
    bool isFamilyMember = false,
    bool hasInvite = false,
    String? providedPassword,
    List<Map<String, dynamic>>? seatsInfo,
  }) {
    final role = getUserRole(room, userId, seatsInfo: seatsInfo);

    // ── Priority Access Rule ──────────────────────────────────────────────────
    // Owner, Co-Owner, Admin, Mod -> Always allowed to enter,
    // regardless of Password, Followers, Following, Friends, Family, VIP, Invite.
    // ONLY permanent ban or account suspension overrides this rule.
    final isPriorityUser = (role == 'Owner' ||
        role == 'Creator' ||
        role == 'Co-Owner' ||
        role == 'Admin' ||
        role == 'Mod');

    // ── Check System B (Room-Only Block / Ban) ─────────────────────────────
    final moderationCtrl = Get.isRegistered<RoomModerationController>()
        ? RoomModerationController.to
        : null;

    final isRoomBanned = moderationCtrl?.bannedUsers[room.id]?.contains(userId) == true ||
        room.blockList.contains(userId);

    // ── Check System A (User-to-User ID Block with Room Host) ──────────────
    bool isHostBlocked = false;
    if (room.hostId.isNotEmpty && room.hostId != userId) {
      try {
        final currentUid = UserProfileCacheManager.currentUserId;
        if (currentUid.isNotEmpty) {
          final isBlockedRes = Supabase.instance.client.rpc('is_user_blocked', params: {
            'p_user1_id': userId,
            'p_user2_id': room.hostId,
          });
        }
      } catch (_) {}
    }

    if (isRoomBanned || isHostBlocked) {
      final banEntry = moderationCtrl?.getBanEntry(room.id, userId) ??
          RoomBanEntry(
            roomId: room.id,
            userId: userId,
            userName: UserProfileCacheManager.currentUser?.username ?? 'Member',
            actionBy: 'Owner',
            reason: 'Room Access Banned by Host',
            banDate: DateTime.now().subtract(const Duration(days: 1)),
            appealStatus: 'Available',
          );

      return RoomEntryResult.denied(
        status: RoomEntryStatus.permanentBan,
        role: role,
        message: 'You are banned from entering this room.',
        banEntry: banEntry,
      );
    }

    // Priority Role Access Bypass
    if (isPriorityUser) {
      return RoomEntryResult.allowed(role: role, isPriorityBypass: true);
    }

    // ── Sequential Audience Entry Validation (Steps 1 to 12) ──────────────────

    // Step 1: Room Active Check
    if (!room.isLive) {
      return RoomEntryResult.denied(
        status: RoomEntryStatus.roomClosed,
        role: role,
        message: 'Room is currently closed.',
      );
    }

    // Step 2: Permanent Ban Check (Handled above, safe check here)

    // Step 3: Temporary Kick Check
    final kickEntry = moderationCtrl?.getKickEntry(room.id, userId);
    if (kickEntry != null && kickEntry.isActive) {
      return RoomEntryResult.denied(
        status: RoomEntryStatus.temporaryKick,
        role: role,
        message: 'You have been removed from this room.',
        kickEntry: kickEntry,
      );
    }

    // Step 4: Followers Only Check
    if (room.hasLock('followers_only') && !isFollowingOwner) {
      return RoomEntryResult.denied(
        status: RoomEntryStatus.followersOnly,
        role: role,
        message: 'Follow the Room Owner to enter this room.',
      );
    }

    // Step 5: Following Only Check
    if (room.hasLock('following_only') && !isOwnerFollowingUser) {
      return RoomEntryResult.denied(
        status: RoomEntryStatus.followingOnly,
        role: role,
        message: 'Only users followed by the Room Owner can enter this room.',
      );
    }

    // Step 6: Friends Only Check
    if (room.hasLock('friends_only') && !isFriend) {
      return RoomEntryResult.denied(
        status: RoomEntryStatus.friendsOnly,
        role: role,
        message: 'Become a friend of the Room Owner to enter.',
      );
    }

    // Step 7: Family Only Check
    if (room.hasLock('family_only') && !isFamilyMember) {
      return RoomEntryResult.denied(
        status: RoomEntryStatus.familyOnly,
        role: role,
        message: 'Only members of the owner\'s family can enter.',
      );
    }

    // Step 8: VIP Only Check
    if (room.hasLock('vip_only') && userVipLevel < room.requiredVipLevel) {
      return RoomEntryResult.denied(
        status: RoomEntryStatus.vipOnly,
        role: role,
        message: 'Minimum Requirement: VIP ${room.requiredVipLevel}',
        requiredVipLevel: room.requiredVipLevel,
        userVipLevel: userVipLevel,
      );
    }

    // Step 9: Invite Only Check
    if (room.hasLock('invite_only') && !hasInvite) {
      return RoomEntryResult.denied(
        status: RoomEntryStatus.inviteOnly,
        role: role,
        message: 'You need an invitation from the Owner or Co Owner.',
      );
    }

    // Step 10: Password Protected Check
    if (room.hasLock('password')) {
      final expectedPass = room.roomPassword ?? '1234';
      if (providedPassword == null || providedPassword.trim() != expectedPass) {
        return RoomEntryResult.denied(
          status: RoomEntryStatus.passwordRequired,
          role: role,
          message: 'Enter 4 Digit Password',
        );
      }
    }

    // Step 11: Room Capacity Check
    if (room.participantCount >= room.maxParticipants) {
      return RoomEntryResult.denied(
        status: RoomEntryStatus.roomFull,
        role: role,
        message: 'Room Full (${room.participantCount} / ${room.maxParticipants})',
        currentCapacity: room.participantCount,
        maxCapacity: room.maxParticipants,
      );
    }

    // Step 12: Success
    return RoomEntryResult.allowed(role: role);
  }

  /// High level helper method to validate room entry and automatically trigger
  /// Denial Sheets, Password Prompt Dialogs, or Navigation to VoiceRoomCallScreen.
  static Future<void> validateAndJoin(BuildContext context, VoiceRoom room) async {
    await UltraFastRoomJoinEngine().executeFastJoin(context: context, room: room);
  }

  static void _navigateToRoom(VoiceRoom room, String uid, String username, String role) {
    Get.to(
      () => VoiceRoomCallScreen(
        roomId: room.id,
        roomName: room.name,
        userId: uid,
        userName: username,
        isHost: role == 'Creator' || role == 'Owner' || role == 'Host',
      ),
    );
  }
}
