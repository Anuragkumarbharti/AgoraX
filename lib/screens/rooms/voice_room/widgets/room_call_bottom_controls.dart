import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme.dart';
import '../../../../services/room/room_controller.dart';
import '../../../../services/room/room_member_controller.dart';
import '../../../../services/user/user_profile_cache_manager.dart';
import '../../../../widgets/gifting/send_gift_dialog.dart';

class RoomCallBottomControls extends StatefulWidget {
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
  State<RoomCallBottomControls> createState() => _RoomCallBottomControlsState();
}

class _RoomCallBottomControlsState extends State<RoomCallBottomControls> {
  String _mentionQuery = '';
  bool _isMentionActive = false;

  @override
  void initState() {
    super.initState();
    widget.chatInputController.addListener(_onTextChanged);
    if (Get.isRegistered<RoomController>()) {
      RoomController.to.roomChatInputController = widget.chatInputController;
      RoomController.to.roomChatFocusNode = widget.chatInputFocusNode;
    }
  }

  @override
  void dispose() {
    widget.chatInputController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.chatInputController.text;
    final selection = widget.chatInputController.selection;
    if (!selection.isValid || selection.baseOffset < 0) {
      if (_isMentionActive) setState(() => _isMentionActive = false);
      return;
    }

    final cursor = selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursor);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex != -1) {
      final query = textBeforeCursor.substring(lastAtIndex + 1);
      if (!query.contains(' ') && !query.contains('\n')) {
        setState(() {
          _isMentionActive = true;
          _mentionQuery = query;
        });
        return;
      }
    }

    if (_isMentionActive) {
      setState(() {
        _isMentionActive = false;
        _mentionQuery = '';
      });
    }
  }

  void _insertMention(String username) {
    final text = widget.chatInputController.text;
    final selection = widget.chatInputController.selection;
    final cursor = selection.isValid ? selection.baseOffset : text.length;
    final textBeforeCursor = text.substring(0, cursor);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex != -1) {
      final prefix = text.substring(0, lastAtIndex);
      final suffix = text.substring(cursor);
      final newText = '$prefix@$username $suffix';
      widget.chatInputController.text = newText;
      widget.chatInputController.selection = TextSelection.collapsed(
        offset: lastAtIndex + username.length + 2,
      );
    }

    setState(() {
      _isMentionActive = false;
      _mentionQuery = '';
    });
    widget.chatInputFocusNode.requestFocus();
  }

  Widget _buildMentionAutocompleteOverlay(BuildContext context) {
    final Map<String, String> candidateMap = {};

    if (Get.isRegistered<RoomMemberController>()) {
      for (final member in RoomMemberController.to.activeMembers) {
        final u = UserProfileCacheManager.getCachedUser(member.userId);
        final name = u?.username ?? u?.displayName ?? 'Student';
        candidateMap[member.userId] = name;
      }
    }

    final seats = RoomController.to.roomSeatsInfo[widget.roomId] ?? [];
    for (final seat in seats) {
      final uid = seat['userId']?.toString();
      final name = seat['userName']?.toString();
      if (uid != null && name != null && uid.isNotEmpty && name.isNotEmpty) {
        candidateMap[uid] = name;
      }
    }

    final matches = candidateMap.entries.where((e) {
      final uName = e.value.toLowerCase();
      return _mentionQuery.isEmpty || uName.contains(_mentionQuery.toLowerCase());
    }).toList();

    if (matches.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: const Color(0xFF141724).withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withOpacity(0.25),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: matches.length,
        separatorBuilder: (_, __) => Divider(
          color: Colors.white.withOpacity(0.08),
          height: 1,
        ),
        itemBuilder: (context, index) {
          final entry = matches[index];
          final uid = entry.key;
          final name = entry.value;
          final u = UserProfileCacheManager.getCachedUser(uid);
          final avatar = u?.avatar;

          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            leading: CircleAvatar(
              radius: 13,
              backgroundImage: avatar != null && avatar.isNotEmpty
                  ? NetworkImage(avatar)
                  : const AssetImage('assets/images/placeholder.png')
                      as ImageProvider,
            ),
            title: Text(
              '@$name',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Room Member',
              style: GoogleFonts.poppins(
                color: Colors.purpleAccent.shade100,
                fontSize: 9.5,
              ),
            ),
            trailing: Icon(
              Icons.north_west_rounded,
              color: Colors.purpleAccent.shade100,
              size: 13,
            ),
            onTap: () => _insertMention(name),
          );
        },
      ),
    );
  }

  void _showEmojiPickerSheet(BuildContext context, tokens) {
    final emojis = [
      '❤️',
      '😂',
      '🔥',
      '👏',
      '🎉',
      '😍',
      '👍',
      '🙌',
      '😮',
      '💯',
      '👑',
      '🚀',
      '⭐',
      '⚡'
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141724),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: emojis.length,
                itemBuilder: (c, idx) {
                  return GestureDetector(
                    onTap: () {
                      widget.chatInputController.text =
                          '${widget.chatInputController.text}${emojis[idx]}';
                      Get.back();
                    },
                    child: Center(
                      child: Text(
                        emojis[idx],
                        style: const TextStyle(fontSize: 24),
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

  @override
  Widget build(BuildContext context) {
    final RoomController controller = RoomController.to;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final effectiveBottomInset =
        isKeyboardOpen ? 4.0 : (bottomInset > 0 ? bottomInset : 8.0);
    final isExpanded = widget.chatInputFocusNode.hasFocus || isKeyboardOpen;

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
          // Mention Autocomplete Overlay
          if (_isMentionActive) _buildMentionAutocompleteOverlay(context),

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
                          color: _isMentionActive
                              ? Colors.purpleAccent
                              : tokens.chatBoxBorderColor,
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
                                controller: widget.chatInputController,
                                focusNode: widget.chatInputFocusNode,
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
                                  hintText: "Let's talk (@ to mention)...",
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
                                        widget.roomId, text.trim());
                                    widget.chatInputController.clear();
                                  }
                                  widget.chatInputFocusNode.requestFocus();
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
                                    widget.chatInputController.text.isNotEmpty)
                                ? GestureDetector(
                                    key: const ValueKey('send_btn'),
                                    onTap: () {
                                      final text =
                                          widget.chatInputController.text.trim();
                                      if (text.isNotEmpty) {
                                        controller.sendRoomBroadcastMessage(
                                            widget.roomId, text);
                                        widget.chatInputController.clear();
                                      }
                                      widget.chatInputFocusNode.requestFocus();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: tokens.chatBoxIconColor
                                            .withOpacity(0.18),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.send_rounded,
                                        color: tokens.chatBoxIconColor,
                                        size: 16,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Mic / Action Buttons
                  GestureDetector(
                    onTap: widget.onToggleMic,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: tokens.chatBoxFillColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: tokens.chatBoxBorderColor,
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        widget.isMicOn.value
                            ? Icons.mic_rounded
                            : Icons.mic_off_rounded,
                        color: widget.isMicOn.value
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Gift Button
                  GestureDetector(
                    onTap: () {
                      Get.dialog(
                        SendGiftDialog(
                          roomId: widget.roomId,
                          targetUserId: RoomController.currentUserId,
                          targetUserName: 'Room Members',
                        ),
                      );
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF2D55), Color(0xFFAF52DE)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.card_giftcard_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
