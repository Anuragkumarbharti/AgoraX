import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../room/room_realtime_controller.dart';
import '../room/room_seat_controller.dart';
import '../room/room_chat_controller.dart';
import '../room/room_dual_progress_controller.dart';
import './gift_animation_controller.dart';
import '../../models/gift/gift_animation_metadata.dart';
import '../user/user_profile_cache_manager.dart';

class GiftEventService extends GetxController {
  static GiftEventService get to {
    if (!Get.isRegistered<GiftEventService>()) {
      return Get.put(GiftEventService());
    }
    return Get.find<GiftEventService>();
  }

  /// Normalizes incoming or outgoing gift event payload to ensure schema compatibility
  Map<String, dynamic> normalizePayload(Map<String, dynamic> raw) {
    final String giftId = (raw['giftId'] ?? raw['gift_id'] ?? 'gift_default').toString();
    final String giftName = (raw['giftName'] ?? raw['gift_name'] ?? raw['name'] ?? 'Gift').toString();
    final meta = GiftMetadataRegistry.getMetadata(giftId.isNotEmpty ? giftId : giftName);

    final String rawIcon = (raw['giftIcon'] ?? raw['gift_icon'] ?? raw['icon'] ?? '').toString();
    final String giftIcon = rawIcon.isNotEmpty ? rawIcon : meta.giftIcon;

    final String senderId = (raw['senderId'] ?? raw['sender_id'] ?? raw['user_id'] ?? UserProfileCacheManager.currentUserId).toString();
    final String senderName = (raw['senderName'] ?? raw['sender_name'] ?? raw['username'] ?? 'Member').toString();
    final String? senderAvatar = raw['senderAvatar'] ?? raw['sender_avatar'];

    final List<dynamic> rIdsRaw = raw['receiverIds'] ?? raw['receiver_ids'] ?? [raw['target_user_id'] ?? 'target'];
    final List<String> receiverIds = rIdsRaw.map((e) => e.toString()).toList();

    final List<dynamic> rNamesRaw = raw['receiverNames'] ?? raw['receiver_names'] ?? [raw['target_username'] ?? 'User'];
    final List<String> receiverNames = rNamesRaw.map((e) => e.toString()).toList();

    final List<dynamic> rSeatsRaw = raw['receiverSeats'] ?? raw['receiver_seats'] ?? raw['seat_indices'] ?? [raw['seat_number'] ?? 0];
    final List<int> receiverSeats = rSeatsRaw.map((e) => int.tryParse(e.toString()) ?? 0).toList();

    final int quantity = int.tryParse((raw['quantity'] ?? raw['count'] ?? raw['amount'] ?? 1).toString()) ?? 1;
    final int giftValue = int.tryParse((raw['giftValue'] ?? raw['amount'] ?? raw['stars_value'] ?? meta.price).toString()) ?? meta.price;
    final String currency = (raw['giftType'] ?? raw['currency'] ?? meta.currency).toString();
    final int timestamp = int.tryParse((raw['timestamp'] ?? DateTime.now().millisecondsSinceEpoch).toString()) ?? DateTime.now().millisecondsSinceEpoch;

    final dynamic luckyResult = raw['luckyResult'] ?? raw['lucky_result'];

    final String formattedMsg = '$senderName $giftName * $quantity ${receiverNames.join(", ")}';

    return {
      'id': (raw['id'] ?? '$timestamp-${senderId.substring(0, min(5, senderId.length))}').toString(),
      'giftId': giftId,
      'giftName': giftName,
      'giftIcon': giftIcon,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'receiverIds': receiverIds,
      'receiverNames': receiverNames,
      'receiverSeats': receiverSeats,
      'quantity': quantity,
      'count': quantity,
      'giftValue': giftValue,
      'currency': currency,
      'timestamp': timestamp,
      'messageText': formattedMsg,
      'tier': meta.tier.name,
      'luckyResult': luckyResult,
    };
  }

