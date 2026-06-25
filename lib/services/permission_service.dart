import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();

  factory PermissionService() {
    return _instance;
  }

  PermissionService._internal();

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      print('❌ Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Request camera permission
  Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      return status.isGranted;
    } catch (e) {
      print('❌ Error requesting camera permission: $e');
      return false;
    }
  }

  /// Request both permissions
  Future<Map<Permission, PermissionStatus>> requestVoiceRoomPermissions() async {
    try {
      final statuses = await [
        Permission.microphone,
        Permission.camera,
      ].request();
      return statuses;
    } catch (e) {
      print('❌ Error requesting permissions: $e');
      return {};
    }
  }

  /// Check if microphone permission is granted
  Future<bool> isMicrophoneGranted() async {
    try {
      final status = await Permission.microphone.status;
      return status.isGranted;
    } catch (e) {
      print('❌ Error checking microphone permission: $e');
      return false;
    }
  }

  /// Check if camera permission is granted
  Future<bool> isCameraGranted() async {
    try {
      final status = await Permission.camera.status;
      return status.isGranted;
    } catch (e) {
      print('❌ Error checking camera permission: $e');
      return false;
    }
  }

  /// Request all critical permissions
  Future<bool> requestAllPermissions() async {
    try {
      final statuses = await requestVoiceRoomPermissions();
      bool allGranted = true;

      statuses.forEach((permission, status) {
        if (!status.isGranted) {
          allGranted = false;
        }
      });

      return allGranted;
    } catch (e) {
      print('❌ Error requesting all permissions: $e');
      return false;
    }
  }

  /// Open app settings
  Future<void> openAppSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      print('❌ Error opening app settings: $e');
    }
  }
}
