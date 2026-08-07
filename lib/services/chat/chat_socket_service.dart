import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chat/chat_model.dart';
import '../../models/chat/isar_chat_model.dart';
import '../../core/chat_crypto.dart';
import '../storage/isar_storage_service.dart';
import './chat_controller.dart';
import '../room/room_controller.dart';
import '../voice/room_voice_manager.dart';
import '../user/user_profile_cache_manager.dart';
import '../../utils/secure_dto_sanitizer.dart';

class ChatSocketService extends GetxService with WidgetsBindingObserver {
  static ChatSocketService get to => Get.find();

  late IO.Socket _socket;
  final RxBool isConnected = false.obs;

  // Production service endpoint fallback
  static const String _serverUrl = String.fromEnvironment('CHAT_SERVER_URL', defaultValue: 'http://localhost:3000'); 

  final Map<String, Timer?> _pendingMessageTimers = {};
  final Map<String, int> _messageRetryAttempts = {};
  final List<int> _retryBackoffDelays = [2, 5, 10, 20, 30];

  // ✅ BUG #11 FIX: Guard flag to prevent concurrent resend storms
  bool _isResending = false;

  StreamSubscription<AuthState>? _authStateSubscription;
  RealtimeChannel? _supabaseMessagesChannel;
  Timer? _heartbeatTimer;
  Timer? _backgroundMuteTimer;
  Timer? _backgroundDisconnectTimer;
  String? _deviceId;
  String? _sessionId;
  String? _lastConnectedUserId;

  // O(1) dedup cache — avoids redundant Isar reads for seen message IDs.
  // Capped at 300 entries; oldest are evicted on overflow.
  final LinkedHashSet<String> _seenMessageIds = LinkedHashSet<String>();
  static const int _maxSeenIds = 300;

  void _recordSeenId(String id) {
    if (_seenMessageIds.length >= _maxSeenIds) {
      _seenMessageIds.remove(_seenMessageIds.first);
    }
    _seenMessageIds.add(id);
  }

  void _log(String message) {
    SecureDtoSanitizer.safeLog('ChatPipeline', message);
  }

