import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../services/zego_cloud_service.dart';
import '../../services/permission_service.dart';

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

class _VoiceRoomCallScreenState extends State<VoiceRoomCallScreen> {
  late ZegoCloudService _zegoService;
  late PermissionService _permissionService;
  bool _isMicOn = true;
  bool _isCameraOn = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _zegoService = ZegoCloudService();
    _permissionService = PermissionService();
    _initializeRoom();
  }

  Future<void> _initializeRoom() async {
    try {
      // Request permissions
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

      // Initialize ZEGOCLOUD
      await _zegoService.init();

      // Set user info
      _zegoService.setUserInfo(widget.userId, widget.userName);

      // Join room
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

  @override
  void dispose() {
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
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
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
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.roomName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_zegoService.getRoomMembersCount()} participants',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      'LIVE',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Avatar
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          widget.userName.substring(0, 1).toUpperCase(),
                          style:
                              Theme.of(context).textTheme.displayMedium?.copyWith(
                                    color: AppTheme.primaryColor,
                                  ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // User Name
                    Text(
                      widget.userName,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),

                    // Status
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.successColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Connected',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.successColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Controls
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Microphone Button
                  _buildControlButton(
                    icon: _isMicOn ? Icons.mic : Icons.mic_off,
                    label: _isMicOn ? 'Mic On' : 'Mic Off',
                    isActive: _isMicOn,
                    onTap: _toggleMic,
                  ),

                  // Camera Button
                  _buildControlButton(
                    icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                    label: _isCameraOn ? 'Camera On' : 'Camera Off',
                    isActive: _isCameraOn,
                    onTap: _toggleCamera,
                  ),

                  // End Call Button
                  GestureDetector(
                    onTap: _leaveRoom,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primaryColor : AppTheme.cardBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppTheme.primaryColor : AppTheme.borderColor,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : AppTheme.textPrimary,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isActive ? AppTheme.primaryColor : AppTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
