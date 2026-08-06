import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../models/room/room_model.dart';
import '../../models/user/user_model.dart';
import '../user/user_profile_cache_manager.dart';

class RoomDiscoveryController extends GetxController {
  static RoomDiscoveryController get to => Get.find<RoomDiscoveryController>();

  final RxList<VoiceRoom> rooms = <VoiceRoom>[].obs;
  final RxList<String> favoriteRoomIds = <String>[].obs;
  final RxList<String> recentRoomIds = <String>[].obs;

  bool _isFetchingRooms = false;

  Future<void> followRoom(String roomId) async {
    if (!favoriteRoomIds.contains(roomId)) {
      favoriteRoomIds.add(roomId);
    } else {
      favoriteRoomIds.remove(roomId);
    }
  }

  void addRecentRoom(String roomId) {
    if (!recentRoomIds.contains(roomId)) {
      recentRoomIds.insert(0, roomId);
      if (recentRoomIds.length > 20) {
        recentRoomIds.removeLast();
      }
    }
  }

  Future<void> loadCachedRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('cached_voice_rooms_json');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> rawList = jsonDecode(jsonStr);
        final List<VoiceRoom> loaded = rawList
            .map((item) => VoiceRoom.fromJson(item as Map<String, dynamic>))
            .toList();
        rooms.assignAll(loaded);
        debugPrint('[RoomDiscoveryController] Loaded ${loaded.length} rooms from local cache.');
      }
    } catch (e) {
      debugPrint('[RoomDiscoveryController] Error loading cached rooms: $e');
    }
  }

  Future<void> saveRooms() async {}
  Future<void> loadSavedRooms() async {}

  Future<void> fetchRooms({bool forceRefresh = false}) async {
    if (_isFetchingRooms && !forceRefresh) return;
    _isFetchingRooms = true;

    try {
      final response = await Supabase.instance.client
          .from('rooms')
          .select(
              '*, profiles:host_id(id, username, avatar_url, avatar_frame, level, vip_level, novel_level)')
          .or('status.eq.live,status.eq.scheduled')
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      final List<VoiceRoom> loaded = [];
      final List<Map<String, dynamic>> rawList = [];

      for (final item in response as List) {
        if (item is Map<String, dynamic>) {
          rawList.add(item);
        }
        loaded.add(VoiceRoom.fromJson(item));
        final hostData = item['profiles'];
        if (hostData != null &&
            hostData is Map<String, dynamic> &&
            hostData['id'] != null) {
          try {
            final userObj = User.fromJson(hostData);
            UserProfileCacheManager.rxCache[userObj.id] = userObj;
          } catch (pe) {
            debugPrint('Error parsing host profile in fetchRooms: $pe');
          }
        }
      }

      rooms.assignAll(loaded);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_voice_rooms_json', jsonEncode(rawList));
      } catch (ce) {
        debugPrint('[RoomDiscoveryController] Cache save error: $ce');
      }
    } catch (e) {
      debugPrint('Error fetching rooms: $e');
      if (rooms.isEmpty) {
        await loadCachedRooms();
      }
    } finally {
      _isFetchingRooms = false;
    }
  }

  Future<void> searchRooms(String query) async {
    if (query.trim().isEmpty) {
      await fetchRooms();
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('rooms')
          .select(
              '*, profiles:host_id(id, username, avatar_url, avatar_frame, level, vip_level, novel_level)')
          .or('id.eq.${query.trim()},name.ilike.%$query%')
          .order('created_at', ascending: false);

      final List<VoiceRoom> loaded = [];
      for (final item in response as List) {
        loaded.add(VoiceRoom.fromJson(item));
      }
      rooms.assignAll(loaded);
    } catch (e) {
      debugPrint('Error searching rooms: $e');
    }
  }

  Future<List<VoiceRoom>> searchRoomsRpc(String query) async {
    if (query.trim().isEmpty) return rooms;
    try {
      final response = await Supabase.instance.client
          .rpc('search_rooms', params: {'p_query': query});
      if (response != null && response is List) {
        return (response as List)
            .map((json) => VoiceRoom.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Search rooms failed: $e');
    }
    return [];
  }

  void syncRoomFromMembers(String roomId, List<RoomMember> members) {
    final idx = rooms.indexWhere((r) => r.id == roomId);
    if (idx != -1) {
      final old = rooms[idx];
      final speakerIds = members.where((m) => m.role == 'Speaker').map((m) => m.userId).toList();
      final listenerIds = members.where((m) => m.role == 'Listener').map((m) => m.userId).toList();
      final json = old.toJson();
      json['participantCount'] = members.length;
      json['speakerIds'] = speakerIds;
      json['listenerIds'] = listenerIds;
      rooms[idx] = VoiceRoom.fromJson(json);
    }
  }

  Future<String?> createRoom({
    required String name,
    required String username,
    required String description,
    required String category,
    required String country,
    required String language,
    required List<String> tags,
    required List<String> rules,
    required String entryPermission,
    required bool isPermanent,
    String? avatar,
    String? banner,
  }) async {
    try {
      final response =
          await Supabase.instance.client.rpc('create_room', params: {
        'p_name': name,
        'p_username': username,
        'p_description': description,
        'p_category': category,
        'p_country': country,
        'p_language': language,
        'p_tags': tags,
        'p_rules': rules,
        'p_entry_permission': entryPermission,
        'p_avatar': avatar,
        'p_banner': banner,
        'p_is_permanent': isPermanent,
      });
      final String roomId = response.toString();
      await fetchRooms();
      return roomId;
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return null;
    }
  }

  Future<String?> createArenaRoom({
    required String name,
    required String username,
    required String description,
    required String category,
    required String country,
    required String language,
    required List<String> tags,
    required List<String> rules,
    required String entryPermission,
    String? avatar,
    String? banner,
    required String creationMethod,
  }) async {
    try {
      final response =
          await Supabase.instance.client.rpc('create_arena', params: {
        'p_name': name,
        'p_username': username,
        'p_description': description,
        'p_category': category,
        'p_country': country,
        'p_language': language,
        'p_tags': tags,
        'p_rules': rules,
        'p_entry_permission': entryPermission,
        'p_avatar': avatar,
        'p_banner': banner,
        'p_creation_method': creationMethod,
      });
      final String roomId = response.toString();
      await fetchRooms();
      return roomId;
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return null;
    }
  }

  Future<String?> createTemporaryRoom({
    required String name,
    required String username,
    required String description,
    required String category,
    required String country,
    required String language,
    required List<String> tags,
    required List<String> rules,
    required String entryPermission,
    String? avatar,
    String? banner,
  }) async {
    final roomId = await createRoom(
      name: name,
      username: username,
      description: description,
      category: category,
      country: country,
      language: language,
      tags: tags,
      rules: rules,
      entryPermission: entryPermission,
      isPermanent: false,
      avatar: avatar,
      banner: banner,
    );
    if (roomId != null) {
      Get.snackbar(
        'Success',
        'Temporary Voice Room created successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
    return roomId;
  }

  Future<String?> createPermanentRoom({
    required String name,
    required String username,
    required String description,
    required String category,
    required String country,
    required String language,
    required List<String> tags,
    required List<String> rules,
    required String entryPermission,
    String? avatar,
    String? banner,
  }) async {
    final roomId = await createRoom(
      name: name,
      username: username,
      description: description,
      category: category,
      country: country,
      language: language,
      tags: tags,
      rules: rules,
      entryPermission: entryPermission,
      isPermanent: true,
      avatar: avatar,
      banner: banner,
    );
    if (roomId != null) {
      Get.snackbar(
        'Success',
        'Permanent Voice Room created successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
    return roomId;
  }
}
