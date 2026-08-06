import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/room/room_background_model.dart';
import '../user/user_profile_cache_manager.dart';
import 'room_chat_controller.dart';
import 'room_activity_controller.dart';
import 'room_background_controller.dart';

class RoomRealtimeController extends GetxController {
  static RoomRealtimeController get to => Get.find<RoomRealtimeController>();

  RealtimeChannel? _roomsListChannel;
  RealtimeChannel? _roomMembersChannel;
  RealtimeChannel? _roomMessagesChannel;
  RealtimeChannel? _roomRequestsChannel;
  RealtimeChannel? _roomPollsChannel;
  RealtimeChannel? _roomProgressionChannel;
  RealtimeChannel? _roomActivityEventsChannel;

  RealtimeChannel? get roomMessagesChannel => _roomMessagesChannel;
  RealtimeChannel? get roomActivityEventsChannel => _roomActivityEventsChannel;

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
          );

      Timer? reconnectTimer;

      _roomMembersChannel?.subscribe((status, [error]) {
        debugPrint(
            '[RoomRealtimeController] Channel status for room $roomId: $status, error: $error');
        if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
          if (reconnectTimer == null) {
            debugPrint(
                '[RoomRealtimeController] Connection lost. Reconnection timer started (20s).');
            reconnectTimer = Timer(const Duration(seconds: 20), () async {
              if (activeRoomId == roomId) {
                debugPrint(
                    '[RoomRealtimeController] Reconnection timed out. Exiting room.');
                onCleanupResources();
                Get.snackbar(
                  'Connection Lost 📡',
                  'You have been disconnected from the room due to network issues.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.orange.withOpacity(0.9),
                  colorText: Colors.white,
                );
              }
            });
          }
        } else if (status == RealtimeSubscribeStatus.subscribed) {
          if (reconnectTimer != null) {
            reconnectTimer!.cancel();
            reconnectTimer = null;
            debugPrint(
                '[RoomRealtimeController] Connection restored successfully within 20s!');
          }
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
                );

                chatCtrl.initializeChatForRoom(roomId);
                if (!chatCtrl.roomChats[roomId]!.any((m) => m.id == msgId)) {
                  chatCtrl.roomChats[roomId]!.add(message);
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
              );

              if (chatCtrl.roomChats[roomId] == null) {
                chatCtrl.roomChats[roomId] = <RoomChatMessage>[].obs;
              }

              if (!chatCtrl.roomChats[roomId]!.any((m) => m.id == msgId)) {
                chatCtrl.roomChats[roomId]!.add(message);
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
                if (record['user_id'] != currentUserId) {
                  RoomActivityController.to.processActivityEventPayload(roomId, record);
                }
              }
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
          .onBroadcast(
            event: 'room_background_changed',
            callback: (payload) {
              if (payload['background'] != null && Get.isRegistered<RoomBackgroundController>()) {
                RoomBackgroundController.to.activeRoomBackground.value =
                    RoomBackgroundItem.fromJson(payload['background']);
              }
            },
          );
      _roomActivityEventsChannel?.subscribe();
    } catch (e) {
      debugPrint('Error subscribing to room realtime: $e');
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
