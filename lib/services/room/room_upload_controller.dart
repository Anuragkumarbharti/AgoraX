import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/room/room_model.dart';
import '../storage/universal_image_optimizer.dart';
import '../user/user_profile_cache_manager.dart';

class RoomUploadController extends GetxController {
  static RoomUploadController get to => Get.find<RoomUploadController>();

  Future<String?> uploadRoomCoverPhoto(String roomId, io.File file) async {
    try {
      final client = Supabase.instance.client;
      final fileName = '${roomId}_cover.png';

      final optRes = await UniversalImageOptimizer.optimizeAndUpload(
        file: file,
        category: ImageCategoryType.avatar,
        storagePath: fileName,
        customBucket: 'avatars',
      );

      final publicUrl = optRes.publicUrl;
      await client.from('rooms').update({'avatar': publicUrl}).eq('id', roomId);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading cover photo: $e');
      Get.snackbar('Upload Failed', e.toString());
      return null;
    }
  }

  Future<String?> uploadRoomBanner(
    String roomId,
    io.File file,
    RxList<VoiceRoom> rooms,
  ) async {
    try {
      final client = Supabase.instance.client;
      final currentUserId = UserProfileCacheManager.currentUserId;
      final fileName = '${roomId}_banner.png';

      final optRes = await UniversalImageOptimizer.optimizeAndUpload(
        file: file,
        category: ImageCategoryType.roomBackground,
        storagePath: fileName,
        customBucket: 'banners',
      );

      final publicUrl = optRes.publicUrl;

      await client.from('rooms').update({
        'avatar': publicUrl,
        'banner': publicUrl,
      }).eq('id', roomId);

      final idx = rooms.indexWhere((r) => r.id == roomId);
      if (idx != -1) {
        final old = rooms[idx];
        rooms[idx] = VoiceRoom(
          id: old.id,
          name: old.name,
          username: old.username,
          description: old.description,
          hostId: old.hostId,
          communityId: old.communityId,
          type: old.type,
          isLive: old.isLive,
          participantCount: old.participantCount,
          maxParticipants: old.maxParticipants,
          speakerIds: old.speakerIds,
          listenerIds: old.listenerIds,
          recordingUrl: old.recordingUrl,
          allowRecording: old.allowRecording,
          allowScreenShare: old.allowScreenShare,
          createdAt: old.createdAt,
          startedAt: old.startedAt,
          endedAt: old.endedAt,
          avatar: publicUrl,
          banner: publicUrl,
          ownerName: old.ownerName,
          category: old.category,
          country: old.country,
          language: old.language,
          tags: old.tags,
          rules: old.rules,
          level: old.level,
          xp: old.xp,
          badges: old.badges,
          totalMembers: old.totalMembers,
          totalFollowers: old.totalFollowers,
          totalGiftsReceived: old.totalGiftsReceived,
          isPermanent: old.isPermanent,
          entryPermission: old.entryPermission,
          coOwnerIds: old.coOwnerIds,
          adminIds: old.adminIds,
          starMemberIds: old.starMemberIds,
          extraCoOwnerSlots: old.extraCoOwnerSlots,
          extraAdminSlots: old.extraAdminSlots,
          extraStarMemberSlots: old.extraStarMemberSlots,
          todayRoomXp: old.todayRoomXp,
          totalRoomGifts: old.totalRoomGifts,
          todayRoomGifts: old.todayRoomGifts,
          totalRoomStars: old.totalRoomStars,
          todayRoomStars: old.todayRoomStars,
          founderId: old.founderId,
          managerIds: old.managerIds,
          moderatorIds: old.moderatorIds,
          hostIds: old.hostIds,
          mentorIds: old.mentorIds,
          judgeIds: old.judgeIds,
          performerIds: old.performerIds,
          eliteMemberIds: old.eliteMemberIds,
          vipMemberIds: old.vipMemberIds,
          memberIds: old.memberIds,
          visitorIds: old.visitorIds,
          bulletin: old.bulletin,
          greetings: old.greetings,
          roomTheme: old.roomTheme,
          wordFilter: old.wordFilter,
          muteAll: old.muteAll,
          blockList: old.blockList,
          whoCanJoin: old.whoCanJoin,
          whoCanSpeak: old.whoCanSpeak,
          seatPermissions: old.seatPermissions,
          invitePermissions: old.invitePermissions,
          giftSettings: old.giftSettings,
          recommendationSettings: old.recommendationSettings,
          musicSettings: old.musicSettings,
          recordingSettings: old.recordingSettings,
          eventSettings: old.eventSettings,
          autoModeration: old.autoModeration,
          activeMode: old.activeMode,
          pinnedAnnouncement: old.pinnedAnnouncement,
          currentDebateRound: old.currentDebateRound,
        );
        rooms.refresh();
      }

      final profile =
          await UserProfileCacheManager.fetchUserProfile(currentUserId);
      final uName = profile?.username ?? 'Creaniaa Student';

      await client.from('room_activity_events').insert({
        'room_id': roomId,
        'event_type': 'room_banner_changed',
        'user_id': currentUserId,
        'username': uName,
        'message': '🖼️ $uName updated the room banner!',
        'created_at': DateTime.now().toIso8601String(),
      });

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading room banner: $e');
      Get.snackbar('Upload Failed', e.toString());
      return null;
    }
  }
}
