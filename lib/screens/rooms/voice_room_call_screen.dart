import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:creania/core/theme.dart';
import '../../models/room/room_model.dart';
import '../../models/chat/chat_model.dart';
import '../../models/gift/gift_animation_metadata.dart';
import '../../services/voice/room_voice_manager.dart';
import '../../services/voice/voice_controller.dart';
import '../../services/user/permission_service.dart';
import '../../services/room/room_controller.dart';
import '../../services/room/room_seat_controller.dart';
import '../../services/user/user_profile_cache_manager.dart';
import '../../services/user/premium_identity_controller.dart';
import '../../services/user/customization_controller.dart';
import '../../widgets/memberships/vip_entry_animation.dart';
import '../../widgets/memberships/novel_entry_animation.dart';
import '../../services/room/room_entry_permission_engine.dart';
import '../../services/gifting/gift_animation_controller.dart';
import '../../services/gifting/gift_overlay_manager.dart';
import '../../services/room/room_dual_progress_controller.dart';

// Extracted Sub-Modules
import 'voice_room/models/floating_reaction.dart';
import 'voice_room/animations/floating_emoji_item.dart';
import 'voice_room/animations/gifting_animation_overlay.dart';
import 'voice_room/widgets/breathing_indicators.dart';
import 'voice_room/widgets/seat_voice_effect.dart';
import 'voice_room/widgets/voice_waveform_widget.dart';
import 'voice_room/widgets/room_call_header.dart';
import 'voice_room/widgets/room_call_seat_grid.dart';
import 'voice_room/widgets/room_call_chat_box.dart';
import 'voice_room/widgets/room_call_bottom_controls.dart';
import 'voice_room/widgets/room_call_special_panels.dart';
import 'voice_room/widgets/room_call_banner_and_xp.dart';
import 'voice_room/dialogs/room_audio_settings_dialog.dart';
import 'voice_room/dialogs/seat_applications_dialog.dart';
import 'voice_room/dialogs/online_members_dialog.dart';
import 'voice_room/dialogs/member_list_dialog.dart';
import 'voice_room/dialogs/mini_profile_dialog.dart';
import 'voice_room/dialogs/mini_profile_sheets.dart';
import 'voice_room/dialogs/mini_profile_badges.dart';
import 'voice_room/dialogs/room_settings_dialog.dart';
import 'voice_room/dialogs/room_settings_management.dart';
import 'voice_room/dialogs/seat_action_sheets.dart';
import 'voice_room/dialogs/room_options_sheet.dart';

export 'voice_room/models/floating_reaction.dart';
export 'voice_room/animations/floating_emoji_item.dart';
export 'voice_room/animations/gifting_animation_overlay.dart';
export 'voice_room/widgets/breathing_indicators.dart';
export 'voice_room/widgets/seat_voice_effect.dart';
export 'voice_room/widgets/voice_waveform_widget.dart';
export 'voice_room/widgets/room_call_header.dart';
export 'voice_room/widgets/room_call_seat_grid.dart';
export 'voice_room/widgets/room_call_chat_box.dart';
export 'voice_room/widgets/room_call_bottom_controls.dart';
export 'voice_room/widgets/room_call_special_panels.dart';
export 'voice_room/widgets/room_call_banner_and_xp.dart';
export 'voice_room/dialogs/room_audio_settings_dialog.dart';
export 'voice_room/dialogs/seat_applications_dialog.dart';
export 'voice_room/dialogs/online_members_dialog.dart';
export 'voice_room/dialogs/member_list_dialog.dart';
export 'voice_room/dialogs/mini_profile_dialog.dart';
export 'voice_room/dialogs/mini_profile_sheets.dart';
export 'voice_room/dialogs/mini_profile_badges.dart';
export 'voice_room/dialogs/room_settings_dialog.dart';
export 'voice_room/dialogs/room_settings_management.dart';
export 'voice_room/dialogs/seat_action_sheets.dart';
export 'voice_room/dialogs/room_options_sheet.dart';

class VoiceRoomCallScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String userId;
  final String userName;
  final bool isHost;

  const VoiceRoomCallScreen({
    Key? key,
    required this.roomId,
    required this.roomName,
    required this.userId,
    required this.userName,
    required this.isHost,
  }) : super(key: key);

  @override
  State<VoiceRoomCallScreen> createState() => _VoiceRoomCallScreenState();
}

