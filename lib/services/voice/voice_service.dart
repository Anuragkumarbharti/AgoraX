import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import 'voice_controller.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  bool _isEngineCreated = false;
  bool get isEngineCreated => _isEngineCreated;

  /// Initialize ZEGO Engine (only once) (STEP 4)
  Future<void> createEngine(int appId) async {
    if (_isEngineCreated) {
      debugPrint('[VoiceService] Engine already created. Skipping.');
      return;
    }
    
    debugPrint('[VoiceService] Initializing ZEGO Express SDK (AppID: $appId)...');
    ZegoEngineProfile profile = ZegoEngineProfile(
      appId,
      ZegoScenario.StandardVoiceCall,
      appSign: '', // Never store AppSign in Flutter, use token auth
    );
    
    await ZegoExpressEngine.createEngineWithProfile(profile);
    _isEngineCreated = true;

    // Apply Premium Audio Configurations (STEP 6)
    await ZegoExpressEngine.instance.enableAEC(true); // Echo Cancellation
    await ZegoExpressEngine.instance.enableANS(true); // Noise Suppression
    await ZegoExpressEngine.instance.enableAGC(true); // Automatic Gain Control
    
    // Configure stable bitrate & sample rate
    ZegoAudioConfig audioConfig = ZegoAudioConfig(48000, ZegoAudioChannel.Mono, ZegoAudioCodecID.Default);
    await ZegoExpressEngine.instance.setAudioConfig(audioConfig);

    // Audio routing default
    await ZegoExpressEngine.instance.setAudioRouteToSpeaker(true);

    // Start sound level monitor for Voice Activity / Speaking status tracking
    await ZegoExpressEngine.instance.startSoundLevelMonitor();
    
    // Setup event callbacks (STEP 10)
    _setupEventCallbacks();

    debugPrint('[VoiceService] Engine initialized successfully with Premium Audio profiles.');
  }

  /// Destroy the engine properly on logout (STEP 4)
  Future<void> destroyEngine() async {
    if (!_isEngineCreated) return;
    debugPrint('[VoiceService] Destroying ZEGO Engine...');
    await ZegoExpressEngine.instance.stopSoundLevelMonitor();
    await ZegoExpressEngine.destroyEngine();
    _isEngineCreated = false;
  }

  /// Log in to ZEGO room
  Future<void> loginRoom(String roomId, String token) async {
    if (!_isEngineCreated) throw Exception('Engine is not initialized');
    
    ZegoRoomConfig config = ZegoRoomConfig.defaultConfig();
    config.token = token;
    config.isUserStatusNotify = true;
    config.maxMemberCount = 100;

    final controller = Get.find<VoiceController>();
    final user = ZegoUser(controller.currentUserId.value, controller.currentUserName.value);
    
    debugPrint('[VoiceService] Logging in to room $roomId...');
    await ZegoExpressEngine.instance.loginRoom(roomId, user, config: config);
  }

  /// Log out from room
  Future<void> logoutRoom(String roomId) async {
    if (!_isEngineCreated) return;
    debugPrint('[VoiceService] Logging out of room $roomId...');
    await ZegoExpressEngine.instance.logoutRoom(roomId);
  }

  /// Start publishing local mic stream (STEP 5)
  Future<void> startPublishing(String streamId) async {
    if (!_isEngineCreated) return;
    debugPrint('[VoiceService] Publishing local audio stream: $streamId');
    await ZegoExpressEngine.instance.enableAudioCaptureDevice(true);
    await ZegoExpressEngine.instance.muteMicrophone(false);
    await ZegoExpressEngine.instance.startPublishingStream(streamId);
    
    final controller = Get.find<VoiceController>();
    controller.publishedStreamId.value = streamId;
    controller.isMicEnabled.value = true;
  }

  /// Stop publishing local mic stream (STEP 5)
  Future<void> stopPublishing() async {
    if (!_isEngineCreated) return;
    debugPrint('[VoiceService] Stopping local stream publishing...');
    await ZegoExpressEngine.instance.stopPublishingStream();
    await ZegoExpressEngine.instance.muteMicrophone(true);
    
    final controller = Get.find<VoiceController>();
    controller.publishedStreamId.value = '';
    controller.isMicEnabled.value = false;
  }

  /// Toggle microphone (software level mute/unmute)
  Future<void> setMicrophoneMute(bool isMuted) async {
    if (!_isEngineCreated) return;
    debugPrint('[VoiceService] Setting mic mute state: $isMuted');
    await ZegoExpressEngine.instance.muteMicrophone(isMuted);
    
    final controller = Get.find<VoiceController>();
    controller.isMicEnabled.value = !isMuted;
  }

  /// Force speaker output routing (STEP 8)
  Future<void> setAudioRouteToSpeaker(bool useSpeaker) async {
    if (!_isEngineCreated) return;
    debugPrint('[VoiceService] Setting audio route to speaker: $useSpeaker');
    await ZegoExpressEngine.instance.setAudioRouteToSpeaker(useSpeaker);
  }

  /// Setup callbacks and stream listeners
  void _setupEventCallbacks() {
    ZegoExpressEngine.onRoomStateChanged = (roomId, reason, errorCode, extendedData) {
      debugPrint('[VoiceService] RoomStateChanged: room=$roomId, reason=$reason, errorCode=$errorCode');
      if (!Get.isRegistered<VoiceController>()) return;
      final controller = Get.find<VoiceController>();
      
      if (reason == ZegoRoomStateChangedReason.Logined || reason == ZegoRoomStateChangedReason.Reconnected) {
        controller.roomState.value = 'connected';
      } else if (reason == ZegoRoomStateChangedReason.Logining) {
        controller.roomState.value = 'connecting';
      } else if (reason == ZegoRoomStateChangedReason.Reconnecting) {
        controller.roomState.value = 'reconnecting';
      } else {
        controller.roomState.value = 'disconnected';
      }
    };

    ZegoExpressEngine.onRoomUserUpdate = (roomId, updateType, userList) {
      debugPrint('[VoiceService] RoomUserUpdate: type=$updateType, users=${userList.map((u) => u.userID).toList()}');
      if (!Get.isRegistered<VoiceController>()) return;
      final controller = Get.find<VoiceController>();
      
      if (updateType == ZegoUpdateType.Add) {
        for (var user in userList) {
          if (!controller.roomUsers.any((u) => u.userID == user.userID)) {
            controller.roomUsers.add(user);
          }
        }
      } else {
        for (var user in userList) {
          controller.roomUsers.removeWhere((u) => u.userID == user.userID);
          controller.userSoundLevels.remove(user.userID);
        }
      }
    };

    ZegoExpressEngine.onRoomStreamUpdate = (roomId, updateType, streamList, extendedData) async {
      debugPrint('[VoiceService] RoomStreamUpdate: type=$updateType, streams=${streamList.map((s) => s.streamID).toList()}');
      if (!Get.isRegistered<VoiceController>()) return;
      final controller = Get.find<VoiceController>();
      
      if (updateType == ZegoUpdateType.Add) {
        for (var stream in streamList) {
          if (stream.user.userID == controller.currentUserId.value) {
            continue; // Ignore our own published stream
          }
          debugPrint('[VoiceService] Playing remote stream: ${stream.streamID}');
          await ZegoExpressEngine.instance.startPlayingStream(stream.streamID);
        }
      } else {
        for (var stream in streamList) {
          debugPrint('[VoiceService] Stopping remote stream: ${stream.streamID}');
          await ZegoExpressEngine.instance.stopPlayingStream(stream.streamID);
          final parts = stream.streamID.split('_');
          if (parts.length >= 2) {
            final userId = parts.sublist(1).join('_');
            controller.userSoundLevels.remove(userId);
          }
        }
      }
    };

    ZegoExpressEngine.onPublisherStateUpdate = (streamId, state, errorCode, extendedData) {
      debugPrint('[VoiceService] PublisherStateUpdate: streamId=$streamId, state=$state, errorCode=$errorCode');
    };

    ZegoExpressEngine.onPlayerStateUpdate = (streamId, state, errorCode, extendedData) {
      debugPrint('[VoiceService] PlayerStateUpdate: streamId=$streamId, state=$state, errorCode=$errorCode');
    };

    ZegoExpressEngine.onCapturedSoundLevelUpdate = (soundLevel) {
      if (!Get.isRegistered<VoiceController>()) return;
      final controller = Get.find<VoiceController>();
      if (controller.roomState.value == 'connected') {
        controller.userSoundLevels[controller.currentUserId.value] = soundLevel;
      }
    };

    ZegoExpressEngine.onRemoteSoundLevelUpdate = (soundLevels) {
      if (!Get.isRegistered<VoiceController>()) return;
      final controller = Get.find<VoiceController>();
      if (controller.roomState.value == 'connected') {
        soundLevels.forEach((streamId, soundLevel) {
          final parts = streamId.split('_');
          if (parts.length >= 2) {
            final userId = parts.sublist(1).join('_');
            controller.userSoundLevels[userId] = soundLevel;
          }
        });
      }
    };
  }
}
