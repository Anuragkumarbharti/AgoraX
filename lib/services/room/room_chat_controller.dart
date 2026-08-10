import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/room/room_activity_event.dart';
import '../user/user_profile_cache_manager.dart';
import 'room_realtime_controller.dart';
import 'room_seat_controller.dart';


class RoomChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String? senderRole;
  final String? senderAvatar;
  final DateTime timestamp;
  final bool isSystem;
  final String messageType;
  final String? replyToMessageId;
  final String? senderLevel;
  final String? vipLabel;
  final String? novelLabel;
  final String? communityTag;
  final String? roleTag;
  final bool isActiveSpeaker;
  final int repeatCount;
  final String? eventType;
  final Map<String, List<String>> reactions;
  final String? avatarFrame;
  final String? nobleLabel;
  final String status;
  final String? mentionedUserId;
  final List<String> mentionedUserIds;

  RoomChatMessage({
    String? id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.senderRole,
    this.senderAvatar,
    required this.timestamp,
    this.isSystem = false,
    this.messageType = 'chat',
    this.replyToMessageId,
    this.senderLevel,
    this.vipLabel,
    this.novelLabel,
    this.communityTag,
    this.roleTag,
    this.isActiveSpeaker = false,
    this.repeatCount = 1,
    this.eventType,
    Map<String, List<String>>? reactions,
    this.avatarFrame,
    this.nobleLabel,
    this.status = 'sent',
    this.mentionedUserId,
    List<String>? mentionedUserIds,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        reactions = reactions ?? {},
        mentionedUserIds = mentionedUserIds ?? [];

  bool isMentionedForUser(String userId, String userName) {
    if (mentionedUserIds.contains(userId)) return true;
    if (mentionedUserId == userId) return true;
    if (userName.isNotEmpty && text.contains('@$userName')) return true;
    return false;
  }

  RoomChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? text,
    String? senderRole,
    String? senderAvatar,
    DateTime? timestamp,
    bool? isSystem,
    String? messageType,
    String? replyToMessageId,
    String? senderLevel,
    String? vipLabel,
    String? novelLabel,
    String? communityTag,
    String? roleTag,
    bool? isActiveSpeaker,
    int? repeatCount,
    String? eventType,
    Map<String, List<String>>? reactions,
    String? avatarFrame,
    String? nobleLabel,
    String? status,
    String? mentionedUserId,
    List<String>? mentionedUserIds,
  }) {
    return RoomChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      senderRole: senderRole ?? this.senderRole,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      timestamp: timestamp ?? this.timestamp,
      isSystem: isSystem ?? this.isSystem,
      messageType: messageType ?? this.messageType,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      senderLevel: senderLevel ?? this.senderLevel,
      vipLabel: vipLabel ?? this.vipLabel,
      novelLabel: novelLabel ?? this.novelLabel,
      communityTag: communityTag ?? this.communityTag,
      roleTag: roleTag ?? this.roleTag,
      isActiveSpeaker: isActiveSpeaker ?? this.isActiveSpeaker,
      repeatCount: repeatCount ?? this.repeatCount,
      eventType: eventType ?? this.eventType,
      reactions: reactions ?? this.reactions,
      avatarFrame: avatarFrame ?? this.avatarFrame,
      nobleLabel: nobleLabel ?? this.nobleLabel,
      status: status ?? this.status,
      mentionedUserId: mentionedUserId ?? this.mentionedUserId,
      mentionedUserIds: mentionedUserIds ?? this.mentionedUserIds,
    );
  }
}

class RoomChatController extends GetxController {
  static RoomChatController get to => Get.find<RoomChatController>();

  final RxMap<String, RxList<RoomChatMessage>> roomChats =
      <String, RxList<RoomChatMessage>>{}.obs;
  final RxList<String> typingUsers = <String>[].obs;
  final RxList<String> bottomSystemNotifications = <String>[].obs;
  final RxnString activeSystemNotification = RxnString();

