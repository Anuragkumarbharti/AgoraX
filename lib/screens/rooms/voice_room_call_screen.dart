import 'dart:async';
import 'dart:math';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../services/user_profile_cache_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zego_uikit/zego_uikit.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/room_model.dart';
import '../../models/user_model.dart';
import '../../models/chat_model.dart';
import '../chat/chat_screen.dart';
import '../../services/chat_controller.dart';
import '../../services/zego_cloud_service.dart';
import '../../services/zego_room_service.dart';
import '../../services/permission_service.dart';
import '../../services/room_controller.dart';
import '../../widgets/send_gift_dialog.dart';
import '../../widgets/room_upgrade_dialog.dart';
import '../profile/profile_screen.dart';
import '../profile/user_profile_screen.dart';
import '../../widgets/mini_profile_widget.dart';
import '../../services/premium_identity_controller.dart';
import '../../services/customization_controller.dart';
import '../../widgets/index.dart';
import '../../widgets/vip_entry_animation.dart';
import '../../widgets/novel_entry_animation.dart';
import '../../widgets/default_entry_animation.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FloatingReaction {
  final Key key;
  final String emoji;
  final double startX;
  final double speed;
  final double size;

  FloatingReaction({
    required this.key,
    required this.emoji,
    required this.startX,
    required this.speed,
    required this.size,
  });
}

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
  late ZegoCloudService _zegoService;
  late PermissionService _permissionService;
  late RoomController _controller;
  bool _isMicOn = false;
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
  Timer? _speakingSimulationTimer;

  // Chat UI controllers
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  RoomChatMessage? _replyTarget;
  bool _isChatAtBottom = true;
  DateTime _messageCooldownUntil = DateTime.fromMillisecondsSinceEpoch(0);
  final RxBool _showEntranceOverlay = false.obs;
  Timer? _heartbeatTimer;
  final RxList<Map<String, dynamic>> _entranceQueue = <Map<String, dynamic>>[].obs;
  final RxBool _isEntrancePlaying = false.obs;
  final RxString _currentEntranceUser = ''.obs;
  final RxString _currentEntranceUserId = ''.obs;
  final RxInt _currentEntranceVipLevel = 0.obs;
  final RxInt _currentEntranceNovelLevel = 0.obs;
  
  bool _showEmojiPanel = false;
  final RxBool _showMentionAutocomplete = false.obs;
  final RxList<Map<String, String>> _mentionSuggestions = <Map<String, String>>[].obs;
  
  final RxList<String> _followedUsers = <String>[].obs;
  final RxList<String> _blockedUsers = <String>[].obs;

  // Floating Reactions
  final RxList<FloatingReaction> _reactions = <FloatingReaction>[].obs;
  
  Worker? _giftNotificationWorker;
  Worker? _systemNotificationWorker;
  Timer? _giftBannerTimer;
  Timer? _systemNotificationTimer;

  // Pinned announcements
  final RxString _pinnedNote =
      '📚 Welcome to the Arena! Stay polite and have fun.'.obs;

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
    _zegoService = ZegoCloudService();
    _permissionService = PermissionService();
    _controller = RoomController.to;
    _controller.activeRoomId = widget.roomId;
    _controller.hidePipBubble();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _initializeSeats();

    // Subscribe to controller's roomSeatsInfo changes to keep local _seats in sync
    _seatsSyncWorker = ever(_controller.roomSeatsInfo, (Map<String, List<Map<String, dynamic>>> infoMap) {
      final list = infoMap[widget.roomId];
      if (list != null && list.isNotEmpty) {
        _seats.assignAll(list);
      }
    });

    // Subscribe to marquee queue updates
    _marqueeWorker = ever(_controller.marqueeAnnouncementsQueue, (List<String> queue) {
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

    // Gift notification timer auto-clear
    _giftNotificationWorker = ever(_controller.activeGiftNotification, (Map<String, dynamic>? data) {
      if (data != null) {
        _giftBannerTimer?.cancel();
        _giftBannerTimer = Timer(const Duration(seconds: 4), () {
          _controller.activeGiftNotification.value = null;
        });
      }
    });

    // System notification toast timer auto-clear
    _systemNotificationWorker = ever(_controller.activeSystemNotification, (String? msg) {
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
          final novel = int.tryParse(event['noble_level']?.toString() ?? '0') ?? 0;
          _entranceQueue.add({
            'userId': uId,
            'userName': uName ?? 'User',
            'vipLevel': vip,
            'novelLevel': novel,
          });
          _processEntranceQueue();
        }
      }
    });

    _initializeRoom();
    _chatScrollController.addListener(_handleChatScroll);
    _startSpeakingSimulation();
    _startMarqueeSimulation();

    // Start secure heartbeat reporting
    _controller.heartbeatRoomMember(widget.roomId, _isMicOn);
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted) {
        _controller.heartbeatRoomMember(widget.roomId, _isMicOn);
      }
    });
  }

  void _startMarqueeSimulation() {
    // Initial delay simulation
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _controller.marqueeAnnouncementsQueue.add('🔥 Rahul Roy (Performer) is singing a song! 🎵');
    });

    _marqueeTimer = Timer.periodic(const Duration(seconds: 22), (timer) {
      if (!mounted) return;
      final messages = [
        '👑 Priya Sharma (Co-owner) gifted 👑 Castle to all seats!',
        '♕ Owner Anurag Kumar Bharti joined the arena!',
        '💎 Vikram Aditya (Admin) locked Seat 8.',
        '👑 Aleena ♕ Queen 👑 💜 and 👑 💜 Shan ♕ KinG 👑 💜 have joined the arena!',
        '🔥 Rahul Roy (Performer) is singing a song! 🎵',
        '⚡ Divya Sharma (VIP Member) entered the Arena!',
      ];
      final randomText = messages[Random().nextInt(messages.length)];
      _controller.marqueeAnnouncementsQueue.add(randomText);
    });
  }

  void _playNextMarquee() {
    _marqueeDelayTimer?.cancel();
    
    if (_localAnnouncementsQueue.isNotEmpty) {
      _currentMarqueeText.value = _localAnnouncementsQueue.removeAt(0);
      _showBanner.value = true;
      _marqueeResetCounter.value++;
    } else if (_currentMarqueeText.value.isNotEmpty) {
      // Loop the current one!
      _marqueeDelayTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        _marqueeResetCounter.value++;
      });
    } else {
      _showBanner.value = false;
    }
  }

  void _initializeSeats() {
    _seats.assignAll(List.generate(10, (index) => {
      'seatIndex': index,
      'role': index == 0 ? 'Owner' : (index == 1 ? 'Co-owner' : 'Guest'),
      'userId': (index == 0 && widget.isHost) ? widget.userId : null,
      'name': (index == 0 && widget.isHost) ? widget.userName : 'Seat ${index + 1}',
      'isSpeaking': index == 0 && widget.isHost,
      'isLocked': false,
    }));
  }

  Future<void> _initializeRoom() async {
    try {
      final permissionsGranted =
          await _permissionService.requestAllPermissions();

      if (!permissionsGranted) {
        Get.snackbar(
          'Permissions Required',
          'Please enable microphone and camera permissions',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.warningColor,
        );
        Navigator.pop(context);
        return;
      }

      // Initialize and join ZEGOCLOUD room securely using Token Authentication
      final zegoRoomService = CustomZegoRoomService();
      await zegoRoomService.joinVoiceRoom(
        roomId: widget.roomId,
        userId: widget.userId,
        userName: widget.userName,
        enableMic: widget.isHost,
        enableCamera: false,
      );

      // Call enterRoom to synchronize Supabase membership, events, and setup realtime subscriptions
      await _controller.enterRoom(widget.roomId);

      // Auto-seat Host or Restore return seats from database
      if (widget.isHost) {
        await _controller.joinRoomSeat(widget.roomId, 0);
      } else {
        await _controller.fetchRoomProgression(widget.roomId);
        final seatsList = _controller.roomSeatsInfo[widget.roomId] ?? [];
        final mySeat = seatsList.firstWhereOrNull((s) => s['userId'] == widget.userId);
        if (mySeat != null) {
          final micStatus = mySeat['micStatus'] ?? 'unmuted';
          _zegoService.toggleMic(micStatus == 'unmuted');
        }
      }

      // Delay setState past current frame to avoid calling it during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            if (widget.isHost) {
              _isMicOn = true;
            } else {
              final seatsList = _controller.roomSeatsInfo[widget.roomId] ?? [];
              final mySeat = seatsList.firstWhereOrNull((s) => s['userId'] == widget.userId);
              if (mySeat != null) {
                _isMicOn = (mySeat['micStatus'] ?? 'unmuted') == 'unmuted';
              }
            }
          });
        }
      });

      _controller.initializeChatForRoom(widget.roomId);
      onUserJoin(widget.userId, widget.userName);
      _startSimulatedUsersTimer();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to initialize arena: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor,
      );
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context);
      });
    }
  }

  void _startSpeakingSimulation() {
    _speakingSimulationTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      for (int i = 0; i < _seats.length; i++) {
        final seat = _seats[i];
        if (seat['userId'] != null) {
          if (seat['userId'] == widget.userId) {
            _seats[i] = {
              ...seat,
              'isSpeaking': _isMicOn,
            };
          } else {
            _seats[i] = {
              ...seat,
              'isSpeaking': Random().nextBool(),
            };
          }
        }
      }
    });
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
        backgroundColor: AppTheme.warningColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    try {
      final newState = !_isMicOn;
      _zegoService.toggleMic(newState);
      setState(() => _isMicOn = newState);

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

  Future<void> _toggleCamera() async {
    if (!_isCurrentUserOnSeat()) {
      Get.snackbar(
        'Camera Locked 🔒',
        'You must join a seat to turn on your camera.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.warningColor.withOpacity(0.9),
      );
      return;
    }
    try {
      final newState = !_isCameraOn;
      _zegoService.toggleCamera(newState);
      setState(() => _isCameraOn = newState);
    } catch (e) {
      Get.snackbar('Error', 'Failed to toggle camera',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _joinSeat(int seatIndex) async {
    final seatsList = _controller.roomSeatsInfo[widget.roomId] ?? [];
    final seat = seatsList.firstWhereOrNull((s) => s['seatIndex'] == seatIndex);
    if (seat != null && seat['userId'] == widget.userId) {
      _showLeaveSeatMenu(seatIndex);
      return;
    }

    try {
      await _controller.joinRoomSeat(widget.roomId, seatIndex);

      _zegoService.toggleMic(true);
      setState(() => _isMicOn = true);

      Get.snackbar(
        'Stage Joined 🎤',
        'You are now in Seat ${seatIndex + 1}. Speak freely!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.successColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to join seat: $e');
    }
  }

  Future<void> _leaveSeat(int seatIndex) async {
    try {
      await _controller.leaveRoomSeat(widget.roomId, seatIndex);

      _zegoService.toggleMic(false);
      setState(() {
        _isMicOn = false;
        _isCameraOn = false;
      });

      Get.snackbar(
        'Left Stage 🚪',
        'You returned to the audience. Your microphone has been muted.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.warningColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to leave seat: $e');
    }
  }

  void _showLeaveSeatMenu(int seatIndex) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your Seat Actions',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: Colors.orange),
              title: const Text('Leave Stage (Move to Audience)',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                _leaveSeat(seatIndex);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: AppTheme.textTertiary),
              title: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textTertiary)),
              onTap: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _leaveRoom() async {
    try {
      _controller.emitRoomActivity(widget.roomId, '👋 ${widget.userName} left the arena.', activityKey: 'room-leave');
      Get.back();
    } catch (e) {
      Get.snackbar('Error', 'Failed to leave arena',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _scrollChatToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleChatScroll() {
    if (!_chatScrollController.hasClients) return;
    final position = _chatScrollController.position;
    _isChatAtBottom = position.pixels >= (position.maxScrollExtent - 24);
  }

  void _maybeAutoScroll() {
    if (_isChatAtBottom) {
      _scrollChatToBottom();
    }
  }

  void onUserJoin(String userId, String userName) {
    final identity = PremiumIdentityController.getIdentity(userId, userName);
    final vipLevel = identity.vipLevel;
    final novelLevel = identity.novelLevel;

    _entranceQueue.add({
      'userId': userId,
      'userName': userName,
      'vipLevel': vipLevel,
      'novelLevel': novelLevel,
    });
    _processEntranceQueue();
  }

  void _processEntranceQueue() async {
    if (_isEntrancePlaying.value || _entranceQueue.isEmpty) return;

    _isEntrancePlaying.value = true;
    final task = _entranceQueue.first;

    _currentEntranceUser.value = task['userName'];
    _currentEntranceUserId.value = task['userId'];
    _currentEntranceVipLevel.value = task['vipLevel'];
    _currentEntranceNovelLevel.value = task['novelLevel'];

    _showEntranceOverlay.value = true;

    await Future.delayed(const Duration(milliseconds: 3200));

    if (!mounted) return;

    _showEntranceOverlay.value = false;

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

  Timer? _simulatedUsersTimer;

  void _startSimulatedUsersTimer() {
    _simulatedUsersTimer = Timer.periodic(const Duration(seconds: 24), (timer) {
      if (!mounted) return;
      final names = [
        {'name': 'Aleena Queen', 'vip': '4', 'novel': '0'},
        {'name': 'Shan King', 'vip': '7', 'novel': '0'},
        {'name': 'Rahul Roy', 'vip': '0', 'novel': '3'},
        {'name': 'Divya Sharma', 'vip': '0', 'novel': '5'},
      ];
      final user = names[Random().nextInt(names.length)];
      final uName = user['name']!;

      onUserJoin('uid_${uName.toLowerCase().replaceAll(' ', '_')}', uName);
    });
  }

  final RxInt _taskProgress = 0.obs;

  void _showRoomTasksDialog() {
    _controller.fetchRoomProgression(widget.roomId);

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                blurRadius: 20,
              )
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'DAILY ARENA TASKS',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Obx(() {
                final stats = _controller.roomStats[widget.roomId];
                final currentPoints = stats?.todayTaskPoints ?? 0;
                final extraPoints = stats?.todayExtraXpPoints ?? 0;
                final totalPoints = currentPoints + extraPoints;
                
                return Text(
                  'Task Points: $totalPoints / 1200 (${extraPoints} Extra points)',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                );
              }),
              const SizedBox(height: 16),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: Get.height * 0.5),
                  child: Obx(() {
                    final tasks = _controller.roomDailyTaskLists[widget.roomId] ?? [];
                    if (tasks.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final t = tasks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildTaskItem(
                            title: t.description,
                            description: 'Rewards: +${t.taskPoints} TP, +${t.xpReward} XP, +${t.silverReward} Silver',
                            progress: '${t.currentValue}/${t.targetValue}',
                            isClaimed: t.isCompleted,
                            onClaim: null,
                          ),
                        );
                      },
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskItem({
    required String title,
    required String description,
    required String progress,
    required bool isClaimed,
    required VoidCallback? onClaim,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(description, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Text(progress, style: GoogleFonts.poppins(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (onClaim != null)
                ElevatedButton(
                  onPressed: isClaimed ? null : onClaim,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isClaimed ? Colors.white12 : const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: const Size(60, 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    isClaimed ? 'Claimed' : 'Claim',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isClaimed ? Colors.green.withOpacity(0.1) : Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isClaimed ? Colors.green.withOpacity(0.3) : Colors.white12),
                  ),
                  child: Text(
                    isClaimed ? 'Completed' : 'In Progress',
                    style: TextStyle(
                      color: isClaimed ? Colors.green : Colors.white60,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _checkMentionAutocomplete(String text) {
    if (text.endsWith('@')) {
      final list = _seats
          .where((s) => s['userId'] != null && s['userId'] != widget.userId)
          .map((s) => {'userId': s['userId'] as String, 'name': s['name'] as String})
          .toList();
      _mentionSuggestions.assignAll(list);
      _showMentionAutocomplete.value = list.isNotEmpty;
    } else if (text.contains('@')) {
      final parts = text.split('@');
      final query = parts.last.toLowerCase();
      if (query.contains(' ')) {
        _showMentionAutocomplete.value = false;
        return;
      }
      final list = _seats
          .where((s) => s['userId'] != null && s['userId'] != widget.userId)
          .map((s) => {'userId': s['userId'] as String, 'name': s['name'] as String})
          .where((u) => u['name']!.toLowerCase().contains(query))
          .toList();
      _mentionSuggestions.assignAll(list);
      _showMentionAutocomplete.value = list.isNotEmpty;
    } else {
      _showMentionAutocomplete.value = false;
    }
  }

  void _selectMentionSuggestion(String name) {
    final text = _chatInputController.text;
    final int atIndex = text.lastIndexOf('@');
    if (atIndex != -1) {
      final newText = text.substring(0, atIndex) + '@${name.replaceAll(' ', '_')} ';
      _chatInputController.text = newText;
      _chatInputController.selection = TextSelection.fromPosition(
        TextPosition(offset: _chatInputController.text.length),
      );
    }
    _showMentionAutocomplete.value = false;
  }

  String _applyProfanityFilter(String text) {
    const bannedWords = ['badword1', 'badword2', 'badword3'];
    var filtered = text;
    for (final word in bannedWords) {
      filtered = filtered.replaceAll(RegExp(word, caseSensitive: false), '***');
    }
    return filtered;
  }

  Future<void> _submitChatMessage(VoiceRoom room) async {
    final rawText = _chatInputController.text.trim();
    if (rawText.isEmpty) return;

    final now = DateTime.now();
    if (now.isBefore(_messageCooldownUntil)) {
      Get.snackbar(
        'Slow down',
        'Please wait a moment before sending another message.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    final roomRole = _controller.getUserRole(room, widget.userId);
    final identity = PremiumIdentityController.getIdentity(widget.userId, widget.userName);
    final cleaned = _applyProfanityFilter(rawText);

    _controller.sendRoomMessage(
      widget.roomId,
      cleaned,
      senderId: widget.userId,
      senderName: widget.userName,
      senderRole: roomRole,
      senderAvatar: widget.isHost
          ? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150'
          : null,
      replyToMessageId: _replyTarget?.id,
      senderLevel: 'Lv ${identity.idLevel}',
      vipLabel: identity.vipLevel > 0 ? 'VIP ${identity.vipLevel}' : null,
      novelLabel: identity.novelLevel > 0 ? 'Novel ${identity.novelLevel}' : null,
      communityTag: identity.communityTag?.name,
      roleTag: roomRole,
      isActiveSpeaker: _isMicOn,
    );

    _messageCooldownUntil = now.add(const Duration(seconds: 2));
    _chatInputController.clear();
    setState(() {
      _replyTarget = null;
    });
    _maybeAutoScroll();
  }

  void _setReplyTarget(RoomChatMessage msg) {
    setState(() {
      _replyTarget = msg;
    });
  }

  void _clearReplyTarget() {
    setState(() {
      _replyTarget = null;
    });
  }

  bool _canDeleteAnyMessage(VoiceRoom room) {
    final myRole = _controller.getUserRole(room, widget.userId);
    return _controller.getRoleWeight(myRole) >= 8;
  }

  TextSpan _buildRichTextWithMentions(String text) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'@([A-Za-z0-9_]+)');
    int start = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.w700),
        ),
      );
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return TextSpan(children: spans, style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 11));
  }

  Widget _buildChatMessageTile(RoomChatMessage msg) {
    if (msg.isSystem) {
      final String emojiPrefix = msg.text.substring(0, min(2, msg.text.length)).trim();
      final Color accentColor = _getSystemEventColor(emojiPrefix);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: AnimatedOpacity(
          opacity: 1,
          duration: const Duration(milliseconds: 280),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0F172A).withOpacity(0.75),
                  const Color(0xFF1E293B).withOpacity(0.55),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.18), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    emojiPrefix.isNotEmpty ? emojiPrefix : '⚙️',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    msg.repeatCount > 1 ? '${msg.text} x${msg.repeatCount}' : msg.text,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final identity = PremiumIdentityController.getIdentity(msg.senderId, msg.senderName);
    final room = _controller.rooms.firstWhere((r) => r.id == widget.roomId);
    final isMine = msg.senderId == widget.userId;
    final canDelete = _canDeleteAnyMessage(room) || isMine;

    final avatarUrl = msg.senderAvatar;
    final roleColor = _getRoleBadgeColor(msg.senderRole ?? 'Guest');
    final bool isSpeaking = msg.isActiveSpeaker;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: GestureDetector(
        onLongPress: () => _showMessageMenu(msg, canDelete),
        onSecondaryTapDown: (_) => _showMessageMenu(msg, canDelete),
        child: Obx(() {
          final u = UserProfileCacheManager.rxCache[msg.senderId] ?? UserProfileCacheManager.getCachedUser(msg.senderId);
          final String uName = u?.username ?? msg.senderName;
          final String? uAvatar = u?.avatar ?? msg.senderAvatar;
          final int uLevel = u?.level ?? 25;
          final int vipLevel = u?.vipLevel ?? 0;
          final int novelLevel = u?.novelLevel ?? 0;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _showProfilePopup(msg),
                child: CustomAvatarFrame(
                  userId: msg.senderId,
                  username: uName,
                  size: 36,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: uAvatar != null && uAvatar.isNotEmpty
                        ? CachedNetworkImageProvider(uAvatar)
                        : null,
                    child: uAvatar == null || uAvatar.isEmpty
                        ? _buildDefaultAvatar(uName, roleColor)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine ? const Color(0xFF1E1B4B).withOpacity(0.9) : const Color(0xFF0F172A).withOpacity(0.7),
                    borderRadius: BorderRadius.only(
                      topRight: const Radius.circular(20),
                      bottomLeft: const Radius.circular(20),
                      bottomRight: const Radius.circular(20),
                      topLeft: isMine ? const Radius.circular(20) : Radius.zero,
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          PremiumNameWidget(
                            name: uName,
                            userId: msg.senderId,
                            style: GoogleFonts.outfit(
                              color: isMine ? const Color(0xFFC084FC) : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _buildTinyTag('LV $uLevel', const Color(0xFF38BDF8)),
                          if (vipLevel > 0) _buildTinyTag('VIP $vipLevel', const Color(0xFFFFD700)),
                          if (novelLevel > 0) _buildTinyTag('Novel $novelLevel', const Color(0xFFF97316)),
                          if (msg.communityTag != null) _buildTinyTag(msg.communityTag!, const Color(0xFF10B981)),
                          if ((msg.senderRole ?? '').isNotEmpty && msg.senderRole != 'Guest')
                            _buildTinyTag(msg.senderRole!, roleColor),
                        ],
                      ),
                    const SizedBox(height: 6),
                    if (msg.replyToMessageId != null) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.04)),
                        ),
                        child: Text(
                          'Replying to previous message',
                          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9),
                        ),
                      ),
                    ],
                    Text.rich(
                      _buildRichTextWithMentions(msg.text),
                      style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.95), fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    if (identity.vipLevel > 0 || identity.novelLevel > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: identity.buildBadges(context, fontSize: 8.0).take(4).toList(),
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatMessageTimestamp(msg.timestamp),
                          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 8.5),
                        ),
                        Text(
                          'Reply / Copy',
                          style: GoogleFonts.poppins(color: Colors.white24, fontSize: 8.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        }),
      ),
    );
  }

  Color _getSystemEventColor(String emoji) {
    switch (emoji) {
      case '🟢': return const Color(0xFF10B981);
      case '👋': return const Color(0xFF6B7280);
      case '🎤': return const Color(0xFF8B5CF6);
      case '💺': return const Color(0xFFEF4444);
      case '🔄': return const Color(0xFFF59E0B);
      case '👑': return const Color(0xFFFBBF24);
      case '⭐': return const Color(0xFFF59E0B);
      case '🛡️': return const Color(0xFF3B82F6);
      case '🔇': return const Color(0xFFEF4444);
      case '🔊': return const Color(0xFF10B981);
      case '🚫': return const Color(0xFFDC2626);
      case '🎁': return const Color(0xFFEC4899);
      case '🎉': return const Color(0xFF10B981);
      case '💎': return const Color(0xFFFBBF24);
      case '📚': return const Color(0xFFF97316);
      case '🏆': return const Color(0xFF10B981);
      case '📢': return const Color(0xFF38BDF8);
      case '🔒': return const Color(0xFFEF4444);
      case '🔓': return const Color(0xFF10B981);
      case '🎊': return const Color(0xFFFF007F);
      case '✅': return const Color(0xFF10B981);
      default: return const Color(0xFFC084FC);
    }
  }

  Widget _buildTinyTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.32), width: 0.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(color: color, fontSize: 7.4, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _formatMessageTimestamp(DateTime timestamp) {
    final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final suffix = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  void _showMessageMenu(RoomChatMessage msg, bool canDeleteAny) {
    final room = _controller.rooms.firstWhere((r) => r.id == widget.roomId);
    final canDelete = canDeleteAny || msg.senderId == widget.userId;

    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: Colors.white70),
              title: const Text('Reply', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                _setReplyTarget(msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.white70),
              title: const Text('Copy', style: TextStyle(color: Colors.white)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.text));
                Get.back();
                Get.snackbar('Copied', 'Message copied to clipboard');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_search_rounded, color: Colors.white70),
              title: const Text('View Profile', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                _showProfilePopup(msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.send_rounded, color: Colors.white70),
              title: const Text('Private Message', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                final conversation = Conversation(
                  id: 'room-${widget.roomId}-${msg.senderId}',
                  otherUserId: msg.senderId,
                  otherUserName: msg.senderName,
                  otherUserAvatar: msg.senderAvatar ?? _getUserDp(msg.senderId),
                  lastMessage: '',
                  lastMessageTime: DateTime.now(),
                  level: PremiumIdentityController.getIdentity(msg.senderId, msg.senderName).idLevel,
                );
                Get.to(() => ChatScreen(conversation: conversation));
              },
            ),
            ListTile(
              leading: const Icon(Icons.card_giftcard_rounded, color: Colors.amber),
              title: const Text('Send Gift', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                Get.dialog(SendGiftDialog(roomId: widget.roomId, occupiedSeatsCount: _seats.where((s) => s['userId'] != null).length));
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: Colors.redAccent),
              title: const Text('Block User', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                Get.snackbar('Blocked', '${msg.senderName} blocked locally in this arena.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: Colors.orangeAccent),
              title: const Text('Report User', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                Get.snackbar('Report', 'Report submitted for ${msg.senderName}.');
              },
            ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                title: const Text('Delete Message', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Get.back();
                  _controller.deleteRoomMessage(widget.roomId, msg.id);
                  _maybeAutoScroll();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showProfilePopup(RoomChatMessage msg) {
    final identity = PremiumIdentityController.getIdentity(msg.senderId, msg.senderName);
    final user = User(
      id: msg.senderId,
      username: msg.senderName.replaceAll(' ', '_').toLowerCase(),
      email: '${msg.senderId}@creania.local',
      displayName: msg.senderName,
      avatar: msg.senderAvatar,
      interests: const ['Voice Arenas'],
      communities: msg.communityTag != null ? [msg.communityTag!] : const [],
      followers: 0,
      following: 0,
      isVerified: identity.idLevel >= 25,
      isPremium: identity.vipLevel > 0 || identity.novelLevel > 0,
      reputation: identity.trustScore,
      sid: msg.senderId.hashCode.abs().toString(),
      level: identity.idLevel,
      xp: identity.idLevel * 100,
      totalXp: identity.idLevel * 1000,
      badges: const [],
      levelTitle: 'Voice Member',
    );

    final isSpeaking = msg.isActiveSpeaker;
    final roleColor = _getRoleBadgeColor(msg.senderRole ?? 'Guest');

    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: AppTheme.bgDark.withOpacity(0.98),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isSpeaking)
                      Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF10B981),
                              blurRadius: 10,
                              spreadRadius: 2.0,
                            ),
                          ],
                        ),
                      ),
                    CustomAvatarFrame(
                      userId: msg.senderId,
                      username: msg.senderName,
                      size: 50,
                      isSpeaking: isSpeaking,
                      role: msg.senderRole,
                      child: CircleAvatar(
                        radius: 23,
                        backgroundImage: msg.senderAvatar != null && msg.senderAvatar!.isNotEmpty
                            ? NetworkImage(msg.senderAvatar!)
                            : null,
                        child: msg.senderAvatar == null || msg.senderAvatar!.isEmpty
                            ? _buildDefaultAvatar(msg.senderName, roleColor)
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            msg.senderName,
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          if (identity.idLevel >= 25)
                            const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 16),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildTinyTag(msg.senderLevel ?? 'LV ${identity.idLevel}', const Color(0xFF38BDF8)),
                          if (msg.vipLabel != null) _buildTinyTag(msg.vipLabel!, const Color(0xFFFFD700)),
                          if (msg.novelLabel != null) _buildTinyTag(msg.novelLabel!, const Color(0xFFF97316)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.25,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                Obx(() {
                  final isFollowing = _followedUsers.contains(msg.senderId);
                  return _buildActionButton(
                    icon: isFollowing ? Icons.person_remove_rounded : Icons.person_add_rounded,
                    label: isFollowing ? 'Unfollow' : 'Follow',
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      Get.back();
                      if (isFollowing) {
                        _followedUsers.remove(msg.senderId);
                        Get.snackbar('Unfollowed', 'You unfollowed ${msg.senderName}.', snackPosition: SnackPosition.BOTTOM);
                      } else {
                        _followedUsers.add(msg.senderId);
                        Get.snackbar('Followed', 'You followed ${msg.senderName}!', snackPosition: SnackPosition.BOTTOM);
                      }
                    },
                  );
                }),
                _buildActionButton(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Message',
                  color: const Color(0xFF38BDF8),
                  onTap: () {
                    Get.back();
                    final conversation = Conversation(
                      id: 'room-${widget.roomId}-${msg.senderId}',
                      otherUserId: msg.senderId,
                      otherUserName: msg.senderName,
                      otherUserAvatar: msg.senderAvatar ?? _getUserDp(msg.senderId),
                      lastMessage: '',
                      lastMessageTime: DateTime.now(),
                      level: PremiumIdentityController.getIdentity(msg.senderId, msg.senderName).idLevel,
                    );
                    Get.to(() => ChatScreen(conversation: conversation));
                  },
                ),
                _buildActionButton(
                  icon: Icons.card_giftcard_rounded,
                  label: 'Gift',
                  color: const Color(0xFFF97316),
                  onTap: () {
                    Get.back();
                    Get.dialog(
                      SendGiftDialog(
                        roomId: widget.roomId,
                        targetUserId: msg.senderId,
                        targetUserName: msg.senderName,
                        occupiedSeatsCount: _seats.where((s) => s['userId'] != null).length,
                      ),
                    );
                  },
                ),
                Obx(() {
                  final isBlocked = _blockedUsers.contains(msg.senderId);
                  return _buildActionButton(
                    icon: Icons.block_rounded,
                    label: isBlocked ? 'Unblock' : 'Block',
                    color: Colors.redAccent,
                    onTap: () {
                      Get.back();
                      if (isBlocked) {
                        _blockedUsers.remove(msg.senderId);
                        Get.snackbar('Unblocked', '${msg.senderName} has been unblocked.', snackPosition: SnackPosition.BOTTOM);
                      } else {
                        _blockedUsers.add(msg.senderId);
                        Get.snackbar('Blocked', '${msg.senderName} has been blocked locally.', snackPosition: SnackPosition.BOTTOM);
                      }
                    },
                  );
                }),
                _buildActionButton(
                  icon: Icons.flag_rounded,
                  label: 'Report',
                  color: Colors.orangeAccent,
                  onTap: () {
                    Get.back();
                    Get.snackbar('Report Submitted', 'We will review ${msg.senderName}\'s activity.', snackPosition: SnackPosition.BOTTOM);
                  },
                ),
                _buildActionButton(
                  icon: Icons.account_circle_rounded,
                  label: 'Profile',
                  color: Colors.white60,
                  onTap: () {
                    Get.back();
                    Get.to(() => UserProfileScreen(user: user));
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _triggerReaction(String emoji) {
    final key = UniqueKey();
    final random = Random();
    final reaction = FloatingReaction(
      key: key,
      emoji: emoji,
      startX: random.nextDouble() * 120 + 20,
      speed: random.nextDouble() * 2 + 3,
      size: random.nextDouble() * 10 + 24,
    );
    _reactions.add(reaction);

    Future.delayed(const Duration(seconds: 2), () {
      _reactions.removeWhere((r) => r.key == key);
    });
  }

  // Get User DP based on user ID
  String _getUserDp(String userId) {
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (userId == 'uid_anurag_101' || userId == 'me' || (currentUid != null && userId == currentUid)) {
      final avatarUrl = UserProfileCacheManager.currentUser?.avatar;
      if (avatarUrl != null && avatarUrl.isNotEmpty) return avatarUrl;
    }
    final u = UserProfileCacheManager.getCachedUser(userId);
    if (u != null && u.avatar != null && u.avatar!.isNotEmpty) return u.avatar!;

    if (userId == 'uid_anurag_101') {
      return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150'; // User DP
    } else if (userId == 'user_co_1' || userId.contains('priya')) {
      return 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150';
    } else if (userId == 'user_adm_1' || userId.contains('vikram')) {
      return 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150';
    } else if (userId == 'user_perf_1' || userId.contains('rahul')) {
      return 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=150';
    } else if (userId == 'user_star_1' || userId.contains('siddharth')) {
      return 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150';
    } else if (userId == 'user_man_1' || userId.contains('rajesh')) {
      return 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150';
    } else if (userId == 'user_mod_1' || userId.contains('sneha')) {
      return 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150';
    } else if (userId == 'user_host_1' || userId.contains('karan')) {
      return 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150';
    } else if (userId == 'user_elite_1' || userId.contains('arjun')) {
      return 'https://images.unsplash.com/photo-1500048993953-d23a436266cf?w=150';
    } else if (userId == 'user_vip_1' || userId.contains('divya')) {
      return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150';
    } else if (userId == 'user_memb_1' || userId.contains('kabir')) {
      return 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150';
    } else if (userId == 'user_vis_1' || userId.contains('ananya')) {
      return 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150';
    } else {
      return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150';
    }
  }

  // Get Role Badge color helper
  Color _getRoleBadgeColor(String role) {
    switch (role) {
      case 'Owner':
        return const Color(0xFFFFD700);
      case 'Co-owner':
        return Colors.amber;
      case 'Admin':
        return Colors.purpleAccent;
      case 'Star Member':
        return Colors.cyanAccent;
      case 'Guest':
        return Colors.white54;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _seatsSyncWorker.dispose();
    _marqueeWorker.dispose();
    _marqueeDelayTimer?.cancel();
    _heartbeatTimer?.cancel();
    _controller.exitRoom(widget.roomId);
    CustomZegoRoomService().leaveVoiceRoom();
    _speakingSimulationTimer?.cancel();
    _debateTimer?.cancel();
    _marqueeTimer?.cancel();
    _simulatedUsersTimer?.cancel();
    _giftNotificationWorker?.dispose();
    _systemNotificationWorker?.dispose();
    _giftBannerTimer?.cancel();
    _systemNotificationTimer?.cancel();
    _glowController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryColor)),
              const SizedBox(height: 24),
              Text('Connecting to Arena...',
                  style:
                      GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Theme-based background
            _buildCustomBackground(),

            // 2. Main Content area (with static headers/seats and scrollable chat)
            Positioned.fill(
              top: 55,
              bottom: 120, // Leave space for bottom control bar
              child: Column(
                children: [
                  _buildRoomLevelAndXpProgress(),
                  
                   // Task Badges and Program Info Row
                  _buildTaskBadgesAndProgramInfo(),
                  
                  const SizedBox(height: 16),

                  // The 10-seat native grid layout matching the screenshot
                  _buildCustomSeatGrid(),

                  // WePlay-style animated horizontal gift notification banner
                  Obx(() {
                    final giftData = _controller.activeGiftNotification.value;
                    if (giftData == null) return const SizedBox.shrink();

                    final senderName = giftData['senderName'] ?? 'Someone';
                    final amount = giftData['amount'] ?? 1;
                    final receiverName = giftData['receiverName'] ?? 'someone';
                    final senderAvatar = giftData['senderAvatar'] as String?;
                    final receiverAvatar = giftData['receiverAvatar'] as String?;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      height: 38,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                        ),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pinkAccent.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 4),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFFD700), width: 1.0),
                            ),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundImage: senderAvatar != null && senderAvatar.isNotEmpty
                                  ? NetworkImage(senderAvatar)
                                  : const AssetImage('assets/images/placeholder.png') as ImageProvider,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '$senderName ',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'sent 🌹 Rose ×$amount to ',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  TextSpan(
                                    text: receiverName,
                                    style: GoogleFonts.poppins(
                                      color: Colors.amberAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFAF52DE), width: 1.0),
                            ),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundImage: receiverAvatar != null && receiverAvatar.isNotEmpty
                                  ? NetworkImage(receiverAvatar)
                                  : const AssetImage('assets/images/placeholder.png') as ImageProvider,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 10),

                  // Custom Chat Box (real-time stream of Zego room messages) - Scrollable
                  Expanded(
                    child: _buildCustomChatBox(),
                  ),
                ],
              ),
            ),

            // 3. Custom Top Header Bar Overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildCustomTopBar(),
            ),

            // 4. Side promotion cards overlay (Riches Marbles & Candy Storm)
            Positioned(
              right: 16,
              bottom: 135,
              child: _buildSidePromotions(),
            ),

            // Floating System Notification toast at the bottom left
            Obx(() {
              final toastMsg = _controller.activeSystemNotification.value;
              if (toastMsg == null) return const SizedBox.shrink();

              return Positioned(
                left: 16,
                bottom: 130,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.9), // Slate gray dark glass
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.cyanAccent, size: 12),
                      const SizedBox(width: 6),
                      Text(
                        toastMsg,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // 5. Custom Bottom controls dock Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildCustomBottomControls(),
            ),

            // Floating reactions animations stack overlay
            _buildFloatingReactionsOverlay(),

            // Entrance Effects Overlay Queue layer
            Obx(() {
              if (!_showEntranceOverlay.value) return const SizedBox.shrink();
              return Positioned(
                top: 80,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: _currentEntranceVipLevel.value > 0
                      ? VipEntryAnimation(
                          username: _currentEntranceUser.value,
                          vipLevel: _currentEntranceVipLevel.value,
                        )
                      : (_currentEntranceNovelLevel.value > 0
                          ? NovelEntryAnimation(
                              username: _currentEntranceUser.value,
                              novelLevel: _currentEntranceNovelLevel.value,
                            )
                          : DefaultEntryAnimation(
                              username: _currentEntranceUser.value,
                              userId: _currentEntranceUserId.value,
                            )),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomSeatGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Row 0: Host & Co-host (2 seats)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSingleNativeSeat(0),
              const SizedBox(width: 48), // Wide spacing between Host and Co-host
              _buildSingleNativeSeat(1),
            ],
          ),
          const SizedBox(height: 25),
          // Row 1: Speakers 2-5 (4 seats)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSingleNativeSeat(2),
              _buildSingleNativeSeat(3),
              _buildSingleNativeSeat(4),
              _buildSingleNativeSeat(5),
            ],
          ),
          const SizedBox(height: 25),
          // Row 2: Speakers 6-9 (4 seats)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSingleNativeSeat(6),
              _buildSingleNativeSeat(7),
              _buildSingleNativeSeat(8),
              _buildSingleNativeSeat(9),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleNativeSeat(int index) {
    return Obx(() {
      final seatsMap = _controller.roomSeatsInfo;
      final _ = seatsMap.length; // Force GetX to observe roomSeatsInfo map changes
      final seatsList = seatsMap[widget.roomId] ?? [];
      final seat = seatsList.firstWhereOrNull((s) => s['seatIndex'] == index);
      final userId = seat?['userId'] as String?;
      final isOccupied = userId != null;
      final isLocked = seat?['isLocked'] == true;
      final isSpeaking = seat?['isSpeaking'] == true;
      final role = seat?['role'] ?? (index == 0 ? 'Host' : (index == 1 ? 'Co-Host' : 'Listener'));

      // Resolve user properties reactively
      final u = isOccupied ? (UserProfileCacheManager.rxCache[userId] ?? UserProfileCacheManager.getCachedUser(userId)) : null;

      final avatarUrl = u?.avatar ?? seat?['avatar'] as String?;
      final avatarFrame = u?.avatarFrame ?? seat?['avatarFrame'] as String? ?? 'Normal';
      final userName = u?.username ?? seat?['name'] as String? ?? (index == 0 ? 'Host' : (index == 1 ? 'Co-Host' : 'Seat ${index + 1}'));
      final userLevel = u?.level ?? seat?['level'] as int? ?? 1;
      final nobleLevel = u?.novelLevel ?? seat?['nobleLevel'] as int? ?? 0;
      final vipLevel = u?.vipLevel ?? seat?['vipLevel'] as int? ?? 0;
      final micStatus = seat?['micStatus'] as String? ?? 'unmuted';
      final totalGifts = seat?['seatTotalGifts'] as int? ?? 0;
      final totalStars = seat?['seatTotalStars'] as int? ?? 0;

      final double size = (index == 0 || index == 1) ? 56.0 : 44.0;

      // Premium Frame Color definitions
      Color frameColor = Colors.white24;
      if (avatarFrame == 'Gold Frame' || nobleLevel > 0) {
        frameColor = const Color(0xFFFFD700); // Gold
      } else if (avatarFrame == 'Neon Frame' || vipLevel > 0) {
        frameColor = const Color(0xFFFF2D55); // Neon Pink
      } else if (isSpeaking) {
        frameColor = const Color(0xFF00FF66); // Speak green
      } else if (index == 0) {
        frameColor = const Color(0xFF8B5CF6); // Purple Host
      } else if (index == 1) {
        frameColor = const Color(0xFFFFB800); // Amber Co-Host
      }

      final double innerAvatarSize = size - 4.0;

      final seatBackground = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08),
        ),
        child: Center(
          child: isLocked
              ? const Icon(Icons.lock, color: Colors.grey, size: 15)
              : const Icon(Icons.chair, color: Colors.white24, size: 16),
        ),
      );

      final avatarWidget = isOccupied
          ? ClipRRect(
              borderRadius: BorderRadius.circular(innerAvatarSize / 2),
              child: SizedBox(
                width: innerAvatarSize,
                height: innerAvatarSize,
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade900,
                          child: const Icon(Icons.person, color: Colors.white24, size: 16),
                        ),
                      )
                    : Container(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        child: Center(
                          child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
              ),
            )
          : const SizedBox.shrink();

      final frameWidget = IgnorePointer(
        child: isOccupied
            ? SeatVoiceEffect(
                userId: userId!,
                size: size,
                frameColor: frameColor,
                isMuted: micStatus == 'muted',
              )
            : Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white10,
                    width: 1.5,
                  ),
                ),
              ),
      );

      final seatAndAvatarStack = GestureDetector(
        onTap: () {
          _handleSeatClick(
            index,
            isOccupied ? ZegoUIKitUser(id: userId!, name: userName) : null,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            seatBackground,
            avatarWidget,
            frameWidget,
            if (isOccupied)
              Positioned(
                right: -10,
                top: 12,
                child: VoiceWaveformWidget(
                  userId: userId!,
                  isMuted: micStatus == 'muted',
                ),
              ),
          ],
        ),
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              seatAndAvatarStack,

              // Top Role Badge for Host/Co-host
              if (index == 0 || index == 1)
                Positioned(
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: index == 0 ? const Color(0xFF8B5CF6) : const Color(0xFFFFB800),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      index == 0 ? 'Host' : 'Co-Host',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Bottom-right indicator badge (Crown/Star) for Host/Co-host
              if (index == 0 || index == 1)
                Positioned(
                  bottom: -1,
                  right: -3,
                  child: index == 0
                      ? const Text('👑', style: TextStyle(fontSize: 11))
                      : const Text('⭐', style: TextStyle(fontSize: 11)),
                ),

              // Speaker red mic off badge (top right)
              if (isOccupied && micStatus == 'muted')
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3B30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_off, color: Colors.white, size: 7),
                  ),
                ),

              // Speaker green check badge (bottom center)
              if (index >= 2 && isOccupied)
                Positioned(
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: const BoxDecoration(
                      color: Color(0xFF34C759),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 7),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),

          // Username Text name label
          SizedBox(
            width: 72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userName,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 1),
                
                // Badges row: Level + VIP/Noble
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'Lv.$userLevel',
                        style: const TextStyle(color: Colors.white70, fontSize: 6.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (vipLevel > 0) ...[
                      const SizedBox(width: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2D55),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'VIP',
                          style: TextStyle(color: Colors.white, fontSize: 6.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    if (nobleLevel > 0) ...[
                      const SizedBox(width: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'Noble',
                          style: TextStyle(color: Colors.black, fontSize: 6.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 2),

                // Star & Gift Counts on seat
                if (isOccupied) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 7.5),
                      const SizedBox(width: 1),
                      Text(
                        '$totalStars',
                        style: const TextStyle(color: Colors.white70, fontSize: 7, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.card_giftcard, color: Colors.pinkAccent, size: 7.5),
                      const SizedBox(width: 1),
                      Text(
                        '$totalGifts',
                        style: const TextStyle(color: Colors.white70, fontSize: 7, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],

                // Soundwave / micro animations if speaking
                if (isSpeaking) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 1.5,
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF66),
                          borderRadius: BorderRadius.circular(0.7),
                        ),
                      ),
                      const SizedBox(width: 1),
                      Container(
                        width: 1.5,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF66),
                          borderRadius: BorderRadius.circular(0.7),
                        ),
                      ),
                      const SizedBox(width: 1),
                      Container(
                        width: 1.5,
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF66),
                          borderRadius: BorderRadius.circular(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildCustomChatBox() {
    return Obx(() {
      final chatsMap = _controller.roomChats;
      final _ = chatsMap.length; // Force GetX to observe roomChats map changes
      final messages = chatsMap[widget.roomId] ?? <RoomChatMessage>[];
      return ListView.builder(
        controller: _chatScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final msg = messages[index];
          bool isConsecutive = false;
          if (index > 0) {
            final prevMsg = messages[index - 1];
            if (msg.senderId == prevMsg.senderId &&
                !msg.isSystem &&
                msg.messageType != 'activity' &&
                !prevMsg.isSystem &&
                prevMsg.messageType != 'activity' &&
                msg.timestamp.difference(prevMsg.timestamp).inMinutes < 3) {
              isConsecutive = true;
            }
          }
          return _buildCustomChatMessage(msg, isConsecutive: isConsecutive);
        },
      );
    });
  }

  Widget _buildCustomBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF020617)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // Soft pink radial gradient light on the left
          Positioned(
            left: -50,
            top: 150,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.pinkAccent.withOpacity(0.08),
              ),
            ),
          ),
          // Soft blue radial gradient light on the right
          Positioned(
            right: -50,
            bottom: 200,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomSeatAvatar(Size size, ZegoUIKitUser? user, int index) {
    bool isOccupied = false;
    bool isSpeaking = false;
    bool isMuted = false;
    String? userId;

    if (user != null) {
      isOccupied = true;
      userId = user.id;
      isSpeaking = user.microphone.value;
      isMuted = _controller.mutedUsers[widget.roomId]?.contains(user.id) ?? false;
    } else if (index >= 0 && index < _seats.length) {
      final mockSeat = _seats[index];
      if (mockSeat['userId'] != null) {
        isOccupied = true;
        userId = mockSeat['userId'] as String;
        isMuted = _controller.mutedUsers[widget.roomId]?.contains(userId) ?? false;
        isSpeaking = mockSeat['isSpeaking'] == true && !isMuted;
      }
    }

    final double customWidth = (index == 0 || index == 1) ? size.width * 1.22 : size.width;
    final double customHeight = (index == 0 || index == 1) ? size.height * 1.22 : size.height;

    // 1. Build the circular avatar container
    final avatarCircle = isOccupied
        ? CustomAvatarFrame(
            userId: userId!,
            username: user?.name ?? '',
            size: customWidth,
            child: CircleAvatar(
              backgroundImage: NetworkImage(_getUserDp(userId!)),
            ),
          )
        : Container(
            width: customWidth,
            height: customHeight,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
              border: Border.all(
                color: index == 0
                    ? const Color(0xFF8B5CF6) // Purple for Host
                    : index == 1
                        ? const Color(0xFFFFB800) // Gold for Co-host
                        : Colors.transparent,
                width: (index == 0 || index == 1) ? 2.5 : 1.5,
              ),
            ),
            child: Center(
              child: (index >= 0 &&
                      index < _seats.length &&
                      _seats[index]['isLocked'] == true)
                  ? const Icon(Icons.lock, color: Colors.grey, size: 20)
                  : const Icon(Icons.chair, color: Colors.white24, size: 22),
            ),
          );

    // 2. Active glow speaking overlay
    Widget mainAvatar = avatarCircle;
    if (isOccupied && isSpeaking && !isMuted) {
      mainAvatar = Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                width: customWidth + (12 * _glowController.value),
                height: customHeight + (12 * _glowController.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (index == 0 ? Colors.amber : AppTheme.primaryColor)
                      .withOpacity(0.4 * (1 - _glowController.value)),
                ),
              );
            },
          ),
          avatarCircle,
        ],
      );
    }

    // 3. Assemble unified layout matching the provided screenshot
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Center Avatar Circle
        mainAvatar,

        // Live Audio Waveform Icon overlay on the right of speaking users
        if (isOccupied && isSpeaking && !isMuted)
          Positioned(
            right: -8,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(3.5),
              decoration: BoxDecoration(
                color: index == 0 
                    ? const Color(0xFFFF9500) 
                    : (index == 1 ? const Color(0xFFAF52DE) : const Color(0xFF007AFF)),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black87, width: 1.5),
              ),
              child: const Icon(
                Icons.waves_rounded,
                color: Colors.white,
                size: 9,
              ),
            ),
          ),

        // Top Host/Co-host pill labels
        if (index == 0 || index == 1)
          Positioned(
            top: -16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
              decoration: BoxDecoration(
                color: index == 0 ? const Color(0xFF8A2BE2) : const Color(0xFFFF8C00),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                index == 0 ? 'Host' : 'Co-Host',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Bottom-Right Overlap Badges (Crown/Star)
        if (index == 0 || index == 1)
          Positioned(
            bottom: 2,
            right: -4,
            child: index == 0
                ? const Text('👑', style: TextStyle(fontSize: 14))
                : const Text('⭐', style: TextStyle(fontSize: 14)),
          ),

        // Bottom labels & Neon Active Soundwave for Host/Co-host
        if (index == 0 || index == 1)
          Positioned(
            bottom: -24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isOccupied
                      ? (user?.name ?? _seats[index]['name'] as String)
                      : (index == 0 ? 'Host' : 'Co-Host'),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2.5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 2.2,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF66),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(width: 1.5),
                    Container(
                      width: 2.2,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF66),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(width: 1.5),
                    Container(
                      width: 2.2,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF66),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Speaker green check badge (bottom center)
        if (index >= 2)
          Positioned(
            bottom: -6,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: const BoxDecoration(
                color: Color(0xFF34C759),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 8),
            ),
          ),

        // Speaker red mic off badge (top right)
        if (index >= 2)
          Positioned(
            top: 0,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFFFF3B30),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_off, color: Colors.white, size: 8),
            ),
          ),

        // Speaker pink points badge below circle
        if (index >= 2)
          Positioned(
            bottom: -22,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFE91E63).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFE91E63).withOpacity(0.4),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.star, color: Color(0xFFE91E63), size: 7.5),
                  SizedBox(width: 2),
                  Text(
                    '0',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomSeatForeground(ZegoUIKitUser? user, int index) {
    return const SizedBox.shrink();
  }

  Widget _buildCustomChatMessage(RoomChatMessage message, {bool isConsecutive = false}) {
    final isSystem = message.isSystem;
    final isActivity = message.messageType == 'activity';

    if (isSystem || isActivity) {
      Color eventColor = const Color(0xFF2196F3);
      IconData icon = Icons.notifications;
      
      final type = message.eventType ?? '';
      if (type == 'room_join') {
        eventColor = const Color(0xFF34C759);
        icon = Icons.login_rounded;
      } else if (type == 'room_leave') {
        eventColor = const Color(0xFFFF3B30);
        icon = Icons.logout_rounded;
      } else if (type.startsWith('seat_')) {
        eventColor = const Color(0xFF007AFF);
        icon = Icons.chair_rounded;
      } else if (type == 'gift_sent') {
        eventColor = const Color(0xFFAF52DE);
        icon = Icons.card_giftcard_rounded;
      } else if (type == 'achievement') {
        eventColor = const Color(0xFFFFCC00);
        icon = Icons.emoji_events_rounded;
      } else if (type == 'room_level_up') {
        eventColor = const Color(0xFFFF9500);
        icon = Icons.trending_up_rounded;
      } else if (type == 'room_banner_changed') {
        eventColor = const Color(0xFFFF2D55);
        icon = Icons.image_rounded;
      }

      final timestampStr = '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: eventColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: eventColor.withOpacity(0.3), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: eventColor, size: 13),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  message.text,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timestampStr,
                style: GoogleFonts.poppins(
                  color: Colors.white30,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final timestampStr = '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';
    
    final seatsList = _controller.roomSeatsInfo[widget.roomId] ?? [];
    final senderSeat = seatsList.firstWhereOrNull((s) => s['userId'] == message.senderId);
    final bool isSpeaking = senderSeat != null && senderSeat['isSpeaking'] == true;

    Widget leftSide;
    if (isConsecutive) {
      leftSide = const SizedBox(width: 44);
    } else {
      leftSide = Container(
        margin: const EdgeInsets.only(right: 8),
        width: 36,
        height: 36,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (isSpeaking)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pinkAccent.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
              ),
            CircleAvatar(
              radius: 18,
              backgroundImage: message.senderAvatar != null && message.senderAvatar!.isNotEmpty
                  ? NetworkImage(message.senderAvatar!)
                  : const AssetImage('assets/images/placeholder.png') as ImageProvider,
            ),
            if (message.avatarFrame != null && message.avatarFrame != 'Normal' && message.avatarFrame!.isNotEmpty)
              Positioned(
                top: -4,
                left: -4,
                right: -4,
                bottom: -4,
                child: Image.network(
                  message.avatarFrame!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black87, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildBadge(String text, Color bg, Color textCol) {
      return Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            color: textCol,
            fontSize: 7.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    Color getRoleColor(String? role) {
      switch (role) {
        case 'Host':
          return const Color(0xFFFF9500);
        case 'Co-Host':
          return const Color(0xFFAF52DE);
        case 'Speaker':
          return const Color(0xFF007AFF);
        default:
          return Colors.white54;
      }
    }

    Widget buildReactions() {
      if (message.reactions.isEmpty) return const SizedBox.shrink();
      
      final reactionWidgets = <Widget>[];
      message.reactions.forEach((reactionType, usersList) {
        if (usersList.isEmpty) return;
        
        final hasReacted = usersList.contains(RoomController.currentUserId);
        String emoji = '❤️';
        if (reactionType == 'laugh') emoji = '😂';
        if (reactionType == 'fire') emoji = '🔥';

        reactionWidgets.add(
          GestureDetector(
            onTap: () {
              _controller.sendRoomReactionBroadcast(widget.roomId, message.id, reactionType);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasReacted ? Colors.pinkAccent.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasReacted ? Colors.pinkAccent.withOpacity(0.5) : Colors.white12,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 10)),
                  const SizedBox(width: 3),
                  Text(
                    usersList.length.toString(),
                    style: GoogleFonts.poppins(
                      color: hasReacted ? Colors.pinkAccent : Colors.white70,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      });

      return Container(
        margin: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: reactionWidgets,
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(top: isConsecutive ? 1 : 4, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leftSide,
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isConsecutive) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              message.senderName,
                              style: GoogleFonts.poppins(
                                color: Colors.cyanAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (message.senderLevel != null)
                            buildBadge('Lv.${message.senderLevel}', Colors.grey.withOpacity(0.24), Colors.amberAccent),
                          if (message.nobleLabel != null && message.nobleLabel!.isNotEmpty)
                            buildBadge(message.nobleLabel!, const Color(0xFFFFD700).withOpacity(0.2), const Color(0xFFFFD700)),
                          if (message.vipLabel != null && message.vipLabel!.isNotEmpty)
                            buildBadge(message.vipLabel!, Colors.pinkAccent.withOpacity(0.2), Colors.pinkAccent),
                          if (message.senderRole != null)
                            buildBadge(message.senderRole!, getRoleColor(message.senderRole).withOpacity(0.2), getRoleColor(message.senderRole)),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    RichText(
                      text: TextSpan(
                        children: _parseMentionsAndText(message.text),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: buildReactions()),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                _controller.sendRoomReactionBroadcast(widget.roomId, message.id, 'heart');
                              },
                              child: Icon(
                                Icons.favorite_border_rounded,
                                color: Colors.white.withOpacity(0.4),
                                size: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timestampStr,
                              style: GoogleFonts.poppins(
                                color: Colors.white30,
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _parseMentionsAndText(String text) {
    final List<InlineSpan> spans = [];
    final RegExp exp = RegExp(r'(@[a-zA-Z0-9_\u00a1-\uffff]+)');
    final Iterable<RegExpMatch> matches = exp.allMatches(text);

    if (matches.isEmpty) {
      spans.add(
        TextSpan(
          text: text,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.9),
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
      return spans;
    }

    int start = 0;
    for (final RegExpMatch match in matches) {
      if (match.start > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, match.start),
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: GoogleFonts.poppins(
            color: Colors.amberAccent,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = match.end;
    }

    if (start < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(start),
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.9),
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }
    return spans;
  }

  Widget _buildTaskBadgesAndProgramInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _showRoomTasksDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F203C).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFF4081).withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_border_rounded,
                          color: Color(0xFFFF4081), size: 15),
                      const SizedBox(width: 6),
                      Obx(() => Text(
                        '${_taskProgress.value}/400',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Capsule 2: Time 3 d
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F203C).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        color: Colors.cyanAccent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '3 d',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Capsule 3: Program info with red edit circle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0F203C).withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30), // Red edit button
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 10),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Program',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'granmmer_yet_go...',
                      style: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white38, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePromotions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 85,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFE91E63), Color(0xFFFF5722)]),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Column(
            children: [
              const Icon(Icons.star, color: Colors.white, size: 14),
              const SizedBox(height: 2),
              Text(
                'Riches Marbles',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 90,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Colors.pinkAccent.withOpacity(0.5), width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.pinkAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Candy Storm',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'This Room',
                style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 6.5,
                    fontWeight: FontWeight.w600),
              ),
              Text(
                '🍬 0/75',
                style: GoogleFonts.poppins(
                    color: Colors.amberAccent,
                    fontSize: 7,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                'Rounds: 0',
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 6),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFFEB3B), Color(0xFFFF9800)]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    'Join Now',
                    style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 7,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomBottomControls() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black87, Colors.black.withOpacity(0.97)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Room Info Bar ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.08)),
                bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Row(
              children: [
                // Room DP (tappable, opens settings for moderators+)
                Obx(() {
                  final roomList = _controller.rooms;
                  final roomAvatar = roomList.any((r) => r.id == widget.roomId)
                      ? (roomList
                              .firstWhere((r) => r.id == widget.roomId)
                              .avatar ??
                          '')
                      : '';
                  return GestureDetector(
                    onTap: () {
                      final room = _controller.rooms
                          .firstWhere((r) => r.id == widget.roomId);
                      final callerRole =
                          _controller.getUserRole(room, widget.userId);
                      final callerWeight =
                          _controller.getRoleWeight(callerRole);
                      if (callerWeight >= 7) {
                        Get.dialog(RoomSettingsDialog(
                            roomId: widget.roomId, room: room));
                      } else {
                        Get.snackbar('Permission Denied',
                            'Only moderators and above can edit the arena.',
                            snackPosition: SnackPosition.BOTTOM);
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: roomAvatar.isNotEmpty
                          ? Image.network(
                              roomAvatar,
                              width: 28,
                              height: 28,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                    color: Colors.pinkAccent.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(6)),
                                child: const Icon(Icons.music_note,
                                    color: Colors.pinkAccent, size: 16),
                              ),
                            )
                          : Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                  color: Colors.pinkAccent.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(6)),
                              child: const Icon(Icons.music_note,
                                  color: Colors.pinkAccent, size: 16),
                            ),
                    ),
                  );
                }),
                const SizedBox(width: 10),
                // Arena Name + Who Can Join
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.roomName,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Obx(() {
                        final roomList = _controller.rooms;
                        final whoCanJoin =
                            roomList.any((r) => r.id == widget.roomId)
                                ? roomList
                                    .firstWhere((r) => r.id == widget.roomId)
                                    .whoCanJoin
                                : 'Everyone';
                        return Text(
                          '👥 $whoCanJoin',
                          style: GoogleFonts.poppins(
                              color: Colors.white38, fontSize: 9),
                        );
                      }),
                    ],
                  ),
                ),
                // Quick action icons: members, edit room, exit
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        final room = _controller.rooms
                            .firstWhere((r) => r.id == widget.roomId);
                        Get.dialog(MemberListDialog(
                            roomId: widget.roomId, room: room));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.people_outline,
                            color: Colors.white70, size: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        final room = _controller.rooms
                            .firstWhere((r) => r.id == widget.roomId);
                        final callerRole =
                            _controller.getUserRole(room, widget.userId);
                        final callerWeight =
                            _controller.getRoleWeight(callerRole);
                        if (callerWeight >= 7) {
                          Get.dialog(RoomSettingsDialog(
                              roomId: widget.roomId, room: room));
                        } else {
                          Get.snackbar('Permission Denied',
                              'Only moderators and above can edit the arena.',
                              snackPosition: SnackPosition.BOTTOM);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.edit_outlined,
                            color: Colors.white70, size: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Exit room button (red logout icon)
                    GestureDetector(
                      onTap: () {
                        Get.defaultDialog(
                          backgroundColor: AppTheme.bgLight,
                          title: 'Exit Arena?',
                          titleStyle: const TextStyle(
                              color: Colors.white, fontSize: 16),
                          middleText:
                              'Are you sure you want to leave the arena?',
                          middleTextStyle: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                          confirm: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: () {
                              Get.back();
                              _leaveRoom();
                            },
                            child: const Text('Exit'),
                          ),
                          cancel: TextButton(
                            onPressed: () => Get.back(),
                            child: const Text('Stay',
                                style: TextStyle(color: Colors.white70)),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.redAccent.withOpacity(0.4),
                              width: 1),
                        ),
                        child: const Icon(Icons.logout_rounded,
                            color: Colors.redAccent, size: 15),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Chat Input + Action Buttons Row ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Row(
              children: [
                // Mic mute/unmute quick button — only shown when user is on a seat
                Obx(() {
                  final isOnSeat = _isCurrentUserOnSeat();
                  if (!isOnSeat) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: _toggleMic,
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: _isMicOn
                              ? AppTheme.primaryColor.withOpacity(0.2)
                              : Colors.red.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isMicOn
                                ? AppTheme.primaryColor.withOpacity(0.5)
                                : Colors.red.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          _isMicOn ? Icons.mic : Icons.mic_off,
                          color: _isMicOn
                              ? AppTheme.primaryColor
                              : Colors.redAccent,
                          size: 18,
                        ),
                      ),
                    ),
                  );
                }),
                // Chat text input
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      controller: _chatInputController,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: "Let's talk",
                        hintStyle:
                            TextStyle(color: Colors.white30, fontSize: 12),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (text) {
                        if (text.trim().isNotEmpty) {
                          _controller.sendRoomBroadcastMessage(widget.roomId, text.trim());
                          _chatInputController.clear();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Action button row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIconButton(
                      icon: Icons.shield,
                      color: Colors.pinkAccent,
                      onTap: () => Get.snackbar('Premium Badge',
                          'You are viewing your achievements.'),
                    ),
                    const SizedBox(width: 8),
                    _buildIconButton(
                      icon: Icons.arrow_upward_rounded,
                      color: Colors.white70,
                      onTap: () => Get.snackbar(
                          'Upload', 'Uploading screen details or files.'),
                    ),
                    const SizedBox(width: 8),
                    Stack(
                      children: [
                        _buildIconButton(
                          icon: Icons.menu,
                          color: Colors.white70,
                          onTap: () {
                            Get.dialog(MemberListDialog(
                              roomId: widget.roomId,
                              room: _controller.rooms
                                  .firstWhere((r) => r.id == widget.roomId),
                            ));
                          },
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
                            constraints: const BoxConstraints(
                                minWidth: 12, minHeight: 12),
                            child: const Text(
                              '90',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 6,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Get.dialog(SendGiftDialog(
                            roomId: widget.roomId, occupiedSeatsCount: 3));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                            color: Colors.pinkAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.card_giftcard,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildRoomBanner() {
    return Obx(() {
      final room = _controller.rooms.firstWhereOrNull((r) => r.id == widget.roomId);
      if (room == null) return const SizedBox.shrink();
      final isOwner = room.hostId == widget.userId;

      final bool hasCover = (room.avatar != null && room.avatar!.isNotEmpty) || (room.banner != null && room.banner!.isNotEmpty);
      final String? coverUrl = (room.avatar != null && room.avatar!.isNotEmpty) ? room.avatar : room.banner;

      return GestureDetector(
        onTap: isOwner ? () => _changeRoomCoverPhoto(room.id) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 110,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(0.04),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            image: hasCover
                ? DecorationImage(
                    image: NetworkImage(coverUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                if (!hasCover)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          color: Colors.white.withOpacity(0.4),
                          size: 24,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isOwner ? 'Tap to change Arena Cover' : 'Welcome to Creania Arena',
                          style: GoogleFonts.poppins(
                            color: Colors.white30,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isOwner)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt, color: Colors.cyanAccent, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            hasCover ? 'Change Cover' : 'Upload Cover',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _changeRoomCoverPhoto(String roomId) {
    final presets = [
      'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150', // Classic Mic
      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=150', // DJ Mixer
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=150', // Concert
      'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=150', // Neon
      'https://images.unsplash.com/photo-1516280440614-37939bbacd6a?w=150', // Acoustic
      'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=150', // Stage Lights
    ];

    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF18181B),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Arena Cover Photo',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Preset Cover Photos Grid
            Text(
              'Select Preset Cover Photo',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: presets.length,
                itemBuilder: (context, idx) {
                  return GestureDetector(
                    onTap: () {
                      _controller.updateRoomSettings(roomId, avatar: presets[idx]);
                      Get.back();
                      Get.snackbar('Cover Changed', 'Arena cover photo updated successfully.', snackPosition: SnackPosition.BOTTOM);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(presets[idx], fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            
            // Custom Upload Option
            ListTile(
              leading: const Icon(Icons.cloud_upload_rounded, color: AppTheme.primaryColor),
              title: Text(
                'Upload Custom Cover Photo',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Pick an image from your gallery',
                style: GoogleFonts.poppins(color: Colors.white30, fontSize: 11),
              ),
              tileColor: Colors.white.withOpacity(0.02),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Get.back();
                _pickAndUploadBanner(roomId);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadBanner(String roomId) async {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Update Arena Banner',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.cyanAccent),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Get.back();
                await _processImageSelection(roomId, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.amberAccent),
              title: const Text('Take a Photo', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Get.back();
                await _processImageSelection(roomId, ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textTertiary)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processImageSelection(String roomId, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile == null) return;

      final file = io.File(pickedFile.path);

      Get.dialog(
        Dialog(
          backgroundColor: AppTheme.bgDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Confirm Arena Banner',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    child: Image.file(file, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This is how the banner will look to all users in this arena.',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white30)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        Get.back();
                        Get.dialog(
                          const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
                          barrierDismissible: false,
                        );
                        final url = await _controller.uploadRoomBanner(roomId, file);
                        Get.back();
                        if (url != null) {
                          Get.snackbar('Success 🎉', 'Arena banner updated successfully!');
                        }
                      },
                      child: const Text('Upload & Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error picking arena banner: $e');
    }
  }

  Widget _buildRoomLevelAndXpProgress() {
    return Obx(() {
      final room = _controller.rooms.firstWhereOrNull((r) => r.id == widget.roomId);
      if (room == null || !room.isPermanent) return const SizedBox.shrink();

      final int xpNeeded = _controller.getXpForNextLevel(room.level);
      final double xpProgress = (room.xp / xpNeeded).clamp(0.0, 1.0);

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.purpleAccent, Colors.deepPurple],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Arena Level ${room.level}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'XP: ${room.xp} / $xpNeeded',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${(xpProgress * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                    color: Colors.amberAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(
                    height: 6,
                    color: Colors.white10,
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    height: 6,
                    width: (MediaQuery.of(context).size.width - 58) * xpProgress,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00FF87), Color(0xFF60EFFF)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCustomTopBar() {
    return Obx(() {
      final liveRoom = _controller.rooms.firstWhereOrNull((r) => r.id == widget.roomId);
      final roomName = liveRoom?.name ?? widget.roomName;
      final roomLevel = liveRoom?.level ?? 1;
      final roomId = liveRoom?.id ?? widget.roomId;

      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Room Capsule + Invite button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      // Green circular avatar with number roomLevel
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34C759), // iOS Green
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$roomLevel',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            roomName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'ID: $roomId',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Pink add button '+'
                GestureDetector(
                  onTap: () {
                    Get.snackbar('Action', 'Inviting users to the arena.');
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF2D55), // Pink Accent
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),

            // Right: Participant capsule + leave button
            Row(
              children: [
                // Capsule with user icon and count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.05), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white70, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${liveRoom?.totalMembers ?? 3}',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                
                // Top Bar Minimize Button
                _buildTopBarButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  onTap: () {
                    Get.back();
                    _controller.showPipBubble(
                      widget.roomId,
                      widget.roomName,
                      _controller.rooms
                              .firstWhereOrNull((r) => r.id == widget.roomId)
                              ?.avatar ??
                          '',
                    );
                  },
                ),
                const SizedBox(width: 6),

                // Close / Exit Button
                _buildTopBarButton(
                  icon: Icons.close_rounded,
                  onTap: _leaveRoom,
                ),
                const SizedBox(width: 32), // Leave space for the warning banner tag
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTopBarButton(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildCallHeader(VoiceRoom room) {
    final int xpNeeded = _controller.getXpForNextLevel(room.level);
    final double xpProgress = (room.xp / xpNeeded).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border(
            bottom:
                BorderSide(color: Colors.white.withOpacity(0.05), width: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back & Title
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 20),
                      onPressed: () {
                        Get.back();
                        _controller.showPipBubble(
                          widget.roomId,
                          widget.roomName,
                          _controller.rooms
                                  .firstWhereOrNull(
                                      (r) => r.id == widget.roomId)
                                  ?.avatar ??
                              '',
                        );
                      },
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.name,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                room.id,
                                style: GoogleFonts.poppins(
                                    color: Colors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  room.type,
                                  style: GoogleFonts.poppins(
                                      color: Colors.white54, fontSize: 8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Header options: Members list, Settings, Level indicator
              Row(
                children: [
                  StreamBuilder<List<ZegoUIKitUser>>(
                    stream: ZegoUIKit().getUserListStream(),
                    initialData: const [],
                    builder: (context, snapshot) {
                      final users = snapshot.data ?? [];
                      final count = users.length;

                      return GestureDetector(
                        onTap: () {
                          Get.dialog(OnlineMembersDialog(
                            roomId: widget.roomId,
                            room: room,
                          ));
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('👥', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                '$count',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white70, size: 22),
                    onPressed: () {
                      final callerRole =
                          _controller.getUserRole(room, widget.userId);
                      final callerWeight =
                          _controller.getRoleWeight(callerRole);

                      if (callerWeight >= 7) {
                        // Moderator or above
                        Get.dialog(RoomSettingsDialog(
                            roomId: widget.roomId, room: room));
                      } else {
                        Get.snackbar(
                          'Permission Denied',
                          'Only the Founder, Manager, or Moderators can access settings.',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: AppTheme.errorColor.withOpacity(0.8),
                          colorText: Colors.white,
                        );
                      }
                    },
                    tooltip: 'Settings',
                  ),
                  if (room.isPermanent) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Colors.purpleAccent, Colors.deepPurple]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'LV ${room.level}',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]
                ],
              ),
            ],
          ),
          if (room.isPermanent) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: xpProgress,
                      minHeight: 3,
                      backgroundColor: Colors.white10,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'XP: ${room.xp}/${xpNeeded}',
                  style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 8,
                      fontWeight: FontWeight.bold),
                )
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildBulletinBanner(VoiceRoom room) {
    return Container(
      width: double.infinity,
      color: Colors.amber.withOpacity(0.04),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.campaign, color: Colors.amber, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              room.bulletin,
              style: GoogleFonts.poppins(
                  color: Colors.amber.shade200,
                  fontSize: 10,
                  fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          if (room.pinnedAnnouncement.isNotEmpty) ...[
            Container(
              width: 1,
              height: 12,
              color: Colors.white24,
            ),
            const SizedBox(width: 6),
            const Icon(Icons.push_pin, color: Colors.tealAccent, size: 10),
            const SizedBox(width: 4),
            Text(
              'Pinned Note active',
              style: GoogleFonts.poppins(color: Colors.tealAccent, fontSize: 9),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildTopAudienceRow(VoiceRoom room) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.people,
                    color: AppTheme.primaryColor, size: 10),
                const SizedBox(width: 4),
                Text(
                  '${room.participantCount}',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 22,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 12,
                itemBuilder: (context, index) {
                  final uids = [
                    'user_man_1',
                    'user_mod_1',
                    'user_elite_1',
                    'user_vip_1',
                    'user_memb_1',
                    'user_vis_1',
                    'listener_1',
                    'listener_2',
                    'listener_3',
                    'listener_4',
                    'listener_5',
                    'listener_6'
                  ];
                  final uid = uids[index % uids.length];
                  final dpUrl = _getUserDp(uid);

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                            image: NetworkImage(dpUrl), fit: BoxFit.cover),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialModePanel(VoiceRoom room) {
    if (room.type == 'Debate Arena' || room.type == 'Debate Room') {
      return _buildDebatePanel(room);
    } else if (room.type == 'Study Arena' || room.type == 'Study Room') {
      return _buildStudyPanel(room);
    } else if (room.type == 'Music Arena' || room.type == 'Music Room') {
      return _buildMusicPanel(room);
    } else if (room.type == 'Event Arena' || room.type == 'Event Room') {
      return _buildEventPanel(room);
    }
    return const SizedBox.shrink();
  }

  Widget _buildDebatePanel(VoiceRoom room) {
    final callerRole = _controller.getUserRole(room, widget.userId);
    final isJudge = callerRole == 'Owner' ||
        callerRole == 'Co-owner' ||
        callerRole == 'Admin';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.05),
        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '⚖️ DEBATE MODE (Round ${_debateRound.value})',
                style: GoogleFonts.poppins(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 10),
              ),
              Obx(() {
                final mins = (_debateTimerSeconds.value ~/ 60)
                    .toString()
                    .padLeft(2, '0');
                final secs =
                    (_debateTimerSeconds.value % 60).toString().padLeft(2, '0');
                return Text(
                  'Timer: $mins:$secs',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  const Text('Candidate A (Pro-AI)',
                      style: TextStyle(color: Colors.white70, fontSize: 10)),
                  Obx(() => Text('${_scoreCandidateA.value} pts',
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold))),
                  if (isJudge)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle,
                              color: Colors.green, size: 18),
                          onPressed: () => _scoreCandidateA.value += 5,
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.red, size: 18),
                          onPressed: () => _scoreCandidateA.value =
                              max(0, _scoreCandidateA.value - 5),
                        ),
                      ],
                    ),
                ],
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Column(
                children: [
                  const Text('Candidate B (Anti-AI)',
                      style: TextStyle(color: Colors.white70, fontSize: 10)),
                  Obx(() => Text('${_scoreCandidateB.value} pts',
                      style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold))),
                  if (isJudge)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle,
                              color: Colors.green, size: 18),
                          onPressed: () => _scoreCandidateB.value += 5,
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.red, size: 18),
                          onPressed: () => _scoreCandidateB.value =
                              max(0, _scoreCandidateB.value - 5),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
          if (isJudge) ...[
            const Divider(color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    if (_isDebateTimerRunning.value) {
                      _debateTimer?.cancel();
                      _isDebateTimerRunning.value = false;
                    } else {
                      _isDebateTimerRunning.value = true;
                      _debateTimer =
                          Timer.periodic(const Duration(seconds: 1), (t) {
                        if (_debateTimerSeconds.value > 0) {
                          _debateTimerSeconds.value--;
                        } else {
                          _debateTimer?.cancel();
                          _isDebateTimerRunning.value = false;
                          Get.snackbar('Debate Alert', 'Timer expired!',
                              snackPosition: SnackPosition.BOTTOM);
                        }
                      });
                    }
                  },
                  child: Obx(() => Text(
                      _isDebateTimerRunning.value
                          ? 'Pause Timer'
                          : 'Start Timer',
                      style: const TextStyle(fontSize: 10))),
                ),
                TextButton(
                  onPressed: () {
                    _debateTimerSeconds.value = 180;
                  },
                  child: const Text('Reset',
                      style: TextStyle(fontSize: 10, color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () {
                    _debateRound.value++;
                    _debateTimerSeconds.value = 180;
                  },
                  child: const Text('Next Round',
                      style: TextStyle(fontSize: 10, color: Colors.amber)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudyPanel(VoiceRoom room) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.tealAccent.withOpacity(0.04),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.quiz, color: Colors.tealAccent, size: 14),
              const SizedBox(width: 6),
              Text(
                'STUDY HUB QUIZ',
                style: GoogleFonts.poppins(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Q: Which article deals with the amendment procedure of the Constitution of India?',
            style: TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Obx(() {
            final voted = _quizVoted.value;
            final selected = _quizSelectedOption.value;
            final totalVotes =
                _quizVotes.values.fold<int>(0, (sum, val) => sum + val);

            Widget buildOption(String opt, String label) {
              final votesCount = _quizVotes[opt] ?? 0;
              final percent = totalVotes > 0 ? (votesCount / totalVotes) : 0.0;
              final optSelected = selected == opt;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  onTap: voted
                      ? null
                      : () {
                          _quizSelectedOption.value = opt;
                          _quizVotes[opt] = votesCount + 1;
                          _quizVoted.value = true;
                          _controller.sendRoomMessage(widget.roomId,
                              'voted for Option $opt in Study Quiz!',
                              senderRole: 'Student');
                        },
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: optSelected
                          ? Colors.tealAccent.withOpacity(0.2)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              optSelected ? Colors.tealAccent : Colors.white10),
                    ),
                    child: Stack(
                      children: [
                        if (voted)
                          FractionallySizedBox(
                            widthFactor: percent,
                            child: Container(
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.tealAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(label,
                                  style: TextStyle(
                                      color: optSelected
                                          ? Colors.tealAccent
                                          : Colors.white,
                                      fontSize: 11)),
                              if (voted)
                                Text(
                                    '${(percent * 100).toStringAsFixed(0)}% ($votesCount votes)',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 9)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: [
                buildOption('A', 'A: Article 356'),
                buildOption('B', 'B: Article 368'),
                buildOption('C', 'C: Article 370'),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMusicPanel(VoiceRoom room) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.pinkAccent.withOpacity(0.03),
        border: Border.all(color: Colors.pinkAccent.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.music_note,
                      color: Colors.pinkAccent, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'KARAOKE SONG QUEUE',
                    style: GoogleFonts.poppins(
                        color: Colors.pinkAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 10),
                  ),
                ],
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.playlist_add,
                    color: Colors.pinkAccent, size: 20),
                onPressed: () {
                  // Show add song input popup
                  final txtController = TextEditingController();
                  Get.defaultDialog(
                    backgroundColor: AppTheme.bgDark,
                    title: 'Request Song',
                    titleStyle:
                        const TextStyle(color: Colors.white, fontSize: 15),
                    content: TextField(
                      controller: txtController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Enter song title & artist...',
                        hintStyle: TextStyle(color: Colors.white30),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white30)),
                      ),
                    ),
                    confirm: ElevatedButton(
                      onPressed: () {
                        if (txtController.text.trim().isNotEmpty) {
                          _songQueue.add({
                            'title': txtController.text.trim(),
                            'singer': 'Singer Request',
                            'requester': widget.userName,
                          });
                          _controller.sendRoomMessage(widget.roomId,
                              'added song "${txtController.text.trim()}" to the Karaoke queue! 🎤');
                        }
                        Get.back();
                      },
                      child: const Text('Add'),
                    ),
                    cancel: TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('Cancel')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Obx(() {
            if (_songQueue.isEmpty) {
              return const Text('Queue is empty! Tap + to add songs.',
                  style: TextStyle(color: Colors.white38, fontSize: 10));
            }
            return Column(
              children: _songQueue.take(2).map((song) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_fill,
                          color: Colors.pinkAccent, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '"${song['title']}" requested by ${song['requester']}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _songQueue.remove(song);
                        },
                        child: const Icon(Icons.close,
                            color: Colors.white38, size: 12),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEventPanel(VoiceRoom room) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withOpacity(0.04),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 14),
              const SizedBox(width: 6),
              Text(
                'LIVE EVENT POLL',
                style: GoogleFonts.poppins(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Question: Should we extend this Creator Awards session by 30 mins?',
            style: TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Obx(() {
            final voted = _pollVoted.value;
            final selected = _pollSelectedOption.value;
            final totalVotes =
                _pollVotes.values.fold<int>(0, (sum, val) => sum + val);

            Widget buildPollOption(String opt, String label) {
              final count = _pollVotes[opt] ?? 0;
              final percent = totalVotes > 0 ? (count / totalVotes) : 0.0;
              final isSel = selected == opt;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  onTap: voted
                      ? null
                      : () {
                          _pollSelectedOption.value = opt;
                          _pollVotes[opt] = count + 1;
                          _pollVoted.value = true;
                          _controller.sendRoomMessage(widget.roomId,
                              'voted "$opt" in the Live Event Poll!');
                        },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSel
                          ? Colors.amber.withOpacity(0.2)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isSel ? Colors.amber : Colors.white10),
                    ),
                    child: Stack(
                      children: [
                        if (voted)
                          FractionallySizedBox(
                            widthFactor: percent,
                            child: Container(
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(label,
                                  style: TextStyle(
                                      color:
                                          isSel ? Colors.amber : Colors.white,
                                      fontSize: 11)),
                              if (voted)
                                Text(
                                    '${(percent * 100).toStringAsFixed(0)}% ($count votes)',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 9)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: [
                buildPollOption('Yes', '🔥 Yes, keep going!'),
                buildPollOption('No', '⏰ No, let\'s wrap up.'),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSpeakerStage(VoiceRoom room) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.76,
      ),
      itemCount: _seats.length,
      itemBuilder: (context, index) {
        final seat = _seats[index];
        final isOccupied = seat['userId'] != null;
        final isSpeaking = seat['isSpeaking'] as bool;
        final isLocked = seat['isLocked'] as bool;
        final isMuted = _controller.mutedUsers[widget.roomId]
                ?.contains(seat['userId'] ?? '') ??
            false;

        return Column(
          children: [
            GestureDetector(
              onTap: () {
                if (isOccupied) {
                  if (seat['userId'] == widget.userId) {
                    _showLeaveSeatMenu(index);
                  } else {
                    _showMiniProfileDialog(
                        seat['userId'], seat['name'], seat['role'], index);
                  }
                } else {
                  if (isLocked) {
                    final callerRole =
                        _controller.getUserRole(room, widget.userId);
                    final callerWeight = _controller.getRoleWeight(callerRole);
                    if (callerWeight >= 7) {
                      // Moderator or above
                      Get.bottomSheet(
                        Container(
                          color: AppTheme.bgLight,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Locked Seat Options',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              ListTile(
                                leading: const Icon(Icons.lock_open,
                                    color: Colors.green),
                                title: const Text('Unlock Seat',
                                    style: TextStyle(color: Colors.white)),
                                onTap: () {
                                  _seats[index] = {...seat, 'isLocked': false};
                                  Get.back();
                                  Get.snackbar('Seat Management',
                                      'Seat ${index + 1} unlocked.');
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      Get.snackbar(
                        'Seat Locked 🔒',
                        'This seat has been locked by the host.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: AppTheme.errorColor.withOpacity(0.8),
                        colorText: Colors.white,
                      );
                    }
                  } else {
                    _joinSeat(index);
                  }
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Speaking Glow Pulsating Ring
                  if (isSpeaking && !isMuted && isOccupied)
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        return Container(
                          width: 54 + (12 * _glowController.value),
                          height: 54 + (12 * _glowController.value),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (seat['role'] == 'Host'
                                    ? Colors.amber
                                    : AppTheme.primaryColor)
                                .withOpacity(0.3 * (1 - _glowController.value)),
                          ),
                        );
                      },
                    ),

                   // Seat base
                  isOccupied
                      ? CustomAvatarFrame(
                          userId: seat['userId'] ?? '',
                          username: seat['name'] ?? '',
                          size: 54,
                          child: CircleAvatar(
                            backgroundImage: NetworkImage(_getUserDp(seat['userId'] ?? '')),
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.02),
                            border: Border.all(
                              color: isLocked
                                  ? Colors.redAccent.withOpacity(0.4)
                                  : Colors.white.withOpacity(0.1),
                              width: 1.0,
                            ),
                          ),
                          child: isLocked
                              ? const Icon(Icons.lock,
                                  color: Colors.redAccent, size: 16)
                              : const Icon(Icons.chair_alt,
                                  color: Colors.white30,
                                  size: 16),
                        ),

                  // Role badge text overlay at the bottom of avatar
                  if (isOccupied)
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _getRoleBadgeColor(seat['role']),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          seat['role'],
                          style: GoogleFonts.poppins(
                            fontSize: 7.5,
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Muted speaker badge
                  if (isMuted && isOccupied)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            color: AppTheme.errorColor, shape: BoxShape.circle),
                        child: const Icon(Icons.mic_off,
                            color: Colors.white, size: 8),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            isOccupied
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PremiumNameWidget(
                        name: seat['name'] ?? '',
                        userId: seat['userId'] ?? '',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: PremiumIdentityController.getIdentity(seat['userId'] ?? '', seat['name'] ?? '')
                            .buildBadgeRow(context, fontSize: 6.5),
                      ),
                    ],
                  )
                : Text(
                    isLocked ? 'Locked' : 'Empty',
                    style: GoogleFonts.poppins(
                      color: AppTheme.textTertiary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ],
        );
      },
    );
  }

  Widget _buildFloatingChat(String roomId) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.4), Colors.transparent],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
      ),
      child: Obx(() {
        final chats = _controller.roomChats[roomId] ?? <RoomChatMessage>[].obs;
        return ListView.builder(
          controller: _chatScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final msg = chats[index];
            return _buildChatMessageTile(msg);
          },
        );
      }),
    );
  }

  // Default letter avatar when image fails / no avatar
  Widget _buildDefaultAvatar(String name, Color color) {
    return Container(
      color: color.withOpacity(0.2),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildQuickReactionsRow() {
    final emojis = ['❤️', '😂', '🔥', '😮', '👏'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: emojis.map((emoji) {
          return GestureDetector(
            onTap: () {
              _triggerReaction(emoji);
            },
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 14)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomControls(VoiceRoom room) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgLight.withOpacity(0.9),
        border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05), width: 0.5)),
      ),
      child: Column(
        children: [
          // Mention Suggestions Row
          Obx(() {
            if (!_showMentionAutocomplete.value) return const SizedBox.shrink();
            return Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _mentionSuggestions.length,
                itemBuilder: (context, index) {
                  final u = _mentionSuggestions[index];
                  return GestureDetector(
                    onTap: () => _selectMentionSuggestion(u['name']!),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '@${u['name']}',
                        style: GoogleFonts.poppins(color: const Color(0xFFC084FC), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            );
          }),

          // Emoji Panel
          if (_showEmojiPanel)
            Container(
              height: 80,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: GridView.count(
                crossAxisCount: 6,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                children: ['😊', '❤️', '😂', '🔥', '👏', '🎉', '🌟', '👑', '💎', '🦄', '😮', '👍'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      _chatInputController.text = '${_chatInputController.text}$emoji';
                      _chatInputController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _chatInputController.text.length),
                      );
                    },
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                }).toList(),
              ),
            ),

          if (_replyTarget != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, color: Color(0xFFC084FC), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to ${_replyTarget!.senderName}',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10),
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearReplyTarget,
                    child: const Icon(Icons.close_rounded, color: Colors.white54, size: 14),
                  ),
                ],
              ),
            ),
          // Chat inputs row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Icon(Icons.chat_bubble_outline,
                          color: Colors.white54, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _chatInputController,
                          onChanged: _checkMentionAutocomplete,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                          decoration: const InputDecoration(
                            hintText: 'Say something...',
                            hintStyle:
                                TextStyle(color: Colors.white30, fontSize: 12),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (_) => _submitChatMessage(room),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showEmojiPanel = !_showEmojiPanel;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(
                            Icons.emoji_emotions_rounded,
                            color: _showEmojiPanel ? const Color(0xFF8B5CF6) : Colors.white54,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _submitChatMessage(room),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                      color: AppTheme.primaryColor, shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Control dock buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mic control
              _buildDockButton(
                icon: _isMicOn ? Icons.mic : Icons.mic_off,
                label: 'Mute',
                color: _isMicOn ? AppTheme.primaryColor : Colors.white38,
                onTap: _toggleMic,
              ),

              // Camera control
              _buildDockButton(
                icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                label: 'Camera',
                color: _isCameraOn ? AppTheme.primaryColor : Colors.white38,
                onTap: _toggleCamera,
              ),

              // Gift
              _buildDockButton(
                icon: Icons.card_giftcard,
                label: 'Gift',
                color: Colors.amber,
                onTap: () {
                  final occupiedSeats =
                      _seats.where((s) => s['userId'] != null).length;
                  Get.dialog(SendGiftDialog(
                    roomId: widget.roomId,
                    occupiedSeatsCount: occupiedSeats,
                  ));
                },
              ),

              // Agency upgrade
              _buildDockButton(
                icon: Icons.workspace_premium,
                label: 'Agency',
                color: Colors.purpleAccent,
                onTap: () {
                  Get.dialog(RoomUpgradeDialog(roomId: widget.roomId));
                },
              ),

              // Leave
              _buildDockButton(
                icon: Icons.call_end,
                label: 'Leave',
                color: AppTheme.errorColor,
                onTap: _leaveRoom,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDockButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 0.5),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 8)),
        ],
      ),
    );
  }

  Widget _buildFloatingReactionsOverlay() {
    return Obx(() {
      return Stack(
        children: _reactions.map((r) {
          return _FloatingEmojiItem(reaction: r);
        }).toList(),
      );
    });
  }

  void _showMiniProfileDialog(
      String targetUserId, String targetUserName, String role, int seatIndex) {
    final room = _controller.rooms.firstWhere((r) => r.id == widget.roomId);
    final occupiedSeats = _seats.where((s) => s['userId'] != null).length;
    Get.dialog(
      MiniProfileDialog(
        roomId: widget.roomId,
        callerUserId: widget.userId,
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        role: role,
        seatIndex: seatIndex,
        isHost: widget.isHost || widget.userId == room.hostId || widget.userId == room.founderId,
        occupiedSeatsCount: occupiedSeats,
        onMoveToAudience: () => _leaveSeat(seatIndex),
      ),
      barrierColor: Colors.black54,
    );
  }

  void _handleSeatClick(int index, ZegoUIKitUser? user) {
    final room = _controller.rooms.firstWhere((r) => r.id == widget.roomId);
    final callerRole = _controller.getUserRole(room, widget.userId);
    final callerWeight = _controller.getRoleWeight(callerRole);

    String? seatUserId;
    String? seatUserName;
    String? seatRole;
    bool isOccupied = false;

    if (user != null) {
      seatUserId = user.id;
      seatUserName = user.name;
      seatRole = _controller.getUserRole(room, user.id);
      isOccupied = true;
    } else if (index >= 0 && index < _seats.length) {
      final mockSeat = _seats[index];
      if (mockSeat['userId'] != null) {
        seatUserId = mockSeat['userId'] as String;
        seatUserName = mockSeat['name'] as String;
        seatRole = mockSeat['role'] as String;
        isOccupied = true;
      }
    }

    if (isOccupied && seatUserId != null) {
      if (seatUserId == widget.userId) {
        _showSelfSeatActions(index);
      } else {
        _showMiniProfileDialog(
            seatUserId, seatUserName ?? 'User', seatRole ?? 'Member', index);
      }
    } else {
      final isLocked = index >= 0 && index < _seats.length
          ? _seats[index]['isLocked'] == true
          : false;
      if (isLocked) {
        if (callerWeight >= 8) {
          _showLockedSeatActions(index);
        } else {
          Get.snackbar(
            'Seat Locked 🔒',
            'This seat has been locked by the management.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppTheme.errorColor.withOpacity(0.8),
            colorText: Colors.white,
          );
        }
      } else {
        if (callerWeight >= 8) {
          _showOpenSeatManagementActions(index);
        } else {
          _joinSeat(index);
        }
      }
    }
  }

  void _showSelfSeatActions(int seatIndex) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your Seat Actions',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(_isMicOn ? Icons.mic_off : Icons.mic,
                  color: AppTheme.primaryColor),
              title: Text(_isMicOn ? 'Mute Microphone' : 'Unmute Microphone',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                _toggleMic();
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: Colors.orange),
              title: const Text('Leave Stage (Move to Audience)',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                _leaveSeat(seatIndex);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: AppTheme.textTertiary),
              title: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textTertiary)),
              onTap: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }

  void _showLockedSeatActions(int seatIndex) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Locked Seat Management',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.lock_open, color: Colors.green),
              title: const Text('Unlock Seat',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                _seats[seatIndex] = {
                  ..._seats[seatIndex],
                  'isLocked': false,
                };
                Get.back();
                Get.snackbar(
                    'Seat Management', 'Seat ${seatIndex + 1} unlocked.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic, color: AppTheme.primaryColor),
              title: const Text('Take Seat & Unlock',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                _seats[seatIndex] = {
                  ..._seats[seatIndex],
                  'isLocked': false,
                };
                _joinSeat(seatIndex);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: AppTheme.textTertiary),
              title: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textTertiary)),
              onTap: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }

  void _showOpenSeatManagementActions(int seatIndex) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Seat Management',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.mic, color: AppTheme.primaryColor),
              title: const Text('Take Seat',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                _joinSeat(seatIndex);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock, color: Colors.redAccent),
              title: const Text('Close Seat (Lock)',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                _seats[seatIndex] = {
                  ..._seats[seatIndex],
                  'isLocked': true,
                };
                Get.back();
                Get.snackbar(
                    'Seat Management', 'Seat ${seatIndex + 1} locked.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: AppTheme.textTertiary),
              title: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textTertiary)),
              onTap: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingEmojiItem extends StatefulWidget {
  final FloatingReaction reaction;
  const _FloatingEmojiItem({required this.reaction, Key? key})
      : super(key: key);

  @override
  State<_FloatingEmojiItem> createState() => _FloatingEmojiItemState();
}

class _FloatingEmojiItemState extends State<_FloatingEmojiItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _yAnim;
  late Animation<double> _xAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _yAnim = Tween<double>(begin: 0.0, end: 320.0).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _xAnim = Tween<double>(begin: 0.0, end: 25.0).animate(
        CurvedAnimation(parent: _animController, curve: Curves.elasticOut));
    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
        parent: _animController, curve: const Interval(0.6, 1.0)));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Positioned(
          bottom: 120 + _yAnim.value,
          left: widget.reaction.startX +
              sin(_animController.value * pi * 2.5) * _xAnim.value,
          child: Opacity(
            opacity: _fadeAnim.value,
            child: Text(
              widget.reaction.emoji,
              style: TextStyle(fontSize: widget.reaction.size),
            ),
          ),
        );
      },
    );
  }
}

class MiniProfileDialog extends StatefulWidget {
  final String roomId;
  final String callerUserId;
  final String targetUserId;
  final String targetUserName;
  final String role;
  final int seatIndex;
  final bool isHost;
  final int occupiedSeatsCount;
  final VoidCallback? onMoveToAudience;

  const MiniProfileDialog({
    Key? key,
    required this.roomId,
    required this.callerUserId,
    required this.targetUserId,
    required this.targetUserName,
    required this.role,
    required this.seatIndex,
    required this.isHost,
    required this.occupiedSeatsCount,
    this.onMoveToAudience,
  }) : super(key: key);

  @override
  State<MiniProfileDialog> createState() => _MiniProfileDialogState();
}

class _MiniProfileDialogState extends State<MiniProfileDialog> {
  bool _isFollowing = false;
  bool _showModMenu = false;
  final RoomController _controller = RoomController.to;

  @override
  void initState() {
    super.initState();
    _isFollowing = false;
    _resolveProfile();
  }

  void _resolveProfile() {
    UserProfileCacheManager.fetchUserProfile(widget.targetUserId).then((u) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  String _getUserDp(String userId) {
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (userId == 'uid_anurag_101' || userId == 'me' || (currentUid != null && userId == currentUid)) {
      final avatarUrl = UserProfileCacheManager.currentUser?.avatar;
      if (avatarUrl != null && avatarUrl.isNotEmpty) return avatarUrl;
    }
    final u = UserProfileCacheManager.getCachedUser(userId);
    if (u != null && u.avatar != null && u.avatar!.isNotEmpty) return u.avatar!;

    if (userId == 'uid_anurag_101') {
      return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150';
    } else if (userId == 'user_co_1' || userId.contains('priya')) {
      return 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150';
    } else if (userId == 'user_adm_1' || userId.contains('vikram')) {
      return 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150';
    } else if (userId == 'user_perf_1' || userId.contains('rahul')) {
      return 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=150';
    } else if (userId == 'user_star_1' || userId.contains('siddharth')) {
      return 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150';
    } else {
      return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150';
    }
  }

  String _getNumericId(String userId) {
    return (userId.hashCode.abs() % 90000000 + 10000000).toString();
  }

  Widget _dialogTag(String label, String icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 9)),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final numericId = _getNumericId(widget.targetUserId);
    final avatarUrl = _getUserDp(widget.targetUserId);
    final isMuted =
        _controller.mutedUsers[widget.roomId]?.contains(widget.targetUserId) ??
            false;
    final room = _controller.rooms.firstWhere((r) => r.id == widget.roomId);

    // Contextual actions based on caller vs target roles weights
    final callerRole = _controller.getUserRole(room, widget.callerUserId);
    final callerWeight = _controller.getRoleWeight(callerRole);
    final targetWeight = _controller.getRoleWeight(widget.role);
    final canModerate =
        callerWeight > targetWeight && callerWeight >= 7; // Mod weight is 7

    return Obx(() {
      final u = UserProfileCacheManager.rxCache[widget.targetUserId] ?? UserProfileCacheManager.getCachedUser(widget.targetUserId);
      final String uName = u?.username ?? widget.targetUserName;
      final String uAvatar = u?.avatar ?? avatarUrl;
      final int uLevel = u?.level ?? 25;
      final int vipLevel = u?.vipLevel ?? 0;
      final int novelLevel = u?.novelLevel ?? 0;
      final bool isVIP = vipLevel > 0 || widget.targetUserId == 'uid_anurag_101' || widget.role == 'Owner' || widget.role == 'Co-owner';

      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 310,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E1B4B), // Dark Purple
                Color(0xFF09090B), // Black
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.15),
                blurRadius: 16,
                spreadRadius: 2,
              )
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Cover Banner
                Container(
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                    ),
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22)),
                  ),
                ),

                Transform.translate(
                  offset: const Offset(0, -35),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Get.back(); // close the mini profile dialog first
                          final currentUid = Supabase.instance.client.auth.currentUser?.id;
                          final isMe = widget.targetUserId == widget.callerUserId || widget.targetUserId == 'uid_anurag_101' || widget.targetUserId == 'me' || (currentUid != null && widget.targetUserId == currentUid);
                          if (isMe) {
                            Get.to(() => const ProfileScreen());
                          } else {
                            final cached = UserProfileCacheManager.getCachedUser(widget.targetUserId);
                            if (cached != null) {
                              Get.to(() => UserProfileScreen(user: cached));
                            } else {
                              final targetUser = User(
                                id: widget.targetUserId,
                                username: uName.toLowerCase().replaceAll(' ', '_'),
                                email: '${widget.targetUserId}@example.com',
                                displayName: uName,
                                avatar: uAvatar,
                                interests: ['Flutter', 'Live Audio', 'Gamification'],
                                communities: ['Creania StarStage'],
                                followers: 1240,
                                following: 380,
                                isVerified: widget.targetUserId == 'uid_anurag_101' || widget.role == 'Owner' || widget.role == 'Co-owner',
                                isPremium: isVIP,
                                reputation: 2350,
                                sid: (widget.targetUserId.hashCode.abs() % 900000 + 100000).toString(),
                                level: uLevel,
                                xp: 340,
                                totalXp: 1000,
                              );
                              Get.to(() => UserProfileScreen(user: targetUser));
                            }
                          }
                        },
                        child: CustomAvatarFrame(
                          userId: widget.targetUserId,
                          username: uName,
                          size: 70,
                          defaultVipLevel: vipLevel,
                          defaultNovelLevel: novelLevel,
                          child: CircleAvatar(
                            radius: 35,
                            backgroundImage: uAvatar.isNotEmpty ? CachedNetworkImageProvider(uAvatar) : null,
                            child: uAvatar.isEmpty ? const Icon(Icons.person, size: 30, color: Colors.white54) : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Name
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PremiumNameWidget(
                            name: uName,
                            userId: widget.targetUserId,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          if (isVIP || u?.isVerified == true)
                            const Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 14),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: uName));
                              Get.snackbar('Copied!', 'Username copied to clipboard.', snackPosition: SnackPosition.BOTTOM);
                            },
                            child: const Icon(Icons.copy_rounded,
                                color: Colors.white38, size: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Unique ID
                      Text('ID: $numericId',
                          style: GoogleFonts.poppins(
                              color: const Color(0xFFFFC107),
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      // Dynamic Tag Row inside dialog
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: [
                          if (vipLevel > 0)
                            _dialogTag('VIP $vipLevel', '👑', const Color(0xFFFFC107)),
                          if (novelLevel > 0)
                            _dialogTag('Novel $novelLevel', '📖', const Color(0xFFF97316)),
                          _dialogTag('Lv.$uLevel', '🆔', const Color(0xFF8B5CF6)),
                          _dialogTag('CS Lv.12', '💻', const Color(0xFF38BDF8)),
                          _dialogTag('Developer', '🏷', const Color(0xFFEC4899)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Gifts & Contribution stats
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC107).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFC107), size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'Gifts: ${isVIP ? "65.6K" : "14.2K"}',
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD946EF).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFD946EF).withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.bolt, color: Color(0xFFD946EF), size: 13),
                                const SizedBox(width: 2),
                                Text(
                                  'Contributed: ${isVIP ? "9.2K" : "4.5K"}',
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // View Profile Button
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.white.withOpacity(0.12)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () {
                                Get.back(); // Close dialog
                                final currentUid = Supabase.instance.client.auth.currentUser?.id;
                                final isMe = widget.targetUserId == widget.callerUserId || widget.targetUserId == 'uid_anurag_101' || widget.targetUserId == 'me' || (currentUid != null && widget.targetUserId == currentUid);
                                if (isMe) {
                                  Get.to(() => const ProfileScreen());
                                } else {
                                  final cached = UserProfileCacheManager.getCachedUser(widget.targetUserId);
                                  if (cached != null) {
                                    Get.to(() => UserProfileScreen(user: cached));
                                  } else {
                                    final targetUser = User(
                                      id: widget.targetUserId,
                                      username: uName.toLowerCase().replaceAll(' ', '_'),
                                      email: '${widget.targetUserId}@example.com',
                                      displayName: uName,
                                      avatar: uAvatar,
                                      interests: ['Flutter', 'Live Audio', 'Gamification'],
                                      communities: ['Creania StarStage'],
                                      followers: 1240,
                                      following: 380,
                                      isVerified: widget.targetUserId == 'uid_anurag_101' || widget.role == 'Founder' || widget.role == 'Co-owner',
                                      isPremium: isVIP,
                                      reputation: 2350,
                                      sid: (widget.targetUserId.hashCode.abs() % 900000 + 100000).toString(),
                                      level: uLevel,
                                      xp: 340,
                                      totalXp: 1000,
                                    );
                                    Get.to(() => UserProfileScreen(user: targetUser));
                                  }
                                }
                              },
                              icon: const Icon(Icons.person_outline_rounded, size: 16, color: Colors.white),
                              label: Text('View Profile',
                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),

                        // Gifting Button inside dialog
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC107),
                                foregroundColor: Colors.black87,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () {
                                Get.back();
                                Get.dialog(SendGiftDialog(
                                  roomId: widget.roomId,
                                  occupiedSeatsCount: widget.occupiedSeatsCount,
                                  targetUserId: widget.targetUserId,
                                  targetUserName: uName,
                                ));
                              },
                              icon: const Icon(Icons.card_giftcard_rounded, size: 16),
                              label: Text('Send Gift',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ),
                        ),

                        // Mute / Unmute Button (based on showMute logic)
                        if ((callerWeight == 10 && targetWeight < 9) || 
                            (callerWeight == 9 && targetWeight < 8) || 
                            (callerWeight == 8 && targetWeight < 7))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF38BDF8),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                onPressed: () {
                                  _controller.toggleMuteUser(widget.roomId, widget.targetUserId);
                                  setState(() {});
                                  Get.snackbar(
                                    isMuted ? 'Unmuted 🎙' : 'Muted 🔇',
                                    '$uName has been ${isMuted ? 'unmuted' : 'muted'}.',
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                },
                                icon: Icon(isMuted ? Icons.mic_rounded : Icons.mic_off_rounded, size: 16),
                                label: Text(isMuted ? 'Unmute' : 'Mute',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ),
                          ),

                        // Kick from Seat / Leave Stage Button
                        if ((callerWeight == 10 && targetWeight <= 9) || 
                            (callerWeight == 9 && targetWeight <= 8) || 
                            (callerWeight == 8 && targetWeight <= 7))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF408B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                onPressed: () {
                                  Get.back();
                                  if (widget.onMoveToAudience != null) {
                                    widget.onMoveToAudience!();
                                  }
                                },
                                icon: const Icon(Icons.airline_seat_recline_normal_rounded, size: 16),
                                label: Text('Kick from Seat',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ),
                          ),

                        // More Moderation Options collapse panel (Kick from Arena, Ban)
                        if (canModerate && (callerWeight - targetWeight) > 1) ...[
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _showModMenu = !_showModMenu),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Admin Moderation Tools',
                                    style: GoogleFonts.poppins(
                                        color: Colors.redAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                                Icon(
                                    _showModMenu
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white54,
                                    size: 16),
                              ],
                            ),
                          ),
                          if (_showModMenu) ...[
                            const SizedBox(height: 8),

                            // Change Role dropdown
                            Row(
                              children: [
                                Text('Set Role: ',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70, fontSize: 10)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.04),
                                          borderRadius: BorderRadius.circular(8)),
                                      child: DropdownButtonHideUnderline(
                                        child: () {
                                          List<String> allowedRoles = [];
                                          if (callerWeight == 10) {
                                            allowedRoles = ['Co-owner', 'Admin', 'Star Member', 'Guest'];
                                          } else if (callerWeight == 9) {
                                            allowedRoles = ['Admin', 'Star Member', 'Guest'];
                                          } else if (callerWeight == 8) {
                                            allowedRoles = ['Star Member', 'Guest'];
                                          }

                                          final currentVal = allowedRoles.contains(widget.role)
                                              ? widget.role
                                              : (allowedRoles.isNotEmpty ? allowedRoles.last : 'Guest');

                                          return DropdownButton<String>(
                                            value: currentVal,
                                            dropdownColor: const Color(0xFF18181B),
                                            isExpanded: true,
                                            style: GoogleFonts.poppins(
                                                color: Colors.white, fontSize: 10),
                                            items: allowedRoles
                                                .map((role) => DropdownMenuItem(
                                                    value: role, child: Text(role)))
                                                .toList(),
                                            onChanged: (newRole) {
                                              if (newRole != null) {
                                                _controller.changeUserRole(
                                                    widget.roomId,
                                                    widget.targetUserId,
                                                    newRole);
                                                Get.back();
                                                Get.snackbar(
                                                  'Role Assigned',
                                                  'User role updated to $newRole.',
                                                  snackPosition: SnackPosition.BOTTOM,
                                                );
                                              }
                                            },
                                          );
                                        }(),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            _buildModTile(
                              icon: Icons.logout_rounded,
                              label: 'Kick from Arena...',
                              color: Colors.orange,
                              onTap: () {
                                _showKickDurationSelector(context);
                              },
                            ),
                            _buildModTile(
                              icon: Icons.block_flipped,
                              label: 'Ban permanently',
                              color: Colors.redAccent,
                              onTap: () {
                                _controller.banUserWithDuration(widget.roomId,
                                    widget.targetUserId, 'Forever');
                                Get.back();
                              },
                            ),
                          ],
                        ]
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _showKickDurationSelector(BuildContext context) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF18181B),
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Kick Duration',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...['1 Day', '3 Days', '7 Days', '1 Month', 'Forever (Permanent)']
                .map((duration) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timer_outlined,
                    color: Color(0xFF8B5CF6)),
                title:
                    Text(duration, style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
                onTap: () {
                  _controller.banUserWithDuration(
                      widget.roomId, widget.targetUserId, duration);
                  Get.back(); // Pop bottom sheet
                  Get.back(); // Pop mini profile dialog
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildModTile(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return ListTile(
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon, color: color, size: 16),
      title: Text(label,
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
      onTap: onTap,
    );
  }
}

class MemberListDialog extends StatelessWidget {
  final String roomId;
  final VoiceRoom room;
  const MemberListDialog({required this.roomId, required this.room, Key? key})
      : super(key: key);

  String _getUserDp(String userId) {
    if (userId == 'uid_anurag_101') {
      return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150';
    } else if (userId == 'user_co_1' || userId.contains('priya')) {
      return 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150';
    } else if (userId == 'user_adm_1' || userId.contains('vikram')) {
      return 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150';
    } else if (userId == 'user_man_1' || userId.contains('rajesh')) {
      return 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150';
    } else if (userId == 'user_mod_1' || userId.contains('sneha')) {
      return 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150';
    } else if (userId == 'user_host_1' || userId.contains('karan')) {
      return 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150';
    } else if (userId == 'user_star_1' || userId.contains('siddharth')) {
      return 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150';
    } else if (userId == 'user_elite_1' || userId.contains('arjun')) {
      return 'https://images.unsplash.com/photo-1500048993953-d23a436266cf?w=150';
    } else if (userId == 'user_vip_1' || userId.contains('divya')) {
      return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150';
    } else if (userId == 'user_memb_1' || userId.contains('kabir')) {
      return 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150';
    } else if (userId == 'user_vis_1' || userId.contains('ananya')) {
      return 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150';
    } else {
      return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150';
    }
  }

  void _handleViewProfile(String userId, String name, String role) {
    final occupiedSeats = (RoomController.to.roomSeatsInfo[roomId] ?? [])
        .where((s) => s['userId'] != null)
        .length;

    Get.dialog(
      MiniProfileDialog(
        roomId: roomId,
        callerUserId: RoomController.currentUserId,
        targetUserId: userId,
        targetUserName: name,
        role: role,
        seatIndex: -1,
        isHost: room.hostId == RoomController.currentUserId || room.founderId == RoomController.currentUserId,
        occupiedSeatsCount: occupiedSeats,
      ),
    );
  }

  void _handleChatPressed(String targetId, String targetName) {
    final dp = _getUserDp(targetId);
    Get.back(); // Dismiss MemberListDialog
    Get.back(); // Exit VoiceRoomCallScreen to go home
    
    // Trigger PIP float bubble with room info
    RoomController.to.showPipBubble(
      roomId,
      room.name,
      dp,
    );

    // Navigate to ChatScreen
    final chatCtrl = Get.find<ChatController>();
    final Conversation conversation = chatCtrl.getOrCreateConversation(
      targetId,
      targetName,
      dp,
    );
    Get.to(() => ChatScreen(conversation: conversation));
  }

  Widget _buildMemberTile({
    required String userId,
    required String fallbackName,
    required String role,
    required bool isOnline,
    required bool isSpeaking,
    required String seatText,
    required VoidCallback onViewProfile,
    required VoidCallback onChatPressed,
  }) {
    return Obx(() {
      final profile = UserProfileCacheManager.rxCache[userId] ?? UserProfileCacheManager.getCachedUser(userId);
      final name = profile?.username ?? fallbackName;
      final avatarUrl = profile?.avatar ?? '';
      final level = profile?.level ?? 1;
      final nobleLevel = profile?.novelLevel ?? 0;
      final vipLevel = profile?.vipLevel ?? 0;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            CustomAvatarFrame(
              userId: userId,
              username: name,
              size: 38,
              child: CircleAvatar(
                radius: 17,
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 18) : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSpeaking) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.mic, color: Color(0xFF00FF66), size: 10),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'Lv $level',
                          style: const TextStyle(color: Colors.amber, fontSize: 7, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (nobleLevel > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'Novel $nobleLevel',
                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 7, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (vipLevel > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'VIP $vipLevel',
                            style: const TextStyle(color: Colors.purpleAccent, fontSize: 7, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          seatText.isNotEmpty ? seatText : role,
                          style: GoogleFonts.poppins(color: Colors.white30, fontSize: 8),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOnline)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF66).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Online', style: TextStyle(color: Color(0xFF00FF66), fontSize: 7, fontWeight: FontWeight.bold)),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Offline', style: TextStyle(color: Colors.white30, fontSize: 7)),
                  ),
                if (userId != RoomController.currentUserId)
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.cyanAccent, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => onChatPressed(),
                  ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, color: Colors.white70, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onViewProfile,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: Get.width * 0.9,
          height: 480,
          decoration: BoxDecoration(
            color: AppTheme.bgDark.withOpacity(0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: const TabBar(
                  isScrollable: true,
                  indicatorColor: AppTheme.primaryColor,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  tabs: [
                    Tab(text: 'Online'),
                    Tab(text: 'Management'),
                    Tab(text: 'Speakers'),
                    Tab(text: 'Elites'),
                    Tab(text: 'VIPs'),
                    Tab(text: 'Audience'),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ZegoUIKitUser>>(
                  stream: ZegoUIKit().getUserListStream(),
                  initialData: const [],
                  builder: (context, snapshot) {
                    final onlineUsers = snapshot.data ?? [];
                    final onlineUserIds = onlineUsers.map((u) => u.id).toSet();

                    return TabBarView(
                      children: [
                        _buildOnlineTab(onlineUsers),
                        _buildManagementTab(onlineUserIds),
                        _buildSpeakersTab(onlineUserIds),
                        _buildElitesTab(onlineUserIds),
                        _buildVipsTab(onlineUserIds),
                        _buildAudienceTab(onlineUserIds, onlineUsers),
                      ],
                    );
                  }
                ),
              ),
              TextButton(
                onPressed: () => Get.back(),
                child: Text('Close', style: GoogleFonts.poppins(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineTab(List<ZegoUIKitUser> onlineUsers) {
    if (onlineUsers.isEmpty) {
      return const Center(child: Text('No users online', style: TextStyle(color: Colors.white30)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: onlineUsers.length,
      itemBuilder: (context, index) {
        final u = onlineUsers[index];
        final member = RoomController.to.activeMembers.firstWhereOrNull((m) => m.userId == u.id);
        final role = member?.role ?? 'Audience';
        final seatsList = RoomController.to.roomSeatsInfo[roomId] ?? [];
        final seatIndex = seatsList.indexWhere((s) => s['userId'] == u.id);
        final seatText = seatIndex != -1 ? 'Seat ${seatIndex + 1}' : 'Audience';

        return _buildMemberTile(
          userId: u.id,
          fallbackName: u.name,
          role: role,
          isOnline: true,
          isSpeaking: u.microphone.value,
          seatText: seatText,
          onViewProfile: () => _handleViewProfile(u.id, u.name, role),
          onChatPressed: () => _handleChatPressed(u.id, u.name),
        );
      },
    );
  }

  Widget _buildManagementTab(Set<String> onlineUserIds) {
    return Obx(() {
      final staffRoles = ['Founder', 'Owner', 'Arena Owner', 'Co-owner', 'Co-Owner', 'Admin', 'Moderator'];
      final staff = RoomController.to.activeMembers.where((m) {
        return staffRoles.any((r) => r.toLowerCase() == m.role.toLowerCase());
      }).toList();

      if (staff.isEmpty) {
        return const Center(child: Text('No management staff found', style: TextStyle(color: Colors.white30)));
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: staff.length,
        itemBuilder: (context, index) {
          final m = staff[index];
          final isOnline = onlineUserIds.contains(m.userId);
          final seatsList = RoomController.to.roomSeatsInfo[roomId] ?? [];
          final seatIndex = seatsList.indexWhere((s) => s['userId'] == m.userId);
          final seatText = seatIndex != -1 ? 'Seat ${seatIndex + 1}' : 'Audience';

          return _buildMemberTile(
            userId: m.userId,
            fallbackName: 'Staff Member',
            role: m.role,
            isOnline: isOnline,
            isSpeaking: false,
            seatText: seatText,
            onViewProfile: () => _handleViewProfile(m.userId, 'Staff', m.role),
            onChatPressed: () => _handleChatPressed(m.userId, 'Staff'),
          );
        },
      );
    });
  }

  Widget _buildSpeakersTab(Set<String> onlineUserIds) {
    return Obx(() {
      final seatsList = RoomController.to.roomSeatsInfo[roomId] ?? [];
      final speakerSeats = seatsList.where((s) => s['userId'] != null).toList();

      if (speakerSeats.isEmpty) {
        return const Center(child: Text('No active speakers', style: TextStyle(color: Colors.white30)));
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: speakerSeats.length,
        itemBuilder: (context, index) {
          final seat = speakerSeats[index];
          final uId = seat['userId'] as String;
          final isOnline = onlineUserIds.contains(uId);
          final seatIndex = seat['seatIndex'] as int;

          return _buildMemberTile(
            userId: uId,
            fallbackName: seat['name'] ?? 'Speaker',
            role: seat['role'] ?? 'Speaker',
            isOnline: isOnline,
            isSpeaking: isOnline,
            seatText: 'Seat ${seatIndex + 1}',
            onViewProfile: () => _handleViewProfile(uId, seat['name'] ?? 'Speaker', seat['role'] ?? 'Speaker'),
            onChatPressed: () => _handleChatPressed(uId, seat['name'] ?? 'Speaker'),
          );
        },
      );
    });
  }

  Widget _buildElitesTab(Set<String> onlineUserIds) {
    return Obx(() {
      final elites = RoomController.to.activeMembers.where((m) {
        final profile = UserProfileCacheManager.rxCache[m.userId] ?? UserProfileCacheManager.getCachedUser(m.userId);
        return (profile?.level ?? 1) >= 20;
      }).toList();

      if (elites.isEmpty) {
        return const Center(child: Text('No Elite members', style: TextStyle(color: Colors.white30)));
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: elites.length,
        itemBuilder: (context, index) {
          final m = elites[index];
          final isOnline = onlineUserIds.contains(m.userId);
          return _buildMemberTile(
            userId: m.userId,
            fallbackName: 'Elite Member',
            role: m.role,
            isOnline: isOnline,
            isSpeaking: false,
            seatText: '',
            onViewProfile: () => _handleViewProfile(m.userId, 'Elite', m.role),
            onChatPressed: () => _handleChatPressed(m.userId, 'Elite'),
          );
        },
      );
    });
  }

  Widget _buildVipsTab(Set<String> onlineUserIds) {
    return Obx(() {
      final vips = RoomController.to.activeMembers.where((m) {
        final profile = UserProfileCacheManager.rxCache[m.userId] ?? UserProfileCacheManager.getCachedUser(m.userId);
        return (profile?.vipLevel ?? 0) > 0 || (profile?.novelLevel ?? 0) > 0;
      }).toList();

      if (vips.isEmpty) {
        return const Center(child: Text('No VIP members', style: TextStyle(color: Colors.white30)));
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: vips.length,
        itemBuilder: (context, index) {
          final m = vips[index];
          final isOnline = onlineUserIds.contains(m.userId);
          return _buildMemberTile(
            userId: m.userId,
            fallbackName: 'VIP Member',
            role: m.role,
            isOnline: isOnline,
            isSpeaking: false,
            seatText: '',
            onViewProfile: () => _handleViewProfile(m.userId, 'VIP', m.role),
            onChatPressed: () => _handleChatPressed(m.userId, 'VIP'),
          );
        },
      );
    });
  }

  Widget _buildAudienceTab(Set<String> onlineUserIds, List<ZegoUIKitUser> onlineUsers) {
    return Obx(() {
      final seatsList = RoomController.to.roomSeatsInfo[roomId] ?? [];
      final speakerUserIds = seatsList.map((s) => s['userId']).where((id) => id != null).toSet();

      final audience = onlineUsers.where((u) => !speakerUserIds.contains(u.id)).toList();

      if (audience.isEmpty) {
        return const Center(child: Text('No audience connected', style: TextStyle(color: Colors.white30)));
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: audience.length,
        itemBuilder: (context, index) {
          final u = audience[index];
          final member = RoomController.to.activeMembers.firstWhereOrNull((m) => m.userId == u.id);
          final role = member?.role ?? 'Audience';

          return _buildMemberTile(
            userId: u.id,
            fallbackName: u.name,
            role: role,
            isOnline: true,
            isSpeaking: u.microphone.value,
            seatText: 'Audience',
            onViewProfile: () => _handleViewProfile(u.id, u.name, role),
            onChatPressed: () => _handleChatPressed(u.id, u.name),
          );
        },
      );
    });
  }
}

class RoomSettingsDialog extends StatefulWidget {
  final String roomId;
  final VoiceRoom room;
  const RoomSettingsDialog({required this.roomId, required this.room, Key? key})
      : super(key: key);

  @override
  State<RoomSettingsDialog> createState() => _RoomSettingsDialogState();
}

class _RoomSettingsDialogState extends State<RoomSettingsDialog> {
  final RoomController _controller = RoomController.to;

  late String _roomName;
  late String _bulletin;
  late String _greetings;
  late String _theme;
  late String _whoCanJoin;
  late String _whoCanBeSeated;
  late String _avatar;
  bool _elitesPriority = true;
  late bool _coHostCanEditCover;
  late bool _adminCanEditCover;

  @override
  void initState() {
    super.initState();
    _roomName = widget.room.name;
    _bulletin = widget.room.bulletin;
    _greetings = widget.room.greetings;
    _theme = widget.room.roomTheme;
    _whoCanJoin = widget.room.whoCanJoin;
    _whoCanBeSeated = widget.room.seatPermissions;
    _avatar = widget.room.avatar ??
        'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150';
    _coHostCanEditCover = widget.room.coHostCanEditCover;
    _adminCanEditCover = widget.room.adminCanEditCover;
  }

  void _saveField(String field, String value) {
    setState(() {
      if (field == 'name') _roomName = value;
      if (field == 'bulletin') _bulletin = value;
      if (field == 'greetings') _greetings = value;
    });
    _controller.updateRoomSettings(
      widget.roomId,
      name: _roomName,
      bulletin: _bulletin,
      greetings: _greetings,
      theme: _theme,
      whoCanJoin: _whoCanJoin,
      seatPermissions: _whoCanBeSeated,
      avatar: _avatar,
    );
  }

  void _showEditTextField(String title, String field, String initialValue) {
    final textController = TextEditingController(text: initialValue);
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.bgLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit $title',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.white54))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor),
                    onPressed: () {
                      if (textController.text.trim().isNotEmpty) {
                        _saveField(field, textController.text.trim());
                      }
                      Get.back();
                    },
                    child: const Text('Save'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showCoverPhotoPicker() {
    final ImagePicker picker = ImagePicker();

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgDark.withOpacity(0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Change Room Cover Photo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Get.back();
                try {
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 75,
                    maxWidth: 1024,
                    maxHeight: 1024,
                  );
                  if (image != null) {
                    final uploadedUrl = await _controller.uploadRoomCoverPhoto(
                      widget.roomId,
                      io.File(image.path),
                    );
                    if (uploadedUrl != null) {
                      setState(() => _avatar = uploadedUrl);
                      Get.snackbar('Success', 'Cover photo updated successfully.', snackPosition: SnackPosition.BOTTOM);
                    }
                  }
                } catch (e) {
                  Get.snackbar('Error', 'Failed to pick image: $e', snackPosition: SnackPosition.BOTTOM);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Get.back();
                try {
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 75,
                    maxWidth: 1024,
                    maxHeight: 1024,
                  );
                  if (image != null) {
                    final uploadedUrl = await _controller.uploadRoomCoverPhoto(
                      widget.roomId,
                      io.File(image.path),
                    );
                    if (uploadedUrl != null) {
                      setState(() => _avatar = uploadedUrl);
                      Get.snackbar('Success', 'Cover photo updated successfully.', snackPosition: SnackPosition.BOTTOM);
                    }
                  }
                } catch (e) {
                  Get.snackbar('Error', 'Failed to pick image: $e', snackPosition: SnackPosition.BOTTOM);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Remove Cover', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Get.back();
                setState(() => _avatar = 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150');
                _controller.updateRoomSettings(
                  widget.roomId,
                  avatar: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150',
                  roomCoverUrl: '',
                );
                Get.snackbar('Success', 'Cover photo removed.', snackPosition: SnackPosition.BOTTOM);
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionSelector(
      String title, String field, List<String> options, String currentValue) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select $title',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...options
                .map((opt) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(opt,
                          style: TextStyle(
                              color: opt == currentValue
                                  ? AppTheme.primaryColor
                                  : Colors.white70,
                              fontWeight: opt == currentValue
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      trailing: opt == currentValue
                          ? const Icon(Icons.check,
                              color: AppTheme.primaryColor)
                          : null,
                      onTap: () {
                        setState(() {
                          if (field == 'whoCanJoin') _whoCanJoin = opt;
                          if (field == 'whoCanBeSeated') _whoCanBeSeated = opt;
                          if (field == 'theme') _theme = opt;
                        });
                        _controller.updateRoomSettings(
                          widget.roomId,
                          theme: _theme,
                          whoCanJoin: _whoCanJoin,
                          seatPermissions: _whoCanBeSeated,
                        );
                        Get.back();
                      },
                    ))
                .toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text('Edit the arena',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Information
            _buildSectionHeader('Basic Information'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  _buildListTile('Arena Name',
                      trailingText: _roomName,
                      onTap: () =>
                          _showEditTextField('Arena Name', 'name', _roomName)),
                  _buildDivider(),
                  _buildListTile(
                    'Cover Photo',
                    trailingWidget: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(_avatar,
                          width: 28, height: 28, fit: BoxFit.cover),
                    ),
                    onTap: () {
                      final currentUid = Supabase.instance.client.auth.currentUser?.id;
                      final isHost = widget.room.hostId == currentUid || widget.room.founderId == currentUid;
                      final isCoHost = widget.room.coOwnerIds.contains(currentUid);
                      final isAdmin = widget.room.adminIds.contains(currentUid);
                      
                      final canEditCover = isHost ||
                          (isCoHost && widget.room.coHostCanEditCover) ||
                          (isAdmin && widget.room.adminCanEditCover);

                      if (canEditCover) {
                        _showCoverPhotoPicker();
                      } else {
                        Get.snackbar(
                          'Permission Denied',
                          'Only Owner/Host or permitted roles can change the cover.',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red.withOpacity(0.8),
                          colorText: Colors.white,
                        );
                      }
                    },
                  ),
                  _buildDivider(),
                  _buildListTile('Background',
                      trailingText: _theme,
                      onTap: () => _showOptionSelector(
                          'Background Theme',
                          'theme',
                          [
                            'Classic Dark',
                            'Purple Velvet',
                            'Emerald Sea',
                            'Cozy Family'
                          ],
                          _theme)),
                  _buildDivider(),
                  _buildListTile('Bulletin',
                      trailingText: _bulletin,
                      onTap: () => _showEditTextField(
                          'Bulletin', 'bulletin', _bulletin)),
                  _buildDivider(),
                  _buildListTile('Greetings',
                      trailingText: _greetings,
                      onTap: () => _showEditTextField(
                          'Greetings', 'greetings', _greetings)),
                  _buildDivider(),
                  _buildListTile('Arena Mode',
                      trailingText: widget.room.type, onTap: () {}),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Arena Admin
            _buildSectionHeader('Arena Admin'),
            Obx(() {
              // Reactively reads from rooms RxList so any role change triggers rebuild
              final room = _controller.rooms
                      .firstWhereOrNull((r) => r.id == widget.roomId) ??
                  (_controller.rooms.isNotEmpty ? _controller.rooms.first : null);

              if (room == null) return const SizedBox.shrink();

              final activeUserIds = _controller.activeMembers.map((m) => m.userId).toSet();
              final coOwners = List<String>.from(room.coOwnerIds).where((id) => activeUserIds.contains(id)).toList();
              final admins = List<String>.from(room.adminIds).where((id) => activeUserIds.contains(id)).toList();
              final starMembers = List<String>.from(room.starMemberIds).where((id) => activeUserIds.contains(id)).toList();
              final ownerId = room.hostId;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    // ── Owner (single) ──
                    _buildRoleGroupTile(
                      role: 'Owner',
                      memberIds: [ownerId],
                      color: const Color(0xFFFFD700),
                    ),

                    // ── Co-owners ──
                    _buildDivider(),
                    _buildRoleGroupTile(
                      role: 'Co-owner',
                      memberIds: coOwners,
                      color: Colors.amber,
                    ),

                    // ── Admins ──
                    _buildDivider(),
                    _buildRoleGroupTile(
                      role: 'Admin',
                      memberIds: admins,
                      color: Colors.purpleAccent,
                    ),

                    // ── Star Members ──
                    _buildDivider(),
                    _buildRoleGroupTile(
                      role: 'Star Member',
                      memberIds: starMembers,
                      color: Colors.cyanAccent,
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            // Arena Management
            _buildSectionHeader('Arena Management'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  _buildListTile(
                    'Arena Elites take priority in queuing',
                    trailingText: _elitesPriority ? 'YES' : 'NO',
                    onTap: () =>
                        setState(() => _elitesPriority = !_elitesPriority),
                  ),
                  _buildDivider(),
                  _buildListTile('Who Can Join',
                      trailingText: _whoCanJoin,
                      onTap: () => _showOptionSelector(
                          'Who Can Join',
                          'whoCanJoin',
                          ['Everyone', 'Members Only', 'VIP Only'],
                          _whoCanJoin)),
                  _buildDivider(),
                  _buildListTile('Who can be seated',
                      trailingText: _whoCanBeSeated,
                      onTap: () => _showOptionSelector(
                          'Who Can Be Seated',
                          'whoCanBeSeated',
                          ['Everyone', 'Speakers Only', 'Management Only'],
                          _whoCanBeSeated)),
                  _buildDivider(),
                  _buildListTile('Song List',
                      trailingText: '3 Songs', onTap: () {}),
                  _buildDivider(),
                  Obx(() {
                    final liveRoom = _controller.rooms
                            .firstWhereOrNull((r) => r.id == widget.roomId) ??
                        widget.room;
                    return _buildListTile(
                      'Block List',
                      trailingText: '${liveRoom.blockList.length} Users',
                      onTap: () => _showBlockListManager(context, liveRoom),
                    );
                  }),
                  if (widget.room.hostId == Supabase.instance.client.auth.currentUser?.id || widget.room.founderId == Supabase.instance.client.auth.currentUser?.id) ...[
                    _buildDivider(),
                    _buildListTile(
                      'Co-owners can edit cover photo',
                      trailingWidget: Switch(
                        value: _coHostCanEditCover,
                        onChanged: (val) {
                          setState(() => _coHostCanEditCover = val);
                          _controller.updateRoomSettings(
                            widget.roomId,
                            coHostCanEditCover: val,
                          );
                        },
                        activeColor: AppTheme.primaryColor,
                      ),
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildListTile(
                      'Admins can edit cover photo',
                      trailingWidget: Switch(
                        value: _adminCanEditCover,
                        onChanged: (val) {
                          setState(() => _adminCanEditCover = val);
                          _controller.updateRoomSettings(
                            widget.roomId,
                            adminCanEditCover: val,
                          );
                        },
                        activeColor: AppTheme.primaryColor,
                      ),
                      onTap: () {},
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
        height: 1, thickness: 0.5, color: Colors.white.withOpacity(0.05));
  }

  Widget _buildListTile(String title,
      {String? trailingText,
      Widget? trailingWidget,
      required VoidCallback onTap}) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingWidget != null) trailingWidget,
          if (trailingText != null)
            Text(
              trailingText.length > 22
                  ? '${trailingText.substring(0, 20)}...'
                  : trailingText,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
        ],
      ),
      onTap: onTap,
    );
  }

  void _showBlockListManager(BuildContext context, VoiceRoom liveRoom) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.bgLight,
        title: const Text('Block List Manager',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: Obx(() {
            // Read reactively from controller to force list updates
            final liveR = _controller.rooms
                    .firstWhereOrNull((r) => r.id == widget.roomId) ??
                liveRoom;

            if (liveR.blockList.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No blocked users in this arena.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textTertiary)),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: liveR.blockList.length,
              itemBuilder: (context, idx) {
                final blockedId = liveR.blockList[idx];
                final name = _getRoomUserName(blockedId);
                final detailed = _controller
                    .roomBannedUsersDetailed[widget.roomId]?[blockedId];
                final durationInfo =
                    detailed != null ? ' (${detailed['duration']})' : '';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundImage:
                        NetworkImage(_getRoomUserAvatar(blockedId)),
                  ),
                  title: Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  subtitle: Text(
                      'ID: ${blockedId.hashCode.abs() % 900000 + 100000}$durationInfo',
                      style: const TextStyle(
                          color: AppTheme.textTertiary, fontSize: 11)),
                  trailing: TextButton(
                    onPressed: () {
                      _controller.unbanUser(widget.roomId, blockedId);
                    },
                    child: const Text('Unblock',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                );
              },
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Close',
                style: TextStyle(color: AppTheme.textTertiary)),
          ),
        ],
      ),
    );
  }

  String _getRoomUserName(String userId) {
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (userId == 'me' || (currentUid != null && userId == currentUid)) {
      return UserProfileCacheManager.currentUser?.username ?? 'Host';
    }
    final cached = UserProfileCacheManager.getCachedUser(userId);
    if (cached != null) return cached.username;
    return 'User_${userId.substring(0, min(userId.length, 5))}';
  }

  String _getRoomUserAvatar(String userId) {
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (userId == 'me' || (currentUid != null && userId == currentUid)) {
      final avatarUrl = UserProfileCacheManager.currentUser?.avatar;
      if (avatarUrl != null && avatarUrl.isNotEmpty) return avatarUrl;
      return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100';
    }
    final cached = UserProfileCacheManager.getCachedUser(userId);
    if (cached != null && cached.avatar != null && cached.avatar!.isNotEmpty) return cached.avatar!;
    return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100';
  }

  /// Builds a single row for a role (Owner/Co-owner/Admin) showing total count
  /// and opens a bottom-sheet with the full list when tapped.
  Widget _buildRoleGroupTile({
    required String role,
    required List<String> memberIds,
    required Color color,
  }) {
    final count = memberIds.length;
    final firstAvatar = count > 0 ? _getRoomUserAvatar(memberIds.first) : null;

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.35), width: 0.8),
        ),
        child: Text(
          role,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        count == 0 ? 'None assigned' : '$count ${count == 1 ? 'member' : 'members'}',
        style: const TextStyle(
            color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w400),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (firstAvatar != null)
            CircleAvatar(
                radius: 10, backgroundImage: NetworkImage(firstAvatar)),
          if (count > 1)
            Container(
              margin: const EdgeInsets.only(left: -6),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Text(
                '+${count - 1}',
                style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
        ],
      ),
      onTap: count == 0
          ? null
          : () => _showTagMemberList(role: role, memberIds: memberIds, color: color),
    );
  }

  /// Shows a bottom sheet listing ALL members of a given role with profile taps.
  void _showTagMemberList({
    required String role,
    required List<String> memberIds,
    required Color color,
  }) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.4), width: 0.8),
                  ),
                  child: Text(role,
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Text(
                  '${memberIds.length} ${memberIds.length == 1 ? 'member' : 'members'}',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),
            // Member list
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: memberIds.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, i) {
                  final uid = memberIds[i];
                  final name = _getRoomUserName(uid);
                  final avatar = _getRoomUserAvatar(uid);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(avatar),
                    ),
                    title: Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'ID: ${uid.hashCode.abs() % 900000 + 100000}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        color: Colors.white24, size: 14),
                    onTap: () {
                      Get.back();
                      _showRoomMemberMiniProfile(uid, name, role);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildAdminTile(
      String userId, String role, String name, String avatarUrl) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(role,
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 10, backgroundImage: NetworkImage(avatarUrl)),
          const SizedBox(width: 8),
          Text(name,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
        ],
      ),
      onTap: () => _showRoomMemberMiniProfile(userId, name, role),
    );
  }

  void _showRoomMemberMiniProfile(
      String userId, String name, String currentRole) {
    final String currentUserId = Supabase.instance.client.auth.currentUser?.id ?? 'uid_anurag_101';
    final bool isOwner = currentUserId == widget.room.hostId || currentUserId == widget.room.founderId;
    final bool isSelf = userId == currentUserId;

    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Profile Info Header
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(_getRoomUserAvatar(userId)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: Colors.blue.withOpacity(0.4),
                                  width: 0.8),
                            ),
                            child: Text(currentRole,
                                style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text('ID: ${userId.hashCode.abs() % 900000 + 100000}',
                              style: const TextStyle(
                                  color: AppTheme.textTertiary, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Mini Profile Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniProfileStat('Level 18', 'Gamification'),
                _miniProfileStat('34,500', 'Gifts Received'),
                _miniProfileStat('Active Host', 'Badge'),
              ],
            ),
            const SizedBox(height: 20),

            const Divider(color: AppTheme.borderColor, height: 1),
            const SizedBox(height: 16),

            // Management actions (if Owner and not self)
            if (isOwner && !isSelf) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('MANAGE ARENA ROLE',
                    style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),

              // Promote/Demote to Co-owner
              _actionTile(
                icon: Icons.star_rounded,
                color: Colors.amber,
                label: currentRole == 'Co-owner'
                    ? 'Demote from Co-owner'
                    : 'Make Co-owner',
                onTap: () {
                  Get.back();
                  _controller.promoteRoomMember(widget.roomId, userId,
                      currentRole == 'Co-owner' ? 'Speaker' : 'Co-owner');
                  Get.snackbar('Role Updated',
                      '$name is now ${currentRole == 'Co-owner' ? 'a Speaker' : 'a Co-owner'}.',
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.9),
                      colorText: Colors.white);
                },
              ),

              // Promote/Demote to Admin
              _actionTile(
                icon: Icons.security_rounded,
                color: Colors.purpleAccent,
                label:
                    currentRole == 'Admin' ? 'Demote from Admin' : 'Make Admin',
                onTap: () {
                  Get.back();
                  _controller.promoteRoomMember(widget.roomId, userId,
                      currentRole == 'Admin' ? 'Speaker' : 'Admin');
                  Get.snackbar('Role Updated',
                      '$name is now ${currentRole == 'Admin' ? 'a Speaker' : 'an Admin'}.',
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.9),
                      colorText: Colors.white);
                },
              ),

              // Kick from room
              _actionTile(
                icon: Icons.gavel_rounded,
                color: AppTheme.errorColor,
                label: 'Kick from Arena',
                onTap: () {
                  Get.back();
                  Get.snackbar(
                      'Kicked User', '$name has been kicked from the arena.',
                      backgroundColor: AppTheme.errorColor.withOpacity(0.9),
                      colorText: Colors.white);
                },
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No management actions available for this user.',
                    style:
                        TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniProfileStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
      ],
    );
  }

  Widget _actionTile(
      {required IconData icon,
      required Color color,
      required String label,
      required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppTheme.textTertiary, size: 16),
    );
  }
}

class SeatVoiceEffect extends StatelessWidget {
  final String userId;
  final double size;
  final Color frameColor;
  final bool isMuted;

  const SeatVoiceEffect({
    required this.userId,
    required this.size,
    required this.frameColor,
    required this.isMuted,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isMuted) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white24,
            width: 1.5,
          ),
        ),
      );
    }

    return StreamBuilder<double>(
      stream: ZegoUIKit().getSoundLevelStream(userId),
      initialData: 0.0,
      builder: (context, snapshot) {
        final volume = snapshot.data ?? 0.0;
        final isSpeaking = volume > 5.0; // Silence threshold
        final factor = (volume / 100.0).clamp(0.0, 1.0);

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Glowing ring around the avatar
            if (isSpeaking)
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: size + 4.0 + (14.0 * factor),
                height: size + 4.0 + (14.0 * factor),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: frameColor.withOpacity(0.15 * (1 - factor)),
                  border: Border.all(
                    color: frameColor.withOpacity(0.6 * (1 - factor)),
                    width: 1.5 + (2.0 * factor),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: frameColor.withOpacity(0.5 + (0.5 * factor)),
                      blurRadius: 6.0 + (18.0 * factor),
                      spreadRadius: 1.0 + (5.0 * factor),
                    )
                  ],
                ),
              ),

            // Dynamic border ring
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSpeaking ? frameColor : Colors.white24,
                  width: isSpeaking ? 2.5 : 1.5,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class VoiceWaveformWidget extends StatelessWidget {
  final String userId;
  final bool isMuted;

  const VoiceWaveformWidget({
    required this.userId,
    required this.isMuted,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isMuted) return const SizedBox.shrink();

    return StreamBuilder<double>(
      stream: ZegoUIKit().getSoundLevelStream(userId),
      initialData: 0.0,
      builder: (context, snapshot) {
        final volume = snapshot.data ?? 0.0;
        final isSpeaking = volume > 5.0;
        if (!isSpeaking) return const SizedBox.shrink();

        final factor = (volume / 100.0).clamp(0.1, 1.0);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            double heightFactor = factor;
            if (index == 0) heightFactor *= 0.7;
            if (index == 2) heightFactor *= 0.5;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 2.2,
              height: 4.0 + (12.0 * heightFactor),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF66),
                borderRadius: BorderRadius.circular(1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF66).withOpacity(0.5),
                    blurRadius: 2,
                  )
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

class OnlineMembersDialog extends StatelessWidget {
  final String roomId;
  final VoiceRoom room;
  const OnlineMembersDialog({required this.roomId, required this.room, Key? key})
      : super(key: key);

  void _handleViewProfile(String userId, String name, String role) {
    Get.back(); // Dismiss OnlineMembersDialog
    final occupiedSeats = (RoomController.to.roomSeatsInfo[roomId] ?? [])
        .where((s) => s['userId'] != null)
        .length;

    Get.dialog(
      MiniProfileDialog(
        roomId: roomId,
        callerUserId: RoomController.currentUserId,
        targetUserId: userId,
        targetUserName: name,
        role: role,
        seatIndex: -1,
        isHost: room.hostId == RoomController.currentUserId || room.founderId == RoomController.currentUserId,
        occupiedSeatsCount: occupiedSeats,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: Get.width * 0.9,
        height: 480,
        decoration: BoxDecoration(
          color: AppTheme.bgDark.withOpacity(0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Online Arena Members',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<ZegoUIKitUser>>(
                stream: ZegoUIKit().getUserListStream(),
                initialData: const [],
                builder: (context, snapshot) {
                  final users = snapshot.data ?? [];
                  if (users.isEmpty) {
                    return Center(
                      child: Text('No users online',
                          style: GoogleFonts.poppins(
                              color: Colors.white30, fontSize: 13)),
                    );
                  }

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final u = users[index];
                      final member = RoomController.to.activeMembers
                          .firstWhereOrNull((m) => m.userId == u.id);
                      final role = member?.role ?? 'Audience';

                      final seatsList =
                          RoomController.to.roomSeatsInfo[roomId] ?? [];
                      final seatIndex =
                          seatsList.indexWhere((s) => s['userId'] == u.id);
                      final seatText =
                          seatIndex != -1 ? 'Seat ${seatIndex + 1}' : 'Audience';

                      return Obx(() {
                        final profile = UserProfileCacheManager.rxCache[u.id] ??
                            UserProfileCacheManager.getCachedUser(u.id);
                        final name = profile?.username ?? u.name;
                        final avatarUrl = profile?.avatar ?? '';
                        final level = profile?.level ?? 1;
                        final nobleLevel = profile?.novelLevel ?? 0;
                        final vipLevel = profile?.vipLevel ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.04)),
                          ),
                          child: Row(
                            children: [
                              CustomAvatarFrame(
                                userId: u.id,
                                username: name,
                                size: 36,
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundImage: avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  child: avatarUrl.isEmpty
                                      ? const Icon(Icons.person, size: 16)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (u.microphone.value) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.mic,
                                              color: Color(0xFF00FF66),
                                              size: 10),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 3, vertical: 0.5),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            'Lv $level',
                                            style: const TextStyle(
                                                color: Colors.amber,
                                                fontSize: 7,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        if (nobleLevel > 0) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 3, vertical: 0.5),
                                            decoration: BoxDecoration(
                                              color: Colors.cyan.withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              'Novel $nobleLevel',
                                              style: const TextStyle(
                                                  color: Colors.cyanAccent,
                                                  fontSize: 7,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        if (vipLevel > 0) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 3, vertical: 0.5),
                                            decoration: BoxDecoration(
                                              color: Colors.purple
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              'VIP $vipLevel',
                                              style: const TextStyle(
                                                  color: Colors.purpleAccent,
                                                  fontSize: 7,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Flexible(
                                          child: Text(
                                            seatText,
                                            style: GoogleFonts.poppins(
                                                color: Colors.white30,
                                                fontSize: 8),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (u.id != RoomController.currentUserId)
                                    IconButton(
                                      icon: const Icon(
                                          Icons.person_add_alt_1_rounded,
                                          color: AppTheme.primaryColor,
                                          size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        Get.snackbar('Followed', 'You followed @$name', snackPosition: SnackPosition.BOTTOM);
                                      },
                                    ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.visibility_outlined,
                                        color: Colors.white70, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () =>
                                        _handleViewProfile(u.id, name, role),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Get.back(),
                child: Text('Close',
                    style: GoogleFonts.poppins(color: Colors.white54)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