class _VoiceRoomCallScreenState extends State<VoiceRoomCallScreen>
    with TickerProviderStateMixin {
  late PermissionService _permissionService;
  late RoomController _controller;
  final RxBool _isMicOn = false.obs;
  final RxBool _isEventSidebarOpen = false.obs;
  bool _isCameraOn = false;
  bool _isLoading = true;

  // Speakers stage seat states
  final RxList<Map<String, dynamic>> _seats = <Map<String, dynamic>>[].obs;

  // Marquee Banner States
  final RxString _bannerText =
      'ALEENA ♕ Queen 👑 💜 and 👑 💜 Shan ♕ KinG 👑 💜 have joined the room!'
          .obs;
  final RxBool _showBanner = false.obs;
  Timer? _marqueeTimer;

  // New Marquee Queue & Animation system
  final List<String> _localAnnouncementsQueue = [];
  final RxString _currentMarqueeText = "".obs;
  final RxInt _marqueeResetCounter = 0.obs;
  late Worker _seatsSyncWorker;
  late Worker _marqueeWorker;
  Timer? _marqueeDelayTimer;

  // Wave animation controllers for speaking glow effects
  late AnimationController _glowController;

  // Chat UI controllers
  final TextEditingController _chatInputController = TextEditingController();
  final FocusNode _chatInputFocusNode = FocusNode();
  final ScrollController _chatScrollController = ScrollController();
  bool _isChatAtBottom = true;
  final RxBool _showEntranceOverlay = false.obs;
  final RxList<Map<String, dynamic>> _entranceQueue =
      <Map<String, dynamic>>[].obs;
  final RxBool _isEntrancePlaying = false.obs;
  final RxString _currentEntranceUser = ''.obs;
  final RxString _currentEntranceUserId = ''.obs;
  final RxInt _currentEntranceVipLevel = 0.obs;
  final RxInt _currentEntranceNovelLevel = 0.obs;
  final RxString _currentEntranceEntryEffect = ''.obs;
  final RxString _resolvedEntranceAnimation = 'None'.obs;

  // Floating Reactions
  final RxList<FloatingReaction> _reactions = <FloatingReaction>[].obs;

  Worker? _giftNotificationWorker;
  Worker? _systemNotificationWorker;
  Timer? _giftBannerTimer;
  Timer? _systemNotificationTimer;
  final Map<int, GlobalKey> _seatKeys = {};

  final RxList<Map<String, dynamic>> _activeGiftingAnimations =
      <Map<String, dynamic>>[].obs;

  final Rx<Offset> _shakeOffset = Offset.zero.obs;

  // Special Debate Mode States
  final RxInt _debateRound = 1.obs;
  final RxInt _debateTimerSeconds = 180.obs;
  Timer? _debateTimer;
  final RxBool _isDebateTimerRunning = false.obs;
  final RxInt _scoreCandidateA = 0.obs;
  final RxInt _scoreCandidateB = 0.obs;

  // Study Mode quiz state
  final RxBool _quizVoted = false.obs;
  final RxString _quizSelectedOption = ''.obs;
  final RxMap<String, int> _quizVotes = <String, int>{
    'A': 12,
    'B': 45,
    'C': 10,
    'D': 3,
  }.obs;

  // Music mode state
  final RxList<Map<String, String>> _songQueue = <Map<String, String>>[
    {'title': 'Perfect', 'singer': 'Ed Sheeran', 'requester': 'Priya Sharma'},
    {
      'title': 'Dil Chahta Hai',
      'singer': 'Shankar Mahadevan',
      'requester': 'Rahul Roy'
    },
    {
      'title': 'Channa Mereya',
      'singer': 'Arijit Singh',
      'requester': 'Anurag Kumar'
    },
  ].obs;

  // Poll state
  final RxBool _pollVoted = false.obs;
  final RxString _pollSelectedOption = ''.obs;
  final RxMap<String, int> _pollVotes = <String, int>{
    'Yes': 34,
    'No': 6,
  }.obs;

  @override
  void initState() {
    super.initState();
    NovelVideoPreloader.preload();
    VipVideoPreloader.preload();
    Get.put(VoiceController());
    Get.put(GiftOverlayManager());
    _permissionService = PermissionService();
    _controller = RoomController.to;
    _controller.activeRoomId = widget.roomId;
    _controller.hidePipBubble();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _initializeSeats();

    _chatScrollController.addListener(() {
      if (_chatScrollController.hasClients) {
        final maxScroll = _chatScrollController.position.maxScrollExtent;
        final currentScroll = _chatScrollController.offset;
        _isChatAtBottom = (maxScroll - currentScroll) <= 40.0;
      }
    });

    _chatInputFocusNode.addListener(() {
      if (_chatInputFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_chatScrollController.hasClients && _isChatAtBottom) {
            _chatScrollController.animateTo(
              _chatScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    });

    _seatsSyncWorker = ever(_controller.roomSeatsInfo,
        (Map<String, List<Map<String, dynamic>>> infoMap) {
      final list = infoMap[widget.roomId];
      if (list != null && list.isNotEmpty) {
        _seats.assignAll(list);
      }
    });

    _marqueeWorker =
        ever(_controller.marqueeAnnouncementsQueue, (List<String> queue) {
      if (queue.isNotEmpty) {
        for (final msg in queue) {
          _localAnnouncementsQueue.add(msg);
        }
        _controller.marqueeAnnouncementsQueue.clear();
        if (!_showBanner.value) {
          _playNextMarquee();
        }
      }
    });

    _giftNotificationWorker =
        ever(_controller.activeGiftNotification, (Map<String, dynamic>? data) {
      if (data != null) {
        _giftBannerTimer?.cancel();
        _giftBannerTimer = Timer(const Duration(seconds: 4), () {
          _controller.activeGiftNotification.value = null;
        });

        final List<dynamic>? seatIndices =
            data['seat_indices'] as List<dynamic>?;
        final String? giftId = data['gift_id'] ?? data['giftId'];
        final String rawName = data['gift_name'] ?? data['name'] ?? '';
        final resolvedMeta =
            GiftMetadataRegistry.getMetadata(giftId ?? rawName);
        final String giftIcon = (data['gift_icon'] ??
                    data['giftIcon'] ??
                    data['icon'] ??
                    '')
                .toString()
                .isNotEmpty
            ? (data['gift_icon'] ?? data['giftIcon'] ?? data['icon']).toString()
            : resolvedMeta.giftIcon;
        final String giftName =
            rawName.isNotEmpty ? rawName : resolvedMeta.giftName;
        final int amount = data['amount'] ?? data['count'] ?? 1;
        final String? senderName = data['senderName'] ?? data['sender_name'];
        final String? senderAvatar =
            data['senderAvatar'] ?? data['sender_avatar'];
        final String? receiverName =
            data['receiverName'] ?? data['receiver_name'];
        final String? receiverAvatar =
            data['receiverAvatar'] ?? data['receiver_avatar'];

        if (seatIndices != null && seatIndices.isNotEmpty) {
          final List<int> targets = seatIndices
              .map((s) => int.tryParse(s.toString()) ?? -1)
              .where((s) => s != -1)
              .toList();
          _triggerGiftingAnimations(targets, giftIcon, giftName, amount,
              giftId: giftId,
              senderName: senderName,
              senderAvatar: senderAvatar,
              receiverName: receiverName,
              receiverAvatar: receiverAvatar);
        } else {
          final rName = data['receiverName'];
          final seats = _controller.roomSeatsInfo[widget.roomId] ?? [];
          final matchedSeat = seats.firstWhereOrNull((s) => s['name'] == rName);
          if (matchedSeat != null) {
            _triggerGiftingAnimations(
                [matchedSeat['seatIndex'] as int], giftIcon, giftName, amount,
                giftId: giftId,
                senderName: senderName,
                senderAvatar: senderAvatar,
                receiverName: receiverName,
                receiverAvatar: receiverAvatar);
          } else {
            _triggerGiftingAnimations([0], giftIcon, giftName, amount,
                giftId: giftId,
                senderName: senderName,
                senderAvatar: senderAvatar,
                receiverName: receiverName,
                receiverAvatar: receiverAvatar);
          }
        }
      }
    });

    _systemNotificationWorker =
        ever(_controller.activeSystemNotification, (String? msg) {
      if (msg != null) {
        _systemNotificationTimer?.cancel();
        _systemNotificationTimer = Timer(const Duration(seconds: 3), () {
          _controller.activeSystemNotification.value = null;
        });
      }
    });

    ever(_controller.rxEntranceEvent, (Map<String, dynamic>? event) {
      if (event != null) {
        final String? uId = event['userId'];
        final String? uName = event['userName'];
        if (uId != null && uId != widget.userId) {
          final vip = int.tryParse(event['vip_level']?.toString() ?? '0') ?? 0;
          final novel =
              int.tryParse(event['noble_level']?.toString() ?? '0') ?? 0;
          final entryEffect = event['entry_effect']?.toString();
          onUserJoin(
            uId,
            uName ?? 'User',
            vipLevel: vip,
            novelLevel: novel,
            entryEffect: entryEffect,
          );
        }
      }
    });

    _initializeRoom();
    _chatScrollController.addListener(_handleChatScroll);
    _controller.startHeartbeatLoop(widget.roomId, () => _isMicOn.value);
  }

  void _playNextMarquee() {
    _marqueeDelayTimer?.cancel();

    if (_localAnnouncementsQueue.isNotEmpty) {
      _currentMarqueeText.value = _localAnnouncementsQueue.removeAt(0);
      _showBanner.value = true;
      _marqueeResetCounter.value++;
    } else if (_currentMarqueeText.value.isNotEmpty) {
      _marqueeDelayTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        _marqueeResetCounter.value++;
      });
    } else {
      _showBanner.value = false;
    }
  }

  void _initializeSeats() {
    final cachedSeats = _controller.roomSeatsInfo[widget.roomId];
    if (cachedSeats != null && cachedSeats.isNotEmpty) {
      _seats.assignAll(cachedSeats);
    } else {
      _seats.assignAll(List.generate(
          10,
          (index) => {
                'seatIndex': index,
                'role':
                    index == 0 ? 'Owner' : (index == 1 ? 'Co-owner' : 'Guest'),
                'userId': null,
                'name': RoomSeatController.getSeatName(index),
                'isSpeaking': false,
                'isLocked': false,
              }));
    }
  }

  Future<void> _initializeRoom() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
    _startBackgroundRoomJoin();
  }

  Future<void> _startBackgroundRoomJoin() async {
    try {
      // Validate Entry Permission before connecting voice or initializing chat
      final liveRoom = _controller.rooms.firstWhereOrNull((r) => r.id == widget.roomId) ??
          VoiceRoom.dummy(widget.roomId);
      final currentUid = widget.userId;
      final userVip = UserProfileCacheManager.currentUser?.vipLevel ?? 1;

      final validationResult = RoomEntryPermissionEngine().validateEntry(
        room: liveRoom,
        userId: currentUid,
        userVipLevel: userVip,
      );

      if (!validationResult.isAllowed) {
        debugPrint('[VoiceRoomCallScreen] Access Denied: ${validationResult.message}');
        if (mounted) {
          Get.back(); // Immediately exit room screen!
        }
        return; // Abort voice connection and chat initialization!
      }

      final roomVoiceManager = RoomVoiceManager();

      if (widget.isHost) {
        final permissionsGranted =
            await _permissionService.requestMicrophonePermission();
        if (!permissionsGranted) {
          Get.snackbar(
            'Permissions Required',
            'Please enable microphone permissions to speak on stage',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: context.warningColor,
          );
        }
      }

      // Every user joins as Audience/Listener with mic OFF by default.
      // No automatic seat assignment for any user (Owner, Co-Host, Admin, Moderator, VIP, Regular User).
      await roomVoiceManager.joinRoom(
        roomId: widget.roomId,
        userId: widget.userId,
        userName: widget.userName,
        enableMic: false,
      );

      await _controller.enterRoom(widget.roomId);
      await _controller.fetchRoomProgression(widget.roomId);
      if (Get.isRegistered<RoomDualProgressController>()) {
        RoomDualProgressController.to.subscribeToRealtimeDualProgress(widget.roomId);
      }

      if (mounted) {
        setState(() {
          _isMicOn.value = false;
        });
      }

      _controller.initializeChatForRoom(widget.roomId);
      String? localEntryEffect;
      try {
        if (Get.isRegistered<CustomizationController>()) {
          localEntryEffect =
              Get.find<CustomizationController>().activeEntryEffect.value;
        }
      } catch (_) {}

      onUserJoin(widget.userId, widget.userName, entryEffect: localEntryEffect);
    } catch (e) {
      debugPrint('[VoiceRoomCallScreen] Error in background room join: $e');
    }
  }

  bool _isCurrentUserOnSeat() {
    final seatsList = _controller.roomSeatsInfo[widget.roomId] ?? [];
    return seatsList.any((s) => s['userId'] == widget.userId);
  }

  Future<void> _toggleMic() async {
    if (!_isCurrentUserOnSeat()) {
      Get.snackbar(
        'Voice Locked 🔒',
        'You are a listener. Tap any empty seat to join the stage and speak!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.warningColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    try {
      final newState = !_isMicOn.value;
      await RoomVoiceManager().toggleMic(newState);
      _isMicOn.value = newState;

      final index = _seats.indexWhere((s) => s['userId'] == widget.userId);
      if (index != -1) {
        _seats[index] = {
          ..._seats[index],
          'isSpeaking': newState,
        };
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to toggle microphone',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _joinSeat(int seatIndex) async {
    final seatsList = _controller.roomSeatsInfo[widget.roomId] ?? [];
    final seat = seatsList.firstWhereOrNull((s) => s['seatIndex'] == seatIndex);
    if (seat != null && seat['userId'] == widget.userId) {
      SeatActionSheets.showSelfSeatActions(
        context: context,
        roomId: widget.roomId,
        seatIndex: seatIndex,
        isMicOn: _isMicOn.value,
        onToggleMic: _toggleMic,
        onLeaveSeat: _leaveSeat,
        seats: _seats,
      );
      return;
    }

    if (!_controller.canOccupySeat(widget.roomId, seatIndex, widget.userId)) {
      Get.snackbar(
        'Seat Access Locked 🔒',
        '${RoomSeatController.getSeatName(seatIndex)} is reserved for Room Host, Co-Owners, and Admins.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    try {
      await _controller.joinRoomSeat(widget.roomId, seatIndex);
      await RoomVoiceManager().toggleMic(true);
      _isMicOn.value = true;

      Get.snackbar(
        'Stage Joined 🎤',
        'You are now in ${RoomSeatController.getSeatName(seatIndex)}. Speak freely!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.successColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Seat Access 🔒',
        'Failed to join seat: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _leaveSeat(int seatIndex) async {
    try {
      await _controller.leaveRoomSeat(widget.roomId, seatIndex);
      await RoomVoiceManager().toggleMic(false);
      _isMicOn.value = false;
      setState(() {
        _isCameraOn = false;
      });

      Get.snackbar(
        'Left Stage 🚪',
        'You returned to the audience. Your microphone has been muted.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.warningColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to leave seat: $e');
    }
  }

  Future<void> _leaveRoom() async {
    final bool? leaveApproved = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Leave Room? 🚪',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to leave this Arena room?',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Get.back(result: true),
            child: Text(
              'Leave',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (leaveApproved == true) {
      try {
        RoomVoiceManager().leaveRoom();
        _controller.exitRoom(widget.roomId);
        Get.back();
      } catch (e) {
        Get.snackbar('Error', 'Failed to leave arena',
            snackPosition: SnackPosition.BOTTOM);
      }
    }
  }

  void _handleChatScroll() {
    if (!_chatScrollController.hasClients) return;
    final position = _chatScrollController.position;
    _isChatAtBottom = position.pixels >= (position.maxScrollExtent - 24);
  }

  void onUserJoin(String userId, String userName,
      {int? vipLevel, int? novelLevel, String? entryEffect}) {
    final identity = PremiumIdentityController.getIdentity(
      userId,
      userName,
      vipLevel: vipLevel,
      novelLevel: novelLevel,
    );
    final finalVip = vipLevel ?? identity.vipLevel;
    final finalNovel = novelLevel ?? identity.novelLevel;

    _entranceQueue.add({
      'userId': userId,
      'userName': userName,
      'vipLevel': finalVip,
      'novelLevel': finalNovel,
      'entryEffect': entryEffect,
    });
    _processEntranceQueue();
  }

  Completer<void>? _currentEntranceCompleter;

  void _onEntranceAnimationFinished() {
    if (_currentEntranceCompleter != null &&
        !_currentEntranceCompleter!.isCompleted) {
      _currentEntranceCompleter!.complete();
    }
  }

  void _processEntranceQueue() async {
    if (_isEntrancePlaying.value || _entranceQueue.isEmpty) return;

    _isEntrancePlaying.value = true;
    final task = _entranceQueue.first;

    _currentEntranceUser.value = task['userName'];
    _currentEntranceUserId.value = task['userId'];
    _currentEntranceVipLevel.value = task['vipLevel'];
    _currentEntranceNovelLevel.value = task['novelLevel'];
    _currentEntranceEntryEffect.value = task['entryEffect'] ?? '';

    final completer = Completer<void>();
    _currentEntranceCompleter = completer;

    final String effectStr = (_currentEntranceEntryEffect.value ?? '').trim();
    final int vipLvl = _currentEntranceVipLevel.value;
    final int novelLvl = _currentEntranceNovelLevel.value;

    String targetEffect = 'None';
    if (effectStr.isNotEmpty && effectStr != 'null') {
      if (effectStr == 'Neon Gateway' ||
          effectStr == 'VIP 2' ||
          effectStr == 'VIP Level 2' ||
          effectStr == 'VIP2') {
        targetEffect = 'VIP 2';
      } else if (effectStr == 'Royal Portal' ||
          effectStr == 'VIP 1' ||
          effectStr == 'VIP Level 1' ||
          effectStr == 'VIP1') {
        targetEffect = 'VIP 1';
      } else if (effectStr.contains('Novel') || effectStr.contains('novel')) {
        targetEffect = 'Novel';
      } else if (effectStr == 'None') {
        targetEffect = 'None';
      } else {
        if (vipLvl >= 2) {
          targetEffect = 'VIP 2';
        } else if (vipLvl == 1) {
          targetEffect = 'VIP 1';
        } else if (novelLvl >= 1) {
          targetEffect = 'Novel';
        }
      }
    } else {
      if (vipLvl >= 2) {
        targetEffect = 'VIP 2';
      } else if (vipLvl == 1) {
        targetEffect = 'VIP 1';
      } else if (novelLvl >= 1) {
        targetEffect = 'Novel';
      }
    }

    _resolvedEntranceAnimation.value = targetEffect;

    if (targetEffect == 'VIP 2') {
      _showEntranceOverlay.value = false;
      VipEntryAnimation.show(
        context,
        username: _currentEntranceUser.value,
        avatarUrl:
            UserProfileCacheManager.getCachedUser(_currentEntranceUserId.value)
                ?.avatar,
        vipLevel: 2,
        onFinished: () {
          if (!mounted) return;
          _onEntranceAnimationFinished();
        },
      );
    } else if (targetEffect == 'Novel') {
      _showEntranceOverlay.value = false;
      final int activeNovelLvl = novelLvl > 0 ? novelLvl : 1;
      NovelEntryAnimation.show(
        context,
        username: _currentEntranceUser.value,
        avatarUrl:
            UserProfileCacheManager.getCachedUser(_currentEntranceUserId.value)
                ?.avatar,
        novelLevel: activeNovelLvl,
        onFinished: () {
          if (!mounted) return;
          final hasVipBanner = _currentEntranceVipLevel.value > 0;
          final hasNovelBanner = _currentEntranceNovelLevel.value > 1;

          if (hasVipBanner || hasNovelBanner) {
            _showEntranceOverlay.value = true;
          } else {
            _onEntranceAnimationFinished();
          }
        },
      );
    } else {
      _showEntranceOverlay.value = true;
    }

    await Future.any([
      completer.future,
      Future.delayed(const Duration(seconds: 12)),
    ]);

    if (!mounted) return;

    _showEntranceOverlay.value = false;
    _currentEntranceCompleter = null;

    _controller.addSystemActivity(
      widget.roomId,
      '🟢 ${_currentEntranceUser.value} entered the arena.',
      senderId: task['userId'],
      senderName: task['userName'],
      activityKey: 'room-enter',
    );

    _entranceQueue.removeAt(0);
    _isEntrancePlaying.value = false;

    _processEntranceQueue();
  }

  void _triggerGiftingAnimations(
      List<int> targets, String giftIcon, String giftName, int count,
      {String? giftId,
      String? senderName,
      String? senderAvatar,
      String? receiverName,
      String? receiverAvatar}) {
    final List<Offset> targetPositions = [];
    for (final seatIndex in targets) {
      final key = _seatKeys[seatIndex];
      if (key != null) {
        final RenderBox? box =
            key.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          final size = box.size;
          final offset = box.localToGlobal(Offset.zero);
          targetPositions.add(
              Offset(offset.dx + size.width / 2, offset.dy + size.height / 2));
        } else {
          targetPositions.add(Offset(Get.width / 2, Get.height / 3));
        }
      } else {
        targetPositions.add(Offset(Get.width / 2, Get.height / 3));
      }
    }

    if (targetPositions.isEmpty) return;

    final startPosition = Offset(Get.width / 2, Get.height - 100);
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();

    _activeGiftingAnimations.add({
      'id': requestId,
      'giftId': giftId ?? giftName,
      'start': startPosition,
      'targets': targetPositions,
      'icon': giftIcon,
      'name': giftName,
      'count': count,
      'senderName': senderName ?? 'Member',
      'senderAvatar': senderAvatar,
      'receiverName': receiverName ?? 'Seat',
      'receiverAvatar': receiverAvatar,
    });
  }

  void _shakeRoomScreen() {
    final random = Random();
    double shakeAmplitude = 6.0;
    int durationMs = 400;
    int intervalMs = 20;

    Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (timer.tick * intervalMs >= durationMs) {
        _shakeOffset.value = Offset.zero;
        timer.cancel();
      } else {
        _shakeOffset.value = Offset(
          (random.nextDouble() * 2 - 1) * shakeAmplitude,
          (random.nextDouble() * 2 - 1) * shakeAmplitude,
        );
      }
    });
  }

  void _triggerReaction(String emoji) {
    _reactions.add(
      FloatingReaction(
        key: UniqueKey(),
        emoji: emoji,
        startX: Random().nextDouble() * 200 - 100,
        speed: 1.0 + Random().nextDouble() * 0.5,
        size: 24.0 + Random().nextDouble() * 12.0,
      ),
    );
  }

  String _getUserDp(String uid) {
    final u = UserProfileCacheManager.getCachedUser(uid);
    if (u?.avatar != null && u!.avatar!.isNotEmpty) {
      return u.avatar!;
    }
    return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150';
  }

  void _handleSeatClick(int seatIndex, dynamic user) {
    final seatsList = _controller.roomSeatsInfo[widget.roomId] ?? [];
    final seat = seatsList.firstWhereOrNull((s) => s['seatIndex'] == seatIndex);
    final isOccupied = seat?['userId'] != null;
    final isLocked = seat?['isLocked'] == true;

    if (isOccupied) {
      final userId = seat!['userId'] as String;
      final userName = seat['name'] as String? ?? 'User';
      final role = seat['role'] as String? ?? 'Guest';

      if (userId == widget.userId) {
        SeatActionSheets.showSelfSeatActions(
          context: context,
          roomId: widget.roomId,
          seatIndex: seatIndex,
          isMicOn: _isMicOn.value,
          onToggleMic: _toggleMic,
          onLeaveSeat: _leaveSeat,
          seats: _seats,
        );
      } else {
        _showMiniProfileDialog(userId, userName, role, seatIndex);
      }
    } else {
      if (isLocked) {
        final callerRole = _controller.getUserRole(
            _controller.rooms.firstWhereOrNull((r) => r.id == widget.roomId) ??
                VoiceRoom.dummy(),
            widget.userId);
        final callerWeight = _controller.getRoleWeight(callerRole);

        if (callerWeight >= 7) {
          SeatActionSheets.showLockedSeatActions(
            context: context,
            roomId: widget.roomId,
            seatIndex: seatIndex,
            controller: _controller,
            onJoinSeat: _joinSeat,
            onStateChanged: () => setState(() {}),
          );
        } else {
          Get.snackbar(
            'Seat Locked 🔒',
            'This seat has been locked by the host.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: context.errorColor.withOpacity(0.8),
            colorText: Colors.white,
          );
        }
      } else {
        final callerRole = _controller.getUserRole(
            _controller.rooms.firstWhereOrNull((r) => r.id == widget.roomId) ??
                VoiceRoom.dummy(),
            widget.userId);
        final callerWeight = _controller.getRoleWeight(callerRole);

        if (callerWeight >= 7) {
          SeatActionSheets.showOpenSeatManagementActions(
            context: context,
            roomId: widget.roomId,
            seatIndex: seatIndex,
            controller: _controller,
            onJoinSeat: _joinSeat,
            onStateChanged: () => setState(() {}),
          );
        } else {
          _joinSeat(seatIndex);
        }
      }
    }
  }

  void _showMiniProfileDialog(
      String targetUserId, String targetUserName, String role, int seatIndex) {
    final occupiedSeats = (_controller.roomSeatsInfo[widget.roomId] ?? [])
        .where((s) => s['userId'] != null)
        .length;
    final liveRoom =
        _controller.rooms.firstWhereOrNull((r) => r.id == widget.roomId);
    final isHost = liveRoom?.hostId == widget.userId ||
        liveRoom?.founderId == widget.userId;

    Get.dialog(
      MiniProfileDialog(
        roomId: widget.roomId,
        callerUserId: widget.userId,
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        role: role,
        seatIndex: seatIndex,
        isHost: isHost,
        occupiedSeatsCount: occupiedSeats,
      ),
    );
  }

  void _showRoomOptionsMenuSheet(BuildContext context) {
    Get.bottomSheet(
      RoomOptionsSheet(roomId: widget.roomId),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<RoomDualProgressController>()) {
      RoomDualProgressController.to.unsubscribeRealtimeDualProgress(widget.roomId);
    }
    _glowController.dispose();
    _chatInputController.dispose();
    _chatInputFocusNode.dispose();
    _chatScrollController.dispose();
    _marqueeTimer?.cancel();
    _marqueeDelayTimer?.cancel();
    _debateTimer?.cancel();
    _giftBannerTimer?.cancel();
    _systemNotificationTimer?.cancel();
    _seatsSyncWorker.dispose();
    _marqueeWorker.dispose();
    _giftNotificationWorker?.dispose();
    _systemNotificationWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 0;
    final dynamicShift =
        isKeyboardOpen ? (bottomInset * 0.42).clamp(0.0, 150.0) : 0.0;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Obx(() {
          final liveRoom =
              _controller.rooms.firstWhereOrNull((r) => r.id == widget.roomId) ??
                  VoiceRoom.dummy();
          final offset = _shakeOffset.value;

          return Transform.translate(
            offset: offset,
            child: Stack(
              children: [
                // 1. Dynamic Background Layer (100% Fixed background)
                RoomCallBannerAndXp.buildCustomBackground(),

                // 2. Main Content Body with Fixed Header & Smart Shiftable Stage
                SafeArea(
                  child: Column(
                    children: [
                      // Top App Bar (100% Fixed at top of screen)
                      RoomCallHeader(
                        roomId: widget.roomId,
                        roomName: widget.roomName,
                        room: liveRoom,
                        userId: widget.userId,
                        getUserDp: _getUserDp,
                        onLeaveRoom: _leaveRoom,
                        onShowRoomOptionsMenuSheet: _showRoomOptionsMenuSheet,
                      ),

                      // Shiftable Stage Content (Seats, Special Panels, Chat Stream)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          transform:
                              Matrix4.translationValues(0, -dynamicShift, 0),
                          child: Column(
                            children: [
                              const SizedBox(height: 8),

                              // Seat Grid Section (Host & Audience seats shift up together)
                              RoomCallSeatGrid(
                                roomId: widget.roomId,
                                seatKeys: _seatKeys,
                                onSeatClick: _handleSeatClick,
                              ),

                              const SizedBox(height: 8),

                              // Special Arena Panel (Debate/Study/Music/Event)
                              RoomCallSpecialPanels(
                                roomId: widget.roomId,
                                room: liveRoom,
                                userId: widget.userId,
                                userName: widget.userName,
                                debateRound: _debateRound,
                                debateTimerSeconds: _debateTimerSeconds,
                                isDebateTimerRunning: _isDebateTimerRunning,
                                scoreCandidateA: _scoreCandidateA,
                                scoreCandidateB: _scoreCandidateB,
                                debateTimer: _debateTimer,
                                quizVotes: _quizVotes,
                                quizSelectedOption: _quizSelectedOption,
                                quizVoted: _quizVoted,
                                songQueue: _songQueue,
                                pollVotes: _pollVotes,
                                pollSelectedOption: _pollSelectedOption,
                                pollVoted: _pollVoted,
                                seats: _seats,
                                glowController: _glowController,
                                getUserDp: _getUserDp,
                                onJoinSeat: _joinSeat,
                                onShowLeaveSeatMenu: (idx) =>
                                    SeatActionSheets.showSelfSeatActions(
                                  context: context,
                                  roomId: widget.roomId,
                                  seatIndex: idx,
                                  isMicOn: _isMicOn.value,
                                  onToggleMic: _toggleMic,
                                  onLeaveSeat: _leaveSeat,
                                  seats: _seats,
                                ),
                                onShowMiniProfileDialog: _showMiniProfileDialog,
                              ),

                              // Chat Stream Box (Expands above keyboard)
                              Expanded(
                                child: RoomCallChatBox(
                                  roomId: widget.roomId,
                                  chatScrollController: _chatScrollController,
                                  getUserDp: _getUserDp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Floating Bottom Controls Dock (Pinned above keyboard)
                Positioned(
                  bottom: bottomInset,
                  left: 0,
                  right: 0,
                  child: RoomCallBottomControls(
                    roomId: widget.roomId,
                    chatInputController: _chatInputController,
                    chatInputFocusNode: _chatInputFocusNode,
                    isMicOn: _isMicOn,
                    isCurrentUserOnSeat: _isCurrentUserOnSeat(),
                    onToggleMic: _toggleMic,
                    onShowRoomOptionsMenuSheet: _showRoomOptionsMenuSheet,
                    onTriggerReaction: () => _triggerReaction('❤️'),
                  ),
                ),

              // 4. Floating Reactions Animation Layer
              Positioned.fill(
                child: IgnorePointer(
                  child: Obx(() {
                    final list = _reactions.toList();
                    return Stack(
                      children: list.map((r) {
                        return FloatingEmojiItem(
                          key: r.key,
                          reaction: r,
                        );
                      }).toList(),
                    );
                  }),
                ),
              ),

              // 5. Smart Gifting Animation Overlay Layer (Positioned on top of background & seats)
              Positioned.fill(
                child: GiftingAnimationOverlay(
                  activeAnimations: _activeGiftingAnimations,
                  seatKeys: _seatKeys,
                  onExplosion: (bool isMajor) {
                    if (isMajor) {
                      _shakeRoomScreen();
                    }
                  },
                ),
              ),

              // 6. Network Disconnect / Kick Overlay Layer
              RoomCallBannerAndXp.buildDisconnectOverlay(),
            ],
          ),
        );
      }),
    ),
  );
}
}
