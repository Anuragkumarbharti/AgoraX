import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../user/user_profile_cache_manager.dart';

class ResolvedReceiver {
  final String userId;
  final int seatIndex;
  final String userName;
  final String? userAvatar;
  final Offset roomPosition;

  ResolvedReceiver({
    required this.userId,
    required this.seatIndex,
    required this.userName,
    this.userAvatar,
    required this.roomPosition,
  });
}

/// Resolves target receiver seats, positions, and details using live room seat mapping.
/// If receiver changes seat before animation starts, uses latest seat position.
/// If receiver leaves during animation, uses last known seat position.
class ReceiverResolver {
  static List<ResolvedReceiver> resolve({
    required List<String> receiverIds,
    required List<int> seatIndices,
    required List<String> receiverNames,
    required List<Map<String, dynamic>> roomSeats,
    required Map<int, GlobalKey> seatKeys,
    Map<String, Offset>? lastKnownPositions,
  }) {
    final List<ResolvedReceiver> result = [];

    for (int i = 0; i < receiverIds.length; i++) {
      final uId = receiverIds[i];
      final seatIdx = i < seatIndices.length ? seatIndices[i] : -1;
      final rawName = i < receiverNames.length ? receiverNames[i] : '';

      // Live seat lookup: check if user is on a seat or at original seat index
      final liveSeat = roomSeats.firstWhereOrNull((s) => s['userId'] == uId) ??
          roomSeats.firstWhereOrNull((s) => s['seatIndex'] == seatIdx);

      final String uName = UserProfileCacheManager.resolveUsernameForGifting(
        uId,
        passedName: rawName,
        seatInfo: liveSeat,
      );

      int finalSeatIndex = seatIdx;
      String? avatar;
      if (liveSeat != null) {
        finalSeatIndex = liveSeat['seatIndex'] as int? ?? seatIdx;
        avatar = liveSeat['avatar'] as String?;
      }

      double width = 360.0;
      double height = 640.0;
      try {
        if (Get.width > 0) width = Get.width;
        if (Get.height > 0) height = Get.height;
      } catch (_) {}

      // Compute screen offset from seat key
      Offset pos = Offset(width / 2, height * 0.4);

      if (finalSeatIndex >= 0 && seatKeys.containsKey(finalSeatIndex)) {
        final key = seatKeys[finalSeatIndex];
        final RenderBox? box =
            key?.currentContext?.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final size = box.size;
          final offset = box.localToGlobal(Offset.zero);
          pos = Offset(offset.dx + size.width / 2, offset.dy + size.height / 2);
        }
      } else if (lastKnownPositions != null &&
          lastKnownPositions.containsKey(uId)) {
        pos = lastKnownPositions[uId]!;
      }

      // Cache last known position
      if (lastKnownPositions != null && pos != Offset.zero) {
        lastKnownPositions[uId] = pos;
      }

      result.add(ResolvedReceiver(
        userId: uId,
        seatIndex: finalSeatIndex,
        userName: uName,
        userAvatar: avatar,
        roomPosition: pos,
      ));
    }

    return result;
  }
}
