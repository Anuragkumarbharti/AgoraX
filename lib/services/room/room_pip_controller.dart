import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../screens/rooms/voice_room_call_screen.dart';
import '../../widgets/common/optimized_image.dart';
import '../user/user_profile_cache_manager.dart';

class RoomPipController extends GetxController {
  static RoomPipController get to => Get.find<RoomPipController>();

  OverlayEntry? _pipOverlayEntry;

  bool get isPipActive => _pipOverlayEntry != null;

  void showPipBubble({
    required String roomId,
    required String roomName,
    required String avatarUrl,
    required bool Function(String roomId) isHostChecker,
  }) {
    if (_pipOverlayEntry != null) return;

    double xPosition = Get.width - 80.0;
    double yPosition = 120.0;

    _pipOverlayEntry = OverlayEntry(
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateOverlay) {
            return Positioned(
              left: xPosition,
              top: yPosition,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setStateOverlay(() {
                    xPosition += details.delta.dx;
                    yPosition += details.delta.dy;
                  });
                },
                onTap: () {
                  hidePipBubble();
                  final currentUid = UserProfileCacheManager.currentUserId;
                  final currentUsername =
                      UserProfileCacheManager.currentUser?.username ??
                          'anurag_kumar';
                  Get.to(
                    () => VoiceRoomCallScreen(
                      roomId: roomId,
                      roomName: roomName,
                      userId: currentUid,
                      userName: currentUsername,
                      isHost: isHostChecker(roomId),
                    ),
                  );
                },
                child: Material(
                  color: Colors.transparent,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.pinkAccent.withOpacity(0.2),
                        ),
                      ),
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.pinkAccent, width: 2),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black38,
                                blurRadius: 6,
                                offset: Offset(0, 3)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(27),
                          child: OptimizedImage(
                            imageUrl: avatarUrl.isNotEmpty
                                ? avatarUrl
                                : 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150',
                            preset: MediaSizePreset.xs,
                            fit: BoxFit.cover,
                            errorWidget: Container(
                              color: Colors.pinkAccent,
                              child: const Icon(Icons.music_note,
                                  color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green,
                            border:
                                Border.all(color: Colors.black87, width: 1.5),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.pinkAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mic, color: Colors.white, size: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    try {
      final overlayState = Navigator.of(Get.context!).overlay;
      if (overlayState != null) {
        overlayState.insert(_pipOverlayEntry!);
      }
    } catch (e) {
      debugPrint('Error inserting PIP overlay entry: $e');
      _pipOverlayEntry = null;
    }
  }

  void hidePipBubble() {
    try {
      _pipOverlayEntry?.remove();
      _pipOverlayEntry = null;
    } catch (e) {
      debugPrint('Error removing PIP overlay: $e');
      _pipOverlayEntry = null;
    }
  }
}
