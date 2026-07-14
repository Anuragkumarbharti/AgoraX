import 'dart:convert';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import '../models/isar_chat_model.dart';
import '../core/chat_crypto.dart';
import 'isar_storage_service.dart';
import 'chat_controller.dart';

class ChatSocketService extends GetxService {
  static ChatSocketService get to => Get.find();

  late IO.Socket _socket;
  final RxBool isConnected = false.obs;

  // Change this to your production Northflank service endpoint or local test IP
  static const String _serverUrl = 'http://152.67.10.10:3000'; 

  void init() {
    final String currentUserId = Supabase.instance.client.auth.currentUser?.id ?? 'uid_anurag_101';

    _socket = IO.io(
      _serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setQuery({'userId': currentUserId})
          .build(),
    );

    _socket.onConnect((_) {
      isConnected.value = true;
      _onConnected();
    });

    _socket.onDisconnect((_) {
      isConnected.value = false;
    });

    // ─── Event Observers ───

    // 1. Message Relayed from Server
    _socket.on('receive_message', (data) async {
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

        // Emit Delivery ACK to Socket.IO immediately so the server deletes the message from Redis queue
        _socket.emit('delivery_ack', {
          'messageId': msgUuid,
          'senderId': senderId,
          'receiverId': receiverId,
        });
      } catch (_) {}
    });

    // 2. Delivery Acknowledged
    _socket.on('delivery_ack', (data) async {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String msgUuid = payload['messageId'] ?? '';
        
        // Update status locally in Isar
        await IsarStorageService.to.updateMessageStatus(msgUuid, MessageStatus.delivered.index);

        // Update in active GetX Controller memory stream
        Get.find<ChatController>().updateMessageStatus(msgUuid, MessageStatus.delivered);
      } catch (_) {}
    });

    // 3. Read Acknowledged
    _socket.on('read_ack', (data) async {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String msgUuid = payload['messageId'] ?? '';

        await IsarStorageService.to.updateMessageStatus(msgUuid, MessageStatus.read.index);
        Get.find<ChatController>().updateMessageStatus(msgUuid, MessageStatus.read);
      } catch (_) {}
    });

    // 4. Typing indicators
    _socket.on('typing_state', (data) {
      try {
        final payload = Map<String, dynamic>.from(data);
        final String conversationId = payload['conversationId'] ?? '';
        final bool isTyping = payload['isTyping'] ?? false;

        Get.find<ChatController>().setTypingFromSocket(conversationId, isTyping);
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
    // 1. Encrypt plaintext payload client-side before transmission
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

    if (isConnected.value) {
      // Direct relay
      _socket.emit('send_message', payload);
    } else {
      // Remains as pending in Isar local DB until next reconnect
    }
  }

  /// Relay typing indicator
  void emitTypingState(String conversationId, bool isTyping) {
    if (!isConnected.value) return;
    _socket.emit('typing_state', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
  }

  /// Relay read receipts
  void emitReadReceipt(String conversationId, String otherUserId) {
    if (!isConnected.value) return;
    _socket.emit('read_ack', {
      'conversationId': conversationId,
      'receiverId': otherUserId,
    });
  }

  /// Drain pending (sending status) messages on reconnect
  Future<void> _onConnected() async {
    try {
      // Find all conversations and messages with statusValue = MessageStatus.sending.index
      final allConvs = await IsarStorageService.to.getAllConversations();
      for (final conv in allConvs) {
        final pendingMsgs = await IsarStorageService.to.getMessagesForConversation(conv.uuid, limit: 100);
        final filteredPending = pendingMsgs.where((m) => m.statusValue == MessageStatus.sending.index).toList();

        for (final isarMsg in filteredPending) {
          // Encrypt and relay
          final aesKey = ChatCrypto.deriveFallbackKey(isarMsg.senderId, isarMsg.receiverId);
          final encrypted = ChatCrypto.encryptMessage(isarMsg.content, aesKey);

          _socket.emit('send_message', {
            'id': isarMsg.uuid,
            'senderId': isarMsg.senderId,
            'receiverId': isarMsg.receiverId,
            'conversationId': isarMsg.conversationId,
            'content': encrypted,
            'type': isarMsg.typeValue,
            'timestamp': isarMsg.timestamp.toIso8601String(),
          });
        }
      }
    } catch (_) {}
  }
}
