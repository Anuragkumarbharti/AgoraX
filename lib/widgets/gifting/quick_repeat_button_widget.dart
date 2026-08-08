import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/gifting/quick_repeat_controller.dart';

class QuickRepeatButtonWidget extends StatelessWidget {
  final String roomId;
  final String currentUserId;

  const QuickRepeatButtonWidget({
    Key? key,
    required this.roomId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = QuickRepeatController.to;

    return Obx(() {
      if (!controller.isVisible(roomId, currentUserId)) {
        return const SizedBox.shrink();
      }

      final state = controller.activeState.value!;
      final isProcessing = controller.isProcessing.value;
      final progressVal = controller.progress.value;
      final secondsLeft = controller.remainingSeconds.value;

      return Container(
        margin: const EdgeInsets.only(bottom: 60, left: 16, right: 16),
        alignment: Alignment.bottomRight,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFFF59E0B).withOpacity(0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular Timer Ring wrapping Gift Icon
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      value: progressVal,
                      strokeWidth: 2.5,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        secondsLeft <= 3 ? Colors.redAccent : const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                  Text(
                    state.giftIcon.isNotEmpty ? state.giftIcon : '🎁',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(width: 8),

              // Gift Name & Counter Display
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.giftName,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Obx(() {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                      child: Container(
                        key: ValueKey('qty_${state.currentQuantity.value}'),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '×${state.currentQuantity.value}',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(width: 10),

              // Repeat Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isProcessing
                      ? null
                      : () {
                          controller.repeatGift(roomId);
                        },
                  borderRadius: BorderRadius.circular(20),
                  splashColor: const Color(0xFFF59E0B).withOpacity(0.4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isProcessing
                          ? const LinearGradient(colors: [Colors.grey, Colors.black45])
                          : const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEC4899).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isProcessing)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        else
                          const Icon(
                            Icons.replay_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        const SizedBox(width: 4),
                        Text(
                          'Repeat',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
