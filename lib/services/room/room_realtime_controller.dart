import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/room/room_background_model.dart';
import '../../widgets/room/role_update_popup_dialog.dart';
import '../user/user_profile_cache_manager.dart';
import 'room_chat_controller.dart';
import 'room_activity_controller.dart';
import 'room_background_controller.dart';
import '../gifting/gift_animation_controller.dart';
import 'room_seat_controller.dart';
import 'room_connection_controller.dart';
import 'room_controller.dart';
import 'room_progression_controller.dart';
import 'room_gift_controller.dart';
import '../gifting/gift_event_service.dart';

class RoomRealtimeController extends GetxController {
  static RoomRealtimeController get to {
    if (!Get.isRegistered<RoomRealtimeController>()) {
      return Get.put(RoomRealtimeController());
    }
    return Get.find<RoomRealtimeController>();
  }

  RealtimeChannel? _roomsListChannel;
  RealtimeChannel? _roomMembersChannel;
  RealtimeChannel? _roomMessagesChannel;
  RealtimeChannel? _roomRequestsChannel;
  RealtimeChannel? _roomPollsChannel;
  RealtimeChannel? _roomProgressionChannel;
  RealtimeChannel? _roomActivityEventsChannel;

  RealtimeChannel? get roomMessagesChannel => _roomMessagesChannel;
  RealtimeChannel? get roomMembersChannel => _roomMembersChannel;
  RealtimeChannel? get roomActivityEventsChannel => _roomActivityEventsChannel;

