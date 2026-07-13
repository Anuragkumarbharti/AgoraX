import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/room_model.dart';
import '../models/room_progression_models.dart';
import '../models/room_activity_event.dart';
import 'customization_controller.dart';
import '../screens/rooms/voice_room_call_screen.dart';

import 'store_controller.dart';
import 'user_progress_sync_service.dart';
import 'user_profile_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user_model.dart';

class RoomChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String? senderRole;
  final String? senderAvatar;
  final DateTime timestamp;
  final bool isSystem;
  final String messageType;
  final String? replyToMessageId;
  final String? senderLevel;
  final String? vipLabel;
  final String? novelLabel;
  final String? communityTag;
  final String? roleTag;
  final bool isActiveSpeaker;
  final int repeatCount;
  final String? eventType;
  final Map<String, List<String>> reactions;
  final String? avatarFrame;
  final String? nobleLabel;

  RoomChatMessage({
    String? id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.senderRole,
    this.senderAvatar,
    required this.timestamp,
    this.isSystem = false,
    this.messageType = 'chat',
    this.replyToMessageId,
    this.senderLevel,
    this.vipLabel,
    this.novelLabel,
    this.communityTag,
    this.roleTag,
    this.isActiveSpeaker = false,
    this.repeatCount = 1,
    this.eventType,
    Map<String, List<String>>? reactions,
    this.avatarFrame,
    this.nobleLabel,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        reactions = reactions ?? {};

  RoomChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? text,
    String? senderRole,
    String? senderAvatar,
    DateTime? timestamp,
    bool? isSystem,
    String? messageType,
    String? replyToMessageId,
    String? senderLevel,
    String? vipLabel,
    String? novelLabel,
    String? communityTag,
    String? roleTag,
    bool? isActiveSpeaker,
    int? repeatCount,
    String? eventType,
    Map<String, List<String>>? reactions,
    String? avatarFrame,
    String? nobleLabel,
  }) {
    return RoomChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      senderRole: senderRole ?? this.senderRole,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      timestamp: timestamp ?? this.timestamp,
      isSystem: isSystem ?? this.isSystem,
      messageType: messageType ?? this.messageType,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      senderLevel: senderLevel ?? this.senderLevel,
      vipLabel: vipLabel ?? this.vipLabel,
      novelLabel: novelLabel ?? this.novelLabel,
      communityTag: communityTag ?? this.communityTag,
      roleTag: roleTag ?? this.roleTag,
      isActiveSpeaker: isActiveSpeaker ?? this.isActiveSpeaker,
      repeatCount: repeatCount ?? this.repeatCount,
      eventType: eventType ?? this.eventType,
      reactions: reactions ?? this.reactions,
      avatarFrame: avatarFrame ?? this.avatarFrame,
      nobleLabel: nobleLabel ?? this.nobleLabel,
    );
  }
}

class RoomController extends GetxController {
  static RoomController get to => Get.find<RoomController>();
  static String get currentUserId => UserProfileCacheManager.currentUserId;

  String? activeRoomId;

  RxInt get walletBalance => Get.find<StoreController>().coinsBalance;
  final RxList<VoiceRoom> rooms = <VoiceRoom>[].obs;

  // New reactive variables for active room state
  final RxList<RoomMember> activeMembers = <RoomMember>[].obs;
  final RxList<Map<String, dynamic>> activeRequests = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> activePolls = <Map<String, dynamic>>[].obs;
  final RxMap<String, bool> currentPermissions = <String, bool>{}.obs;
  final RxBool isMutedByModerator = false.obs;
  final RxList<String> typingUsers = <String>[].obs;
  final RxList<String> animatingJoinUserIds = <String>[].obs;
  final RxMap<String, dynamic> entranceEvent = <String, dynamic>{}.obs;
  final Rxn<Map<String, dynamic>> rxEntranceEvent = Rxn<Map<String, dynamic>>();

  // Room Progression System states
  final RxMap<String, RoomLevelProgress> roomLevelProgresses = <String, RoomLevelProgress>{}.obs;
  final RxMap<String, RoomStatistics> roomStats = <String, RoomStatistics>{}.obs;
  final RxMap<String, List<RoomDailyTask>> roomDailyTaskLists = <String, List<RoomDailyTask>>{}.obs;
  final RxMap<String, List<Map<String, dynamic>>> roomSeatsInfo = <String, List<Map<String, dynamic>>>{}.obs;
  final RxMap<String, int> roomSeatGiftsCounters = <String, int>{}.obs; // key: room_id:seat_index -> silver_gift_count
  final RxList<String> marqueeAnnouncementsQueue = <String>[].obs;

  RealtimeChannel? _roomProgressionChannel;
  RealtimeChannel? _roomMembersChannel;
  RealtimeChannel? _roomMessagesChannel;
  RealtimeChannel? _roomRequestsChannel;
  RealtimeChannel? _roomPollsChannel;
  RealtimeChannel? _roomActivityEventsChannel;
  RealtimeChannel? _roomsListChannel;

  // Track participant states per room (simulated local states)
  // roomId -> list of muted user IDs
  final RxMap<String, List<String>> mutedUsers = <String, List<String>>{}.obs;
  // roomId -> list of banned user IDs
  final RxMap<String, List<String>> bannedUsers = <String, List<String>>{}.obs;

  // roomId -> { userId -> { 'duration': String, 'timestamp': DateTime, 'unbanTime': DateTime? } }
  final RxMap<String, Map<String, Map<String, dynamic>>> roomBannedUsersDetailed = <String, Map<String, Map<String, dynamic>>>{}.obs;

  // Favorites and Recents tracking for discovery
  final RxList<String> favoriteRoomIds = <String>[].obs;
  final RxList<String> recentRoomIds = <String>[].obs;

