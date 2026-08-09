import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/gift/gift_animation_metadata.dart';

class GiftAnimationEventPayload {
  final String id;
  final String giftId;
  final String giftName;
  final String giftIcon;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final List<String> receiverIds;
  final List<String> receiverNames;
  final List<int> receiverSeats;
  final GiftTier tier;
  final String currency;
  final int price;
  final int count;
  final int timestamp;

  GiftAnimationEventPayload({
    required this.id,
    required this.giftId,
    required this.giftName,
    required this.giftIcon,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.receiverIds,
    required this.receiverNames,
    required this.receiverSeats,
    required this.tier,
    this.currency = 'gold',
    this.price = 10,
    this.count = 1,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'giftId': giftId,
        'giftName': giftName,
        'giftIcon': giftIcon,
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'receiverIds': receiverIds,
        'receiverNames': receiverNames,
        'receiverSeats': receiverSeats,
        'tier': tier.name,
        'currency': currency,
        'price': price,
        'count': count,
        'timestamp': timestamp,
      };
}

class GiftAnimationController extends GetxController {
  static GiftAnimationController get to {
    if (!Get.isRegistered<GiftAnimationController>()) {
      return Get.put(GiftAnimationController());
    }
    return Get.find<GiftAnimationController>();
  }

  final RxList<GiftAnimationEventPayload> activeEvents =
      <GiftAnimationEventPayload>[].obs;
  final Set<String> _processedEventIds = {};

  /// Dispatches a backend-broadcasted gift event payload to reconstruct animation locally.
  void dispatchBroadcastGiftEvent(Map<String, dynamic> payload) {
    final String eventId = payload['id'] ??
        payload['timestamp']?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString();

    if (_processedEventIds.contains(eventId)) return;
    _processedEventIds.add(eventId);
    if (_processedEventIds.length > 200) {
      _processedEventIds.remove(_processedEventIds.first);
    }

    final String rawGiftId =
        (payload['gift_id'] ?? payload['giftId'] ?? '').toString().trim();
    final String rawGiftName =
        (payload['gift_name'] ?? payload['giftName'] ?? payload['name'] ?? '').toString().trim();

    final String lookupKey = (rawGiftId.isNotEmpty &&
            rawGiftId != 'gift_default' &&
            rawGiftId != 'gift')
        ? rawGiftId
        : (rawGiftName.isNotEmpty ? rawGiftName : 'Gift');

    final meta = GiftMetadataRegistry.getMetadata(lookupKey);

    final String giftId = (rawGiftId.isNotEmpty && rawGiftId != 'gift_default')
        ? rawGiftId
        : meta.giftId;
    final String giftName =
        (rawGiftName.isNotEmpty && rawGiftName.toLowerCase() != 'gift')
            ? rawGiftName
            : meta.giftName;

    final String rawIcon = payload['gift_icon'] ??
        payload['giftIcon'] ??
        payload['icon'] ??
        '';
    final String giftIcon = rawIcon.isNotEmpty ? rawIcon : meta.giftIcon;

    final String senderId = payload['sender_id'] ??
        payload['senderId'] ??
        payload['user_id'] ??
        'sender';
    final String senderName = payload['sender_name'] ??
        payload['senderName'] ??
        payload['username'] ??
        'Member';

    final List<dynamic> rIdsRaw = payload['receiver_ids'] ??
        payload['receiverIds'] ??
        [payload['target_user_id'] ?? 'target'];
    final List<String> receiverIds =
        rIdsRaw.map((e) => e.toString()).toList();

    final List<dynamic> rNamesRaw = payload['receiver_names'] ??
        payload['receiverNames'] ??
        [payload['target_username'] ?? 'User'];
    final List<String> receiverNames =
        rNamesRaw.map((e) => e.toString()).toList();

    final List<dynamic> rSeatsRaw = payload['seat_indices'] ??
        payload['receiverSeats'] ??
        [payload['seat_number'] ?? 0];
    final List<int> receiverSeats = rSeatsRaw
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .toList();

    final int count =
        payload['count'] ?? payload['amount'] ?? payload['quantity'] ?? 1;

    final eventPayload = GiftAnimationEventPayload(
      id: eventId,
      giftId: giftId,
      giftName: giftName,
      giftIcon: giftIcon,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: payload['sender_avatar'] ?? payload['senderAvatar'],
      receiverIds: receiverIds,
      receiverNames: receiverNames,
      receiverSeats: receiverSeats,
      tier: meta.tier,
      currency: meta.currency,
      price: meta.price,
      count: count,
      timestamp: payload['timestamp'] ??
          DateTime.now().millisecondsSinceEpoch,
    );

    debugPrint('[Gift] Queue Added: Gift event $eventId queued');
    debugPrint('[Gift] Overlay Created: Rendering animation overlay layer');
    debugPrint('[Gift] Asset Loaded: $giftIcon');
    debugPrint('[Gift] Animation Started');

    activeEvents.add(eventPayload);
  }

  void removeEvent(String id) {
    activeEvents.removeWhere((e) => e.id == id);
    debugPrint('[Gift] Animation Finished');
  }
}
