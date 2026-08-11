import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/room/room_model.dart';
import '../../../../services/room/room_controller.dart';
import '../../../../services/room/room_seat_controller.dart';
import '../../../../services/user/user_profile_cache_manager.dart';
import '../../../../widgets/gifting/send_gift_dialog.dart';

class SeatActionSheets {
  /// Show seat action management sheet for occupied seats with Light Theme UI & permissions
  static void showOccupiedSeatActions({
    required BuildContext context,
    required String roomId,
    required int seatIndex,
    required String targetUserId,
    required String targetUserName,
    required String targetRole,
    required String callerUserId,
    required bool isHost,
    required bool isMicOn,
    required VoidCallback onToggleMic,
    required Function(int) onLeaveSeat,
    required Function(String, String, String, int) onViewProfile,
    required List<Map<String, dynamic>> seats,
  }) {
    final seatName = RoomSeatController.getSeatName(seatIndex);
    final bool isSelf = callerUserId == targetUserId;

    // Role Permission Calculation
    final liveRoom = Get.isRegistered<RoomController>()
        ? RoomController.to.rooms.firstWhereOrNull((r) => r.id == roomId)
        : null;
    final String callerRole = Get.isRegistered<RoomController>()
        ? RoomController.to.getUserRole(liveRoom ?? VoiceRoom.dummy(), callerUserId)
        : 'Guest';
    final String actualTargetRole = (liveRoom != null && Get.isRegistered<RoomController>())
        ? RoomController.to.getUserRole(liveRoom, targetUserId)
        : targetRole;

    final int callerWeight = Get.isRegistered<RoomController>()
        ? RoomController.to.permissionCtrl.getRoleWeight(callerRole)
        : 1;
    final int targetWeight = Get.isRegistered<RoomController>()
        ? RoomController.to.permissionCtrl.getRoleWeight(actualTargetRole)
        : 1;

    bool canMute = false;
    bool canRemoveFromSeat = false;

    if (isSelf) {
      canMute = true;
      canRemoveFromSeat = true;
    } else {
      if (callerWeight > targetWeight) {
        canMute = true;
        canRemoveFromSeat = true;
      }
    }

    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle indicator bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Title
            Text(
              'Actions for $seatName',
              style: GoogleFonts.poppins(
                color: const Color(0xFF111827),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              isSelf ? 'Your Seat' : targetUserName,
              style: GoogleFonts.poppins(
                color: const Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // 1. View Profile
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_outline_rounded,
                    color: Color(0xFF3B82F6), size: 20),
              ),
              title: Text(
                'View Profile',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF1F2937),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Get.back();
                onViewProfile(targetUserId, targetUserName, targetRole, seatIndex);
              },
            ),

