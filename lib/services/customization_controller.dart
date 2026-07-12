import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'vip_controller.dart';
import 'novel_controller.dart';
import 'user_profile_cache_manager.dart';

class CustomizationController extends GetxController {
  static String get currentUserId => UserProfileCacheManager.currentUserId;

  // SharedPreferences Keys (Local cache fallback/Visual settings)
  static const String _keyTheme = 'cust_active_theme';
  static const String _keyFavorites = 'cust_favorites';

  // Observables
  final RxString activeFrame = 'Normal'.obs;
  final RxString activeBubble = 'Classic Bubble'.obs;
  final RxString activeEntryEffect = 'None'.obs;
  final RxString activeAvatarEffect = 'None'.obs;
  final RxString activeNameEffect = 'None'.obs;
  final RxString activeTheme = 'Dark'.obs;
  final RxString activeBackground = 'None'.obs;
  final RxString activeAvatar = 'Default'.obs;
  final RxString customAvatarPath = ''.obs;
  final RxString activeEmojiPack = 'Classic Emojis'.obs;

  final RxList<String> activeBadges = <String>[].obs; // Max 5 badges
  final RxList<String> activeTags = <String>[].obs; // Max 3 tags
  final RxList<String> activeGifts = <String>[].obs; // Max 3 gifts
  final RxList<String> favorites = <String>[].obs;
  final RxList<String> unlockedItems = <String>[].obs;

  // Track expiry date for each cosmetic item
  final RxMap<String, DateTime> itemExpiries = <String, DateTime>{}.obs;

