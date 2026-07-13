import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'zego_config.dart';

class ZegoTokenService {
  static final ZegoTokenService _instance = ZegoTokenService._internal();
  factory ZegoTokenService() => _instance;
  ZegoTokenService._internal();

  String? _cachedToken;
  int? _cachedExpireTimestamp; // in seconds
  String? _cachedUserId;

  /// Retrieve a token, fetching a fresh one if the cached one is near expiry (5-minute buffer)
  Future<String> getToken(String userId, {bool forceRefresh = false}) async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // Check if cache is valid and has at least 5 minutes remaining
    if (!forceRefresh &&
        _cachedToken != null &&
        _cachedUserId == userId &&
        _cachedExpireTimestamp != null &&
        (_cachedExpireTimestamp! - nowSeconds) > 300) {
      debugPrint('⚡ Returning cached ZEGO token (expires in ${(_cachedExpireTimestamp! - nowSeconds)}s)');
      return _cachedToken!;
    }

    // Fetch fresh token with retry logic and exponential backoff
    int attempt = 0;
    int delayMs = 1000;
    while (attempt < 3) {
      try {
        debugPrint('🌐 Fetching ZEGO token from Supabase Edge Function (Attempt ${attempt + 1})...');
        final response = await Supabase.instance.client.functions.invoke(
          ZegoConfig.functionName,
          body: {'userId': userId},
        );

        if (response.status == 200) {
          final data = response.data as Map<String, dynamic>;
          final token = data['token'] as String;
          final expire = data['expire'] as int;

          _cachedToken = token;
          _cachedExpireTimestamp = expire;
          _cachedUserId = userId;

          debugPrint('✅ ZEGO token generated successfully (expires at $expire)');
          return token;
        } else {
          throw Exception('Edge function returned status ${response.status}: ${response.data}');
        }
      } catch (e) {
        attempt++;
        debugPrint('⚠️ ZEGO token fetch failed (Attempt $attempt): $e');
        if (attempt >= 3) {
          throw Exception('Failed to fetch ZEGO token after 3 attempts: $e');
        }
        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs *= 2; // Exponential backoff
      }
    }
    throw Exception('Failed to fetch ZEGO token');
  }

  /// Manually clear cached token info
  void clearCache() {
    _cachedToken = null;
    _cachedExpireTimestamp = null;
    _cachedUserId = null;
  }
}
