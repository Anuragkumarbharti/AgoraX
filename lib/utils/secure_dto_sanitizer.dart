import 'package:flutter/foundation.dart';

/// Secure Backend -> Frontend Communication & DTO Sanitization Layer.
/// Ensures frontend functions purely as a presentation layer:
/// - Strips database schemas, table names, stack traces, server IDs, and raw payloads.
/// - Masks ciphertext/encrypted data with user-friendly fallbacks.
/// - Cleans push and realtime notification titles and bodies.
class SecureDtoSanitizer {
  SecureDtoSanitizer._();

  // Common patterns for encrypted text, JSON objects, and raw backend errors
  static final RegExp _ciphertextRegex = RegExp(r'^(gAAAAA|[A-Za-z0-9+/=]{40,})');
  static final RegExp _backendErrorRegex = RegExp(
    r'(PostgrestException|PGRST\d+|DatabaseError|SQLState|stack_trace|public\.\w+|schema_cache|InternalServerError)',
    caseSensitive: false,
  );

  /// Sanitize Notification Title
  static String sanitizeNotificationTitle(dynamic title, {String fallback = 'New Notification'}) {
    if (title == null) return fallback;
    final str = title.toString().trim();
    if (str.isEmpty || isEncryptedOrRawJson(str) || containsBackendDetails(str)) {
      return fallback;
    }
    return str;
  }

  /// Sanitize Notification Body
  static String sanitizeNotificationBody(dynamic body, {String fallback = 'New message received'}) {
    if (body == null) return fallback;
    final str = body.toString().trim();
    if (str.isEmpty || isEncryptedOrRawJson(str) || containsBackendDetails(str)) {
      return fallback;
    }
    return str;
  }

  /// Detects if a string is raw JSON, encrypted ciphertext, or serialized object
  static bool isEncryptedOrRawJson(String text) {
    if (text.startsWith('{') && text.endsWith('}')) return true;
    if (text.startsWith('[') && text.endsWith(']')) return true;
    if (_ciphertextRegex.hasMatch(text)) return true;
    return false;
  }

  /// Detects backend implementation details (SQL errors, stack traces, table names)
  static bool containsBackendDetails(String text) {
    return _backendErrorRegex.hasMatch(text);
  }

  /// Sanitizes raw Notification Map to clean DTO Map for UI consumption
  static Map<String, dynamic> sanitizeNotificationMap(Map<String, dynamic> raw) {
    final Map<String, dynamic> cleanDto = {};

    final String rawTitle = (raw['title'] ?? raw['notification_title'] ?? raw['heading'] ?? '').toString();
    final String rawBody = (raw['body'] ?? raw['notification_body'] ?? raw['message'] ?? raw['content'] ?? '').toString();

    cleanDto['id'] = (raw['id'] ?? raw['uuid'] ?? '').toString();
    cleanDto['title'] = sanitizeNotificationTitle(rawTitle, fallback: 'New Notification');
    cleanDto['body'] = sanitizeNotificationBody(rawBody, fallback: 'New message received');
    cleanDto['type'] = (raw['type'] ?? raw['notification_type'] ?? 'general').toString();
    final bool isRead = raw['is_read'] == true || raw['read'] == true || raw['read_at'] != null;
    cleanDto['is_read'] = isRead;
    cleanDto['read'] = isRead;
    cleanDto['created_at'] = (raw['created_at'] ?? raw['timestamp'] ?? DateTime.now().toIso8601String()).toString();
    cleanDto['avatar_url'] = (raw['avatar_url'] ?? raw['sender_avatar'] ?? '').toString();

    // Preserve optional safe UI payload data (e.g. target room ID or target user ID)
    if (raw.containsKey('data') && raw['data'] is Map) {
      final dataMap = raw['data'] as Map<String, dynamic>;
      cleanDto['target_id'] = (dataMap['target_id'] ?? dataMap['room_id'] ?? dataMap['user_id'] ?? '').toString();
    } else {
      cleanDto['target_id'] = (raw['target_id'] ?? raw['room_id'] ?? raw['user_id'] ?? '').toString();
    }

    return cleanDto;
  }

  /// Sanitizes Chat Message Content
  static String sanitizeChatMessageContent(String rawContent, {String fallback = 'Encrypted message'}) {
    final str = rawContent.trim();
    if (str.isEmpty) return fallback;
    if (containsBackendDetails(str)) return fallback;
    if (isEncryptedOrRawJson(str)) return fallback;
    return str;
  }

  /// Safe logging utility that masks secrets and prints only in debug mode
  static void safeLog(String tag, String message) {
    if (!kDebugMode) return;
    
    // Mask sensitive tokens/passwords if present
    String sanitized = message
        .replaceAll(RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'), '[JWT_TOKEN_MASKED]')
        .replaceAll(RegExp(r'(password|secret|bearer|token)\s*=\s*([^\s,]+)', caseSensitive: false), r'$1=[MASKED]');
        
    debugPrint('[$tag] $sanitized');
  }
}
