import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:creania/core/theme.dart';

import '../../../../models/room/room_model.dart';
import '../../../../services/room/room_controller.dart';
import '../../../../services/user/user_profile_cache_manager.dart';
import '../governance/room_governance_dashboard_dialog.dart';

class RoomSettingsManagement {
  static void showGovernanceDashboard(
    BuildContext context,
    String roomId,
    String roomName,
  ) {
    RoomGovernanceDashboardDialog.show(context, roomId: roomId, roomName: roomName);
  }
  static String getRoomUserName(String userId) {
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (userId == 'me' || (currentUid != null && userId == currentUid)) {
      return UserProfileCacheManager.currentUser?.username ?? 'Host';
    }
    final cached = UserProfileCacheManager.getCachedUser(userId);
    if (cached != null) return cached.username;
    return 'User_${userId.substring(0, min(userId.length, 5))}';
  }

  static String getRoomUserAvatar(String userId) {
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (userId == 'me' || (currentUid != null && userId == currentUid)) {
      final avatarUrl = UserProfileCacheManager.currentUser?.avatar;
      if (avatarUrl != null && avatarUrl.isNotEmpty) return avatarUrl;
      return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100';
    }
    final cached = UserProfileCacheManager.getCachedUser(userId);
    if (cached != null && cached.avatar != null && cached.avatar!.isNotEmpty) {
      return cached.avatar!;
    }
    return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100';
  }

  /// Block List Manager Dialog
  static void showBlockListManager(
    BuildContext context,
    String roomId,
    VoiceRoom liveRoom,
    RoomController controller,
  ) {
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF121927),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: Get.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🚫 Arena Block List',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Obx(() {
                final liveR = controller.rooms.firstWhereOrNull((r) => r.id == roomId) ?? liveRoom;

