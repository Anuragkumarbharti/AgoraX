import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/room/room_model.dart';
import '../../models/progression/room_progression_models.dart';
import '../../models/gift/gift_animation_metadata.dart';
import '../../models/room/room_background_model.dart';
import '../../widgets/gifting/gift_animation_overlay.dart';
import '../user/user_profile_cache_manager.dart';
import '../store/store_controller.dart';
import '../network/network_connectivity_service.dart';

import 'room_connection_controller.dart';
import 'room_realtime_controller.dart';
import 'room_chat_controller.dart';
import 'room_member_controller.dart';
import 'room_seat_controller.dart';
import 'room_permission_controller.dart';
import 'room_progression_controller.dart';
import 'room_gift_controller.dart';
import 'room_activity_controller.dart';
import 'room_moderation_controller.dart';
import 'room_background_controller.dart';
import 'room_upload_controller.dart';
import 'room_discovery_controller.dart';
import '../voice/room_voice_manager.dart';
import 'room_pip_controller.dart';
import 'room_dual_progress_controller.dart';
import '../gifting/gift_animation_controller.dart';
import '../gifting/gift_event_service.dart';
import '../gifting/gift_overlay_manager.dart';

export 'room_chat_controller.dart';
export '../../widgets/gifting/gift_animation_overlay.dart';

/// Lightweight Coordinator Controller for Voice Rooms.
/// Initializes domain feature sub-controllers and exposes facade delegators
/// ensuring 100% backward compatibility for all existing UI callers.
class RoomController extends GetxController with WidgetsBindingObserver {
  static RoomController get to => Get.find<RoomController>();
  static String get currentUserId => UserProfileCacheManager.currentUserId;

  // Sub-controller references
  late RoomConnectionController connCtrl;
  late RoomRealtimeController realtimeCtrl;
  late RoomChatController chatCtrl;
  late RoomMemberController memberCtrl;
  late RoomSeatController seatCtrl;
  late RoomPermissionController permissionCtrl;
  late RoomProgressionController progressionCtrl;
  late RoomGiftController giftCtrl;
  late RoomActivityController activityCtrl;
  late RoomModerationController moderationCtrl;
  late RoomBackgroundController backgroundCtrl;
  late RoomUploadController uploadCtrl;
  late RoomDiscoveryController discoveryCtrl;
  late RoomPipController pipCtrl;

  // Connection State Delegators
  String? get activeRoomId => connCtrl.activeRoomId;
  set activeRoomId(String? val) => connCtrl.activeRoomId = val;
  RxBool get isRoomDisconnecting => connCtrl.isRoomDisconnecting;
  RxString get disconnectTitle => connCtrl.disconnectTitle;
  RxString get disconnectReason => connCtrl.disconnectReason;

  // Discovery & Room Feed Delegators
  RxList<VoiceRoom> get rooms => discoveryCtrl.rooms;
  RxList<String> get favoriteRoomIds => discoveryCtrl.favoriteRoomIds;
  RxList<String> get recentRoomIds => discoveryCtrl.recentRoomIds;

  // Active Room State Delegators
  RxList<RoomMember> get activeMembers => memberCtrl.activeMembers;
  RxList<Map<String, dynamic>> get activeRequests => memberCtrl.activeRequests;
  RxList<Map<String, dynamic>> get activePolls => activityCtrl.activePolls;
  RxMap<String, bool> get currentPermissions => permissionCtrl.currentPermissions;
  RxBool get isMutedByModerator => memberCtrl.isMutedByModerator;
  RxList<String> get typingUsers => chatCtrl.typingUsers;
  RxList<String> get animatingJoinUserIds => activityCtrl.animatingJoinUserIds;
  RxMap<String, dynamic> get entranceEvent => activityCtrl.entranceEvent;
  Rxn<Map<String, dynamic>> get rxEntranceEvent => activityCtrl.rxEntranceEvent;

  // Progression & Seat State Delegators
  RxMap<String, RoomLevelProgress> get roomLevelProgresses => progressionCtrl.roomLevelProgresses;
  RxMap<String, RoomStatistics> get roomStats => progressionCtrl.roomStats;
  RxMap<String, List<RoomDailyTask>> get roomDailyTaskLists => progressionCtrl.roomDailyTaskLists;
  RxMap<String, List<Map<String, dynamic>>> get roomSeatsInfo => seatCtrl.roomSeatsInfo;
  RxMap<String, int> get roomSeatGiftsCounters => seatCtrl.roomSeatGiftsCounters;
  RxList<String> get marqueeAnnouncementsQueue => progressionCtrl.marqueeAnnouncementsQueue;