  // Room Chat messages (roomId -> list of messages)
  final RxMap<String, RxList<RoomChatMessage>> roomChats = <String, RxList<RoomChatMessage>>{}.obs;
  final Rxn<Map<String, dynamic>> activeGiftNotification = Rxn<Map<String, dynamic>>();
  final RxList<String> bottomSystemNotifications = <String>[].obs;
  final RxnString activeSystemNotification = RxnString();
  final RxMap<String, bool> roomActivityQueuesBusy = <String, bool>{}.obs;
  final RxMap<String, List<Map<String, dynamic>>> roomActivityQueues = <String, List<Map<String, dynamic>>>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchRooms();
    subscribeToRoomsList();
  }

  void initializeChatForRoom(String roomId) {
    if (!roomChats.containsKey(roomId)) {
      roomChats[roomId] = <RoomChatMessage>[].obs;
    }
  }

  void addChatMessage(
    String roomId,
    RoomChatMessage message,
  ) {
    initializeChatForRoom(roomId);
    final messages = roomChats[roomId]!;

    if (message.isSystem && messages.isNotEmpty) {
      final last = messages.last;
      if (last.isSystem) {
        // 1. Merge consecutive entry/leave events
        // Format for entry: "🟢 {Username} entered the room."
        // Format for leave: "👋 {Username} left the room."
        final bool isEntry = message.text.contains('entered the room');
        final bool isLeave = message.text.contains('left the room');
        final bool wasEntry = last.text.contains('entered the room');
        final bool wasLeave = last.text.contains('left the room');

        if ((isEntry && wasEntry) || (isLeave && wasLeave)) {
          final String keyword = isEntry ? ' entered the room.' : ' left the room.';
          final String emoji = isEntry ? '🟢 ' : '👋 ';

          // Clean names
          final lastClean = last.text.replaceFirst(emoji, '').replaceFirst(keyword, '');
          final newClean = message.text.replaceFirst(emoji, '').replaceFirst(keyword, '');

          // Get names set
          final Set<String> names = lastClean.split(', ').toSet();
          if (!names.contains(newClean)) {
            names.add(newClean);
            final updatedText = '$emoji${names.join(', ')}$keyword';
            messages[messages.length - 1] = last.copyWith(text: updatedText, repeatCount: last.repeatCount + 1);
            return;
          } else {
            // Already contains name, merge by incrementing repeat count or just ignore
            messages[messages.length - 1] = last.copyWith(repeatCount: last.repeatCount + 1);
            return;
          }
        }

        // 2. Merge consecutive identical gift messages
        // Format: "🎁 {Username} sent {Gift Name} × {Count} to {Receiver}."
        if (message.text.startsWith('🎁') && last.text.startsWith('🎁')) {
          final giftRegex = RegExp(r'^🎁\s+(.*?)\s+sent\s+(.*?)\s+×\s+(\d+)\s+to\s+(.*?)\.$');
          final matchLast = giftRegex.firstMatch(last.text);
          final matchNew = giftRegex.firstMatch(message.text);

          if (matchLast != null && matchNew != null) {
            final senderLast = matchLast.group(1);
            final giftLast = matchLast.group(2);
            final countLast = int.tryParse(matchLast.group(3) ?? '1') ?? 1;
            final receiverLast = matchLast.group(4);

            final senderNew = matchNew.group(1);
            final giftNew = matchNew.group(2);
            final countNew = int.tryParse(matchNew.group(3) ?? '1') ?? 1;
            final receiverNew = matchNew.group(4);

            if (senderLast == senderNew && giftLast == giftNew && receiverLast == receiverNew) {
              final totalCount = countLast + countNew;
              final updatedText = '🎁 $senderNew sent $giftNew × $totalCount to $receiverNew.';
              messages[messages.length - 1] = last.copyWith(text: updatedText);
              return;
            }
          }
        }
      }
    }

    messages.add(message);
  }

  void addSystemActivity(
    String roomId,
    String text, {
    String? senderId = 'system',
    String? senderName = 'System',
    String? senderAvatar,
    String? messageType = 'activity',
    String? activityKey,
  }) {
    initializeChatForRoom(roomId);
    final msg = RoomChatMessage(
      senderId: senderId ?? 'system',
      senderName: senderName ?? 'System',
      text: text,
      senderAvatar: senderAvatar,
      timestamp: DateTime.now(),
      isSystem: true,
      messageType: messageType ?? 'activity',
      roleTag: activityKey,
    );
    addChatMessage(roomId, msg);
  }

  Future<void> deleteRoomMessage(String roomId, String messageId) async {
    try {
      await _roomMessagesChannel?.sendBroadcastMessage(
        event: 'delete_message',
        payload: {'message_id': messageId},
      );
      final messages = roomChats[roomId];
      if (messages != null) {
        messages.removeWhere((message) => message.id == messageId);
      }
    } catch (e) {
      debugPrint('Error broadcasting delete message: $e');
    }
  }

  void emitRoomActivity(String roomId, String text, {String? activityKey}) {
    addSystemActivity(roomId, text, activityKey: activityKey);
  }

  Future<void> queueEntranceEffect(
    String roomId,
    String userId,
    String userName,
  ) async {
    final entryEffect = _getActiveEntranceEffect();
    if (entryEffect == null) {
      addSystemActivity(roomId, '🟢 $userName entered the room.');
      return;
    }

    roomActivityQueues.putIfAbsent(roomId, () => []);
    roomActivityQueues[roomId]!.add({
      'userId': userId,
      'userName': userName,
      'effect': entryEffect,
    });

    if (roomActivityQueuesBusy[roomId] == true) return;
    roomActivityQueuesBusy[roomId] = true;

    while ((roomActivityQueues[roomId] ?? []).isNotEmpty) {
      final next = roomActivityQueues[roomId]!.removeAt(0);
      await Future.delayed(const Duration(milliseconds: 2200));
      addSystemActivity(
        roomId,
        '🟢 ${next['userName']} entered the room.',
        activityKey: 'entrance',
      );
    }

    roomActivityQueuesBusy[roomId] = false;
  }

  String? _getActiveEntranceEffect() {
    try {
      final customizationController = Get.find<CustomizationController>();
      final effect = customizationController.activeEntryEffect.value;
      if (effect == 'None' || effect.isEmpty) return null;
      if (!customizationController.isItemUnlocked(effect)) return null;
      return effect;
    } catch (_) {
      return null;
    }
  }

  Future<void> sendRoomMessage(
    String roomId,
    String text, {
    String? senderId,
    String? senderName,
    String? senderRole,
    String? senderAvatar,
    String? replyToMessageId,
    String? senderLevel,
    String? vipLabel,
    String? novelLabel,
    String? communityTag,
    String? roleTag,
    bool isActiveSpeaker = false,
  }) async {
    try {
      final uid = senderId ?? UserProfileCacheManager.currentUserId;
      final payload = {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'sender_id': uid,
        'sender_name': senderName ?? 'Creania Student',
        'text': text,
        'sender_role': senderRole ?? 'Listener',
        'sender_avatar': senderAvatar,
        'timestamp': DateTime.now().toIso8601String(),
        'reply_to_message_id': replyToMessageId,
        'sender_level': senderLevel,
        'vip_label': vipLabel,
        'novel_label': novelLabel,
        'community_tag': communityTag,
        'role_tag': roleTag,
        'is_active_speaker': isActiveSpeaker,
      };

      await _roomMessagesChannel?.sendBroadcastMessage(
        event: 'chat_message',
        payload: payload,
      );

      final message = RoomChatMessage(
        id: payload['id'] as String,
        senderId: payload['sender_id'] as String,
        senderName: payload['sender_name'] as String,
        text: payload['text'] as String,
        senderRole: payload['sender_role'] as String?,
        senderAvatar: payload['sender_avatar'] as String?,
        timestamp: DateTime.parse(payload['timestamp'] as String),
        replyToMessageId: payload['reply_to_message_id'] as String?,
        senderLevel: payload['sender_level'] as String?,
        vipLabel: payload['vip_label'] as String?,
        novelLabel: payload['novel_label'] as String?,
        communityTag: payload['community_tag'] as String?,
        roleTag: payload['role_tag'] as String?,
        isActiveSpeaker: payload['is_active_speaker'] == true,
      );

      if (roomChats[roomId] == null) {
        roomChats[roomId] = <RoomChatMessage>[].obs;
      }
      roomChats[roomId]!.add(message);
    } catch (e) {
      debugPrint('Error broadcasting message: $e');
    }
  }

  Future<void> setTypingStatus(String roomId, bool isTyping) async {
    try {
      final username = UserProfileCacheManager.currentUser?.username ?? 'Creania Student';
      await _roomMessagesChannel?.sendBroadcastMessage(
        event: 'typing_indicator',
        payload: {
          'user_id': UserProfileCacheManager.currentUserId,
          'username': username,
          'is_typing': isTyping,
        },
      );
    } catch (_) {}
  }

  void toggleFavoriteRoom(String roomId) {
    if (favoriteRoomIds.contains(roomId)) {
      favoriteRoomIds.remove(roomId);
      Get.snackbar(
        'Removed from Favorites',
        'Arena has been removed from your favorites.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } else {
      favoriteRoomIds.add(roomId);
      Get.snackbar(
        'Added to Favorites',
        'Arena has been added to your favorites!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    }
  }
  void addRecentRoom(String roomId) {
    recentRoomIds.remove(roomId); // Bring to top
    recentRoomIds.insert(0, roomId);
    if (recentRoomIds.length > 10) {
      recentRoomIds.removeLast();
    }
  }

  Future<void> fetchRooms() async {
    try {
      final response = await Supabase.instance.client
          .from('rooms')
          .select('*, profiles:host_id(id, username, avatar_url, avatar_frame, level, vip_level, novel_level)')
          .or('status.eq.live,status.eq.scheduled')
          .order('created_at', ascending: false);

      final List<VoiceRoom> loaded = [];
      for (final item in response as List) {
        loaded.add(VoiceRoom.fromJson(item));
        final hostData = item['profiles'];
        if (hostData != null && hostData is Map<String, dynamic> && hostData['id'] != null) {
          try {
            final userObj = User.fromJson(hostData);
            UserProfileCacheManager.rxCache[userObj.id] = userObj;
          } catch (pe) {
            debugPrint('Error parsing host profile in fetchRooms: $pe');
          }
        }
      }
      rooms.assignAll(loaded);
    } catch (e) {
      debugPrint('Error fetching rooms: $e');
    }
  }

  Future<void> searchRooms(String query) async {
    if (query.trim().isEmpty) {
      await fetchRooms();
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('rooms')
          .select('*, profiles:host_id(id, username, avatar_url, avatar_frame, level, vip_level, novel_level)')
          .or('id.eq.${query.trim()},name.ilike.%$query%')
          .order('created_at', ascending: false);

      final List<VoiceRoom> loaded = [];
      for (final item in response as List) {
        loaded.add(VoiceRoom.fromJson(item));
        final hostData = item['profiles'];
        if (hostData != null && hostData is Map<String, dynamic> && hostData['id'] != null) {
          try {
            final userObj = User.fromJson(hostData);
            UserProfileCacheManager.rxCache[userObj.id] = userObj;
          } catch (pe) {
            debugPrint('Error parsing host profile in searchRooms: $pe');
          }
        }
      }
      rooms.assignAll(loaded);
    } catch (e) {
      debugPrint('Error searching rooms: $e');
    }
  }

  void syncRoomFromMembers(String roomId, List<RoomMember> members) {
    final idx = rooms.indexWhere((r) => r.id == roomId);
    if (idx != -1) {
      final oldRoom = rooms[idx];
      
      final String hostId = members.firstWhereOrNull((m) => m.role == 'Host')?.userId ?? oldRoom.hostId;
      final List<String> coOwnerIds = members.where((m) => m.role == 'Co-Host').map((m) => m.userId).toList();
      final List<String> adminIds = members.where((m) => m.role == 'Moderator').map((m) => m.userId).toList();
      final List<String> starMemberIds = members.where((m) => m.role == 'Speaker').map((m) => m.userId).toList();
      
      final List<String> speakerIds = [hostId, ...coOwnerIds, ...starMemberIds];
      final List<String> listenerIds = members.where((m) => m.role == 'Moderator' || m.role == 'Listener' || m.role == 'Guest').map((m) => m.userId).toList();
      
      final updatedRoom = VoiceRoom(
        id: oldRoom.id,
        name: oldRoom.name,
        username: oldRoom.username,
        description: oldRoom.description,
        hostId: hostId,
        communityId: oldRoom.communityId,
        type: oldRoom.type,
        isLive: oldRoom.isLive,
        participantCount: members.length,
        maxParticipants: oldRoom.maxParticipants,
        speakerIds: speakerIds,
        listenerIds: listenerIds,
        recordingUrl: oldRoom.recordingUrl,
        allowRecording: oldRoom.allowRecording,
        allowScreenShare: oldRoom.allowScreenShare,
        createdAt: oldRoom.createdAt,
        startedAt: oldRoom.startedAt,
        endedAt: oldRoom.endedAt,
        avatar: oldRoom.avatar,
        banner: oldRoom.banner,
        ownerName: oldRoom.ownerName,
        category: oldRoom.category,
        country: oldRoom.country,
        language: oldRoom.language,
        tags: oldRoom.tags,
        rules: oldRoom.rules,
        level: oldRoom.level,
        xp: oldRoom.xp,
        badges: oldRoom.badges,
        totalMembers: members.length,
        totalFollowers: oldRoom.totalFollowers,
        totalGiftsReceived: oldRoom.totalGiftsReceived,
        isPermanent: oldRoom.isPermanent,
        entryPermission: oldRoom.entryPermission,
        coOwnerIds: coOwnerIds,
        adminIds: adminIds,
        starMemberIds: starMemberIds,
        extraCoOwnerSlots: oldRoom.extraCoOwnerSlots,
        extraAdminSlots: oldRoom.extraAdminSlots,
        extraStarMemberSlots: oldRoom.extraStarMemberSlots,
        founderId: hostId,
        managerIds: oldRoom.managerIds,
        moderatorIds: adminIds,
        hostIds: [hostId],
        mentorIds: oldRoom.mentorIds,
        judgeIds: oldRoom.judgeIds,
        performerIds: oldRoom.performerIds,
        eliteMemberIds: oldRoom.eliteMemberIds,
        vipMemberIds: oldRoom.vipMemberIds,
        memberIds: members.map((m) => m.userId).toList(),
        visitorIds: oldRoom.visitorIds,
        bulletin: oldRoom.bulletin,
        greetings: oldRoom.greetings,
        roomTheme: oldRoom.roomTheme,
        wordFilter: oldRoom.wordFilter,
        muteAll: oldRoom.muteAll,
        blockList: oldRoom.blockList,
        whoCanJoin: oldRoom.whoCanJoin,
        whoCanSpeak: oldRoom.whoCanSpeak,
        seatPermissions: oldRoom.seatPermissions,
        invitePermissions: oldRoom.invitePermissions,
        giftSettings: oldRoom.giftSettings,
        recommendationSettings: oldRoom.recommendationSettings,
        musicSettings: oldRoom.musicSettings,
        recordingSettings: oldRoom.recordingSettings,
        eventSettings: oldRoom.eventSettings,
        autoModeration: oldRoom.autoModeration,
        activeMode: oldRoom.activeMode,
        pinnedAnnouncement: oldRoom.pinnedAnnouncement,
        currentDebateRound: oldRoom.currentDebateRound,
      );
      
      rooms[idx] = updatedRoom;
    }
  }

  Future<void> enterRoom(String roomId, {String? password}) async {
    try {
      activeRoomId = roomId;

      // Clear previous room session chats from memory
      roomChats[roomId]?.clear();

      // Invoke join_room RPC function
      final response = await Supabase.instance.client.rpc('join_room', params: {
        'p_room_id': roomId,
        'p_password': password,
      });

      debugPrint('Join room response: $response');

      // Fetch initial room settings, members, permissions, chat messages
      await fetchRoomPermissions(roomId);
      await fetchRoomMembers(roomId);
      await fetchRoomChatMessages(roomId);
      await fetchRoomRequests(roomId);
      await fetchRoomPolls(roomId);

      // Emit join event with custom role greetings
      final profile = await UserProfileCacheManager.fetchUserProfile(currentUserId);
      final uName = profile?.username ?? 'Creania Student';
      final uLevel = profile?.level ?? 1;
      final vipLevel = profile?.vipLevel ?? 0;
      final nobleLevel = profile?.novelLevel ?? 0;

      final activeRoom = rooms.firstWhereOrNull((r) => r.id == roomId);
      final isOwner = activeRoom?.hostId == currentUserId;

      String greetingMsg = '👋 Welcome $uName! Enjoy your time in this arena.';
      if (isOwner) {
        greetingMsg = '🏠 Arena Owner $uName joined.';
      } else if (nobleLevel > 0) {
        greetingMsg = '👑 Noble $uName has arrived.';
      } else if (vipLevel > 0) {
        greetingMsg = '💎 VIP $uName entered the arena. Give them a warm welcome!';
      } else if (uLevel >= 50) {
        greetingMsg = '🔥 Level $uLevel $uName entered the arena.';
      }

      await emitRoomActivityEvent(
        roomId: roomId,
        eventType: 'room_join',
        userId: currentUserId,
        username: uName,
        message: greetingMsg,
        metadata: {
          'level': uLevel,
          'vip_level': vipLevel,
          'noble_level': nobleLevel,
        },
      );

      // Subscribe to real-time updates for this room
      subscribeToRoomRealtime(roomId);
      await fetchRoomProgression(roomId);
    } catch (e) {
      debugPrint('Error entering room: $e');
      Get.snackbar(
        'Join Failed',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      rethrow;
    }
  }

  Future<void> exitRoom(String roomId) async {
    try {
      // Gracefully vacate seat in DB if current user is sitting on one
      final seats = roomSeatsInfo[roomId];
      if (seats != null) {
        final seat = seats.firstWhereOrNull((s) => s['userId'] == currentUserId);
        if (seat != null) {
          final seatIdx = seat['seatIndex'] as int;
          await Supabase.instance.client.rpc('leave_room_seat', params: {
            'p_room_id': roomId,
            'p_seat_index': seatIdx,
          });
        }
      }

      activeRoomId = null;
      unsubscribeRoomRealtime();
      currentPermissions.clear();
      activeMembers.clear();
      activeRequests.clear();
      activePolls.clear();
      isMutedByModerator.value = false;
      roomChats[roomId]?.clear();

      final profile = await UserProfileCacheManager.fetchUserProfile(currentUserId);
      final uName = profile?.username ?? 'Creania Student';
      final exitMsgs = [
        '👋 $uName left the arena.',
        '🚪 $uName exited the arena.'
      ];
      final greetingMsg = exitMsgs[Random().nextInt(exitMsgs.length)];

      await emitRoomActivityEvent(
        roomId: roomId,
        eventType: 'room_leave',
        userId: currentUserId,
        username: uName,
        message: greetingMsg,
      );

      await Supabase.instance.client.rpc('leave_room', params: {
        'p_room_id': roomId,
      });
    } catch (e) {
      debugPrint('Error leaving room: $e');
    }
  }

  Future<void> fetchRoomPermissions(String roomId) async {
    try {
      final response = await Supabase.instance.client.rpc('get_room_permissions', params: {
        'p_room_id': roomId,
      });
      if (response != null) {
        final Map<String, bool> permissions = {};
        (response as Map<String, dynamic>).forEach((key, value) {
          permissions[key] = value == true;
        });
        currentPermissions.assignAll(permissions);
      }
    } catch (e) {
      debugPrint('Error fetching room permissions: $e');
    }
  }

  Future<void> fetchRoomMembers(String roomId) async {
    try {
      final response = await Supabase.instance.client
          .from('room_members')
          .select()
          .eq('room_id', roomId);
      
      final List<RoomMember> members = (response as List)
          .map((m) => RoomMember.fromJson(m))
          .toList();
      
      activeMembers.assignAll(members);

      // Enforce mute from backend
      final myMember = members.firstWhereOrNull((m) => m.userId == currentUserId);
      if (myMember != null) {
        isMutedByModerator.value = myMember.isMuted;
      }

      // Check if we are kicked/removed
      if (activeRoomId == roomId && !members.any((m) => m.userId == currentUserId)) {
        Get.back();
        Get.snackbar(
          'Removed from Room',
          'You have been kicked or banned from this room.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
      }

      syncRoomFromMembers(roomId, members);
    } catch (e) {
      debugPrint('Error fetching room members: $e');
    }
  }

  Future<void> fetchRoomChatMessages(String roomId) async {
    roomChats[roomId] = <RoomChatMessage>[].obs;
  }

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
        'event_id': DateTime.now().microsecondsSinceEpoch.toString(),
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

      await _roomActivityEventsChannel?.sendBroadcastMessage(
        event: 'room_activity_event',
        payload: payload,
      );

      _processActivityEventPayload(roomId, payload);
    } catch (e) {
      debugPrint('Error emitting room activity event: $e');
    }
  }

  void _processActivityEventPayload(String roomId, Map<String, dynamic> payload) {
    final eventId = payload['event_id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString();
    final eventType = payload['event_type'] as String? ?? 'activity';
    final senderId = payload['user_id'] as String?;
    final senderName = payload['username'] as String? ?? 'System';
    final message = payload['message'] as String? ?? '';
    final metadata = Map<String, dynamic>.from(payload['metadata'] ?? {});

    // Filter and queue real-time marquee announcements
    bool shouldAnnounce = false;
    if (eventType == 'room_join' || eventType == 'seat_join') {
      final vipLevel = int.tryParse(metadata['vip_level']?.toString() ?? '0') ?? 0;
      final nobleLevel = int.tryParse(metadata['noble_level']?.toString() ?? '0') ?? 0;
      if (vipLevel >= 5 || nobleLevel >= 2) {
        shouldAnnounce = true;
      }
    } else if (eventType == 'gift_sent') {
      final amount = int.tryParse(metadata['amount']?.toString() ?? '0') ?? 0;
      final isGold = metadata['is_gold'] == true;
      if (isGold && amount > 500) {
        shouldAnnounce = true;
      }
    }

    if (shouldAnnounce) {
      marqueeAnnouncementsQueue.add(message);
    }
    
    if (eventType == 'room_banner_changed') {
      Supabase.instance.client
          .from('rooms')
          .select('banner')
          .eq('id', roomId)
          .maybeSingle()
          .then((data) {
            if (data != null && data['banner'] != null) {
              final bUrl = data['banner'] as String;
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
                  avatar: old.avatar,
                  banner: bUrl,
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
            }
          });
    }

    // Formulate bottom toast notifications
    if (eventType == 'room_join' || eventType == 'room_leave' || eventType.startsWith('seat_')) {
      bottomSystemNotifications.add(message);
      activeSystemNotification.value = message;
    }

    // Push gift notifications
    if (eventType == 'gift_sent') {
      final amount = int.tryParse(metadata['amount']?.toString() ?? '1') ?? 1;
      final isGold = metadata['is_gold'] == true;
      final receiverName = metadata['receiver_name'] ?? 'someone';
      
      Future.microtask(() async {
        final senderProfile = senderId != null ? await UserProfileCacheManager.fetchUserProfile(senderId) : null;
        final senderAvatar = senderProfile?.avatar;

        String? receiverAvatar;
        final seats = roomSeatsInfo[roomId] ?? [];
        final targetSeat = seats.firstWhereOrNull((s) => s['name'] == receiverName);
        if (targetSeat != null && targetSeat['userId'] != null) {
          final receiverProfile = await UserProfileCacheManager.fetchUserProfile(targetSeat['userId']);
          receiverAvatar = receiverProfile?.avatar;
        }

        activeGiftNotification.value = {
          'senderId': senderId,
          'senderName': senderName,
          'senderAvatar': senderAvatar,
          'amount': amount,
          'isGold': isGold,
          'receiverName': receiverName,
          'receiverAvatar': receiverAvatar,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
      });
    }

    // Publish entrance events for entry animations
    if (eventType == 'room_join') {
      rxEntranceEvent.value = {
        'userId': senderId,
        'userName': senderName,
        'vip_level': metadata['vip_level'],
        'noble_level': metadata['noble_level'],
        'level': metadata['level'],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    }

    final systemMessage = RoomChatMessage(
      id: eventId,
      senderId: senderId ?? 'system',
      senderName: senderName,
      text: message,
      timestamp: payload['created_at'] != null ? DateTime.parse(payload['created_at'] as String) : DateTime.now(),
      isSystem: true,
      messageType: 'activity',
      eventType: eventType,
      vipLabel: metadata['vip_level']?.toString(),
      novelLabel: metadata['noble_level']?.toString(),
      senderLevel: metadata['level']?.toString(),
    );

    if (roomChats[roomId] == null) {
      roomChats[roomId] = <RoomChatMessage>[].obs;
    }
    
    roomChats[roomId]!.add(systemMessage);
    if (roomChats[roomId]!.length > 200) {
      roomChats[roomId]!.removeAt(0);
    }
  }

  Future<void> fetchRoomRequests(String roomId) async {
    try {
      final response = await Supabase.instance.client
          .from('room_requests')
          .select('*, profiles:user_id(username, avatar_url)')
          .eq('room_id', roomId)
          .eq('status', 'pending');
      
      activeRequests.assignAll(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint('Error fetching room requests: $e');
    }
  }

  Future<void> fetchRoomPolls(String roomId) async {
    try {
      final response = await Supabase.instance.client
          .from('room_polls')
          .select()
          .eq('room_id', roomId)
          .eq('is_active', true);
      
      activePolls.assignAll(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint('Error fetching room polls: $e');
    }
  }

  void subscribeToRoomsList() {
    if (_roomsListChannel != null) return;
    try {
      _roomsListChannel = Supabase.instance.client
          .channel('public:rooms_list')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'rooms',
            callback: (payload) {
              debugPrint('[RoomController] Realtime rooms table change: ${payload.eventType}');
              fetchRooms();
            },
          );
      _roomsListChannel?.subscribe();
      debugPrint('[RoomController] Subscribed to rooms table changes.');
    } catch (e) {
      debugPrint('[RoomController] Error subscribing to rooms list: $e');
    }
  }

  void subscribeToRoomRealtime(String roomId) {
    unsubscribeRoomRealtime();

    try {
      final client = Supabase.instance.client;

      _roomMembersChannel = client
          .channel('room_members:$roomId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_members',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) async {
              if (payload.eventType == PostgresChangeEvent.insert) {
                final newRecord = payload.newRecord;
                final String? uId = newRecord?['user_id'];
                if (uId != null && uId != currentUserId) {
                  animatingJoinUserIds.add(uId);
                  final profile = await UserProfileCacheManager.fetchUserProfile(uId);
                  final String uName = profile?.username ?? 'Creania Student';
                  final String? uAvatar = profile?.avatar;
                  try {
                    final custResponse = await Supabase.instance.client
                        .from('user_customizations')
                        .select('name')
                        .eq('user_id', uId)
                        .eq('type', 'entry_effect')
                        .eq('is_equipped', true)
                        .maybeSingle();
                    final String? entryEffect = custResponse != null ? custResponse['name'] : null;
                    entranceEvent.value = {
                      'userId': uId,
                      'userName': uName,
                      'avatarUrl': uAvatar,
                      'entryEffect': entryEffect,
                      'timestamp': DateTime.now().millisecondsSinceEpoch,
                    };
                  } catch (_) {
                    entranceEvent.value = {
                      'userId': uId,
                      'userName': uName,
                      'avatarUrl': uAvatar,
                      'entryEffect': null,
                      'timestamp': DateTime.now().millisecondsSinceEpoch,
                    };
                  }
                }
              }
              await fetchRoomMembers(roomId);
              await fetchRoomPermissions(roomId);
            },
          );
      _roomMembersChannel?.subscribe();

      _roomMessagesChannel = client
          .channel('room_messages:$roomId')
          .onBroadcast(
            event: 'chat_message',
            callback: (payload) {
              if (payload['sender_id'] == currentUserId) return; // avoid duplicate optimistic local messages

              final Map<String, List<String>> parsedReactions = {};
              if (payload['reactions'] != null) {
                final rawReactions = payload['reactions'] as Map<String, dynamic>;
                rawReactions.forEach((key, val) {
                  parsedReactions[key] = List<String>.from(val as List);
                });
              }

              final message = RoomChatMessage(
                id: payload['id'] as String,
                senderId: payload['sender_id'] as String,
                senderName: payload['sender_name'] as String,
                text: payload['text'] as String,
                senderRole: payload['sender_role'] as String?,
                senderAvatar: payload['sender_avatar'] as String?,
                timestamp: DateTime.parse(payload['timestamp'] as String),
                replyToMessageId: payload['reply_to_message_id'] as String?,
                senderLevel: payload['sender_level']?.toString(),
                vipLabel: payload['vip_label'] as String?,
                novelLabel: payload['novel_label'] as String?,
                communityTag: payload['community_tag'] as String?,
                roleTag: payload['role_tag'] as String?,
                isActiveSpeaker: payload['is_active_speaker'] == true,
                reactions: parsedReactions,
                avatarFrame: payload['avatar_frame'] as String?,
                nobleLabel: payload['noble_label'] as String?,
              );
              if (roomChats[roomId] == null) {
                roomChats[roomId] = <RoomChatMessage>[].obs;
              }
              roomChats[roomId]!.add(message);
            },
          )
          .onBroadcast(
            event: 'message_reaction',
            callback: (payload) {
              final msgId = payload['message_id'] as String?;
              final reactionType = payload['reaction_type'] as String?;
              final uId = payload['user_id'] as String?;
              if (msgId != null && reactionType != null && uId != null) {
                final chatList = roomChats[roomId];
                if (chatList != null) {
                  final idx = chatList.indexWhere((msg) => msg.id == msgId);
                  if (idx != -1) {
                    final msg = chatList[idx];
                    final currentReactions = Map<String, List<String>>.from(msg.reactions);
                    if (currentReactions[reactionType] == null) {
                      currentReactions[reactionType] = [];
                    }
                    if (!currentReactions[reactionType]!.contains(uId)) {
                      currentReactions[reactionType]!.add(uId);
                    } else {
                      currentReactions[reactionType]!.remove(uId);
                    }
                    chatList[idx] = msg.copyWith(reactions: currentReactions);
                  }
                }
              }
            },
          )
          .onBroadcast(
            event: 'delete_message',
            callback: (payload) {
              final messageId = payload['message_id'] as String?;
              if (messageId != null) {
                final chatList = roomChats[roomId];
                if (chatList != null) {
                  chatList.removeWhere((msg) => msg.id == messageId);
                }
              }
            },
          )
          .onBroadcast(
            event: 'typing_indicator',
            callback: (payload) {
              final username = payload['username'] as String?;
              final isTyping = payload['is_typing'] == true;
              if (username != null) {
                if (isTyping) {
                  if (!typingUsers.contains(username)) {
                    typingUsers.add(username);
                  }
                } else {
                  typingUsers.remove(username);
                }
              }
            },
          );
      _roomMessagesChannel?.subscribe();

      _roomRequestsChannel = client
          .channel('room_requests:$roomId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_requests',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) {
              fetchRoomRequests(roomId);
            },
          );
      _roomRequestsChannel?.subscribe();

      _roomPollsChannel = client
          .channel('room_polls:$roomId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_polls',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) {
              fetchRoomPolls(roomId);
            },
          );
      _roomPollsChannel?.subscribe();

      _roomProgressionChannel = client
          .channel('room_progression:$roomId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_level_progress',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) {
              if (payload.newRecord != null) {
                roomLevelProgresses[roomId] = RoomLevelProgress.fromJson(payload.newRecord);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_statistics',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) {
              if (payload.newRecord != null) {
                roomStats[roomId] = RoomStatistics.fromJson(payload.newRecord);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_seats',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) async {
              await fetchRoomProgression(roomId);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_seat_gifts',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) async {
              await fetchRoomProgression(roomId);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_daily_task_progress',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) async {
              await fetchRoomProgression(roomId);
            },
          );
      _roomProgressionChannel?.subscribe();

      _roomActivityEventsChannel = client
          .channel('room_activity_events:$roomId')
          .onBroadcast(
            event: 'room_activity_event',
            callback: (payload) {
              if (payload['user_id'] == currentUserId) return;
              _processActivityEventPayload(roomId, payload);
            },
          );
      _roomActivityEventsChannel?.subscribe();

    } catch (e) {
      debugPrint('Error subscribing to room realtime: $e');
    }
  }

  void unsubscribeRoomRealtime() {
    try {
      if (_roomMembersChannel != null) {
        Supabase.instance.client.removeChannel(_roomMembersChannel!);
        _roomMembersChannel = null;
      }
      if (_roomMessagesChannel != null) {
        Supabase.instance.client.removeChannel(_roomMessagesChannel!);
        _roomMessagesChannel = null;
      }
      if (_roomRequestsChannel != null) {
        Supabase.instance.client.removeChannel(_roomRequestsChannel!);
        _roomRequestsChannel = null;
      }
      if (_roomPollsChannel != null) {
        Supabase.instance.client.removeChannel(_roomPollsChannel!);
        _roomPollsChannel = null;
      }
      if (_roomProgressionChannel != null) {
        Supabase.instance.client.removeChannel(_roomProgressionChannel!);
        _roomProgressionChannel = null;
      }
      if (_roomActivityEventsChannel != null) {
        Supabase.instance.client.removeChannel(_roomActivityEventsChannel!);
        _roomActivityEventsChannel = null;
      }
    } catch (e) {
      debugPrint('Error unsubscribing: $e');
    }
  }

  @override
  void onClose() {
    unsubscribeRoomRealtime();
    if (_roomsListChannel != null) {
      Supabase.instance.client.removeChannel(_roomsListChannel!);
      _roomsListChannel = null;
    }
    super.onClose();
  }

  Future<void> raiseHand(String roomId) async {
    try {
      await Supabase.instance.client.rpc('request_speak', params: {
        'p_room_id': roomId,
      });
    } catch (e) {
      debugPrint('Error raising hand: $e');
    }
  }

  Future<void> moderateSpeakerRequest(String roomId, String userId, String action) async {
    try {
      await Supabase.instance.client.rpc('moderate_request', params: {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_action': action,
      });
    } catch (e) {
      debugPrint('Error moderating speaker request: $e');
      Get.snackbar(
        'Action Failed',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> moderateMuteUser(String roomId, String userId, bool mute) async {
    try {
      await Supabase.instance.client.rpc('moderate_user_mute', params: {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_mute': mute,
      });
    } catch (e) {
      debugPrint('Error muting user: $e');
      Get.snackbar('Mute Failed', e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> moderateKickUser(String roomId, String userId) async {
    try {
      await Supabase.instance.client.rpc('moderate_user_kick', params: {
        'p_room_id': roomId,
        'p_user_id': userId,
      });
    } catch (e) {
      debugPrint('Error kicking user: $e');
      Get.snackbar('Kick Failed', e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> moderateBanUser(String roomId, String userId, String reason, {String? duration}) async {
    try {
      await Supabase.instance.client.rpc('moderate_user_ban', params: {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_reason': reason,
        'p_duration': duration,
      });
    } catch (e) {
      debugPrint('Error banning user: $e');
      Get.snackbar('Ban Failed', e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> transferHost(String roomId, String newHostId) async {
    try {
      await Supabase.instance.client.rpc('transfer_room_host', params: {
        'p_room_id': roomId,
        'p_new_host_id': newHostId,
      });
    } catch (e) {
      debugPrint('Error transferring host: $e');
      Get.snackbar('Transfer Failed', e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> changeMemberRole(String roomId, String userId, String newRole) async {
    try {
      await Supabase.instance.client.rpc('change_member_role', params: {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_new_role': newRole,
      });
    } catch (e) {
      debugPrint('Error changing role: $e');
      Get.snackbar('Role Change Failed', e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> endRoom(String roomId) async {
    try {
      await Supabase.instance.client.rpc('end_room', params: {
        'p_room_id': roomId,
      });
      rooms.removeWhere((r) => r.id == roomId);
    } catch (e) {
      debugPrint('Error ending room: $e');
      Get.snackbar('End Room Failed', e.toString().replaceAll('Exception: ', ''));
    }
  }

  bool canEditRoom() => currentPermissions['can_edit_room'] ?? false;
  bool canDeleteRoom() => currentPermissions['can_delete_room'] ?? false;
  bool canInviteUsers() => currentPermissions['can_invite_users'] ?? false;
  bool canManageSpeakers() => currentPermissions['can_manage_speakers'] ?? false;
  bool canManageListeners() => currentPermissions['can_manage_listeners'] ?? false;
  bool canManageChat() => currentPermissions['can_manage_chat'] ?? false;
  bool canManageGifts() => currentPermissions['can_manage_gifts'] ?? false;
  bool canManagePolls() => currentPermissions['can_manage_polls'] ?? false;
  bool canRecordRoom() => currentPermissions['can_record_room'] ?? false;
  bool canTransferHost() => currentPermissions['can_transfer_host'] ?? false;
  bool canLockRoom() => currentPermissions['can_lock_room'] ?? false;
  bool canChangeSettings() => currentPermissions['can_change_settings'] ?? false;

  void _loadInitialRooms() {}
  Future<void> _saveRooms() async {}
  Future<void> _loadSavedRooms() async {}


  void changeUserRole(String roomId, String userId, String newRole) {
    String dbRole = newRole;
    if (newRole == 'Owner') dbRole = 'Host';
    else if (newRole == 'Co-owner') dbRole = 'Co-Host';
    else if (newRole == 'Admin') dbRole = 'Moderator';
    else if (newRole == 'Star Member') dbRole = 'Speaker';
    else if (newRole == 'Guest') dbRole = 'Listener';

    changeMemberRole(roomId, userId, dbRole);
  }

  void removeUserRole(String roomId, String userId) {
    changeUserRole(roomId, userId, 'Visitor');
    addSystemActivity(roomId, '🔄 $userId switched to Seat 0.', messageType: 'activity');
  }

  void toggleMuteAll(String roomId) {
    final int index = rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final old = rooms[index];
      final bool newMuteAll = !old.muteAll;
      
      rooms[index] = VoiceRoom(
        id: old.id,
        name: old.name,
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
        avatar: old.avatar,
        banner: old.banner,
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
        muteAll: newMuteAll,
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

      Get.snackbar(
        'Room Setting Changed',
        newMuteAll ? 'All speakers have been muted by management.' : 'Speakers can now unmute.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.withOpacity(0.8),
        colorText: Colors.white,
      );
      addSystemActivity(
        roomId,
        newMuteAll ? '🔒 Room has been locked.' : '🔓 Room has been unlocked.',
        messageType: 'activity',
      );
    }
  }

  void updateRoomSettings(
    String roomId, {
    String? name,
    String? description,
    String? bulletin,
    String? greetings,
    String? theme,
    String? whoCanJoin,
    String? whoCanSpeak,
    String? seatPermissions,
    String? invitePermissions,
    String? giftSettings,
    String? recommendationSettings,
    String? musicSettings,
    String? recordingSettings,
    String? eventSettings,
    String? autoModeration,
    String? wordFilter,
    String? activeMode,
    String? pinnedAnnouncement,
    String? avatar,
    String? roomCoverUrl,
    bool? coHostCanEditCover,
    bool? adminCanEditCover,
  }) {
    final int index = rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final old = rooms[index];
      rooms[index] = VoiceRoom(
        id: old.id,
        name: name ?? old.name,
        description: description ?? old.description,
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
        avatar: avatar ?? old.avatar,
        banner: old.banner,
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
        bulletin: bulletin ?? old.bulletin,
        greetings: greetings ?? old.greetings,
        roomTheme: theme ?? old.roomTheme,
        wordFilter: wordFilter ?? old.wordFilter,
        muteAll: old.muteAll,
        blockList: old.blockList,
        whoCanJoin: whoCanJoin ?? old.whoCanJoin,
        whoCanSpeak: whoCanSpeak ?? old.whoCanSpeak,
        seatPermissions: seatPermissions ?? old.seatPermissions,
        invitePermissions: invitePermissions ?? old.invitePermissions,
        giftSettings: giftSettings ?? old.giftSettings,
        recommendationSettings: recommendationSettings ?? old.recommendationSettings,
        musicSettings: musicSettings ?? old.musicSettings,
        recordingSettings: recordingSettings ?? old.recordingSettings,
        eventSettings: eventSettings ?? old.eventSettings,
        autoModeration: autoModeration ?? old.autoModeration,
        activeMode: activeMode ?? old.activeMode,
        pinnedAnnouncement: pinnedAnnouncement ?? old.pinnedAnnouncement,
        currentDebateRound: old.currentDebateRound,
        coHostCanEditCover: coHostCanEditCover ?? old.coHostCanEditCover,
        adminCanEditCover: adminCanEditCover ?? old.adminCanEditCover,
        roomCoverUrl: roomCoverUrl ?? old.roomCoverUrl,
      );

      if (bulletin != null || pinnedAnnouncement != null) {
        addSystemActivity(roomId, '📢 Host updated the room announcement.', messageType: 'activity');
      }
      if (eventSettings != null) {
        addSystemActivity(
          roomId,
          eventSettings == 'Enabled' ? '🎊 Room event has started.' : '✅ Room event has ended.',
          messageType: 'activity',
         );
      }
      
      Supabase.instance.client.from('rooms').update({
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (avatar != null) 'avatar': avatar,
        if (avatar != null) 'banner': avatar,
        if (roomCoverUrl != null) 'room_cover_url': roomCoverUrl,
        if (coHostCanEditCover != null) 'co_host_can_edit_cover': coHostCanEditCover,
        if (adminCanEditCover != null) 'admin_can_edit_cover': adminCanEditCover,
      }).eq('id', roomId).then((_) {
        debugPrint('Room settings updated in Supabase.');
      }).catchError((err) {
        debugPrint('Failed to update room settings in Supabase: $err');
      });

      Get.snackbar(
        'Success',
        'Room settings updated successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  Future<String?> uploadRoomCoverPhoto(String roomId, io.File file) async {
    try {
      final client = Supabase.instance.client;
      final fileExtension = file.path.split('.').last;
      final fileName = '${roomId}_cover_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      
      await client.storage.from('avatars').uploadBinary(
        fileName,
        await file.readAsBytes(),
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl = client.storage.from('avatars').getPublicUrl(fileName);
      
      await client.from('rooms').update({
        'avatar': publicUrl,
        'room_cover_url': publicUrl,
        'updated_by': currentUserId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
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
          roomCoverUrl: publicUrl,
          banner: old.banner,
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
          coHostCanEditCover: old.coHostCanEditCover,
          adminCanEditCover: old.adminCanEditCover,
          updatedBy: currentUserId,
          updatedAt: DateTime.now(),
        );
      }
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading room cover: $e');
      rethrow;
    }
  }

  Future<String?> createRoom({
    required String name,
    required String username,
    required String description,
    required String category,
    required String country,
    required String language,
    required List<String> tags,
    required List<String> rules,
    required String entryPermission,
    required bool isPermanent,
    String? avatar,
    String? banner,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc('create_room', params: {
        'p_name': name,
        'p_username': username,
        'p_description': description,
        'p_category': category,
        'p_country': country,
        'p_language': language,
        'p_tags': tags,
        'p_rules': rules,
        'p_entry_permission': entryPermission,
        'p_avatar': avatar,
        'p_banner': banner,
        'p_is_permanent': isPermanent,
      });
      final String roomId = response.toString();
      await fetchRooms(); // Refresh the list
      return roomId;
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return null;
    }
  }

  Future<String?> createTemporaryRoom({
    required String name,
    required String username,
    required String description,
    required String category,
    required String country,
    required String language,
    required List<String> tags,
    required List<String> rules,
    required String entryPermission,
    String? avatar,
    String? banner,
  }) async {
    final roomId = await createRoom(
      name: name,
      username: username,
      description: description,
      category: category,
      country: country,
      language: language,
      tags: tags,
      rules: rules,
      entryPermission: entryPermission,
      isPermanent: false,
      avatar: avatar,
      banner: banner,
    );
    if (roomId != null) {
      Get.snackbar(
        'Success',
        'Temporary Voice Room created successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
    return roomId;
  }

  Future<String?> createPermanentRoom({
    required String name,
    required String username,
    required String description,
    required String category,
    required String country,
    required String language,
    required List<String> tags,
    required List<String> rules,
    required String entryPermission,
    String? avatar,
    String? banner,
  }) async {
    final roomId = await createRoom(
      name: name,
      username: username,
      description: description,
      category: category,
      country: country,
      language: language,
      tags: tags,
      rules: rules,
      entryPermission: entryPermission,
      isPermanent: true,
      avatar: avatar,
      banner: banner,
    );
    if (roomId != null) {
      Get.snackbar(
        'Success',
        'Permanent Voice Room created successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
    return roomId;
  }

  Future<List<VoiceRoom>> searchRoomsRpc(String query) async {
    if (query.trim().isEmpty) return rooms;
    try {
      final response = await Supabase.instance.client
          .rpc('search_rooms', params: {'p_query': query});
      if (response != null && response is List) {
        return (response as List)
            .map((json) => VoiceRoom.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Search rooms failed: $e');
    }
    return rooms.where((r) =>
        r.name.toLowerCase().contains(query.toLowerCase()) ||
        r.username.toLowerCase().contains(query.toLowerCase()) ||
        r.id.toLowerCase().contains(query.toLowerCase())).toList();
  }

  Future<bool> sendGiftToRoom(
    String roomId, {
    required int giftCost,
    required String giftName,
    required String fromUserName,
    int count = 1,
    String? targetUserId,
    String? targetUserName,
    bool deductCoins = true,
  }) async {
    try {
      final room = rooms.firstWhereOrNull((r) => r.id == roomId);
      if (room == null) return false;

      String dbReceiverId = targetUserId ?? room.hostId;
      
      final RegExp uuidExp = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (!uuidExp.hasMatch(dbReceiverId)) {
        dbReceiverId = room.hostId;
      }

      if (!uuidExp.hasMatch(dbReceiverId)) {
        debugPrint('Host ID is not a valid UUID, mocking gift success');
        walletBalance.value = (walletBalance.value - (giftCost * count)).clamp(0, 999999);
        Get.snackbar(
          'Gift Sent! 🎁',
          '$fromUserName sent $giftName to ${targetUserName ?? 'Host'}!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
        );
        return true;
      }
      
      final response = await Supabase.instance.client.rpc('send_room_gift', params: {
        'p_room_id': roomId,
        'p_receiver_id': dbReceiverId,
        'p_gift_name': giftName,
        'p_coins_value': giftCost,
        'p_quantity': count,
      });

      if (response != null && response['success'] == true) {
        walletBalance.value = (response['remaining_balance'] as num).toInt();
        Get.snackbar(
          'Gift Sent! 🎁',
          '$fromUserName sent $giftName to ${targetUserName ?? 'Host'}!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sending gift: $e');
      Get.snackbar(
        'Gift Failed',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return false;
    }
  }

  // Buy role slots upgrade (using Gold Coins)
  bool buyRoleUpgrade(String roomId, String roleType, int cost) {
    if (walletBalance.value < cost) {
      Get.snackbar(
        'Insufficient Balance',
        'Upgrading role slots costs $cost coins. Current balance: ${walletBalance.value} coins.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return false;
    }

    walletBalance.value -= cost;

    final int index = rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final VoiceRoom oldRoom = rooms[index];
      int coSlots = oldRoom.extraCoOwnerSlots;
      int adminSlots = oldRoom.extraAdminSlots;
      int starSlots = oldRoom.extraStarMemberSlots;

      if (roleType == 'Co-owner') {
        coSlots++;
      } else if (roleType == 'Admin') {
        adminSlots++;
      } else if (roleType == 'Star Member') {
        starSlots++;
      }

      rooms[index] = VoiceRoom(
        id: oldRoom.id,
        name: oldRoom.name,
        description: oldRoom.description,
        hostId: oldRoom.hostId,
        communityId: oldRoom.communityId,
        type: oldRoom.type,
        isLive: oldRoom.isLive,
        participantCount: oldRoom.participantCount,
        maxParticipants: oldRoom.maxParticipants,
        speakerIds: oldRoom.speakerIds,
        listenerIds: oldRoom.listenerIds,
        recordingUrl: oldRoom.recordingUrl,
        allowRecording: oldRoom.allowRecording,
        allowScreenShare: oldRoom.allowScreenShare,
        createdAt: oldRoom.createdAt,
        startedAt: oldRoom.startedAt,
        endedAt: oldRoom.endedAt,
        avatar: oldRoom.avatar,
        banner: oldRoom.banner,
        ownerName: oldRoom.ownerName,
        category: oldRoom.category,
        country: oldRoom.country,
        language: oldRoom.language,
        tags: oldRoom.tags,
        rules: oldRoom.rules,
        level: oldRoom.level,
        xp: oldRoom.xp,
        badges: oldRoom.badges,
        totalMembers: oldRoom.totalMembers,
        totalFollowers: oldRoom.totalFollowers,
        totalGiftsReceived: oldRoom.totalGiftsReceived,
        isPermanent: oldRoom.isPermanent,
        entryPermission: oldRoom.entryPermission,
        coOwnerIds: oldRoom.coOwnerIds,
        adminIds: oldRoom.adminIds,
        starMemberIds: oldRoom.starMemberIds,
        extraCoOwnerSlots: coSlots,
        extraAdminSlots: adminSlots,
        extraStarMemberSlots: starSlots,
        founderId: oldRoom.founderId,
        managerIds: oldRoom.managerIds,
        moderatorIds: oldRoom.moderatorIds,
        hostIds: oldRoom.hostIds,
        mentorIds: oldRoom.mentorIds,
        judgeIds: oldRoom.judgeIds,
        performerIds: oldRoom.performerIds,
        eliteMemberIds: oldRoom.eliteMemberIds,
        vipMemberIds: oldRoom.vipMemberIds,
        memberIds: oldRoom.memberIds,
        visitorIds: oldRoom.visitorIds,
        bulletin: oldRoom.bulletin,
        greetings: oldRoom.greetings,
        roomTheme: oldRoom.roomTheme,
        wordFilter: oldRoom.wordFilter,
        muteAll: oldRoom.muteAll,
        blockList: oldRoom.blockList,
        whoCanJoin: oldRoom.whoCanJoin,
        whoCanSpeak: oldRoom.whoCanSpeak,
        seatPermissions: oldRoom.seatPermissions,
        invitePermissions: oldRoom.invitePermissions,
        giftSettings: oldRoom.giftSettings,
        recommendationSettings: oldRoom.recommendationSettings,
        musicSettings: oldRoom.musicSettings,
        recordingSettings: oldRoom.recordingSettings,
        eventSettings: oldRoom.eventSettings,
        autoModeration: oldRoom.autoModeration,
        activeMode: oldRoom.activeMode,
        pinnedAnnouncement: oldRoom.pinnedAnnouncement,
        currentDebateRound: oldRoom.currentDebateRound,
      );

      Get.snackbar(
        'Upgrade Unlocked! ⭐',
        'Purchased 1 extra $roleType slot for room ${oldRoom.id}.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
      );
      return true;
    }
    return false;
  }

  // Moderation: Mute User
  void toggleMuteUser(String roomId, String userId) {
    final list = mutedUsers[roomId] ?? [];
    if (list.contains(userId)) {
      list.remove(userId);
      addSystemActivity(roomId, '🔊 $userId was unmuted by Host.', messageType: 'activity');
    } else {
      list.add(userId);
      addSystemActivity(roomId, '🔇 $userId was muted by Host.', messageType: 'activity');
    }
    mutedUsers[roomId] = List<String>.from(list);
  }

  // Moderation: Ban User
  void banUser(String roomId, String userId) {
    final list = bannedUsers[roomId] ?? [];
    if (!list.contains(userId)) {
      list.add(userId);
      bannedUsers[roomId] = List<String>.from(list);
      
      final int index = rooms.indexWhere((r) => r.id == roomId);
      if (index != -1) {
        final old = rooms[index];
        final List<String> newSpeakers = List<String>.from(old.speakerIds)..remove(userId);
        final List<String> newListeners = List<String>.from(old.listenerIds)..remove(userId);
        
        rooms[index] = VoiceRoom(
          id: old.id,
          name: old.name,
          description: old.description,
          hostId: old.hostId,
          communityId: old.communityId,
          type: old.type,
          isLive: old.isLive,
          participantCount: max(0, old.participantCount - 1),
          maxParticipants: old.maxParticipants,
          speakerIds: newSpeakers,
          listenerIds: newListeners,
          recordingUrl: old.recordingUrl,
          allowRecording: old.allowRecording,
          allowScreenShare: old.allowScreenShare,
          createdAt: old.createdAt,
          startedAt: old.startedAt,
          endedAt: old.endedAt,
          avatar: old.avatar,
          banner: old.banner,
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
          blockList: List<String>.from(old.blockList)..add(userId),
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
      }

      addSystemActivity(roomId, '🚫 $userId was removed from the room.', messageType: 'activity');
    }
  }

  void banUserWithDuration(String roomId, String userId, String duration) {
    DateTime now = DateTime.now();
    DateTime? unbanTime;
    if (duration == '1 Day') {
      unbanTime = now.add(const Duration(days: 1));
    } else if (duration == '3 Days') {
      unbanTime = now.add(const Duration(days: 3));
    } else if (duration == '7 Days') {
      unbanTime = now.add(const Duration(days: 7));
    } else if (duration == '1 Month') {
      unbanTime = now.add(const Duration(days: 30));
    } else {
      unbanTime = null; // Forever
    }

    // Call base banUser to add them to lists
    banUser(roomId, userId);

    if (!roomBannedUsersDetailed.containsKey(roomId)) {
      roomBannedUsersDetailed[roomId] = <String, Map<String, dynamic>>{};
    }
    roomBannedUsersDetailed[roomId]![userId] = {
      'duration': duration,
      'timestamp': now,
      'unbanTime': unbanTime,
    };
  }

  void unbanUser(String roomId, String userId) {
    final list = bannedUsers[roomId] ?? [];
    list.remove(userId);
    bannedUsers[roomId] = List<String>.from(list);

    if (roomBannedUsersDetailed.containsKey(roomId)) {
      roomBannedUsersDetailed[roomId]!.remove(userId);
    }

    final int index = rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final old = rooms[index];
      final List<String> newBlockList = List<String>.from(old.blockList)..remove(userId);
      rooms[index] = VoiceRoom(
        id: old.id,
        name: old.name,
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
        avatar: old.avatar,
        banner: old.banner,
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
        blockList: newBlockList,
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
      addSystemActivity(roomId, '🔓 Room has been unlocked.', messageType: 'activity');
    }
  }

  // Add Member
  void followRoom(String roomId) {
    final int index = rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final old = rooms[index];
      rooms[index] = VoiceRoom(
        id: old.id,
        name: old.name,
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
        avatar: old.avatar,
        banner: old.banner,
        ownerName: old.ownerName,
        category: old.category,
        country: old.country,
        language: old.language,
        tags: old.tags,
        rules: old.rules,
        level: old.level,
        xp: old.xp,
        badges: old.badges,
        totalMembers: old.totalMembers + 1,
        totalFollowers: old.totalFollowers + 1,
        totalGiftsReceived: old.totalGiftsReceived,
        isPermanent: old.isPermanent,
        entryPermission: old.entryPermission,
        coOwnerIds: old.coOwnerIds,
        adminIds: old.adminIds,
        starMemberIds: old.starMemberIds,
        extraCoOwnerSlots: old.extraCoOwnerSlots,
        extraAdminSlots: old.extraAdminSlots,
        extraStarMemberSlots: old.extraStarMemberSlots,
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
      Get.snackbar('Room joined', 'You are now a member of ${old.name}', snackPosition: SnackPosition.BOTTOM);
    }
  }

  // Level Up logic helper
  int getXpForNextLevel(int currentLevel) {
    return currentLevel * 1000;
  }

  String getUserRole(VoiceRoom room, String userId) {
    if (room.hostId == userId || room.founderId == userId) return 'Owner';
    if (room.coOwnerIds.contains(userId)) return 'Co-owner';
    if (room.adminIds.contains(userId)) return 'Admin';
    if (room.starMemberIds.contains(userId)) return 'Star Member';
    return 'Guest';
  }

  int getRoleWeight(String role) {
    switch (role) {
      case 'Owner':
      case 'Founder':
        return 10;
      case 'Co-owner':
        return 9;
      case 'Admin':
        return 8;
      case 'Star Member':
        return 7;
      case 'Guest':
      default:
        return 1;
    }
  }

  void promoteRoomMember(String roomId, String userId, String role) {
    final idx = rooms.indexWhere((r) => r.id == roomId);
    if (idx != -1) {
      final old = rooms[idx];
      List<String> coOwners = List.from(old.coOwnerIds);
      List<String> admins = List.from(old.adminIds);

      coOwners.remove(userId);
      admins.remove(userId);

      if (role == 'Co-owner') {
        if (!coOwners.contains(userId)) coOwners.add(userId);
      } else if (role == 'Admin') {
        if (!admins.contains(userId)) admins.add(userId);
      }

      rooms[idx] = VoiceRoom(
        id: old.id,
        name: old.name,
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
        avatar: old.avatar,
        banner: old.banner,
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
        coOwnerIds: coOwners,
        adminIds: admins,
        starMemberIds: old.starMemberIds,
        extraCoOwnerSlots: old.extraCoOwnerSlots,
        extraAdminSlots: old.extraAdminSlots,
        extraStarMemberSlots: old.extraStarMemberSlots,
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
    }
  }

  OverlayEntry? _pipOverlayEntry;

  void showPipBubble(String roomId, String roomName, String avatarUrl) {
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
                  final currentUsername = UserProfileCacheManager.currentUser?.username ?? 'anurag_kumar';
                  Get.to(
                    () => VoiceRoomCallScreen(
                      roomId: roomId,
                      roomName: roomName,
                      userId: currentUid,
                      userName: currentUsername,
                      isHost: roomId == '#VX100001' || rooms.any((r) => r.id == roomId && r.hostId == currentUid),
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
                          border: Border.all(color: Colors.pinkAccent, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(27),
                          child: Image.network(
                            avatarUrl.isNotEmpty ? avatarUrl : 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.pinkAccent,
                              child: const Icon(Icons.music_note, color: Colors.white, size: 24),
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
                            border: Border.all(color: Colors.black87, width: 1.5),
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

    final overlayState = Navigator.of(Get.context!).overlay;
    if (overlayState != null) {
      overlayState.insert(_pipOverlayEntry!);
    }
  }

  void hidePipBubble() {
    if (_pipOverlayEntry != null) {
      _pipOverlayEntry!.remove();
      _pipOverlayEntry = null;
    }
  }

  Future<void> fetchRoomProgression(String roomId) async {
    try {
      final client = Supabase.instance.client;

      // 1. Fetch level progress
      final progressResp = await client
          .from('room_level_progress')
          .select()
          .eq('room_id', roomId)
          .maybeSingle();
      if (progressResp != null) {
        roomLevelProgresses[roomId] = RoomLevelProgress.fromJson(progressResp);
      }

      // 2. Fetch stats
      final statsResp = await client
          .from('room_statistics')
          .select()
          .eq('room_id', roomId)
          .maybeSingle();
      if (statsResp != null) {
        roomStats[roomId] = RoomStatistics.fromJson(statsResp);
      }

      // 3. Fetch tasks & progress
      final tasksResp = await client.from('room_daily_tasks').select();
      final progressListResp = await client
          .from('room_daily_task_progress')
          .select()
          .eq('room_id', roomId);

      final progressMap = {
        for (var p in progressListResp)
          p['task_key'] as String: p
      };

      final List<RoomDailyTask> mergedTasks = (tasksResp as List).map((t) {
        final key = t['task_key'] as String;
        final prog = progressMap[key];
        return RoomDailyTask(
          taskKey: key,
          description: t['description'] ?? '',
          targetValue: t['target_value'] ?? 0,
          currentValue: prog != null ? (prog['current_value'] ?? 0) : 0,
          taskPoints: t['task_points'] ?? 0,
          xpReward: t['xp_reward'] ?? 0,
          silverReward: t['silver_reward'] ?? 0,
          goldReward: t['gold_reward'] ?? 0,
          isCompleted: prog != null ? (prog['is_completed'] ?? false) : false,
        );
      }).toList();

      roomDailyTaskLists[roomId] = mergedTasks;

      // 4. Fetch seats & seat gifts
      final seatsResp = await client
          .from('room_seats')
          .select()
          .eq('room_id', roomId)
          .order('seat_index', ascending: true);

      final giftsResp = await client
          .from('room_seat_gifts')
          .select()
          .eq('room_id', roomId);

      final giftMap = {
        for (var g in giftsResp)
          g['seat_index'] as int: g['silver_gift_count'] as int
      };

      final List<Map<String, dynamic>> seatsList = [];
      for (var s in seatsResp as List) {
        final idx = s['seat_index'] as int;
        final uId = s['user_id'] as String?;
        final giftsCount = giftMap[idx] ?? 0;
        
        roomSeatGiftsCounters['$roomId:$idx'] = giftsCount;

        String? username;
        String? avatar;
        if (uId != null) {
          final profile = await UserProfileCacheManager.fetchUserProfile(uId);
          username = profile?.username;
          avatar = profile?.avatar;
        }

        seatsList.add({
          'seatIndex': idx,
          'role': s['role'] ?? 'Listener',
          'userId': uId,
          'name': s['username'] ?? username ?? 'Seat ${idx + 1}',
          'isSpeaking': s['is_speaking'] == true,
          'isLocked': s['is_locked'] ?? false,
          'silverGiftCount': giftsCount,
          'avatar': s['avatar'] ?? avatar,
          'avatarFrame': s['avatar_frame'] ?? 'Normal',
          'level': s['level'] ?? 1,
          'nobleLevel': s['noble_level'] ?? 0,
          'vipLevel': s['vip_level'] ?? 0,
          'micStatus': s['mic_status'] ?? 'unmuted',
          'seatTotalGifts': s['seat_total_gifts'] ?? 0,
          'seatTotalStars': s['seat_total_stars'] ?? 0,
          'lastGiftTime': s['last_gift_time'],
        });
      }

      roomSeatsInfo[roomId] = seatsList;
    } catch (e) {
      debugPrint('Error fetching room progression: $e');
    }
  }

  Future<void> heartbeatRoomMember(String roomId, bool isSpeaking) async {
    try {
      await Supabase.instance.client.rpc('heartbeat_room_member', params: {
        'p_room_id': roomId,
        'p_is_speaking': isSpeaking,
      });
    } catch (e) {
      debugPrint('Heartbeat failed: $e');
    }
  }

  Future<void> sendRoomGift(String roomId, int seatIndex, int amount, bool isGold) async {
    try {
      final profile = await UserProfileCacheManager.fetchUserProfile(currentUserId);
      final uName = profile?.username ?? 'Creania Student';

      await Supabase.instance.client.rpc('send_room_gift', params: {
        'p_room_id': roomId,
        'p_seat_index': seatIndex,
        'p_amount': amount,
        'p_is_gold': isGold,
      });

      // Find occupant of seat Index to output user names
      final seatInfo = roomSeatsInfo[roomId]?.firstWhereOrNull((s) => s['seatIndex'] == seatIndex);
      final String receiverName = seatInfo?['name'] ?? 'Seat #${seatIndex + 1}';

      final String message = '🎁 $uName sent $amount ${isGold ? 'Gold Coins' : 'Silver Coins'} to $receiverName.';

      await emitRoomActivityEvent(
        roomId: roomId,
        eventType: 'gift_sent',
        userId: currentUserId,
        username: uName,
        seatNumber: seatIndex + 1,
        message: message,
        metadata: {
          'amount': amount,
          'is_gold': isGold,
          'receiver_name': receiverName,
        },
      );

      await fetchRoomProgression(roomId);
    } catch (e) {
      Get.snackbar(
        'Gifting Error',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  Future<void> joinRoomSeat(String roomId, int seatIndex) async {
    try {
      // Optimistic local update to make seat occupancy feel instant
      final seats = roomSeatsInfo[roomId];
      if (seats != null) {
        final List<Map<String, dynamic>> updatedSeats = List.from(seats);
        
        // 1. Remove current user from any previous seat
        final prevIdx = updatedSeats.indexWhere((s) => s['userId'] == currentUserId);
        if (prevIdx != -1) {
          updatedSeats[prevIdx] = {
            ...updatedSeats[prevIdx],
            'userId': null,
            'name': 'Seat ${prevIdx + 1}',
            'avatar': null,
            'isSpeaking': false,
          };
        }
        
        // 2. Fetch current user profile details
        final profile = await UserProfileCacheManager.fetchUserProfile(currentUserId);
        
        // 3. Put current user on new seat
        final targetIdx = updatedSeats.indexWhere((s) => s['seatIndex'] == seatIndex);
        if (targetIdx != -1) {
          updatedSeats[targetIdx] = {
            ...updatedSeats[targetIdx],
            'userId': currentUserId,
            'name': profile?.username ?? 'Creania Student',
            'avatar': profile?.avatar,
            'level': profile?.level ?? 1,
            'vipLevel': profile?.vipLevel ?? 0,
            'nobleLevel': profile?.novelLevel ?? 0,
            'isSpeaking': false,
          };
        }
        
        roomSeatsInfo[roomId] = updatedSeats;
      }

      await Supabase.instance.client.rpc('join_room_seat', params: {
        'p_room_id': roomId,
        'p_seat_index': seatIndex,
      });

      final profile = await UserProfileCacheManager.fetchUserProfile(currentUserId);
      final uName = profile?.username ?? 'Creania Student';

      final seatJoinMsgs = [
        '🎤 $uName took Seat #${seatIndex + 1}.',
        '👑 $uName is now sitting on Seat #${seatIndex + 1}.',
        '🎙️ $uName joined Seat #${seatIndex + 1}.'
      ];
      final message = seatJoinMsgs[Random().nextInt(seatJoinMsgs.length)];

      await emitRoomActivityEvent(
        roomId: roomId,
        eventType: 'seat_join',
        userId: currentUserId,
        username: uName,
        seatNumber: seatIndex + 1,
        message: message,
        metadata: {
          'vip_level': profile?.vipLevel ?? 0,
          'noble_level': profile?.novelLevel ?? 0,
          'level': profile?.level ?? 1,
        },
      );

      await fetchRoomProgression(roomId);
    } catch (e) {
      debugPrint('Join seat failed: $e');
    }
  }

  Future<void> leaveRoomSeat(String roomId, int seatIndex) async {
    try {
      // Optimistic local update
      final seats = roomSeatsInfo[roomId];
      if (seats != null) {
        final List<Map<String, dynamic>> updatedSeats = List.from(seats);
        final targetIdx = updatedSeats.indexWhere((s) => s['seatIndex'] == seatIndex);
        if (targetIdx != -1) {
          updatedSeats[targetIdx] = {
            ...updatedSeats[targetIdx],
            'userId': null,
            'name': 'Seat ${seatIndex + 1}',
            'avatar': null,
            'isSpeaking': false,
          };
        }
        roomSeatsInfo[roomId] = updatedSeats;
      }

      await Supabase.instance.client.rpc('leave_room_seat', params: {
        'p_room_id': roomId,
        'p_seat_index': seatIndex,
      });

      final profile = await UserProfileCacheManager.fetchUserProfile(currentUserId);
      final uName = profile?.username ?? 'Creania Student';

      final seatLeaveMsgs = [
        '📤 $uName left Seat #${seatIndex + 1}.',
        '🎤 Seat #${seatIndex + 1} is now available.',
        '🚪 $uName left the microphone.'
      ];
      final message = seatLeaveMsgs[Random().nextInt(seatLeaveMsgs.length)];

      await emitRoomActivityEvent(
        roomId: roomId,
        eventType: 'seat_leave',
        userId: currentUserId,
        username: uName,
        seatNumber: seatIndex + 1,
        message: message,
      );

      await fetchRoomProgression(roomId);
    } catch (e) {
      debugPrint('Leave seat failed: $e');
    }
  }

  Future<String?> uploadRoomBanner(String roomId, io.File file) async {
    try {
      final client = Supabase.instance.client;
      final fileExtension = file.path.split('.').last;
      final fileName = '${roomId}_banner_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      
      await client.storage.from('banners').uploadBinary(
        fileName,
        await file.readAsBytes(),
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl = client.storage.from('banners').getPublicUrl(fileName);
      
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
      
      final profile = await UserProfileCacheManager.fetchUserProfile(currentUserId);
      final uName = profile?.username ?? 'Creania Student';
      await emitRoomActivityEvent(
        roomId: roomId,
        eventType: 'room_banner_changed',
        userId: currentUserId,
        username: uName,
        message: '🖼️ $uName updated the room banner!',
      );

      await fetchRoomProgression(roomId);
      
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading room banner: $e');
      Get.snackbar('Upload Failed', e.toString());
      return null;
    }
  }

  Future<void> sendRoomBroadcastMessage(String roomId, String text) async {
    try {
      final profile = await UserProfileCacheManager.fetchUserProfile(currentUserId);
      final uName = profile?.username ?? 'Creania Student';

      final seatsList = roomSeatsInfo[roomId] ?? [];
      final mySeat = seatsList.firstWhereOrNull((s) => s['userId'] == currentUserId);
      String role = 'Audience';
      if (mySeat != null) {
        final seatIndex = mySeat['seatIndex'] as int;
        role = seatIndex == 0 ? 'Host' : (seatIndex == 1 ? 'Co-Host' : 'Speaker');
      }

      String? equippedFrame;
      String? customTitle;
      try {
        final custResponse = await Supabase.instance.client
            .from('user_customizations')
            .select('name, type')
            .eq('user_id', currentUserId)
            .eq('is_equipped', true);
        if (custResponse != null) {
          for (final item in custResponse) {
            if (item['type'] == 'avatar_frame') {
              equippedFrame = item['name'] as String?;
            } else if (item['type'] == 'custom_title') {
              customTitle = item['name'] as String?;
            }
          }
        }
      } catch (_) {}

      final payload = {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'sender_id': currentUserId,
        'sender_name': uName,
        'text': text,
        'sender_role': role,
        'sender_avatar': profile?.avatar,
        'timestamp': DateTime.now().toIso8601String(),
        'sender_level': profile?.level?.toString() ?? '1',
        'vip_label': (profile?.vipLevel ?? 0) > 0 ? 'VIP ${profile?.vipLevel}' : null,
        'novel_label': (profile?.novelLevel ?? 0) > 0 ? 'Novel ${profile?.novelLevel}' : null,
        'avatar_frame': equippedFrame,
        'noble_label': (profile?.vipLevel ?? 0) > 0 ? 'Noble ${profile?.vipLevel}' : null,
      };

      // Add to local chat list immediately for optimistic UI rendering
      final localMessage = RoomChatMessage(
        id: payload['id'] as String,
        senderId: currentUserId,
        senderName: uName,
        text: text,
        senderRole: role,
        senderAvatar: profile?.avatar,
        timestamp: DateTime.now(),
        senderLevel: payload['sender_level'],
        vipLabel: payload['vip_label'],
        novelLabel: payload['novel_label'],
        avatarFrame: equippedFrame,
        nobleLabel: payload['noble_label'],
      );

      if (roomChats[roomId] == null) {
        roomChats[roomId] = <RoomChatMessage>[].obs;
      }
      roomChats[roomId]!.add(localMessage);

      // Broadcast to channel
      await _roomMessagesChannel?.sendBroadcastMessage(
        event: 'chat_message',
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error sending broadcast message: $e');
    }
  }

  Future<void> sendRoomReactionBroadcast(String roomId, String messageId, String reactionType) async {
    try {
      final payload = {
        'message_id': messageId,
        'reaction_type': reactionType,
        'user_id': currentUserId,
      };

      final chatList = roomChats[roomId];
      if (chatList != null) {
        final idx = chatList.indexWhere((msg) => msg.id == messageId);
        if (idx != -1) {
          final msg = chatList[idx];
          final currentReactions = Map<String, List<String>>.from(msg.reactions);
          if (currentReactions[reactionType] == null) {
            currentReactions[reactionType] = [];
          }
          if (!currentReactions[reactionType]!.contains(currentUserId)) {
            currentReactions[reactionType]!.add(currentUserId);
          } else {
            currentReactions[reactionType]!.remove(currentUserId);
          }
          chatList[idx] = msg.copyWith(reactions: currentReactions);
        }
      }

      await _roomMessagesChannel?.sendBroadcastMessage(
        event: 'message_reaction',
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error sending reaction broadcast: $e');
    }
  }
}

// Interactive level up dialog widget
class LevelUpDialog extends StatelessWidget {
  final String roomId;
  final String roomName;
  final int oldLevel;
  final int newLevel;

  const LevelUpDialog({
    Key? key,
    required this.roomId,
    required this.roomName,
    required this.oldLevel,
    required this.newLevel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.amber, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.stars,
              color: Colors.amber,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              'ROOM LEVEL UP! 🎉',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ) ?? const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              roomName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ) ?? const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLevelCircle(context, oldLevel.toString(), 'Level'),
                const SizedBox(width: 16),
                const Icon(Icons.arrow_forward, color: Colors.white54, size: 28),
                const SizedBox(width: 16),
                _buildLevelCircle(context, newLevel.toString(), 'Level', isNew: true),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'New role slots and entry permissions have been unlocked for this room!',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text(
                'Awesome!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCircle(BuildContext context, String text, String label, {bool isNew = false}) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isNew ? Colors.amber : Colors.white10,
            border: Border.all(
              color: isNew ? Colors.amberAccent : Colors.white24,
              width: 2,
            ),
            boxShadow: isNew
                ? [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.4),
                      blurRadius: 10,
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isNew ? Colors.black87 : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

