import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../room/room_realtime_controller.dart';
import '../room/room_seat_controller.dart';
import '../room/room_chat_controller.dart';
import '../room/room_dual_progress_controller.dart';
import '../room/room_progression_controller.dart';
import '../room/room_discovery_controller.dart';
import '../room/room_controller.dart';
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
    final String giftId =
        (raw['giftId'] ?? raw['gift_id'] ?? 'gift_default').toString();
    final String giftName =
        (raw['giftName'] ?? raw['gift_name'] ?? raw['name'] ?? 'Gift')
            .toString();
    final meta =
        GiftMetadataRegistry.getMetadata(giftId.isNotEmpty ? giftId : giftName);

    final String rawIcon =
        (raw['giftIcon'] ?? raw['gift_icon'] ?? raw['icon'] ?? '').toString();
    final String giftIcon = rawIcon.isNotEmpty ? rawIcon : meta.giftIcon;

    final String senderId = (raw['senderId'] ??
            raw['sender_id'] ??
            raw['user_id'] ??
            UserProfileCacheManager.currentUserId)
        .toString();
    final String rawSender = (raw['senderName'] ?? raw['sender_name'] ?? raw['username'] ?? '').toString();
    final String senderName = UserProfileCacheManager.resolveUsernameForGifting(
      senderId,
      passedName: rawSender,
    );
    final String? senderAvatar = raw['senderAvatar'] ?? raw['sender_avatar'];

    final List<dynamic> rIdsRaw = raw['receiverIds'] ??
        raw['receiver_ids'] ??
        [raw['target_user_id'] ?? 'target'];
    final List<String> receiverIds = rIdsRaw.map((e) => e.toString()).toList();

    final List<dynamic> rNamesRaw = raw['receiverNames'] ??
        raw['receiver_names'] ??
        [raw['target_username'] ?? 'User'];
    final List<String> receiverNames = [];
    for (int i = 0; i < rNamesRaw.length; i++) {
      final uId = i < receiverIds.length ? receiverIds[i] : '';
      final nameItem = rNamesRaw[i].toString();
      final resolved = UserProfileCacheManager.resolveUsernameForGifting(uId, passedName: nameItem);
      if (!receiverNames.contains(resolved)) {
        receiverNames.add(resolved);
      }
    }
    if (receiverNames.isEmpty) receiverNames.add('Member');

    final List<dynamic> rSeatsRaw = raw['receiverSeats'] ??
        raw['receiver_seats'] ??
        raw['seat_indices'] ??
        [raw['seat_number'] ?? 0];
    final List<int> receiverSeats =
        rSeatsRaw.map((e) => int.tryParse(e.toString()) ?? 0).toList();

    final int quantity = int.tryParse(
            (raw['quantity'] ?? raw['count'] ?? raw['amount'] ?? 1)
                .toString()) ??
        1;
    final int giftValue = int.tryParse((raw['giftValue'] ??
                raw['amount'] ??
                raw['stars_value'] ??
                meta.price)
            .toString()) ??
        meta.price;
    final String currency =
        (raw['giftType'] ?? raw['currency'] ?? meta.currency).toString();
    final int timestamp = int.tryParse(
            (raw['timestamp'] ?? DateTime.now().millisecondsSinceEpoch)
                .toString()) ??
        DateTime.now().millisecondsSinceEpoch;

    final dynamic luckyResult = raw['luckyResult'] ?? raw['lucky_result'];

    final String formattedMsg =
        '$senderName $giftName * $quantity ${receiverNames.join(", ")}';

    return {
      'id': (raw['id'] ??
              '$timestamp-${senderId.substring(0, min(5, senderId.length))}')
          .toString(),
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
  Future<void> broadcastGiftEvent(
      String roomId, Map<String, dynamic> rawPayload) async {
    final normalized = normalizePayload(rawPayload);
    debugPrint(
        '[GiftEventService] Broadcasting gift_sent_event: ${normalized['messageText']}');

    // Dispatch locally immediately for zero-latency local feedback
    handleIncomingGiftEvent(roomId, normalized);

    // Broadcast via Supabase Realtime Channel to all other connected clients
    if (Get.isRegistered<RoomRealtimeController>()) {
      await RoomRealtimeController.to
          .broadcastGiftSentEvent(roomId, normalized);
    }
  }

  final Set<String> _processedGiftEventIds = <String>{};

  /// Processes incoming realtime gift payload on every client in the room
  void handleIncomingGiftEvent(String roomId, Map<String, dynamic> rawPayload) {
    final normalized = normalizePayload(rawPayload);
    final String eventId = (normalized['id'] ?? '').toString();
    final bool isDuplicate = eventId.isNotEmpty && _processedGiftEventIds.contains(eventId);

    if (eventId.isNotEmpty) {
      _processedGiftEventIds.add(eventId);
      if (_processedGiftEventIds.length > 500) {
        _processedGiftEventIds.remove(_processedGiftEventIds.first);
      }
    }

    debugPrint(
        '[GiftEventService] Received Gift Event (dup=$isDuplicate): ${normalized['messageText']}');

    // 1. Dispatch event to GiftAnimationController queue
    if (Get.isRegistered<GiftAnimationController>()) {
      GiftAnimationController.to.dispatchBroadcastGiftEvent(normalized);
    }

    // If duplicate event delivery, skip applying transaction counters twice
    if (isDuplicate) return;

    // 2. Dispatch standard gift chat announcement to room chat feed
    try {
      if (Get.isRegistered<RoomChatController>()) {
        final senderId = (normalized['senderId'] ?? '').toString();
        final senderName = (normalized['senderName'] ?? 'Member').toString();
        final giftName = (normalized['giftName'] ?? 'Gift').toString();
        final quantity = normalized['quantity'] ?? 1;
        final List<dynamic> rNamesRaw = normalized['receiverNames'] ?? ['User'];
        final String receiverNamesText = rNamesRaw.join(', ');

        final String chatText =
            '🎁 $senderName sent $giftName × $quantity to $receiverNamesText.';

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
      debugPrint(
          '[GiftEventService] Error adding gift message to room chat: $e');
    }

    // 3. Dispatch Lucky Gift Chat Announcement if luckyResult exists (Server-First)
    try {
      final luckyResult = normalized['luckyResult'];
      if (luckyResult != null &&
          luckyResult is Map &&
          luckyResult['is_lucky_gift'] == true) {
        if (Get.isRegistered<RoomChatController>()) {
          RoomChatController.to.addLuckyGiftMessage(
              roomId, Map<String, dynamic>.from(luckyResult));
        }
      }
    } catch (e) {
      debugPrint('[GiftEventService] Error handling lucky message in chat: $e');
    }

    // 4. Update reactive seat session gems
    int singleReceiverGems = 0;
    try {
      if (Get.isRegistered<RoomSeatController>()) {
        final seatCtrl = RoomSeatController.to;
        final seats = seatCtrl.roomSeatsInfo[roomId];
        final List<int> seatIndices =
            List<int>.from(normalized['receiverSeats'] ?? []);
        final int giftValue = (normalized['giftValue'] as num?)?.toInt() ?? 1;
        final int quantity = (normalized['quantity'] as num?)?.toInt() ?? 1;
        final String currency = (normalized['currency'] ?? 'gold').toString().toLowerCase();

        singleReceiverGems = (normalized['gemsValue'] as num?)?.toInt() ?? 0;
        if (singleReceiverGems <= 0) {
          if (currency == 'silver') {
            singleReceiverGems = (giftValue / 100).floor().clamp(1, 999999) * quantity;
          } else {
            singleReceiverGems = giftValue * quantity;
          }
        }

        if (seats != null) {
          final List<int> seatIndices = List<int>.from(normalized['receiverSeats'] ?? []);
          final List<String> receiverIds = List<String>.from(normalized['receiverIds'] ?? []);
          final Set<int> targetPositions = <int>{};

          for (final sIdx in seatIndices) {
            final pos = seats.indexWhere((s) => s['seatIndex'] == sIdx);
            if (pos != -1) targetPositions.add(pos);
          }

          for (final rId in receiverIds) {
            if (rId.isNotEmpty) {
              final pos = seats.indexWhere((s) => s['userId'] == rId);
              if (pos != -1) targetPositions.add(pos);
            }
          }

          for (final seatPos in targetPositions) {
            final currentGems =
                (seats[seatPos]['seatSessionGems'] as num?)?.toInt() ??
                (seats[seatPos]['seatTotalStars'] as num?)?.toInt() ??
                0;
            final newGems = currentGems + singleReceiverGems;
            seats[seatPos]['seatSessionGems'] = newGems;
            seats[seatPos]['seatTotalStars'] = newGems;
            seats[seatPos]['seatTotalGems'] = newGems;
          }
          seatCtrl.roomSeatsInfo.refresh();
        }
      }
    } catch (e) {
      debugPrint('[GiftEventService] Seat star update error: $e');
    }

    // 5. Update room header Total & Today Gems in realtime
    try {
      final List<int> seatIndices = List<int>.from(normalized['receiverSeats'] ?? []);
      final int countReceivers = seatIndices.isNotEmpty ? seatIndices.length : 1;
      final int totalAddedGems = singleReceiverGems * countReceivers;

      if (Get.isRegistered<RoomProgressionController>()) {
        final progCtrl = RoomProgressionController.to;
        final currentMapGems = progCtrl.roomTotalGemsMap[roomId] ?? 0;
        progCtrl.roomTotalGemsMap[roomId] = currentMapGems + totalAddedGems;
      }

      if (Get.isRegistered<RoomDiscoveryController>()) {
        final roomCtrl = RoomDiscoveryController.to;
        final idx = roomCtrl.rooms.indexWhere((r) => r.id == roomId);
        if (idx != -1) {
          final liveRoom = roomCtrl.rooms[idx];
          liveRoom.totalRoomGems += totalAddedGems;
          liveRoom.todayRoomGems += totalAddedGems;
          roomCtrl.rooms.refresh();
        }
      }
    } catch (e) {
      debugPrint('[GiftEventService] Room header gems refresh note: $e');
    }

    // 6. Trigger Room Task Dual Progress (Gold AP) sync across clients
    try {
      if (Get.isRegistered<RoomDualProgressController>()) {
        final dualCtrl = RoomDualProgressController.to;
        final int giftValue = (normalized['giftValue'] as num?)?.toInt() ?? 1;
        final int quantity = (normalized['quantity'] as num?)?.toInt() ?? 1;
        final String currency = (normalized['currency'] ?? 'gold').toString().toLowerCase();

        if (currency == 'gold' && dualCtrl.dualProgresses.containsKey(roomId)) {
          final currentDual = dualCtrl.dualProgresses[roomId];
          if (currentDual != null) {
            final addedGold = giftValue * quantity;
            dualCtrl.dualProgresses[roomId] = currentDual.copyWith(
              goldPoints: currentDual.goldPoints + addedGold,
              totalTask: currentDual.totalTask + addedGold,
            );
          }
        }

        dualCtrl.fetchDualProgress(roomId);
      }
    } catch (e) {
      debugPrint('[GiftEventService] Room Dual Progress refresh error: $e');
    }
  }
}
