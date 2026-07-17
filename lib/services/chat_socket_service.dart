import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import '../models/isar_chat_model.dart';
import '../core/chat_crypto.dart';
import 'isar_storage_service.dart';
import 'chat_controller.dart';
import 'room_controller.dart';
import 'voice/room_voice_manager.dart';
import 'user_profile_cache_manager.dart';

class ChatSocketService extends GetxService with WidgetsBindingObserver {
  static ChatSocketService get to => Get.find();

  late IO.Socket _socket;
  final RxBool isConnected = false.obs;

  // Production Northflank service endpoint
  static const String _serverUrl = String.fromEnvironment('CHAT_SERVER_URL', defaultValue: 'http://localhost:3000'); 

  final Map<String, Timer?> _pendingMessageTimers = {};
  final Map<String, int> _messageRetryAttempts = {};
  final List<int> _retryBackoffDelays = [2, 5, 10, 20, 30];

  StreamSubscription<AuthState>? _authStateSubscription;
  Timer? _heartbeatTimer;
  Timer? _backgroundMuteTimer;
  Timer? _backgroundDisconnectTimer;
  String? _deviceId;
  String? _sessionId;

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
      _startHeartbeatTimer();
      _onConnected();
    });

    _socket.onDisconnect((_) {
      isConnected.value = false;
      _stopHeartbeatTimer();
    });

    _socket.on('force_logout', (data) async {
      final payload = Map<String, dynamic>.from(data);
      final String msg = payload['message'] ?? 'Logged in from another device.';
      await UserProfileCacheManager.forceLogout(message: msg);
    });

    _loadDeviceAndSession().then((_) {
      _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        final event = data.event;

        if (session != null) {
          _connectWithSession(session, event);
        } else {
          disconnect();
        }
      });

      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession != null) {
        _connectWithSession(currentSession, AuthChangeEvent.signedIn);
      }
    });

    // ─── Event Observers ───

    // 1. Message Relayed from Server (E2EE payload)
    _socket.on('message', (data) async {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String msgUuid = payload['id'] ?? '';
        final String senderId = payload['senderId'] ?? '';
        final String receiverId = payload['receiverId'] ?? '';
        final String conversationId = payload['conversationId'] ?? '';
        final String encryptedContent = payload['content'] ?? '';
        final String timestampStr = payload['timestamp'] ?? '';
        final int typeValue = payload['type'] ?? 0;

        // Derive E2EE Shared Key (AES-256-GCM)
        final aesKey = ChatCrypto.deriveFallbackKey(senderId, receiverId);
        final decryptedText = ChatCrypto.decryptMessage(encryptedContent, aesKey);

        final dt = timestampStr.isNotEmpty ? DateTime.parse(timestampStr) : DateTime.now();

        // Write to local Isar DB (Single Source of Truth)
        final isarMsg = IsarChatMessage()
          ..uuid = msgUuid
          ..senderId = senderId
          ..receiverId = receiverId
          ..conversationId = conversationId
          ..content = decryptedText
          ..typeValue = typeValue
          ..statusValue = MessageStatus.delivered.index
          ..timestamp = dt
          ..isDeleted = false
          ..isEdited = false;

        await IsarStorageService.to.saveMessage(isarMsg);

        // Fetch user cache or check conversation
        final chatCtrl = Get.find<ChatController>();
        final idx = chatCtrl.conversations.indexWhere((c) => c.id == conversationId);
        if (idx == -1) {
          // Auto create conversation
          chatCtrl.getOrCreateConversation(senderId, 'User $senderId', 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100');
        }

        // Notify controller to update active UI stream
        chatCtrl.onMessageReceivedFromSocket(
          ChatMessage(
            id: msgUuid,
            senderId: senderId,
            receiverId: receiverId,
            conversationId: conversationId,
            content: decryptedText,
            timestamp: dt,
            status: MessageStatus.delivered,
            type: MessageType.values[typeValue],
          ),
        );

        // Emit Delivery ACK to Socket.IO immediately (Double Grey Tick)
        _socket.emit('delivery_ack', {
          'messageId': msgUuid,
          'senderId': senderId,
          'receiverId': receiverId,
        });
      } catch (_) {}
    });

    // 2. Server ACK (Single Tick)
    _socket.on('server_ack', (data) async {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String msgUuid = payload['messageId'] ?? '';
        
        _clearMessageFromRetryLoop(msgUuid);

        // Update status locally in Isar
        await IsarStorageService.to.updateMessageStatus(msgUuid, MessageStatus.sent.index);

        // Update in active GetX Controller memory stream
        Get.find<ChatController>().updateMessageStatus(msgUuid, MessageStatus.sent);
      } catch (_) {}
    });

    // 3. Delivery Acknowledged (Double Grey Tick)
    _socket.on('delivery_ack', (data) async {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String msgUuid = payload['messageId'] ?? '';
        
        await IsarStorageService.to.updateMessageStatus(msgUuid, MessageStatus.delivered.index);
        Get.find<ChatController>().updateMessageStatus(msgUuid, MessageStatus.delivered);
      } catch (_) {}
    });

    // 4. Read Acknowledged (Double Blue Tick)
    _socket.on('read_ack', (data) async {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String msgUuid = payload['messageId'] ?? '';

        await IsarStorageService.to.updateMessageStatus(msgUuid, MessageStatus.read.index);
        Get.find<ChatController>().updateMessageStatus(msgUuid, MessageStatus.read);
      } catch (_) {}
    });

    // 5. Typing indicators
    _socket.on('typing_start', (data) {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String conversationId = payload['conversationId'] ?? '';
        Get.find<ChatController>().setTypingFromSocket(conversationId, true);
      } catch (_) {}
    });

    _socket.on('typing_stop', (data) {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String conversationId = payload['conversationId'] ?? '';
        Get.find<ChatController>().setTypingFromSocket(conversationId, false);
      } catch (_) {}
    });

    // 6. Presence & Last Seen updates
    _socket.on('presence_update', (data) {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String uid = payload['userId'] ?? '';
        final String status = payload['status'] ?? 'offline';
        final String? lastSeen = payload['lastSeen'];

        Get.find<ChatController>().updateUserPresence(uid, status == 'online', lastSeen);
      } catch (_) {}
    });

    _socket.on('last_seen_update', (data) {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String uid = payload['userId'] ?? '';
        final String status = payload['status'] ?? 'offline';
        final String? lastSeen = payload['lastSeen'];

        Get.find<ChatController>().updateUserPresence(uid, status == 'online', lastSeen);
      } catch (_) {}
    });

    _socket.connect();
  }

  // Connect / Disconnect lifecycle
  void connect() => _socket.connect();
  void disconnect() => _socket.disconnect();

  // ─── Actions ───

  /// Send encrypted message through Socket.IO and save locally
  Future<void> emitMessage(ChatMessage msg) async {
    // Encrypt plaintext payload client-side before transmission
    final aesKey = ChatCrypto.deriveFallbackKey(msg.senderId, msg.receiverId);
    final encryptedContent = ChatCrypto.encryptMessage(msg.content, aesKey);

    final payload = {
      'id': msg.id,
      'senderId': msg.senderId,
      'receiverId': msg.receiverId,
      'conversationId': msg.conversationId,
      'content': encryptedContent,
      'type': msg.type.index,
      'timestamp': msg.timestamp.toIso8601String(),
    };

    _startRetryLoop(msg.id, payload);
  }

  void _startRetryLoop(String msgId, Map<String, dynamic> payload) {
    if (_pendingMessageTimers.containsKey(msgId)) return;
    _sendOrRetry(msgId, payload);
  }

  void _sendOrRetry(String msgId, Map<String, dynamic> payload) {
    final bool currentlyConnected = isConnected.value || _socket.connected;
    if (!currentlyConnected) {
      _scheduleNextRetry(msgId, payload, 5000);
      return;
    }

    _socket.emit('message', payload);

    _pendingMessageTimers[msgId]?.cancel();
    _pendingMessageTimers[msgId] = Timer(const Duration(seconds: 5), () {
      final attempt = _messageRetryAttempts[msgId] ?? 0;
      final delaySeconds = _retryBackoffDelays[attempt.clamp(0, _retryBackoffDelays.length - 1)];
      _messageRetryAttempts[msgId] = attempt + 1;
      
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
    _pendingMessageTimers[msgId]?.cancel();
    _pendingMessageTimers.remove(msgId);
    _messageRetryAttempts.remove(msgId);
  }

  /// Relay typing start
  void emitTypingStart(String conversationId, String receiverId) {
    if (!isConnected.value) return;
    _socket.emit('typing_start', {
      'conversationId': conversationId,
      'receiverId': receiverId,
    });
  }

  /// Relay typing stop
  void emitTypingStop(String conversationId, String receiverId) {
    if (!isConnected.value) return;
    _socket.emit('typing_stop', {
      'conversationId': conversationId,
      'receiverId': receiverId,
    });
  }

  /// Relay read receipts
  void emitReadReceipt(String conversationId, String msgId, String otherUserId) {
    if (!isConnected.value) return;
    _socket.emit('read_ack', {
      'conversationId': conversationId,
      'messageId': msgId,
      'senderId': Supabase.instance.client.auth.currentUser?.id ?? 'me',
      'receiverId': otherUserId,
    });
  }

  /// Manually request presence / last seen of a user
  void requestLastSeen(String targetUserId) {
    if (!isConnected.value) return;
    _socket.emit('last_seen_update', {
      'targetUserId': targetUserId,
    });
  }

  /// Drain pending (sending status) messages on reconnect
  Future<void> _onConnected() async {
    try {
      final allConvs = await IsarStorageService.to.getAllConversations();
      for (final conv in allConvs) {
        final pendingMsgs = await IsarStorageService.to.getMessagesForConversation(conv.uuid, limit: 100);
        final filteredPending = pendingMsgs.where((m) => m.statusValue == MessageStatus.sending.index).toList();

        for (final isarMsg in filteredPending) {
          final aesKey = ChatCrypto.deriveFallbackKey(isarMsg.senderId, isarMsg.receiverId);
          final encrypted = ChatCrypto.encryptMessage(isarMsg.content, aesKey);

          final payload = {
            'id': isarMsg.uuid,
            'senderId': isarMsg.senderId,
            'receiverId': isarMsg.receiverId,
            'conversationId': isarMsg.conversationId,
            'content': encrypted,
            'type': isarMsg.typeValue,
            'timestamp': isarMsg.timestamp.toIso8601String(),
          };

          _startRetryLoop(isarMsg.uuid, payload);
        }
      }
    } catch (_) {}
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
    if (event == AuthChangeEvent.signedIn || _sessionId == null) {
      _sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(100000)}';
      await prefs.setString('session_id', _sessionId!);
    }

    final String userId = session.user.id;
    final String token = session.accessToken;

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
    _socket.connect();
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_socket.connected) {
        _socket.emit('heartbeat');
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
      _backgroundMuteTimer = Timer(const Duration(seconds: 60), () {
        debugPrint('[SocketService] 60s background limit: muting microphone.');
        _socket.emit('background_state', {'state': 'background_60s'});
        try {
          RoomVoiceManager().toggleMic(false);
        } catch (_) {}
      });

      _backgroundDisconnectTimer = Timer(const Duration(minutes: 5), () {
        debugPrint('[SocketService] 5m background limit: disconnecting socket.');
        _socket.emit('background_state', {'state': 'background_5m'});
        disconnect();
      });
    } else if (state == AppLifecycleState.resumed) {
      _backgroundMuteTimer?.cancel();
      _backgroundDisconnectTimer?.cancel();
      if (!_socket.connected && Supabase.instance.client.auth.currentSession != null) {
        connect();
      }
    } else if (state == AppLifecycleState.detached) {
      debugPrint('[SocketService] Detached state detected: leaving room.');
      _socket.emit('logout_room', {
        'roomId': RoomController.to.activeRoomId
      });
      disconnect();
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _authStateSubscription?.cancel();
    _stopHeartbeatTimer();
    _backgroundMuteTimer?.cancel();
    _backgroundDisconnectTimer?.cancel();
    super.onClose();
  }
}
