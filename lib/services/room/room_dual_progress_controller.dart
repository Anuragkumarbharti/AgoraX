import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/progression/room_dual_progress_model.dart';
import '../user/user_profile_cache_manager.dart';

class RoomDualProgressController extends GetxController {
  static RoomDualProgressController get to {
    if (!Get.isRegistered<RoomDualProgressController>()) {
      return Get.put(RoomDualProgressController());
    }
    return Get.find<RoomDualProgressController>();
  }

  final RxMap<String, RoomDualProgress> dualProgresses = <String, RoomDualProgress>{}.obs;
  final RxMap<String, bool> isOverflowingMap = <String, bool>{}.obs;
  final RxMap<String, RealtimeChannel> _activeChannels = <String, RealtimeChannel>{}.obs;

  /// Get dual progress state for a specific room ID with fallback defaults.
  RoomDualProgress getDualProgress(String roomId) {
    return dualProgresses[roomId] ?? RoomDualProgress(roomId: roomId);
  }

  /// Check if overflow streaming animation should be active for room ID
  bool isOverflowing(String roomId) {
    final prog = getDualProgress(roomId);
    return isOverflowingMap[roomId] == true || prog.isOverflowActive;
  }

  /// Fetch initial dual progress state from backend database
  Future<RoomDualProgress> fetchDualProgress(String roomId) async {
    if (roomId.isEmpty) return const RoomDualProgress(roomId: '');

    try {
      final client = Supabase.instance.client;
      final resp = await client
          .from('room_dual_progress')
          .select()
          .eq('room_id', roomId)
          .maybeSingle();

      if (resp != null) {
        final model = RoomDualProgress.fromJson(resp as Map<String, dynamic>);
        dualProgresses[roomId] = model;
        isOverflowingMap[roomId] = model.isOverflowActive;
        return model;
      } else {
        final defaultModel = RoomDualProgress(roomId: roomId);
        dualProgresses[roomId] = defaultModel;
        return defaultModel;
      }
    } catch (e) {
      debugPrint('[RoomDualProgressController] Fetch error: $e');
      final fallback = dualProgresses[roomId] ?? RoomDualProgress(roomId: roomId);
      return fallback;
    }
  }