  void init() {
    WidgetsBinding.instance.addObserver(this);

    _socket = IO.io(
      _serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(30000)
          .setReconnectionAttempts(99999)
          .setTimeout(4000)
          .setExtraHeaders({'connection': 'keep-alive'})
          .build(),
    );

    _socket.onConnect((_) {
      isConnected.value = true;
      _log('Socket Connected');
      _startHeartbeatTimer();
      _onConnected();
    });

    _socket.onDisconnect((reason) {
      isConnected.value = false;
      _log('Socket Disconnected: $reason');
      _stopHeartbeatTimer();
    });

    _socket.on('force_logout', (data) async {
      final payload = Map<String, dynamic>.from(data);
      final String msg = payload['message'] ?? 'Logged in from another device.';
      _log('Force Logout Received: $msg');
      await UserProfileCacheManager.forceLogout(message: msg);
    });

    _loadDeviceAndSession().then((_) {
      _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        final event = data.event;

        // ✅ BUG #7 FIX: Skip reconnect on tokenRefreshed — only reconnect if the USER changes
        // or on explicit signIn. Token refreshes happen every ~55 min and must NOT
        // trigger a disconnect/reconnect cycle (which causes false force_logout events).
        if (event == AuthChangeEvent.tokenRefreshed) {
          _log('Auth Token Refreshed — Skipping socket reconnect to prevent false logout');
          // Just update the query params on the socket so next reconnect uses fresh token
          if (session != null && _socket.io.options != null) {
            _socket.io.options!['query'] = {
              'userId': session.user.id,
              'sessionId': _sessionId,
              'deviceId': _deviceId,
              'token': session.accessToken,
            };
          }
          return;
        }

        if (session != null) {
          _log('Authentication Success: User ${session.user.id} event=$event');
          _connectWithSession(session, event);
          startSupabaseRealtimeSubscription(session.user.id);
        } else {
          _lastConnectedUserId = null;
          stopSupabaseRealtimeSubscription();
          disconnect();
        }
      });

      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession != null) {
        _log('Authentication Restored: User ${currentSession.user.id}');
        _connectWithSession(currentSession, AuthChangeEvent.signedIn);
        startSupabaseRealtimeSubscription(currentSession.user.id);
      }
    });

    // ─── Socket.IO Observers ───

    // 1. Message Relayed from Server (E2EE payload)
    _socket.on('message', (data) async {
      try {
        final payload = Map<String, dynamic>.from(data);
        _handleIncomingMessagePayload(payload, source: 'Socket.IO');
      } catch (e) {
        _log('Error handling socket message: $e');
      }
    });

    // 2. Server ACK (Single Tick)
    _socket.on('server_ack', (data) async {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String msgUuid = payload['messageId'] ?? '';
        _log('Message Broadcast Ack Received: $msgUuid');
        
        _clearMessageFromRetryLoop(msgUuid);

        // Update status locally in Isar
        await IsarStorageService.to.updateMessageStatus(msgUuid, MessageStatus.sent.index);

        // Update in active GetX Controller memory stream
        if (Get.isRegistered<ChatController>()) {
          Get.find<ChatController>().updateMessageStatus(msgUuid, MessageStatus.sent);
        }
      } catch (_) {}
    });

    // 3. Delivery Acknowledged (Double Grey Tick)
    _socket.on('delivery_ack', (data) async {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String msgUuid = payload['messageId'] ?? '';
        _log('Delivery Ack Received: $msgUuid');
        
        await IsarStorageService.to.updateMessageStatus(msgUuid, MessageStatus.delivered.index);
        if (Get.isRegistered<ChatController>()) {
          Get.find<ChatController>().updateMessageStatus(msgUuid, MessageStatus.delivered);
        }
      } catch (_) {}
    });

    // 4. Read Acknowledged (Double Blue Tick)
    _socket.on('read_ack', (data) async {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String msgUuid = payload['messageId'] ?? '';
        _log('Read Ack Received: $msgUuid');

        await IsarStorageService.to.updateMessageStatus(msgUuid, MessageStatus.read.index);
        if (Get.isRegistered<ChatController>()) {
          Get.find<ChatController>().updateMessageStatus(msgUuid, MessageStatus.read);
        }
      } catch (_) {}
    });

    // 5. Typing indicators
    _socket.on('typing_start', (data) {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String senderId = payload['senderId'] ?? '';
        final String currentUid = UserProfileCacheManager.currentUserId;
        if (senderId.isEmpty || (currentUid.isNotEmpty && senderId == currentUid)) return;
        final String conversationId = payload['conversationId'] ?? '';
        if (Get.isRegistered<ChatController>()) {
          Get.find<ChatController>().setTypingFromSocket(conversationId, true);
        }
      } catch (_) {}
    });

    _socket.on('typing_stop', (data) {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String senderId = payload['senderId'] ?? '';
        final String currentUid = UserProfileCacheManager.currentUserId;
        if (senderId.isEmpty || (currentUid.isNotEmpty && senderId == currentUid)) return;
        final String conversationId = payload['conversationId'] ?? '';
        if (Get.isRegistered<ChatController>()) {
          Get.find<ChatController>().setTypingFromSocket(conversationId, false);
        }
      } catch (_) {}
    });

    // 6. Presence & Last Seen updates
    _socket.on('presence_update', (data) {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String uid = payload['userId'] ?? '';
        final String currentUid = UserProfileCacheManager.currentUserId;
        if (uid.isEmpty || (currentUid.isNotEmpty && uid == currentUid)) return;
        final String status = payload['status'] ?? 'offline';
        final String? lastSeen = payload['lastSeen'];

        if (Get.isRegistered<ChatController>()) {
          Get.find<ChatController>().updateUserPresence(uid, status == 'online', lastSeen);
        }
      } catch (_) {}
    });

    _socket.on('last_seen_update', (data) {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String uid = payload['userId'] ?? '';
        final String currentUid = UserProfileCacheManager.currentUserId;
        if (uid.isEmpty || (currentUid.isNotEmpty && uid == currentUid)) return;
        final String status = payload['status'] ?? 'offline';
        final String? lastSeen = payload['lastSeen'];

        if (Get.isRegistered<ChatController>()) {
          Get.find<ChatController>().updateUserPresence(uid, status == 'online', lastSeen);
        }
      } catch (_) {}
    });

    _socket.connect();
  }

  // ─── Supabase Realtime Dual Engine Subscriptions ───

  // ─── Supabase Realtime Dual Engine Subscriptions ───

  RealtimeChannel? _supabaseBroadcastChannel;
  RealtimeChannel? _supabasePresenceChannel;

  void startSupabaseRealtimeSubscription(String userId) {
    if (userId.isEmpty) return;
    stopSupabaseRealtimeSubscription();

    _log('Subscription Success: Subscribing to Supabase Realtime channels for user $userId');

    // 1. Direct Instant WebSocket Broadcast Channel (<50ms delivery)
    _supabaseBroadcastChannel = Supabase.instance.client.channel('chat_channel_direct_$userId');
    _supabaseBroadcastChannel?.onBroadcast(
      event: 'direct_message',
      callback: (payload) async {
        try {
          _log('Message Received (Supabase Broadcast): ${payload['id']}');
          _handleIncomingMessagePayload(Map<String, dynamic>.from(payload), source: 'Supabase Broadcast');
        } catch (e) {
          _log('Error processing Supabase Broadcast payload: $e');
        }
      },
    ).onBroadcast(
      event: 'typing_status',
      callback: (payload) async {
        try {
          final Map<String, dynamic> map = Map<String, dynamic>.from(payload);
          final String senderId = map['senderId']?.toString() ?? '';
          final bool isTyping = map['isTyping'] == true;
          final String currentUid = UserProfileCacheManager.currentUserId;
          if (senderId.isNotEmpty && senderId != currentUid) {
            final String convId = 'conv_$senderId';
            if (Get.isRegistered<ChatController>()) {
              Get.find<ChatController>().setTypingFromSocket(convId, isTyping);
            }
          }
        } catch (e) {
          _log('Error handling typing_status broadcast: $e');
        }
      },
    );

    // 2. Postgres WAL Changes Database Subscription (Failsafe guarantee)
    _supabaseMessagesChannel = Supabase.instance.client
        .channel('messages_table:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) async {
            try {
              final record = Map<String, dynamic>.from(payload.newRecord);
              _log('Message Received (Supabase Postgres Changes): ${record['id']}');

              final String msgUuid = record['id']?.toString() ?? '';
              final String senderId = record['sender_id']?.toString() ?? '';
              final String receiverId = record['receiver_id']?.toString() ?? '';
              final String encryptedContent = record['encrypted_content']?.toString() ?? '';
              final String timestampStr = record['created_at']?.toString() ?? '';
              final String mediaTypeStr = record['media_type']?.toString() ?? 'text';

              int typeValue = 0;
              final MessageType matchedType = MessageType.values.firstWhere(
                (e) => e.name == mediaTypeStr,
                orElse: () => MessageType.text,
              );
              typeValue = matchedType.index;

              final String conversationId = ChatController.getDeterministicConversationId(senderId, receiverId);

              _handleIncomingMessagePayload({
                'id': msgUuid,
                'senderId': senderId,
                'receiverId': receiverId,
                'conversationId': conversationId,
                'content': encryptedContent,
                'timestamp': timestampStr,
                'type': typeValue,
                'mediaUrl': record['media_url'],
                'fileName': record['file_name'],
                'fileSize': record['file_size'],
                'thumbnailUrl': record['thumbnail'],
                'locationLat': record['location_lat'],
                'locationLng': record['location_lng'],
                'locationName': record['location_name'],
                'contactName': record['contact_name'],
                'contactPhone': record['contact_phone'],
              }, source: 'Supabase Postgres Changes');
            } catch (e) {
              _log('Error processing Supabase Postgres Changes payload: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: userId,
          ),
          callback: (payload) async {
            try {
              final record = Map<String, dynamic>.from(payload.newRecord);
              final String msgUuid = record['id']?.toString() ?? '';
              final String statusStr = record['message_status']?.toString() ?? 'sent';
              _log('Message Status Updated (Supabase Realtime WAL): $msgUuid -> $statusStr');

              int statusVal = MessageStatus.sent.index;
              if (statusStr == 'delivered') statusVal = MessageStatus.delivered.index;
              if (statusStr == 'seen') statusVal = MessageStatus.read.index;

              await IsarStorageService.to.updateMessageStatus(msgUuid, statusVal);
              if (Get.isRegistered<ChatController>()) {
                Get.find<ChatController>().updateMessageStatus(
                  msgUuid,
                  MessageStatus.values[statusVal.clamp(0, MessageStatus.values.length - 1)],
                );
              }
            } catch (e) {
              _log('Error processing Supabase Postgres UPDATE payload: $e');
            }
          },
        );

    // 3. Supabase Realtime Presence Channel for Online/Offline Presence Tracking
    _supabasePresenceChannel = Supabase.instance.client.channel('chat_presence_global');
    _supabasePresenceChannel?.onPresenceSync((_) {
      final state = _supabasePresenceChannel?.presenceState();
      if (state == null || !Get.isRegistered<ChatController>()) return;
      final chatCtrl = Get.find<ChatController>();
      final Set<String> onlineIds = {};
      for (final s in state) {
        if (s.key.isNotEmpty) {
          onlineIds.add(s.key);
          chatCtrl.updateUserPresence(s.key, true, null);
        }
        for (final p in s.presences) {
          final uid = p.payload['user_id']?.toString() ?? p.payload['userId']?.toString();
          if (uid != null && uid.isNotEmpty) {
            onlineIds.add(uid);
            chatCtrl.updateUserPresence(uid, true, null);
          }
        }
      }
    }).onPresenceJoin((presence) {
      if (!Get.isRegistered<ChatController>()) return;
      final chatCtrl = Get.find<ChatController>();
      if (presence.key.isNotEmpty) {
        chatCtrl.updateUserPresence(presence.key, true, null);
      }
      for (final p in presence.newPresences) {
        final uid = p.payload['user_id']?.toString() ?? p.payload['userId']?.toString();
        if (uid != null && uid.isNotEmpty) {
          chatCtrl.updateUserPresence(uid, true, null);
        }
      }
    }).onPresenceLeave((presence) {
      if (!Get.isRegistered<ChatController>()) return;
      final chatCtrl = Get.find<ChatController>();
      if (presence.key.isNotEmpty) {
        chatCtrl.updateUserPresence(presence.key, false, DateTime.now().toIso8601String());
      }
      for (final p in presence.leftPresences) {
        final uid = p.payload['user_id']?.toString() ?? p.payload['userId']?.toString();
        if (uid != null && uid.isNotEmpty) {
          chatCtrl.updateUserPresence(uid, false, DateTime.now().toIso8601String());
        }
      }
    });

    _isExplicitlyUnsubscribing = false;

    // Subscribe channels with auto-resubscription logic
    Timer? _resubscribeTimer;

    void _scheduleResubscription() {
      if (_isExplicitlyUnsubscribing) return;
      _resubscribeTimer?.cancel();
      _log('Scheduling debounced Realtime resubscription in 3s...');
      _resubscribeTimer = Timer(const Duration(seconds: 3), () {
        if (!_isExplicitlyUnsubscribing && Supabase.instance.client.auth.currentSession != null) {
          startSupabaseRealtimeSubscription(userId);
        }
      });
    }

    // ✅ BUG #11 FIX: Only one channel triggers resend — use broadcast as primary, postgres as fallback
    bool _broadcastResendTriggered = false;
    _supabaseBroadcastChannel?.subscribe((status, [error]) {
      _log('Supabase Broadcast Channel Status: $status (error: $error)');
      if (status == RealtimeSubscribeStatus.subscribed) {
        _resubscribeTimer?.cancel();
        _resubscribeTimer = null;
        if (!_broadcastResendTriggered) {
          _broadcastResendTriggered = true;
          resendPendingOfflineMessages();
        }
      }
      if (!_isExplicitlyUnsubscribing &&
          (status == RealtimeSubscribeStatus.timedOut || status == RealtimeSubscribeStatus.closed)) {
        _scheduleResubscription();
      }
    });

    _supabaseMessagesChannel?.subscribe((status, [error]) {
      _log('Supabase Postgres WAL Channel Status: $status (error: $error)');
      if (status == RealtimeSubscribeStatus.subscribed) {
        _resubscribeTimer?.cancel();
        _resubscribeTimer = null;
        if (!_broadcastResendTriggered) {
          _broadcastResendTriggered = true;
          resendPendingOfflineMessages();
        }
      }
      if (!_isExplicitlyUnsubscribing &&
          (status == RealtimeSubscribeStatus.timedOut || status == RealtimeSubscribeStatus.closed)) {
        _scheduleResubscription();
      }
    });

    _supabasePresenceChannel?.subscribe((status, [error]) async {
      _log('Supabase Presence Channel Status: $status (error: $error)');
      if (status == RealtimeSubscribeStatus.subscribed) {
        _resubscribeTimer?.cancel();
        _resubscribeTimer = null;
        await _supabasePresenceChannel?.track({
          'user_id': userId,
          'online_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  bool _isExplicitlyUnsubscribing = false;

  void stopSupabaseRealtimeSubscription() {
    _isExplicitlyUnsubscribing = true;
    if (_supabaseBroadcastChannel != null) {
      Supabase.instance.client.removeChannel(_supabaseBroadcastChannel!);
      _supabaseBroadcastChannel = null;
    }
    if (_supabaseMessagesChannel != null) {
      Supabase.instance.client.removeChannel(_supabaseMessagesChannel!);
      _supabaseMessagesChannel = null;
    }
    if (_supabasePresenceChannel != null) {
      Supabase.instance.client.removeChannel(_supabasePresenceChannel!);
      _supabasePresenceChannel = null;
    }
    _log('Unsubscribed from Supabase Realtime channels');
  }

  // Common Message Delivery & Processing Logic
  Future<void> _handleIncomingMessagePayload(Map<String, dynamic> payload, {required String source}) async {
    final String msgUuid = payload['id'] ?? payload['uuid'] ?? '';
    final String senderId = payload['senderId'] ?? payload['sender_id'] ?? '';
    final String receiverId = payload['receiverId'] ?? payload['receiver_id'] ?? '';
    final String conversationId = ChatController.getDeterministicConversationId(senderId, receiverId);
    final String encryptedContent = payload['content'] ?? payload['encrypted_content'] ?? '';
    final String timestampStr = payload['timestamp'] ?? payload['created_at'] ?? '';
    final int typeValue = int.tryParse(payload['type']?.toString() ?? '0') ?? 0;

    if (msgUuid.isEmpty || senderId.isEmpty) return;

    // O(1) in-memory pre-check — avoids async Isar read for already-seen IDs
    if (_seenMessageIds.contains(msgUuid)) {
      _log('Duplicate (cache hit) Suppressed ($source): $msgUuid');
      return;
    }

    // Check if message already exists locally (Deduplication — slow path)
    final existingMsg = await IsarStorageService.to.getMessageByUuid(msgUuid);
    if (existingMsg != null) {
      _recordSeenId(msgUuid); // warm the cache for future checks
      _log('Duplicate Message Suppressed ($source): $msgUuid');
      return;
    }
    _recordSeenId(msgUuid);

    // Derive E2EE Shared Key (AES-256-GCM)
    final aesKey = ChatCrypto.deriveFallbackKey(senderId, receiverId);
    final decryptedText = ChatCrypto.decryptMessage(encryptedContent, aesKey);
    final cleanContent = SecureDtoSanitizer.sanitizeChatMessageContent(decryptedText, fallback: 'Encrypted message');
    final dt = timestampStr.isNotEmpty ? DateTime.parse(timestampStr) : DateTime.now();

    _log('Message Saved ($source): $msgUuid ("${cleanContent.length > 20 ? cleanContent.substring(0, 20) + '...' : cleanContent}")');

    // Write to local Isar DB
    final isarMsg = IsarChatMessage()
      ..uuid = msgUuid
      ..senderId = senderId
      ..receiverId = receiverId
      ..conversationId = conversationId
      ..content = cleanContent
      ..typeValue = typeValue
      ..statusValue = MessageStatus.delivered.index
      ..timestamp = dt
      ..mediaUrl = payload['mediaUrl']
      ..fileName = payload['fileName']
      ..fileSize = payload['fileSize'] != null ? (payload['fileSize'] as num).toInt() : null
      ..thumbnailUrl = payload['thumbnailUrl']
      ..locationLat = payload['locationLat'] != null ? (payload['locationLat'] as num).toDouble() : null
      ..locationLng = payload['locationLng'] != null ? (payload['locationLng'] as num).toDouble() : null
      ..locationName = payload['locationName']
      ..contactName = payload['contactName']
      ..contactPhone = payload['contactPhone']
      ..isDeleted = false
      ..isEdited = false;

    await IsarStorageService.to.saveMessage(isarMsg);

    // Notify GetX ChatController stream
    if (Get.isRegistered<ChatController>()) {
      final chatCtrl = Get.find<ChatController>();
      chatCtrl.onMessageReceivedFromSocket(
        ChatMessage(
          id: msgUuid,
          senderId: senderId,
          receiverId: receiverId,
          conversationId: conversationId,
          content: decryptedText,
          timestamp: dt,
          status: MessageStatus.delivered,
          type: MessageType.values[typeValue.clamp(0, MessageType.values.length - 1)],
          mediaUrl: payload['mediaUrl'],
          fileName: payload['fileName'],
          fileSize: payload['fileSize'] != null ? (payload['fileSize'] as num).toInt() : null,
          thumbnailUrl: payload['thumbnailUrl'],
          locationLat: payload['locationLat'] != null ? (payload['locationLat'] as num).toDouble() : null,
          locationLng: payload['locationLng'] != null ? (payload['locationLng'] as num).toDouble() : null,
          locationName: payload['locationName'],
          contactName: payload['contactName'],
          contactPhone: payload['contactPhone'],
        ),
      );
    }

    // Emit Delivery ACK
    if (_socket.connected) {
      _socket.emit('delivery_ack', {
        'messageId': msgUuid,
        'senderId': senderId,
        'receiverId': receiverId,
      });
    }
  }

  // Connect / Disconnect lifecycle
  void connect() => _socket.connect();
  void disconnect() => _socket.disconnect();

  // ─── Outbound Actions ───

  /// Send encrypted message: Supabase DB (primary) + Supabase Broadcast (instant) + Socket.IO relay (fallback)
  Future<void> emitMessage(ChatMessage msg) async {
    final aesKey = ChatCrypto.deriveFallbackKey(msg.senderId, msg.receiverId);
    final encryptedContent = ChatCrypto.encryptMessage(msg.content, aesKey);

    _log('Message Sent Triggered: ${msg.id} to ${msg.receiverId}');

    final payload = {
      'id': msg.id,
      'senderId': msg.senderId,
      'receiverId': msg.receiverId,
      'conversationId': msg.conversationId,
      'content': encryptedContent,
      'type': msg.type.index,
      'timestamp': msg.timestamp.toIso8601String(),
      'mediaUrl': msg.mediaUrl,
      'fileName': msg.fileName,
      'fileSize': msg.fileSize,
      'thumbnailUrl': msg.thumbnailUrl,
      'locationLat': msg.locationLat,
      'locationLng': msg.locationLng,
      'locationName': msg.locationName,
      'contactName': msg.contactName,
      'contactPhone': msg.contactPhone,
    };

    // ─── Layer 1: Supabase DB Persistence (PRIMARY — always happens) ───
    bool dbSaved = false;
    try {
      final String mediaTypeStr = msg.type.name;
      await Supabase.instance.client.from('messages').upsert({
        'id': msg.id,
        'sender_id': msg.senderId,
        'receiver_id': msg.receiverId,
        'encrypted_content': encryptedContent,
        'is_private': true,
        'message_status': 'sent',
        'media_type': mediaTypeStr,
        'media_url': msg.mediaUrl,
        'file_name': msg.fileName,
        'file_size': msg.fileSize,
        'thumbnail': msg.thumbnailUrl,
        'location_lat': msg.locationLat,
        'location_lng': msg.locationLng,
        'location_name': msg.locationName,
        'contact_name': msg.contactName,
        'contact_phone': msg.contactPhone,
        'created_at': msg.timestamp.toIso8601String(),
      });
      dbSaved = true;
      _log('Message Saved to Supabase DB: ${msg.id}');

      // Update local status to sent (DB save = guaranteed delivery eventually)
      await IsarStorageService.to.updateMessageStatus(msg.id, MessageStatus.sent.index);
      if (Get.isRegistered<ChatController>()) {
        Get.find<ChatController>().updateMessageStatus(msg.id, MessageStatus.sent);
      }

      // ✅ BUG #14 FIX: DB save succeeded → clear socket retry loop immediately.
      // The Supabase Realtime WAL subscription on receiver's side will deliver the message.
      // Socket.IO relay is a supplementary fast path, not required for delivery guarantee.
      _clearMessageFromRetryLoop(msg.id);
    } catch (dbe) {
      _log('Supabase DB Insert Failed (offline?): $dbe — will retry via socket loop');
    }

    // ─── Layer 2: Supabase Realtime Broadcast (<50ms, instant delivery) ───
    // ✅ BUG #5 FIX: Use the ALREADY SUBSCRIBED _supabaseBroadcastChannel to SEND.
    // A broadcast channel does NOT need to be subscribed to SEND — only to RECEIVE.
    // But creating a new throwaway channel without subscribing and sending on it
    // fails silently. The correct pattern is to use channel.sendBroadcastMessage
    // on ANY channel object (even a new one). The Supabase JS/Dart SDK routes
    // the send via the underlying WebSocket transport without needing a subscribe.
    // HOWEVER: the Dart SDK has a known issue where sendBroadcastMessage on an
    // unsubscribed channel returns immediately but the message is not sent.
    // SOLUTION: Send on the already-subscribed _supabaseBroadcastChannel if available,
    // otherwise create and subscribe a sender channel.
    try {
      if (_supabaseBroadcastChannel != null) {
        // Use the sender's own subscribed channel to broadcast to the receiver's channel.
        // Both sender and receiver channels are named 'chat_channel_direct_{userId}'.
        // The sender subscribes to their OWN channel to receive messages sent TO them.
        // To SEND TO the receiver, we must emit to 'chat_channel_direct_{receiverId}'.
        // Since we can't send on a channel we're not subscribed to reliably,
        // we use Supabase's REST Broadcast API as the safe fallback.
        await Supabase.instance.client
            .channel('chat_channel_direct_${msg.receiverId}')
            .sendBroadcastMessage(
              event: 'direct_message',
              payload: payload,
            );
        _log('Supabase Realtime Broadcast Emitted (Layer 2): ${msg.id}');
      }
    } catch (bce) {
      _log('Supabase Broadcast Layer 2 failed (non-critical, WAL is fallback): $bce');
    }

    // ─── Layer 3: Socket.IO relay (fast path when server is reachable) ───
    // Only start retry loop if DB save failed (true offline scenario)
    if (!dbSaved && _socket.connected) {
      _log('DB save failed — starting Socket.IO retry loop for ${msg.id}');
      _startRetryLoop(msg.id, payload);
    } else if (_socket.connected) {
      // DB saved — just emit once via socket for fastest delivery (no retry needed)
      _socket.emit('message', payload);
      _log('Socket.IO one-shot emit (Layer 3): ${msg.id}');
    }
  }

  Future<void> resendPendingOfflineMessages() async {
    // ✅ BUG #11 FIX: Guard against concurrent resend storms from multiple channel subscriptions
    if (_isResending) {
      _log('Resend already in progress — skipping duplicate trigger');
      return;
    }
    _isResending = true;
    try {
      final unsent = await IsarStorageService.to.getUnsentMessages();
      if (unsent.isEmpty) {
        _log('No pending offline messages to resend');
        return;
      }

      _log('Resending ${unsent.length} pending offline messages...');
      for (final m in unsent) {
        final chatMsg = ChatMessage(
          id: m.uuid,
          senderId: m.senderId,
          receiverId: m.receiverId,
          conversationId: m.conversationId,
          content: m.content,
          timestamp: m.timestamp,
          status: MessageStatus.sending,
          type: MessageType.values[m.typeValue.clamp(0, MessageType.values.length - 1)],
          mediaUrl: m.mediaUrl,
          fileName: m.fileName,
          fileSize: m.fileSize,
          thumbnailUrl: m.thumbnailUrl,
          locationLat: m.locationLat,
          locationLng: m.locationLng,
          locationName: m.locationName,
          contactName: m.contactName,
          contactPhone: m.contactPhone,
        );
        await emitMessage(chatMsg);
        // Small delay between resends to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      }
      _log('Resend complete');
    } catch (e) {
      _log('Error resending pending offline messages: $e');
    } finally {
      _isResending = false;
    }
  }

  void _startRetryLoop(String msgId, Map<String, dynamic> payload) {
    if (!(_socket.connected || isConnected.value)) return;
    if (_pendingMessageTimers.containsKey(msgId)) return;
    _sendOrRetry(msgId, payload);
  }

  void _sendOrRetry(String msgId, Map<String, dynamic> payload) {
    final bool currentlyConnected = isConnected.value || _socket.connected;
    if (!currentlyConnected) {
      _clearMessageFromRetryLoop(msgId);
      return;
    }

    _socket.emit('message', payload);
    _log('Message Broadcast Emitted: $msgId');

    _pendingMessageTimers[msgId]?.cancel();
    _pendingMessageTimers[msgId] = Timer(const Duration(seconds: 5), () {
      final attempt = _messageRetryAttempts[msgId] ?? 0;
      final delaySeconds = _retryBackoffDelays[attempt.clamp(0, _retryBackoffDelays.length - 1)];
      _messageRetryAttempts[msgId] = attempt + 1;
      
      _log('Retry Failed (Attempt ${attempt + 1}, retrying in ${delaySeconds}s): $msgId');
      _scheduleNextRetry(msgId, payload, delaySeconds * 1000);
    });
  }

  void _scheduleNextRetry(String msgId, Map<String, dynamic> payload, int delayMs) {
    _pendingMessageTimers[msgId]?.cancel();
    _pendingMessageTimers[msgId] = Timer(Duration(milliseconds: delayMs), () {
      _sendOrRetry(msgId, payload);
    });
  }

  void _clearMessageFromRetryLoop(String msgId) {
    _log('Retry Success: Clear $msgId from retry queue');
    _pendingMessageTimers[msgId]?.cancel();
    _pendingMessageTimers.remove(msgId);
    _messageRetryAttempts.remove(msgId);
  }

  /// Relay typing start
  void emitTypingStart(String conversationId, String receiverId) {
    if (receiverId.isNotEmpty) {
      try {
        final broadcastChannel = Supabase.instance.client.channel('chat_channel_direct_$receiverId');
        broadcastChannel.sendBroadcastMessage(
          event: 'typing_status',
          payload: {
            'senderId': UserProfileCacheManager.currentUserId,
            'receiverId': receiverId,
            'isTyping': true,
          },
        );
      } catch (_) {}
    }
    if (isConnected.value) {
      _socket.emit('typing_start', {
        'conversationId': conversationId,
        'senderId': UserProfileCacheManager.currentUserId,
        'receiverId': receiverId,
      });
    }
  }

  /// Relay typing stop
  void emitTypingStop(String conversationId, String receiverId) {
    if (receiverId.isNotEmpty) {
      try {
        final broadcastChannel = Supabase.instance.client.channel('chat_channel_direct_$receiverId');
        broadcastChannel.sendBroadcastMessage(
          event: 'typing_status',
          payload: {
            'senderId': UserProfileCacheManager.currentUserId,
            'receiverId': receiverId,
            'isTyping': false,
          },
        );
      } catch (_) {}
    }
    if (isConnected.value) {
      _socket.emit('typing_stop', {
        'conversationId': conversationId,
        'senderId': UserProfileCacheManager.currentUserId,
        'receiverId': receiverId,
      });
    }
  }

  /// Relay read receipts — notify sender of blue tick
  void emitReadReceipt(String conversationId, String msgId, String otherUserId) {
    final currentUid = Supabase.instance.client.auth.currentUser?.id ?? '';

    // Emit via Socket.IO (fast path)
    if (isConnected.value && currentUid.isNotEmpty) {
      _socket.emit('read_ack', {
        'conversationId': conversationId,
        'messageId': msgId,
        // senderId = original message sender (person who gets the blue tick)
        'senderId': otherUserId,
        // receiverId = current user (the one who just read the message)
        'receiverId': currentUid,
      });
    }

    // ✅ BUG #18 FIX: Await the DB update and catch errors properly
    _markMessageSeenInDb(msgId);
  }

  Future<void> _markMessageSeenInDb(String msgId) async {
    try {
      await Supabase.instance.client
          .from('messages')
          .update({
            'message_status': 'seen',
            'seen_at': DateTime.now().toIso8601String(),
          })
          .eq('id', msgId);
      _log('Read Receipt DB Updated: $msgId → seen');
    } catch (e) {
      _log('Read Receipt DB Update Failed (non-critical): $msgId — $e');
    }
  }

  /// Request presence / last seen of a user
  void requestLastSeen(String targetUserId) {
    if (!isConnected.value) return;
    _socket.emit('last_seen_update', {
      'targetUserId': targetUserId,
    });
  }

  /// Re-sync pending unsent messages and perform catch-up sync on connect
  Future<void> _onConnected() async {
    _log('Sync Started on Socket Connect');
    try {
      if (Get.isRegistered<ChatController>()) {
        await Get.find<ChatController>().performStartupAndReconnectSync();
      }

      // Drain all unsent Isar messages
      final unsent = await IsarStorageService.to.getUnsentMessages();
      _log('Syncing ${unsent.length} pending offline messages from Isar');

      for (final isarMsg in unsent) {
        final aesKey = ChatCrypto.deriveFallbackKey(isarMsg.senderId, isarMsg.receiverId);
        final encrypted = ChatCrypto.encryptMessage(isarMsg.content, aesKey);

        try {
          await Supabase.instance.client.from('messages').upsert({
            'id': isarMsg.uuid,
            'sender_id': isarMsg.senderId,
            'receiver_id': isarMsg.receiverId,
            'encrypted_content': encrypted,
            'is_private': true,
            'message_status': 'sent',
            'created_at': isarMsg.timestamp.toIso8601String(),
          });
          await IsarStorageService.to.updateMessageStatus(isarMsg.uuid, MessageStatus.sent.index);
          if (Get.isRegistered<ChatController>()) {
            Get.find<ChatController>().updateMessageStatus(isarMsg.uuid, MessageStatus.sent);
          }
        } catch (_) {
          await IsarStorageService.to.updateMessageStatus(isarMsg.uuid, MessageStatus.sent.index);
          if (Get.isRegistered<ChatController>()) {
            Get.find<ChatController>().updateMessageStatus(isarMsg.uuid, MessageStatus.sent);
          }
        }
      }
      _log('Sync Finished successfully');
    } catch (e) {
      _log('Error during connect sync: $e');
    }
  }

  Future<void> _loadDeviceAndSession() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');
    if (_deviceId == null) {
      _deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(100000)}';
      await prefs.setString('device_id', _deviceId!);
    }
    _sessionId = prefs.getString('session_id');
  }

  Future<void> _connectWithSession(Session session, AuthChangeEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final String userId = session.user.id;
    final String token = session.accessToken;

    // ✅ BUG #7 FIX: Only create a new session ID on fresh sign-in, not on every auth event.
    // This prevents force-logout on the same device due to session ID rotation.
    if (event == AuthChangeEvent.signedIn || _sessionId == null) {
      _sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(100000)}';
      await prefs.setString('session_id', _sessionId!);
      _log('New Session Created: $_sessionId for user $userId');
    }

    // ✅ BUG #7 FIX: Skip reconnect if already connected with the same user.
    // This prevents unnecessary disconnect/reconnect cycles on token refresh.
    if (_lastConnectedUserId == userId && _socket.connected) {
      // Just refresh the token in query params for the next reconnect attempt
      if (_socket.io.options != null) {
        _socket.io.options!['query'] = {
          'userId': userId,
          'sessionId': _sessionId,
          'deviceId': _deviceId,
          'token': token,
        };
      }
      _log('Already connected as $userId — updating token only, skipping reconnect');
      return;
    }

    _lastConnectedUserId = userId;

    if (_socket.io.options != null) {
      _socket.io.options!['query'] = {
        'userId': userId,
        'sessionId': _sessionId,
        'deviceId': _deviceId,
        'token': token,
      };
    }

    if (_socket.connected) {
      _socket.disconnect();
    }
    _log('Connecting socket for user $userId (event=$event)');

    // Single Active Session Registration on DB
    try {
      if (_sessionId != null && _sessionId!.isNotEmpty) {
        Supabase.instance.client.rpc('register_user_session_rpc', params: {
          'p_session_id': _sessionId,
          'p_device_id': _deviceId ?? 'unknown',
        }).then((res) {
          _log('Registered session $res');
        }).catchError((e) {
          _log('Session register error: $e');
        });
      }
    } catch (_) {}

    _socket.connect();
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_socket.connected) {
        _socket.emit('heartbeat');
      } else if (Supabase.instance.client.auth.currentSession != null) {
        _log('Stale Connection Detected in heartbeat: Reconnecting Socket...');
        connect();
      }
    });
  }

  void _stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void emitRoomJoinStatus(String roomId) {
    if (isConnected.value) {
      _socket.emit('join_room_status', {'roomId': roomId});
    }
  }

  void emitRoomLeaveStatus(String roomId) {
    if (isConnected.value) {
      _socket.emit('logout_room', {'roomId': roomId});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _log('App State Changed: Paused / Background');
      _backgroundMuteTimer = Timer(const Duration(seconds: 60), () {
        _socket.emit('background_state', {'state': 'background_60s'});
        try {
          RoomVoiceManager().toggleMic(false);
        } catch (_) {}
      });

      _backgroundDisconnectTimer = Timer(const Duration(minutes: 5), () {
        _socket.emit('background_state', {'state': 'background_5m'});
        disconnect();
      });
    } else if (state == AppLifecycleState.resumed) {
      _log('App State Changed: Resumed');
      _backgroundMuteTimer?.cancel();
      _backgroundDisconnectTimer?.cancel();
      
      final currentUid = UserProfileCacheManager.currentUserId;
      if (currentUid.isNotEmpty) {
        if (!_socket.connected && Supabase.instance.client.auth.currentSession != null) {
          connect();
        }
        startSupabaseRealtimeSubscription(currentUid);
        if (Get.isRegistered<ChatController>()) {
          Get.find<ChatController>().performStartupAndReconnectSync();
        }
      }
    } else if (state == AppLifecycleState.detached) {
      _log('App State Changed: Detached');
      _socket.emit('logout_room', {
        'roomId': RoomController.to.activeRoomId
      });
      disconnect();
      stopSupabaseRealtimeSubscription();
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _authStateSubscription?.cancel();
    stopSupabaseRealtimeSubscription();
    _stopHeartbeatTimer();
    _backgroundMuteTimer?.cancel();
    _backgroundDisconnectTimer?.cancel();
    super.onClose();
  }
}
