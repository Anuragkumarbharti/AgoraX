import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../models/room_model.dart';
import '../../services/zego_cloud_service.dart';
import '../../services/permission_service.dart';
import '../../services/room_controller.dart';
import '../../widgets/send_gift_dialog.dart';
import '../../widgets/room_upgrade_dialog.dart';

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

class _VoiceRoomCallScreenState extends State<VoiceRoomCallScreen> with TickerProviderStateMixin {
  late ZegoCloudService _zegoService;
  late PermissionService _permissionService;
  late RoomController _controller;
  
  bool _isMicOn = false; // Starts muted for listeners, host is unmuted
  bool _isCameraOn = false;
  bool _isLoading = true;
  
  // Speakers stage seat states
  final RxList<Map<String, dynamic>> _seats = <Map<String, dynamic>>[].obs;
  
  // Wave animation controllers for speaking glow effects
  late AnimationController _glowController;
  Timer? _speakingSimulationTimer;

  @override
  void initState() {
    super.initState();
    _zegoService = ZegoCloudService();
    _permissionService = PermissionService();
    _controller = RoomController.to;

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _initializeSeats();
    _initializeRoom();
    _startSpeakingSimulation();
  }

  void _initializeSeats() {
    _seats.assignAll([
      {
        'seatIndex': 0,
        'role': 'Host',
        'userId': widget.isHost ? widget.userId : 'host_001',
        'name': widget.isHost ? widget.userName : 'Anurag Kumar',
        'isSpeaking': widget.isHost, // Host starts speaking
      },
      {
        'seatIndex': 1,
        'role': 'Co-owner',
        'userId': 'co_001',
        'name': 'Priya Sharma',
        'isSpeaking': false,
      },
      {
        'seatIndex': 2,
        'role': 'Admin',
        'userId': 'adm_001',
        'name': 'Vikram Aditya',
        'isSpeaking': false,
      },
      {
        'seatIndex': 3,
        'role': 'Star',
        'userId': 'str_001',
        'name': 'Siddharth Roy',
        'isSpeaking': false,
      },
      {
        'seatIndex': 4,
        'role': 'Speaker',
        'userId': null,
        'name': 'Seat 5',
        'isSpeaking': false,
      },
      {
        'seatIndex': 5,
        'role': 'Speaker',
        'userId': null,
        'name': 'Seat 6',
        'isSpeaking': false,
      },
      {
        'seatIndex': 6,
        'role': 'Speaker',
        'userId': null,
        'name': 'Seat 7',
        'isSpeaking': false,
      },
      {
        'seatIndex': 7,
        'role': 'Speaker',
        'userId': null,
        'name': 'Seat 8',
        'isSpeaking': false,
      },
    ]);
  }

