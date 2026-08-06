import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/room/room_controller.dart';
import '../../../../services/room/room_seat_controller.dart';
import '../../../../services/voice/voice_controller.dart';
import '../../../../services/user/user_profile_cache_manager.dart';
import '../../../../widgets/index.dart';
import '../../../../core/theme.dart';

class RoomCallSeatGrid extends StatelessWidget {
  final String roomId;
  final Map<int, GlobalKey> seatKeys;
  final Function(int seatIndex, dynamic user) onSeatClick;

  const RoomCallSeatGrid({
    Key? key,
    required this.roomId,
    required this.seatKeys,
    required this.onSeatClick,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double baseWidth = 375.0;
    final double scale = (screenWidth > 600 ? 600.0 : screenWidth) / baseWidth;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16 * scale),
        child: Column(
          children: [
            // Row 0: Host & Co-host (2 seats)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSingleNativeSeat(context, 0, scale),
                SizedBox(
                    width: 48 * scale), // Wide spacing between Host and Co-host
                _buildSingleNativeSeat(context, 1, scale),
              ],
            ),
            SizedBox(height: 25 * scale),
            // Row 1: Speakers 2-5 (4 seats)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSingleNativeSeat(context, 2, scale),
                _buildSingleNativeSeat(context, 3, scale),
                _buildSingleNativeSeat(context, 4, scale),
                _buildSingleNativeSeat(context, 5, scale),
              ],
            ),
            SizedBox(height: 25 * scale),
            // Row 2: Speakers 6-9 (4 seats)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSingleNativeSeat(context, 6, scale),
                _buildSingleNativeSeat(context, 7, scale),
                _buildSingleNativeSeat(context, 8, scale),
                _buildSingleNativeSeat(context, 9, scale),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleNativeSeat(BuildContext context, int index, double scale) {
    final RoomController controller = RoomController.to;

    return Obx(() {
      final _seatsCount = controller.roomSeatsInfo.length;
      final _levelsCount = VoiceController.to.userSoundLevels.length;
      final _cacheCount = UserProfileCacheManager.rxCache.length;
      final seatsList = controller.roomSeatsInfo[roomId] ?? [];
      final seat = seatsList.firstWhereOrNull((s) => s['seatIndex'] == index);
      final userId = seat?['userId'] as String?;
      final isOccupied = userId != null;
      final isLocked = seat?['isLocked'] == true;
      final micStatus = seat?['micStatus'] as String? ?? 'unmuted';
      final soundLevel = isOccupied
          ? (VoiceController.to.userSoundLevels[userId] ?? 0.0)
          : 0.0;
      final isSpeaking = isOccupied && soundLevel > 3.0 && micStatus != 'muted';

      // Resolve user properties reactively
      final u = isOccupied
          ? (UserProfileCacheManager.rxCache[userId] ??
              UserProfileCacheManager.getCachedUser(userId))
          : null;

      final avatarUrl = u?.avatar ?? seat?['avatar'] as String?;
      final avatarFrame =
          u?.avatarFrame ?? seat?['avatarFrame'] as String? ?? 'Normal';
      final userName = u?.username ??
          seat?['name'] as String? ??
          RoomSeatController.getSeatName(index);
      final userLevel = u?.level ?? seat?['level'] as int? ?? 1;
      final nobleLevel = u?.novelLevel ?? seat?['nobleLevel'] as int? ?? 0;
      final vipLevel = u?.vipLevel ?? seat?['vipLevel'] as int? ?? 0;
      final totalStars = seat?['seatTotalStars'] as int? ?? 0;
      final double size = ((index == 0 || index == 1) ? 56.0 : 44.0) * scale;

      final lockedColor = context.lockedSeatColor;

      final seatBackground = AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08),
          border: isLocked
              ? Border.all(
                  color: lockedColor.withOpacity(0.40),
                  width: 1.0,
                )
              : null,
        ),
        child: Center(
          child: isLocked
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  builder: (context, val, child) {
                    return Transform.scale(
                      scale: val,
                      child: Icon(
                        Icons.lock_rounded,
                        color: lockedColor.withOpacity(0.45),
                        size: 16 * scale,
                      ),
                    );
                  },
                )
              : Icon(
                  Icons.chair_rounded,
                  color: Colors.white24,
                  size: 16 * scale,
                ),
        ),
      );

      final seatAndAvatarStack = GestureDetector(
        onTap: () {
          onSeatClick(
            index,
            isOccupied ? userId : null,
          );
        },
        child: isOccupied
            ? CustomAvatarFrame(
                userId: userId!,
                username: userName,
                size: size,
                vipLevel: vipLevel,
                novelLevel: nobleLevel,
                level: userLevel,
                soundLevel: soundLevel,
                isSpeaking: isSpeaking && micStatus != 'muted',
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? Image.network(avatarUrl, fit: BoxFit.cover)
                    : Container(
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                        child: Center(
                          child: Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14 * scale,
                            ),
                          ),
                        ),
                      ),
              )
            : seatBackground,
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            key: seatKeys.putIfAbsent(index, () => GlobalKey()),
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              seatAndAvatarStack,

              // Speaker red mic off badge (top right)
              if (isOccupied &&
                  (controller.mutedUsers[roomId]?.contains(userId) ?? false))
                Positioned(
                  top: -1 * scale,
                  right: -1 * scale,
                  child: Container(
                    padding: EdgeInsets.all(1.5 * scale),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3B30),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.mic_off,
                        color: Colors.white, size: 7 * scale),
                  ),
                ),
            ],
          ),
          SizedBox(height: 5 * scale),

          // Username Text name label
          SizedBox(
            width: 72 * scale,
            height: 14 * scale,
            child: Center(
              child: Text(
                userName,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 8.5 * scale,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(height: 1 * scale),

          // ⭐ Total Gift Stars
          SizedBox(
            width: 72 * scale,
            height: 12 * scale,
            child: isOccupied
                ? Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star,
                            color: Colors.amber, size: 7.5 * scale),
                        SizedBox(width: 1 * scale),
                        Text(
                          '$totalStars',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 7 * scale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      );
    });
  }
}
