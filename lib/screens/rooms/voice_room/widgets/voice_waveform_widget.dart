import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../services/voice/voice_controller.dart';

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
