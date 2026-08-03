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
import 'voice/room_voice_manager.dart';
import 'voice/voice_controller.dart';

import 'store_controller.dart';
import 'user_progress_sync_service.dart';
import 'user_profile_cache_manager.dart';
import 'progression_controller.dart';
import 'chat_socket_service.dart';
import 'network_connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user_model.dart';
import '../models/gift_animation_metadata.dart';
import '../widgets/gift_animation_overlay.dart';

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

class RoomController extends GetxController with WidgetsBindingObserver {
  static RoomController get to => Get.find<RoomController>();
  static String get currentUserId => UserProfileCacheManager.currentUserId;

  String? activeRoomId;

  RxInt get walletBalance => Get.find<StoreController>().coinsBalance;
  final RxList<VoiceRoom> rooms = <VoiceRoom>[].obs;

  // New reactive variables for active room state
  final RxList<RoomMember> activeMembers = <RoomMember>[].obs;
  final RxList<Map<String, dynamic>> activeRequests =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> activePolls = <Map<String, dynamic>>[].obs;
  final RxMap<String, bool> currentPermissions = <String, bool>{}.obs;
  final RxBool isMutedByModerator = false.obs;
  final RxList<String> typingUsers = <String>[].obs;
  final RxList<String> animatingJoinUserIds = <String>[].obs;
  final RxMap<String, dynamic> entranceEvent = <String, dynamic>{}.obs;
  final Rxn<Map<String, dynamic>> rxEntranceEvent = Rxn<Map<String, dynamic>>();

  // Room Progression System states
  final RxMap<String, RoomLevelProgress> roomLevelProgresses =
      <String, RoomLevelProgress>{}.obs;
  final RxMap<String, RoomStatistics> roomStats =
      <String, RoomStatistics>{}.obs;
  final RxMap<String, List<RoomDailyTask>> roomDailyTaskLists =
      <String, List<RoomDailyTask>>{}.obs;
  final RxMap<String, List<Map<String, dynamic>>> roomSeatsInfo =
      <String, List<Map<String, dynamic>>>{}.obs;
  final RxMap<String, int> roomSeatGiftsCounters =
      <String, int>{}.obs; // key: room_id:seat_index -> silver_gift_count
  final RxList<String> marqueeAnnouncementsQueue = <String>[].obs;
  final Rxn<GiftAnimationEvent> activeGiftAnimation = Rxn<GiftAnimationEvent>();

  void triggerGiftAnimation(GiftAnimationEvent event) {
    activeGiftAnimation.value = event;
  }

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
  // roomId -> list of chat muted user IDs
  final RxMap<String, List<String>> mutedChatUsers =
      <String, List<String>>{}.obs;
  // roomId -> list of banned user IDs
  final RxMap<String, List<String>> bannedUsers = <String, List<String>>{}.obs;

  // roomId -> { userId -> { 'duration': String, 'timestamp': DateTime, 'unbanTime': DateTime? } }
  final RxMap<String, Map<String, Map<String, dynamic>>>
      roomBannedUsersDetailed =
      <String, Map<String, Map<String, dynamic>>>{}.obs;

  // Favorites and Recents tracking for discovery
  final RxList<String> favoriteRoomIds = <String>[].obs;
  final RxList<String> recentRoomIds = <String>[].obs;

  // Room Chat messages (roomId -> list of messages)
  final RxMap<String, RxList<RoomChatMessage>> roomChats =
      <String, RxList<RoomChatMessage>>{}.obs;
  final Rxn<Map<String, dynamic>> activeGiftNotification =
      Rxn<Map<String, dynamic>>();
  final RxList<String> bottomSystemNotifications = <String>[].obs;
  final RxnString activeSystemNotification = RxnString();
  final RxMap<String, bool> roomActivityQueuesBusy = <String, bool>{}.obs;
  final RxMap<String, List<Map<String, dynamic>>> roomActivityQueues =
      <String, List<Map<String, dynamic>>>{}.obs;

  Timer? _progressionTimer;
  int _minutesInRoom = 0;

