import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/room/room_model.dart';
import '../user/user_profile_cache_manager.dart';

import '../voice/voice_controller.dart';
import 'room_seat_controller.dart';

class RoomMemberController extends GetxController {
  static RoomMemberController get to => Get.find<RoomMemberController>();

  final RxList<RoomMember> activeMembers = <RoomMember>[].obs;
  final RxList<Map<String, dynamic>> activeRequests =
      <Map<String, dynamic>>[].obs;
  final RxBool isMutedByModerator = false.obs;

  int get eyeCount => activeMembers.length;

  Future<void> fetchRoomMembers(
    String roomId, {
    required String? activeRoomId,
    required void Function(String title, String reason) onDisconnect,
    required void Function(String roomId, List<RoomMember> members) onSyncRoom,
  }) async {
    try {
      final currentUserId = UserProfileCacheManager.currentUserId;
      final response = await Supabase.instance.client
          .from('room_members')
          .select()
          .eq('room_id', roomId);

      final List<RoomMember> members =
          (response as List).map((m) => RoomMember.fromJson(m)).toList();

      activeMembers.assignAll(members);

      final activeUserIds = members.map((m) => m.userId).toSet();

      // Auto-prune stale RTC voice users that no longer exist in DB room_members
      if (Get.isRegistered<VoiceController>()) {
        VoiceController.to.roomUsers
            .removeWhere((u) => !activeUserIds.contains(u.userID));
      }

      // Auto-clear seats for users who have left room_members
      if (Get.isRegistered<RoomSeatController>()) {
        final seats = RoomSeatController.to.roomSeatsInfo[roomId];
        if (seats != null && seats.isNotEmpty) {
          bool seatModified = false;
          final updatedSeats = seats.map((s) {
            final seatUserId = s['userId'];
            if (seatUserId != null && !activeUserIds.contains(seatUserId)) {
              seatModified = true;
              final map = Map<String, dynamic>.from(s);
              map['userId'] = null;
              map['isSpeaking'] = false;
              map['micStatus'] = 'muted';
              map['isReconnecting'] = false;
              return map;
            }
            return s;
          }).toList();

          if (seatModified) {
            RoomSeatController.to.roomSeatsInfo[roomId] = updatedSeats;
            RoomSeatController.to.roomSeatsInfo.refresh();
          }
        }
      }

      final myMember =
          members.firstWhereOrNull((m) => m.userId == currentUserId);
      if (myMember != null) {
        isMutedByModerator.value = myMember.isMuted;
      }

      if (activeRoomId == roomId &&
          !members.any((m) => m.userId == currentUserId)) {
        onDisconnect(
          'Removed from Room 🥾',
          'You have been kicked or banned from this room.',
        );
      }

      onSyncRoom(roomId, members);
    } catch (e) {
      debugPrint('Error fetching room members: $e');
    }
  }

  Future<void> fetchRoomRequests(String roomId) async {
    try {
      final response = await Supabase.instance.client
          .from('room_speaker_requests')
          .select()
          .eq('room_id', roomId)
          .eq('status', 'pending');

      final List<Map<String, dynamic>> reqs =
          List<Map<String, dynamic>>.from(response as List);
      activeRequests.assignAll(reqs);
    } catch (e) {
      debugPrint('Error fetching speaker requests: $e');
    }
  }

  Future<void> raiseHand(String roomId) async {
    try {
      final currentUserId = UserProfileCacheManager.currentUserId;
      final profile = UserProfileCacheManager.currentUser;
      await Supabase.instance.client.from('room_speaker_requests').insert({
        'room_id': roomId,
        'user_id': currentUserId,
        'user_name': profile?.username ?? 'Creaniaa Student',
        'user_avatar': profile?.avatar,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error raising hand: $e');
    }
  }

  Future<void> moderateSpeakerRequest(
    String roomId,
    String requestId,
    String status,
  ) async {
    try {
      await Supabase.instance.client
          .from('room_speaker_requests')
          .update({'status': status})
          .eq('id', requestId);
      activeRequests.removeWhere((r) => r['id'] == requestId);
    } catch (e) {
      debugPrint('Error moderating speaker request: $e');
    }
  }
}