  // Gift & Animation State Delegators
  Rxn<GiftAnimationEvent> get activeGiftAnimation => giftCtrl.activeGiftAnimation;
  Rxn<Map<String, dynamic>> get activeGiftNotification => giftCtrl.activeGiftNotification;
  Rx<RoomBackgroundItem> get activeRoomBackground => backgroundCtrl.activeRoomBackground;

  // Moderation State Delegators
  RxMap<String, List<String>> get mutedUsers => moderationCtrl.mutedUsers;
  RxMap<String, List<String>> get mutedChatUsers => moderationCtrl.mutedChatUsers;
  RxMap<String, List<String>> get bannedUsers => moderationCtrl.bannedUsers;
  RxMap<String, Map<String, RoomBanEntry>> get roomBannedUsersDetailed => moderationCtrl.roomBannedUsersDetailed;

  // Chat & Notifications State Delegators
  RxMap<String, RxList<RoomChatMessage>> get roomChats => chatCtrl.roomChats;

  TextEditingController? roomChatInputController;
  FocusNode? roomChatFocusNode;

  void mentionUserInRoomChat(String userName) {
    if (roomChatInputController != null) {
      final text = roomChatInputController!.text;
      final newText = text.isEmpty ? '@$userName ' : '$text @$userName ';
      roomChatInputController!.text = newText;
      roomChatInputController!.selection =
          TextSelection.collapsed(offset: newText.length);
      if (roomChatFocusNode != null) {
        roomChatFocusNode!.requestFocus();
      }
    }
  }
  RxList<String> get bottomSystemNotifications => chatCtrl.bottomSystemNotifications;
  RxnString get activeSystemNotification => chatCtrl.activeSystemNotification;

  int get eyeCount => memberCtrl.eyeCount;
  RxInt get walletBalance => Get.isRegistered<StoreController>()
      ? Get.find<StoreController>().coinsBalance
      : 0.obs;

  bool _subControllersInitialized = false;

  RoomController() {
    _initSubControllers();
  }

