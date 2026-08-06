import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme.dart';
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
    final effectiveBottomInset =
        isKeyboardOpen ? 4.0 : (bottomInset > 0 ? bottomInset : 8.0);
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
            padding: EdgeInsets.fromLTRB(14, 6, 14, effectiveBottomInset),
            child: Obx(() {
              final bg = controller.activeRoomBackground.value;
              final tokens = AdaptiveSeatThemeEngine.resolve(bg,
                  isDarkMode: context.isDark);

              return Row(
                children: [
                  // Adaptive Liquid Glass Expanding Chat Input Bar
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOutCubic,
                      height: 42,
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: tokens.chatBoxFillColor,
                        borderRadius:
                            BorderRadius.circular(tokens.chatBoxCornerRadius),
                        border: Border.all(
                          color: tokens.chatBoxBorderColor,
                          width: 1.2,
                        ),
                        boxShadow: tokens.seatBoxShadows,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _showEmojiPickerSheet(context, tokens),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.sentiment_satisfied_alt_rounded,
                                color: tokens.chatBoxIconColor,
                                size: 20,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: TextField(
                                controller: chatInputController,
                                focusNode: chatInputFocusNode,
                                textInputAction: TextInputAction.send,
                                cursorColor: tokens.chatBoxTextColor,
                                maxLines: 1,
                                minLines: 1,
                                scrollPadding: EdgeInsets.zero,
                                textAlignVertical: TextAlignVertical.center,
                                style: GoogleFonts.poppins(
                                  color: tokens.chatBoxTextColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Let's talk...",
                                  hintStyle: GoogleFonts.poppins(
                                    color: tokens.chatBoxPlaceholderColor,
                                    fontSize: 12.5,
                                    height: 1.2,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onSubmitted: (text) {
                                  if (text.trim().isNotEmpty) {
                                    controller.sendRoomBroadcastMessage(
                                        roomId, text.trim());
                                    chatInputController.clear();
                                  }
                                  chatInputFocusNode.requestFocus();
                                },
                              ),
                            ),
                          ),
                          // Smooth Fade/Scale Send Icon when expanded or text is present
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 100),
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
                                      chatInputFocusNode.requestFocus();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: tokens.chatBoxFillColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: tokens.chatBoxBorderColor,
                                            width: 1.0),
                                      ),
                                      child: Icon(
                                        Icons.send_rounded,
                                        color: tokens.chatBoxIconColor,
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

                  // Action Buttons Row (Seat Action, Mic, Menu, Gift) smoothly fading out when expanded
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 120),
                    firstCurve: Curves.easeOutCubic,
                    secondCurve: Curves.easeOutCubic,
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
                            tokens: tokens,
                            onTap: () => Get.snackbar('Seat Action',
                                'Requesting seat or raising hand.'),
                          ),
                          // Self-Mute Mic Quick Toggle Button (right next to Up-Arrow)
                          Builder(
                            builder: (context) {
                              final isMicActive =
                                  isCurrentUserOnSeat && isMicOn.value;

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
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeInOutCubic,
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: isMicActive
                                          ? tokens.chatBoxFillColor
                                          : tokens.chatBoxFillColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isMicActive
                                            ? tokens.chatBoxBorderColor
                                            : tokens.chatBoxBorderColor,
                                        width: 1.2,
                                      ),
                                      boxShadow: tokens.seatBoxShadows,
                                    ),
                                    child: Icon(
                                      isMicActive ? Icons.mic : Icons.mic_off,
                                      color: isMicActive
                                          ? tokens.iconColor
                                          : tokens.micOffIconColor,
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
                                tokens: tokens,
                                onTap: () =>
                                    onShowRoomOptionsMenuSheet(context),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle),
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
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeInOutCubic,
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: tokens.chatBoxFillColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: tokens.chatBoxBorderColor,
                                    width: 1.2),
                                boxShadow: tokens.seatBoxShadows,
                              ),
                              child: Icon(Icons.card_giftcard,
                                  color: tokens.iconColor, size: 19),
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
      required AdaptiveSeatThemeTokens tokens,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tokens.chatBoxFillColor,
          shape: BoxShape.circle,
          border: Border.all(color: tokens.chatBoxBorderColor, width: 1.0),
        ),
        child: Icon(icon, color: tokens.iconColor, size: 18),
      ),
    );
  }

  void _showEmojiPickerSheet(
      BuildContext context, AdaptiveSeatThemeTokens tokens) {
    final List<String> popularEmojis = [
      '❤️', '😂', '🔥', '👏', '🎉', '👑', '👍', '😮',
      '🙏', '💯', '😍', '🥳', '😎', '✨', '🚀', '💪',
      '💖', '⭐', '🎈', '🤩', '🙌', '⚡', '😇', '🥳',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          decoration: BoxDecoration(
            color: tokens.chatBoxFillColor.withOpacity(0.95),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: tokens.chatBoxBorderColor, width: 1.2),
            boxShadow: tokens.seatBoxShadows,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.chatBoxPlaceholderColor.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Select Emoji",
                style: GoogleFonts.poppins(
                  color: tokens.chatBoxTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: popularEmojis.length,
                itemBuilder: (context, index) {
                  final emoji = popularEmojis[index];
                  return GestureDetector(
                    onTap: () {
                      final currentText = chatInputController.text;
                      final selection = chatInputController.selection;
                      if (selection.isValid && selection.start >= 0) {
                        final newText = currentText.replaceRange(
                            selection.start, selection.end, emoji);
                        chatInputController.text = newText;
                        chatInputController.selection = TextSelection.collapsed(
                            offset: selection.start + emoji.length);
                      } else {
                        chatInputController.text = currentText + emoji;
                        chatInputController.selection = TextSelection.collapsed(
                            offset: chatInputController.text.length);
                      }
                      Navigator.pop(ctx);
                      chatInputFocusNode.requestFocus();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: tokens.chatBoxFillColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: tokens.chatBoxBorderColor.withOpacity(0.5)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
