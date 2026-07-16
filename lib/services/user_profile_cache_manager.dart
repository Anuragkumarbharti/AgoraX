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
import '../screens/auth/login_screen.dart';
import 'package:flutter/material.dart';

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
      // Deactivate expired memberships on the backend if looking up own profile
      if (idToQuery == currentId) {
        try {
          await Supabase.instance.client.rpc('check_and_clean_expired_memberships');
        } catch (_) {}
      }

      var data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', idToQuery)
          .maybeSingle();

      if (idToQuery == currentId) {
        if (data == null) {
          final currentUser = Supabase.instance.client.auth.currentUser;
          if (currentUser == null) {
            await forceLogout(message: "Your account is unavailable. Please sign in again or contact support.");
            throw Exception("Profile row missing and auth user is null");
          }
          try {
            final newUsername = 'user_${currentUser.id.replaceAll('-', '').substring(0, 8)}';
            await Supabase.instance.client.from('profiles').insert({
              'id': currentUser.id,
              'username': newUsername,
              'email': currentUser.email,
              'phone': currentUser.phone,
              'level': 1,
              'experience': 0,
              'vip_level': 0,
              'novel_level': 0,
              'verified': false,
            });
            final refetched = await Supabase.instance.client
                .from('profiles')
                .select()
                .eq('id', currentUser.id)
                .maybeSingle();
            if (refetched != null) {
              data = refetched;
            } else {
              await forceLogout(message: "Your account is unavailable. Please sign in again or contact support.");
              throw Exception("Recreation succeeded but refetch returned null");
            }
          } catch (recreateError) {
            debugPrint('[CacheManager] Missing profile recreation failed: $recreateError');
            await forceLogout(message: "Your account is unavailable. Please sign in again or contact support.");
            throw Exception("Profile row missing and recreation failed: $recreateError");
          }
        }
        final status = data['status'] as String?;
        final isBanned = data['is_banned'] as bool? ?? false;
        final banReason = data['ban_reason'] as String?;
        if (status == 'suspended' || status == 'banned' || isBanned) {
          await forceLogout(
            message: banReason != null && banReason.isNotEmpty
                ? "Your account has been suspended. Reason: $banReason"
                : "Your account has been suspended.",
          );
          throw Exception("Account suspended");
        }
      }

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

  static Future<bool> validateCurrentUserSession() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) {
      return false;
    }

    try {
      // Deactivate expired memberships on the backend
      try {
        await client.rpc('check_and_clean_expired_memberships');
      } catch (e) {
        debugPrint('[CacheManager] Error running expiry cleanup: $e');
      }

      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        await forceLogout(message: "Your session is invalid. Please sign in again.");
        return false;
      }

      // Check if matching row exists in profiles
      Map<String, dynamic>? data = await client
          .from('profiles')
          .select('status, is_banned, ban_reason')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (data == null) {
        // Attempt to auto-recreate the profiles row if missing
        try {
          final newUsername = 'user_${currentUser.id.replaceAll('-', '').substring(0, 8)}';
          await client.from('profiles').insert({
            'id': currentUser.id,
            'username': newUsername,
            'email': currentUser.email,
            'phone': currentUser.phone,
            'level': 1,
            'experience': 0,
            'vip_level': 0,
            'novel_level': 0,
            'verified': false,
          });
          // Verify it was created successfully
          final refetched = await client
              .from('profiles')
              .select('status, is_banned, ban_reason')
              .eq('id', currentUser.id)
              .maybeSingle();
          if (refetched != null) {
            data = refetched;
          } else {
            await forceLogout(message: "Your account is unavailable. Please sign in again or contact support.");
            return false;
          }
        } catch (e) {
          debugPrint('[CacheManager] Auto-recreation of profiles row failed during session validation: $e');
          await forceLogout(message: "Your account is unavailable. Please sign in again or contact support.");
          return false;
        }
      }

      // Check if suspended or banned
      final status = data['status'] as String?;
      final isBanned = data['is_banned'] as bool? ?? false;
      final banReason = data['ban_reason'] as String?;

      if (status == 'suspended' || status == 'banned' || isBanned) {
        await forceLogout(
          message: banReason != null && banReason.isNotEmpty
              ? "Your account has been suspended. Reason: $banReason"
              : "Your account has been suspended.",
        );
        return false;
      }

      // Check bans ledger for active bans
      final banLedger = await client
          .from('bans')
          .select('reason')
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (banLedger != null) {
        final reason = banLedger['reason'] as String?;
        await forceLogout(
          message: reason != null && reason.isNotEmpty
              ? "Your account has been suspended. Reason: $reason"
              : "Your account has been suspended.",
        );
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[CacheManager] Session validation error: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('jwt') || errStr.contains('session') || errStr.contains('unauthorized') || errStr.contains('invalid token') || errStr.contains('expired')) {
        // Attempt session refresh
        try {
          final res = await client.auth.refreshSession();
          if (res.session == null) {
            await forceLogout(message: "Your session has expired. Please sign in again.");
            return false;
          }
          return true;
        } catch (_) {
          await forceLogout(message: "Your session has expired. Please sign in again.");
          return false;
        }
      }
      return true; // Keep active for temporary network issues
    }
  }

  static Future<void> forceLogout({required String message}) async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}

    clear();

    try {
      final isar = IsarStorageService.to;
      await isar.deleteConversation('offline_profiles_cache');
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('profiles_last_sync_timestamp');
      await prefs.remove('store_coins_balance');
      await prefs.remove('store_silver_balance');
      await prefs.remove('vip_level');
      await prefs.remove('vip_expiry');
      await prefs.remove('novel_level');
      await prefs.remove('novel_expiry');
    } catch (_) {}

    Get.offAll(() => const LoginScreen());

    Get.snackbar(
      'Account Alert 🔒',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 6),
    );
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
                    if (Get.isRegistered<VipController>()) {
                      final vipCtrl = Get.find<VipController>();
                      vipCtrl.vipLevel.value = (newRecord['vip_level'] ?? 0).toInt();
                      final expiryStr = newRecord['vip_expiry'];
                      if (expiryStr != null) {
                        vipCtrl.expiryDate.value = DateTime.tryParse(expiryStr);
                      } else {
                        vipCtrl.expiryDate.value = null;
                      }
                      vipCtrl.saveState();
                    }
                  } catch (_) {}
                  try {
                    if (Get.isRegistered<NovelController>()) {
                      final novelCtrl = Get.find<NovelController>();
                      novelCtrl.novelLevel.value = (newRecord['novel_level'] ?? 0).toInt();
                      final expiryStr = newRecord['novel_expiry'];
                      if (expiryStr != null) {
                        novelCtrl.expiryDate.value = DateTime.tryParse(expiryStr);
                      } else {
                        novelCtrl.expiryDate.value = null;
                      }
                      novelCtrl.saveState();
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

    // Subscribe to wallets table for coins and silver coins real-time sync
    try {
      final walletsChannel = Supabase.instance.client
          .channel('public:wallets_cache_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'wallets',
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord != null && newRecord['id'] != null) {
                final String userId = newRecord['id'];
                if (userId == currentUserId) {
                  final num coins = newRecord['coins_balance'] ?? 0;
                  final num silver = newRecord['silver_balance'] ?? 0;
                  try {
                    if (Get.isRegistered<StoreController>()) {
                      Get.find<StoreController>().coinsBalance.value = coins.toInt();
                      Get.find<StoreController>().silverCoinsBalance.value = silver.toInt();
                    }
                  } catch (_) {}
                }
              }
            },
          );
      walletsChannel.subscribe();
      debugPrint('[UserProfileCacheManager] Subscribed to wallets table Realtime updates.');
    } catch (e) {
      debugPrint('[UserProfileCacheManager] Wallets realtime subscription failed: $e');
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
    final myId = currentUserId;
    if (myId.isEmpty) return;
    try {
      await fetchUserProfile(myId, forceRefresh: true);
    } catch (e) {
      debugPrint('[CacheManager] rebuildAndSyncCurrentUserTagSystem failed: $e');
    }
  }
}
