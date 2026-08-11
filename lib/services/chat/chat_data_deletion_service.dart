import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../storage/isar_storage_service.dart';
import '../../models/chat/chat_model.dart';
import '../user/user_profile_cache_manager.dart';

enum DeletionReason {
  userDeleteMessage,
  userClearChat,
  userDeleteConversation,
  serverConfirmedDelete,
  // Unauthorized / Blocked deletion attempts:
  logout,
  socketDisconnect,
  syncReconciliation,
  cacheRefresh,
  appRestart,
  profileMissing,
  networkError,
  pagination,
}

class ChatDataDeletionService extends GetxService {
  static ChatDataDeletionService get to {
    if (!Get.isRegistered<ChatDataDeletionService>()) {
      Get.put(ChatDataDeletionService(), permanent: true);
    }
    return Get.find<ChatDataDeletionService>();
  }

  /// Centralized Deletion Guard Policy Validator
  bool isDeletionAllowed(DeletionReason reason) {
    switch (reason) {
      case DeletionReason.userDeleteMessage:
      case DeletionReason.userClearChat:
      case DeletionReason.userDeleteConversation:
      case DeletionReason.serverConfirmedDelete:
        return true;

      case DeletionReason.logout:
      case DeletionReason.socketDisconnect:
      case DeletionReason.syncReconciliation:
      case DeletionReason.cacheRefresh:
      case DeletionReason.appRestart:
      case DeletionReason.profileMissing:
      case DeletionReason.networkError:
      case DeletionReason.pagination:
        debugPrint('🛡️ [DELETE GUARD DENIED] Blocked automatic deletion attempt. Reason: ${reason.name}');
        return false;
    }
  }

  /// Soft Delete Message (Sync Tombstone)
  Future<bool> softDeleteMessage({
    required String messageId,
    required String conversationId,
    required DeletionReason reason,
    String? deletedBy,
  }) async {
    if (!isDeletionAllowed(reason)) {
      debugPrint('🛡️ [DELETE GUARD] Deletion disallowed for messageId=$messageId');
      return false;
    }

    final currentUid = UserProfileCacheManager.currentUserId;
    final operatorId = deletedBy ?? currentUid;
    final now = DateTime.now();

    debugPrint('🗑️ [SOFT DELETE TOMBSTONE] Message $messageId in conversation $conversationId (Reason: ${reason.name})');

    try {
      // 1. Soft-delete locally in Isar
      await IsarStorageService.to.deleteMessage(messageId);

      // 2. Publish soft-delete tombstone record to Supabase backend if user-initiated
      if (reason == DeletionReason.userDeleteMessage && operatorId.isNotEmpty) {
        try {
          await Supabase.instance.client.from('message_tombstones').upsert({
            'message_id': messageId,
            'conversation_id': conversationId,
            'deleted_by': operatorId,
            'deleted_at': now.toIso8601String(),
            'deletion_type': 'SOFT_DELETE',
          });
        } catch (e) {
          debugPrint('⚠️ [TOMBSTONE SYNC] Failed to publish tombstone to Supabase (offline?): $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('❌ [SOFT DELETE ERROR] Failed to soft delete message $messageId: $e');
      return false;
    }
  }

  /// Explicit Conversation Delete (User Action Only)
  Future<bool> deleteConversationExplicitly({
    required String conversationId,
    required DeletionReason reason,
  }) async {
    if (!isDeletionAllowed(reason)) {
      debugPrint('🛡️ [DELETE GUARD DENIED] Cannot delete conversation $conversationId for reason: ${reason.name}');
      return false;
    }

    try {
      await IsarStorageService.to.deleteConversation(conversationId);
      debugPrint('🗑️ [EXPLICIT DELETE] Conversation $conversationId deleted explicitly.');
      return true;
    } catch (e) {
      debugPrint('❌ [DELETE ERROR] Failed to delete conversation $conversationId: $e');
      return false;
    }
  }
}
