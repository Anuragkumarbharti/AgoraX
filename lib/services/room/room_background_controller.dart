import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/room/room_background_model.dart';
import 'room_realtime_controller.dart';

class RoomBackgroundController extends GetxController {
  static RoomBackgroundController get to => Get.find<RoomBackgroundController>();

  final Rx<RoomBackgroundItem> activeRoomBackground =
      RoomBackgroundCatalog.defaultBackground.obs;
  
  final RxBool isPreloaded = false.obs;

  /// Preload all background images into memory cache when entering room.
  Future<void> preloadRoomBackgrounds(BuildContext context) async {
    if (isPreloaded.value) return;
    try {
      for (final bg in RoomBackgroundCatalog.allBackgrounds) {
        await precacheImage(AssetImage(bg.assetPath), context);
      }
      isPreloaded.value = true;
    } catch (e) {
      debugPrint('[RoomBackgroundController] Error preloading backgrounds: $e');
    }
  }

  /// Load persisted background theme for a specific room (from SharedPreferences & fallback).
  Future<void> loadRoomBackgroundForRoom(String? roomId, {String? roomThemeFromDb}) async {
    if (roomId == null || roomId.isEmpty) {
      activeRoomBackground.value = RoomBackgroundCatalog.defaultBackground;
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('room_bg_theme_$roomId');
      final effectiveId = savedId ?? roomThemeFromDb;

      if (effectiveId != null && effectiveId.isNotEmpty) {
        activeRoomBackground.value = RoomBackgroundCatalog.findById(effectiveId);
      } else {
        activeRoomBackground.value = RoomBackgroundCatalog.defaultBackground;
      }
    } catch (e) {
      debugPrint('[RoomBackgroundController] Error loading saved theme: $e');
      activeRoomBackground.value = RoomBackgroundCatalog.defaultBackground;
    }
  }

  /// Change room background theme with smooth animation, persistence, DB sync, and real-time broadcast to all users in the room.
  Future<void> changeRoomBackground(RoomBackgroundItem item, {required String? activeRoomId}) async {
    activeRoomBackground.value = item;

    if (activeRoomId != null && activeRoomId.isNotEmpty) {
      // 1. Persist choice locally per room ID
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('room_bg_theme_$activeRoomId', item.id);
      } catch (e) {
        debugPrint('[RoomBackgroundController] Error saving room theme locally: $e');
      }

      // 2. Persist to DB rooms table via RPC & direct update fallback
      try {
        await Supabase.instance.client.rpc('update_room_background_theme', params: {
          'p_room_id': activeRoomId,
          'p_theme_id': item.id,
        });
      } catch (_) {
        try {
          await Supabase.instance.client
              .from('rooms')
              .update({'room_theme': item.id})
              .eq('id', activeRoomId);
        } catch (e) {
          debugPrint('[RoomBackgroundController] Error saving room theme to DB: $e');
        }
      }
    }

    // 3. Broadcast real-time event to all connected users in the room
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
        debugPrint('[RoomBackgroundController] Broadcasted room_background_changed for room $activeRoomId: ${item.id}');
      }
    }
  }
}
