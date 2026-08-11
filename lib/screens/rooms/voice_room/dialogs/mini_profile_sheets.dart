import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../services/room/room_controller.dart';

class MiniProfileSheets {
  static void showReportUserSheet(BuildContext context, String targetUserName) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0E17).withOpacity(0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Report User',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Select a reason for reporting $targetUserName:',
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ...[
              'Harassment or Abuse',
              'Spam or Scam',
              'Inappropriate Profile Picture/Bio',
              'Hate Speech',
              'Intellectual Property Violation',
            ].map((reason) {
              return ListTile(
                leading: const Icon(Icons.report_problem_rounded,
                    color: Colors.orangeAccent, size: 18),
                title: Text(reason,
                    style:
                        GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
                onTap: () {
                  Get.back();
                  Get.snackbar(
                    'Report Submitted 📩',
                    'Thank you for reporting. Our moderation team will review this user shortly.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: const Color(0xFF10B981),
                    colorText: Colors.white,
                  );
                },
              );
            }).toList(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Get.back(),
                child: Text('Cancel',
                    style: GoogleFonts.poppins(color: Colors.white38)),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  static void showThreeDotMenuSheet({
    required BuildContext context,
    required String roomId,
    required String callerUserId,
    required String targetUserId,
    required RoomController controller,
    required VoidCallback onStateChanged,
  }) {
    final room = controller.rooms.firstWhere((r) => r.id == roomId);
    final callerRole = controller.getUserRole(room, callerUserId);
    final callerWeight = controller.permissionCtrl.getRoleWeight(callerRole);

    final isMuted =
        controller.mutedUsers[roomId]?.contains(targetUserId) ?? false;
    final isChatMuted =
        controller.mutedChatUsers[roomId]?.contains(targetUserId) ?? false;

    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0E17).withOpacity(0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Moderation & Options',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person_remove_rounded,
                  color: Colors.orangeAccent),
              title: Text('Remove From Room',
                  style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () {
                Get.back();
                controller.moderateKickUser(roomId, targetUserId);
                Get.back();
                Get.snackbar(
                    'Success 🎉', 'User has been removed from the room.',
                    snackPosition: SnackPosition.BOTTOM);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_flipped, color: Colors.redAccent),
              title: Text('Ban From Room',
                  style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () {
                Get.back();
                showKickDurationSelector(
                    context: context,
                    roomId: roomId,
                    targetUserId: targetUserId,
                    controller: controller);
              },
            ),
            if (callerWeight >= 7)
              ListTile(
                leading: const Icon(Icons.manage_accounts_rounded,
                    color: Colors.cyanAccent),
                title: Text('Change Role',
                    style: GoogleFonts.poppins(color: Colors.white)),
                onTap: () {
                  Get.back();
                  showChangeRoleSheet(
                    context: context,
                    roomId: roomId,
                    callerUserId: callerUserId,
                    targetUserId: targetUserId,
                    controller: controller,
                    onStateChanged: onStateChanged,
                  );
                },
              ),
            ListTile(
              leading: Icon(isMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
                  color: Colors.greenAccent),
              title: Text(isMuted ? 'Unmute Voice' : 'Mute Voice',
                  style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () {
                Get.back();
                controller.toggleMuteUser(roomId, targetUserId);
                onStateChanged();
                Get.snackbar(
                    'Success 🎉', isMuted ? 'Voice unmuted.' : 'Voice muted.',
                    snackPosition: SnackPosition.BOTTOM);
              },
            ),
            ListTile(
              leading: Icon(
                  isChatMuted
                      ? Icons.chat_bubble_rounded
                      : Icons.chat_bubble_outline_rounded,
                  color: Colors.blueAccent),
              title: Text(isChatMuted ? 'Unmute Chat' : 'Mute Chat',
                  style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () {
                Get.back();
                controller.toggleMuteUserChat(roomId, targetUserId);
                onStateChanged();
                Get.snackbar(
                    'Success 🎉', isChatMuted ? 'Chat unmuted.' : 'Chat muted.',
                    snackPosition: SnackPosition.BOTTOM);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.history_rounded, color: Colors.purpleAccent),
              title: Text('View Moderation History',
                  style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () {
                Get.back();
                showModHistoryDialog(context);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Get.back(),
                child: Text('Cancel',
                    style: GoogleFonts.poppins(color: Colors.white38)),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  static void showChangeRoleSheet({
    required BuildContext context,
    required String roomId,
    required String callerUserId,
    required String targetUserId,
    required RoomController controller,
    required VoidCallback onStateChanged,
  }) {
    final room = controller.rooms.firstWhereOrNull((r) => r.id == roomId);
    final callerRole = room != null
        ? controller.getUserRole(room, callerUserId)
        : 'Audience';
    final targetRole = room != null
        ? controller.getUserRole(room, targetUserId)
        : 'Audience';

    final callerWeight = controller.permissionCtrl.getRoleWeight(callerRole);
    final isCreator = callerWeight >= 10;
    final isCoOwner = callerWeight >= 8;
    final isAdmin = callerWeight >= 7;

    final bool isTargetCoOwner = targetRole == 'Co-Owner' || (room?.coOwnerIds.contains(targetUserId) == true);
    final bool isTargetAdmin = targetRole == 'Admin' || (room?.adminIds.contains(targetUserId) == true);
    final bool isTargetHost = targetRole == 'Host' || (room?.hostIds.contains(targetUserId) == true);

    final limits = controller.permissionCtrl.getRoomRoleLimits(room?.level ?? 1);
    final maxCoOwners = limits['co_owners'] ?? 1;
    final maxAdmins = limits['admins'] ?? 4;

    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0E17),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Manage Roles',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),

            // 1. Co-Owner Assign / Remove (Owner Only)
            if (isCreator) ...[
              if (isTargetCoOwner)
                ListTile(
                  leading: const Icon(Icons.remove_moderator_rounded, color: Colors.orangeAccent),
                  title: Text('Remove 💎 Co-Owner Role', style: GoogleFonts.poppins(color: Colors.white)),
                  subtitle: Text('Demote user from Co-Owner', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
                  onTap: () async {
                    Get.back();
                    await controller.demoteRoomMemberRole(roomId, targetUserId, 'Co-Owner');
                    onStateChanged();
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.diamond_rounded, color: Color(0xFFCE93D8)),
                  title: Text('Assign 💎 Co-Owner Role', style: GoogleFonts.poppins(color: Colors.white)),
                  subtitle: Text('Level ${room?.level ?? 1} Limit: Max $maxCoOwners Co-Owner(s)', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
                  onTap: () async {
                    Get.back();
                    await controller.promoteRoomMemberRole(roomId, targetUserId, 'Co-Owner');
                    onStateChanged();
                  },
                ),
            ],

            // 2. Admin Assign / Remove (Owner & Co-Owner)
            if (isCreator || isCoOwner) ...[
              if (isTargetAdmin)
                ListTile(
                  leading: const Icon(Icons.shield_outlined, color: Colors.amberAccent),
                  title: Text('Remove 🛡 Admin Role', style: GoogleFonts.poppins(color: Colors.white)),
                  subtitle: Text('Remove Admin privileges from user', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
                  onTap: () async {
                    Get.back();
                    await controller.demoteRoomMemberRole(roomId, targetUserId, 'Admin');
                    onStateChanged();
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.shield_rounded, color: Color(0xFF60A5FA)),
                  title: Text('Assign 🛡 Admin Role', style: GoogleFonts.poppins(color: Colors.white)),
                  subtitle: Text('Level ${room?.level ?? 1} Limit: Max $maxAdmins Admin(s)', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
                  onTap: () async {
                    Get.back();
                    await controller.promoteRoomMemberRole(roomId, targetUserId, 'Admin');
                    onStateChanged();
                  },
                ),
            ],

            // 3. Host Assign / Remove (Owner, Co-Owner & Admin)
            if (isCreator || isCoOwner || isAdmin) ...[
              if (isTargetHost)
                ListTile(
                  leading: const Icon(Icons.mic_off_rounded, color: Colors.deepOrangeAccent),
                  title: Text('Remove 🎙 Host Role', style: GoogleFonts.poppins(color: Colors.white)),
                  subtitle: Text('Remove Host tag & permissions', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
                  onTap: () async {
                    Get.back();
                    await controller.demoteRoomMemberRole(roomId, targetUserId, 'Host');
                    onStateChanged();
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.mic_rounded, color: Color(0xFF34D399)),
                  title: Text('Assign 🎙 Host Role', style: GoogleFonts.poppins(color: Colors.white)),
                  subtitle: Text('Grant Host tag & stage privileges', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
                  onTap: () async {
                    Get.back();
                    await controller.promoteRoomMemberRole(roomId, targetUserId, 'Host');
                    onStateChanged();
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  static void showModHistoryDialog(BuildContext context) {
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF13121F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Moderation History',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No recent violations or moderator actions found for this user.',
                  style:
                      GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6)),
                  onPressed: () => Get.back(),
                  child: Text('Close',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  static void showKickDurationSelector({
    required BuildContext context,
    required String roomId,
    required String targetUserId,
    required RoomController controller,
  }) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF18181B),
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Kick Duration',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...['1 Day', '3 Days', '7 Days', '1 Month', 'Forever (Permanent)']
                .map((duration) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.timer_outlined, color: Color(0xFF8B5CF6)),
                title: Text(duration,
                    style:
                        GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
                onTap: () {
                  controller.banUserWithDuration(
                      roomId, targetUserId, duration);
                  Get.back(); // Pop bottom sheet
                  Get.back(); // Pop mini profile dialog
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
