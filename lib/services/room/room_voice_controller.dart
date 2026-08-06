import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../voice/room_voice_manager.dart';
import '../voice/voice_controller.dart';

class RoomVoiceController extends GetxController {
  static RoomVoiceController get to => Get.find<RoomVoiceController>();

  Future<void> joinRoomVoice({
    required String roomId,
    required String userId,
    required String userName,
    bool enableMic = false,
  }) async {
    try {
      await RoomVoiceManager().joinRoom(
        roomId: roomId,
        userId: userId,
        userName: userName,
        enableMic: enableMic,
      );
    } catch (e) {
      debugPrint('Error joining room voice engine: $e');
    }
  }

  Future<void> leaveRoomVoice() async {
    try {
      await RoomVoiceManager().leaveRoom();
      if (Get.isRegistered<VoiceController>()) {
        Get.find<VoiceController>().reset();
      }
    } catch (e) {
      debugPrint('Error leaving room voice engine: $e');
    }
  }
}
