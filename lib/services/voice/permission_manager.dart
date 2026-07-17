import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  Future<bool> checkMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }

  Future<PermissionStatus> requestMicrophonePermission() async {
    return await Permission.microphone.request();
  }
}
