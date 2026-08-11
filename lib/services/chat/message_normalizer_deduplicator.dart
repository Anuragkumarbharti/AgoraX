import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../models/chat/chat_model.dart';
import '../../models/chat/isar_chat_model.dart';
import '../../core/chat_crypto.dart';
import '../storage/isar_storage_service.dart';
import '../../utils/secure_dto_sanitizer.dart';
import '../user/user_profile_cache_manager.dart';

class MessageNormalizerDeduplicator {
  static final LinkedHashSet<String> _seenMessageIds = LinkedHashSet<String>();
  static final LinkedHashSet<String> _seenClientMessageIds = LinkedHashSet<String>();
  static final LinkedHashSet<String> _seenInviteIds = LinkedHashSet<String>();
  static const int _maxCacheSize = 500;

  static void _recordSeen(String? msgId, String? clientMsgId, String? inviteId) {
    if (msgId != null && msgId.isNotEmpty) {
      if (_seenMessageIds.length >= _maxCacheSize) _seenMessageIds.remove(_seenMessageIds.first);
      _seenMessageIds.add(msgId);
    }
    if (clientMsgId != null && clientMsgId.isNotEmpty) {
      if (_seenClientMessageIds.length >= _maxCacheSize) _seenClientMessageIds.remove(_seenClientMessageIds.first);
      _seenClientMessageIds.add(clientMsgId);
    }
    if (inviteId != null && inviteId.isNotEmpty) {
      if (_seenInviteIds.length >= _maxCacheSize) _seenInviteIds.remove(_seenInviteIds.first);
      _seenInviteIds.add(inviteId);
    }
  }

  /// 1. MESSAGE NORMALIZER
  /// Converts raw Map or payload from Socket/API/Push into a normalized ChatMessage.
  static ChatMessage normalizePayload(Map<String, dynamic> rawPayload, {required String currentUserId}) {
    final String id = rawPayload['id']?.toString() ?? rawPayload['uuid']?.toString() ?? ChatMessage.getDeterministicConversationId(currentUserId, rawPayload['sender_id']?.toString() ?? '');
    final String? clientMsgId = rawPayload['clientMessageId']?.toString() ?? rawPayload['client_message_id']?.toString();
    final String? inviteId = rawPayload['inviteId']?.toString() ?? rawPayload['invite_id']?.toString();
    final String senderId = rawPayload['senderId']?.toString() ?? rawPayload['sender_id']?.toString() ?? '';
    final String receiverId = rawPayload['receiverId']?.toString() ?? rawPayload['receiver_id']?.toString() ?? '';
    final String rawContent = rawPayload['content']?.toString() ?? rawPayload['encrypted_content']?.toString() ?? '';
    final String mediaTypeStr = rawPayload['media_type']?.toString() ?? rawPayload['type_str']?.toString() ?? 'text';
    final int typeVal = int.tryParse(rawPayload['type']?.toString() ?? '-1') ?? -1;

    MessageType matchedType;
    if (typeVal >= 0 && typeVal < MessageType.values.length) {
      matchedType = MessageType.values[typeVal];
    } else {
      matchedType = MessageType.values.firstWhere(
        (e) => e.name == mediaTypeStr,
        orElse: () => MessageType.text,
      );
    }

    // Decrypt if encrypted
    String decryptedContent = rawContent;
    if (senderId.isNotEmpty && receiverId.isNotEmpty && (rawContent.contains(':') || rawContent.length > 30)) {
      final aesKey = ChatCrypto.deriveFallbackKey(senderId, receiverId);
      decryptedContent = ChatCrypto.decryptMessage(rawContent, aesKey);
    }

    final cleanContent = SecureDtoSanitizer.sanitizeChatMessageContent(decryptedContent, fallback: 'Media Attachment');
    final String canonicalConvId = ChatMessage.getDeterministicConversationId(senderId, receiverId);

    final String timestampStr = rawPayload['timestamp']?.toString() ?? rawPayload['created_at']?.toString() ?? '';
    final DateTime dt = timestampStr.isNotEmpty ? (DateTime.tryParse(timestampStr) ?? DateTime.now()) : DateTime.now();

    final String? roomIdStr = rawPayload['roomId']?.toString() ?? rawPayload['room_id']?.toString() ?? rawPayload['contact_phone']?.toString();
    final String? roomNameStr = rawPayload['roomName']?.toString() ?? rawPayload['room_name']?.toString() ?? rawPayload['location_name']?.toString();

    return ChatMessage(
      id: id,
      clientMessageId: clientMsgId,
      inviteId: matchedType == MessageType.roomInvite ? inviteId : null,
      senderId: senderId,
      receiverId: receiverId,
      conversationId: canonicalConvId,
      content: cleanContent,
      type: matchedType,
      status: MessageStatus.sent,
      timestamp: dt,
      isDeleted: rawPayload['is_deleted'] == true || rawPayload['isDeleted'] == true,
      mediaUrl: rawPayload['mediaUrl']?.toString() ?? rawPayload['media_url']?.toString(),
      fileName: rawPayload['fileName']?.toString() ?? rawPayload['file_name']?.toString(),
      fileSize: rawPayload['fileSize'] != null ? (rawPayload['fileSize'] as num).toInt() : (rawPayload['file_size'] != null ? (rawPayload['file_size'] as num).toInt() : null),
      thumbnailUrl: rawPayload['thumbnailUrl']?.toString() ?? rawPayload['thumbnail']?.toString(),
      locationLat: rawPayload['locationLat'] != null ? (rawPayload['locationLat'] as num).toDouble() : (rawPayload['location_lat'] != null ? (rawPayload['location_lat'] as num).toDouble() : null),
      locationLng: rawPayload['locationLng'] != null ? (rawPayload['locationLng'] as num).toDouble() : (rawPayload['location_lng'] != null ? (rawPayload['location_lng'] as num).toDouble() : null),
      locationName: roomNameStr,
      contactName: rawPayload['contactName']?.toString() ?? rawPayload['contact_name']?.toString(),
      contactPhone: roomIdStr,
      roomId: roomIdStr,
      roomName: roomNameStr,
    );
  }