  /// Broadcasts standardized gift event to all clients in the room
  Future<void> broadcastGiftEvent(String roomId, Map<String, dynamic> rawPayload) async {
    final normalized = normalizePayload(rawPayload);
    debugPrint('[GiftEventService] Broadcasting gift_sent_event: ${normalized['messageText']}');

    // Dispatch locally immediately for zero-latency local feedback
    handleIncomingGiftEvent(roomId, normalized);

    // Broadcast via Supabase Realtime Channel to all other connected clients
    if (Get.isRegistered<RoomRealtimeController>()) {
      await RoomRealtimeController.to.broadcastGiftSentEvent(roomId, normalized);
    }
  }

  /// Processes incoming realtime gift payload on every client in the room
  void handleIncomingGiftEvent(String roomId, Map<String, dynamic> rawPayload) {
    final normalized = normalizePayload(rawPayload);
    debugPrint('[GiftEventService] Received Gift Event: ${normalized['messageText']}');

    // 1. Dispatch event to GiftAnimationController queue
    if (Get.isRegistered<GiftAnimationController>()) {
      GiftAnimationController.to.dispatchBroadcastGiftEvent(normalized);
    }

    // 2. Dispatch standard gift chat announcement to room chat feed
    try {
      if (Get.isRegistered<RoomChatController>()) {
        final senderId = (normalized['senderId'] ?? '').toString();
        final senderName = (normalized['senderName'] ?? 'Member').toString();
        final giftName = (normalized['giftName'] ?? 'Gift').toString();
        final quantity = normalized['quantity'] ?? 1;
        final List<dynamic> rNamesRaw = normalized['receiverNames'] ?? ['User'];
        final String receiverNamesText = rNamesRaw.join(', ');

        final String chatText = '🎁 $senderName sent $giftName × $quantity to $receiverNamesText.';

        final chatMsg = RoomChatMessage(
          id: 'gift_${normalized['id']}',
          senderId: senderId,
          senderName: senderName,
          text: chatText,
          senderAvatar: normalized['senderAvatar']?.toString(),
          timestamp: DateTime.now(),
          isSystem: true,
          messageType: 'gift',
          eventType: 'gift_sent',
        );

        RoomChatController.to.addChatMessage(roomId, chatMsg);
      }
    } catch (e) {
      debugPrint('[GiftEventService] Error adding gift message to room chat: $e');
    }

    // 3. Dispatch Lucky Gift Chat Announcement if luckyResult exists (Server-First)
    try {
      final luckyResult = normalized['luckyResult'];
      if (luckyResult != null && luckyResult is Map && luckyResult['is_lucky_gift'] == true) {
        if (Get.isRegistered<RoomChatController>()) {
          RoomChatController.to.addLuckyGiftMessage(roomId, Map<String, dynamic>.from(luckyResult));
        }
      }
    } catch (e) {
      debugPrint('[GiftEventService] Error handling lucky message in chat: $e');
    }

    // 3. Update reactive seat total stars
    try {
      if (Get.isRegistered<RoomSeatController>()) {
        final seatCtrl = RoomSeatController.to;
        final seats = seatCtrl.roomSeatsInfo[roomId];
        final List<int> seatIndices = List<int>.from(normalized['receiverSeats']);
        final int giftValue = normalized['giftValue'] as int;
        final int quantity = normalized['quantity'] as int;

        if (seats != null && seatIndices.isNotEmpty) {
          for (final idx in seatIndices) {
            final seatPos = seats.indexWhere((s) => s['seatIndex'] == idx);
            if (seatPos != -1) {
              final currentStars = (seats[seatPos]['seatTotalStars'] as num?)?.toInt() ?? 0;
              seats[seatPos]['seatTotalStars'] = currentStars + (giftValue * quantity);
              seatCtrl.roomSeatsInfo.refresh();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[GiftEventService] Seat star update error: $e');
    }

    // 5. Trigger Room Task Dual Progress sync across clients
    try {
      if (Get.isRegistered<RoomDualProgressController>()) {
        RoomDualProgressController.to.fetchDualProgress(roomId);
      }
    } catch (e) {
      debugPrint('[GiftEventService] Room Dual Progress refresh error: $e');
    }
  }
}
