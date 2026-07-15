import 'package:flutter/material.dart';
import 'package:creania/core/theme.dart';

class RoomControlsWidget extends StatelessWidget {
  final bool isMicOn;
  final bool isCameraOn;
  final bool isSpeakerOn;
  final VoidCallback onMicToggle;
  final VoidCallback onCameraToggle;
  final VoidCallback onSpeakerToggle;
  final VoidCallback onRaiseHand;
  final VoidCallback onLeaveRoom;

  const RoomControlsWidget({
    Key? key,
    required this.isMicOn,
    required this.isCameraOn,
    required this.isSpeakerOn,
    required this.onMicToggle,
    required this.onCameraToggle,
    required this.onSpeakerToggle,
    required this.onRaiseHand,
    required this.onLeaveRoom,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        border: Border(
          top: BorderSide(
            color: context.borderColor,
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControl(
                context,
                icon: isMicOn ? Icons.mic : Icons.mic_off,
                label: 'Microphone',
                isActive: isMicOn,
                onTap: onMicToggle,
              ),
              _buildControl(
                context,
                icon: isCameraOn ? Icons.videocam : Icons.videocam_off,
                label: 'Camera',
                isActive: isCameraOn,
                onTap: onCameraToggle,
              ),
              _buildControl(
                context,
                icon: isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                label: 'Speaker',
                isActive: isSpeakerOn,
                onTap: onSpeakerToggle,
              ),
              _buildControl(
                context,
                icon: Icons.pan_tool,
                label: 'Raise Hand',
                isActive: false,
                onTap: onRaiseHand,
              ),
            ],
          ),
          SizedBox(height: 24),

          // Leave Room Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onLeaveRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.errorColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Leave Room',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControl(
    BuildContext context, {
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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isActive ? context.primaryColor : context.secondaryBackgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? context.primaryColor : context.borderColor,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : context.caption,
              size: 24,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