                if (liveR.blockList.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.white38, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'No blocked users in this arena.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return SizedBox(
                  height: 240,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: liveR.blockList.length,
                    itemBuilder: (context, idx) {
                      final blockedId = liveR.blockList[idx];
                      final name = getRoomUserName(blockedId);
                      final detailed = controller.roomBannedUsersDetailed[roomId]?[blockedId];
                      final durationInfo = detailed != null ? ' (${detailed.reason})' : '';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(getRoomUserAvatar(blockedId)),
                        ),
                        title: Text(
                          name,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'ID: ${blockedId.hashCode.abs() % 900000 + 100000}$durationInfo',
                          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          onPressed: () {
                            controller.unbanUser(roomId, blockedId);
                            Get.snackbar(
                              'Unblocked',
                              '$name has been unblocked.',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.green,
                              colorText: Colors.white,
                            );
                          },
                          child: Text(
                            'Unblock',
                            style: GoogleFonts.poppins(
                              color: Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  /// Song List & BGM Manager Sheet
  static void showRoomSongListManager(
    BuildContext context,
    String roomId,
    RoomController controller,
    List<Map<String, String>> currentSongs,
    Function(List<Map<String, String>>) onPlaylistUpdated,
  ) {
    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setStateSheet) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF141A28),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.queue_music_rounded, color: Colors.amberAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Arena Song List (${currentSongs.length})',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                      onPressed: Get.back,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Add Song Track Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent.withValues(alpha: 0.15),
                      side: const BorderSide(color: Colors.amberAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_rounded, color: Colors.amberAccent, size: 18),
                    label: Text(
                      'Add New Song to Arena',
                      style: GoogleFonts.poppins(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () {
                      final titleCtrl = TextEditingController();
                      final artistCtrl = TextEditingController();
                      Get.dialog(
                        Dialog(
                          backgroundColor: const Color(0xFF121927),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Add New Song Track', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: titleCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Song Title',
                                    labelStyle: const TextStyle(color: Colors.white54),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.05),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: artistCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Artist / Singer',
                                    labelStyle: const TextStyle(color: Colors.white54),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.05),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(onPressed: Get.back, child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent),
                                      onPressed: () {
                                        if (titleCtrl.text.trim().isNotEmpty) {
                                          final newSong = {
                                            'title': titleCtrl.text.trim(),
                                            'artist': artistCtrl.text.trim().isNotEmpty ? artistCtrl.text.trim() : 'Creania Audio',
                                            'duration': '3:45',
                                          };
                                          currentSongs.add(newSong);
                                          onPlaylistUpdated(currentSongs);
                                          setStateSheet(() {});
                                          Get.back();
                                          Get.snackbar('Song Added', '${newSong['title']} added to playlist.', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white);
                                        }
                                      },
                                      child: const Text('Add Track', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // Songs List
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: currentSongs.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, i) {
                      final song = currentSongs[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.amberAccent.withValues(alpha: 0.2),
                          child: const Icon(Icons.music_note, color: Colors.amberAccent, size: 18),
                        ),
                        title: Text(
                          song['title'] ?? 'Unknown Track',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${song['artist']} • ${song['duration']}',
                          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.cyanAccent, size: 24),
                              onPressed: () {
                                Get.snackbar('Playing Song 🎵', 'Now playing ${song['title']}', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.purple, colorText: Colors.white);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              onPressed: () {
                                setStateSheet(() {
                                  currentSongs.removeAt(i);
                                  onPlaylistUpdated(currentSongs);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  static bool canAppointRole(VoiceRoom room, String callerUserId, String targetRoleToAssign) {
    final isOwner = room.hostId == callerUserId ||
        room.founderId == callerUserId ||
        callerUserId == 'uid_anurag_101';
    final isCoOwner = room.coOwnerIds.contains(callerUserId);
    final isAdmin = room.adminIds.contains(callerUserId);

    final normRole = targetRoleToAssign.toLowerCase();
    if (normRole.contains('co-owner') || normRole.contains('co owner')) {
      return isOwner; // ONLY Room Owner can appoint Co-Owners!
    } else if (normRole.contains('admin')) {
      return isOwner || isCoOwner; // Owner & Co-Owner can appoint Admins!
    } else if (normRole.contains('star')) {
      return isOwner || isCoOwner || isAdmin; // Owner, Co-Owner & Admin can appoint Star Members!
    }
    return isOwner;
  }

  /// Appoint Role Member Sheet (Filtered to valid candidates, excluding self)
  static void showAppointRoleMemberSheet(
    BuildContext context,
    String roomId,
    String role,
    VoiceRoom room,
    RoomController controller,
  ) {
    final currentUid = Supabase.instance.client.auth.currentUser?.id ?? 'uid_anurag_101';

    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141A28),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Appoint Member as $role',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select an active arena member to grant $role permissions.',
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Obx(() {
              // Filter out caller (no self-appointment), room owner, and existing role holders
              final candidateMems = controller.activeMembers.where((m) {
                if (m.userId == currentUid) return false;
                if (m.userId == room.hostId || m.userId == room.founderId) return false;
                if (role.toLowerCase().contains('co') && room.coOwnerIds.contains(m.userId)) return false;
                if (role.toLowerCase().contains('admin') && (room.adminIds.contains(m.userId) || room.coOwnerIds.contains(m.userId))) return false;
                return true;
              }).toList();

              if (candidateMems.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No eligible active members to appoint.',
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                  ),
                );
              }

              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidateMems.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, i) {
                    final mem = candidateMems[i];
                    final name = getRoomUserName(mem.userId);
                    final avatar = getRoomUserAvatar(mem.userId);

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage(avatar),
                      ),
                      title: Text(
                        name,
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('ID: ${mem.userId}', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        onPressed: () {
                          Get.back();
                          controller.promoteRoomMember(roomId, mem.userId, role);
                          Get.snackbar(
                            'Role Assigned 👑',
                            '$name has been appointed as $role.',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.purpleAccent,
                            colorText: Colors.white,
                          );
                        },
                        child: Text(
                          'Appoint $role',
                          style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  /// Build Role Group Tile for Arena Admin Section
  static Widget buildRoleGroupTile({
    required BuildContext context,
    required String role,
    required List<String> memberIds,
    required Color color,
    required VoiceRoom room,
  }) {
    final count = memberIds.length;
    final firstAvatar = count > 0 ? getRoomUserAvatar(memberIds.first) : null;

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
        ),
        child: Text(
          role,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        count == 0 ? 'None assigned' : '$count ${count == 1 ? 'member' : 'members'}',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (firstAvatar != null)
            CircleAvatar(
              radius: 10,
              backgroundImage: NetworkImage(firstAvatar),
            ),
          if (count > 1)
            Container(
              margin: const EdgeInsets.only(left: -6),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Text(
                '+${count - 1}',
                style: TextStyle(
                  color: color,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
        ],
      ),
      onTap: () {
        showTagMemberList(
          context: context,
          role: role,
          memberIds: memberIds,
          color: color,
          room: room,
        );
      },
    );
  }

  static void showTagMemberList({
    required BuildContext context,
    required String role,
    required List<String> memberIds,
    required Color color,
    required VoiceRoom room,
  }) {
    final currentUid = Supabase.instance.client.auth.currentUser?.id ?? 'uid_anurag_101';
    final canAppoint = canAppointRole(room, currentUid, role);

    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141A28),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${memberIds.length} ${memberIds.length == 1 ? 'member' : 'members'}',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),

                // Appoint button ONLY if role is not Owner AND caller has appointment authority!
                if (role != 'Owner' && canAppoint)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color.withValues(alpha: 0.2),
                      side: BorderSide(color: color),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    icon: Icon(Icons.add, color: color, size: 14),
                    label: Text(
                      'Appoint',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    onPressed: () {
                      Get.back();
                      showAppointRoleMemberSheet(context, room.id, role, room, RoomController.to);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),

            if (memberIds.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No $role assigned yet.',
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: memberIds.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, i) {
                    final uid = memberIds[i];
                    final name = getRoomUserName(uid);
                    final avatar = getRoomUserAvatar(uid);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(avatar),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'ID: ${uid.hashCode.abs() % 900000 + 100000}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                      onTap: () {
                        Get.back();
                        showRoomMemberMiniProfile(context, uid, name, role, room);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  static void showRoomMemberMiniProfile(
    BuildContext context,
    String userId,
    String name,
    String currentRole,
    VoiceRoom room,
  ) {
    final String currentUserId = Supabase.instance.client.auth.currentUser?.id ?? 'uid_anurag_101';
    final bool isOwner = currentUserId == room.hostId || currentUserId == room.founderId;
    final bool isSelf = userId == currentUserId;
    final controller = RoomController.to;

    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141A28),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(getRoomUserAvatar(userId)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.4), width: 0.8),
                            ),
                            child: Text(
                              currentRole,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ID: ${userId.hashCode.abs() % 900000 + 100000}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniProfileStat(context, 'Level 18', 'Gamification'),
                _miniProfileStat(context, '34,500', 'Gifts Received'),
                _miniProfileStat(context, 'Active Host', 'Badge'),
              ],
            ),
            const SizedBox(height: 20),

            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 16),

            if (isOwner && !isSelf) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MANAGE ARENA ROLE',
                  style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),

              _actionTile(
                context: context,
                icon: Icons.star_rounded,
                color: Colors.amber,
                label: currentRole == 'Co-owner' ? 'Demote from Co-owner' : 'Make Co-owner',
                onTap: () {
                  Get.back();
                  controller.promoteRoomMember(
                    room.id,
                    userId,
                    currentRole == 'Co-owner' ? 'Speaker' : 'Co-owner',
                  );
                  Get.snackbar(
                    'Role Updated',
                    '$name is now ${currentRole == 'Co-owner' ? 'a Speaker' : 'a Co-owner'}.',
                    backgroundColor: Colors.purpleAccent,
                    colorText: Colors.white,
                  );
                },
              ),

              _actionTile(
                context: context,
                icon: Icons.security_rounded,
                color: Colors.purpleAccent,
                label: currentRole == 'Admin' ? 'Demote from Admin' : 'Make Admin',
                onTap: () {
                  Get.back();
                  controller.promoteRoomMember(
                    room.id,
                    userId,
                    currentRole == 'Admin' ? 'Speaker' : 'Admin',
                  );
                  Get.snackbar(
                    'Role Updated',
                    '$name is now ${currentRole == 'Admin' ? 'a Speaker' : 'an Admin'}.',
                    backgroundColor: Colors.purpleAccent,
                    colorText: Colors.white,
                  );
                },
              ),

              _actionTile(
                context: context,
                icon: Icons.gavel_rounded,
                color: Colors.redAccent,
                label: 'Kick from Arena',
                onTap: () {
                  Get.back();
                  Get.snackbar(
                    'Kicked User',
                    '$name has been kicked from the arena.',
                    backgroundColor: Colors.redAccent,
                    colorText: Colors.white,
                  );
                },
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No management actions available for this user.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _miniProfileStat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  static Widget _actionTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 16),
    );
  }
}