            // 2. Send Gift
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.card_giftcard_rounded,
                    color: Color(0xFFD97706), size: 20),
              ),
              title: Text(
                isSelf ? 'Send Gift to Yourself 🎁' : 'Send Gift to $targetUserName 🎁',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF1F2937),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Get.back();
                final occupiedSeats =
                    seats.where((s) => s['userId'] != null).length;
                Get.dialog(SendGiftDialog(
                  roomId: roomId,
                  occupiedSeatsCount: occupiedSeats,
                  targetUserId: targetUserId,
                  targetUserName: isSelf ? 'Me (Self)' : targetUserName,
                ));
              },
            ),

            // 3. Mention in Chat
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.alternate_email_rounded,
                    color: Color(0xFF9333EA), size: 20),
              ),
              title: Text(
                'Mention $targetUserName in Chat',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF1F2937),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Get.back();
                if (Get.isRegistered<RoomController>()) {
                  RoomController.to.mentionUserInRoomChat(targetUserName);
                }
              },
            ),

            // 4. Mute / Unmute Microphone (When Permitted)
            if (canMute)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFEFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isMicOn ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: const Color(0xFF0891B2),
                    size: 20,
                  ),
                ),
                title: Text(
                  isSelf
                      ? (isMicOn ? 'Mute Microphone' : 'Unmute Microphone')
                      : 'Mute / Unmute Microphone',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF1F2937),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Get.back();
                  onToggleMic();
                },
              ),

            // 5. Remove from Seat / Leave Seat (When Permitted)
            if (canRemoveFromSeat)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isSelf ? Icons.arrow_downward_rounded : Icons.remove_circle_outline_rounded,
                    color: const Color(0xFFEF4444),
                    size: 20,
                  ),
                ),
                title: Text(
                  isSelf
                      ? 'Leave $seatName (Move to Audience)'
                      : 'Remove $targetUserName from $seatName',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFDC2626),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Get.back();
                  if (isSelf) {
                    onLeaveSeat(seatIndex);
                  } else {
                    if (Get.isRegistered<RoomSeatController>()) {
                      RoomSeatController.to.removeUserFromSeat(
                        roomId,
                        seatIndex,
                        targetUserId,
                        onEmitActivity: (_, __, ___, ____) async {},
                      );
                    }
                  }
                },
              ),

            const SizedBox(height: 10),

            // 6. Cancel Button (Light Theme UI)
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  foregroundColor: const Color(0xFF4B5563),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Get.back(),
                icon: const Icon(Icons.close_rounded,
                    color: Color(0xFF6B7280), size: 16),
                label: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF374151),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show locked seat management sheet (Light Theme UI)
  static void showLockedSeatActions({
    required BuildContext context,
    required String roomId,
    required int seatIndex,
    required RoomController controller,
    required Function(int) onJoinSeat,
    required VoidCallback onStateChanged,
  }) {
    final seatName = RoomSeatController.getSeatName(seatIndex);
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Locked $seatName Management',
              style: GoogleFonts.poppins(
                color: const Color(0xFF111827),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_open_rounded,
                    color: Color(0xFF10B981), size: 20),
              ),
              title: Text(
                'Unlock $seatName',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF1F2937),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Get.back();
                await controller.toggleSeatLock(roomId, seatIndex);
                onStateChanged();
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mic_rounded,
                    color: Color(0xFF3B82F6), size: 20),
              ),
              title: Text(
                'Take $seatName & Unlock',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF1F2937),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Get.back();
                await controller.toggleSeatLock(roomId, seatIndex);
                await onJoinSeat(seatIndex);
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  foregroundColor: const Color(0xFF4B5563),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Get.back(),
                icon: const Icon(Icons.close_rounded,
                    color: Color(0xFF6B7280), size: 16),
                label: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF374151),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show open seat management sheet (Light Theme UI)
  static void showOpenSeatManagementActions({
    required BuildContext context,
    required String roomId,
    required int seatIndex,
    required RoomController controller,
    required Function(int) onJoinSeat,
    required VoidCallback onStateChanged,
  }) {
    final seatName = RoomSeatController.getSeatName(seatIndex);
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '$seatName Management',
              style: GoogleFonts.poppins(
                color: const Color(0xFF111827),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mic_rounded,
                    color: Color(0xFF3B82F6), size: 20),
              ),
              title: Text(
                'Take $seatName',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF1F2937),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Get.back();
                onJoinSeat(seatIndex);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_rounded,
                    color: Color(0xFFEF4444), size: 20),
              ),
              title: Text(
                'Close $seatName (Lock)',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFDC2626),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Get.back();
                await controller.toggleSeatLock(roomId, seatIndex);
                onStateChanged();
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  foregroundColor: const Color(0xFF4B5563),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Get.back(),
                icon: const Icon(Icons.close_rounded,
                    color: Color(0xFF6B7280), size: 16),
                label: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF374151),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show self seat actions helper method
  static void showSelfSeatActions({
    required BuildContext context,
    required String roomId,
    required int seatIndex,
    required bool isMicOn,
    required VoidCallback onToggleMic,
    required Function(int) onLeaveSeat,
    required List<Map<String, dynamic>> seats,
  }) {
    final seat = seats.firstWhereOrNull((s) => s['seatIndex'] == seatIndex);
    final userId = UserProfileCacheManager.currentUserId;
    final userName = seat?['name'] as String? ?? 'Me';
    final role = seat?['role'] as String? ?? 'Guest';

    showOccupiedSeatActions(
      context: context,
      roomId: roomId,
      seatIndex: seatIndex,
      targetUserId: userId,
      targetUserName: userName,
      targetRole: role,
      callerUserId: userId,
      isHost: false,
      isMicOn: isMicOn,
      onToggleMic: onToggleMic,
      onLeaveSeat: onLeaveSeat,
      onViewProfile: (_, __, ___, ____) {},
      seats: seats,
    );
  }
}
