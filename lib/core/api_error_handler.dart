import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiErrorHandler {
  /// Converts any exception, PostgrestException, AuthException, or HTML error string
  /// into a clean, concise, human-readable user message.
  static String parseError(dynamic error) {
    if (error == null) return 'An unexpected error occurred.';
    
    final errStr = error.toString();
    
    // 1. Detect HTML server error pages (e.g., 502 Bad Gateway / 503 Service Unavailable)
    final lowerErr = errStr.toLowerCase();
    if (lowerErr.contains('<!doctype') || lowerErr.contains('<html') || lowerErr.contains('<meta') || lowerErr.contains('502 bad gateway') || lowerErr.contains('503 service unavailable')) {
      return 'Server connection temporary issue. Your changes were saved locally.';
    }

    // 2. PostgrestException parsing
    if (error is PostgrestException) {
      final msg = error.message.trim();
      if (msg.isNotEmpty) {
        if (msg.contains('JWSError') || msg.contains('JWT expired') || msg.contains('invalid claim')) {
          return 'Session expired. Refreshing your credentials...';
        }
        if (msg.contains('record_membership_purchase')) {
          return 'Membership update error. Please try again.';
        }
        if (msg.contains('duplicate key') || msg.contains('unique constraint')) {
          return 'Action already completed.';
        }
        return msg;
      }
    }

    // 3. AuthException parsing
    if (error is AuthException) {
      final msg = error.message.trim();
      if (msg.isNotEmpty) return msg;
    }

    // 4. Socket or Network Exceptions
    if (error is SocketException || errStr.contains('SocketException') || errStr.contains('Failed host lookup') || errStr.contains('NetworkImage') || errStr.contains('Connection refused')) {
      return 'Network connection issue. Please check your connection and retry.';
    }

    if (error is TimeoutException || errStr.contains('TimeoutException')) {
      return 'Request timed out. Please try again.';
    }

    // 5. Clean up string if raw postgres error or exception
    String cleanMsg = errStr
        .replaceAll(RegExp(r'PostgrestException\(.*message:\s*'), '')
        .replaceAll(RegExp(r'Exception:\s*'), '')
        .replaceAll(RegExp(r'\{.*\}'), '')
        .trim();

    if (cleanMsg.length > 120) {
      cleanMsg = '${cleanMsg.substring(0, 120)}...';
    }

    return cleanMsg.isNotEmpty ? cleanMsg : 'Unable to complete request. Please try again.';
  }

  /// Executes an asynchronous API action with exponential backoff retries and session auto-refresh.
  static Future<T> executeWithRetry<T>(
    Future<T> Function() action, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (true) {
      attempt++;
      try {
        return await action();
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final isAuthErr = errStr.contains('jwt') || errStr.contains('session') || errStr.contains('unauthorized') || errStr.contains('401');

        if (isAuthErr && attempt <= maxRetries) {
          try {
            debugPrint('[ApiErrorHandler] Auth session issue detected. Attempting token refresh...');
            await Supabase.instance.client.auth.refreshSession();
          } catch (refreshErr) {
            debugPrint('[ApiErrorHandler] Session refresh failed: $refreshErr');
          }
        }

        if (attempt >= maxRetries) {
          debugPrint('[ApiErrorHandler] Exhausted $maxRetries retries. Final error: $e');
          rethrow;
        }

        debugPrint('[ApiErrorHandler] Action failed (Attempt $attempt/$maxRetries). Retrying in ${delay.inMilliseconds}ms... Error: $e');
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff: 500ms, 1000ms, 2000ms
      }
    }
  }
}
