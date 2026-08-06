import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:creania/core/theme.dart';

import '../../../../models/room/room_model.dart';
import '../../../../services/room/room_controller.dart';
import '../../../../services/voice/voice_controller.dart';
import '../../../../widgets/room/creania_vp_progress_bar.dart';
import '../dialogs/online_members_dialog.dart';
import '../dialogs/seat_applications_dialog.dart';
import '../dialogs/room_settings_dialog.dart';

class RoomCallHeader extends StatelessWidget {
  final String roomId;
  final String roomName;
  final VoiceRoom room;
  final String userId;
  final String Function(String) getUserDp;
  final VoidCallback onLeaveRoom;
  final Function(BuildContext) onShowRoomOptionsMenuSheet;

  const RoomCallHeader({
    Key? key,
    required this.roomId,
    required this.roomName,
    required this.room,
    required this.userId,
    required this.getUserDp,
    required this.onLeaveRoom,
    required this.onShowRoomOptionsMenuSheet,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _buildCustomTopBar(context);
  }

  Widget _buildCustomTopBar(BuildContext context) {
    final RoomController controller = RoomController.to;

    return Obx(() {
      final liveRoom =
          controller.rooms.firstWhereOrNull((r) => r.id == roomId);
      final liveName = liveRoom?.name ?? roomName;
      final roomLevel = liveRoom?.level ?? 1;
      final liveId = liveRoom?.id ?? roomId;

      final String? coverUrl =
          (liveRoom?.avatar != null && liveRoom!.avatar!.isNotEmpty)
              ? liveRoom.avatar
              : liveRoom?.banner;

      final topInset = MediaQuery.of(context).padding.top;

      return Container(
        padding: EdgeInsets.fromLTRB(16, topInset + 6, 12, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Builder(
                  builder: (context) {
                    final freeVp = controller.getRoomFreeVp(roomId);
                    final goldVp = controller.getRoomGoldVp(roomId);
                    return CreaniaVpProgressBar(
                      roomLevel: roomLevel,
                      freeXp: freeVp,
                      freeTarget: 700,
                      extraXp: goldVp,
                      extraTarget: 1000,
                      roomId: '$liveId',
                      roomName: liveName,
                      coverUrl: coverUrl,
                      onTap: () {
                        onShowRoomOptionsMenuSheet(context);
                      },
                      onPlusTap: () {
                        Get.snackbar('Action', 'Inviting users to the arena.');
                      },
                    );
                  },
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Right: Participant capsule + leave button
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    if (liveRoom != null) {
                      Get.dialog(
                          OnlineMembersDialog(roomId: liveId, room: liveRoom));
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.05), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.remove_red_eye_rounded,
                            color: Colors.cyanAccent, size: 13),
                        const SizedBox(width: 4),
                        Builder(
                          builder: (context) {
                            final onlineUsersCount =
                                VoiceController.to.roomUsers.length;
                            final displayCount = onlineUsersCount > 0
                                ? onlineUsersCount
                                : (liveRoom?.totalMembers ?? 1);
                            return Text(
                              '$displayCount',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white70, size: 12),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Top Bar Dropdown Button for Seat Applications
                _buildTopBarButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  onTap: () {
                    Get.dialog(SeatApplicationsDialog(roomId: liveId));
                  },
                ),
                const SizedBox(width: 6),

                // Close / Exit Button
                _buildTopBarButton(
                  icon: Icons.close_rounded,
                  onTap: onLeaveRoom,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTopBarButton(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildCallHeader(BuildContext context) {
    final RoomController controller = RoomController.to;
    final int xpNeeded = controller.getXpForNextLevel(room.level);
    final double xpProgress = (room.xp / xpNeeded).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border(
            bottom:
                BorderSide(color: Colors.white.withOpacity(0.05), width: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 20),
                      onPressed: onLeaveRoom,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.name,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Text(
                                  room.id,
                                  style: GoogleFonts.poppins(
                                      color: Colors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    room.type,
                                    style: GoogleFonts.poppins(
                                        color: Colors.white54, fontSize: 8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Row(
                children: [
                  Builder(
                    builder: (context) {
                      final users = VoiceController.to.roomUsers;
                      final count = users.length;

                      return GestureDetector(
                        onTap: () {
                          Get.dialog(OnlineMembersDialog(
                            roomId: roomId,
                            room: room,
                          ));
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1), width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.remove_red_eye_rounded,
                                  color: Colors.cyanAccent, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                '$count',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white70, size: 22),
                    onPressed: () {
                      final callerRole =
                          controller.getUserRole(room, userId);
                      final callerWeight =
                          controller.getRoleWeight(callerRole);

                      if (callerWeight >= 7) {
                        Get.dialog(RoomSettingsDialog(
                            roomId: roomId, room: room));
                      } else {
                        Get.snackbar(
                          'Permission Denied',
                          'Only the Founder, Manager, or Moderators can access settings.',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: context.errorColor.withOpacity(0.8),
                          colorText: Colors.white,
                        );
                      }
                    },
                    tooltip: 'Settings',
                  ),
                  if (room.isPermanent) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Colors.purpleAccent, Colors.deepPurple]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'LV ${room.level}',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]
                ],
              ),
            ],
          ),
          if (room.isPermanent) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: xpProgress,
                      minHeight: 3,
                      backgroundColor: Colors.white10,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'XP: ${room.xp}/${xpNeeded}',
                  style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 8,
                      fontWeight: FontWeight.bold),
                )
              ],
            )
          ]
        ],
      ),
    );
  }
}
