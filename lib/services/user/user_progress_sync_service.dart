import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:get/get.dart';

import '../store/store_controller.dart';
import '../progression/career_progression_controller.dart';
import '../vault/study_category_controller.dart';
import '../room/room_controller.dart';
import '../community/community_controller.dart';
import '../memberships/vip_controller.dart';
import '../memberships/novel_controller.dart';
import '../vault/study_vault_controller.dart';
import './customization_controller.dart';
import '../../models/user/user_model.dart';
import './user_profile_cache_manager.dart';

class UserProgressSyncService {
  static Timer? _debounceTimer;
  static bool _isSyncingFromRemote = false;

  /// Trigger debounced sync of local progression state to Supabase database
  static void syncToSupabase() {
    if (_isSyncingFromRemote) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      _executeSyncToSupabase();
    });
  }

  static Future<void> _executeSyncToSupabase() async {
    if (_isSyncingFromRemote) return;
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final Map<String, dynamic> metadata = {};

      for (final key in keys) {
        if (key.startsWith('vip_') ||
            key.startsWith('novel_') ||
            key.startsWith('vault_') ||
            key.startsWith('study_') ||
            key.startsWith('store_') ||
            key.startsWith('prog_') ||
            key.startsWith('customization_') ||
            key.startsWith('premium_') ||
            key.startsWith('followed_') ||
            key == 'user_created_communities' ||
            key == 'user_created_rooms') {
          final val = prefs.get(key);
          if (val != null) {
            metadata[key] = val;
          }
        }
      }

      final canonicalId = await UserProfileCacheManager.getOrFetchCanonicalId();
      await Supabase.instance.client
          .from('profiles')
          .update({'progress_metadata': metadata})
          .eq('id', canonicalId);

      debugPrint('Sync: Successfully updated user progress metadata on Supabase.');
    } catch (e) {
      debugPrint('Sync Error: Failed to upload user progress to Supabase: $e');
    }
  }

  /// Download and sync progress from Supabase database
  static Future<void> syncFromSupabase() async {
    if (_isSyncingFromRemote) return;
    _isSyncingFromRemote = true;
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final canonicalId = await UserProfileCacheManager.getOrFetchCanonicalId();
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', canonicalId)
          .maybeSingle();

      if (response != null) {
        // Cache the current user's profile details
        response['email'] = currentUser.email ?? '';
        final userObj = User.fromJson(response);
        UserProfileCacheManager.setCurrentUser(userObj);

        if (response['progress_metadata'] != null) {
          final Map<String, dynamic> metadata = Map<String, dynamic>.from(response['progress_metadata']);
          final prefs = await SharedPreferences.getInstance();

          for (final entry in metadata.entries) {
            final key = entry.key;
            final value = entry.value;

            if (value is int) {
              await prefs.setInt(key, value);
            } else if (value is double) {
              await prefs.setDouble(key, value);
            } else if (value is bool) {
              await prefs.setBool(key, value);
            } else if (value is String) {
              await prefs.setString(key, value);
            } else if (value is List) {
              await prefs.setStringList(key, List<String>.from(value));
            }
          }
        }
        debugPrint('Sync: Successfully downloaded user progress metadata from Supabase.');
        _refreshAllControllers();
      }
    } catch (e) {
      debugPrint('Sync Error: Failed to download user progress from Supabase: $e');
    } finally {
      _isSyncingFromRemote = false;
    }
  }

  static void _refreshAllControllers() {
    try {
      // Refresh state values in-memory safely across injected GetX controllers without re-attaching listeners
      if (Get.isRegistered<StoreController>()) {
        Get.find<StoreController>().syncWithDatabase();
      }
      if (Get.isRegistered<VipController>()) {
        final vipCtrl = Get.find<VipController>();
        vipCtrl.loadVipFromDatabase();
      }
      if (Get.isRegistered<NovelController>()) {
        final novelCtrl = Get.find<NovelController>();
        novelCtrl.loadNovelFromDatabase();
      }
      if (Get.isRegistered<CustomizationController>()) {
        Get.find<CustomizationController>().refreshCustomizations();
      }
    } catch (e) {
      debugPrint('Sync: Error refreshing controllers: $e');
    }
  }
}
