import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

import '../../../../models/room/room_model.dart';
import '../../../../services/room/room_controller.dart';
import '../../../../services/voice/voice_controller.dart';
import '../../../../services/user/user_profile_cache_manager.dart';
import '../../../../widgets/user_tags/user_badge_widgets.dart';
import '../../../../widgets/profile/custom_avatar_frame.dart';
import '../../../../widgets/common/optimized_image.dart';
import 'mini_profile_dialog.dart';

class OnlineMembersDialog extends StatelessWidget {
  final String roomId;
  final VoiceRoom room;
  const OnlineMembersDialog(
      {required this.roomId, required this.room, Key? key})
      : super(key: key);

  void _handleViewProfile(String userId, String name, String role) {
    Get.back(); // Dismiss OnlineMembersDialog
    final occupiedSeats = (RoomController.to.roomSeatsInfo[roomId] ?? [])
        .where((s) => s['userId'] != null)
        .length;

    Get.dialog(
      MiniProfileDialog(
        roomId: roomId,
        callerUserId: RoomController.currentUserId,
        targetUserId: userId,
        targetUserName: name,
        role: role,
        seatIndex: -1,
        isHost: room.hostId == RoomController.currentUserId ||
            room.founderId == RoomController.currentUserId,
        occupiedSeatsCount: occupiedSeats,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: Get.width * 0.92,
        height: 520,
        decoration: BoxDecoration(
          color: const Color(0xFF121927),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 16,
              spreadRadius: 2,
            )
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.remove_red_eye_rounded,
                          color: Colors.cyanAccent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Arena Members',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Obx(() {
                          final activeMems = RoomController.to.activeMembers;
                          final count = activeMems.isNotEmpty
                              ? activeMems.length
                              : VoiceController.to.roomUsers.length;
                          return Text(
                            '$count Users Currently Online',
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Get.back(),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                        color: Colors.white10, shape: BoxShape.circle),
                    child: const Icon(Icons.close,
                        color: Colors.white70, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Obx(
                () {
                  // DB active members is the primary Single Source of Truth (SSOT)
                  final Map<String, dynamic> userMap = {};
                  final dbMembers = RoomController.to.activeMembers;

                  if (dbMembers.isNotEmpty) {
                    for (final m in dbMembers) {
                      final profile =
                          UserProfileCacheManager.getCachedUser(m.userId);
                      final voiceUser = VoiceController.to.roomUsers
                          .firstWhereOrNull((u) => u.userID == m.userId);
                      userMap[m.userId] = voiceUser ??
                          ZegoUser(m.userId, profile?.username ?? 'Member');
                    }
                  } else {
                    for (final u in VoiceController.to.roomUsers) {
                      userMap[u.userID] = u;
                    }
                  }

                  final users = userMap.values.toList();
                  if (users.isEmpty) {
                    return Center(
                      child: Text('No users live in room',
                          style: GoogleFonts.poppins(
                              color: Colors.white54, fontSize: 13)),
                    );
                  }

                  // Sort members by hierarchy: Owner -> Co-Owner/Admin -> Star Member -> Speaker -> Member
                  final sortedUsers = List<dynamic>.from(users);
                  sortedUsers.sort((a, b) {
                    final roleA = RoomController.to.getUserRole(room, a.userID);
                    final roleB = RoomController.to.getUserRole(room, b.userID);
                    final weightA = RoomController.to.getRoleWeight(roleA);
                    final weightB = RoomController.to.getRoleWeight(roleB);
                    return weightB.compareTo(weightA);
                  });

                  return ListView.builder(
                    itemCount: sortedUsers.length,
                    itemBuilder: (context, index) {
                      final u = sortedUsers[index];
                      final role =
                          RoomController.to.getUserRole(room, u.userID);

                      final seatsList =
                          RoomController.to.roomSeatsInfo[roomId] ?? [];
                      final seatIndex =
                          seatsList.indexWhere((s) => s['userId'] == u.userID);
                      final isSpeaking = seatIndex != -1 &&
                          seatsList[seatIndex]['isSpeaking'] == true;

                      return Obx(() {
                        final _ = UserProfileCacheManager.rxCache.length;
                        final profile =
                            UserProfileCacheManager.rxCache[u.userID] ??
                                UserProfileCacheManager.getCachedUser(u.userID);
                        final name = profile?.username ?? u.userName;
                        final avatarUrl = profile?.avatar ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              CustomAvatarFrame(
                                userId: u.userID,
                                username: name,
                                size: 40,
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundImage: avatarUrl.isNotEmpty
                                      ? OptimizedImage.getOptimizedImageProvider(avatarUrl)
                                      : null,
                                  child: avatarUrl.isEmpty
                                      ? const Icon(Icons.person,
                                          size: 18, color: Colors.white70)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isSpeaking) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.mic,
                                              color: Color(0xFF00FF66),
                                              size: 12),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'ID: ${profile?.sid != null && profile!.sid.isNotEmpty ? profile.sid : (u.userID.hashCode.abs() % 900000 + 100000)}',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white38,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    UserBadgeRow(
                                       user: profile,
                                       roomRole: role,
                                       showRoleTag: true,
                                       maxWidth: 240,
                                     ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (u.userID != RoomController.currentUserId)
                                    IconButton(
                                      icon: const Icon(
                                          Icons.person_add_alt_1_rounded,
                                          color: Colors.pinkAccent,
                                          size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        Get.snackbar(
                                            'Followed', 'You followed @$name',
                                            snackPosition:
                                                SnackPosition.BOTTOM);
                                      },
                                    ),
                                  const SizedBox(width: 8),
                                  // Profile & Role management button
                                  IconButton(
                                    icon: const Icon(
                                        Icons.manage_accounts_rounded,
                                        color: Colors.cyanAccent,
                                        size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Manage Member & Profile',
                                    onPressed: () => _handleViewProfile(
                                        u.userID, name, role),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Get.back(),
                child: Text('Close',
                    style: GoogleFonts.poppins(
                        color: Colors.white54, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