  // Central customization database with items and metadata
  final List<Map<String, dynamic>> customizationDb = [
    // 1. Avatar Frames (Static & Animated)
    {'name': 'Normal', 'category': 'Avatar Frame', 'rarity': 'Common', 'premium': 'None', 'req': 'Default unlocked border'},
    {'name': 'Early Explorer Frame', 'category': 'Avatar Frame', 'rarity': 'Rare', 'premium': 'None', 'req': 'Profile Completion Badge'},
    // VIP Frames
    {'name': 'Royal Frame', 'category': 'Avatar Frame', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Neon Frame (Animated)', 'category': 'Avatar Frame', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2'},
    {'name': 'Gold Glow Frame', 'category': 'Avatar Frame', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Diamond Frame', 'category': 'Avatar Frame', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 4'},
    {'name': 'Crystal Cyan Frame', 'category': 'Avatar Frame', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 5'},
    {'name': 'Rainbow Frame (Animated)', 'category': 'Avatar Frame', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 6'},
    {'name': 'Royal Crown (Animated)', 'category': 'Avatar Frame', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 7'},
    // Novel Frames
    {'name': 'Galaxy Orbit (Animated)', 'category': 'Avatar Frame', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Galaxy Novel II'},
    {'name': 'Royal Gold Palace', 'category': 'Avatar Frame', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Royal Novel III'},
    {'name': 'Dragon Fire Frame', 'category': 'Avatar Frame', 'rarity': 'Limited', 'premium': 'Novel', 'req': 'Unlock with Dragon Novel IV'},
    {'name': 'Phoenix Flame (Animated)', 'category': 'Avatar Frame', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Phoenix Novel V'},
    {'name': 'Celestial Sky Frame', 'category': 'Avatar Frame', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Celestial Novel VI'},
    {'name': 'Cosmic Emperor (Animated)', 'category': 'Avatar Frame', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII'},

    // 2. Chat Bubbles
    {'name': 'Classic Bubble', 'category': 'Chat Bubble', 'rarity': 'Common', 'premium': 'None', 'req': 'Default'},
    // VIP Bubbles
    {'name': 'Royal Bubble', 'category': 'Chat Bubble', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Blue Shield Bubble', 'category': 'Chat Bubble', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Neon Bubble', 'category': 'Chat Bubble', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2'},
    {'name': 'VIP Bubble', 'category': 'Chat Bubble', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Golden Shimmer Bubble', 'category': 'Chat Bubble', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Diamond Bubble', 'category': 'Chat Bubble', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 4'},
    {'name': 'Crystal Cyan Neon Bubble', 'category': 'Chat Bubble', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 5'},
    {'name': 'Rainbow Bubble', 'category': 'Chat Bubble', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 6'},
    {'name': 'Emperor Bubble', 'category': 'Chat Bubble', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 7'},
    // Novel Bubbles
    {'name': 'Galaxy Bubble', 'category': 'Chat Bubble', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Galaxy Novel II'},
    {'name': 'Royal Palace Bubble', 'category': 'Chat Bubble', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Royal Novel III'},
    {'name': 'Dragon Fire Bubble', 'category': 'Chat Bubble', 'rarity': 'Limited', 'premium': 'Novel', 'req': 'Unlock with Dragon Novel IV'},
    {'name': 'Phoenix Bubble', 'category': 'Chat Bubble', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Phoenix Novel V'},
    {'name': 'Celestial Bubble', 'category': 'Chat Bubble', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Celestial Novel VI'},
    {'name': 'Cosmic Emperor Bubble', 'category': 'Chat Bubble', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII'},

    // 3. Entry Effects
    {'name': 'None', 'category': 'Entry Effect', 'rarity': 'Common', 'premium': 'None', 'req': 'Default'},
    // VIP Entry Effects
    {'name': 'Royal Portal', 'category': 'Entry Effect', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Neon Gateway', 'category': 'Entry Effect', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2'},
    {'name': 'Golden Explosion', 'category': 'Entry Effect', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Diamond Shatter', 'category': 'Entry Effect', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 4'},
    {'name': 'Crystal Blizzard', 'category': 'Entry Effect', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 5'},
    {'name': 'Rainbow Bridge', 'category': 'Entry Effect', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 6'},
    {'name': 'Emperor Throne Room', 'category': 'Entry Effect', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 7'},
  ];

  @override
  void onInit() {
    super.onInit();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    activeTheme.value = prefs.getString(_keyTheme) ?? 'Dark';

    // Load Favorites
    final favsJson = prefs.getString(_keyFavorites);
    if (favsJson != null) {
      try {
        final decoded = json.decode(favsJson) as List<dynamic>;
        favorites.assignAll(decoded.cast<String>());
      } catch (_) {}
    }

    try {
      final List<dynamic> list = await Supabase.instance.client
          .from('user_customizations')
          .select()
          .eq('user_id', currentUserId);

      // Unlocked items
      unlockedItems.assignAll(list.map((m) => m['name'] as String).toList());
      
      // Default seeds
      final defaults = [
        'Normal', 'Classic Bubble', 'None', 'Legend', 'Explorer', 'Scholar', 'Dark', 'Default', 'Classic Emojis', 'Love Castle', 'Early Explorer Frame'
      ];
      for (final def in defaults) {
        if (!unlockedItems.contains(def)) {
          unlockedItems.add(def);
        }
      }

      // Filter equipped
      final equipped = list.where((m) => m['is_equipped'] == true).toList();
      
      activeFrame.value = equipped.firstWhereOrNull((m) => m['type'] == 'Avatar Frame')?['name'] ?? 'Normal';
      activeBubble.value = equipped.firstWhereOrNull((m) => m['type'] == 'Chat Bubble')?['name'] ?? 'Classic Bubble';
      activeEntryEffect.value = equipped.firstWhereOrNull((m) => m['type'] == 'Entry Effect')?['name'] ?? 'None';
      activeAvatarEffect.value = equipped.firstWhereOrNull((m) => m['type'] == 'Avatar Effect')?['name'] ?? 'None';
      activeNameEffect.value = equipped.firstWhereOrNull((m) => m['type'] == 'Name Effect')?['name'] ?? 'None';
      activeBackground.value = equipped.firstWhereOrNull((m) => m['type'] == 'Background')?['name'] ?? 'None';
      activeEmojiPack.value = equipped.firstWhereOrNull((m) => m['type'] == 'Emoji Pack')?['name'] ?? 'Classic Emojis';

      activeBadges.assignAll(equipped.where((m) => m['type'] == 'Badge').map((m) => m['name'] as String).toList());
      if (activeBadges.isEmpty) activeBadges.assignAll(['Legend', 'Explorer']);

      activeTags.assignAll(equipped.where((m) => m['type'] == 'Tag').map((m) => m['name'] as String).toList());
      if (activeTags.isEmpty) activeTags.assignAll(['Scholar']);

      activeGifts.assignAll(equipped.where((m) => m['type'] == 'Gift').map((m) => m['name'] as String).toList());
      if (activeGifts.isEmpty) activeGifts.assignAll(['Love Castle']);

    } catch (e) {
      debugPrint('Supabase Customizations Load failed: $e');
    }
  }

  bool isItemUnlocked(String itemName) {
    if (itemName == 'Normal' || itemName == 'None' || itemName == 'Classic Bubble' || itemName == 'Dark' || itemName == 'Default' || itemName == 'Classic Emojis' || itemName == 'Love Castle' || itemName == 'Scholar' || itemName == 'Early Explorer Frame') {
      return true;
    }

    if (itemExpiries.containsKey(itemName)) {
      return itemExpiries[itemName]!.isAfter(DateTime.now());
    }

    if (unlockedItems.contains(itemName)) {
      return true;
    }

    final item = customizationDb.firstWhere(
      (element) => element['name'] == itemName,
      orElse: () => <String, dynamic>{},
    );

    if (item.isEmpty) return false;

    final premium = item['premium'] as String;
    final req = item['req'] as String;

    try {
      if (premium == 'VIP') {
        final vipCtrl = Get.find<VipController>();
        final vipLvl = vipCtrl.vipLevel.value;
        final match = RegExp(r'Level\s+(\d+)').firstMatch(req);
        int reqLevel = 0;
        if (match != null) {
          reqLevel = int.tryParse(match.group(1) ?? '0') ?? 0;
        } else if (req.contains('Level 1')) reqLevel = 1;
        else if (req.contains('Level 2')) reqLevel = 2;
        else if (req.contains('Level 3')) reqLevel = 3;
        else if (req.contains('Level 4')) reqLevel = 4;
        else if (req.contains('Level 5')) reqLevel = 5;
        else if (req.contains('Level 6')) reqLevel = 6;
        else if (req.contains('Level 7')) reqLevel = 7;

        if (vipLvl >= reqLevel) return true;
      }

      if (premium == 'Novel') {
        final novelCtrl = Get.find<NovelController>();
        int reqLevel = 0;
        if (req.contains(' Novel I') || req.contains(' Novel 1') || req.contains('Level 1')) reqLevel = 1;
        else if (req.contains(' Novel II') || req.contains(' Novel 2') || req.contains('Level 2')) reqLevel = 2;
        else if (req.contains(' Novel III') || req.contains(' Novel 3') || req.contains('Level 3')) reqLevel = 3;
        else if (req.contains(' Novel IV') || req.contains(' Novel 4') || req.contains('Level 4')) reqLevel = 4;
        else if (req.contains(' Novel V') || req.contains(' Novel 5') || req.contains('Level 5')) reqLevel = 5;
        else if (req.contains(' Novel VI') || req.contains(' Novel 6') || req.contains('Level 6')) reqLevel = 6;
        else if (req.contains(' Novel VII') || req.contains(' Novel 7') || req.contains('Level 7')) reqLevel = 7;

        if (reqLevel > 0) {
          if (novelCtrl.ownedNovels.contains(reqLevel) || novelCtrl.novelLevel.value >= reqLevel) {
            return true;
          }
        }
      }
    } catch (_) {}

    return false;
  }

  String getAvatarUrl(String avatarName, String defaultUrl) {
    if (avatarName == 'Default') {
      if (customAvatarPath.isNotEmpty) {
        return customAvatarPath.value;
      }
      return defaultUrl;
    }
    switch (avatarName) {
      case 'VIP Gold Crown':
        return 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400';
      case 'Neon Gamer Tech':
        return 'https://images.unsplash.com/photo-1614850523459-c2f4c699c52e?w=400';
      case 'Galaxy Mage Cosmic':
        return 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=400';
      case 'Cyberpunk Samurai':
        return 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=400';
      case 'Crimson Dragon Lord':
        return 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=400';
      default:
        return defaultUrl;
    }
  }

  Future<void> equipItem(String category, String itemName) async {
    if (!isItemUnlocked(itemName)) {
      Get.snackbar(
        '⚠️ Item Locked',
        'You need to unlock $itemName first.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    try {
      await Supabase.instance.client
          .from('user_customizations')
          .update({'is_equipped': false})
          .eq('user_id', currentUserId)
          .eq('type', category);

      await Supabase.instance.client
          .from('user_customizations')
          .upsert({
            'user_id': currentUserId,
            'type': category,
            'name': itemName,
            'is_equipped': true,
          });

      await _loadState();

      // Also update frame attribute on profiles table if Avatar Frame
      if (category == 'Avatar Frame') {
        await Supabase.instance.client
            .from('profiles')
            .update({'avatar_frame': itemName})
            .eq('id', currentUserId);
      }

      Get.snackbar(
        '✨ Equipped Successfully',
        '$itemName is now active!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981).withOpacity(0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
      );
    } catch (_) {}
  }

  Future<void> removeItem(String category) async {
    try {
      await Supabase.instance.client
          .from('user_customizations')
          .update({'is_equipped': false})
          .eq('user_id', currentUserId)
          .eq('type', category);

      await _loadState();
    } catch (_) {}
  }

  Future<void> toggleFavorite(String itemName) async {
    final prefs = await SharedPreferences.getInstance();
    if (favorites.contains(itemName)) {
      favorites.remove(itemName);
    } else {
      favorites.add(itemName);
    }
    await prefs.setString(_keyFavorites, json.encode(favorites.toList()));
  }

  Future<void> toggleBadge(String badgeName) async {
    final category = 'Badge';
    final isEquipped = activeBadges.contains(badgeName);

    try {
      if (isEquipped) {
        await Supabase.instance.client
            .from('user_customizations')
            .update({'is_equipped': false})
            .eq('user_id', currentUserId)
            .eq('type', category)
            .eq('name', badgeName);
      } else {
        if (activeBadges.length >= 5) {
          Get.snackbar(
            '⚠️ Maximum Badges Reached',
            'You can equip a maximum of 5 badges simultaneously.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
            colorText: Colors.white,
          );
          return;
        }
        await Supabase.instance.client
            .from('user_customizations')
            .upsert({
              'user_id': currentUserId,
              'type': category,
              'name': badgeName,
              'is_equipped': true,
            });
      }
      await _loadState();
    } catch (_) {}
  }

  Future<void> toggleTag(String tagName) async {
    final category = 'Tag';
    final isEquipped = activeTags.contains(tagName);

    try {
      if (isEquipped) {
        await Supabase.instance.client
            .from('user_customizations')
            .update({'is_equipped': false})
            .eq('user_id', currentUserId)
            .eq('type', category)
            .eq('name', tagName);
      } else {
        if (activeTags.length >= 3) {
          Get.snackbar(
            '⚠️ Maximum Tags Reached',
            'You can display a maximum of 3 tags simultaneously.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
            colorText: Colors.white,
          );
          return;
        }
        await Supabase.instance.client
            .from('user_customizations')
            .upsert({
              'user_id': currentUserId,
              'type': category,
              'name': tagName,
              'is_equipped': true,
            });
      }
      await _loadState();
    } catch (_) {}
  }

  Future<void> toggleGift(String giftName) async {
    final category = 'Gift';
    final isEquipped = activeGifts.contains(giftName);

    try {
      if (isEquipped) {
        await Supabase.instance.client
            .from('user_customizations')
            .update({'is_equipped': false})
            .eq('user_id', currentUserId)
            .eq('type', category)
            .eq('name', giftName);
      } else {
        if (activeGifts.length >= 3) {
          Get.snackbar(
            '⚠️ Maximum Showcase Reached',
            'You can display a maximum of 3 gifts in the showcase.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
            colorText: Colors.white,
          );
          return;
        }
        await Supabase.instance.client
            .from('user_customizations')
            .upsert({
              'user_id': currentUserId,
              'type': category,
              'name': giftName,
              'is_equipped': true,
            });
      }
      await _loadState();
    } catch (_) {}
  }

  Future<void> unlockItem(String itemName, {String category = 'Avatar Frame'}) async {
    try {
      await Supabase.instance.client
          .from('user_customizations')
          .upsert({
            'user_id': currentUserId,
            'type': category,
            'name': itemName,
            'is_equipped': false,
          });
      await _loadState();
    } catch (_) {}
  }

  Future<void> renewOrPurchaseItem(String itemName, Duration duration, {String category = 'Avatar Frame'}) async {
    try {
      await Supabase.instance.client
          .from('user_customizations')
          .upsert({
            'user_id': currentUserId,
            'type': category,
            'name': itemName,
            'is_equipped': false,
          });
      await _loadState();
    } catch (_) {}
  }

  void checkExpirations() {}

  void reorderBadges(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = activeBadges.removeAt(oldIndex);
    activeBadges.insert(newIndex, item);
  }

  void reorderTags(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = activeTags.removeAt(oldIndex);
    activeTags.insert(newIndex, item);
  }

  void reorderGifts(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = activeGifts.removeAt(oldIndex);
    activeGifts.insert(newIndex, item);
  }

  List<String> getActiveReminders() {
    final List<String> reminders = [];
    final now = DateTime.now();

    try {
      final vipCtrl = Get.find<VipController>();
      if (vipCtrl.vipLevel.value > 0 && vipCtrl.expiryDate.value != null) {
        final diff = vipCtrl.expiryDate.value!.difference(now);
        if (!diff.isNegative && diff.inDays <= 3) {
          if (diff.inDays >= 1) {
            reminders.add('Your VIP expires in ${diff.inDays} days.');
          } else if (diff.inHours >= 1) {
            reminders.add('Your VIP expires in ${diff.inHours} hours.');
          } else {
            reminders.add('Your VIP expires soon.');
          }
        }
      }
    } catch (_) {}

    try {
      final novelCtrl = Get.find<NovelController>();
      if (novelCtrl.novelLevel.value > 0 && novelCtrl.expiryDate.value != null) {
        final diff = novelCtrl.expiryDate.value!.difference(now);
        if (!diff.isNegative && diff.inDays <= 3) {
          if (diff.inDays >= 1) {
            reminders.add('Your Novel membership expires in ${diff.inDays} days.');
          } else if (diff.inHours >= 1) {
            reminders.add('Your Novel membership expires in ${diff.inHours} hours.');
          } else {
            reminders.add('Your Novel membership expires soon.');
          }
        }
      }
    } catch (_) {}

    return reminders;
  }
}
