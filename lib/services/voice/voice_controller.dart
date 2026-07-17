import 'package:get/get.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class VoiceController extends GetxController {
  static VoiceController get to => Get.find<VoiceController>();

  final RxString currentUserId = ''.obs;
  final RxString currentUserName = ''.obs;
  final RxString activeRoomId = ''.obs;
  final RxString roomState = 'disconnected'.obs; // 'disconnected', 'connecting', 'connected', 'reconnecting'
  
  final RxBool isMicEnabled = false.obs;
  final RxBool isCameraEnabled = false.obs;

  final RxMap<String, double> userSoundLevels = <String, double>{}.obs;
  final RxList<ZegoUser> roomUsers = <ZegoUser>[].obs;
  final RxString publishedStreamId = ''.obs;

  void reset() {
    activeRoomId.value = '';
    roomState.value = 'disconnected';
    isMicEnabled.value = false;
    isCameraEnabled.value = false;
    userSoundLevels.clear();
    roomUsers.clear();
    publishedStreamId.value = '';
  }
}
