import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/room_model.dart';
import 'customization_controller.dart';
import '../screens/rooms/voice_room_call_screen.dart';

import 'store_controller.dart';
import 'user_progress_sync_service.dart';
import 'user_profile_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

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
    );
  }
}

class RoomController extends GetxController {
  static RoomController get to => Get.find<RoomController>();
  static String get currentUserId => UserProfileCacheManager.currentUserId;

  String? activeRoomId;

  RxInt get walletBalance => Get.find<StoreController>().coinsBalance;
  final RxList<VoiceRoom> rooms = <VoiceRoom>[].obs;
  
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
  final RxMap<String, bool> roomActivityQueuesBusy = <String, bool>{}.obs;
  final RxMap<String, List<Map<String, dynamic>>> roomActivityQueues = <String, List<Map<String, dynamic>>>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _loadInitialRooms();
    _loadSavedRooms().then((_) {
      ever(rooms, (_) => _saveRooms());
    });
  }

  void initializeChatForRoom(String roomId) {
    if (!roomChats.containsKey(roomId)) {
      roomChats[roomId] = <RoomChatMessage>[
        RoomChatMessage(
          senderId: 'system',
          senderName: 'System',
          text: 'Welcome to the Room! Please read the rules and stay respectful. 🎉',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          isSystem: true,
          messageType: 'system',
        ),
        RoomChatMessage(
          senderId: 'user_co_1',
          senderName: 'Priya Sharma',
          senderRole: 'Co-owner',
          senderAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
          text: 'Hey everyone! Welcome to Creania. 😊',
          timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
        ),
        RoomChatMessage(
          senderId: 'user_adm_1',
          senderName: 'Vikram Aditya',
          senderRole: 'Admin',
          senderAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
          text: 'Glad to be here! Let\'s have a great conversation today.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
        ),
      ].obs;
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

  void deleteRoomMessage(String roomId, String messageId) {
    final messages = roomChats[roomId];
    if (messages == null) return;
    messages.removeWhere((message) => message.id == messageId);
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

  void sendRoomMessage(
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
  }) {
    initializeChatForRoom(roomId);

    // Add local message
    roomChats[roomId]!.add(
      RoomChatMessage(
        senderId: senderId ?? UserProfileCacheManager.currentUserId,
        senderName: senderName ?? 'You',
        senderRole: senderRole ?? 'Owner',
        senderAvatar: senderAvatar,
        text: text,
        timestamp: DateTime.now(),
        replyToMessageId: replyToMessageId,
        senderLevel: senderLevel,
        vipLabel: vipLabel,
        novelLabel: novelLabel,
        communityTag: communityTag,
        roleTag: roleTag,
        isActiveSpeaker: isActiveSpeaker,
      ),
    );

    // Simulate auto-responses based on keywords
    if (text.toLowerCase().contains('hello') || text.toLowerCase().contains('hi')) {
      Future.delayed(const Duration(seconds: 1), () {
        if (roomChats.containsKey(roomId)) {
          roomChats[roomId]!.add(
            RoomChatMessage(
              senderId: 'user_co_1',
              senderName: 'Priya Sharma',
              senderRole: 'Co-owner',
              senderAvatar:
                  'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
              text: 'Hello there! Welcome in! 👋',
              timestamp: DateTime.now(),
            ),
          );
        }
      });
    } else if (text.toLowerCase().contains('music') ||
        text.toLowerCase().contains('song')) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (roomChats.containsKey(roomId)) {
          roomChats[roomId]!.add(
            RoomChatMessage(
              senderId: 'user_star_1',
              senderName: 'Rahul Roy',
              senderRole: 'Star Member',
              senderAvatar:
                  'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=150',
              text: 'Did someone say music? I\'m queueing up a song! 🎵',
              timestamp: DateTime.now(),
            ),
          );
        }
      });
    }
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

  void _loadInitialRooms() {
    // Left empty for production backend loads
  }

  Future<void> _saveRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUid = currentUserId;
    final userRooms = rooms.where((r) => r.hostId == currentUid || r.founderId == currentUid || r.hostId == 'uid_anurag_101' || r.founderId == 'uid_anurag_101').toList();
    final jsonStr = json.encode(userRooms.map((r) => r.toJson()).toList());
    await prefs.setString('user_created_rooms', jsonStr);
    UserProgressSyncService.syncToSupabase();
  }

  Future<void> _loadSavedRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('user_created_rooms');
      if (jsonStr != null) {
        final List<dynamic> decoded = json.decode(jsonStr);
        for (final item in decoded) {
          final room = VoiceRoom.fromJson(item);
          if (!rooms.any((r) => r.id == room.id)) {
            rooms.add(room);
          }
        }
      }
    } catch (_) {}
  }

  void changeUserRole(String roomId, String userId, String newRole) {
    final int index = rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final old = rooms[index];
      
      // Clear user from all other roles first
      List<String> coOwners = List<String>.from(old.coOwnerIds)..remove(userId);
      List<String> admins = List<String>.from(old.adminIds)..remove(userId);
      List<String> starMembers = List<String>.from(old.starMemberIds)..remove(userId);
      
      List<String> managers = List<String>.from(old.managerIds)..remove(userId);
      List<String> moderators = List<String>.from(old.moderatorIds)..remove(userId);
      List<String> hosts = List<String>.from(old.hostIds)..remove(userId);
      List<String> mentors = List<String>.from(old.mentorIds)..remove(userId);
      List<String> judges = List<String>.from(old.judgeIds)..remove(userId);
      List<String> performers = List<String>.from(old.performerIds)..remove(userId);
      List<String> elites = List<String>.from(old.eliteMemberIds)..remove(userId);
      List<String> vips = List<String>.from(old.vipMemberIds)..remove(userId);
      List<String> members = List<String>.from(old.memberIds)..remove(userId);
      List<String> visitors = List<String>.from(old.visitorIds)..remove(userId);

      // Assign to the new role
      if (newRole == 'Co-owner') coOwners.add(userId);
      else if (newRole == 'Admin') admins.add(userId);
      else if (newRole == 'Star Member') starMembers.add(userId);
      else if (newRole == 'Manager') managers.add(userId);
      else if (newRole == 'Moderator') moderators.add(userId);
      else if (newRole == 'Host') hosts.add(userId);
      else if (newRole == 'Mentor') mentors.add(userId);
      else if (newRole == 'Judge') judges.add(userId);
      else if (newRole == 'Performer') performers.add(userId);
      else if (newRole == 'Elite Member') elites.add(userId);
      else if (newRole == 'VIP Member') vips.add(userId);
      else if (newRole == 'Member') members.add(userId);
      else if (newRole == 'Visitor') visitors.add(userId);

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
        coOwnerIds: coOwners,
        adminIds: admins,
        starMemberIds: starMembers,
        extraCoOwnerSlots: old.extraCoOwnerSlots,
        extraAdminSlots: old.extraAdminSlots,
        extraStarMemberSlots: old.extraStarMemberSlots,
        founderId: old.founderId,
        managerIds: managers,
        moderatorIds: moderators,
        hostIds: hosts,
        mentorIds: mentors,
        judgeIds: judges,
        performerIds: performers,
        eliteMemberIds: elites,
        vipMemberIds: vips,
        memberIds: members,
        visitorIds: visitors,
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

      Get.snackbar(
        'Role Updated',
        'User role changed to $newRole successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
      );
      final roleMessage = switch (newRole) {
        'Host' => '👑 $userId became Host.',
        'Co-owner' => '⭐ $userId became Co-Host.',
        'Moderator' => '🛡️ $userId became Moderator.',
        _ => '🎉 $userId became $newRole.',
      };
      addSystemActivity(roomId, roleMessage, messageType: 'activity');
    }
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
      
      Get.snackbar(
        'Success',
        'Room settings updated successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  // Create a temporary room (Free)
  bool createTemporaryRoom({
    required String name,
    required String description,
    required String category,
    required String country,
    required String language,
    required List<String> tags,
    required List<String> rules,
    required String entryPermission,
    String? avatar,
    String? banner,
  }) {
    final currentUid = UserProfileCacheManager.currentUserId;
    final currentUsername = UserProfileCacheManager.currentUser?.username ?? 'Creania Student';
    if (rooms.any((r) => r.hostId == currentUid || r.founderId == currentUid)) {
      Get.snackbar(
        'Limit Exceeded',
        'You can only own one voice room at a time.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return false;
    }

    final String tempId = 'room_temp_${Random().nextInt(90000) + 10000}';
    final VoiceRoom newRoom = VoiceRoom(
      id: tempId,
      name: name,
      description: description,
      hostId: currentUid,
      ownerName: currentUsername, 
      communityId: 'comm_custom',
      type: 'Social Room',
      isLive: true,
      participantCount: 1,
      maxParticipants: 50,
      speakerIds: [currentUid],
      listenerIds: [],
      allowRecording: true,
      allowScreenShare: true,
      createdAt: DateTime.now(),
      startedAt: DateTime.now(),
      isPermanent: false,
      level: 1,
      xp: 0,
      totalMembers: 1,
      totalFollowers: 0,
      totalGiftsReceived: 0,
      category: category,
      country: country,
      language: language,
      tags: tags,
      rules: rules,
      entryPermission: entryPermission,
      founderId: currentUid,
      coOwnerIds: [],
      adminIds: [],
      starMemberIds: [],
      managerIds: [],
      moderatorIds: [],
      hostIds: [],
      mentorIds: [],
      judgeIds: [],
      performerIds: [],
      eliteMemberIds: [],
      vipMemberIds: [],
      memberIds: [],
      visitorIds: [],
      blockList: [],
      avatar: avatar,
      banner: banner,
    );

    rooms.insert(0, newRoom);
    Get.snackbar(
      'Success',
      'Temporary Voice Room created successfully!',
      snackPosition: SnackPosition.BOTTOM,
    );
    return true;
  }

  // Create a permanent room (Costs 599 Gold Coins)
  bool createPermanentRoom({
    required String name,
    required String description,
    required String category,
    required String country,
    required String language,
    required List<String> tags,
    required List<String> rules,
    required String entryPermission,
    String? avatar,
    String? banner,
  }) {
    final currentUid = UserProfileCacheManager.currentUserId;
    final currentUsername = UserProfileCacheManager.currentUser?.username ?? 'Creania Student';
    if (rooms.any((r) => r.hostId == currentUid || r.founderId == currentUid)) {
      Get.snackbar(
        'Limit Exceeded',
        'You can only own one voice room at a time.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return false;
    }

    if (walletBalance.value < 599) {
      Get.snackbar(
        'Insufficient Balance',
        'You need 599 Gold Coins to unlock a Permanent Room. Current balance: ${walletBalance.value} coins.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return false;
    }

    // Deduct coins
    walletBalance.value -= 599;

    // Generate permanent Room ID (e.g. #VX786543)
    final int randomId = Random().nextInt(900000) + 100000;
    final String permId = '#VX$randomId';

    final VoiceRoom newRoom = VoiceRoom(
      id: permId,
      name: name,
      description: description,
      hostId: currentUid,
      ownerName: currentUsername,
      communityId: 'comm_custom',
      type: 'Social Room',
      isLive: true,
      participantCount: 1,
      maxParticipants: 200,
      speakerIds: [currentUid],
      listenerIds: [],
      allowRecording: true,
      allowScreenShare: true,
      createdAt: DateTime.now(),
      startedAt: DateTime.now(),
      isPermanent: true,
      level: 1,
      xp: 0,
      totalMembers: 1,
      totalFollowers: 0,
      totalGiftsReceived: 0,
      category: category,
      country: country,
      language: language,
      tags: tags,
      rules: rules,
      entryPermission: entryPermission,
      founderId: currentUid,
      coOwnerIds: [],
      adminIds: [],
      starMemberIds: [],
      managerIds: [],
      moderatorIds: [],
      hostIds: [],
      mentorIds: [],
      judgeIds: [],
      performerIds: [],
      eliteMemberIds: [],
      vipMemberIds: [],
      memberIds: [],
      visitorIds: [],
      blockList: [],
      avatar: avatar ?? 'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?w=150',
      banner: banner ?? 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600',
    );

    rooms.insert(0, newRoom);
    Get.snackbar(
      'Success',
      'Unlocked Permanent Voice Room: $permId! Deducted 599 Gold Coins.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.withOpacity(0.8),
      colorText: Colors.white,
    );
    return true;
  }

  // Send a gift inside a room
  bool sendGiftToRoom(String roomId, {required int giftCost, required String giftName, required String fromUserName, int count = 1, String? targetUserId, String? targetUserName, bool deductCoins = true}) {
    final int totalCost = giftCost * count;
    if (deductCoins) {
      if (walletBalance.value < totalCost) {
        Get.snackbar(
          'Insufficient Coins',
          'You need $totalCost Gold Coins to send this gift (to $count members). You currently have ${walletBalance.value} coins.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
        return false;
      }
      walletBalance.value -= totalCost;
    }

    final int index = rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final VoiceRoom oldRoom = rooms[index];

      // XP gained is equal to totalCost * 5
      final int xpGain = totalCost * 5;
      final int newXp = oldRoom.xp + xpGain;
      
      // Calculate level-up: Each level requires level * 1000 XP
      int newLevel = oldRoom.level;
      int tempLevel = oldRoom.level;
      int xpNeeded = tempLevel * 1000;
      int remainingXp = newXp;

      while (remainingXp >= xpNeeded && tempLevel < 10) {
        remainingXp -= xpNeeded;
        tempLevel++;
        xpNeeded = tempLevel * 1000;
      }
      newLevel = tempLevel;

      final bool leveledUp = newLevel > oldRoom.level;

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
        level: newLevel,
        xp: leveledUp ? remainingXp : newXp,
        badges: oldRoom.badges + (leveledUp ? 1 : 0),
        totalMembers: oldRoom.totalMembers,
        totalFollowers: oldRoom.totalFollowers,
        totalGiftsReceived: oldRoom.totalGiftsReceived + totalCost,
        isPermanent: oldRoom.isPermanent,
        entryPermission: oldRoom.entryPermission,
        coOwnerIds: oldRoom.coOwnerIds,
        adminIds: oldRoom.adminIds,
        starMemberIds: oldRoom.starMemberIds,
        extraCoOwnerSlots: oldRoom.extraCoOwnerSlots,
        extraAdminSlots: oldRoom.extraAdminSlots,
        extraStarMemberSlots: oldRoom.extraStarMemberSlots,
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

      // Trigger system message about gift
      final String receiver = targetUserName ?? (count > 1 ? 'all seats' : 'the stage');
      final String giftText = '🎁 $fromUserName sent $giftName × $count to $receiver.';
      
      addChatMessage(
        roomId,
        RoomChatMessage(
          senderId: 'system',
          senderName: 'System',
          text: giftText,
          timestamp: DateTime.now(),
          isSystem: true,
          messageType: 'gift',
          roleTag: 'gift',
        ),
      );

      if (leveledUp) {
        Get.dialog(
          LevelUpDialog(
            roomId: roomId,
            roomName: oldRoom.name,
            oldLevel: oldRoom.level,
            newLevel: newLevel,
          ),
          barrierDismissible: true,
        );
      } else {
        Get.snackbar(
          'Gift Sent! 🎁',
          count > 1
              ? '$fromUserName sent $giftName to all $count occupied seats! Total cost: $totalCost Coins. +$xpGain Room XP.'
              : '$fromUserName sent a $giftName ($giftCost Coins) to the room! +$xpGain Room XP.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF6366F1).withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    }
    return true;
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
