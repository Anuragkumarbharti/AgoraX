import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:creania/core/theme.dart';
import '../../../../services/room/room_controller.dart';
import '../../../../services/room/room_seat_controller.dart';
import '../../../../services/user/user_profile_cache_manager.dart';
import '../../../../widgets/gifting/send_gift_dialog.dart';

class SeatActionSheets {
  static void showSelfSeatActions({
    required BuildContext context,
    required String roomId,
    required int seatIndex,
    required bool isMicOn,
    required VoidCallback onToggleMic,
    required Function(int) onLeaveSeat,
    required List<Map<String, dynamic>> seats,
  }) {
    final seatName = RoomSeatController.getSeatName(seatIndex);
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161822),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Actions for $seatName',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(isMicOn ? Icons.mic_off : Icons.mic,
                  color: context.primaryColor),
              title: Text(isMicOn ? 'Mute Microphone' : 'Unmute Microphone',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                onToggleMic();
              },
            ),
            ListTile(
              leading: const Icon(Icons.card_giftcard_rounded,
                  color: Color(0xFFFFD700)),
              title: const Text('Send Gift to Yourself 🎁',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              onTap: () {
                Get.back();
                final occupiedSeats =
                    seats.where((s) => s['userId'] != null).length;
                Get.dialog(SendGiftDialog(
                  roomId: roomId,
                  occupiedSeatsCount: occupiedSeats,
                  targetUserId: UserProfileCacheManager.currentUserId,
                  targetUserName: 'Me (Self)',
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: Colors.orange),
              title: Text('Leave $seatName (Move to Audience)',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                onLeaveSeat(seatIndex);
              },
            ),
            ListTile(
              leading: Icon(Icons.close, color: context.caption),
              title: Text('Cancel', style: TextStyle(color: context.caption)),
              onTap: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }

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
        decoration: BoxDecoration(
          color: const Color(0xFF161822),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Locked $seatName Management',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.lock_open, color: Colors.greenAccent),
              title: Text('Unlock $seatName',
                  style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Get.back();
                await controller.toggleSeatLock(roomId, seatIndex);
                onStateChanged();
              },
            ),
            ListTile(
              leading: Icon(Icons.mic, color: context.primaryColor),
              title: Text('Take $seatName & Unlock',
                  style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Get.back();
                await controller.toggleSeatLock(roomId, seatIndex);
                await onJoinSeat(seatIndex);
              },
            ),
            ListTile(
              leading: Icon(Icons.close, color: context.caption),
              title: Text('Cancel', style: TextStyle(color: context.caption)),
              onTap: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }

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
        decoration: BoxDecoration(
          color: const Color(0xFF161822),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$seatName Management',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.mic, color: context.primaryColor),
              title: Text('Take $seatName',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                onJoinSeat(seatIndex);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock, color: Colors.redAccent),
              title: Text('Close $seatName (Lock)',
                  style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Get.back();
                await controller.toggleSeatLock(roomId, seatIndex);
                onStateChanged();
              },
            ),
            ListTile(
              leading: Icon(Icons.close, color: context.caption),
              title: Text('Cancel', style: TextStyle(color: context.caption)),
              onTap: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }
}