  void initializeChatForRoom(String roomId) {
    if (!roomChats.containsKey(roomId)) {
      roomChats[roomId] = <RoomChatMessage>[].obs;
    }
  }

  void addChatMessage(String roomId, RoomChatMessage message) {
    initializeChatForRoom(roomId);
    final messages = roomChats[roomId]!;

    if (message.isSystem && messages.isNotEmpty) {
      final last = messages.last;
      if (last.isSystem) {
        final bool isEntry = message.text.contains('entered the room');
        final bool isLeave = message.text.contains('left the room');
        final bool wasEntry = last.text.contains('entered the room');
        final bool wasLeave = last.text.contains('left the room');

        if ((isEntry && wasEntry) || (isLeave && wasLeave)) {
          final String keyword =
              isEntry ? ' entered the room.' : ' left the room.';
          final String emoji = isEntry ? '🟢 ' : '👋 ';

          final lastClean =
              last.text.replaceFirst(emoji, '').replaceFirst(keyword, '');
          final newClean =
              message.text.replaceFirst(emoji, '').replaceFirst(keyword, '');

          final Set<String> names = lastClean.split(', ').toSet();
          if (!names.contains(newClean)) {
            names.add(newClean);
            final updatedText = '$emoji${names.join(', ')}$keyword';
            messages[messages.length - 1] = last.copyWith(
                text: updatedText, repeatCount: last.repeatCount + 1);
            return;
          } else {
            messages[messages.length - 1] =
                last.copyWith(repeatCount: last.repeatCount + 1);
            return;
          }
        }

        if (message.text.startsWith('🎁') && last.text.startsWith('🎁')) {
          final giftRegex =
              RegExp(r'^🎁\s+(.*?)\s+sent\s+(.*?)\s+×\s+(\d+)\s+to\s+(.*?)\.$');
          final matchLast = giftRegex.firstMatch(last.text);
          final matchNew = giftRegex.firstMatch(message.text);

          if (matchLast != null && matchNew != null) {
            final senderLast = matchLast.group(1);
            final giftLast = matchLast.group(2);
            final countLast = int.tryParse(matchLast.group(3) ?? '1') ?? 1;
            final receiverLast = matchLast.group(4);

            final senderNew = matchNew.group(1);
            final giftNew = matchNew.group(2);
            final countNew = int.tryParse(matchNew.group(3) ?? '1') ?? 1;
            final receiverNew = matchNew.group(4);

            if (senderLast == senderNew &&
                giftLast == giftNew &&
                receiverLast == receiverNew) {
              final totalCount = countLast + countNew;
              final updatedText =
                  '🎁 $senderNew sent $giftNew × $totalCount to $receiverNew.';
              messages[messages.length - 1] = last.copyWith(text: updatedText);
              return;
            }
          }
        }
      }
    }

    messages.add(message);
  }

  final Set<String> _processedLuckyTxIds = {};
  final Set<String> _processedEventIds = {};

  bool addSystemActivityWithDeduplication({
    required String roomId,
    required String eventId,
    required String text,
    String? senderId = 'system',
    String? senderName = 'System',
    String? senderAvatar,
    String? messageType = 'activity',
    String? activityKey,
  }) {
    if (eventId.isNotEmpty) {
      if (_processedEventIds.contains(eventId)) {
        debugPrint('[RoomChatController] Blocked duplicate activity eventId: $eventId');
        return false;
      }
      _processedEventIds.add(eventId);
      if (_processedEventIds.length > 1000) {
        _processedEventIds.clear();
      }
    }

    addSystemActivity(
      roomId,
      text,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      messageType: messageType,
      activityKey: activityKey,
      eventType: activityKey,
      id: eventId.isNotEmpty ? eventId : null,
    );
    return true;
  }