  /// Subscribe to WebSocket / Supabase Realtime channel for instant sync across all users
  void subscribeToRealtimeDualProgress(String roomId) {
    if (roomId.isEmpty || _activeChannels.containsKey(roomId)) return;

    try {
      final client = Supabase.instance.client;
      final channelName = 'public:room_dual_progress:room_id=eq.$roomId';

      final channel = client.channel(channelName);
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'room_dual_progress',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (payload) {
          final newRecord = payload.newRecord;
          if (newRecord != null && newRecord.isNotEmpty) {
            final updatedModel = RoomDualProgress.fromJson(newRecord);
            dualProgresses[roomId] = updatedModel;
            if (updatedModel.isOverflowActive) {
              isOverflowingMap[roomId] = true;
            }
            debugPrint('[DualProgress Realtime] Room $roomId updated: Gold=${updatedModel.goldPoints}/${updatedModel.goldTarget}, Normal=${updatedModel.normalPoints}/${updatedModel.normalTarget}');
          }
        },
      );

      channel.subscribe();
      _activeChannels[roomId] = channel;
    } catch (e) {
      debugPrint('[RoomDualProgressController] Realtime subscribe error: $e');
    }
  }

  /// Unsubscribe realtime channel for room
  void unsubscribeRealtimeDualProgress(String roomId) {
    final channel = _activeChannels.remove(roomId);
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
  }

  /// Process Gold Gift contribution (Fills Gold Progress -> Overflows into Normal Progress)
  Future<Map<String, dynamic>> processGoldContribution({
    required String roomId,
    required int goldPoints,
    String? userId,
  }) async {
    final currentUserId = userId ?? UserProfileCacheManager.currentUserId;
    try {
      final client = Supabase.instance.client;
      final resp = await client.rpc('process_room_dual_progress', params: {
        'p_room_id': roomId,
        'p_user_id': currentUserId,
        'p_points': goldPoints,
        'p_source': 'gold_gift',
      });

      if (resp != null && resp['success'] == true) {
        final goldAdded = resp['gold_added'] as int? ?? 0;
        final overflowAdded = resp['gold_overflow_added'] as int? ?? 0;
        final normalAdded = resp['normal_added'] as int? ?? 0;
        final newGoldPoints = resp['gold_points'] as int? ?? 0;
        final newGoldTarget = resp['gold_target'] as int? ?? 1000;
        final newNormalPoints = resp['normal_points'] as int? ?? 0;
        final newNormalTarget = resp['normal_target'] as int? ?? 700;
        final newLevel = resp['room_level'] as int? ?? 1;

        final updatedModel = RoomDualProgress(
          roomId: roomId,
          goldPoints: newGoldPoints,
          goldTarget: newGoldTarget,
          normalPoints: newNormalPoints,
          normalTarget: newNormalTarget,
          overflowPoints: (dualProgresses[roomId]?.overflowPoints ?? 0) + overflowAdded,
          roomLevel: newLevel,
          updatedAt: DateTime.now(),
        );

        dualProgresses[roomId] = updatedModel;

        if (overflowAdded > 0) {
          isOverflowingMap[roomId] = true;
          // Reset overflow pulse animation after 3 seconds
          Future.delayed(const Duration(seconds: 4), () {
            if (dualProgresses[roomId]?.isGoldFull != true) {
              isOverflowingMap[roomId] = false;
            }
          });
        }

        debugPrint('[DualProgress] Gold Contribution: +$goldAdded Gold, +$overflowAdded Overflow -> +$normalAdded Normal. Level=$newLevel');
      }
      return Map<String, dynamic>.from(resp as Map);
    } catch (e) {
      debugPrint('[RoomDualProgressController] Gold contribution error: $e');
      return {'success': false, 'reason': e.toString()};
    }
  }

  /// Process Free Activity contribution (Silver Gift, Like, Chat, Room Stay, Mic Time)
  /// Anti-abuse rule: Free activities CAN NEVER increase Gold Progress!
  Future<Map<String, dynamic>> processFreeActivityContribution({
    required String roomId,
    required int points,
    required String activityType, // 'silver_gift', 'like', 'chat', 'mic_time', 'stay_time'
    String? userId,
  }) async {
    final currentUserId = userId ?? UserProfileCacheManager.currentUserId;
    try {
      final client = Supabase.instance.client;
      final resp = await client.rpc('process_room_dual_progress', params: {
        'p_room_id': roomId,
        'p_user_id': currentUserId,
        'p_points': points,
        'p_source': activityType,
      });

      if (resp != null && resp['success'] == true) {
        final normalAdded = resp['normal_added'] as int? ?? 0;
        final newGoldPoints = resp['gold_points'] as int? ?? 0;
        final newGoldTarget = resp['gold_target'] as int? ?? 1000;
        final newNormalPoints = resp['normal_points'] as int? ?? 0;
        final newNormalTarget = resp['normal_target'] as int? ?? 700;
        final newLevel = resp['room_level'] as int? ?? 1;

        final updatedModel = RoomDualProgress(
          roomId: roomId,
          goldPoints: newGoldPoints,
          goldTarget: newGoldTarget,
          normalPoints: newNormalPoints,
          normalTarget: newNormalTarget,
          overflowPoints: dualProgresses[roomId]?.overflowPoints ?? 0,
          roomLevel: newLevel,
          updatedAt: DateTime.now(),
        );

        dualProgresses[roomId] = updatedModel;
        debugPrint('[DualProgress] Free Activity ($activityType): +$normalAdded Normal points. Gold points unchanged ($newGoldPoints). Level=$newLevel');
      }
      return Map<String, dynamic>.from(resp as Map);
    } catch (e) {
      debugPrint('[RoomDualProgressController] Free activity error: $e');
      return {'success': false, 'reason': e.toString()};
    }
  }

  /// Claim 1-time unique user seat occupancy join bonus (+20 Normal AP, max 5 users/day)
  Future<Map<String, dynamic>> claimUniqueSeatBonus(String roomId, String userId) async {
    try {
      final client = Supabase.instance.client;
      final resp = await client.rpc('claim_unique_seat_bonus', params: {
        'p_room_id': roomId,
        'p_user_id': userId,
      });

      if (resp != null && resp['success'] == true) {
        await fetchDualProgress(roomId);
        debugPrint('[DualProgress] Unique Seat Bonus Claimed: +20 Normal AP for room $roomId, user $userId');
      }
      return Map<String, dynamic>.from(resp as Map);
    } catch (e) {
      debugPrint('[RoomDualProgressController] Claim unique seat bonus error: $e');
      return {'success': false, 'reason': e.toString()};
    }
  }

  /// Process 1-time unique user first gift bonus (+5 Normal AP bonus, max 20 users/day)
  Future<Map<String, dynamic>> processFirstGiftBonus(String roomId, String userId) async {
    try {
      final client = Supabase.instance.client;
      final resp = await client.rpc('process_first_gift_bonus', params: {
        'p_room_id': roomId,
        'p_user_id': userId,
      });

      if (resp != null && resp['success'] == true) {
        await fetchDualProgress(roomId);
        debugPrint('[DualProgress] First Gift Bonus Claimed: +5 Normal AP for room $roomId, user $userId');
      }
      return Map<String, dynamic>.from(resp as Map);
    } catch (e) {
      debugPrint('[RoomDualProgressController] First gift bonus error: $e');
      return {'success': false, 'reason': e.toString()};
    }
  }

  /// Process Active Seat Time AP (4 Normal AP / min per active seated user)
  Future<Map<String, dynamic>> processActiveSeatTime(String roomId, int activeSeatCount) async {
    if (activeSeatCount <= 0) return {'success': false, 'reason': 'No active seated users', 'added_ap': 0};

    try {
      final client = Supabase.instance.client;
      final resp = await client.rpc('process_active_seat_time_ap', params: {
        'p_room_id': roomId,
        'p_active_seat_count': activeSeatCount,
      });

      if (resp != null && resp['success'] == true) {
        await fetchDualProgress(roomId);
        final addedAp = resp['added_ap'] as int? ?? 0;
        debugPrint('[DualProgress] Active Seat Time AP: +$addedAp Normal AP ($activeSeatCount seated users x 4 AP/min)');
      }
      return Map<String, dynamic>.from(resp as Map);
    } catch (e) {
      debugPrint('[RoomDualProgressController] Active seat time error: $e');
      return {'success': false, 'reason': e.toString()};
    }
  }

  @override
  void onClose() {
    for (final channel in _activeChannels.values) {
      Supabase.instance.client.removeChannel(channel);
    }
    _activeChannels.clear();
    super.onClose();
  }
}
