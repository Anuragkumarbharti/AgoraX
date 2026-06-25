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

class _VoiceRoomCallScreenState extends State<VoiceRoomCallScreen> with SingleTickerProviderStateMixin {
  late ZegoCloudService _zegoService;
  late PermissionService _permissionService;
  late RoomController _controller;
  
  bool _isMicOn = true;
  bool _isCameraOn = false;
  bool _isLoading = true;
  
  // Animation for speaker wave pulse
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _zegoService = ZegoCloudService();
    _permissionService = PermissionService();
    _controller = RoomController.to;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _initializeRoom();
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

      await _zegoService.joinRoom(
        roomId: widget.roomId,
        enableMic: true,
        enableCamera: false, // Start with camera off for audio rooms
      );

      setState(() => _isLoading = false);
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

  Future<void> _toggleMic() async {
    try {
      final newState = !_isMicOn;
      _zegoService.toggleMic(newState);
      setState(() => _isMicOn = newState);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to toggle microphone',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  Future<void> _toggleCamera() async {
    try {
      final newState = !_isCameraOn;
      _zegoService.toggleCamera(newState);
      setState(() => _isCameraOn = newState);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to toggle camera',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  Future<void> _leaveRoom() async {
    try {
      await _zegoService.leaveRoom();
      await _zegoService.dispose();
      Get.back();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to leave room',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  void _showModerationMenu(String targetUserId, String targetUserName, String role) {
    if (!widget.isHost && widget.userId != 'host_001') {
      Get.snackbar(
        'Permission Denied',
        'Only the Host or Admins can perform moderation actions.',
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

  @override
  void dispose() {
    _pulseController.dispose();
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
              // Header with Room Level & Coins
              _buildCallHeader(room),

              // Audio Wave Stage / Speakers Grid
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        // Host & Speakers Stage
                        _buildSpeakerStage(room),
                        const SizedBox(height: 24),

                        // Audience/Listeners list
                        _buildAudienceSection(room),
                      ],
                    ),
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
              // Room Details
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
                          Row(
                            children: [
                              Text(
                                room.id,
                                style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.people_outline, color: AppTheme.textTertiary, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${room.participantCount} active',
                                style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Level Badges & Coins
              Row(
                children: [
                  if (room.isPermanent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.indigo, Color(0xFF6366F1)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'LV ${room.level}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.bgLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${_controller.walletBalance.value}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
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

  Widget _buildSpeakerStage(VoiceRoom room) {
    // We render 8 speaker seats
    final List<Map<String, dynamic>> seats = [
      {'role': 'Host', 'userId': room.hostId, 'name': room.ownerName, 'isSpeaking': true},
      {'role': 'Co-owner', 'userId': room.coOwnerIds.isNotEmpty ? room.coOwnerIds[0] : null, 'name': 'Co-owner Seat', 'isSpeaking': false},
      {'role': 'Admin', 'userId': room.adminIds.isNotEmpty ? room.adminIds[0] : null, 'name': 'Admin Seat', 'isSpeaking': false},
      {'role': 'Star', 'userId': room.starMemberIds.isNotEmpty ? room.starMemberIds[0] : null, 'name': 'Star Seat', 'isSpeaking': false},
      {'role': 'Speaker', 'userId': null, 'name': 'Speaker Seat', 'isSpeaking': false},
      {'role': 'Speaker', 'userId': null, 'name': 'Speaker Seat', 'isSpeaking': false},
      {'role': 'Speaker', 'userId': null, 'name': 'Speaker Seat', 'isSpeaking': false},
      {'role': 'Speaker', 'userId': null, 'name': 'Speaker Seat', 'isSpeaking': false},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SPEAKING STAGE 🎙️',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              if (room.allowScreenShare)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'WATCH PARTY ON',
                    style: TextStyle(color: AppTheme.successColor, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: seats.length,
            itemBuilder: (context, index) {
              final seat = seats[index];
              final isOccupied = seat['userId'] != null;
              final isSpeaking = seat['isSpeaking'] as bool;
              final isMuted = _controller.mutedUsers[widget.roomId]?.contains(seat['userId'] ?? '') ?? false;

              return Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (isOccupied) {
                        _showModerationMenu(seat['userId'], seat['name'], seat['role']);
                      } else {
                        // Request to take mic seat
                        Get.snackbar('Seat Requested', 'Request to join mic stage sent to host.', snackPosition: SnackPosition.BOTTOM);
                      }
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Speaking Wave Pulse Effect
                        if (isSpeaking && !isMuted)
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                width: 56 + (16 * _pulseController.value),
                                height: 56 + (16 * _pulseController.value),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primaryColor.withOpacity(0.3 * (1 - _pulseController.value)),
                                ),
                              );
                            },
                          ),
                        
                        // Seat Circle
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOccupied ? AppTheme.bgLight : Colors.transparent,
                            border: Border.all(
                              color: isOccupied
                                  ? (seat['role'] == 'Host' ? Colors.amber : AppTheme.primaryColor)
                                  : AppTheme.borderColor,
                              width: isOccupied ? 2.0 : 1.0,
                            ),
                          ),
                          child: CircleAvatar(
                            backgroundColor: Colors.transparent,
                            child: isOccupied
                                ? Text(
                                    seat['name']!.substring(0, 1).toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: seat['role'] == 'Host' ? Colors.amber : Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add, color: AppTheme.textTertiary, size: 20),
                          ),
                        ),

                        // Role badge
                        Positioned(
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: seat['role'] == 'Host'
                                  ? Colors.amber
                                  : (isOccupied ? AppTheme.primaryColor : AppTheme.borderColor),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              seat['role'],
                              style: const TextStyle(fontSize: 8, color: Colors.black87, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        // Muted icon overlay
                        if (isMuted)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: AppTheme.errorColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.mic_off, color: Colors.white, size: 10),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isOccupied ? seat['name'] : 'Empty Seat',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceSection(VoiceRoom room) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AUDIENCE (${max(0, room.participantCount - 4)} listening)',
              style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.filter_list, color: AppTheme.textTertiary, size: 16),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: 12, // Simulated active audience members
          itemBuilder: (context, index) {
            final String uId = 'aud_$index';
            final String uName = 'Listener $index';

            return Column(
              children: [
                GestureDetector(
                  onTap: () => _showModerationMenu(uId, uName, 'Listener'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.cardBg,
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Center(
                      child: Text(
                        uName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  uName,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
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
            color: _isMicOn ? AppTheme.primaryColor : AppTheme.borderColor,
            onTap: _toggleMic,
          ),

          // Camera Toggle
          _buildDockButton(
            icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            color: _isCameraOn ? AppTheme.primaryColor : AppTheme.borderColor,
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

          // Upgrades Button (Host only)
          if (room.isPermanent)
            _buildDockButton(
              icon: Icons.workspace_premium,
              label: 'Upgrade',
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
              color: color.withOpacity(0.15),
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
