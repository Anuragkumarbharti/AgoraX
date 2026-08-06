import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zego_express_engine/zego_express_engine.dart' hide Text;

import '../../../../models/room/room_model.dart';
import '../../../../services/room/room_controller.dart';
import '../../../../services/room/room_seat_controller.dart';
import '../../../../services/voice/voice_controller.dart';
import '../../../../services/user/user_profile_cache_manager.dart';
import '../../../../widgets/index.dart';
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
                          final count = max(
                            RoomController.to.activeMembers.length,
                            VoiceController.to.roomUsers.length,
                          );
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
                  // Merge active members from RoomController and VoiceController
                  final Map<String, dynamic> userMap = {};

                  for (final u in VoiceController.to.roomUsers) {
                    userMap[u.userID] = u;
                  }

                  for (final m in RoomController.to.activeMembers) {
                    if (!userMap.containsKey(m.userId)) {
                      final profile =
                          UserProfileCacheManager.getCachedUser(m.userId);
                      userMap[m.userId] =
                          ZegoUser(m.userId, profile?.username ?? 'Member');
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
                      final seatText =
                          seatIndex != -1 ? RoomSeatController.getSeatName(seatIndex) : null;
                      final isSpeaking = seatIndex != -1 &&
                          seatsList[seatIndex]['isSpeaking'] == true;

                      return Obx(() {
                        final _ = UserProfileCacheManager.rxCache.length;
                        final profile =
                            UserProfileCacheManager.rxCache[u.userID] ??
                                UserProfileCacheManager.getCachedUser(u.userID);
                        final name = profile?.username ?? u.userName;
                        final avatarUrl = profile?.avatar ?? '';
                        final level = profile?.level ?? 1;
                        final nobleLevel = profile?.novelLevel ?? 0;
                        final vipLevel = profile?.vipLevel ?? 0;

                        // Determine distinct role tag color & label
                        Color roleBgColor;
                        Color roleTextColor;
                        String roleLabel;

                        if (role == 'Creator' || role == 'Owner' || role == 'Founder') {
                          roleBgColor = const Color(0xFFFFD700).withOpacity(0.9);
                          roleTextColor = Colors.black87;
                          roleLabel = '👑 Creator';
                        } else if (role == 'Co-owner' || role == 'Co-Owner' || role == 'Co Owner') {
                          roleBgColor = const Color(0xFF9C27B0);
                          roleTextColor = Colors.white;
                          roleLabel = '💎 Co Owner';
                        } else if (role == 'Admin' || role == 'Moderator') {
                          roleBgColor = const Color(0xFF2563EB);
                          roleTextColor = Colors.white;
                          roleLabel = '🛡 Admin';
                        } else if (role == 'Host' || seatText == 'Host') {
                          roleBgColor = const Color(0xFFEF4444);
                          roleTextColor = Colors.white;
                          roleLabel = '🎤 Host';
                        } else if (seatText != null) {
                          roleBgColor = Colors.cyan;
                          roleTextColor = Colors.black87;
                          roleLabel = '🎙️ $seatText';
                        } else {
                          roleBgColor = Colors.blueGrey.withOpacity(0.5);
                          roleTextColor = Colors.white70;
                          roleLabel = '👤 Audience';
                        }

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
                                      ? NetworkImage(avatarUrl)
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
                                      'ID: ${u.userID}',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white38,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        // Level Tag
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.amber.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Lv $level',
                                            style: GoogleFonts.poppins(
                                                color: Colors.amber,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (nobleLevel > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.cyan.withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Novel $nobleLevel',
                                              style: GoogleFonts.poppins(
                                                  color: Colors.cyanAccent,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        if (vipLevel > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.purple
                                                  .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'VIP $vipLevel',
                                              style: GoogleFonts.poppins(
                                                  color: Colors.purpleAccent,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        // Role Tag
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color:
                                                roleBgColor.withOpacity(0.85),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            roleLabel,
                                            style: GoogleFonts.poppins(
                                              color: roleTextColor,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
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