  void _initSubControllers() {
    if (_subControllersInitialized) return;
    _subControllersInitialized = true;

    connCtrl = Get.isRegistered<RoomConnectionController>() ? Get.find<RoomConnectionController>() : Get.put(RoomConnectionController());
    realtimeCtrl = Get.isRegistered<RoomRealtimeController>() ? Get.find<RoomRealtimeController>() : Get.put(RoomRealtimeController());
    chatCtrl = Get.isRegistered<RoomChatController>() ? Get.find<RoomChatController>() : Get.put(RoomChatController());
    memberCtrl = Get.isRegistered<RoomMemberController>() ? Get.find<RoomMemberController>() : Get.put(RoomMemberController());
    seatCtrl = Get.isRegistered<RoomSeatController>() ? Get.find<RoomSeatController>() : Get.put(RoomSeatController());
    permissionCtrl = Get.isRegistered<RoomPermissionController>() ? Get.find<RoomPermissionController>() : Get.put(RoomPermissionController());
    progressionCtrl = Get.isRegistered<RoomProgressionController>() ? Get.find<RoomProgressionController>() : Get.put(RoomProgressionController());
    giftCtrl = Get.isRegistered<RoomGiftController>() ? Get.find<RoomGiftController>() : Get.put(RoomGiftController());
    activityCtrl = Get.isRegistered<RoomActivityController>() ? Get.find<RoomActivityController>() : Get.put(RoomActivityController());
    moderationCtrl = Get.isRegistered<RoomModerationController>() ? Get.find<RoomModerationController>() : Get.put(RoomModerationController());
    backgroundCtrl = Get.isRegistered<RoomBackgroundController>() ? Get.find<RoomBackgroundController>() : Get.put(RoomBackgroundController());
    uploadCtrl = Get.isRegistered<RoomUploadController>() ? Get.find<RoomUploadController>() : Get.put(RoomUploadController());
    discoveryCtrl = Get.isRegistered<RoomDiscoveryController>() ? Get.find<RoomDiscoveryController>() : Get.put(RoomDiscoveryController());
    pipCtrl = Get.isRegistered<RoomPipController>() ? Get.find<RoomPipController>() : Get.put(RoomPipController());

    if (!Get.isRegistered<GiftAnimationController>()) Get.put(GiftAnimationController());
    if (!Get.isRegistered<GiftEventService>()) Get.put(GiftEventService());
    if (!Get.isRegistered<GiftOverlayManager>()) Get.put(GiftOverlayManager());
    if (!Get.isRegistered<RoomDualProgressController>()) Get.put(RoomDualProgressController());
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    _initSubControllers();

    fetchRooms();
    subscribeToRoomsList();

    if (Get.isRegistered<NetworkConnectivityService>()) {
      NetworkConnectivityService.to.addDisconnectedCallback(() {
        debugPrint('[RoomController] Network dropped. Leaving room locally.');
        leaveActiveRoomLocally(reason: 'Network connection lost. Left room automatically.');
      });
      NetworkConnectivityService.to.addReconnectedCallback(() {
        debugPrint('[RoomController] Network restored. Auto-fetching rooms.');
        fetchRooms(forceRefresh: true);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (activeRoomId != null) {
        leaveActiveRoomLocally();
      }
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    stopProgressionTimer();
    unsubscribeRoomRealtime();
    super.onClose();
  }

  // Forwarding Methods for 100% Backward Compatibility
  void triggerInRoomDisconnectOverlay({required String title, required String reason, bool navigateToArena = true}) => connCtrl.triggerInRoomDisconnectOverlay(title: title, reason: reason, navigateToArena: navigateToArena);
  void startHeartbeatLoop(String roomId, bool Function() isMicOnGetter) => connCtrl.startHeartbeatLoop(roomId, isMicOnGetter);
  Future<bool> heartbeatRoomMember(String roomId, bool isSpeaking) => connCtrl.heartbeatRoomMember(roomId, isSpeaking);
  Future<void> repairRoomState(String roomId) => connCtrl.repairRoomState(roomId);
  void leaveActiveRoomLocally({String? reason, bool navigateToArena = false}) => connCtrl.leaveActiveRoomLocally(reason: reason, navigateToArena: navigateToArena);
  Map<String, dynamic> validate12StepRoomEntry(String roomId, String userId) => connCtrl.validate12StepRoomEntry(roomId, userId);
  Future<void> enterRoom(String roomId, {String? password}) => connCtrl.enterRoom(roomId, password: password);
  Future<void> exitRoom(String roomId) => connCtrl.exitRoom(roomId);

  void subscribeToRoomsList() => realtimeCtrl.subscribeToRoomsList(() => fetchRooms());
  void unsubscribeRoomRealtime() => realtimeCtrl.unsubscribeRoomRealtime();

  void initializeChatForRoom(String roomId) => chatCtrl.initializeChatForRoom(roomId);
  void addChatMessage(String roomId, RoomChatMessage message) => chatCtrl.addChatMessage(roomId, message);
  void addSystemActivity(String roomId, String text, {String? senderId, String? senderName, String? senderAvatar, String? messageType, String? activityKey}) => chatCtrl.addSystemActivity(roomId, text, senderId: senderId, senderName: senderName, senderAvatar: senderAvatar, messageType: messageType, activityKey: activityKey);
  Future<void> deleteRoomMessage(String roomId, String messageId) => chatCtrl.deleteRoomMessage(roomId, messageId);
  void emitRoomActivity(String roomId, String text, {String? activityKey}) => chatCtrl.emitRoomActivity(roomId, text, activityKey: activityKey);
  Future<void> sendRoomMessage(String roomId, String text, {String? senderId, String? senderName, String? senderRole, String? senderAvatar, String? replyToMessageId, String? senderLevel, String? vipLabel, String? novelLabel, String? communityTag, String? roleTag, bool isActiveSpeaker = false}) => chatCtrl.sendRoomMessage(roomId, text, senderId: senderId, senderName: senderName, senderRole: senderRole, senderAvatar: senderAvatar, replyToMessageId: replyToMessageId, senderLevel: senderLevel, vipLabel: vipLabel, novelLabel: novelLabel, communityTag: communityTag, roleTag: roleTag, isActiveSpeaker: isActiveSpeaker);
  Future<void> sendRoomBroadcastMessage(String roomId, String text) => chatCtrl.sendRoomBroadcastMessage(roomId, text, seatsList: roomSeatsInfo[roomId]);
  Future<void> sendRoomReactionBroadcast(String roomId, String messageId, String reactionType) => chatCtrl.sendRoomReactionBroadcast(roomId, messageId, reactionType);
  Future<void> setTypingStatus(String roomId, bool isTyping) => chatCtrl.setTypingStatus(roomId, isTyping);
  Future<void> fetchRoomChatMessages(String roomId) => chatCtrl.fetchRoomChatMessages(roomId);
  void addSystemNotification(String notificationText) => chatCtrl.addSystemNotification(notificationText);

  Future<void> fetchRoomMembers(String roomId) => memberCtrl.fetchRoomMembers(roomId, activeRoomId: activeRoomId, onDisconnect: (t, r) => triggerInRoomDisconnectOverlay(title: t, reason: r), onSyncRoom: (rid, mems) => discoveryCtrl.syncRoomFromMembers(rid, mems));
  Future<void> fetchRoomRequests(String roomId) => memberCtrl.fetchRoomRequests(roomId);
  Future<void> raiseHand(String roomId) => memberCtrl.raiseHand(roomId);
  Future<void> moderateSpeakerRequest(String roomId, String requestId, String status) => memberCtrl.moderateSpeakerRequest(roomId, requestId, status);
  void syncRoomFromMembers(String roomId, List<RoomMember> members) => discoveryCtrl.syncRoomFromMembers(roomId, members);

  String getSeatName(int seatIndex) => RoomSeatController.getSeatName(seatIndex);
  bool canOccupySeat(String roomId, int seatIndex, String userId) => seatCtrl.canOccupySeat(roomId, seatIndex, userId);
  Future<void> joinRoomSeat(String roomId, int seatIndex) => seatCtrl.joinRoomSeat(roomId, seatIndex, onEmitActivity: (et, uid, snum, msg, meta) => emitRoomActivityEvent(roomId: roomId, eventType: et, userId: uid, seatNumber: snum, message: msg, metadata: meta), onRefreshProgression: () => fetchRoomProgression(roomId), onRepairState: () => repairRoomState(roomId));
  Future<void> leaveRoomSeat(String roomId, int seatIndex) => seatCtrl.leaveRoomSeat(roomId, seatIndex, onEmitActivity: (et, uid, snum, msg, meta) => emitRoomActivityEvent(roomId: roomId, eventType: et, userId: uid, seatNumber: snum, message: msg, metadata: meta), onRefreshProgression: () => fetchRoomProgression(roomId), onRepairState: () => repairRoomState(roomId));
  Future<bool> removeUserFromSeat(String roomId, int seatIndex, String targetUserId) => seatCtrl.removeUserFromSeat(roomId, seatIndex, targetUserId, onEmitActivity: (et, tu, snum, msg) => emitRoomActivityEvent(roomId: roomId, eventType: et, targetUserId: tu, seatNumber: snum, message: msg));
  Future<bool> toggleSeatLock(String roomId, int seatIndex) => seatCtrl.toggleSeatLock(roomId, seatIndex);

  Future<void> fetchRoomPermissions(String roomId) => permissionCtrl.fetchRoomPermissions(roomId);
  bool canPerformAction(String action) => permissionCtrl.canPerformAction(action);
  String getUserRole(VoiceRoom room, String userId, {List<Map<String, dynamic>>? seatsInfo}) => permissionCtrl.getUserRole(room, userId, seatsInfo: seatsInfo);
  bool canChangeEntryRules(VoiceRoom room, String userId) => permissionCtrl.canChangeEntryRules(room, userId);
  int getRoleWeight(String role) => permissionCtrl.getRoleWeight(role);
  bool isHost(String roomId, String userId, {VoiceRoom? room}) => permissionCtrl.isHost(roomId, userId, room: room);
  bool isCoHost(String roomId, String userId, {VoiceRoom? room}) => permissionCtrl.isCoHost(roomId, userId, room: room);
  bool isModerator(String roomId, String userId, {VoiceRoom? room}) => permissionCtrl.isModerator(roomId, userId, room: room);

  int calculateActiveStageVpRate(int occupantCount) => progressionCtrl.calculateActiveStageVpRate(occupantCount);
  int getXpForNextLevel(int level) => progressionCtrl.getXpForNextLevel(level);
  int getRoomFreeVp(String roomId) => progressionCtrl.getRoomFreeVp(roomId);
  int getRoomGoldVp(String roomId) => progressionCtrl.getRoomGoldVp(roomId);
  void startProgressionTimer(String roomId) => progressionCtrl.startProgressionTimer(roomId, activeRoomId: activeRoomId, seats: roomSeatsInfo[roomId]);
  void stopProgressionTimer() => progressionCtrl.stopProgressionTimer();
  Future<void> fetchRoomProgression(String roomId) => progressionCtrl.fetchRoomProgression(roomId, onUpdateSeats: (m) => seatCtrl.roomSeatsInfo.addAll(m), onUpdateSeatGifts: (m) => seatCtrl.roomSeatGiftsCounters.addAll(m));

  void triggerGiftAnimation(GiftAnimationEvent event) => giftCtrl.triggerGiftAnimation(event);
  Future<bool> sendStarGiftToRoom({required String roomId, required String giftId, required String giftName, required int giftCost, required String currency, required List<String> targetUserIds, required List<String> targetUserNames, required List<int> seatIndices, int count = 1, int comboCount = 1}) => giftCtrl.sendStarGiftToRoom(roomId: roomId, giftId: giftId, giftName: giftName, giftCost: giftCost, currency: currency, targetUserIds: targetUserIds, targetUserNames: targetUserNames, seatIndices: seatIndices, roomsList: rooms, walletBalance: walletBalance, count: count, comboCount: comboCount);
  Future<void> sendRoomGift(String roomId, int seatIndex, int amount, bool isGold) => giftCtrl.sendRoomGift(roomId, seatIndex, amount, isGold, seats: roomSeatsInfo[roomId], onEmitActivity: (et, uid, snum, msg, meta) => emitRoomActivityEvent(roomId: roomId, eventType: et, userId: uid, seatNumber: snum, message: msg, metadata: meta), onRefreshProgression: () => fetchRoomProgression(roomId));

  Future<void> emitRoomActivityEvent({required String roomId, required String eventType, String? userId, String? username, int? seatNumber, String? targetUserId, String? targetUsername, required String message, Map<String, dynamic>? metadata}) => activityCtrl.emitRoomActivityEvent(roomId: roomId, eventType: eventType, userId: userId, username: username, seatNumber: seatNumber, targetUserId: targetUserId, targetUsername: targetUsername, message: message, metadata: metadata);
  Future<void> queueEntranceEffect(String roomId, String userId, String userName) => activityCtrl.queueEntranceEffect(roomId, userId, userName);
  Future<void> fetchRoomPolls(String roomId) => activityCtrl.fetchRoomPolls(roomId);

  Future<void> moderateMuteUser(String roomId, String userId, bool mute) => moderationCtrl.moderateMuteUser(roomId, userId, mute, rooms: rooms, onEmitActivity: (e, tu, msg) => emitRoomActivityEvent(roomId: roomId, eventType: e, targetUserId: tu, message: msg));
  Future<void> toggleMuteUser(String roomId, String userId) => moderationCtrl.toggleMuteUser(roomId, userId, rooms: rooms);
  Future<void> toggleMuteUserChat(String roomId, String userId) => moderationCtrl.toggleMuteUserChat(roomId, userId);
  Future<void> moderateKickUser(String roomId, String userId) => moderationCtrl.moderateKickUser(roomId, userId, rooms: rooms, activeMembers: activeMembers, onEmitActivity: (e, tu, msg) => emitRoomActivityEvent(roomId: roomId, eventType: e, targetUserId: tu, message: msg));
  Future<void> moderateBanUser(String roomId, String userId, String reason, {String? duration}) => moderationCtrl.moderateBanUser(roomId, userId, reason, duration: duration);
  Future<void> banUserWithDuration(String roomId, String userId, String reason, [String duration = '24_hours']) => moderationCtrl.banUserWithDuration(roomId, userId, reason, duration);
  Future<void> unbanUser(String roomId, String userId) => moderationCtrl.unbanUser(roomId, userId);
  Future<void> updateRoomSettings(String roomId, {String? name, String? bulletin, String? greetings, String? theme, String? whoCanJoin, String? whoCanSpeak, String? seatPermissions, List<String>? wordFilter, bool? muteAll, String? avatar, String? banner, String? roomCoverUrl, bool? coHostCanEditCover, bool? adminCanEditCover}) => moderationCtrl.updateRoomSettings(roomId, name: name, bulletin: bulletin, greetings: greetings, theme: theme, whoCanJoin: whoCanJoin, whoCanSpeak: whoCanSpeak, seatPermissions: seatPermissions, wordFilter: wordFilter, muteAll: muteAll, avatar: avatar, banner: banner, roomCoverUrl: roomCoverUrl, coHostCanEditCover: coHostCanEditCover, adminCanEditCover: adminCanEditCover);
  Future<void> transferHost(String roomId, String newHostId) => moderationCtrl.transferHost(roomId, newHostId);
  Future<void> changeMemberRole(String roomId, String userId, String newRole) => moderationCtrl.changeMemberRole(roomId, userId, newRole);
  Future<bool> promoteRoomMember(String roomId, String userId, String currentRole) => moderationCtrl.promoteRoomMember(roomId, userId, currentRole);
  Future<bool> promoteRoomMemberRole(String roomId, String userId, String currentRole) => moderationCtrl.promoteRoomMemberRole(roomId, userId, currentRole);
  Future<bool> demoteRoomMemberRole(String roomId, String userId, [String? currentRole]) => moderationCtrl.demoteRoomMemberRole(roomId, userId, currentRole);
  Future<bool> transferRoomOwnership(String roomId, String newOwnerUserId) => moderationCtrl.transferRoomOwnership(roomId, newOwnerUserId);
  Future<void> endRoom(String roomId) => moderationCtrl.endRoom(roomId, onLeaveLocal: () => leaveActiveRoomLocally());

  void changeRoomBackground(RoomBackgroundItem item) => backgroundCtrl.changeRoomBackground(item, activeRoomId: activeRoomId);
  Future<String?> uploadRoomCoverPhoto(String roomId, io.File file) => uploadCtrl.uploadRoomCoverPhoto(roomId, file);
  Future<String?> uploadRoomBanner(String roomId, io.File file) => uploadCtrl.uploadRoomBanner(roomId, file, rooms);

  Future<void> fetchRooms({bool forceRefresh = false}) => discoveryCtrl.fetchRooms(forceRefresh: forceRefresh);
  Future<void> searchRooms(String query) => discoveryCtrl.searchRooms(query);
  Future<List<VoiceRoom>> searchRoomsRpc(String query) => discoveryCtrl.searchRoomsRpc(query);
  Future<void> followRoom(String roomId) => discoveryCtrl.followRoom(roomId);
  Future<void> toggleFavoriteRoom(String roomId) => discoveryCtrl.followRoom(roomId);
  void addRecentRoom(String roomId) => discoveryCtrl.addRecentRoom(roomId);
  Future<String?> createRoom({required String name, required String username, required String description, required String category, required String country, required String language, required List<String> tags, required List<String> rules, required String entryPermission, required bool isPermanent, String? avatar, String? banner}) => discoveryCtrl.createRoom(name: name, username: username, description: description, category: category, country: country, language: language, tags: tags, rules: rules, entryPermission: entryPermission, isPermanent: isPermanent, avatar: avatar, banner: banner);
  Future<String?> createArenaRoom({required String name, required String username, required String description, required String category, required String country, required String language, required List<String> tags, required List<String> rules, required String entryPermission, String? avatar, String? banner, required String creationMethod}) => discoveryCtrl.createArenaRoom(name: name, username: username, description: description, category: category, country: country, language: language, tags: tags, rules: rules, entryPermission: entryPermission, avatar: avatar, banner: banner, creationMethod: creationMethod);
  Future<String?> createTemporaryRoom({required String name, required String username, required String description, required String category, required String country, required String language, required List<String> tags, required List<String> rules, required String entryPermission, String? avatar, String? banner}) => discoveryCtrl.createTemporaryRoom(name: name, username: username, description: description, category: category, country: country, language: language, tags: tags, rules: rules, entryPermission: entryPermission, avatar: avatar, banner: banner);
  Future<String?> createPermanentRoom({required String name, required String username, required String description, required String category, required String country, required String language, required List<String> tags, required List<String> rules, required String entryPermission, String? avatar, String? banner}) => discoveryCtrl.createPermanentRoom(name: name, username: username, description: description, category: category, country: country, language: language, tags: tags, rules: rules, entryPermission: entryPermission, avatar: avatar, banner: banner);
  Future<void> loadCachedRooms() => discoveryCtrl.loadCachedRooms();
  Future<void> saveRooms() => discoveryCtrl.saveRooms();
  Future<void> loadSavedRooms() => discoveryCtrl.loadSavedRooms();

  Future<void> joinRoomVoice({required String roomId, required String userId, required String userName, bool enableMic = false}) => RoomVoiceManager().joinRoom(roomId: roomId, userId: userId, userName: userName, enableMic: enableMic);
  Future<void> leaveRoomVoice() => RoomVoiceManager().leaveRoom();

  void showPipBubble(String roomId, String roomName, String avatarUrl) => pipCtrl.showPipBubble(roomId: roomId, roomName: roomName, avatarUrl: avatarUrl, isHostChecker: (rid) => isHost(rid, currentUserId));
  void hidePipBubble() => pipCtrl.hidePipBubble();
}
