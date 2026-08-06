import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:creania/core/theme.dart';

import '../../../../models/room/room_model.dart';
import '../../../../services/room/room_controller.dart';
import '../../../../services/user/user_profile_cache_manager.dart';
import '../../../../widgets/index.dart';
import 'mini_profile_dialog.dart';

class RoomSettingsManagement {
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

  static void showBlockListManager(
      BuildContext context, String roomId, VoiceRoom liveRoom, RoomController controller) {
    Get.dialog(
      AlertDialog(
        backgroundColor: context.secondaryBackgroundColor,
        title: const Text('Block List Manager',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: Obx(() {
            final liveR = controller.rooms
                    .firstWhereOrNull((r) => r.id == roomId) ??
                liveRoom;

            if (liveR.blockList.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('No blocked users in this arena.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.caption)),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: liveR.blockList.length,
              itemBuilder: (context, idx) {
                final blockedId = liveR.blockList[idx];
                final name = getRoomUserName(blockedId);
                final detailed = controller
                    .roomBannedUsersDetailed[roomId]?[blockedId];
                final durationInfo =
                    detailed != null ? ' (${detailed['duration']})' : '';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundImage:
                        NetworkImage(getRoomUserAvatar(blockedId)),
                  ),
                  title: Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  subtitle: Text(
                      'ID: ${blockedId.hashCode.abs() % 900000 + 100000}$durationInfo',
                      style: TextStyle(color: context.caption, fontSize: 11)),
                  trailing: TextButton(
                    onPressed: () {
                      controller.unbanUser(roomId, blockedId);
                    },
                    child: const Text('Unblock',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                );
              },
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close', style: TextStyle(color: context.caption)),
          ),
        ],
      ),
    );
  }

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
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.35), width: 0.8),
        ),
        child: Text(
          role,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        count == 0
            ? 'None assigned'
            : '$count ${count == 1 ? 'member' : 'members'}',
        style: const TextStyle(
            color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w400),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (firstAvatar != null)
            CircleAvatar(
                radius: 10, backgroundImage: NetworkImage(firstAvatar)),
          if (count > 1)
            Container(
              margin: const EdgeInsets.only(left: -6),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Text(
                '+${count - 1}',
                style: TextStyle(
                    color: color, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
        ],
      ),
      onTap: count == 0
          ? null
          : () => showTagMemberList(
              context: context, role: role, memberIds: memberIds, color: color, room: room),
    );
  }

  static void showTagMemberList({
    required BuildContext context,
    required String role,
    required List<String> memberIds,
    required Color color,
    required VoiceRoom room,
  }) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: context.secondaryBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: color.withOpacity(0.4), width: 0.8),
                  ),
                  child: Text(role,
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Text(
                  '${memberIds.length} ${memberIds.length == 1 ? 'member' : 'members'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: memberIds.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white10, height: 1),
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
                    title: Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'ID: ${uid.hashCode.abs() % 900000 + 100000}',
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        color: Colors.white24, size: 14),
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

  static Widget buildAdminTile({
    required BuildContext context,
    required String userId,
    required String role,
    required String name,
    required String avatarUrl,
    required VoiceRoom room,
  }) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(role,
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 10, backgroundImage: NetworkImage(avatarUrl)),
          const SizedBox(width: 8),
          Text(name,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
        ],
      ),
      onTap: () => showRoomMemberMiniProfile(context, userId, name, role, room),
    );
  }

  static void showRoomMemberMiniProfile(
      BuildContext context, String userId, String name, String currentRole, VoiceRoom room) {
    final String currentUserId =
        Supabase.instance.client.auth.currentUser?.id ?? 'uid_anurag_101';
    final bool isOwner = currentUserId == room.hostId ||
        currentUserId == room.founderId;
    final bool isSelf = userId == currentUserId;
    final controller = RoomController.to;

    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: context.secondaryBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                color: context.borderColor,
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
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: Colors.blue.withOpacity(0.4),
                                  width: 0.8),
                            ),
                            child: Text(currentRole,
                                style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text('ID: ${userId.hashCode.abs() % 900000 + 100000}',
                              style: TextStyle(
                                  color: context.caption, fontSize: 12)),
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

            Divider(color: context.borderColor, height: 1),
            const SizedBox(height: 16),

            if (isOwner && !isSelf) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text('MANAGE ARENA ROLE',
                    style: TextStyle(
                        color: context.caption,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),

              _actionTile(
                context: context,
                icon: Icons.star_rounded,
                color: Colors.amber,
                label: currentRole == 'Co-owner'
                    ? 'Demote from Co-owner'
                    : 'Make Co-owner',
                onTap: () {
                  Get.back();
                  controller.promoteRoomMember(room.id, userId,
                      currentRole == 'Co-owner' ? 'Speaker' : 'Co-owner');
                  Get.snackbar('Role Updated',
                      '$name is now ${currentRole == 'Co-owner' ? 'a Speaker' : 'a Co-owner'}.',
                      backgroundColor: context.primaryColor.withOpacity(0.9),
                      colorText: Colors.white);
                },
              ),

              _actionTile(
                context: context,
                icon: Icons.security_rounded,
                color: Colors.purpleAccent,
                label:
                    currentRole == 'Admin' ? 'Demote from Admin' : 'Make Admin',
                onTap: () {
                  Get.back();
                  controller.promoteRoomMember(room.id, userId,
                      currentRole == 'Admin' ? 'Speaker' : 'Admin');
                  Get.snackbar('Role Updated',
                      '$name is now ${currentRole == 'Admin' ? 'a Speaker' : 'an Admin'}.',
                      backgroundColor: context.primaryColor.withOpacity(0.9),
                      colorText: Colors.white);
                },
              ),

              _actionTile(
                context: context,
                icon: Icons.gavel_rounded,
                color: context.errorColor,
                label: 'Kick from Arena',
                onTap: () {
                  Get.back();
                  Get.snackbar(
                      'Kicked User', '$name has been kicked from the arena.',
                      backgroundColor: context.errorColor.withOpacity(0.9),
                      colorText: Colors.white);
                },
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No management actions available for this user.',
                    style: TextStyle(color: context.caption, fontSize: 13)),
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
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: context.caption, fontSize: 11)),
      ],
    );
  }

  static Widget _actionTile(
      {required BuildContext context,
      required IconData icon,
      required Color color,
      required String label,
      required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      trailing:
          Icon(Icons.chevron_right_rounded, color: context.caption, size: 16),
    );
  }
}
