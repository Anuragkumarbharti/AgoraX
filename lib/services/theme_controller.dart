import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_cache_manager.dart';

class ThemeController extends GetxController {
  static ThemeController get to => Get.find<ThemeController>();

  final RxString currentThemePreference = 'system'.obs;

  @override
  void onInit() {
    super.onInit();
    _loadThemePreference();
  }

  ThemeMode get activeThemeMode {
    switch (currentThemePreference.value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefVal = prefs.getString('theme_preference') ?? 'system';
      currentThemePreference.value = prefVal;
      Get.changeThemeMode(activeThemeMode);
    } catch (e) {
      debugPrint('[ThemeController] Error loading preference: $e');
    }
  }

  Future<void> updateThemePreference(String preference) async {
    if (preference != 'system' && preference != 'light' && preference != 'dark') {
      return;
    }
    
    currentThemePreference.value = preference;
    Get.changeThemeMode(activeThemeMode);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_preference', preference);

      try {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null) {
          final canonicalId = await UserProfileCacheManager.getOrFetchCanonicalId();
          await Supabase.instance.client
              .from('profiles')
              .update({'theme_preference': preference})
              .eq('id', canonicalId);
          debugPrint('[ThemeController] Synced preference to Supabase: $preference');
        }
      } catch (supabaseError) {
        if (!supabaseError.toString().contains('initialize')) {
          debugPrint('[ThemeController] Error syncing to Supabase: $supabaseError');
        }
      }
    } catch (e) {
      debugPrint('[ThemeController] Error updating preference: $e');
    }
  }

  Future<void> syncThemeFromDatabase() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;
      
      final canonicalId = await UserProfileCacheManager.getOrFetchCanonicalId();
      final data = await Supabase.instance.client
          .from('profiles')
          .select('theme_preference')
          .eq('id', canonicalId)
          .maybeSingle();
      
      if (data != null && data['theme_preference'] != null) {
        final pref = data['theme_preference'] as String;
        currentThemePreference.value = pref;
        Get.changeThemeMode(activeThemeMode);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('theme_preference', pref);
        debugPrint('[ThemeController] Loaded preference from database: $pref');
      }
    } catch (e) {
      if (!e.toString().contains('initialize')) {
        debugPrint('[ThemeController] Error syncing from DB: $e');
      }
    }
  }
}