  /// Adds exactly ONE room entry system message per user session: "[Username] has entered the room".
  bool addRoomEntrySystemMessage(String roomId, String userId, String userName) {
    if (roomId.isEmpty || userId.isEmpty) return false;
    final eventId = 'entry_${roomId}_$userId';
    final text = '$userName has entered the room';
    return addSystemActivityWithDeduplication(
      roomId: roomId,
      eventId: eventId,
      text: text,
      senderId: userId,
      senderName: userName,
      messageType: 'activity',
      activityKey: 'room_join',
    );
  }

  /// Adds exactly ONE seat action system message for confirmed seat events:
  /// "[Username] took Seat 3" or "[Username] left Seat 3".
  bool addSeatActionSystemMessage({
    required String roomId,
    required String userId,
    required String userName,
    required String action, // 'take' or 'leave'
    required int seatIndex,
    String? customSeatName,
  }) {
    if (roomId.isEmpty || userId.isEmpty) return false;
    final seatLabel = customSeatName ?? 'Seat ${seatIndex + 1}';
    final text = action == 'take'
        ? '$userName took $seatLabel'
        : '$userName left $seatLabel';
    final eventId = 'seat_${action}_${roomId}_${seatIndex}_${userId}_${DateTime.now().millisecondsSinceEpoch ~/ 3000}';
    final eventType = action == 'take' ? 'seat_taken' : 'seat_left';

    return addSystemActivityWithDeduplication(
      roomId: roomId,
      eventId: eventId,
      text: text,
      senderId: userId,
      senderName: userName,
      messageType: 'activity',
      activityKey: eventType,
    );
  }

  bool addLuckyGiftMessage(String roomId, Map<String, dynamic> luckyResult) {
    try {
      if (luckyResult['is_lucky_gift'] != true) return false;
      final int cashbackGold = ((luckyResult['cashback_gold'] ?? luckyResult['coins_back'] ?? 0) as num).toInt();

      // Suppress 0 Coin Back messages completely
      if (cashbackGold <= 0) {
        debugPrint('[RoomChatController] 0 Coin Back message suppressed.');
        return false;
      }

      final String txId = (luckyResult['transaction_id'] ?? luckyResult['tx_id'] ?? '').toString();
      if (txId.isNotEmpty && _processedLuckyTxIds.contains(txId)) {
        debugPrint('[RoomChatController] Duplicate lucky gift message blocked for transaction: $txId');
        return false;
      }

      if (txId.isNotEmpty) {
        _processedLuckyTxIds.add(txId);
      }

      final String senderName = (luckyResult['sender_name'] ?? 'User').toString();
      final num multNum = luckyResult['multiplier'] ?? 0;
      final String tier = (luckyResult['tier'] ?? 'no_reward').toString();
      final String eventType = tier == 'jackpot' ? 'lucky_jackpot' : ArenaEventTypes.luckyCoinWon;
      final String canonicalLuckyMsg = ArenaEventFormatter.formatLuckyCoinWinMessage(senderName, cashbackGold);
      final String eventId = txId.isNotEmpty ? 'lucky-$txId' : 'lucky-${DateTime.now().microsecondsSinceEpoch}';

      // 1. Add Chat Box Message with deduplication
      initializeChatForRoom(roomId);
      if (!addSystemActivityWithDeduplication(
        roomId: roomId,
        eventId: eventId,
        text: canonicalLuckyMsg,
        senderId: 'system_lucky',
        senderName: 'Lucky Draw 🎰',
        messageType: 'activity',
        activityKey: eventType,
      )) {
        return false;
      }

      // 2. Trigger Top Floating Notification Pill for everyone in the room
      activeSystemNotification.value = '🎰 $senderName won $cashbackGold Gold back (${multNum}×)!';

      return true;
    } catch (e) {
      debugPrint('[RoomChatController] Error adding lucky gift message: $e');
      return false;
    }
  }

