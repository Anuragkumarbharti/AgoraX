import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../models/user/user_model.dart';
import '../store/store_controller.dart';
import '../memberships/vip_controller.dart';
import '../memberships/novel_controller.dart';
import './customization_controller.dart';
import '../progression/career_progression_controller.dart';

import '../storage/isar_storage_service.dart';
import '../chat/chat_controller.dart';
import '../chat/chat_socket_service.dart';
import '../../models/chat/isar_chat_model.dart';
import '../storage/asset_cache_manager.dart';
import '../../screens/auth/login_screen.dart';
import '../../core/api_error_handler.dart';
import './smart_default_avatar_service.dart';
import 'package:flutter/material.dart';
import '../auth/auth_memory_service.dart';

class UserProfileCacheManager {
  static final Map<String, User> _cache = {};
  static final RxMap<String, User> rxCache = <String, User>{}.obs;
  static User? _currentUser;
  static final List<VoidCallback> _listeners = [];
  static RealtimeChannel? _realtimeChannel;
  static RealtimeChannel? _customizationsRealtimeChannel;
  static RealtimeChannel? _connectionsRealtimeChannel;
  static RealtimeChannel? _giftRealtimeChannel;
  static RealtimeChannel? _sessionRealtimeChannel;
  static String _currentSessionId = '';
  static final RxInt giftTransactionsTrigger = 0.obs;

  static String get currentSessionId {
    if (_currentSessionId.isNotEmpty) return _currentSessionId;
    _currentSessionId = 'sess_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';
    SharedPreferences.getInstance().then((prefs) => prefs.setString('current_session_id', _currentSessionId));
    return _currentSessionId;
  }

  /// Resolves clean @username for gift events and chat notifications.
  /// Never returns generic "User", "User.", "Seat No.", or "No. X".
  static String resolveUsernameForGifting(
    String? userId, {
    String? passedName,
    Map<String, dynamic>? seatInfo,
  }) {
    final uid = userId?.trim() ?? '';
    final curUser = currentUser;
    final curId = currentUserId;

    // 1. If sending to self or matching logged-in user
    if (uid.isNotEmpty && uid == curId && curUser != null) {
      if (curUser.username.isNotEmpty && curUser.username != 'User' && curUser.username != 'User.') {
        return curUser.username;
      }
    }

    // 2. Check live room seat info
    if (seatInfo != null) {
      final sUsername = (seatInfo['username'] as String?)?.trim() ?? (seatInfo['name'] as String?)?.trim();
      if (sUsername != null &&
          sUsername.isNotEmpty &&
          sUsername != 'User' &&
          sUsername != 'User.' &&
          !sUsername.startsWith('Seat') &&
          !sUsername.startsWith('No.')) {
        return sUsername;
      }
    }

    // 3. Check passedName if valid username
    final pName = passedName?.trim() ?? '';
    if (pName.isNotEmpty &&
        pName != 'User' &&
        pName != 'User.' &&
        !pName.startsWith('Seat') &&
        !pName.startsWith('No.')) {
      return pName;
    }

    // 4. Check cached user profile
    if (uid.isNotEmpty) {
      final cached = getCachedUser(uid);
      if (cached != null &&
          cached.username.isNotEmpty &&
          cached.username != 'User' &&
          cached.username != 'User.') {
        return cached.username;
      }
    }

    // 5. Fallback
    if (uid.isNotEmpty && uid == curId && curUser != null && curUser.username.isNotEmpty) {
      return curUser.username;
    }
    return 'Member';
  }

