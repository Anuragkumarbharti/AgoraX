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
            if (callerRole == 'Owner')
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
    final room =
        controller.rooms.firstWhereOrNull((r) => r.id == roomId);
    final callerRole = room != null
        ? controller.getUserRole(room, callerUserId)
        : 'Member';

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
              'Select Role Action',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            if (callerRole == 'Owner')
              ListTile(
                leading:
                    const Icon(Icons.star_rounded, color: Colors.amberAccent),
                title: Text('Promote to Co-Owner',
                    style: GoogleFonts.poppins(color: Colors.white)),
                subtitle: Text('Max limit based on room level',
                    style: GoogleFonts.poppins(
                        color: Colors.white54, fontSize: 10)),
                onTap: () async {
                  Get.back();
                  await controller.promoteRoomMemberRole(
                      roomId, targetUserId, 'Co-Owner');
                  onStateChanged();
                },
              ),
            if (callerRole == 'Owner' ||
                callerRole == 'Co-Owner' ||
                callerRole == 'Co Owner')
              ListTile(
                leading: const Icon(Icons.security_rounded,
                    color: Colors.blueAccent),
                title: Text('Promote to Admin',
                    style: GoogleFonts.poppins(color: Colors.white)),
                subtitle: Text('Max limit based on room level (4 × Level)',
                    style: GoogleFonts.poppins(
                        color: Colors.white54, fontSize: 10)),
                onTap: () async {
                  Get.back();
                  await controller.promoteRoomMemberRole(
                      roomId, targetUserId, 'Admin');
                  onStateChanged();
                },
              ),
            if (callerRole == 'Owner' ||
                callerRole == 'Co-Owner' ||
                callerRole == 'Co Owner')
              ListTile(
                leading:
                    const Icon(Icons.mic_rounded, color: Color(0xFF10B981)),
                title: Text('Promote to Host',
                    style: GoogleFonts.poppins(color: Colors.white)),
                onTap: () async {
                  Get.back();
                  await controller.promoteRoomMemberRole(
                      roomId, targetUserId, 'Host');
                  onStateChanged();
                },
              ),
            if (callerRole == 'Owner' ||
                callerRole == 'Co-Owner' ||
                callerRole == 'Co Owner')
              ListTile(
                leading: const Icon(Icons.record_voice_over_rounded,
                    color: Colors.purpleAccent),
                title: Text('Promote to Co-Host',
                    style: GoogleFonts.poppins(color: Colors.white)),
                subtitle: Text('Max limit based on room level (2 × Level)',
                    style: GoogleFonts.poppins(
                        color: Colors.white54, fontSize: 10)),
                onTap: () async {
                  Get.back();
                  await controller.promoteRoomMemberRole(
                      roomId, targetUserId, 'Co-Host');
                  onStateChanged();
                },
              ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded,
                  color: Colors.white70),
              title: Text('Demote to Member',
                  style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () async {
                Get.back();
                await controller.demoteRoomMemberRole(
                    roomId, targetUserId);
                onStateChanged();
              },
            ),
            if (callerRole == 'Owner')
              ListTile(
                leading: const Icon(Icons.king_bed_rounded,
                    color: Colors.orangeAccent),
                title: Text('Transfer Room Ownership',
                    style: GoogleFonts.poppins(
                        color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Get.back();
                  await controller.transferRoomOwnership(
                      roomId, targetUserId);
                  onStateChanged();
                },
              ),
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