  Future<void> broadcastRoleUpdate({
    required String roomId,
    required String roomName,
    required String targetUserId,
    required String targetUserName,
    required String action,
    required String newRole,
    String? oldRole,
    String? reason,
  }) async {
    try {
      if (_roomMembersChannel != null) {
        await _roomMembersChannel?.sendBroadcastMessage(
          event: 'role_event',
          payload: {
            'room_id': roomId,
            'room_name': roomName,
            'target_user_id': targetUserId,
            'target_user_name': targetUserName,
            'action': action,
            'new_role': newRole,
            'old_role': oldRole,
            'reason': reason,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e) {
      debugPrint('[RoomRealtimeController] Error broadcasting role update: $e');
    }
  }

  Future<void> broadcastKickEviction({
    required String roomId,
    required String targetUserId,
  }) async {
    try {
      if (_roomMembersChannel != null) {
        await _roomMembersChannel?.sendBroadcastMessage(
          event: 'kick_event',
          payload: {
            'room_id': roomId,
            'target_user_id': targetUserId,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e) {
      debugPrint('[RoomRealtimeController] Error broadcasting kick eviction: $e');
    }
  }

  Future<void> broadcastBanEviction({
    required String roomId,
    required String targetUserId,
    String? reason,
  }) async {
    try {
      if (_roomMembersChannel != null) {
        await _roomMembersChannel?.sendBroadcastMessage(
          event: 'ban_event',
          payload: {
            'room_id': roomId,
            'target_user_id': targetUserId,
            'reason': reason,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e) {
      debugPrint('[RoomRealtimeController] Error broadcasting ban eviction: $e');
    }
  }

  /// Broadcasts one Realtime GiftSent event to everyone in the room.
  Future<void> broadcastGiftSentEvent(String roomId, Map<String, dynamic> eventPayload) async {
    try {
      if (_roomActivityEventsChannel != null) {
        await _roomActivityEventsChannel?.sendBroadcastMessage(
          event: 'gift_sent_event',
          payload: eventPayload,
        );
      } else {
        // Fallback channel if main subscription is initializing
        final fallbackChannel = Supabase.instance.client.channel('room_activity_events:$roomId');
        await fallbackChannel.subscribe();
        await fallbackChannel.sendBroadcastMessage(
          event: 'gift_sent_event',
          payload: eventPayload,
        );
      }
    } catch (e) {
      debugPrint('[GiftPipeline] Error broadcasting gift event: $e');
    }
  }

  void subscribeToRoomsList(Function() onFetchRooms) {
    if (_roomsListChannel != null) return;
    try {
      _roomsListChannel = Supabase.instance.client
          .channel('public:rooms_list')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'rooms',
            callback: (payload) {
              debugPrint('[RoomRealtimeController] Realtime rooms table change: ${payload.eventType}');
              onFetchRooms();
            },
          );
      _roomsListChannel?.subscribe();
      debugPrint('[RoomRealtimeController] Subscribed to rooms table changes.');
    } catch (e) {
      debugPrint('[RoomRealtimeController] Error subscribing to rooms list: $e');
    }
  }

  void subscribeToRoomRealtime(
    String roomId, {
    required String? activeRoomId,
    required Future<void> Function(String) onFetchMembers,
    required Future<void> Function(String) onFetchPermissions,
    required Future<void> Function(String) onFetchRequests,
    required Future<void> Function(String) onFetchPolls,
    required Future<void> Function(String) onFetchProgression,
    required Function() onCleanupResources,
  }) {
    unsubscribeRoomRealtime();

    try {
      final client = Supabase.instance.client;
      final currentUserId = UserProfileCacheManager.currentUserId;

      _roomMembersChannel = client
          .channel('room_members:$roomId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_members',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) async {
              if (payload.eventType == PostgresChangeEvent.insert && Get.isRegistered<RoomActivityController>()) {
                final newRecord = payload.newRecord;
                final String? uId = newRecord?['user_id'];
                if (uId != null && uId != currentUserId) {
                  final activityCtrl = RoomActivityController.to;
                  activityCtrl.animatingJoinUserIds.add(uId);
                  final profile =
                      await UserProfileCacheManager.fetchUserProfile(uId);
                  final String uName = profile?.username ?? 'Creaniaa Student';
                  final String? uAvatar = profile?.avatar;
                  try {
                    final custResponse = await Supabase.instance.client
                        .from('user_customizations')
                        .select('name')
                        .eq('user_id', uId)
                        .eq('type', 'entry_effect')
                        .eq('is_equipped', true)
                        .maybeSingle();
                    final String? entryEffect =
                        custResponse != null ? custResponse['name'] : null;
                    activityCtrl.entranceEvent.value = {
                      'userId': uId,
                      'userName': uName,
                      'avatarUrl': uAvatar,
                      'entryEffect': entryEffect,
                      'timestamp': DateTime.now().millisecondsSinceEpoch,
                    };
                  } catch (_) {
                    activityCtrl.entranceEvent.value = {
                      'userId': uId,
                      'userName': uName,
                      'avatarUrl': uAvatar,
                      'entryEffect': null,
                      'timestamp': DateTime.now().millisecondsSinceEpoch,
                    };
                  }
                }
              }
              await onFetchMembers(roomId);
              await onFetchPermissions(roomId);
            },
          )
          .onBroadcast(
            event: 'role_event',
            callback: (payload) async {
              final String? tUserId = payload['target_user_id']?.toString();
              final String tUserName =
                  payload['target_user_name']?.toString() ?? 'Member';
              final String action = payload['action']?.toString() ?? 'PROMOTED';
              final String newRole = payload['new_role']?.toString() ?? 'Admin';
              final String? oldRole = payload['old_role']?.toString();
              final String roomName =
                  payload['room_name']?.toString() ?? 'Voice Room';
              final String? reason = payload['reason']?.toString();

              if (Get.isRegistered<RoomChatController>()) {
                final chatCtrl = RoomChatController.to;
                final notificationText = action == 'PROMOTED'
                    ? '🛡 $tUserName has been promoted to $newRole.'
                    : '🛡 $tUserName is no longer an ${oldRole ?? "Admin"}.';
                chatCtrl.addChatMessage(
                  roomId,
                  RoomChatMessage(
                    senderId: 'system',
                    senderName: 'System',
                    text: notificationText,
                    timestamp: DateTime.now(),
                    isSystem: true,
                    messageType: 'activity',
                    eventType: 'role_update',
                  ),
                );
              }

              // Re-fetch members and permissions for EVERY user in the room to update tags & roles instantly
              await onFetchMembers(roomId);
              await onFetchPermissions(roomId);

              if (tUserId == currentUserId) {
                await UserProfileCacheManager.rebuildAndSyncCurrentUserTagSystem();

                if (action == 'PROMOTED') {
                  RoleUpdatePopupDialog.showRoleAssigned(
                    roleName: newRole,
                    roomName: roomName,
                  );
                } else {
                  RoleUpdatePopupDialog.showRoleRemoved(
                    oldRoleName: oldRole ?? 'Admin',
                    roomName: roomName,
                    reason: reason,
                  );
                }
              }
            },
          )
          .onBroadcast(
            event: 'kick_event',
            callback: (payload) {
              final String? tUserId = payload['target_user_id']?.toString();
              if (tUserId == currentUserId) {
                if (Get.isRegistered<RoomConnectionController>()) {
                  RoomConnectionController.to.exitRoom(roomId);
                }
                Get.snackbar(
                  'Kicked Out 🥾',
                  'You have been removed from the room by a moderator.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: const Color(0xFFEF4444),
                  colorText: Colors.white,
                  duration: const Duration(seconds: 4),
                );
              }
            },
          )
          .onBroadcast(
            event: 'ban_event',
            callback: (payload) {
              final String? tUserId = payload['target_user_id']?.toString();
              final String? reason = payload['reason']?.toString();
              if (tUserId == currentUserId) {
                if (Get.isRegistered<RoomConnectionController>()) {
                  RoomConnectionController.to.exitRoom(roomId);
                }
                Get.snackbar(
                  'Banned 🚫',
                  reason != null && reason.isNotEmpty
                      ? 'You have been banned from this room: $reason'
                      : 'You have been banned from this room by a moderator.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: const Color(0xFFDC2626),
                  colorText: Colors.white,
                  duration: const Duration(seconds: 4),
                );
              }
            },
          );

      Timer? reconnectTimer;

      _roomMembersChannel?.subscribe((status, [error]) {
        debugPrint(
            '[RoomRealtimeController] Channel status for room $roomId: $status, error: $error');
        if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
          debugPrint('[RoomRealtimeController] Realtime channel error/timeout for room $roomId');
          if (Get.isRegistered<RoomConnectionController>()) {
            RoomConnectionController.to.handleSocketOrNetworkDrop();
          }
        } else if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint('[RoomRealtimeController] Channel subscribed successfully for room $roomId');
          Future.microtask(() async {
            await onFetchPermissions(roomId);
            await onFetchMembers(roomId);
            await onFetchRequests(roomId);
            await onFetchPolls(roomId);
            await onFetchProgression(roomId);
          });
        }
      });

      _roomMessagesChannel = client
          .channel('room_messages:$roomId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'room_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) {
              if (payload.newRecord != null && Get.isRegistered<RoomChatController>()) {
                final chatCtrl = RoomChatController.to;
                final map = payload.newRecord!;
                final senderId = map['sender_id']?.toString() ?? map['senderId']?.toString();
                if (senderId == currentUserId) return;

                final msgId = map['id'].toString();
                final text = map['content']?.toString() ?? map['text']?.toString() ?? '';
                final timestamp = map['created_at'] != null
                    ? DateTime.parse(map['created_at'].toString())
                    : DateTime.now();

                final metadata = map['metadata'] is Map
                    ? Map<String, dynamic>.from(map['metadata'])
                    : <String, dynamic>{};

                final mentionedUserIds = (metadata['mentioned_user_ids'] as List?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    [];

                final message = RoomChatMessage(
                  id: msgId,
                  senderId: senderId ?? '',
                  senderName: map['sender_name']?.toString() ?? metadata['sender_name']?.toString() ?? 'Member',
                  text: text,
                  senderRole: map['sender_role']?.toString() ?? metadata['sender_role']?.toString() ?? 'Listener',
                  senderAvatar: map['sender_avatar']?.toString() ?? metadata['sender_avatar']?.toString(),
                  timestamp: timestamp,
                  replyToMessageId: map['reply_to_message_id']?.toString() ?? metadata['reply_to_message_id']?.toString(),
                  senderLevel: metadata['sender_level']?.toString() ?? '1',
                  vipLabel: metadata['vip_label']?.toString(),
                  novelLabel: metadata['novel_label']?.toString(),
                  communityTag: metadata['community_tag']?.toString(),
                  roleTag: metadata['role_tag']?.toString(),
                  isActiveSpeaker: metadata['is_active_speaker'] == true,
                  avatarFrame: metadata['avatar_frame']?.toString(),
                  mentionedUserIds: mentionedUserIds,
                );

                chatCtrl.initializeChatForRoom(roomId);
                if (!chatCtrl.roomChats[roomId]!.any((m) => m.id == msgId)) {
                  chatCtrl.roomChats[roomId]!.add(message);
                }

                if (mentionedUserIds.contains(currentUserId)) {
                  Get.snackbar(
                    '💬 Mentioned in Room',
                    '${message.senderName} mentioned you in chat: "$text"',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.95),
                    colorText: Colors.white,
                    duration: const Duration(seconds: 4),
                    icon: const Icon(Icons.alternate_email_rounded,
                        color: Colors.white),
                  );
                }
              }
            },
          )
          .onBroadcast(
            event: 'chat_message',
            callback: (payload) async {
              if (!Get.isRegistered<RoomChatController>()) return;
              final chatCtrl = RoomChatController.to;
              final senderId = payload['sender_id'] as String;
              if (senderId == currentUserId) return;

              final msgId = payload['id'] as String;
              final text = payload['text'] as String? ?? '';
              final timestamp = DateTime.parse(payload['timestamp'] as String);

              final mentionedUserIds = (payload['mentioned_user_ids'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [];

              final message = RoomChatMessage(
                id: msgId,
                senderId: senderId,
                senderName:
                    payload['sender_name'] as String? ?? 'Creaniaa Student',
                text: text,
                senderRole: payload['sender_role'] as String? ?? 'Listener',
                senderAvatar: payload['sender_avatar'] as String?,
                timestamp: timestamp,
                replyToMessageId: payload['reply_to_message_id'] as String?,
                senderLevel: payload['sender_level']?.toString() ?? '1',
                vipLabel: payload['vip_label'] as String?,
                novelLabel: payload['novel_label'] as String?,
                communityTag: payload['community_tag'] as String?,
                roleTag: payload['role_tag'] as String?,
                isActiveSpeaker: payload['is_active_speaker'] == true,
                avatarFrame: payload['avatar_frame'] as String?,
                mentionedUserIds: mentionedUserIds,
              );

              if (chatCtrl.roomChats[roomId] == null) {
                chatCtrl.roomChats[roomId] = <RoomChatMessage>[].obs;
              }

              if (!chatCtrl.roomChats[roomId]!.any((m) => m.id == msgId)) {
                chatCtrl.roomChats[roomId]!.add(message);
              }

              if (mentionedUserIds.contains(currentUserId)) {
                Get.snackbar(
                  '💬 Mentioned in Room',
                  '${message.senderName} mentioned you in chat: "$text"',
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.95),
                  colorText: Colors.white,
                  duration: const Duration(seconds: 4),
                  icon: const Icon(Icons.alternate_email_rounded,
                      color: Colors.white),
                );
              }
            },
          )
          .onBroadcast(
            event: 'message_reaction',
            callback: (payload) {
              if (!Get.isRegistered<RoomChatController>()) return;
              final chatCtrl = RoomChatController.to;
              final msgId = payload['message_id'] as String?;
              final reactionType = payload['reaction_type'] as String?;
              final uId = payload['user_id'] as String?;
              if (msgId != null && reactionType != null && uId != null) {
                final chatList = chatCtrl.roomChats[roomId];
                if (chatList != null) {
                  final idx = chatList.indexWhere((msg) => msg.id == msgId);
                  if (idx != -1) {
                    final msg = chatList[idx];
                    final currentReactions =
                        Map<String, List<String>>.from(msg.reactions);
                    if (currentReactions[reactionType] == null) {
                      currentReactions[reactionType] = [];
                    }
                    if (!currentReactions[reactionType]!.contains(uId)) {
                      currentReactions[reactionType]!.add(uId);
                    } else {
                      currentReactions[reactionType]!.remove(uId);
                    }
                    chatList[idx] = msg.copyWith(reactions: currentReactions);
                  }
                }
              }
            },
          )
          .onBroadcast(
            event: 'delete_message',
            callback: (payload) {
              if (!Get.isRegistered<RoomChatController>()) return;
              final messageId = payload['message_id'] as String?;
              if (messageId != null) {
                final chatList = RoomChatController.to.roomChats[roomId];
                if (chatList != null) {
                  chatList.removeWhere((msg) => msg.id == messageId);
                }
              }
            },
          )
          .onBroadcast(
            event: 'typing_indicator',
            callback: (payload) {
              if (!Get.isRegistered<RoomChatController>()) return;
              final chatCtrl = RoomChatController.to;
              final username = payload['username'] as String?;
              final isTyping = payload['is_typing'] == true;
              if (username != null) {
                if (isTyping) {
                  if (!chatCtrl.typingUsers.contains(username)) {
                    chatCtrl.typingUsers.add(username);
                  }
                } else {
                  chatCtrl.typingUsers.remove(username);
                }
              }
            },
          );
      _roomMessagesChannel?.subscribe();

      _roomRequestsChannel =
          client.channel('room_requests:$roomId').onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'room_requests',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'room_id',
                  value: roomId,
                ),
                callback: (payload) {
                  onFetchRequests(roomId);
                },
              );
      _roomRequestsChannel?.subscribe();

      _roomPollsChannel =
          client.channel('room_polls:$roomId').onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'room_polls',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'room_id',
                  value: roomId,
                ),
                callback: (payload) {
                  onFetchPolls(roomId);
                },
              );
      _roomPollsChannel?.subscribe();

      _roomProgressionChannel = client
          .channel('room_progression:$roomId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_seats',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) async {
              await onFetchProgression(roomId);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_seat_gifts',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) async {
              await onFetchProgression(roomId);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_daily_task_progress',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) async {
              await onFetchProgression(roomId);
            },
          );
      _roomProgressionChannel?.subscribe();

      _roomActivityEventsChannel = client
          .channel('room_activity_events:$roomId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'room_activity_events',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) {
              if (payload.newRecord != null && Get.isRegistered<RoomActivityController>()) {
                final record = payload.newRecord!;
                RoomActivityController.to.processActivityEventPayload(roomId, record);
              }
            },
          )
          .onBroadcast(
            event: 'gift_sent_event',
            callback: (payload) {
              handleIncomingRealtimeGiftEvent(roomId, Map<String, dynamic>.from(payload));
            },
          )
          .onBroadcast(
            event: 'room_activity_event',
            callback: (payload) {
              if (payload['user_id'] == currentUserId) return;
              if (Get.isRegistered<RoomActivityController>()) {
                RoomActivityController.to.processActivityEventPayload(roomId, payload);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'rooms',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: roomId,
            ),
            callback: (payload) {
              if (payload.newRecord != null && Get.isRegistered<RoomBackgroundController>()) {
                final newThemeId = payload.newRecord!['room_theme'];
                if (newThemeId != null && newThemeId is String) {
                  final bgItem = RoomBackgroundCatalog.findById(newThemeId);
                  RoomBackgroundController.to.activeRoomBackground.value = bgItem;
                  SharedPreferences.getInstance().then((prefs) {
                    prefs.setString('room_bg_theme_$roomId', bgItem.id);
                  });
                  debugPrint('[RoomRealtimeController] DB UPDATE on rooms table detected background: ${bgItem.id}');
                }
              }
            },
          )
          .onBroadcast(
            event: 'room_background_changed',
            callback: (payload) {
              if (payload['background'] != null && Get.isRegistered<RoomBackgroundController>()) {
                final bgItem = RoomBackgroundItem.fromJson(payload['background']);
                RoomBackgroundController.to.activeRoomBackground.value = bgItem;
                final roomId = payload['room_id'];
                if (roomId != null && roomId is String) {
                  SharedPreferences.getInstance().then((prefs) {
                    prefs.setString('room_bg_theme_$roomId', bgItem.id);
                  });
                }
                debugPrint('[RoomRealtimeController] Realtime background updated to: ${bgItem.id}');
              }
            },
          );
      _roomActivityEventsChannel?.subscribe();
    } catch (e) {
      debugPrint('Error subscribing to room realtime: $e');
    }
  }

