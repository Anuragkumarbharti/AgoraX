// lib/services/gifting/gift_overlay_manager.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../widgets/gifting/creania_gift_animation_engine.dart';
import './gift_animation_controller.dart';

/// Centralized manager for showing gift animations in a dedicated high-priority
/// Overlay layer above the room background, room UI, seats, and avatars.
class GiftOverlayManager extends GetxController {
  static GiftOverlayManager get to {
    if (!Get.isRegistered<GiftOverlayManager>()) {
      return Get.put(GiftOverlayManager());
    }
    return Get.find<GiftOverlayManager>();
  }

  final RxList<OverlayEntry> _activeOverlayEntries = <OverlayEntry>[].obs;
  bool _isRoomOverlayRegistered = false;

  /// Marks that the VoiceRoomScreen has an active GiftingAnimationOverlay mounted.
  void registerRoomOverlay() {
    _isRoomOverlayRegistered = true;
  }

  /// Unmarks the room overlay when VoiceRoomScreen is disposed.
  void unregisterRoomOverlay() {
    _isRoomOverlayRegistered = false;
    clearAllOverlayEntries();
  }

  /// Plays a gift animation. If a room overlay is active, dispatches to [GiftAnimationController].
  /// Otherwise, creates a dedicated floating [OverlayEntry] above the room content.
  void showGiftAnimation({
    required BuildContext context,
    required GiftRequestEvent event,
    VoidCallback? onCompleted,
  }) {
    if (_isRoomOverlayRegistered && Get.isRegistered<GiftAnimationController>()) {
      final payload = {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'giftId': event.giftId,
        'giftName': event.giftName,
        'giftIcon': event.giftIcon,
        'price': event.price,
        'currency': event.currency,
        'senderName': event.senderName,
        'senderAvatar': event.senderAvatar,
        'receiverNames': [event.receiverName],
        'receiverAvatars': [event.receiverAvatar],
        'count': event.count,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      GiftAnimationController.to.dispatchBroadcastGiftEvent(payload);
      return;
    }

    // Fallback standalone OverlayEntry creation
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (BuildContext ctx) {
        return IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: CreaniaGiftAnimationEngine(
              event: event,
              onCompleted: () {
                overlayEntry.remove();
                _activeOverlayEntries.remove(overlayEntry);
                if (onCompleted != null) onCompleted();
              },
            ),
          ),
        );
      },
    );

    final overlayState = Overlay.of(context);
    overlayState.insert(overlayEntry);
    _activeOverlayEntries.add(overlayEntry);
  }

  /// Removes all active overlay entries cleanly.
  void clearAllOverlayEntries() {
    for (final entry in _activeOverlayEntries) {
      try {
        entry.remove();
      } catch (_) {}
    }
    _activeOverlayEntries.clear();
  }

  @override
  void onClose() {
    clearAllOverlayEntries();
    super.onClose();
  }
}