  void addSystemActivity(
    String roomId,
    String text, {
    String? senderId = 'system',
    String? senderName = 'System',
    String? senderAvatar,
    String? messageType = 'activity',
    String? activityKey,
    String? eventType,
    String? id,
  }) {
    initializeChatForRoom(roomId);
    final msg = RoomChatMessage(
      id: id,
      senderId: senderId ?? 'system',
      senderName: senderName ?? 'System',
      text: text,
      senderAvatar: senderAvatar,
      timestamp: DateTime.now(),
      isSystem: true,
      messageType: messageType ?? 'activity',
      roleTag: activityKey,
      eventType: eventType ?? activityKey,
    );
    addChatMessage(roomId, msg);
  }

  Future<void> deleteRoomMessage(String roomId, String messageId) async {
    try {
      if (Get.isRegistered<RoomRealtimeController>()) {
        await RoomRealtimeController.to.roomMessagesChannel?.sendBroadcastMessage(
          event: 'delete_message',
          payload: {'message_id': messageId},
        );
      }
      roomChats[roomId]?.removeWhere((msg) => msg.id == messageId);
    } catch (e) {
      debugPrint('Error deleting room message: $e');
    }
  }

  void emitRoomActivity(String roomId, String text, {String? activityKey}) {
    addSystemActivity(roomId, text, activityKey: activityKey);
  }

  Future<void> sendRoomMessage(
    String roomId,
    String text, {
    String? senderId,
    String? senderName,
    String? senderRole,
    String? senderAvatar,
    String? replyToMessageId,
    String? senderLevel,
    String? vipLabel,
    String? novelLabel,
    String? communityTag,
    String? roleTag,
    bool isActiveSpeaker = false,
  }) async {
    try {
      final uid = senderId ?? UserProfileCacheManager.currentUserId;
      final msgId = DateTime.now().microsecondsSinceEpoch.toString();

      final u = UserProfileCacheManager.rxCache[uid];
      final avatarFrame = u?.avatarFrame;

      final payload = {
        'id': msgId,
        'sender_id': uid,
        'sender_name': senderName ?? 'Creaniaa Student',
        'text': text,
        'sender_role': senderRole ?? 'Listener',
        'sender_avatar': senderAvatar,
        'timestamp': DateTime.now().toIso8601String(),
        'sender_level': senderLevel ?? '1',
        'vip_label': vipLabel,
        'novel_label': novelLabel,
        'community_tag': communityTag,
        'role_tag': roleTag,
        'is_active_speaker': isActiveSpeaker,
        'reply_to_message_id': replyToMessageId,
        'avatar_frame': avatarFrame,
      };

      final localMessage = RoomChatMessage(
        id: msgId,
        senderId: uid,
        senderName: senderName ?? 'Creaniaa Student',
        text: text,
        senderRole: senderRole ?? 'Listener',
        senderAvatar: senderAvatar,
        timestamp: DateTime.now(),
        replyToMessageId: replyToMessageId,
        senderLevel: senderLevel ?? '1',
        vipLabel: vipLabel,
        novelLabel: novelLabel,
        communityTag: communityTag,
        roleTag: roleTag,
        isActiveSpeaker: isActiveSpeaker,
        avatarFrame: avatarFrame,
      );

      if (roomChats[roomId] == null) {
        roomChats[roomId] = <RoomChatMessage>[].obs;
      }
      if (!roomChats[roomId]!.any((m) => m.id == msgId)) {
        roomChats[roomId]!.add(localMessage);
      }

      try {
        await Supabase.instance.client.rpc('send_room_chat_message', params: {
          'p_room_id': roomId,
          'p_content': text,
          'p_message_type': 'text',
          'p_metadata': payload,
        });
      } catch (rpcErr) {
        debugPrint('[RoomChatController] RPC send_room_chat_message error: $rpcErr');
      }

      if (Get.isRegistered<RoomRealtimeController>()) {
        await RoomRealtimeController.to.roomMessagesChannel?.sendBroadcastMessage(
          event: 'chat_message',
          payload: payload,
        );
      }
    } catch (e) {
      debugPrint('Error sending broadcast room message: $e');
    }
  }

