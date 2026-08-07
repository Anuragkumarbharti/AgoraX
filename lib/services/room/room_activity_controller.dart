import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/gift/gift_animation_metadata.dart';
import '../../widgets/gifting/gift_animation_overlay.dart';
import '../../models/room/room_activity_event.dart';
import '../user/user_profile_cache_manager.dart';
import '../gifting/gift_animation_controller.dart';
import 'room_chat_controller.dart';
import 'room_gift_controller.dart';
import 'room_realtime_controller.dart';

class RoomActivityController extends GetxController {
  static RoomActivityController get to {
    if (!Get.isRegistered<RoomActivityController>()) {
      return Get.put(RoomActivityController());
    }
    return Get.find<RoomActivityController>();
  }

  final RxList<Map<String, dynamic>> activePolls = <Map<String, dynamic>>[].obs;
  final RxMap<String, bool> roomActivityQueuesBusy = <String, bool>{}.obs;
  final RxMap<String, List<Map<String, dynamic>>> roomActivityQueues =
      <String, List<Map<String, dynamic>>>{}.obs;
  final RxList<String> animatingJoinUserIds = <String>[].obs;
  final RxMap<String, dynamic> entranceEvent = <String, dynamic>{}.obs;
  final Rxn<Map<String, dynamic>> rxEntranceEvent = Rxn<Map<String, dynamic>>();

  Future<void> emitRoomActivityEvent({
    required String roomId,
    required String eventType,
    String? userId,
    String? username,
    int? seatNumber,
    String? targetUserId,
    String? targetUsername,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final payload = {
        'room_id': roomId,
        'event_type': eventType,
        'user_id': userId,
        'username': username,
        'seat_number': seatNumber,
        'target_user_id': targetUserId,
        'target_username': targetUsername,
        'message': message,
        'metadata': metadata ?? {},
        'created_at': DateTime.now().toIso8601String(),
      };

      if (Get.isRegistered<RoomChatController>()) {
        RoomChatController.to.addSystemActivity(
          roomId,
          message,
          senderId: userId ?? 'system',
          senderName: username ?? 'System',
          messageType: 'activity',
          activityKey: eventType,
        );
      }

      await Supabase.instance.client
          .from('room_activity_events')
          .insert(payload);

      if (Get.isRegistered<RoomRealtimeController>()) {
        await RoomRealtimeController.to.roomActivityEventsChannel?.sendBroadcastMessage(
          event: 'room_activity_event',
          payload: payload,
        );
      }
    } catch (e) {
      debugPrint('Error emitting room activity event: $e');
    }
  }

  void processActivityEventPayload(
    String roomId,
    Map<String, dynamic> payload,
  ) {
    if (roomActivityQueues[roomId] == null) {
      roomActivityQueues[roomId] = <Map<String, dynamic>>[];
    }
    roomActivityQueues[roomId]!.add(payload);
    _drainRoomActivityQueue(roomId);
  }

  Future<void> _drainRoomActivityQueue(String roomId) async {
    if (roomActivityQueuesBusy[roomId] == true) return;
    roomActivityQueuesBusy[roomId] = true;

    while (roomActivityQueues[roomId] != null &&
        roomActivityQueues[roomId]!.isNotEmpty) {
      final payload = roomActivityQueues[roomId]!.removeAt(0);

      try {
        final String eventType = payload['event_type'] ?? payload['eventType'] ?? '';
        final String messageText = payload['message'] ?? '';
        final String senderId = payload['user_id'] ?? payload['userId'] ?? 'system';
        final String senderName = payload['username'] ?? payload['userName'] ?? 'System';
        final Map<String, dynamic> metadata = payload['metadata'] is Map
            ? Map<String, dynamic>.from(payload['metadata'])
            : <String, dynamic>{};

        if (Get.isRegistered<RoomChatController>()) {
          RoomChatController.to.addSystemActivity(
            roomId,
            messageText,
            senderId: senderId,
            senderName: senderName,
            messageType: 'activity',
            activityKey: eventType,
          );
        }

        if (eventType == 'gift_sent') {
          final Map<String, dynamic> fullPayload = metadata.isNotEmpty ? Map<String, dynamic>.from(metadata) : <String, dynamic>{
            'giftId': metadata['gift_id'] ?? metadata['giftId'],
            'giftName': metadata['gift_name'] ?? metadata['giftName'],
            'giftIcon': metadata['gift_icon'] ?? metadata['giftIcon'],
            'senderId': payload['user_id'] ?? metadata['sender_id'],
            'senderName': senderName,
            'senderAvatar': metadata['sender_avatar'] ?? metadata['senderAvatar'],
            'receiverIds': metadata['receiver_ids'] ?? (payload['target_user_id'] != null ? [payload['target_user_id']] : []),
            'receiverNames': metadata['receiver_names'] ?? (payload['target_username'] != null ? [payload['target_username']] : []),
            'receiverSeats': metadata['seat_indices'] ?? (payload['seat_number'] != null ? [payload['seat_number']] : []),
            'quantity': metadata['count'] ?? metadata['quantity'] ?? 1,
            'giftValue': metadata['amount'] ?? metadata['stars_value'] ?? 10,
            'timestamp': metadata['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
          };

          if (Get.isRegistered<RoomRealtimeController>()) {
            RoomRealtimeController.to.handleIncomingRealtimeGiftEvent(roomId, fullPayload);
          } else if (Get.isRegistered<GiftAnimationController>()) {
            GiftAnimationController.to.dispatchBroadcastGiftEvent(fullPayload);
          }
        }

        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        debugPrint('Error draining activity queue payload: $e');
      }
    }

    roomActivityQueuesBusy[roomId] = false;
  }

  Future<void> queueEntranceEffect(
    String roomId,
    String userId,
    String userName,
  ) async {
    animatingJoinUserIds.add(userId);
    final profile = await UserProfileCacheManager.fetchUserProfile(userId);
    final String? uAvatar = profile?.avatar;
    entranceEvent.value = {
      'userId': userId,
      'userName': userName,
      'avatarUrl': uAvatar,
      'entryEffect': null,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Future<void> fetchRoomPolls(String roomId) async {
    try {
      final response = await Supabase.instance.client
          .from('room_polls')
          .select()
          .eq('room_id', roomId)
          .eq('is_active', true);

      final List<Map<String, dynamic>> polls =
          List<Map<String, dynamic>>.from(response as List);
      activePolls.assignAll(polls);
    } catch (e) {
      debugPrint('Error fetching room polls: $e');
    }
  }
}