  static Future<String> getOrGenerateSessionId() async {
    if (_currentSessionId.isNotEmpty) return _currentSessionId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('current_session_id');
      if (stored != null && stored.isNotEmpty) {
        _currentSessionId = stored;
      } else {
        _currentSessionId = 'sess_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';
        await prefs.setString('current_session_id', _currentSessionId);
      }
    } catch (_) {
      if (_currentSessionId.isEmpty) {
        _currentSessionId = 'sess_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';
      }
    }
    return _currentSessionId;
  }

  static Future<Map<String, dynamic>?> registerSession(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      var deviceId = prefs.getString('device_id');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = 'device_${Random().nextInt(9999999)}';
        await prefs.setString('device_id', deviceId);
      }

      final sid = await getOrGenerateSessionId();

      // Try RPC for atomic single session registration and invalidation of old sessions
      try {
        final rpcRes = await Supabase.instance.client.rpc('register_new_session', params: {
          'p_session_id': sid,
          'p_device_id': deviceId,
          'p_device_name': defaultTargetPlatform.name,
          'p_os_version': kIsWeb ? 'Web' : defaultTargetPlatform.toString(),
          'p_app_version': '1.0.0',
          'p_platform': defaultTargetPlatform.name,
        });

        if (rpcRes != null && rpcRes is Map<String, dynamic>) {
          debugPrint('[UserProfileCacheManager] Single Device Session Authenticated Log:');
          debugPrint('  -> Previous Session ID: ${rpcRes['previous_session_id']}');
          debugPrint('  -> New Session ID: ${rpcRes['new_session_id']}');
          debugPrint('  -> Device ID: ${rpcRes['device_id']}');
          debugPrint('  -> Login Timestamp: ${rpcRes['login_time']}');
          return rpcRes;
        }
      } catch (rpcErr) {
        debugPrint('[UserProfileCacheManager] register_new_session RPC fallback: $rpcErr');
      }

      // Direct upsert fallback
      await Supabase.instance.client.from('user_sessions').upsert({
        'session_id': sid,
        'user_id': userId,
        'device_id': deviceId,
        'device_name': defaultTargetPlatform.name,
        'os_version': kIsWeb ? 'Web' : defaultTargetPlatform.toString(),
        'app_version': '1.0.0',
        'platform': defaultTargetPlatform.name,
        'login_time': DateTime.now().toIso8601String(),
        'last_seen': DateTime.now().toIso8601String(),
        'online_status': 'Online',
      });
      debugPrint('[UserProfileCacheManager] Session registered via fallback: $sid');
    } catch (e) {
      debugPrint('[UserProfileCacheManager] Session registration error: $e');
    }
    return null;
  }

  /// Incremented every time an equip/unequip is confirmed by the backend.
  /// Screens can listen to this with Obx(() => ...) to refresh their user card.
  static final RxInt equipEventTrigger = 0.obs;

  /// Called by CustomizationController after every confirmed backend equip/unequip.
  /// All screens (Profile, Room, Chat, Leaderboard, Store) should Obx-react to equipEventTrigger.
  static void broadcastEquipConfirmed() {
    equipEventTrigger.value++;
  }


  // Connection RxSets
  static final RxSet<String> followedUserIds = <String>{}.obs;
  static final RxSet<String> followerUserIds = <String>{}.obs;
  static final RxMap<String, String> connectionStatuses =
      <String, String>{}.obs; // key: otherUserId -> status

  static User? get currentUser => _currentUser;

  static void setCurrentUserForTesting(User? user) {
    _currentUser = user;
  }

  static String get currentUserId {
    try {
      final authUid = Supabase.instance.client.auth.currentUser?.id;
      if (authUid != null && authUid.isNotEmpty) return authUid;
    } catch (_) {}
    final cachedUid = _currentUser?.id;
    if (cachedUid != null && cachedUid.isNotEmpty) return cachedUid;
    return '';
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
    _cache['me'] = user;
    rxCache['me'] = user;
    _notifyListeners();
    _saveCacheToOffline();
  }

  /// Fetches canonical mapping for the logged in auth user (returns auth.uid() directly)
  static Future<String> getOrFetchCanonicalId() async {
    final uid = currentUserId;
    return uid;
  }

  /// Get cached user or null
  static User? getCachedUser(String userId) {
    if (userId.trim().isEmpty) return null;
    final currentId = currentUserId;
    final id = (userId == 'me' || userId == 'uid_anurag_101' || (currentId.isNotEmpty && userId == currentId))
        ? (currentId.isNotEmpty ? currentId : userId)
        : userId;
    if (currentId.isNotEmpty && id == currentId && _currentUser != null) return _currentUser;
    return _cache[id];
  }

  /// Fetch a user by ID, using local memory cache if available, falling back to Supabase
  static Future<User> fetchUserProfile(String userId,
      {bool forceRefresh = false}) async {
    if (userId.trim().isEmpty) {
      throw Exception("User ID cannot be empty");
    }
    final currentId = currentUserId;

    // Resolve user ID if the query is for the active user session
    String idToQuery = userId;
    if (userId == 'me' || userId == 'uid_anurag_101' || (currentId.isNotEmpty && userId == currentId)) {
      idToQuery = currentId.isNotEmpty ? currentId : userId;
    }
    if (idToQuery.trim().isEmpty) {
      throw Exception("User ID cannot be empty");
    }

    // ── Guard: reject malformed IDs (e.g. concatenated roomId_userId keys) ──
    // A valid Supabase UUID has exactly 36 chars in format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    final uuidPattern = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (!uuidPattern.hasMatch(idToQuery)) {
      debugPrint('[CacheManager] Rejected malformed userId: $idToQuery');
      throw FormatException('Invalid user ID format: $idToQuery');
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
          await Supabase.instance.client
              .rpc('check_and_clean_expired_memberships');
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
            await forceLogout(
                message:
                    "Your account is unavailable. Please sign in again or contact support.");
            throw Exception("Profile row missing and auth user is null");
          }
          try {
            final newUsername =
                'user_${currentUser.id.replaceAll('-', '').substring(0, 8)}';
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
              await forceLogout(
                  message:
                      "Your account is unavailable. Please sign in again or contact support.");
              throw Exception("Recreation succeeded but refetch returned null");
            }
          } catch (recreateError) {
            debugPrint(
                '[CacheManager] Missing profile recreation failed: $recreateError');
            await forceLogout(
                message:
                    "Your account is unavailable. Please sign in again or contact support.");
            throw Exception(
                "Profile row missing and recreation failed: $recreateError");
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
        var userObj = User.fromJson(data);
        if (!SmartDefaultAvatarService.hasCustomAvatar(userObj.avatar) && idToQuery == currentId) {
          final assignedAvatar = await SmartDefaultAvatarService.ensureDefaultAvatarAssigned(
            userId: idToQuery,
            currentAvatar: userObj.avatar,
            gender: userObj.gender,
          );
          userObj = userObj.copyWith(avatar: assignedAvatar);
        }
        if (idToQuery == currentId) {
          // Backend is now the single source of truth.
          // No local lock overlay — VIP/Novel state comes directly from DB via subscriptions table.
        }
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

        debugPrint(
            '[CacheManager] Profile fetch success but no data for $idToQuery');
      }
    } catch (e) {
      debugPrint('[CacheManager] Profile fetch failed for $idToQuery: $e');
    }

    // Fallback if not found or query fails
    return User(
      id: idToQuery,
      username: 'User_${idToQuery.substring(0, min(idToQuery.length, 5))}',
      email: '',
      displayName: 'Creaniaa Student',
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
    if (Get.isRegistered<ChatController>()) {
      Get.find<ChatController>().clearAllDataOnLogout();
    }
    _notifyListeners();
  }

  static Future<bool> validateCurrentUserSession() async {
    final client = Supabase.instance.client;

    // ── Wait briefly for Supabase to restore persisted session on cold start ──
    Session? session = client.auth.currentSession;
    if (session == null) {
      // Give the SDK up to 1 second to restore its persisted session
      for (int i = 0; i < 5; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        session = client.auth.currentSession;
        if (session != null) break;
      }
    }

    if (session == null) {
      // No session even after wait — check if Remember Me can restore it
      debugPrint('[CacheManager] No session found after cold-start wait');
      return false;
    }

    try {
      // Deactivate expired memberships on the backend (fire & forget)
      client.rpc('check_and_clean_expired_memberships').catchError((_) {});

      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        // This should not happen if session != null, treat as network issue
        debugPrint('[CacheManager] currentUser null despite valid session — keeping logged in');
        return true;
      }

      // Check if matching row exists in profiles
      Map<String, dynamic>? data;
      try {
        data = await client
            .from('profiles')
            .select('status, is_banned, ban_reason')
            .eq('id', currentUser.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));
      } catch (netErr) {
        // Network error — keep user logged in, don't logout
        debugPrint('[CacheManager] Profile fetch network error (keeping logged in): $netErr');
        return true;
      }

      if (data == null) {
        // Attempt to auto-recreate the profiles row if missing
        try {
          final newUsername =
              'user_${currentUser.id.replaceAll('-', '').substring(0, 8)}';
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
            'signup_status': 'otp_verified',
          });
          final refetched = await client
              .from('profiles')
              .select('status, is_banned, ban_reason')
              .eq('id', currentUser.id)
              .maybeSingle();
          if (refetched != null) {
            data = refetched;
          } else {
            // Could not recreate — treat as network/DB issue, keep logged in
            debugPrint('[CacheManager] Profile row missing and recreation failed — keeping logged in');
            return true;
          }
        } catch (e) {
          // Recreation failed due to network — keep logged in
          debugPrint('[CacheManager] Profile recreation error (keeping logged in): $e');
          return true;
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
      try {
        final banLedger = await client
            .from('bans')
            .select('reason')
            .eq('user_id', currentUser.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 3));

        if (banLedger != null) {
          final reason = banLedger['reason'] as String?;
          await forceLogout(
            message: reason != null && reason.isNotEmpty
                ? "Your account has been suspended. Reason: $reason"
                : "Your account has been suspended.",
          );
          return false;
        }
      } catch (_) {
        // Ban check network error — keep logged in
      }

      // Ensure active session registration (non-blocking)
      registerSession(currentUser.id).catchError((_) => false);

      // Validate session ID on backend via RPC
      try {
        final bool isSessionActive = await client.rpc('validate_active_session', params: {
          'p_user_id': currentUser.id,
          'p_session_id': currentSessionId,
        }).timeout(const Duration(seconds: 3));

        if (!isSessionActive) {
          await forceLogout(
              message: "Your account has been logged in from another device.");
          return false;
        }
      } catch (e) {
        debugPrint('[CacheManager] Active session RPC validation warning (keeping logged in): $e');
        // Network error during session check — keep user logged in
      }

      return true;
    } catch (e) {
      debugPrint('[CacheManager] Session validation error: $e');
      final errStr = e.toString().toLowerCase();

      // Only logout on confirmed authentication failures
      final isAuthError = errStr.contains('jwt expired') ||
          errStr.contains('invalid jwt') ||
          errStr.contains('token is expired') ||
          errStr.contains('401');

      if (isAuthError) {
        // Try to refresh the session first
        try {
          final res = await client.auth.refreshSession();
          if (res.session != null) {
            debugPrint('[CacheManager] Session refreshed successfully');
            return true;
          }
          await forceLogout(message: "Your session has expired. Please sign in again.");
          return false;
        } catch (_) {
          await forceLogout(message: "Your session has expired. Please sign in again.");
          return false;
        }
      }

      // For all other errors (network, timeout, etc.) — keep user logged in
      return true;
    }
  }

  static Future<void> forceLogout({required String message}) async {
    final uid = currentUserId;
    if (uid.isNotEmpty) {
      final nowIso = DateTime.now().toIso8601String();
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'last_seen': nowIso})
            .eq('id', uid);
      } catch (_) {}

      try {
        if (Get.isRegistered<ChatSocketService>()) {
          ChatSocketService.to.disconnect();
        }
      } catch (_) {}
    }

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}

    clear();

    // ── Normal logout: clear session token, keep email + Last Login ──
    try {
      await AuthMemoryService.clearSession();
    } catch (_) {}

    try {
      final isar = IsarStorageService.to;
      await isar.deleteConversation('offline_profiles_cache');
    } catch (_) {}

    try {
      _currentSessionId = '';
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_session_id');
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
      debugPrint(
          '[CacheManager] Connections loaded. Following: ${followed.length}, Followers: ${followers.length}');

      // Save to Isar offline cache
      try {
        final isar = IsarStorageService.to;
        final connData = {
          'followed': followed.toList(),
          'followers': followers.toList(),
          'statuses': statuses,
        };
        await isar.saveCacheEntry(
            'offline_connections_cache', jsonEncode(connData));
      } catch (e) {
        debugPrint('[CacheManager] Error saving connections cache to Isar: $e');
      }
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
      _currentUser = me.copyWith(
        following: me.following + 1,
        friendsCount: isMutual ? me.friendsCount + 1 : me.friendsCount,
      );
      rxCache[myId] = _currentUser!;
    }
    final target = rxCache[targetUserId];
    if (target != null) {
      rxCache[targetUserId] = target.copyWith(
        followers: target.followers + 1,
        friendsCount: isMutual ? target.friendsCount + 1 : target.friendsCount,
      );
    }
    _notifyListeners();

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
      _currentUser = me.copyWith(
        following: me.following - 1 >= 0 ? me.following - 1 : 0,
        friendsCount: wasMutual
            ? (me.friendsCount - 1 >= 0 ? me.friendsCount - 1 : 0)
            : me.friendsCount,
      );
      rxCache[myId] = _currentUser!;
    }
    final target = rxCache[targetUserId];
    if (target != null) {
      rxCache[targetUserId] = target.copyWith(
        followers: target.followers - 1 >= 0 ? target.followers - 1 : 0,
        friendsCount: wasMutual
            ? (target.friendsCount - 1 >= 0 ? target.friendsCount - 1 : 0)
            : target.friendsCount,
      );
    }
    _notifyListeners();

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
      debugPrint(
          '[UserProfileCacheManager] Subscribed to connections table Realtime updates.');
    } catch (e) {
      debugPrint(
          '[UserProfileCacheManager] Connections realtime subscription failed: $e');
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
                final userObj =
                    User.fromJson(Map<String, dynamic>.from(newRecord));

                _cache[userId] = userObj;
                rxCache[userId] = userObj;
                if (userId == currentUserId) {
                  _currentUser = userObj;

                  // Rule 1 & 2 & 17: Check active_session_id mismatch and ban status
                  final String? activeSessionId = newRecord['active_session_id']?.toString();
                  final bool isBanned = newRecord['is_banned'] as bool? ?? false;
                  final String? status = newRecord['status']?.toString();

                  if (activeSessionId != null && activeSessionId.isNotEmpty && activeSessionId != currentSessionId) {
                    forceLogout(message: "Your account has been logged in from another device.");
                    return;
                  }

                  if (isBanned || status == 'suspended' || status == 'banned') {
                    forceLogout(message: "Your account has been suspended.");
                    return;
                  }

                  // Update GetX controllers in real-time
                  try {
                    if (Get.isRegistered<VipController>()) {
                      final vipCtrl = Get.find<VipController>();
                      final newVipLevel = (newRecord['vip_level'] ?? 0).toInt();
                      vipCtrl.vipLevel.value = newVipLevel;
                      final expiryStr = newRecord['vip_expiry'];
                      if (expiryStr != null) {
                        vipCtrl.expiryDate.value = DateTime.tryParse(expiryStr);
                      } else {
                        vipCtrl.expiryDate.value = null;
                      }
                      vipCtrl.saveState(syncToRemote: false);
                    }
                  } catch (_) {}
                  try {
                    if (Get.isRegistered<NovelController>()) {
                      final novelCtrl = Get.find<NovelController>();
                      novelCtrl.novelLevel.value =
                          (newRecord['novel_level'] ?? 0).toInt();
                      final expiryStr = newRecord['novel_expiry'];
                      if (expiryStr != null) {
                        novelCtrl.expiryDate.value =
                            DateTime.tryParse(expiryStr);
                      } else {
                        novelCtrl.expiryDate.value = null;
                      }
                      novelCtrl.saveState(syncToRemote: false);
                    }
                  } catch (_) {}
                  try {
                    if (Get.isRegistered<CustomizationController>()) {
                      final frameVal = newRecord['avatar_frame']?.toString();
                      if (frameVal != null && frameVal.isNotEmpty) {
                        Get.find<CustomizationController>().activeFrame.value = frameVal;
                      }
                      // Reload full inventory on any VIP/Novel/frame profile change
                      Get.find<CustomizationController>().fetchFullInventoryAndEntitlementsViaRpc();
                    }
                  } catch (_) {}
                  try {
                    if (Get.isRegistered<CareerProgressionController>()) {
                      final cCtrl = Get.find<CareerProgressionController>();
                      cCtrl.idLevel.value = (newRecord['level'] ?? 1).toInt();
                      cCtrl.idXp.value = (newRecord['experience'] ?? 0).toInt();
                      cCtrl.careerLevel.value =
                          (newRecord['career_level'] ?? 1).toInt();
                      cCtrl.careerXp.value =
                          (newRecord['career_xp'] ?? 0).toInt();
                    }
                  } catch (_) {}
                }

                _notifyListeners();
                if (userObj.avatar != null && userObj.avatar!.isNotEmpty) {
                  AssetCacheManager.evictUrl(userObj.avatar!);
                }
                broadcastEquipConfirmed();
                AssetCacheManager.prefetchProfileAssets(userObj);
                debugPrint(
                    '[UserProfileCacheManager] Realtime update notified for: $userId');
              }
            },
          );
      _realtimeChannel?.subscribe();
      debugPrint(
          '[UserProfileCacheManager] Subscribed to profiles table Realtime updates.');
    } catch (e) {
      debugPrint('[UserProfileCacheManager] Realtime subscription failed: $e');
    }

    // Subscribe to user_customizations table for real-time tool equipping sync
    try {
      _customizationsRealtimeChannel = Supabase.instance.client
          .channel('public:user_customizations_cache_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_customizations',
            callback: (payload) {
              final newRecord = payload.newRecord ?? payload.oldRecord;
              if (newRecord != null && newRecord['user_id'] != null) {
                final String userId = newRecord['user_id'] as String;
                fetchUserProfile(userId, forceRefresh: true).then((userObj) {
                  if (userId == currentUserId && Get.isRegistered<CustomizationController>()) {
                    Get.find<CustomizationController>().refreshCustomizations();
                  }
                  broadcastEquipConfirmed();
                });
              }
            },
          );
      _customizationsRealtimeChannel?.subscribe();
      debugPrint('[UserProfileCacheManager] Subscribed to user_customizations table Realtime updates.');
    } catch (e) {
      debugPrint('[UserProfileCacheManager] user_customizations Realtime subscription failed: $e');
    }

    // Subscribe to user_sessions table for Single Device Login rule enforcement
    try {
      if (currentUserId.isNotEmpty) {
        _sessionRealtimeChannel = Supabase.instance.client
            .channel('public:user_sessions_realtime_$currentUserId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'user_sessions',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: currentUserId,
              ),
              callback: (payload) {
                final newRecord = payload.newRecord;
                if (newRecord != null) {
                  final String? status = newRecord['online_status']?.toString();
                  final String? sid = newRecord['session_id']?.toString();
                  // CRITICAL FIX: Only trigger logout if THIS device's active currentSessionId was set to 'Offline' (which happens when ANOTHER device inserts a new session)
                  if (sid != null && sid == currentSessionId && status == 'Offline') {
                    forceLogout(
                        message: "Your account has been logged in from another device.");
                  }
                }
              },
            );
        _sessionRealtimeChannel?.subscribe();
        debugPrint(
            '[UserProfileCacheManager] Subscribed to user_sessions table Realtime updates.');
      }
    } catch (e) {
      debugPrint(
          '[UserProfileCacheManager] user_sessions realtime subscription failed: $e');
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
                      Get.find<StoreController>().coinsBalance.value =
                          coins.toInt();
                      Get.find<StoreController>().silverCoinsBalance.value =
                          silver.toInt();
                    }
                  } catch (_) {}
                }
              }
            },
          );
      walletsChannel.subscribe();
      debugPrint(
          '[UserProfileCacheManager] Subscribed to wallets table Realtime updates.');
    } catch (e) {
      debugPrint(
          '[UserProfileCacheManager] Wallets realtime subscription failed: $e');
    }

    // Subscribe to gift_transactions table to refresh stats in real-time
    try {
      _giftRealtimeChannel = Supabase.instance.client
          .channel('public:gift_transactions_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'gift_transactions',
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord != null) {
                final senderId = newRecord['sender_id'] as String?;
                final receiverId = newRecord['receiver_id'] as String?;
                final currentId = currentUserId;
                if (currentId.isNotEmpty &&
                    (senderId == currentId || receiverId == currentId)) {
                  debugPrint(
                      '[UserProfileCacheManager] Realtime gift transaction involving user detected.');
                  giftTransactionsTrigger.value++;
                  _notifyListeners();
                }
              }
            },
          );
      _giftRealtimeChannel?.subscribe();
      debugPrint(
          '[UserProfileCacheManager] Subscribed to gift_transactions table Realtime updates.');
    } catch (e) {
      debugPrint(
          '[UserProfileCacheManager] Gift transactions realtime subscription failed: $e');
    }

    // Subscribe to subscriptions table changes for VIP/Novel real-time sync
    try {
      Supabase.instance.client
          .channel('public:subscriptions_cache_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'subscriptions',
            callback: (payload) {
              final record = payload.newRecord ?? payload.oldRecord;
              if (record != null && record['user_id'] != null) {
                final String userId = record['user_id'].toString();
                if (userId == currentUserId) {
                  debugPrint('[UserProfileCacheManager] Subscriptions Realtime change detected. Reloading VIP/Novel state.');
                  // Reload VIP and Novel from backend as the source of truth
                  try {
                    if (Get.isRegistered<VipController>()) {
                      Get.find<VipController>().loadVipFromDatabase();
                    }
                  } catch (_) {}
                  try {
                    if (Get.isRegistered<NovelController>()) {
                      Get.find<NovelController>().loadNovelFromDatabase();
                    }
                  } catch (_) {}
                  try {
                    if (Get.isRegistered<CustomizationController>()) {
                      Get.find<CustomizationController>().fetchFullInventoryAndEntitlementsViaRpc();
                    }
                  } catch (_) {}
                }
              }
            },
          )
          .subscribe();
      debugPrint('[UserProfileCacheManager] Subscribed to subscriptions table Realtime updates.');
    } catch (e) {
      debugPrint('[UserProfileCacheManager] Subscriptions realtime subscription failed: $e');
    }

    // Auth state change listener: auto-reload on reconnect / token refresh
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        if (event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.signedIn) {
          final uid = currentUserId;
          if (uid.isNotEmpty) {
            debugPrint('[UserProfileCacheManager] Auth event: $event — reloading profile, VIP, Novel, and inventory.');
            fetchUserProfile(uid, forceRefresh: true);
            try { if (Get.isRegistered<VipController>()) Get.find<VipController>().loadVipFromDatabase(); } catch (_) {}
            try { if (Get.isRegistered<NovelController>()) Get.find<NovelController>().loadNovelFromDatabase(); } catch (_) {}
            try { if (Get.isRegistered<CustomizationController>()) Get.find<CustomizationController>().fetchFullInventoryAndEntitlementsViaRpc(); } catch (_) {}
          }
        }
      });
      debugPrint('[UserProfileCacheManager] Auth state change listener registered.');
    } catch (e) {
      debugPrint('[UserProfileCacheManager] Auth state change listener failed: $e');
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
        debugPrint(
            '[CacheManager] Loaded ${_cache.length} profiles from Isar offline cache.');
      }

      // Load cached connections
      final connPayload =
          await isar.getCacheEntryPayload('offline_connections_cache');
      if (connPayload != null && connPayload.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(connPayload);
        final followed = List<String>.from(decoded['followed'] ?? []);
        final followers = List<String>.from(decoded['followers'] ?? []);
        final Map<String, dynamic> rawStatuses = decoded['statuses'] ?? {};
        final statuses = rawStatuses.map((k, v) => MapEntry(k, v.toString()));

        followedUserIds.assignAll(followed);
        followerUserIds.assignAll(followers);
        connectionStatuses.assignAll(statuses);
        debugPrint(
            '[CacheManager] Connections loaded from Isar offline cache.');
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
      await isar.saveCacheEntry(
          'offline_profiles_cache', jsonEncode(dataToSave));
    } catch (e) {
      debugPrint('[CacheManager] Error saving to Isar offline cache: $e');
    }
  }

  static Future<void> syncDeltaProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? lastSyncStr =
          prefs.getString('profiles_last_sync_timestamp');

      var query = Supabase.instance.client.from('profiles').select();

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
        await prefs.setString('profiles_last_sync_timestamp',
            DateTime.now().toUtc().toIso8601String());
        _saveCacheToOffline();
        _notifyListeners();
        debugPrint(
            '[CacheManager] Delta sync completed. Processed ${list.length} profiles.');
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
      debugPrint(
          '[CacheManager] rebuildAndSyncCurrentUserTagSystem failed: $e');
    }
  }
}
