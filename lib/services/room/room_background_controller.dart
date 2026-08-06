import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/room/room_background_model.dart';
import 'room_realtime_controller.dart';

class RoomBackgroundController extends GetxController {
  static RoomBackgroundController get to => Get.find<RoomBackgroundController>();

  final Rx<RoomBackgroundItem> activeRoomBackground =
      RoomBackgroundCatalog.defaultBackground.obs;

  void changeRoomBackground(RoomBackgroundItem item, {required String? activeRoomId}) {
    activeRoomBackground.value = item;
    if (activeRoomId != null && Get.isRegistered<RoomRealtimeController>()) {
      final realtimeCtrl = RoomRealtimeController.to;
      if (realtimeCtrl.roomActivityEventsChannel != null) {
        realtimeCtrl.roomActivityEventsChannel!.sendBroadcastMessage(
          event: 'room_background_changed',
          payload: {
            'room_id': activeRoomId,
            'background': item.toJson(),
          },
        );
      }
    }
  }
}
