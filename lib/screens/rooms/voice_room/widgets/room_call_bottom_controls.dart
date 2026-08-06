import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/room/room_controller.dart';
import '../../../../widgets/gifting/send_gift_dialog.dart';

class RoomCallBottomControls extends StatelessWidget {
  final String roomId;
  final TextEditingController chatInputController;
  final FocusNode chatInputFocusNode;
  final RxBool isMicOn;
  final bool isCurrentUserOnSeat;
  final VoidCallback onToggleMic;
  final Function(BuildContext) onShowRoomOptionsMenuSheet;
  final VoidCallback onTriggerReaction;

  const RoomCallBottomControls({
    Key? key,
    required this.roomId,
    required this.chatInputController,
    required this.chatInputFocusNode,
    required this.isMicOn,
    required this.isCurrentUserOnSeat,
    required this.onToggleMic,
    required this.onShowRoomOptionsMenuSheet,
    required this.onTriggerReaction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final RoomController controller = RoomController.to;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final effectiveBottomInset = isKeyboardOpen ? 0.0 : bottomInset;
    final isExpanded = chatInputFocusNode.hasFocus || isKeyboardOpen;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.black.withOpacity(0.94)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + effectiveBottomInset),
            child: Obx(() {
              final bg = controller.activeRoomBackground.value;
              final accentColor =
                  (bg.gradientColors != null && bg.gradientColors!.isNotEmpty)
                      ? bg.gradientColors!.first
                      : const Color(0xFFFF2D55);

              return Row(
                children: [
                  // StarMaker Style Smooth Expanding Chat Input Bar
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOutCubic,
                      height: 42,
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(
                                bg.isLightBackground ? 0.75 : 0.50),
                            accentColor.withOpacity(0.25),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: accentColor.withOpacity(0.55),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.20),
                            blurRadius: 10,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: chatInputController,
                              focusNode: chatInputFocusNode,
                              cursorColor: accentColor,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: "Let's talk...",
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.white60,
                                  fontSize: 12.5,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                filled: false,
                                fillColor: Colors.transparent,
                                isDense: true,
                              ),
                              onSubmitted: (text) {
                                if (text.trim().isNotEmpty) {
                                  controller.sendRoomBroadcastMessage(
                                      roomId, text.trim());
                                  chatInputController.clear();
                                }
                                chatInputFocusNode.unfocus();
                              },
                            ),
                          ),
                          // Smooth Fade/Scale Send Icon when expanded or text is present
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, anim) => ScaleTransition(
                              scale: anim,
                              child:
                                  FadeTransition(opacity: anim, child: child),
                            ),
                            child: (isExpanded ||
                                    chatInputController.text.isNotEmpty)
                                ? GestureDetector(
                                    key: const ValueKey('send_btn'),
                                    onTap: () {
                                      final text =
                                          chatInputController.text.trim();
                                      if (text.isNotEmpty) {
                                        controller.sendRoomBroadcastMessage(
                                            roomId, text);
                                        chatInputController.clear();
                                      }
                                      chatInputFocusNode.unfocus();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: accentColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                        size: 13,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey('empty_btn')),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Action Buttons Row (Seat Action, Menu, Gift) smoothly fading out when expanded
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 280),
                    firstCurve: Curves.easeInOutCubic,
                    secondCurve: Curves.easeInOutCubic,
                    crossFadeState: isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 4),
                          _buildIconButton(
                            icon: Icons.arrow_upward_rounded,
                            color: Colors.white70,
                            onTap: () => Get.snackbar('Seat Action',
                                'Requesting seat or raising hand.'),
                          ),
                          // Self-Mute Mic Quick Toggle Button (right next to Up-Arrow)
                          Builder(
                            builder: (context) {
                              final isMicActive = isCurrentUserOnSeat && isMicOn.value;

                              return Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    if (isCurrentUserOnSeat) {
                                      onToggleMic();
                                    } else {
                                      Get.snackbar(
                                        'Stage Mic 🎤',
                                        'Take a seat to unmute your mic.',
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor:
                                            Colors.black.withOpacity(0.85),
                                        colorText: Colors.white,
                                      );
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: isMicActive
                                          ? accentColor.withOpacity(0.25)
                                          : Colors.white.withOpacity(0.10),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isMicActive
                                            ? accentColor
                                            : Colors.white24,
                                        width: 1.8,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isMicActive
                                              ? accentColor.withOpacity(0.40)
                                              : Colors.black.withOpacity(0.25),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isMicActive ? Icons.mic : Icons.mic_off,
                                      color: isMicActive
                                          ? Colors.white
                                          : const Color(0xFFF87171),
                                      size: 18,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Stack(
                            children: [
                              _buildIconButton(
                                icon: Icons.menu,
                                color: Colors.white70,
                                onTap: () => onShowRoomOptionsMenuSheet(context),
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
                                  roomId: roomId, occupiedSeatsCount: 3));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: const BoxDecoration(
                                  color: Colors.pinkAccent,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.card_giftcard,
                                  color: Colors.white, size: 19),
                            ),
                          ),
                        ],
                      ),
                    ),
                    secondChild: const SizedBox.shrink(),
                  ),
                ],
              );
            }),
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
}
