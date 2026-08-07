import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Resolves the launch start position for a gift sender automatically.
/// Case 1: Sender is sitting on a room seat -> Gift starts from sender's seat.
/// Case 2: Sender is NOT sitting on any seat -> Gift starts from sender avatar/profile area.
/// Never hardcodes seat numbers.
class SenderPositionResolver {
  static Offset resolve({
    required String senderId,
    required List<Map<String, dynamic>> roomSeats,
    required Map<int, GlobalKey> seatKeys,
    Offset? fallbackProfilePosition,
  }) {
    // Search live room seats to see if sender is currently sitting on a seat
    final seat = roomSeats.firstWhereOrNull((s) => s['userId'] == senderId);

    if (seat != null) {
      final seatIdx = seat['seatIndex'] as int?;
      if (seatIdx != null && seatKeys.containsKey(seatIdx)) {
        final key = seatKeys[seatIdx];
        final RenderBox? box =
            key?.currentContext?.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final size = box.size;
          final offset = box.localToGlobal(Offset.zero);
          return Offset(offset.dx + size.width / 2, offset.dy + size.height / 2);
        }
      }
    }

    // Case 2: Sender NOT on any seat -> starts from sender avatar/profile area
    if (fallbackProfilePosition != null &&
        fallbackProfilePosition != Offset.zero) {
      return fallbackProfilePosition;
    }

    double width = 360.0;
    double height = 640.0;
    try {
      if (Get.width > 0) width = Get.width;
      if (Get.height > 0) height = Get.height;
    } catch (_) {}
    return Offset(width / 2, height * 0.92);
  }
}
