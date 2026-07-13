import 'package:zego_uikit/zego_uikit.dart';
import 'zego_config.dart';

class ZegoCloudService {
  static final ZegoCloudService _instance = ZegoCloudService._internal();

  factory ZegoCloudService() {
    return _instance;
  }

  ZegoCloudService._internal();

  /// Initialize ZEGOCLOUD with empty appSign (for Token Authentication)
  Future<void> init() async {
    try {
      await ZegoUIKit.instance.init(
        appID: ZegoConfig.appId,
        appSign: '', // Set empty to use token authentication in production
      );
      print('✅ ZEGOCLOUD initialized successfully (Token Mode)');
    } catch (e) {
      print('❌ ZEGOCLOUD initialization error: $e');
      rethrow;
    }
  }

  /// Set user info
  void setUserInfo(String userId, String userName) {
    try {
      ZegoUIKit.instance.login(userId, userName);
      print('✅ User info set: $userId - $userName');
    } catch (e) {
      print('❌ Error setting user info: $e');
    }
  }

  /// Join a room with token
  Future<void> joinRoom({
    required String roomId,
    required bool enableMic,
    required bool enableCamera,
    required String token,
  }) async {
    try {
      await ZegoUIKit.instance.joinRoom(roomId, token: token);
      ZegoUIKit.instance.turnMicrophoneOn(enableMic);
      ZegoUIKit.instance.turnCameraOn(enableCamera);
      print('✅ Joined room: $roomId with token');
    } catch (e) {
      print('❌ Error joining room: $e');
      rethrow;
    }
  }

  /// Renew token in active room
  Future<void> renewToken(String token) async {
    try {
      await ZegoUIKit.instance.renewRoomToken(token);
      print('✅ ZEGOCLOUD token renewed successfully');
    } catch (e) {
      print('❌ Error renewing ZEGOCLOUD token: $e');
    }
  }

  /// Leave room
  Future<void> leaveRoom() async {
    try {
      await ZegoUIKit.instance.leaveRoom();
      print('✅ Left room');
    } catch (e) {
      print('❌ Error leaving room: $e');
      rethrow;
    }
  }

  /// Toggle microphone
  void toggleMic(bool isOn) {
    try {
      ZegoUIKit.instance.turnMicrophoneOn(isOn);
      print('🎤 Microphone: ${isOn ? 'ON' : 'OFF'}');
    } catch (e) {
      print('❌ Error toggling mic: $e');
    }
  }

  /// Toggle camera
  void toggleCamera(bool isOn) {
    try {
      ZegoUIKit.instance.turnCameraOn(isOn);
      print('📹 Camera: ${isOn ? 'ON' : 'OFF'}');
    } catch (e) {
      print('❌ Error toggling camera: $e');
    }
  }

  /// Get current room state
  bool isInRoom() {
    try {
      return ZegoUIKit.instance.getRoom().id.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Get microphone state
  bool isMicOn() {
    try {
      return ZegoUIKit.instance.getLocalUser().microphone.value;
    } catch (_) {
      return false;
    }
  }

  /// Get camera state
  bool isCameraOn() {
    try {
      return ZegoUIKit.instance.getLocalUser().camera.value;
    } catch (_) {
      return false;
    }
  }

  /// Get room members count
  int getRoomMembersCount() {
    try {
      return ZegoUIKit.instance.getRemoteUsers().length + 1; // +1 for current user
    } catch (_) {
      return 1;
    }
  }

  /// Dispose/cleanup
  Future<void> dispose() async {
    try {
      await ZegoUIKit.instance.leaveRoom();
      print('✅ ZEGOCLOUD cleaned up');
    } catch (e) {
      print('❌ Error during cleanup: $e');
    }
  }
}
