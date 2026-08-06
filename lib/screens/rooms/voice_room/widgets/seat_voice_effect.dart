import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../services/voice/voice_controller.dart';
import '../../../../core/theme.dart';

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
    final activeColor = frameColor != Colors.transparent && frameColor != Colors.white24
        ? frameColor
        : context.adaptiveSeatTheme.speakingRingColor;

    if (isMuted) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: context.adaptiveSeatTheme.emptySeatIconColor,
            width: 1.5,
          ),
        ),
      );
    }

    final soundStream =
        Stream.periodic(const Duration(milliseconds: 100), (count) {
      if (isMuted) return 0.0;
      return VoiceController.to.userSoundLevels[userId] ?? 0.0;
    }).asBroadcastStream();

    return StreamBuilder<double>(
      stream: soundStream,
      initialData: 0.0,
      builder: (context, snapshot) {
        final volume = snapshot.data ?? 0.0;
        final isSpeaking = volume > 5.0; // Silence threshold
        final factor = (volume / 100.0).clamp(0.0, 1.0);

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Glowing ring around the avatar
              if (isSpeaking)
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: size + 4.0 + (14.0 * factor),
                    height: size + 4.0 + (14.0 * factor),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeColor.withOpacity(0.15 * (1 - factor)),
                      border: Border.all(
                        color: activeColor.withOpacity(0.6 * (1 - factor)),
                        width: 1.5 + (2.0 * factor),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withOpacity(0.5 + (0.5 * factor)),
                          blurRadius: 6.0 + (18.0 * factor),
                          spreadRadius: 1.0 + (5.0 * factor),
                        )
                      ],
                    ),
                  ),
                ),

              // Dynamic border ring
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSpeaking ? activeColor : context.adaptiveSeatTheme.emptySeatIconColor,
                    width: isSpeaking ? 2.5 : 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