  void handleIncomingRealtimeGiftEvent(String roomId, Map<String, dynamic> payload) {
    if (Get.isRegistered<GiftEventService>()) {
      GiftEventService.to.handleIncomingGiftEvent(roomId, payload);
    } else {
      GiftAnimationController.to.dispatchBroadcastGiftEvent(payload);
    }
  }

  void unsubscribeRoomRealtime() {
    try {
      final client = Supabase.instance.client;
      if (_roomMembersChannel != null) {
        client.removeChannel(_roomMembersChannel!);
        _roomMembersChannel = null;
      }
      if (_roomMessagesChannel != null) {
        client.removeChannel(_roomMessagesChannel!);
        _roomMessagesChannel = null;
      }
      if (_roomRequestsChannel != null) {
        client.removeChannel(_roomRequestsChannel!);
        _roomRequestsChannel = null;
      }
      if (_roomPollsChannel != null) {
        client.removeChannel(_roomPollsChannel!);
        _roomPollsChannel = null;
      }
      if (_roomProgressionChannel != null) {
        client.removeChannel(_roomProgressionChannel!);
        _roomProgressionChannel = null;
      }
      if (_roomActivityEventsChannel != null) {
        client.removeChannel(_roomActivityEventsChannel!);
        _roomActivityEventsChannel = null;
      }
    } catch (e) {
      debugPrint('Error unsubscribing: $e');
    }
  }
}
