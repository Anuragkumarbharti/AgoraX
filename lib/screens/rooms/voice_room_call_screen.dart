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
                      _showModerationMenu(seat['userId'], seat['name'], seat['role'], index);
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
                            seat['role'],
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
              Get.dialog(SendGiftDialog(roomId: widget.roomId));
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
}
