import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user_model.dart';
import 'store_controller.dart';
import 'vip_controller.dart';
import 'novel_controller.dart';
import 'customization_controller.dart';
import 'career_progression_controller.dart';

import 'isar_storage_service.dart';
import '../models/isar_chat_model.dart';
import 'asset_cache_manager.dart';

class UserProfileCacheManager {
  static final Map<String, User> _cache = {};
  static final RxMap<String, User> rxCache = <String, User>{}.obs;
  static User? _currentUser;
  static final List<VoidCallback> _listeners = [];
  static RealtimeChannel? _realtimeChannel;
  static RealtimeChannel? _connectionsRealtimeChannel;

  // Connection RxSets
  static final RxSet<String> followedUserIds = <String>{}.obs;
  static final RxSet<String> followerUserIds = <String>{}.obs;
  static final RxMap<String, String> connectionStatuses = <String, String>{}.obs; // key: otherUserId -> status

  static User? get currentUser => _currentUser;

  static String get currentUserId {
    return Supabase.instance.client.auth.currentUser?.id ?? '';
  }

  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  static void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener();
      } catch (_) {}
    }
  }

  static void setCurrentUser(User user) {
    _currentUser = user;
    _cache[user.id] = user;
    rxCache[user.id] = user;
    _notifyListeners();
    _saveCacheToOffline();
  }

  /// Fetches canonical mapping for the logged in auth user (returns auth.uid() directly)
  static Future<String> getOrFetchCanonicalId() async {
    return Supabase.instance.client.auth.currentUser?.id ?? '';
  }

  /// Get cached user or null
  static User? getCachedUser(String userId) {
    final currentId = Supabase.instance.client.auth.currentUser?.id;
    final id = (userId == 'me' || userId == 'uid_anurag_101' || userId == currentId)
        ? (currentId ?? userId)
        : userId;
    if (id == currentId && _currentUser != null) return _currentUser;
    return _cache[id];
  }

  /// Fetch a user by ID, using local memory cache if available, falling back to Supabase
  static Future<User> fetchUserProfile(String userId, {bool forceRefresh = false}) async {
    final currentId = Supabase.instance.client.auth.currentUser?.id;
    
    // Resolve user ID if the query is for the active user session
    String idToQuery = userId;
    if (userId == 'me' || userId == 'uid_anurag_101' || userId == currentId) {
      idToQuery = currentId ?? '';
    }

    if (!forceRefresh && idToQuery == currentId && _currentUser != null) {
      return _currentUser!;
    }

    if (!forceRefresh && _cache.containsKey(idToQuery)) {
      return _cache[idToQuery]!;
    }

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', idToQuery)
          .maybeSingle();

      if (data != null) {
        final userObj = User.fromJson(data);
        _cache[idToQuery] = userObj;
        rxCache[idToQuery] = userObj;
        if (idToQuery == currentId) {
          _currentUser = userObj;
        }
        _notifyListeners();
        _saveCacheToOffline();
        AssetCacheManager.prefetchProfileAssets(userObj);
        debugPrint('[CacheManager] Profile fetch success for $idToQuery');
        return userObj;
      } else {
        debugPrint('[CacheManager] Profile fetch success but no data for $idToQuery');
      }
    } catch (e) {
      debugPrint('[CacheManager] Profile fetch failed for $idToQuery: $e');
    }

    // Fallback if not found or query fails
    return User(
      id: idToQuery,
      username: 'User_${idToQuery.substring(0, min(idToQuery.length, 5))}',
      email: '',
      displayName: 'Creania Student',
      interests: [],
      communities: [],
      followers: 0,
      following: 0,
      isVerified: false,
      isPremium: false,
      reputation: 0,
      sid: '123456',
    );
  }

  static void invalidateCache(String userId) {
    _cache.remove(userId);
    rxCache.remove(userId);
    if (userId == currentUserId) {
      _currentUser = null;
    }
    _notifyListeners();
  }

  static void clear() {
    _cache.clear();
    rxCache.clear();
    _currentUser = null;
    _notifyListeners();
  }

  static Future<void> loadUserConnections() async {
    final myId = currentUserId;
    if (myId.isEmpty) return;
    try {
      final response = await Supabase.instance.client
          .from('connections')
          .select('follower_id, following_id, status')
          .or('follower_id.eq.$myId,following_id.eq.$myId');

      final followed = <String>{};
      final followers = <String>{};
      final statuses = <String, String>{};

      for (final row in response as List) {
        final fid = row['follower_id'] as String;
        final fguid = row['following_id'] as String;
        final status = row['status'] as String;

        if (fid == myId) {
          followed.add(fguid);
          statuses[fguid] = status;
        }
        if (fguid == myId) {
          followers.add(fid);
          if (statuses[fid] == null || statuses[fid] == 'following') {
            statuses[fid] = status;
          }
        }
      }

      followedUserIds.assignAll(followed);
      followerUserIds.assignAll(followers);
      connectionStatuses.assignAll(statuses);
      debugPrint('[CacheManager] Connections loaded. Following: ${followed.length}, Followers: ${followers.length}');
    } catch (e) {
      debugPrint('[CacheManager] Error loading connections: $e');
    }
  }

  static Future<void> followUser(String targetUserId) async {
    final myId = currentUserId;
    if (myId.isEmpty || targetUserId.isEmpty || myId == targetUserId) return;

    final isMutual = followerUserIds.contains(targetUserId);
    final status = isMutual ? 'friends' : 'following';

    final prevFollowed = Set<String>.from(followedUserIds);
    final prevStatuses = Map<String, String>.from(connectionStatuses);

    // Optimistically update
    followedUserIds.add(targetUserId);
    connectionStatuses[targetUserId] = status;

    final me = rxCache[myId];
    if (me != null) {
      rxCache[myId] = me.copyWith(
        following: me.following + 1,
        friendsCount: isMutual ? me.friendsCount + 1 : me.friendsCount,
      );
    }
    final target = rxCache[targetUserId];
    if (target != null) {
      rxCache[targetUserId] = target.copyWith(
        followers: target.followers + 1,
        friendsCount: isMutual ? target.friendsCount + 1 : target.friendsCount,
      );
    }

    try {
      await Supabase.instance.client.from('connections').insert({
        'follower_id': myId,
        'following_id': targetUserId,
      });
      await fetchUserProfile(targetUserId, forceRefresh: true);
      await fetchUserProfile(myId, forceRefresh: true);
    } catch (e) {
      debugPrint('[CacheManager] Follow failed, rolling back: $e');
      followedUserIds.assignAll(prevFollowed);
      connectionStatuses.assignAll(prevStatuses);
      await fetchUserProfile(myId, forceRefresh: true);
      await fetchUserProfile(targetUserId, forceRefresh: true);
    }
  }

  static Future<void> unfollowUser(String targetUserId) async {
    final myId = currentUserId;
    if (myId.isEmpty || targetUserId.isEmpty) return;

    final wasMutual = connectionStatuses[targetUserId] == 'friends';

    final prevFollowed = Set<String>.from(followedUserIds);
    final prevStatuses = Map<String, String>.from(connectionStatuses);

    // Optimistically update
    followedUserIds.remove(targetUserId);
    connectionStatuses.remove(targetUserId);

    final me = rxCache[myId];
    if (me != null) {
      rxCache[myId] = me.copyWith(
        following: me.following - 1 >= 0 ? me.following - 1 : 0,
        friendsCount: wasMutual ? (me.friendsCount - 1 >= 0 ? me.friendsCount - 1 : 0) : me.friendsCount,
      );
    }
    final target = rxCache[targetUserId];
    if (target != null) {
      rxCache[targetUserId] = target.copyWith(
        followers: target.followers - 1 >= 0 ? target.followers - 1 : 0,
        friendsCount: wasMutual ? (target.friendsCount - 1 >= 0 ? target.friendsCount - 1 : 0) : target.friendsCount,
      );
    }

    try {
      await Supabase.instance.client
          .from('connections')
          .delete()
          .eq('follower_id', myId)
          .eq('following_id', targetUserId);
      await fetchUserProfile(targetUserId, forceRefresh: true);
      await fetchUserProfile(myId, forceRefresh: true);
    } catch (e) {
      debugPrint('[CacheManager] Unfollow failed, rolling back: $e');
      followedUserIds.assignAll(prevFollowed);
      connectionStatuses.assignAll(prevStatuses);
      await fetchUserProfile(myId, forceRefresh: true);
      await fetchUserProfile(targetUserId, forceRefresh: true);
    }
  }

  /// Subscribe to profiles table changes and update cached values dynamically
  static void initializeRealtimeSubscription() {
    if (_realtimeChannel != null) return;
    loadUserConnections();
    
    // Subscribe to connections table
    try {
      _connectionsRealtimeChannel = Supabase.instance.client
          .channel('public:connections_cache_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'connections',
            callback: (payload) {
              loadUserConnections();
            },
          );
      _connectionsRealtimeChannel?.subscribe();
      debugPrint('[UserProfileCacheManager] Subscribed to connections table Realtime updates.');
    } catch (e) {
      debugPrint('[UserProfileCacheManager] Connections realtime subscription failed: $e');
    }

    try {
      _realtimeChannel = Supabase.instance.client
          .channel('public:profiles_cache_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'profiles',
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord != null && newRecord['id'] != null) {
                final String userId = newRecord['id'];
                
                // Parse updated user object
                final userObj = User.fromJson(Map<String, dynamic>.from(newRecord));
                
                _cache[userId] = userObj;
                rxCache[userId] = userObj;
                if (userId == currentUserId) {
                  _currentUser = userObj;

                  // Update GetX controllers in real-time
                  try {
                    if (Get.isRegistered<StoreController>()) {
                      Get.find<StoreController>().coinsBalance.value = (newRecord['coins_balance'] ?? 0).toInt();
                    }
                  } catch (_) {}
                  try {
                    if (Get.isRegistered<VipController>()) {
                      Get.find<VipController>().vipLevel.value = (newRecord['vip_level'] ?? 0).toInt();
                    }
                  } catch (_) {}
                  try {
                    if (Get.isRegistered<NovelController>()) {
                      Get.find<NovelController>().novelLevel.value = (newRecord['novel_level'] ?? 0).toInt();
                    }
                  } catch (_) {}
                  try {
                    if (Get.isRegistered<CustomizationController>()) {
                      Get.find<CustomizationController>().activeFrame.value = newRecord['avatar_frame'] ?? 'Normal';
                    }
                  } catch (_) {}
                  try {
                    if (Get.isRegistered<CareerProgressionController>()) {
                      final cCtrl = Get.find<CareerProgressionController>();
                      cCtrl.idLevel.value = (newRecord['level'] ?? 1).toInt();
                      cCtrl.idXp.value = (newRecord['experience'] ?? 0).toInt();
                      cCtrl.careerLevel.value = (newRecord['career_level'] ?? 1).toInt();
                      cCtrl.careerXp.value = (newRecord['career_xp'] ?? 0).toInt();
                    }
                  } catch (_) {}
                }

                _notifyListeners();
                AssetCacheManager.prefetchProfileAssets(userObj);
                debugPrint('[UserProfileCacheManager] Realtime update notified for: $userId');
              }
            },
          );
      _realtimeChannel?.subscribe();
      debugPrint('[UserProfileCacheManager] Subscribed to profiles table Realtime updates.');
    } catch (e) {
      debugPrint('[UserProfileCacheManager] Realtime subscription failed: $e');
    }
  }

  static Future<void> initOfflineCache() async {
    try {
      final isar = IsarStorageService.to;
      final payload = await isar.getCacheEntryPayload('offline_profiles_cache');
      if (payload != null && payload.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(payload);
        decoded.forEach((key, value) {
          final user = User.fromJson(Map<String, dynamic>.from(value));
          _cache[key] = user;
          rxCache[key] = user;
          if (key == currentUserId) {
            _currentUser = user;
          }
        });
        _notifyListeners();
        debugPrint('[CacheManager] Loaded ${_cache.length} profiles from Isar offline cache.');
      }
    } catch (e) {
      debugPrint('[CacheManager] Error loading Isar offline cache: $e');
    }
  }

  static void _saveCacheToOffline() async {
    try {
      final isar = IsarStorageService.to;
      final Map<String, dynamic> dataToSave = {};
      _cache.forEach((key, value) {
        // Cache profile records locally
        dataToSave[key] = value.toJson();
      });
      await isar.saveCacheEntry('offline_profiles_cache', jsonEncode(dataToSave));
    } catch (e) {
      debugPrint('[CacheManager] Error saving to Isar offline cache: $e');
    }
  }

  static Future<void> syncDeltaProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? lastSyncStr = prefs.getString('profiles_last_sync_timestamp');
      
      var query = Supabase.instance.client
          .from('profiles')
          .select();
          
      if (lastSyncStr != null) {
        query = query.gt('updated_at', lastSyncStr);
      }
      
      final response = await query;
      if (response != null) {
        final list = response as List<dynamic>;
        for (final record in list) {
          final userObj = User.fromJson(Map<String, dynamic>.from(record));
          _cache[userObj.id] = userObj;
          rxCache[userObj.id] = userObj;
          if (userObj.id == currentUserId) {
            _currentUser = userObj;
          }
        }
        await prefs.setString('profiles_last_sync_timestamp', DateTime.now().toUtc().toIso8601String());
        _saveCacheToOffline();
        _notifyListeners();
        debugPrint('[CacheManager] Delta sync completed. Processed ${list.length} profiles.');
      }
    } catch (e) {
      debugPrint('[CacheManager] Delta sync failed: $e');
    }
  }

  static Future<void> rebuildAndSyncCurrentUserTagSystem() async {
    final user = currentUser;
    if (user == null) return;

    // 1. Identity Tag Bar
    final List<Map<String, dynamic>> identityTags = [];
    identityTags.add({'type': 'id_level', 'value': 'Lv.${user.level}'});

    // Resolve community tag
    String? commTag;
    try {
      final List<dynamic>? comms = await Supabase.instance.client
          .from('communities')
          .select('id')
          .eq('type', 'Official')
          .contains('members', [user.id]);
      if (comms != null && comms.isNotEmpty) {
        final commId = comms.first['id'] as String;
        if (commId == 'comm-connect-005') commTag = 'Connect';
        else if (commId == 'comm-creators-002') commTag = 'Studio';
        else if (commId == 'comm-gamers-003') commTag = 'ArenaX';
        else if (commId == 'comm-campus-004') commTag = 'Campus';
        else if (commId == 'comm-official-001') commTag = 'Origin';
      }
    } catch (_) {}

    if (commTag != null) {
      identityTags.add({'type': 'community', 'value': commTag});
    }

    if (user.vipLevel > 0) {
      identityTags.add({'type': 'vip', 'value': 'VIP ${user.vipLevel}'});
    }

    if (user.novelLevel > 0) {
      identityTags.add({'type': 'noble', 'value': 'Novel ${user.novelLevel}'});
    }

    // Special tag
    final rolesSet = user.rTags.map((r) => r.trim().toLowerCase()).toSet();
    String? specialTag;
    if (rolesSet.contains('anniversary')) {
      specialTag = 'Anniversary';
    } else if (rolesSet.contains('champion')) {
      specialTag = 'Champion';
    } else if (rolesSet.contains('creator') || rolesSet.contains('star creator')) {
      specialTag = 'Creator';
    } else if (rolesSet.contains('official') || rolesSet.contains('creania official')) {
      specialTag = 'Official';
    }

    if (specialTag != null) {
      identityTags.add({'type': 'special', 'value': specialTag});
    }

    // 2. Official Status
    String? verifiedTag;
    for (final v in ['celebrity', 'partner', 'official', 'verified', 'verified tester']) {
      if (rolesSet.contains(v)) {
        verifiedTag = v[0].toUpperCase() + v.substring(1);
        break;
      }
    }
    if (verifiedTag == null && user.isVerified) {
      verifiedTag = 'Verified';
    }

    String? roleTag;
    for (final r in ['developer', 'administrator', 'admin', 'official staff', 'employee', 'moderator', 'host']) {
      if (rolesSet.contains(r)) {
        if (r == 'admin') {
          roleTag = 'Administrator';
        } else if (r == 'employee') {
          roleTag = 'Official Staff';
        } else {
          roleTag = r.split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
        }
        break;
      }
    }

    final localTagSystem = TagSystem(
      identityTagBar: identityTags.map((e) => IdentityTag.fromJson(e)).toList(),
      officialStatus: OfficialStatus(verifiedTag: verifiedTag, roleTag: roleTag),
      profileShowcase: user.showcasedBadges,
    );

    final List<String> tagLights = identityTags.map((e) => e['value'] as String).toList();

    // Update cache in-memory instantly to avoid infinite recursion
    final updatedUser = user.copyWith(tagSystem: localTagSystem, tagLights: tagLights);
    _currentUser = updatedUser;
    rxCache[user.id] = updatedUser;
    _cache[user.id] = updatedUser;
    _notifyListeners();
  }
}