  Future<void> sendRoomBroadcastMessage(
    String roomId,
    String text, {
    required List<Map<String, dynamic>>? seatsList,
  }) async {
    try {
      final currentUserId = UserProfileCacheManager.currentUserId;
      final profile =
          await UserProfileCacheManager.fetchUserProfile(currentUserId);
      final uName = profile?.username ?? 'Creaniaa Student';

      final seats = seatsList ?? [];
      final mySeat =
          seats.firstWhereOrNull((s) => s['userId'] == currentUserId);
      String role = 'Audience';
      if (mySeat != null) {
        final seatIndex = mySeat['seatIndex'] as int;
        role = RoomSeatController.getSeatName(seatIndex);
      }

      String? equippedFrame;
      try {
        final custResponse = await Supabase.instance.client
            .from('user_customizations')
            .select('name, type')
            .eq('user_id', currentUserId)
            .eq('is_equipped', true);
        if (custResponse != null) {
          for (final item in custResponse) {
            if (item['type'] == 'avatar_frame') {
              equippedFrame = item['name'] as String?;
            }
          }
        }
      } catch (_) {}

      List<String> mentionedUserIds = [];
      try {
        final regExp = RegExp(r'@([\w\.-]+)');
        final matches = regExp.allMatches(text);
        for (final match in matches) {
          final nameToken = match.group(1);
          if (nameToken != null && nameToken.isNotEmpty) {
            final cachedUser = UserProfileCacheManager.rxCache.values
                .firstWhereOrNull((u) =>
                    u.displayName.toLowerCase() == nameToken.toLowerCase() ||
                    u.username.toLowerCase() == nameToken.toLowerCase());
            if (cachedUser != null &&
                !mentionedUserIds.contains(cachedUser.id)) {
              mentionedUserIds.add(cachedUser.id);
            }
          }
        }
      } catch (_) {}

      final payload = {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'sender_id': currentUserId,
        'sender_name': uName,
        'text': text,
        'sender_role': role,
        'sender_avatar': profile?.avatar,
        'timestamp': DateTime.now().toIso8601String(),
        'sender_level': profile?.level?.toString() ?? '1',
        'vip_label':
            (profile?.vipLevel ?? 0) > 0 ? 'VIP ${profile?.vipLevel}' : null,
        'novel_label': (profile?.novelLevel ?? 0) > 0
            ? 'Novel ${profile?.novelLevel}'
            : null,
        'avatar_frame': equippedFrame,
        'noble_label':
            (profile?.vipLevel ?? 0) > 0 ? 'Noble ${profile?.vipLevel}' : null,
        'mentioned_user_ids': mentionedUserIds,
      };

      final localMessage = RoomChatMessage(
        id: payload['id'] as String,
        senderId: currentUserId,
        senderName: uName,
        text: text,
        senderRole: role,
        senderAvatar: profile?.avatar,
        timestamp: DateTime.now(),
        senderLevel: payload['sender_level']?.toString(),
        vipLabel: payload['vip_label']?.toString(),
        novelLabel: payload['novel_label']?.toString(),
        avatarFrame: equippedFrame,
        nobleLabel: payload['noble_label']?.toString(),
        mentionedUserIds: mentionedUserIds,
      );

      if (roomChats[roomId] == null) {
        roomChats[roomId] = <RoomChatMessage>[].obs;
      }
      roomChats[roomId]!.add(localMessage);

      if (Get.isRegistered<RoomRealtimeController>()) {
        await RoomRealtimeController.to.roomMessagesChannel?.sendBroadcastMessage(
          event: 'chat_message',
          payload: payload,
        );
      }
    } catch (e) {
      debugPrint('Error sending broadcast message: $e');
    }
  }

