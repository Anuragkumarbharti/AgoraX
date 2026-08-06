import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import './voice_service.dart';
import './voice_repository.dart';
import './voice_controller.dart';
import './permission_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class RoomVoiceManager {
  static final RoomVoiceManager _instance = RoomVoiceManager._internal();
  factory RoomVoiceManager() => _instance;
  RoomVoiceManager._internal();

  final VoiceService _voiceService = VoiceService();
  final VoiceRepository _voiceRepo = VoiceRepository();
  final PermissionManager _permManager = PermissionManager();

  Timer? _tokenRenewTimer;
  String? _activeRoomId;
  String? _activeUserId;
  String? _activeUserName;

  // Cache token variables to prevent repeated token fetching (under 2 hour expiry)
  String? _cachedToken;
  DateTime? _cachedTokenExpiry;
  int? _cachedAppId;
  String? _cachedTokenUserId;

  /// Helper to retry an operation with exponential backoff
  Future<T> _retryWithBackoff<T>(
    Future<T> Function() action, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await action();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          rethrow;
        }
        final delay = initialDelay * (pow(2, attempt) as int);
        debugPrint('[RoomVoiceManager] Action failed: $e. Retrying in ${delay.inMilliseconds}ms (Attempt $attempt/$maxRetries)...');
        await Future.delayed(delay);
      }
    }
  }

  /// Preload ZEGOCLOUD engine and fetch token in the background (after user login/app start)
  Future<void> preloadEngine(String userId) async {
    if (userId.trim().isEmpty) return;
    try {
      debugPrint('[RoomVoiceManager] Background engine preload started for user $userId...');
      
      final tokenData = await _voiceRepo.fetchVoiceToken(userId);
      _cachedAppId = tokenData['appId'] as int;
      _cachedToken = tokenData['token'] as String;
      // Cache token for 90 minutes
      _cachedTokenExpiry = DateTime.now().add(const Duration(minutes: 90));
      _cachedTokenUserId = userId;

      await _voiceService.createEngine(_cachedAppId!);
      debugPrint('[RoomVoiceManager] Background engine preload completed successfully.');
    } catch (e) {
      debugPrint('[RoomVoiceManager] Background engine preload failed: $e');
    }
  }

  /// Join a voice room securely (STEP 5)
  Future<void> joinRoom({
    required String roomId,
    required String userId,
    required String userName,
    required bool enableMic,
  }) async {
    try {
      // Rule 6: Disconnect previous voice channel if user was in another room
      if (_activeRoomId != null && _activeRoomId != roomId) {
        debugPrint('[RoomVoiceManager] Disconnecting previous room voice stream $_activeRoomId before joining $roomId');
        await leaveRoom();
      }

      debugPrint('[RoomVoiceManager] Joining Room $roomId...');
      _activeRoomId = roomId;
      _activeUserId = userId;
      _activeUserName = userName;

      // 1. Fetch mic permission only if mic is enabled (saving time for guests/listeners)
      if (enableMic) {
        final hasPerm = await _permManager.checkMicrophonePermission();
        if (!hasPerm) {
          final status = await _permManager.requestMicrophonePermission();
          if (!status.isGranted) {
            throw Exception('Microphone permission required to join stage');
          }
        }
      }

      // 2. Fetch token and AppID (check cache first to avoid repeated API requests)
      int appId;
      String token;

      if (_cachedToken != null &&
          _cachedAppId != null &&
          _cachedTokenUserId == userId &&
          _cachedTokenExpiry != null &&
          _cachedTokenExpiry!.isAfter(DateTime.now())) {
        appId = _cachedAppId!;
        token = _cachedToken!;
        debugPrint('[RoomVoiceManager] Token cache hit. Reusing cached token.');
      } else {
        debugPrint('[RoomVoiceManager] Token cache miss or expired. Fetching token...');
        final tokenData = await _voiceRepo.fetchVoiceToken(userId);
        appId = tokenData['appId'] as int;
        token = tokenData['token'] as String;

        // Update Cache
        _cachedAppId = appId;
        _cachedToken = token;
        _cachedTokenExpiry = DateTime.now().add(const Duration(minutes: 90));
        _cachedTokenUserId = userId;
      }

      // 3. Initialize Voice Controller details
      if (!Get.isRegistered<VoiceController>()) {
        Get.put(VoiceController());
      }
      final controller = VoiceController.to;
      controller.currentUserId.value = userId;
      controller.currentUserName.value = userName;
      controller.activeRoomId.value = roomId;

      // 4. Initialize engine once (STEP 4)
      await _voiceService.createEngine(appId);

      // 5. Login to ZEGO Room with retry (STEP 5)
      await _retryWithBackoff(() => _voiceService.loginRoom(roomId, token));

      // 6. Manage stage seat publishing (STEP 5)
      if (enableMic) {
        final String streamId = '${roomId}_$userId';
        await _voiceService.startPublishing(streamId);
      } else {
        await _voiceService.stopPublishing();
      }

      // 7. Start periodic token renewal timer (STEP 9)
      _startTokenRenewTimer();
      debugPrint('[RoomVoiceManager] Joined room successfully.');
    } catch (e) {
      debugPrint('[RoomVoiceManager] Error joining voice room: $e');
      rethrow;
    }
  }

  /// Leave room and release resources (STEP 5)
  Future<void> leaveRoom() async {
    try {
      debugPrint('[RoomVoiceManager] Leaving active room session...');
      _stopTokenRenewTimer();

      if (_activeRoomId != null) {
        await _voiceService.stopPublishing();
        await _voiceService.logoutRoom(_activeRoomId!);
      }

      _activeRoomId = null;
      _activeUserId = null;
      _activeUserName = null;

      if (Get.isRegistered<VoiceController>()) {
        VoiceController.to.reset();
      }
      debugPrint('[RoomVoiceManager] Left room successfully.');
    } catch (e) {
      debugPrint('[RoomVoiceManager] Error leaving room: $e');
    }
  }

  /// Toggle microphone stage publishing
  Future<void> toggleMic(bool isOn) async {
    try {
      if (_activeRoomId == null || _activeUserId == null) return;
      if (!Get.isRegistered<VoiceController>()) return;
      
      if (isOn) {
        final String streamId = '${_activeRoomId}_$_activeUserId';
        await _voiceService.startPublishing(streamId);
      } else {
        await _voiceService.stopPublishing();
      }
    } catch (e) {
      debugPrint('[RoomVoiceManager] Error toggling microphone stream: $e');
    }
  }

  /// Force audio routing between speaker and earpiece/headset (STEP 8)
  Future<void> setAudioRouteToSpeaker(bool useSpeaker) async {
    await _voiceService.setAudioRouteToSpeaker(useSpeaker);
  }

  /// Start token renewal timer
  void _startTokenRenewTimer() {
    _tokenRenewTimer?.cancel();
    // Renew token every 30 minutes (well before the 2 hours expiry)
    _tokenRenewTimer = Timer.periodic(const Duration(minutes: 30), (timer) async {
      if (_activeRoomId == null || _activeUserId == null) {
        _stopTokenRenewTimer();
        return;
      }
      try {
        debugPrint('[RoomVoiceManager] Renewing token...');
        final tokenData = await _voiceRepo.fetchVoiceToken(_activeUserId!);
        final String token = tokenData['token'] as String;
        
        await ZegoExpressEngine.instance.renewToken(_activeRoomId!, token);
        debugPrint('[RoomVoiceManager] Token renewed successfully.');
      } catch (e) {
        debugPrint('[RoomVoiceManager] Error renewing token: $e');
      }
    });
  }

  /// Stop token renewal timer
  void _stopTokenRenewTimer() {
    _tokenRenewTimer?.cancel();
    _tokenRenewTimer = null;
  }
}
