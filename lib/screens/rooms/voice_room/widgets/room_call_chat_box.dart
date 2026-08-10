import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:collection/collection.dart';

import '../../../../core/theme.dart';
import '../../../../models/chat/chat_model.dart';
import '../../../../services/room/room_controller.dart';
import '../../../../services/user/user_profile_cache_manager.dart';
import '../../../../services/voice/voice_controller.dart';
import '../dialogs/mini_profile_dialog.dart';
import '../../../../widgets/common/optimized_image.dart';

class RoomCallChatBox extends StatefulWidget {
  final String roomId;
  final ScrollController chatScrollController;
  final String Function(String) getUserDp;

  const RoomCallChatBox({
    Key? key,
    required this.roomId,
    required this.chatScrollController,
    required this.getUserDp,
  }) : super(key: key);

  @override
  State<RoomCallChatBox> createState() => _RoomCallChatBoxState();
}

class _RoomCallChatBoxState extends State<RoomCallChatBox> {
  bool _isAtBottom = true;
  int _unreadCount = 0;
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    widget.chatScrollController.addListener(_onScrollListener);
  }

  @override
  void dispose() {
    widget.chatScrollController.removeListener(_onScrollListener);
    super.dispose();
  }

  void _onScrollListener() {
    if (!widget.chatScrollController.hasClients) return;
    final position = widget.chatScrollController.position;
    final isAtBottomNow = position.pixels >= (position.maxScrollExtent - 40);

    if (isAtBottomNow != _isAtBottom) {
      setState(() {
        _isAtBottom = isAtBottomNow;
        if (_isAtBottom) {
          _unreadCount = 0;
        }
      });
    }
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.chatScrollController.hasClients) return;
      final maxExtent = widget.chatScrollController.position.maxScrollExtent;
      if (animate) {
        widget.chatScrollController.animateTo(
          maxExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        widget.chatScrollController.jumpTo(maxExtent);
      }
      if (mounted) {
        setState(() {
          _unreadCount = 0;
          _isAtBottom = true;
        });
      }
    });
  }

  void _showMiniProfile(String targetUserId, String targetUserName, {String role = 'Guest'}) {
    final controller = RoomController.to;
    final occupiedSeats = (controller.roomSeatsInfo[widget.roomId] ?? [])
        .where((s) => s['userId'] != null)
        .length;
    final room = controller.rooms.firstWhereOrNull((r) => r.id == widget.roomId);
    final isHost = room?.hostId == RoomController.currentUserId ||
        room?.founderId == RoomController.currentUserId;

    Get.dialog(
      MiniProfileDialog(
        roomId: widget.roomId,
        callerUserId: RoomController.currentUserId,
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        role: role,
        seatIndex: -1,
        isHost: isHost,
        occupiedSeatsCount: occupiedSeats,
      ),
    );
  }

  void _triggerDirectMention(RoomChatMessage message) {
    if (message.senderName.isEmpty) return;
    HapticFeedback.lightImpact();
    RoomController.to.mentionUserInRoomChat(message.senderName);
  }

  @override
  Widget build(BuildContext context) {
    final RoomController controller = RoomController.to;

    return Stack(
      children: [
        Obx(() {
          final chatsMap = controller.roomChats;
          final _ = chatsMap.length; // Force GetX observation
          final messages = chatsMap[widget.roomId] ?? <RoomChatMessage>[];

          // Handle auto-scroll or unread count update when messages change
          if (messages.length > _previousMessageCount) {
            final isNewFromMe = messages.isNotEmpty &&
                messages.last.senderId == RoomController.currentUserId;

            _previousMessageCount = messages.length;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_isAtBottom || isNewFromMe) {
                _scrollToBottom(animate: true);
              } else {
                setState(() {
                  _unreadCount += 1;
                });
              }
            });
          }

          return ListView.builder(
            controller: widget.chatScrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              bool isConsecutive = false;
              if (index > 0) {
                final prevMsg = messages[index - 1];
                if (msg.senderId == prevMsg.senderId &&
                    !msg.isSystem &&
                    msg.messageType != 'activity' &&
                    !prevMsg.isSystem &&
                    prevMsg.messageType != 'activity' &&
                    msg.timestamp.difference(prevMsg.timestamp).inMinutes < 3) {
                  isConsecutive = true;
                }
              }
              return buildCustomChatMessage(context, msg,
                  isConsecutive: isConsecutive);
            },
          );
        }),

        // New Messages Indicator Pill Button
        if (!_isAtBottom && _unreadCount > 0)
          Positioned(
            bottom: 12,
            right: 16,
            child: GestureDetector(
              onTap: () => _scrollToBottom(animate: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purpleAccent.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_downward_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '$_unreadCount new message${_unreadCount > 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget buildCustomChatMessage(BuildContext context, RoomChatMessage message,
      {bool isConsecutive = false}) {
    final RoomController controller = RoomController.to;
    final bg = controller.activeRoomBackground.value;
    final tokens =
        AdaptiveSeatThemeEngine.resolve(bg, isDarkMode: context.isDark);

    final isSystem = message.isSystem;
    final isActivity = message.messageType == 'activity';

    if (isSystem || isActivity) {
      IconData icon = Icons.notifications_rounded;
      final type = message.eventType ?? '';
      bool isJackpot = type == 'lucky_jackpot';
      bool isLuckyWin = type == 'lucky_win' || isJackpot;

      if (type == 'room_join') {
        icon = Icons.login_rounded;
      } else if (type == 'room_leave') {
        icon = Icons.logout_rounded;
      } else if (type.startsWith('seat_')) {
        icon = Icons.chair_rounded;
      } else if (type == 'gift_sent') {
        icon = Icons.card_giftcard_rounded;
      } else if (isJackpot) {
        icon = Icons.diamond_rounded;
      } else if (isLuckyWin) {
        icon = Icons.casino_rounded;
      }

      final timestampStr =
          '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

      return Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _triggerDirectMention(message),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.chatBoxFillColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isJackpot ? const Color(0xFFF59E0B) : tokens.chatBoxBorderColor,
                width: isJackpot ? 1.2 : 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: (isJackpot ? const Color(0xFFF59E0B) : tokens.iconColor)
                        .withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isJackpot ? const Color(0xFFF59E0B) : tokens.iconColor,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: GestureDetector(
                    onTap: message.senderId != 'system' && message.senderId.isNotEmpty
                        ? () => _showMiniProfile(message.senderId, message.senderName)
                        : null,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOutCubic,
                      style: GoogleFonts.poppins(
                        color: tokens.primaryTextColor,
                        fontSize: 10.5,
                        fontWeight: isJackpot ? FontWeight.w700 : FontWeight.w600,
                      ),
                      child: Text(message.text),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubic,
                  style: GoogleFonts.poppins(
                    color: isJackpot
                        ? (context.isDark ? const Color(0xFFF59E0B) : const Color(0xFFB45309))
                        : tokens.secondaryTextColor,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w500,
                  ),
                  child: Text(timestampStr),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final timestampStr =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    final seatsList = controller.roomSeatsInfo[widget.roomId] ?? [];
    final senderSeat =
        seatsList.firstWhereOrNull((s) => s['userId'] == message.senderId);
    final bool isSpeaking =
        senderSeat != null && senderSeat['isSpeaking'] == true;

    Widget leftSide;
    if (isConsecutive) {
      leftSide = const SizedBox(width: 44);
    } else {
      leftSide = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showMiniProfile(message.senderId, message.senderName, role: message.senderRole ?? 'Guest'),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          width: 36,
          height: 36,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (isSpeaking)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pinkAccent.withOpacity(0.6),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  ),
                ),
              CircleAvatar(
                radius: 18,
                backgroundImage: message.senderAvatar != null &&
                        message.senderAvatar!.isNotEmpty
                    ? OptimizedImage.getOptimizedImageProvider(
                        message.senderAvatar!,
                        preset: MediaSizePreset.xs,
                      )
                    : const AssetImage('assets/images/placeholder.png')
                        as ImageProvider,
              ),
              if (message.avatarFrame != null &&
                  message.avatarFrame != 'Normal' &&
                  message.avatarFrame!.isNotEmpty)
                Positioned(
                  top: -4,
                  left: -4,
                  right: -4,
                  bottom: -4,
                  child: OptimizedImage(
                    imageUrl: message.avatarFrame!,
                    preset: MediaSizePreset.xs,
                    fit: BoxFit.cover,
                    errorWidget: const SizedBox.shrink(),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black87, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildBadge(String text, Color bg, Color textCol) {
      return Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            color: textCol,
            fontSize: 7.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    Color getRoleColor(String? role) {
      switch (role) {
        case 'Host':
          return const Color(0xFFFF9500);
        case 'Co-Host':
          return const Color(0xFFAF52DE);
        case 'Speaker':
          return const Color(0xFF007AFF);
        default:
          return tokens.secondaryTextColor;
      }
    }

    Widget buildReactions() {
      if (message.reactions.isEmpty) return const SizedBox.shrink();

      final reactionWidgets = <Widget>[];
      message.reactions.forEach((reactionType, usersList) {
        if (usersList.isEmpty) return;

        final hasReacted = usersList.contains(RoomController.currentUserId);
        String emoji = '❤️';
        if (reactionType == 'laugh') emoji = '😂';
        if (reactionType == 'fire') emoji = '🔥';

        reactionWidgets.add(
          GestureDetector(
            onTap: () {
              controller.sendRoomReactionBroadcast(
                  widget.roomId, message.id, reactionType);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasReacted
                    ? Colors.pinkAccent.withOpacity(0.2)
                    : tokens.chatBoxFillColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasReacted
                      ? Colors.pinkAccent.withOpacity(0.5)
                      : tokens.chatBoxBorderColor,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 10)),
                  const SizedBox(width: 3),
                  Text(
                    usersList.length.toString(),
                    style: GoogleFonts.poppins(
                      color: hasReacted
                          ? Colors.pinkAccent
                          : tokens.secondaryTextColor,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      });

      return Container(
        margin: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: reactionWidgets,
        ),
      );
    }

    final currentUid = RoomController.currentUserId;
    final currentUser = UserProfileCacheManager.currentUser;
    final currentUserName = currentUser?.username ?? currentUser?.displayName ?? '';
    final bool isMentionedForMe = message.isMentionedForUser(currentUid, currentUserName);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(top: isConsecutive ? 1 : 4, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leftSide,
            Expanded(
              child: GestureDetector(
                onLongPress: () => _triggerDirectMention(message),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubic,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMentionedForMe
                        ? const Color(0xFF8B5CF6).withOpacity(0.18)
                        : tokens.chatBoxFillColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isMentionedForMe
                          ? const Color(0xFF8B5CF6)
                          : tokens.chatBoxBorderColor,
                      width: isMentionedForMe ? 1.2 : 0.8,
                    ),
                    boxShadow: isMentionedForMe
                        ? [
                            BoxShadow(
                              color: Colors.purpleAccent.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 1,
                            )
                          ]
                        : tokens.seatBoxShadows,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isConsecutive) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _showMiniProfile(
                                  message.senderId,
                                  message.senderName,
                                  role: message.senderRole ?? 'Guest',
                                ),
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeInOutCubic,
                                  style: GoogleFonts.poppins(
                                    color: tokens.primaryTextColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  child: Text(message.senderName),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (isMentionedForMe)
                              buildBadge(
                                  '@ Mentioned',
                                  const Color(0xFF8B5CF6).withOpacity(0.3),
                                  const Color(0xFFA78BFA)),
                            if (message.senderLevel != null)
                              buildBadge(
                                  'Lv.${message.senderLevel}',
                                  Colors.grey.withOpacity(0.24),
                                  Colors.amberAccent),
                            if (message.nobleLabel != null &&
                                message.nobleLabel!.isNotEmpty)
                              buildBadge(
                                  message.nobleLabel!,
                                  const Color(0xFFFFD700).withOpacity(0.2),
                                  const Color(0xFFFFD700)),
                            if (message.vipLabel != null &&
                                message.vipLabel!.isNotEmpty)
                              buildBadge(
                                  message.vipLabel!,
                                  Colors.pinkAccent.withOpacity(0.2),
                                  Colors.pinkAccent),
                            if (message.senderRole != null)
                              buildBadge(
                                  message.senderRole!,
                                  getRoleColor(message.senderRole)
                                      .withOpacity(0.2),
                                  getRoleColor(message.senderRole)),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      RichText(
                        text: TextSpan(
                          children: _parseMentionsAndText(message.text, tokens),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: buildReactions()),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  controller.sendRoomReactionBroadcast(
                                      widget.roomId, message.id, 'heart');
                                },
                                child: Icon(
                                  Icons.favorite_border_rounded,
                                  color: tokens.secondaryIconColor,
                                  size: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeInOutCubic,
                                style: GoogleFonts.poppins(
                                  color: tokens.secondaryTextColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                ),
                                child: Text(timestampStr),
                              ),
                            ],
                          ),
                        ],
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
  }

  List<InlineSpan> _parseMentionsAndText(
      String text, AdaptiveSeatThemeTokens tokens) {
    final List<InlineSpan> spans = [];
    final RegExp exp = RegExp(r'(@[\w\.-]+)');
    final Iterable<RegExpMatch> matches = exp.allMatches(text);

    if (matches.isEmpty) {
      spans.add(
        TextSpan(
          text: text,
          style: GoogleFonts.poppins(
            color: tokens.primaryTextColor,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
      return spans;
    }

    int start = 0;
    for (final RegExpMatch match in matches) {
      if (match.start > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, match.start),
            style: GoogleFonts.poppins(
              color: tokens.primaryTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        );
      }
      final String mentionToken = match.group(0) ?? '';
      final String rawUsername = mentionToken.replaceFirst('@', '');

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () {
              final cachedUser = UserProfileCacheManager.rxCache.values
                  .firstWhereOrNull((u) =>
                      u.displayName.toLowerCase() == rawUsername.toLowerCase() ||
                      u.username.toLowerCase() == rawUsername.toLowerCase());
              if (cachedUser != null) {
                _showMiniProfile(cachedUser.id, cachedUser.username);
              }
            },
            child: Text(
              mentionToken,
              style: GoogleFonts.poppins(
                color: Colors.amberAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
      start = match.end;
    }

    if (start < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(start),
          style: GoogleFonts.poppins(
            color: tokens.primaryTextColor,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }
    return spans;
  }
}
