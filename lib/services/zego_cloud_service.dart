import 'package:get/get.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import 'dart:math';
import 'zego_config.dart';

class ZegoCloudService {
  static final ZegoCloudService _instance = ZegoCloudService._internal();

  factory ZegoCloudService() {
    return _instance;
  }

  ZegoCloudService._internal();

  ZegoUser _currentUser = ZegoUser('', '');
  bool _isInRoom = false;
  bool _isMicEnabled = false;
  bool _isCameraEnabled = false;
  String _currentRoomId = '';
  int _membersCount = 1;

  final RxList<ZegoUser> roomUsers = <ZegoUser>[].obs;

  /// Initialize ZEGOCLOUD Express Engine
  Future<void> init() async {
    try {
      ZegoEngineProfile profile = ZegoEngineProfile(
        ZegoConfig.appId,
        ZegoScenario.StandardVoiceCall,
        appSign: '', // empty to use token authentication in production
      );
      await ZegoExpressEngine.createEngineWithProfile(profile);
      
      // Setup event callbacks
      ZegoExpressEngine.onRoomUserUpdate = (roomId, updateType, userList) {
        if (updateType == ZegoUpdateType.Add) {
          for (var user in userList) {
            if (!roomUsers.any((u) => u.userID == user.userID)) {
              roomUsers.add(user);
            }
          }
          _membersCount = roomUsers.length;
        } else {
          for (var user in userList) {
            roomUsers.removeWhere((u) => u.userID == user.userID);
          }
          _membersCount = max(1, roomUsers.length);
        }
      };

      print('✅ ZEGOCLOUD Express Engine initialized successfully');
    } catch (e) {
      print('❌ ZEGOCLOUD Express Engine initialization error: $e');
      rethrow;
    }
  }

  /// Set user info
  void setUserInfo(String userId, String userName) {
    _currentUser = ZegoUser(userId, userName);
    print('✅ ZEGOCLOUD User info set: $userId - $userName');
  }

  /// Join a room with token
  Future<void> joinRoom({
    required String roomId,
    required bool enableMic,
    required bool enableCamera,
    required String token,
  }) async {
    try {
      _currentRoomId = roomId;
      ZegoRoomConfig config = ZegoRoomConfig.defaultConfig();
      config.token = token;
      config.isUserStatusNotify = true;

      await ZegoExpressEngine.instance.loginRoom(roomId, _currentUser, config: config);
      _isInRoom = true;
      roomUsers.clear();
      roomUsers.add(_currentUser);
      _membersCount = 1; // reset count upon entering new room

      // Audio & Video state initialization
      await ZegoExpressEngine.instance.muteMicrophone(!enableMic);
      _isMicEnabled = enableMic;

      await ZegoExpressEngine.instance.enableCamera(enableCamera);
      _isCameraEnabled = enableCamera;

      print('✅ ZEGOCLOUD Joined room: $roomId with token');
    } catch (e) {
      print('❌ ZEGOCLOUD Error joining room: $e');
      rethrow;
    }
  }

  /// Renew token in active room
  Future<void> renewToken(String token) async {
    try {
      await ZegoExpressEngine.instance.renewToken(_currentRoomId, token);
      print('✅ ZEGOCLOUD token renewed successfully');
    } catch (e) {
      print('❌ ZEGOCLOUD Error renewing token: $e');
    }
  }

  /// Leave room
  Future<void> leaveRoom() async {
    try {
      if (_isInRoom) {
        await ZegoExpressEngine.instance.logoutRoom(_currentRoomId);
        _isInRoom = false;
        _currentRoomId = '';
        _membersCount = 1;
      }
      print('✅ ZEGOCLOUD Left room');
    } catch (e) {
      print('❌ ZEGOCLOUD Error leaving room: $e');
      rethrow;
    }
  }

  /// Toggle microphone
  void toggleMic(bool isOn) async {
    try {
      await ZegoExpressEngine.instance.muteMicrophone(!isOn);
      _isMicEnabled = isOn;
      print('🎤 ZEGOCLOUD Microphone: ${isOn ? 'ON' : 'OFF'}');
    } catch (e) {
      print('❌ ZEGOCLOUD Error toggling mic: $e');
    }
  }

  /// Toggle camera
  void toggleCamera(bool isOn) async {
    try {
      await ZegoExpressEngine.instance.enableCamera(isOn);
      _isCameraEnabled = isOn;
      print('📹 ZEGOCLOUD Camera: ${isOn ? 'ON' : 'OFF'}');
    } catch (e) {
      print('❌ ZEGOCLOUD Error toggling camera: $e');
    }
  }

  /// Get current room state
  bool isInRoom() {
    return _isInRoom;
  }

  /// Get microphone state
  bool isMicOn() {
    return _isMicEnabled;
  }

  /// Get camera state
  bool isCameraOn() {
    return _isCameraEnabled;
  }

  /// Get room members count
  int getRoomMembersCount() {
    return _membersCount;
  }

  /// Dispose/cleanup
  Future<void> dispose() async {
    try {
      await leaveRoom();
      await ZegoExpressEngine.destroyEngine();
      print('✅ ZEGOCLOUD Express Engine destroyed');
    } catch (e) {
      print('❌ ZEGOCLOUD Error during cleanup: $e');
    }
  }
}
