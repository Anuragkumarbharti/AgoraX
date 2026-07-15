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

  /// Subscribe to profiles table changes and update cached values dynamically
  static void initializeRealtimeSubscription() {
    if (_realtimeChannel != null) return;
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
}