  /// 2. MESSAGE DEDUPLICATOR
  /// Checks memory cache + Isar DB for duplicate messageId, clientMessageId, or inviteId (for invites only).
  static Future<bool> isDuplicate(ChatMessage msg) async {
    if (msg.id.isNotEmpty && _seenMessageIds.contains(msg.id)) return true;
    if (msg.clientMessageId != null && msg.clientMessageId!.isNotEmpty && _seenClientMessageIds.contains(msg.clientMessageId!)) return true;
    if (msg.type == MessageType.roomInvite && msg.inviteId != null && msg.inviteId!.isNotEmpty && _seenInviteIds.contains(msg.inviteId!)) return true;

    // Check Isar DB
    final existingById = await IsarStorageService.to.getMessageByUuid(msg.id);
    if (existingById != null) {
      _recordSeen(msg.id, msg.clientMessageId, msg.inviteId);
      return true;
    }

    if (msg.clientMessageId != null && msg.clientMessageId!.isNotEmpty) {
      final existingByClient = await IsarStorageService.to.getMessageByClientMessageId(msg.clientMessageId!);
      if (existingByClient != null) {
        _recordSeen(msg.id, msg.clientMessageId, msg.inviteId);
        return true;
      }
    }

    if (msg.type == MessageType.roomInvite && msg.inviteId != null && msg.inviteId!.isNotEmpty) {
      final existingByInvite = await IsarStorageService.to.getMessageByInviteId(msg.inviteId!);
      if (existingByInvite != null) {
        _recordSeen(msg.id, msg.clientMessageId, msg.inviteId);
        return true;
      }
    }

    return false;
  }

  /// 3. PIPELINE ENTRY POINT
  /// Process raw payload -> normalize -> deduplicate -> upsert to Isar -> return normalized ChatMessage if unique.
  static Future<ChatMessage?> processIncomingPayload(Map<String, dynamic> rawPayload, {required String source}) async {
    final currentUid = UserProfileCacheManager.currentUserId;
    final msg = normalizePayload(rawPayload, currentUserId: currentUid);

    if (msg.id.isEmpty || msg.senderId.isEmpty) {
      debugPrint('⚠️ [PIPELINE] Suppressed invalid payload from $source (empty ID/sender)');
      return null;
    }

    final dup = await isDuplicate(msg);
    if (dup) {
      debugPrint('🚫 [PIPELINE DEDUP] Suppressed duplicate message from $source: id=${msg.id}, inviteId=${msg.inviteId}');
      return null;
    }

    _recordSeen(msg.id, msg.clientMessageId, msg.inviteId);

    // Save to Isar Single Source of Truth
    final isarMsg = IsarChatMessage()
      ..uuid = msg.id
      ..clientMessageId = msg.clientMessageId
      ..inviteId = msg.inviteId
      ..senderId = msg.senderId
      ..receiverId = msg.receiverId
      ..conversationId = msg.conversationId
      ..content = msg.content
      ..typeValue = msg.type.index
      ..statusValue = msg.status.index
      ..timestamp = msg.timestamp
      ..mediaUrl = msg.mediaUrl
      ..fileName = msg.fileName
      ..fileSize = msg.fileSize
      ..thumbnailUrl = msg.thumbnailUrl
      ..locationLat = msg.locationLat
      ..locationLng = msg.locationLng
      ..locationName = msg.locationName
      ..contactName = msg.contactName
      ..contactPhone = msg.contactPhone
      ..roomId = msg.roomId
      ..roomName = msg.roomName
      ..isDeleted = msg.isDeleted
      ..isEdited = false;

    await IsarStorageService.to.saveMessage(isarMsg);
    debugPrint('✅ [PIPELINE SUCCESS] Saved clean message from $source: ${msg.id} in conv ${msg.conversationId}');
    return msg;
  }
}
