import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme.dart';
import '../../../../models/chat/chat_model.dart';
import '../../../../services/room/room_controller.dart';
import '../../../../services/user/user_profile_cache_manager.dart';
import '../../../../services/voice/voice_controller.dart';
import '../dialogs/mini_profile_dialog.dart';

class RoomCallChatBox extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final RoomController controller = RoomController.to;

    return Obx(() {
      final chatsMap = controller.roomChats;
      final _ = chatsMap.length; // Force GetX to observe roomChats map changes
      final messages = chatsMap[roomId] ?? <RoomChatMessage>[];
      return ListView.builder(
        controller: chatScrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 64),
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
    });
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
      Color eventColor = const Color(0xFF2196F3);
      IconData icon = Icons.notifications_rounded;

      final type = message.eventType ?? '';
      bool isJackpot = type == 'lucky_jackpot';
      bool isLuckyWin = type == 'lucky_win' || isJackpot;

      if (type == 'room_join') {
        eventColor = const Color(0xFF34C759);
        icon = Icons.login_rounded;
      } else if (type == 'room_leave') {
        eventColor = const Color(0xFFFF3B30);
        icon = Icons.logout_rounded;
      } else if (type.startsWith('seat_')) {
        eventColor = const Color(0xFF007AFF);
        icon = Icons.chair_rounded;
      } else if (type == 'gift_sent') {
        eventColor = const Color(0xFFAF52DE);
        icon = Icons.card_giftcard_rounded;
      } else if (isJackpot) {
        eventColor = const Color(0xFFF59E0B);
        icon = Icons.stars_rounded;
      } else if (isLuckyWin) {
        eventColor = const Color(0xFF8B5CF6);
        icon = Icons.casino_rounded;
      } else if (type == 'achievement') {
        eventColor = const Color(0xFFFFCC00);
        icon = Icons.emoji_events_rounded;
      } else if (type == 'room_level_up') {
        eventColor = const Color(0xFFFF9500);
        icon = Icons.trending_up_rounded;
      } else if (type == 'room_banner_changed') {
        eventColor = const Color(0xFFFF2D55);
        icon = Icons.image_rounded;
      }

      final timestampStr =
          '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

      return Align(
        alignment: Alignment.centerLeft,
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
      );
    }

    final timestampStr =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    final seatsList = controller.roomSeatsInfo[roomId] ?? [];
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
        onTap: () {
          final occupiedSeats = (controller.roomSeatsInfo[roomId] ?? [])
              .where((s) => s['userId'] != null)
              .length;
          Get.dialog(
            MiniProfileDialog(
              roomId: roomId,
              callerUserId: RoomController.currentUserId,
              targetUserId: message.senderId,
              targetUserName: message.senderName,
              role: message.senderRole ?? 'Guest',
              seatIndex: -1,
              isHost: (() {
                final room =
                    controller.rooms.firstWhereOrNull((r) => r.id == roomId);
                return room?.hostId == RoomController.currentUserId ||
                    room?.founderId == RoomController.currentUserId;
              })(),
              occupiedSeatsCount: occupiedSeats,
            ),
          );
        },
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
                    ? NetworkImage(message.senderAvatar!)
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
                  child: Image.network(
                    message.avatarFrame!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
                  roomId, message.id, reactionType);
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
                onLongPress: () {
                  Get.bottomSheet(
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141724),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
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
                          ListTile(
                            leading: const Icon(Icons.alternate_email_rounded,
                                color: Color(0xFFA78BFA)),
                            title: Text(
                              'Mention ${message.senderName}',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Add @${message.senderName} to chat field',
                              style: GoogleFonts.poppins(
                                  color: Colors.white60, fontSize: 11),
                            ),
                            onTap: () {
                              Get.back();
                              controller.mentionUserInRoomChat(message.senderName);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
                                onTap: () {
                                  final occupiedSeats =
                                      (controller.roomSeatsInfo[roomId] ?? [])
                                          .where((s) => s['userId'] != null)
                                          .length;
                                  Get.dialog(
                                    MiniProfileDialog(
                                      roomId: roomId,
                                      callerUserId: RoomController.currentUserId,
                                      targetUserId: message.senderId,
                                      targetUserName: message.senderName,
                                      role: message.senderRole ?? 'Guest',
                                      seatIndex: -1,
                                      isHost: (() {
                                        final room = controller.rooms
                                            .firstWhereOrNull(
                                                (r) => r.id == roomId);
                                        return room?.hostId ==
                                                RoomController.currentUserId ||
                                            room?.founderId ==
                                                RoomController.currentUserId;
                                      })(),
                                      occupiedSeatsCount: occupiedSeats,
                                    ),
                                  );
                                },
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
                                    roomId, message.id, 'heart');
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
    final RegExp exp = RegExp(r'(@[a-zA-Z0-9_\u00a1-\uffff]+)');
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
      spans.add(
        TextSpan(
          text: match.group(0),
          style: GoogleFonts.poppins(
            color: Colors.amberAccent,
            fontSize: 11,
            fontWeight: FontWeight.bold,
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

  static Widget buildDefaultAvatar(String name, Color color) {
    return Container(
      color: color.withOpacity(0.2),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
