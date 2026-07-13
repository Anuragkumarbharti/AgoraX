import 'dart:async';
import 'package:flutter/foundation.dart';
import 'zego_cloud_service.dart';
import 'zego_token_service.dart';

class CustomZegoRoomService {
  static final CustomZegoRoomService _instance = CustomZegoRoomService._internal();
  factory CustomZegoRoomService() => _instance;
  CustomZegoRoomService._internal();

  final ZegoCloudService _zegoCloudService = ZegoCloudService();
  final ZegoTokenService _zegoTokenService = ZegoTokenService();

  Timer? _tokenRefreshTimer;
  String? _currentRoomId;
  String? _currentUserId;
  String? _lastRenewedToken;

  /// Join a voice room securely using Token Authentication
  Future<void> joinVoiceRoom({
    required String roomId,
    required String userId,
    required String userName,
    required bool enableMic,
    required bool enableCamera,
  }) async {
    try {
      _currentRoomId = roomId;
      _currentUserId = userId;

      // 1. Initialize Zego
      await _zegoCloudService.init();

      // 2. Set user info
      _zegoCloudService.setUserInfo(userId, userName);

      // 3. Fetch token from token service (force refresh on fresh join)
      final token = await _zegoTokenService.getToken(userId, forceRefresh: true);
      _lastRenewedToken = token;

      // 4. Join the room using low-level service
      await _zegoCloudService.joinRoom(
        roomId: roomId,
        enableMic: enableMic,
        enableCamera: enableCamera,
        token: token,
      );

      // 5. Start background auto-refresh timer
      _startTokenRefreshTimer();
    } catch (e) {
      debugPrint('❌ Error in ZegoRoomService.joinVoiceRoom: $e');
      rethrow;
    }
  }

  /// Leave the active room and stop background refresh timers
  Future<void> leaveVoiceRoom() async {
    try {
      _stopTokenRefreshTimer();
      await _zegoCloudService.leaveRoom();
      _currentRoomId = null;
      _currentUserId = null;
      _lastRenewedToken = null;
    } catch (e) {
      debugPrint('❌ Error in ZegoRoomService.leaveVoiceRoom: $e');
      rethrow;
    }
  }

  /// Start repeating timer to monitor token expiry and renew if needed
  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = Timer.periodic(const Duration(seconds: 45), (timer) async {
      if (_currentRoomId == null || _currentUserId == null) {
        _stopTokenRefreshTimer();
        return;
      }

      try {
        // getToken checks expiration buffer. If near expiry (within 5 mins), it fetches a new one.
        final token = await _zegoTokenService.getToken(_currentUserId!);
        if (token != _lastRenewedToken) {
          await _zegoCloudService.renewToken(token);
          _lastRenewedToken = token;
          debugPrint('🔄 ZegoRoomService: Token renewed successfully in active room session');
        }
      } catch (e) {
        debugPrint('⚠️ ZegoRoomService: Background token refresh failed: $e');
      }
    });
  }

  void _stopTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }
}