  Future<void> _initializeRoom() async {
    try {
      final permissionsGranted = await _permissionService.requestAllPermissions();

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

      await _zegoService.init();
      _zegoService.setUserInfo(widget.userId, widget.userName);

      // Join room
      await _zegoService.joinRoom(
        roomId: widget.roomId,
        enableMic: widget.isHost, // Unmute if host
        enableCamera: false,
      );

      setState(() {
        _isLoading = false;
        if (widget.isHost) {
          _isMicOn = true;
        }
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to join room: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor,
      );
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context);
      });
    }
  }

  // Periodic timer simulating speech waveform activity on occupied seats
  void _startSpeakingSimulation() {
    _speakingSimulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      for (int i = 0; i < _seats.length; i++) {
        final seat = _seats[i];
        if (seat['userId'] != null) {
          // If it is the current user, speak only if mic is unmuted
          if (seat['userId'] == widget.userId) {
            _seats[i] = {
              ...seat,
              'isSpeaking': _isMicOn,
            };
          } else {
            // Randomly toggle other occupants speaking status
            _seats[i] = {
              ...seat,
              'isSpeaking': Random().nextBool(),
            };
          }
        }
      }
    });
  }

  // Force voice rules: check if user is on a seat
  bool _isCurrentUserOnSeat() {
    return _seats.any((s) => s['userId'] == widget.userId);
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

      // Update seat status instantly
      final index = _seats.indexWhere((s) => s['userId'] == widget.userId);
      if (index != -1) {
        _seats[index] = {
          ..._seats[index],
          'isSpeaking': newState,
        };
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to toggle microphone', snackPosition: SnackPosition.BOTTOM);
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
      Get.snackbar('Error', 'Failed to toggle camera', snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _joinSeat(int seatIndex) {
    // If already in that seat, offer to leave
    final seat = _seats[seatIndex];
    if (seat['userId'] == widget.userId) {
      _showLeaveSeatMenu(seatIndex);
      return;
    }

    // Leave previous seat if occupied
    final previousIndex = _seats.indexWhere((s) => s['userId'] == widget.userId);
    if (previousIndex != -1) {
      _seats[previousIndex] = {
        ..._seats[previousIndex],
        'userId': null,
        'name': 'Seat ${previousIndex + 1}',
        'isSpeaking': false,
      };
    }

    // Take new seat
    _seats[seatIndex] = {
      ...seat,
      'userId': widget.userId,
      'name': widget.userName,
      'isSpeaking': false,
    };

    // Auto unmute when taking seat
    _zegoService.toggleMic(true);
    setState(() => _isMicOn = true);

    Get.snackbar(
      'Stage Joined 🎤',
      'You are now in Seat ${seatIndex + 1}. Speak freely!',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.successColor.withOpacity(0.9),
      colorText: Colors.white,
    );
  }

  void _leaveSeat(int seatIndex) {
    final seat = _seats[seatIndex];
    _seats[seatIndex] = {
      ...seat,
      'userId': null,
      'name': 'Seat ${seatIndex + 1}',
      'isSpeaking': false,
    };

    // Auto mute when leaving seat
    _zegoService.toggleMic(false);
    setState(() {
      _isMicOn = false;
      _isCameraOn = false;
    });

    Get.snackbar(
      'Stage Left',
      'You returned to the audience. Your microphone has been muted.',
      snackPosition: SnackPosition.BOTTOM,
    );
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
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: Colors.orange),
              title: const Text('Leave Stage (Move to Audience)', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                _leaveSeat(seatIndex);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: AppTheme.textTertiary),
              title: const Text('Cancel', style: TextStyle(color: AppTheme.textTertiary)),
              onTap: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }

  void _showModerationMenu(String targetUserId, String targetUserName, String role, int seatIndex) {
    // If taping self, show seat action menu
    if (targetUserId == widget.userId) {
      _showLeaveSeatMenu(seatIndex);
      return;
    }

    if (!widget.isHost && widget.userId != 'host_001') {
      Get.snackbar(
        'Permission Denied',
        'Only the Host can moderate participants.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    final isMuted = _controller.mutedUsers[widget.roomId]?.contains(targetUserId) ?? false;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                  child: Text(targetUserName.substring(0, 1).toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      targetUserName,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Role: $role • ID: $targetUserId',
                      style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: AppTheme.borderColor),
            const SizedBox(height: 12),

            // Toggle Mute
            ListTile(
              leading: Icon(isMuted ? Icons.mic : Icons.mic_off, color: Colors.amber),
              title: Text(isMuted ? 'Unmute Speaker' : 'Mute Speaker', style: const TextStyle(color: Colors.white)),
              onTap: () {
                _controller.toggleMuteUser(widget.roomId, targetUserId);
                Get.back();
              },
            ),

            // Remove from Seat
            ListTile(
              leading: const Icon(Icons.airline_seat_recline_normal, color: Colors.deepOrangeAccent),
              title: const Text('Move to Audience', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                _leaveSeat(seatIndex);
              },
            ),

            // Kick User
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.orange),
              title: const Text('Kick from Room', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                Get.snackbar(
                  'Moderation Action',
                  '$targetUserName has been kicked from the room.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppTheme.warningColor.withOpacity(0.8),
                );
              },
            ),

            // Ban User
            ListTile(
              leading: const Icon(Icons.block, color: Colors.redAccent),
              title: const Text('Ban Permanently', style: TextStyle(color: Colors.white)),
              onTap: () {
                _controller.banUser(widget.roomId, targetUserId);
                Get.back();
              },
            ),
          ],
        ),
      ),
      barrierColor: Colors.black54,
    );
  }

  Future<void> _leaveRoom() async {
    try {
      await _zegoService.leaveRoom();
      await _zegoService.dispose();
      Get.back();
    } catch (e) {
      Get.snackbar('Error', 'Failed to leave room', snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  void dispose() {
    _speakingSimulationTimer?.cancel();
    _glowController.dispose();
    _zegoService.dispose();
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
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
              const SizedBox(height: 24),
              Text(
                'Connecting to ${widget.roomName}...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Obx(() {
          final roomIndex = _controller.rooms.indexWhere((r) => r.id == widget.roomId);
          if (roomIndex == -1) {
            return const Center(child: Text('Room Session Closed'));
          }
          final VoiceRoom room = _controller.rooms[roomIndex];

          return Column(
            children: [
              // Header
              _buildCallHeader(room),

              // Top Icy Listener Bubble Row ("ice ice")
              _buildTopAudienceRow(room),

              // Audio Speaker Grid Stage
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: _buildSpeakerStage(room),
                  ),
                ),
              ),

              // Bottom control dock
              _buildControlDock(room),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCallHeader(VoiceRoom room) {
    final int xpNeeded = _controller.getXpForNextLevel(room.level);
    final double xpProgress = (room.xp / xpNeeded).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.bgLight.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back & Room info
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                      onPressed: _leaveRoom,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            room.id,
                            style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Level indicator
              if (room.isPermanent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'LV ${room.level}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (room.isPermanent) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: xpProgress,
                      minHeight: 4,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'XP: ${room.xp}/${xpNeeded}',
                  style: const TextStyle(color: AppTheme.textTertiary, fontSize: 9, fontWeight: FontWeight.bold),
                )
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildTopAudienceRow(VoiceRoom room) {
    // Frosty glassmorphism bar representing horizontal mini listener bubbles
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
      ),
      child: Row(
        children: [
          // Total active counter in room
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: AppTheme.primaryColor, size: 12),
                const SizedBox(width: 4),
                Text(
                  '${room.participantCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Horizontal overlapping bubbles
          Expanded(
            child: SizedBox(
              height: 26,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 12,
                itemBuilder: (context, index) {
                  final bubbleColors = [
                    Colors.amber, Colors.teal, Colors.purple, Colors.pink, Colors.blue, Colors.orange
                  ];
                  final color = bubbleColors[index % bubbleColors.length];

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.25),
                        border: Border.all(color: Colors.white30, width: 0.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'U${index + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
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

  Widget _buildSpeakerStage(VoiceRoom room) {
    return Column(
      children: [
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 24,
            childAspectRatio: 0.72,
          ),
          itemCount: _seats.length,
          itemBuilder: (context, index) {
            final seat = _seats[index];
            final isOccupied = seat['userId'] != null;
            final isSpeaking = seat['isSpeaking'] as bool;
            final isMuted = _controller.mutedUsers[widget.roomId]?.contains(seat['userId'] ?? '') ?? false;

            return Column(
              children: [
                GestureDetector(
                  onTap: () {
                    if (isOccupied) {
                      if (seat['userId'] == widget.userId) {
                        _showLeaveSeatMenu(index);
                      } else {
                        _showMiniProfileDialog(seat['userId'], seat['name'], seat['role'], index);
                      }
                    } else {
                      _joinSeat(index);
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsating glow ring for StarMaker effect (if speaking and not muted)
                      if (isSpeaking && !isMuted && isOccupied)
                        AnimatedBuilder(
                          animation: _glowController,
                          builder: (context, child) {
                            return Container(
                              width: 58 + (14 * _glowController.value),
                              height: 58 + (14 * _glowController.value),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (seat['role'] == 'Host' ? Colors.amber : AppTheme.primaryColor)
                                    .withOpacity(0.3 * (1 - _glowController.value)),
                              ),
                            );
                          },
                        ),
                      
                      // Seat Ring
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOccupied ? AppTheme.bgLight : Colors.white.withOpacity(0.03),
                          border: Border.all(
                            color: isOccupied
                                ? (seat['role'] == 'Host' ? Colors.amber : AppTheme.primaryColor)
                                : AppTheme.borderColor.withOpacity(0.6),
                            width: isOccupied ? 2 : 1,
                          ),
                        ),
                        child: CircleAvatar(
                          backgroundColor: Colors.transparent,
                          child: isOccupied
                              ? Text(
                                  seat['name']!.substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: seat['role'] == 'Host' ? Colors.amber : Colors.white,
                                  ),
                                )
                              : const Icon(Icons.mic, color: AppTheme.textTertiary, size: 16),
                        ),
                      ),

                      // Role Label Badge
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: seat['role'] == 'Host'
                                ? Colors.amber
                                : (isOccupied ? AppTheme.primaryColor : AppTheme.borderColor.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            seat['role'] == 'Host' ? 'Host' : 'Speaker',
                            style: TextStyle(
                              fontSize: 7.5,
                              color: seat['role'] == 'Host' ? Colors.black87 : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // Microphone mute state indicator
                      if (isMuted && isOccupied)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppTheme.errorColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.mic_off, color: Colors.white, size: 8),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isOccupied ? seat['name'] : 'Join Seat',
                  style: TextStyle(
                    color: isOccupied ? Colors.white : AppTheme.textTertiary,
                    fontSize: 10,
                    fontWeight: isOccupied ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildControlDock(VoiceRoom room) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        border: Border(top: BorderSide(color: AppTheme.borderColor, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Microphone Toggle
          _buildDockButton(
            icon: _isMicOn ? Icons.mic : Icons.mic_off,
            label: 'Mute',
            color: _isMicOn ? AppTheme.primaryColor : AppTheme.textTertiary,
            onTap: _toggleMic,
          ),

          // Camera Toggle
          _buildDockButton(
            icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            color: _isCameraOn ? AppTheme.primaryColor : AppTheme.textTertiary,
            onTap: _toggleCamera,
          ),

          // Gifting Button
          _buildDockButton(
            icon: Icons.card_giftcard,
            label: 'Gift',
            color: Colors.amber,
            onTap: () {
              final occupiedSeats = _seats.where((s) => s['userId'] != null).length;
              Get.dialog(SendGiftDialog(
                roomId: widget.roomId,
                occupiedSeatsCount: occupiedSeats,
              ));
            },
          ),

          // Upgrades Button (Redirects to Website Notice)
          _buildDockButton(
            icon: Icons.workspace_premium,
            label: 'Agency',
            color: Colors.purpleAccent,
            onTap: () {
              Get.dialog(RoomUpgradeDialog(roomId: widget.roomId));
            },
          ),

          // Leave Room Button
          _buildDockButton(
            icon: Icons.call_end,
            label: 'Leave',
            color: AppTheme.errorColor,
            onTap: _leaveRoom,
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showMiniProfileDialog(String targetUserId, String targetUserName, String role, int seatIndex) {
    final occupiedSeats = _seats.where((s) => s['userId'] != null).length;
    Get.dialog(
      MiniProfileDialog(
        roomId: widget.roomId,
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        role: role,
        seatIndex: seatIndex,
        isHost: widget.isHost || widget.userId == 'host_001',
        occupiedSeatsCount: occupiedSeats,
        onMoveToAudience: () => _leaveSeat(seatIndex),
      ),
      barrierColor: Colors.black54,
    );
  }
}

class MiniProfileDialog extends StatefulWidget {
  final String roomId;
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

  String _getAvatarUrl(String userId) {
    if (userId.contains('co_001') || userId.contains('priya')) {
      return 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150';
    } else if (userId.contains('adm_001') || userId.contains('vikram')) {
      return 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150';
    } else if (userId.contains('str_001') || userId.contains('siddharth')) {
      return 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150';
    } else {
      return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150';
    }
  }

  String _getNumericId(String userId) {
    return (userId.hashCode.abs() % 90000000 + 10000000).toString();
  }

  @override
  Widget build(BuildContext context) {
    final numericId = _getNumericId(widget.targetUserId);
    final avatarUrl = _getAvatarUrl(widget.targetUserId);
    final isMuted = _controller.mutedUsers[widget.roomId]?.contains(widget.targetUserId) ?? false;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: AppTheme.bgDark.withOpacity(0.95),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top cover gradient
              Container(
                height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(26),
                    topRight: Radius.circular(26),
                  ),
                ),
              ),
              
              // Overlapping Avatar
              Transform.translate(
                offset: const Offset(0, -40),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.bgDark, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                          )
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: AppTheme.bgLight,
                        backgroundImage: NetworkImage(avatarUrl),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Name & Copy button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.targetUserName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            Get.snackbar(
                              'Copied! 📋',
                              'Username "${widget.targetUserName}" copied to clipboard.',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.green.withOpacity(0.8),
                              colorText: Colors.white,
                            );
                          },
                          child: const Icon(
                            Icons.copy_rounded,
                            color: AppTheme.textTertiary,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Unique ID & Copy button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ID: $numericId',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            Get.snackbar(
                              'Copied! 📋',
                              'Unique ID "$numericId" copied to clipboard.',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.green.withOpacity(0.8),
                              colorText: Colors.white,
                            );
                          },
                          child: const Icon(
                            Icons.copy_rounded,
                            color: Colors.amber,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.role == 'Host'
                            ? Colors.amber.withOpacity(0.2)
                            : AppTheme.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.role == 'Host' ? Colors.amber : AppTheme.primaryColor,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.role,
                        style: TextStyle(
                          color: widget.role == 'Host' ? Colors.amber : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Transform.translate(
                offset: const Offset(0, -24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Action buttons: Follow, Message, Gift
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Follow button
                          _buildProfileButton(
                            icon: _isFollowing ? Icons.check_circle : Icons.person_add_rounded,
                            label: _isFollowing ? 'Following' : 'Follow',
                            color: _isFollowing ? AppTheme.bgLight : AppTheme.primaryColor,
                            borderColor: _isFollowing ? AppTheme.borderColor : Colors.transparent,
                            textColor: _isFollowing ? AppTheme.textSecondary : Colors.white,
                            onTap: () {
                              setState(() {
                                _isFollowing = !_isFollowing;
                              });
                              Get.snackbar(
                                _isFollowing ? 'Following! 👥' : 'Unfollowed 👥',
                                _isFollowing
                                    ? 'You are now following ${widget.targetUserName}.'
                                    : 'You stopped following ${widget.targetUserName}.',
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            },
                          ),
                          
                          // Message button
                          _buildProfileButton(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'Message',
                            color: AppTheme.bgLight,
                            borderColor: AppTheme.borderColor,
                            textColor: Colors.white,
                            onTap: () {
                              Get.back();
                              Get.snackbar(
                                'Chat Launched 💬',
                                'Direct messaging ${widget.targetUserName} (Simulated).',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: const Color(0xFF6366F1).withOpacity(0.8),
                                colorText: Colors.white,
                              );
                            },
                          ),
                          
                          // Gift button
                          _buildProfileButton(
                            icon: Icons.card_giftcard_rounded,
                            label: 'Gift',
                            color: Colors.amber,
                            textColor: Colors.black87,
                            onTap: () {
                              Get.back();
                              Get.dialog(
                                SendGiftDialog(
                                  roomId: widget.roomId,
                                  occupiedSeatsCount: widget.occupiedSeatsCount,
                                  targetUserId: widget.targetUserId,
                                  targetUserName: widget.targetUserName,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Moderation section (Host only)
                      if (widget.isHost || widget.targetUserId == 'host_001') ...[
                        const Divider(color: AppTheme.borderColor),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showModMenu = !_showModMenu;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Moderation Options',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Icon(
                                  _showModMenu ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                  color: AppTheme.textTertiary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showModMenu) ...[
                          const SizedBox(height: 8),
                          _buildModOption(
                            icon: isMuted ? Icons.mic : Icons.mic_off,
                            label: isMuted ? 'Unmute Speaker' : 'Mute Speaker',
                            color: Colors.amber,
                            onTap: () {
                              _controller.toggleMuteUser(widget.roomId, widget.targetUserId);
                              setState(() {}); // Refresh dialog
                            },
                          ),
                          _buildModOption(
                            icon: Icons.airline_seat_recline_normal,
                            label: 'Move to Audience',
                            color: Colors.deepOrangeAccent,
                            onTap: () {
                              Get.back();
                              if (widget.onMoveToAudience != null) {
                                widget.onMoveToAudience!();
                              }
                            },
                          ),
                          _buildModOption(
                            icon: Icons.logout,
                            label: 'Kick from Room',
                            color: Colors.orange,
                            onTap: () {
                              Get.back();
                              Get.snackbar(
                                'Moderation Action',
                                '${widget.targetUserName} has been kicked from the room.',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: AppTheme.warningColor.withOpacity(0.8),
                              );
                            },
                          ),
                          _buildModOption(
                            icon: Icons.block,
                            label: 'Ban Permanently',
                            color: Colors.redAccent,
                            onTap: () {
                              _controller.banUser(widget.roomId, widget.targetUserId);
                              Get.back();
                            },
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileButton({
    required IconData icon,
    required String label,
    required Color color,
    Color borderColor = Colors.transparent,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      onTap: onTap,
    );
  }
}