  Future<void> sendRoomReactionBroadcast(
    String roomId,
    String messageId,
    String reactionType,
  ) async {
    try {
      final currentUserId = UserProfileCacheManager.currentUserId;
      final payload = {
        'message_id': messageId,
        'reaction_type': reactionType,
        'user_id': currentUserId,
      };

      final chatList = roomChats[roomId];
      if (chatList != null) {
        final idx = chatList.indexWhere((msg) => msg.id == messageId);
        if (idx != -1) {
          final msg = chatList[idx];
          final currentReactions =
              Map<String, List<String>>.from(msg.reactions);
          if (currentReactions[reactionType] == null) {
            currentReactions[reactionType] = [];
          }
          if (!currentReactions[reactionType]!.contains(currentUserId)) {
            currentReactions[reactionType]!.add(currentUserId);
          } else {
            currentReactions[reactionType]!.remove(currentUserId);
          }
          chatList[idx] = msg.copyWith(reactions: currentReactions);
        }
      }

      if (Get.isRegistered<RoomRealtimeController>()) {
        await RoomRealtimeController.to.roomMessagesChannel?.sendBroadcastMessage(
          event: 'message_reaction',
          payload: payload,
        );
      }
    } catch (e) {
      debugPrint('Error sending reaction broadcast: $e');
    }
  }

  Future<void> setTypingStatus(String roomId, bool isTyping) async {
    try {
      final username =
          UserProfileCacheManager.currentUser?.username ?? 'Creaniaa Student';
      if (Get.isRegistered<RoomRealtimeController>()) {
        await RoomRealtimeController.to.roomMessagesChannel?.sendBroadcastMessage(
          event: 'typing_status',
          payload: {
            'username': username,
            'is_typing': isTyping,
          },
        );
      }
    } catch (e) {
      debugPrint('Error broadcasting typing status: $e');
    }
  }

  Future<void> fetchRoomChatMessages(String roomId) async {
    try {
      initializeChatForRoom(roomId);
      final response = await Supabase.instance.client
          .from('room_messages')
          .select()
          .eq('room_id', roomId)
          .order('created_at', ascending: true)
          .limit(100);

      final List<RoomChatMessage> fetched = [];
      for (final map in response) {
        final meta = map['metadata'] != null && map['metadata'] is Map
            ? Map<String, dynamic>.from(map['metadata'] as Map)
            : <String, dynamic>{};

        fetched.add(RoomChatMessage(
          id: map['id'].toString(),
          senderId: map['sender_id']?.toString() ?? '',
          senderName: meta['sender_name'] ?? 'Member',
          text: map['content'] ?? '',
          senderRole: meta['sender_role'] ?? 'Listener',
          senderAvatar: meta['sender_avatar'],
          timestamp: map['created_at'] != null
              ? DateTime.parse(map['created_at'])
              : DateTime.now(),
          senderLevel: meta['sender_level']?.toString() ?? '1',
          vipLabel: meta['vip_label'],
          novelLabel: meta['novel_label'],
          communityTag: meta['community_tag'],
          roleTag: meta['role_tag'],
          avatarFrame: meta['avatar_frame'],
        ));
      }

      final chatList = roomChats[roomId]!;
      for (final msg in fetched) {
        if (!chatList.any((m) => m.id == msg.id)) {
          chatList.add(msg);
        }
      }
    } catch (e) {
      debugPrint('Error fetching room chat messages: $e');
    }
  }

  void addSystemNotification(String notificationText) {
    if (notificationText.isEmpty) return;
    bottomSystemNotifications.add(notificationText);
    if (activeSystemNotification.value == null) {
      _showNextSystemNotification();
    }
  }

  void _showNextSystemNotification() {
    if (bottomSystemNotifications.isEmpty) {
      activeSystemNotification.value = null;
      return;
    }
    activeSystemNotification.value = bottomSystemNotifications.removeAt(0);
    Timer(const Duration(seconds: 4), () {
      _showNextSystemNotification();
    });
  }
}