  void startProgressionTimer(String roomId) {
    _progressionTimer?.cancel();
    _minutesInRoom = 0;
    _progressionTimer =
        Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (activeRoomId != roomId) {
        timer.cancel();
        return;
      }

      // Determine if sitting on a seat (hosting/co-hosting)
      bool isSitting = false;
      final seats = roomSeatsInfo[roomId];
      if (seats != null) {
        isSitting = seats.any((s) => s['userId'] == currentUserId);
      }

      try {
        final progCtrl = Get.put(ProgressionController());
        if (isSitting) {
          await progCtrl.triggerXpEvent('room_hosted_minute');
        } else {
          await progCtrl.triggerXpEvent('room_joined_minute');
        }
      } catch (e) {
        debugPrint('RoomController progression timer error: $e');
      }

      _minutesInRoom++;
    });
  }

  void stopProgressionTimer() {
    _progressionTimer?.cancel();
    _progressionTimer = null;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _loadCachedRooms();
    fetchRooms();
    subscribeToRoomsList();
    if (Get.isRegistered<NetworkConnectivityService>()) {
      NetworkConnectivityService.to.addReconnectedCallback(() {
        debugPrint('[RoomController] Network restored. Auto-fetching rooms.');
        fetchRooms(forceRefresh: true);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      if (activeRoomId != null) {
        _cleanupLocalResources();
      }
    }
  }

  void _cleanupLocalResources() {
    try {
      final roomId = activeRoomId;
      if (roomId != null) {
        final seats = roomSeatsInfo[roomId];
        if (seats != null) {
          final seat =
              seats.firstWhereOrNull((s) => s['userId'] == currentUserId);
          if (seat != null) {
            final seatIdx = seat['seatIndex'] as int;
            Supabase.instance.client
                .rpc('leave_room_seat', params: {
                  'p_room_id': roomId,
                  'p_seat_index': seatIdx,
                })
                .then((_) => null)
                .catchError((_) => null);
          }
        }

        Supabase.instance.client
            .rpc('leave_room', params: {
              'p_room_id': roomId,
            })
            .then((_) => null)
            .catchError((_) => null);
      }

      RoomVoiceManager().leaveRoom();

      activeRoomId = null;
      unsubscribeRoomRealtime();
      currentPermissions.clear();
      activeMembers.clear();
      activeRequests.clear();
      activePolls.clear();
      isMutedByModerator.value = false;
      stopProgressionTimer();
    } catch (e) {
      debugPrint('Error in _cleanupLocalResources: $e');
    }
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
          final String keyword =
              isEntry ? ' entered the room.' : ' left the room.';
          final String emoji = isEntry ? '🟢 ' : '👋 ';

          // Clean names
          final lastClean =
              last.text.replaceFirst(emoji, '').replaceFirst(keyword, '');
          final newClean =
              message.text.replaceFirst(emoji, '').replaceFirst(keyword, '');

          // Get names set
          final Set<String> names = lastClean.split(', ').toSet();
          if (!names.contains(newClean)) {
            names.add(newClean);
            final updatedText = '$emoji${names.join(', ')}$keyword';
            messages[messages.length - 1] = last.copyWith(
                text: updatedText, repeatCount: last.repeatCount + 1);
            return;
          } else {
            // Already contains name, merge by incrementing repeat count or just ignore
            messages[messages.length - 1] =
                last.copyWith(repeatCount: last.repeatCount + 1);
            return;
          }
        }

        // 2. Merge consecutive identical gift messages
        // Format: "🎁 {Username} sent {Gift Name} × {Count} to {Receiver}."
        if (message.text.startsWith('🎁') && last.text.startsWith('🎁')) {
          final giftRegex =
              RegExp(r'^🎁\s+(.*?)\s+sent\s+(.*?)\s+×\s+(\d+)\s+to\s+(.*?)\.$');
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

            if (senderLast == senderNew &&
                giftLast == giftNew &&
                receiverLast == receiverNew) {
              final totalCount = countLast + countNew;
              final updatedText =
                  '🎁 $senderNew sent $giftNew × $totalCount to $receiverNew.';
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
      // Session-based message deletion, broadcast to other users
      await _roomMessagesChannel?.sendBroadcastMessage(
        event: 'delete_message',
        payload: {'message_id': messageId},
      );
      roomChats[roomId]?.removeWhere((msg) => msg.id == messageId);
    } catch (e) {
      debugPrint('Error deleting room message: $e');
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
      final msgId = DateTime.now().microsecondsSinceEpoch.toString();

      // Resolve avatar frame if available in rxCache
      final u = UserProfileCacheManager.rxCache[uid];
      final avatarFrame = u?.avatarFrame;

      final payload = {
        'id': msgId,
        'sender_id': uid,
        'sender_name': senderName ?? 'Creania Student',
        'text': text,
        'sender_role': senderRole ?? 'Listener',
        'sender_avatar': senderAvatar,
        'timestamp': DateTime.now().toIso8601String(),
        'sender_level': senderLevel ?? '1',
        'vip_label': vipLabel,
        'novel_label': novelLabel,
        'community_tag': communityTag,
        'role_tag': roleTag,
        'is_active_speaker': isActiveSpeaker,
        'reply_to_message_id': replyToMessageId,
        'avatar_frame': avatarFrame,
      };

      // Add to local chat list immediately for optimistic UI rendering
      final localMessage = RoomChatMessage(
        id: msgId,
        senderId: uid,
        senderName: senderName ?? 'Creania Student',
        text: text,
        senderRole: senderRole ?? 'Listener',
        senderAvatar: senderAvatar,
        timestamp: DateTime.now(),
        replyToMessageId: replyToMessageId,
        senderLevel: senderLevel ?? '1',
        vipLabel: vipLabel,
        novelLabel: novelLabel,
        communityTag: communityTag,
        roleTag: roleTag,
        isActiveSpeaker: isActiveSpeaker,
        avatarFrame: avatarFrame,
      );

      if (roomChats[roomId] == null) {
        roomChats[roomId] = <RoomChatMessage>[].obs;
      }
      roomChats[roomId]!.add(localMessage);

      // Broadcast message via Supabase Realtime Broadcast Channel
      await _roomMessagesChannel?.sendBroadcastMessage(
        event: 'chat_message',
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error sending broadcast room message: $e');
    }
  }

  Future<void> setTypingStatus(String roomId, bool isTyping) async {
    try {
      final username =
          UserProfileCacheManager.currentUser?.username ?? 'Creania Student';
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

  bool _isFetchingRooms = false;

  Future<void> _loadCachedRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedJson = prefs.getString('cached_voice_rooms_json');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List list = jsonDecode(cachedJson);
        final List<VoiceRoom> loaded = list.map((item) => VoiceRoom.fromJson(item)).toList();
        if (loaded.isNotEmpty && rooms.isEmpty) {
          rooms.assignAll(loaded);
          debugPrint('[RoomController] Loaded ${loaded.length} rooms from local cache.');
        }
      }
    } catch (e) {
      debugPrint('[RoomController] Error loading cached rooms: $e');
    }
  }

  Future<void> fetchRooms({bool forceRefresh = false}) async {
    if (_isFetchingRooms && !forceRefresh) return;
    _isFetchingRooms = true;

    try {
      final response = await Supabase.instance.client
          .from('rooms')
          .select(
              '*, profiles:host_id(id, username, avatar_url, avatar_frame, level, vip_level, novel_level)')
          .or('status.eq.live,status.eq.scheduled')
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      final List<VoiceRoom> loaded = [];
      final List<Map<String, dynamic>> rawList = [];

      for (final item in response as List) {
        if (item is Map<String, dynamic>) {
          rawList.add(item);
        }
        loaded.add(VoiceRoom.fromJson(item));
        final hostData = item['profiles'];
        if (hostData != null &&
            hostData is Map<String, dynamic> &&
            hostData['id'] != null) {
          try {
            final userObj = User.fromJson(hostData);
            UserProfileCacheManager.rxCache[userObj.id] = userObj;
          } catch (pe) {
            debugPrint('Error parsing host profile in fetchRooms: $pe');
          }
        }
      }

      rooms.assignAll(loaded);

      // Save to local cache asynchronously
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_voice_rooms_json', jsonEncode(rawList));
      } catch (ce) {
        debugPrint('[RoomController] Cache save error: $ce');
      }
    } catch (e) {
      debugPrint('Error fetching rooms: $e');
      // If network failed and list is empty, attempt to load from local cache
      if (rooms.isEmpty) {
        await _loadCachedRooms();
      }
    } finally {
      _isFetchingRooms = false;
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
          .select(
              '*, profiles:host_id(id, username, avatar_url, avatar_frame, level, vip_level, novel_level)')
          .or('id.eq.${query.trim()},name.ilike.%$query%')
          .order('created_at', ascending: false);

      final List<VoiceRoom> loaded = [];
      for (final item in response as List) {
        loaded.add(VoiceRoom.fromJson(item));
        final hostData = item['profiles'];
        if (hostData != null &&
            hostData is Map<String, dynamic> &&
            hostData['id'] != null) {
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

      final String hostId =
          members.firstWhereOrNull((m) => m.role == 'Host')?.userId ??
              oldRoom.hostId;
      final List<String> coOwnerIds = members
          .where((m) => m.role == 'Co-Host')
          .map((m) => m.userId)
          .toList();
      final List<String> adminIds = members
          .where((m) => m.role == 'Moderator')
          .map((m) => m.userId)
          .toList();
      final List<String> starMemberIds = members
          .where((m) => m.role == 'Speaker')
          .map((m) => m.userId)
          .toList();

      final List<String> speakerIds = [hostId, ...coOwnerIds, ...starMemberIds];
      final List<String> listenerIds = members
          .where((m) =>
              m.role == 'Moderator' ||
              m.role == 'Listener' ||
              m.role == 'Guest')
          .map((m) => m.userId)
          .toList();

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
      // Rule 3: One Account = One Room — Auto-leave previous room cleanly if currently active in another
      if (activeRoomId != null && activeRoomId != roomId) {
        debugPrint('[RoomController] Auto-leaving previous active room $activeRoomId before entering $roomId');
        await exitRoom(activeRoomId!);
      }

      activeRoomId = roomId;

      // Clear previous room session chats and notifications from memory
      roomChats[roomId]?.clear();
      bottomSystemNotifications.clear();
      marqueeAnnouncementsQueue.clear();
      activeSystemNotification.value = null;

      // Invoke join_room RPC function
      final response = await Supabase.instance.client.rpc('join_room', params: {
        'p_room_id': roomId,
        'p_password': password,
      });

      debugPrint('Join room response: $response');

      // Fetch initial room settings, members, permissions, and profile in parallel (Skip DB chat history query)
      final parallelResults = await Future.wait<dynamic>([
        fetchRoomPermissions(roomId),
        fetchRoomMembers(roomId),
        fetchRoomRequests(roomId),
        fetchRoomPolls(roomId),
        UserProfileCacheManager.fetchUserProfile(currentUserId),
      ]);

      final profile = parallelResults[4] as User?;
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
        greetingMsg =
            '💎 VIP $uName entered the arena. Give them a warm welcome!';
      } else if (uLevel >= 50) {
        greetingMsg = '🔥 Level $uLevel $uName entered the arena.';
      }

      String? equippedEntryEffect;
      try {
        if (Get.isRegistered<CustomizationController>()) {
          equippedEntryEffect = Get.find<CustomizationController>().activeEntryEffect.value;
        }
      } catch (_) {}

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
          'entry_effect': equippedEntryEffect,
        },
      );

      // Subscribe to real-time updates for this room
      subscribeToRoomRealtime(roomId);
      await fetchRoomProgression(roomId);
      startProgressionTimer(roomId);

      try {
        ChatSocketService.to.emitRoomJoinStatus(roomId);
      } catch (err) {
        debugPrint('Socket join status notify failed: $err');
      }
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
      // Rule 10: Room Exit Cleanup — Leave voice channel and stop mic stream
      try {
        await RoomVoiceManager().leaveRoom();
      } catch (ve) {
        debugPrint('[RoomController] Voice manager leaveRoom error: $ve');
      }

      stopProgressionTimer();
      // Gracefully vacate seat in DB if current user is sitting on one
      final seats = roomSeatsInfo[roomId];
      if (seats != null) {
        final seat =
            seats.firstWhereOrNull((s) => s['userId'] == currentUserId);
        if (seat != null) {
          final seatIdx = seat['seatIndex'] as int;
          await Supabase.instance.client.rpc('leave_room_seat', params: {
            'p_room_id': roomId,
            'p_seat_index': seatIdx,
          });
        }
      }

      try {
        ChatSocketService.to.emitRoomLeaveStatus(roomId);
      } catch (err) {
        debugPrint('Socket leave status notify failed: $err');
      }

      activeRoomId = null;
      unsubscribeRoomRealtime();
      currentPermissions.clear();
      activeMembers.clear();
      activeRequests.clear();
      activePolls.clear();
      isMutedByModerator.value = false;
      roomChats[roomId]?.clear();

      final profile =
          await UserProfileCacheManager.fetchUserProfile(currentUserId);
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
      final response =
          await Supabase.instance.client.rpc('get_room_permissions', params: {
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

      final List<RoomMember> members =
          (response as List).map((m) => RoomMember.fromJson(m)).toList();

      activeMembers.assignAll(members);

      // Enforce mute from backend
      final myMember =
          members.firstWhereOrNull((m) => m.userId == currentUserId);
      if (myMember != null) {
        isMutedByModerator.value = myMember.isMuted;
      }

      // Check if we are kicked/removed
      if (activeRoomId == roomId &&
          !members.any((m) => m.userId == currentUserId)) {
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
    // Session-based chats, do not fetch history from database
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

  void _processActivityEventPayload(
      String roomId, Map<String, dynamic> payload) {
    final eventId = payload['event_id'] as String? ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final eventType = payload['event_type'] as String? ?? 'activity';
    final senderId = payload['user_id'] as String?;
    final senderName = payload['username'] as String? ?? 'System';
    final message = payload['message'] as String? ?? '';
    final metadata = Map<String, dynamic>.from(payload['metadata'] ?? {});

    // Filter and queue real-time marquee announcements
    bool shouldAnnounce = false;
    if (eventType == 'room_join' || eventType == 'seat_join') {
      final vipLevel =
          int.tryParse(metadata['vip_level']?.toString() ?? '0') ?? 0;
      final nobleLevel =
          int.tryParse(metadata['noble_level']?.toString() ?? '0') ?? 0;
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
    if (eventType == 'room_join' ||
        eventType == 'room_leave' ||
        eventType.startsWith('seat_')) {
      bottomSystemNotifications.add(message);
      activeSystemNotification.value = message;
    }

    // Push gift notifications
    if (eventType == 'gift_sent') {
      final amount = int.tryParse(metadata['amount']?.toString() ?? '1') ?? 1;
      final isGold = metadata['is_gold'] == true;
      final receiverName = metadata['receiver_name'] ?? 'someone';
      final giftId = metadata['gift_id'] ?? metadata['giftId'];
      final giftName = metadata['gift_name'] ?? metadata['giftName'] ?? 'Gift';
      final giftIcon = metadata['gift_icon'] ?? metadata['icon'] ?? GiftMetadataRegistry.getMetadata(giftId ?? giftName).giftIcon;

      Future.microtask(() async {
        final senderProfile = senderId != null
            ? await UserProfileCacheManager.fetchUserProfile(senderId)
            : null;
        final senderAvatar = senderProfile?.avatar;

        String? receiverAvatar;
        final seats = roomSeatsInfo[roomId] ?? [];
        final targetSeat =
            seats.firstWhereOrNull((s) => s['name'] == receiverName);
        if (targetSeat != null && targetSeat['userId'] != null) {
          final receiverProfile =
              await UserProfileCacheManager.fetchUserProfile(
                  targetSeat['userId']);
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
          'gift_id': giftId,
          'giftId': giftId,
          'gift_name': giftName,
          'giftName': giftName,
          'gift_icon': giftIcon,
          'giftIcon': giftIcon,
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
        'entry_effect': metadata['entry_effect'],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    }

    final systemMessage = RoomChatMessage(
      id: eventId,
      senderId: senderId ?? 'system',
      senderName: senderName,
      text: message,
      timestamp: payload['created_at'] != null
          ? DateTime.parse(payload['created_at'] as String)
          : DateTime.now(),
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
              debugPrint(
                  '[RoomController] Realtime rooms table change: ${payload.eventType}');
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

      _roomMembersChannel =
          client.channel('room_members:$roomId').onPostgresChanges(
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
                      final profile =
                          await UserProfileCacheManager.fetchUserProfile(uId);
                      final String uName =
                          profile?.username ?? 'Creania Student';
                      final String? uAvatar = profile?.avatar;
                      try {
                        final custResponse = await Supabase.instance.client
                            .from('user_customizations')
                            .select('name')
                            .eq('user_id', uId)
                            .eq('type', 'entry_effect')
                            .eq('is_equipped', true)
                            .maybeSingle();
                        final String? entryEffect =
                            custResponse != null ? custResponse['name'] : null;
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

      Timer? reconnectTimer;

      _roomMembersChannel?.subscribe((status, [error]) {
        debugPrint(
            '[RoomController] Channel status for room $roomId: $status, error: $error');
        if (status == 'channelError' || status == 'timedOut') {
          if (reconnectTimer == null) {
            debugPrint(
                '[RoomController] Connection lost. Reconnection timer started (20s).');
            reconnectTimer = Timer(const Duration(seconds: 20), () async {
              if (activeRoomId == roomId) {
                debugPrint(
                    '[RoomController] Reconnection timed out. Exiting room.');
                _cleanupLocalResources();
                Get.snackbar(
                  'Connection Lost 📡',
                  'You have been disconnected from the room due to network issues.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.orange.withOpacity(0.9),
                  colorText: Colors.white,
                );
              }
            });
          }
        } else if (status == 'subscribed') {
          if (reconnectTimer != null) {
            reconnectTimer!.cancel();
            reconnectTimer = null;
            debugPrint(
                '[RoomController] Connection restored successfully within 20s!');
          }
          // Re-fetch all room state to ensure synchronization upon reconnection (skip DB chat history query)
          Future.microtask(() async {
            await fetchRoomPermissions(roomId);
            await fetchRoomMembers(roomId);
            await fetchRoomRequests(roomId);
            await fetchRoomPolls(roomId);
            await fetchRoomProgression(roomId);
          });
        }
      });

      _roomMessagesChannel = client
          .channel('room_messages:$roomId')
          .onBroadcast(
            event: 'chat_message',
            callback: (payload) async {
              final senderId = payload['sender_id'] as String;
              if (senderId == currentUserId)
                return; // Already rendered optimistically

              final msgId = payload['id'] as String;
              final text = payload['text'] as String? ?? '';
              final timestamp = DateTime.parse(payload['timestamp'] as String);

              final message = RoomChatMessage(
                id: msgId,
                senderId: senderId,
                senderName:
                    payload['sender_name'] as String? ?? 'Creania Student',
                text: text,
                senderRole: payload['sender_role'] as String? ?? 'Listener',
                senderAvatar: payload['sender_avatar'] as String?,
                timestamp: timestamp,
                replyToMessageId: payload['reply_to_message_id'] as String?,
                senderLevel: payload['sender_level']?.toString() ?? '1',
                vipLabel: payload['vip_label'] as String?,
                novelLabel: payload['novel_label'] as String?,
                communityTag: payload['community_tag'] as String?,
                roleTag: payload['role_tag'] as String?,
                isActiveSpeaker: payload['is_active_speaker'] == true,
                avatarFrame: payload['avatar_frame'] as String?,
              );

              if (roomChats[roomId] == null) {
                roomChats[roomId] = <RoomChatMessage>[].obs;
              }

              // Avoid duplicates
              if (!roomChats[roomId]!.any((m) => m.id == msgId)) {
                roomChats[roomId]!.add(message);
              }
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
                    final currentReactions =
                        Map<String, List<String>>.from(msg.reactions);
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

      _roomRequestsChannel =
          client.channel('room_requests:$roomId').onPostgresChanges(
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

      _roomPollsChannel =
          client.channel('room_polls:$roomId').onPostgresChanges(
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
                roomLevelProgresses[roomId] =
                    RoomLevelProgress.fromJson(payload.newRecord);
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

      _roomActivityEventsChannel =
          client.channel('room_activity_events:$roomId').onBroadcast(
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
    WidgetsBinding.instance.removeObserver(this);
    stopProgressionTimer();
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

  Future<void> moderateSpeakerRequest(
      String roomId, String userId, String action) async {
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

  Future<void> moderateBanUser(String roomId, String userId, String reason,
      {String? duration}) async {
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
      Get.snackbar(
          'Transfer Failed', e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> changeMemberRole(
      String roomId, String userId, String newRole) async {
    try {
      await Supabase.instance.client.rpc('change_member_role', params: {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_new_role': newRole,
      });
    } catch (e) {
      debugPrint('Error changing role: $e');
      Get.snackbar(
          'Role Change Failed', e.toString().replaceAll('Exception: ', ''));
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
      Get.snackbar(
          'End Room Failed', e.toString().replaceAll('Exception: ', ''));
    }
  }

  bool canEditRoom() => currentPermissions['can_edit_room'] ?? false;
  bool canDeleteRoom() => currentPermissions['can_delete_room'] ?? false;
  bool canInviteUsers() => currentPermissions['can_invite_users'] ?? false;
  bool canManageSpeakers() =>
      currentPermissions['can_manage_speakers'] ?? false;
  bool canManageListeners() =>
      currentPermissions['can_manage_listeners'] ?? false;
  bool canManageChat() => currentPermissions['can_manage_chat'] ?? false;
  bool canManageGifts() => currentPermissions['can_manage_gifts'] ?? false;
  bool canManagePolls() => currentPermissions['can_manage_polls'] ?? false;
  bool canRecordRoom() => currentPermissions['can_record_room'] ?? false;
  bool canTransferHost() => currentPermissions['can_transfer_host'] ?? false;
  bool canLockRoom() => currentPermissions['can_lock_room'] ?? false;
  bool canChangeSettings() =>
      currentPermissions['can_change_settings'] ?? false;

  void _loadInitialRooms() {}
  Future<void> _saveRooms() async {}
  Future<void> _loadSavedRooms() async {}

  void changeUserRole(String roomId, String userId, String newRole) {
    String dbRole = newRole;
    if (newRole == 'Owner')
      dbRole = 'Host';
    else if (newRole == 'Co-owner')
      dbRole = 'Co-Host';
    else if (newRole == 'Admin')
      dbRole = 'Moderator';
    else if (newRole == 'Star Member')
      dbRole = 'Speaker';
    else if (newRole == 'Guest') dbRole = 'Listener';

    changeMemberRole(roomId, userId, dbRole);
  }

  void removeUserRole(String roomId, String userId) {
    changeUserRole(roomId, userId, 'Visitor');
    addSystemActivity(roomId, '🔄 $userId switched to Seat 0.',
        messageType: 'activity');
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
        newMuteAll
            ? 'All speakers have been muted by management.'
            : 'Speakers can now unmute.',
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
        recommendationSettings:
            recommendationSettings ?? old.recommendationSettings,
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
        addSystemActivity(roomId, '📢 Host updated the room announcement.',
            messageType: 'activity');
      }
      if (eventSettings != null) {
        addSystemActivity(
          roomId,
          eventSettings == 'Enabled'
              ? '🎊 Room event has started.'
              : '✅ Room event has ended.',
          messageType: 'activity',
        );
      }

      Supabase.instance.client
          .from('rooms')
          .update({
            if (name != null) 'name': name,
            if (description != null) 'description': description,
            if (avatar != null) 'avatar': avatar,
            if (avatar != null) 'banner': avatar,
            if (roomCoverUrl != null) 'room_cover_url': roomCoverUrl,
            if (coHostCanEditCover != null)
              'co_host_can_edit_cover': coHostCanEditCover,
            if (adminCanEditCover != null)
              'admin_can_edit_cover': adminCanEditCover,
          })
          .eq('id', roomId)
          .then((_) {
            debugPrint('Room settings updated in Supabase.');
          })
          .catchError((err) {
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
      final fileName =
          '${roomId}_cover_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

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
      final response =
          await Supabase.instance.client.rpc('create_room', params: {
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

  Future<String?> createArenaRoom({
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
    required String creationMethod,
  }) async {
    try {
      final response =
          await Supabase.instance.client.rpc('create_arena', params: {
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
        'p_creation_method': creationMethod,
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
    return rooms
        .where((r) =>
            r.name.toLowerCase().contains(query.toLowerCase()) ||
            r.username.toLowerCase().contains(query.toLowerCase()) ||
            r.id.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<bool> sendStarGiftToRoom({
    required String roomId,
    required String giftId,
    required String giftName,
    required int giftCost,
    required String currency,
    required List<String> targetUserIds,
    required List<String> targetUserNames,
    required List<int> seatIndices,
    int count = 1,
    int comboCount = 1,
  }) async {
    try {
      final room = rooms.firstWhereOrNull((r) => r.id == roomId);
      if (room == null) return false;

      // 1. Database RPC
      final response =
          await Supabase.instance.client.rpc('send_star_gift', params: {
        'p_room_id': roomId,
        'p_receiver_ids': targetUserIds,
        'p_gift_id': giftId,
        'p_quantity': count,
        'p_combo_count': comboCount,
        'p_seat_indices': seatIndices,
      });

      if (response != null && response['success'] == true) {
        // Update local wallet balances in StoreController and RoomController
        final remaining = (response['remaining_balance'] as num).toInt();
        walletBalance.value = remaining;
        try {
          final StoreController storeCtrl = Get.find<StoreController>();
          if (currency == 'gold') {
            storeCtrl.coinsBalance.value = remaining;
          } else {
            storeCtrl.silverCoinsBalance.value = remaining;
          }
        } catch (_) {}

        // Handle Magic Gift lottery outcomes
        final magicResult = response['magic_result'];
        if (magicResult != null &&
            magicResult['payout_type'] != null &&
            magicResult['payout_type'] != 'nothing') {
          final String type = magicResult['payout_type'];
          final int coinsBack = magicResult['coins_back'] ?? 0;
          final int silverAmount = magicResult['silver_reward'] ?? 0;
          final String vaultName = magicResult['vault_item_name'] ?? '';

          String outcomeText = '';
          if (type == 'coin_back') {
            outcomeText = '🔮 Lucky Draw! You got $coinsBack Gold Coins Back!';
          } else if (type == 'silver_reward') {
            outcomeText = '🔮 Lucky Draw! You won $silverAmount Silver Coins!';
          } else if (type == 'vault_reward') {
            outcomeText = '🔮 Lucky Draw! You won a $vaultName!';
          }

          Get.snackbar(
            'Magic Gift Reward! 🔮',
            outcomeText,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFFF59E0B),
            colorText: Colors.black,
            duration: const Duration(seconds: 4),
          );
        }

        // Resolve sender profile info
        final profile =
            await UserProfileCacheManager.fetchUserProfile(currentUserId);
        final uName = profile?.username ?? 'Creania Student';

        // Formulate chat/banner message body matching required structure
        final actualGiftIcon = GiftMetadataRegistry.getMetadata(giftId).giftIcon;
        String messageBody;
        if (targetUserIds.length == 1) {
          final targetName = targetUserNames[0];
          messageBody = count > 1
              ? '$uName sent $count× $actualGiftIcon $giftName to $targetName'
              : '$uName sent $actualGiftIcon $giftName to $targetName';
        } else if (targetUserIds.length >= 10) {
          messageBody = '$uName gifted everyone with $actualGiftIcon $giftName';
        } else {
          messageBody =
              '$uName sent $actualGiftIcon $giftName to ${targetUserIds.length} selected users';
        }

        // Trigger 60/120 FPS Native Hardware Accelerated Gift Animation Overlay
        triggerGiftAnimation(GiftAnimationEvent(
          giftId: giftId,
          giftName: giftName,
          giftIcon: actualGiftIcon,
          senderName: uName,
          senderAvatar: profile?.avatar,
          receiverName: targetUserNames.isNotEmpty ? targetUserNames[0] : 'Everyone',
          count: count * comboCount,
          currency: currency,
        ));

        // 2. Broadcast event to update other users real-time UI/Animations
        await emitRoomActivityEvent(
          roomId: roomId,
          eventType: 'gift_sent',
          userId: currentUserId,
          username: uName,
          targetUserId: targetUserIds.join(','),
          targetUsername: targetUserNames.join(','),
          message: messageBody,
          metadata: {
            'gift_id': giftId,
            'gift_name': giftName,
            'gift_icon': actualGiftIcon,
            'amount': count,
            'currency': currency,
            'stars': giftCost,
            'combo_count': comboCount,
            'receiver_ids': targetUserIds,
            'receiver_names': targetUserNames,
            'seat_indices': seatIndices,
            'sender_avatar': profile?.avatar,
            'is_gold': currency == 'gold',
          },
        );

        // Sync progression tag systems
        await UserProfileCacheManager.rebuildAndSyncCurrentUserTagSystem();

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sending star gift: $e');
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

      String receiverId = targetUserId ?? room.hostId;
      String receiverName = targetUserName ?? 'Host';

      // Find target seat index
      int seatIdx = -1;
      final seats = roomSeatsInfo[roomId] ?? [];
      final seat = seats.firstWhereOrNull((s) => s['userId'] == receiverId);
      if (seat != null) {
        seatIdx = seat['seatIndex'] as int? ?? -1;
      }

      // Catalog UUID mapping
      String matchedGiftId =
          'a1000000-0000-0000-0000-000000000001'; // Default Rose
      if (giftName.contains('Heart')) {
        matchedGiftId = 'a1000000-0000-0000-0000-000000000002';
      } else if (giftName.contains('Crown')) {
        matchedGiftId = 'a1000000-0000-0000-0000-000000000003';
      } else if (giftName.contains('Car') || giftName.contains('Sports Car')) {
        matchedGiftId = 'a1000000-0000-0000-0000-000000000004';
      } else if (giftName.contains('Castle')) {
        matchedGiftId = 'a1000000-0000-0000-0000-000000000005';
      } else if (giftName.contains('Rocket')) {
        matchedGiftId = 'a1000000-0000-0000-0000-000000000006';
      } else if (giftName.contains('Like')) {
        matchedGiftId = 'a1000000-0000-0000-0000-000000000011';
      } else if (giftName.contains('Coffee')) {
        matchedGiftId = 'a1000000-0000-0000-0000-000000000012';
      } else if (giftName.contains('Chocolate')) {
        matchedGiftId = 'a1000000-0000-0000-0000-000000000013';
      } else if (giftName.contains('Flower')) {
        matchedGiftId = 'a1000000-0000-0000-0000-000000000014';
      } else if (giftName.contains('Cake')) {
        matchedGiftId = 'a1000000-0000-0000-0000-000000000015';
      } else if (giftName.contains('Small Heart')) {
        matchedGiftId = 'a1000000-0000-0000-0000-000000000016';
      }

      String currencyType = giftName.startsWith('Vault:')
          ? 'vault'
          : ((giftName.contains('Like') ||
                  giftName.contains('Coffee') ||
                  giftName.contains('Chocolate') ||
                  giftName.contains('Flower') ||
                  giftName.contains('Cake') ||
                  giftName.contains('Small Heart'))
              ? 'silver'
              : 'gold');

      return await sendStarGiftToRoom(
        roomId: roomId,
        giftId: matchedGiftId,
        giftName: giftName,
        giftCost: giftCost,
        currency: currencyType,
        targetUserIds: [receiverId],
        targetUserNames: [receiverName],
        seatIndices: seatIdx != -1 ? [seatIdx] : [],
        count: count,
        comboCount: 1,
      );
    } catch (e) {
      debugPrint('Error wrapping legacy sendGiftToRoom: $e');
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
      addSystemActivity(roomId, '🔊 $userId was unmuted by Host.',
          messageType: 'activity');
    } else {
      list.add(userId);
      addSystemActivity(roomId, '🔇 $userId was muted by Host.',
          messageType: 'activity');
    }
    mutedUsers[roomId] = List<String>.from(list);
  }

  // Moderation: Mute Chat
  void toggleMuteUserChat(String roomId, String userId) {
    final list = mutedChatUsers[roomId] ?? [];
    if (list.contains(userId)) {
      list.remove(userId);
      addSystemActivity(roomId, '🔊 $userId chat was unmuted by Host.',
          messageType: 'activity');
    } else {
      list.add(userId);
      addSystemActivity(roomId, '🔇 $userId chat was muted by Host.',
          messageType: 'activity');
    }
    mutedChatUsers[roomId] = List<String>.from(list);
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
        final List<String> newSpeakers = List<String>.from(old.speakerIds)
          ..remove(userId);
        final List<String> newListeners = List<String>.from(old.listenerIds)
          ..remove(userId);

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

      addSystemActivity(roomId, '🚫 $userId was removed from the room.',
          messageType: 'activity');
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
      final List<String> newBlockList = List<String>.from(old.blockList)
        ..remove(userId);
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
      addSystemActivity(roomId, '🔓 Room has been unlocked.',
          messageType: 'activity');
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
      Get.snackbar('Room joined', 'You are now a member of ${old.name}',
          snackPosition: SnackPosition.BOTTOM);
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
                  final currentUsername =
                      UserProfileCacheManager.currentUser?.username ??
                          'anurag_kumar';
                  Get.to(
                    () => VoiceRoomCallScreen(
                      roomId: roomId,
                      roomName: roomName,
                      userId: currentUid,
                      userName: currentUsername,
                      isHost: roomId == '#VX100001' ||
                          rooms.any(
                              (r) => r.id == roomId && r.hostId == currentUid),
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
                          border:
                              Border.all(color: Colors.pinkAccent, width: 2),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black38,
                                blurRadius: 6,
                                offset: Offset(0, 3)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(27),
                          child: Image.network(
                            avatarUrl.isNotEmpty
                                ? avatarUrl
                                : 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.pinkAccent,
                              child: Icon(Icons.music_note,
                                  color: Colors.white, size: 24),
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
                            border:
                                Border.all(color: Colors.black87, width: 1.5),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -2,
                        top: -2,
                        child: Container(
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.pinkAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.mic, color: Colors.white, size: 10),
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

      // Execute all 6 queries in parallel
      final results = await Future.wait<dynamic>([
        client.from('room_level_progress').select().eq('room_id', roomId).maybeSingle(),
        client.from('room_statistics').select().eq('room_id', roomId).maybeSingle(),
        client.from('room_daily_tasks').select(),
        client.from('room_daily_task_progress').select().eq('room_id', roomId),
        client.from('room_seats').select().eq('room_id', roomId).order('seat_index', ascending: true),
        client.from('room_seat_gifts').select().eq('room_id', roomId),
      ]);

      // 1. Process level progress
      final progressResp = results[0];
      if (progressResp != null) {
        roomLevelProgresses[roomId] = RoomLevelProgress.fromJson(progressResp as Map<String, dynamic>);
      }

      // 2. Process stats
      final statsResp = results[1];
      if (statsResp != null) {
        roomStats[roomId] = RoomStatistics.fromJson(statsResp as Map<String, dynamic>);
      }

      // 3. Process tasks & progress
      final tasksResp = results[2] as List;
      final progressListResp = results[3] as List;

      final progressMap = {
        for (var p in progressListResp) p['task_key'] as String: p
      };

      final List<RoomDailyTask> mergedTasks = (tasksResp).map((t) {
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

      // 4. Process seats & seat gifts
      final seatsResp = results[4] as List;
      final giftsResp = results[5] as List;

      final giftMap = {
        for (var g in giftsResp)
          g['seat_index'] as int: g['silver_gift_count'] as int
      };

      // Collect missing occupant profile IDs to fetch them in parallel
      final Set<String> userIdsToFetch = {};
      for (var s in seatsResp) {
        final uId = s['user_id'] as String?;
        if (uId != null && uId.isNotEmpty) {
          if (UserProfileCacheManager.getCachedUser(uId) == null) {
            userIdsToFetch.add(uId);
          }
        }
      }

      // Concurrent fetch for all missing seat profiles
      if (userIdsToFetch.isNotEmpty) {
        await Future.wait(
          userIdsToFetch.map((id) => UserProfileCacheManager.fetchUserProfile(id)),
        );
      }

      final List<Map<String, dynamic>> seatsList = [];
      for (var s in seatsResp) {
        final idx = s['seat_index'] as int;
        final uId = s['user_id'] as String?;
        final giftsCount = giftMap[idx] ?? 0;

        roomSeatGiftsCounters['$roomId:$idx'] = giftsCount;

        String? username;
        String? avatar;
        if (uId != null) {
          final profile = UserProfileCacheManager.getCachedUser(uId);
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

  Future<void> sendRoomGift(
      String roomId, int seatIndex, int amount, bool isGold) async {
    try {
      final profile =
          await UserProfileCacheManager.fetchUserProfile(currentUserId);
      final uName = profile?.username ?? 'Creania Student';

      await Supabase.instance.client.rpc('send_room_gift', params: {
        'p_room_id': roomId,
        'p_seat_index': seatIndex,
        'p_amount': amount,
        'p_is_gold': isGold,
      });

      // Find occupant of seat Index to output user names
      final seatInfo = roomSeatsInfo[roomId]
          ?.firstWhereOrNull((s) => s['seatIndex'] == seatIndex);
      final String receiverName = seatInfo?['name'] ?? 'Seat #${seatIndex + 1}';

      final String message =
          '🎁 $uName sent $amount ${isGold ? 'Gold Coins' : 'Silver Coins'} to $receiverName.';

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
        final prevIdx =
            updatedSeats.indexWhere((s) => s['userId'] == currentUserId);
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
        final profile =
            await UserProfileCacheManager.fetchUserProfile(currentUserId);

        // 3. Put current user on new seat
        final targetIdx =
            updatedSeats.indexWhere((s) => s['seatIndex'] == seatIndex);
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

      final profile =
          await UserProfileCacheManager.fetchUserProfile(currentUserId);
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
        final targetIdx =
            updatedSeats.indexWhere((s) => s['seatIndex'] == seatIndex);
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

      final profile =
          await UserProfileCacheManager.fetchUserProfile(currentUserId);
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
      final fileName =
          '${roomId}_banner_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

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

      final profile =
          await UserProfileCacheManager.fetchUserProfile(currentUserId);
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
      final profile =
          await UserProfileCacheManager.fetchUserProfile(currentUserId);
      final uName = profile?.username ?? 'Creania Student';

      final seatsList = roomSeatsInfo[roomId] ?? [];
      final mySeat =
          seatsList.firstWhereOrNull((s) => s['userId'] == currentUserId);
      String role = 'Audience';
      if (mySeat != null) {
        final seatIndex = mySeat['seatIndex'] as int;
        role =
            seatIndex == 0 ? 'Host' : (seatIndex == 1 ? 'Co-Host' : 'Speaker');
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
        'vip_label':
            (profile?.vipLevel ?? 0) > 0 ? 'VIP ${profile?.vipLevel}' : null,
        'novel_label': (profile?.novelLevel ?? 0) > 0
            ? 'Novel ${profile?.novelLevel}'
            : null,
        'avatar_frame': equippedFrame,
        'noble_label':
            (profile?.vipLevel ?? 0) > 0 ? 'Noble ${profile?.vipLevel}' : null,
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

  Future<void> sendRoomReactionBroadcast(
      String roomId, String messageId, String reactionType) async {
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
          final currentReactions =
              Map<String, List<String>>.from(msg.reactions);
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
          gradient: LinearGradient(
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
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.stars,
              color: Colors.amber,
              size: 80,
            ),
            SizedBox(height: 16),
            Text(
              'ROOM LEVEL UP! 🎉',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ) ??
                  TextStyle(
                      color: Colors.amber,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              roomName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ) ??
                  TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLevelCircle(context, oldLevel.toString(), 'Level'),
                SizedBox(width: 16),
                Icon(Icons.arrow_forward, color: Colors.white54, size: 28),
                SizedBox(width: 16),
                _buildLevelCircle(context, newLevel.toString(), 'Level',
                    isNew: true),
              ],
            ),
            SizedBox(height: 24),
            Text(
              'New role slots and entry permissions have been unlocked for this room!',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black87,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                'Awesome!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCircle(BuildContext context, String text, String label,
      {bool isNew = false}) {
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
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}
