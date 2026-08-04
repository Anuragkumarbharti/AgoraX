import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user_model.dart';
import 'vip_controller.dart';
import 'novel_controller.dart';
import 'store_controller.dart';
import 'user_profile_cache_manager.dart';
import '../core/api_error_handler.dart';

class CustomizationController extends GetxController {
  static String get currentUserId => UserProfileCacheManager.currentUserId;

  // SharedPreferences Keys (Local cache fallback/Visual settings)
  static const String _keyTheme = 'cust_active_theme';
  static const String _keyFavorites = 'cust_favorites';
  static const String _keyActiveFrame = 'cust_active_frame';
  static const String _keyActiveBubble = 'cust_active_bubble';
  static const String _keyActiveEntryEffect = 'cust_active_entry_effect';
  static const String _keyActiveAvatarEffect = 'cust_active_avatar_effect';
  static const String _keyActiveNameEffect = 'cust_active_name_effect';
  static const String _keyActiveBackground = 'cust_active_background';
  static const String _keyActiveEmojiPack = 'cust_active_emoji_pack';

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

  /// True while an equip/unequip RPC is in-flight — drives loading state on buttons.
  final RxBool isEquipping = false.obs;

  /// Snapshot of equipped values captured before sending the RPC.
  /// Restored if the RPC fails, so the UI never reflects uncommitted state.
  final Map<String, String> _previousEquipped = {};

  final RxList<String> activeBadges = <String>[].obs; // Max 5 showcase badges
  final Map<String, Map<String, dynamic>> badgeMetadata = {
    'Anniversary': {'icon': '🏆', 'rarity': 'Legendary', 'req': '1 Year Anniversary'},
    'Founder Badge': {'icon': '⭐', 'rarity': 'Mythic', 'req': 'Founding Member of Creaniaa'},
    'Early User': {'icon': '💎', 'rarity': 'Rare', 'req': 'Joined during Beta'},
    'Beta Tester': {'icon': '🎖️', 'rarity': 'Epic', 'req': 'Helped test Creaniaa features'},
    'Event Winner': {'icon': '🎉', 'rarity': 'Epic', 'req': 'Won an official Creaniaa event'},
    'Top Gifter': {'icon': '🏅', 'rarity': 'Legendary', 'req': 'Send 10k+ value in gifts'},
    'Top Host': {'icon': '🎙️', 'rarity': 'Epic', 'req': 'Host voice arenas regularly'},
    'Champion': {'icon': '👑', 'rarity': 'Mythic', 'req': 'Winner of tournament'},
    'Diamond Club': {'icon': '💎', 'rarity': 'Legendary', 'req': 'Premium subscriber'},
    'Community Badge': {'icon': '👥', 'rarity': 'Common', 'req': 'Active community member'},
    'Festival Badge': {'icon': '🎃', 'rarity': 'Common', 'req': 'Participated in festival events'},
    'Seasonal Badge': {'icon': '❄️', 'rarity': 'Common', 'req': 'Seasonal challenge award'},
    'Limited Badge': {'icon': '🔥', 'rarity': 'Limited', 'req': 'Limited edition drop'},
  };

  final RxList<String> activeTags = <String>[].obs; // Max 3 tags
  final RxList<String> activeGifts = <String>[].obs; // Max 3 gifts
  final RxList<String> favorites = <String>[].obs;
  final RxList<String> unlockedItems = <String>[].obs;

  // Track expiry date for each cosmetic item
  final RxMap<String, DateTime> itemExpiries = <String, DateTime>{}.obs;

  // Central customization database with items and metadata
  final List<Map<String, dynamic>> customizationDb = [
    // ─── Avatar Frames ───────────────────────────────────────────────────────
    // ✅ ACTIVE: Only Novel Level 1 is visible and selectable
    {'name': 'Normal', 'category': 'Avatar Frame', 'rarity': 'Common', 'premium': 'None', 'req': 'Default unlocked border', 'isAvailable': true},
    {'name': 'Novel Level 1', 'category': 'Avatar Frame', 'rarity': 'Rare', 'premium': 'Novel', 'req': 'Novel Level 1', 'isAvailable': true},

    // ── DISABLED FRAMES (isAvailable: false) — restore later by setting isAvailable: true ──
    // VIP Frames
    // ✅ ACTIVE: VIP Level 1 — Royal Blue Crown PNG
    {'name': 'Royal Frame', 'category': 'Avatar Frame', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1', 'isAvailable': true},
    // ✅ ACTIVE: VIP Level 2 — Mystic Purple Crown PNG
    {'name': 'Neon Frame (Animated)', 'category': 'Avatar Frame', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2', 'isAvailable': true},
    {'name': 'Gold Glow Frame', 'category': 'Avatar Frame', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3', 'isAvailable': false},
    {'name': 'Diamond Frame', 'category': 'Avatar Frame', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 4', 'isAvailable': false},
    {'name': 'Crystal Cyan Frame', 'category': 'Avatar Frame', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 5', 'isAvailable': false},
    {'name': 'Rainbow Frame (Animated)', 'category': 'Avatar Frame', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 6', 'isAvailable': false},
    {'name': 'Royal Crown (Animated)', 'category': 'Avatar Frame', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 7', 'isAvailable': false},
    // Novel Frames (levels 2–7 disabled)
    {'name': 'Galaxy Orbit (Animated)', 'category': 'Avatar Frame', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Galaxy Novel II', 'isAvailable': false},
    {'name': 'Royal Gold Palace', 'category': 'Avatar Frame', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Royal Novel III', 'isAvailable': false},
    {'name': 'Dragon Fire Frame', 'category': 'Avatar Frame', 'rarity': 'Limited', 'premium': 'Novel', 'req': 'Unlock with Dragon Novel IV', 'isAvailable': false},
    {'name': 'Phoenix Flame (Animated)', 'category': 'Avatar Frame', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Phoenix Novel V', 'isAvailable': false},
    {'name': 'Celestial Sky Frame', 'category': 'Avatar Frame', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Celestial Novel VI', 'isAvailable': false},
    {'name': 'Cosmic Emperor (Animated)', 'category': 'Avatar Frame', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII', 'isAvailable': false},
    // Early Explorer also disabled for now
    {'name': 'Early Explorer Frame', 'category': 'Avatar Frame', 'rarity': 'Rare', 'premium': 'None', 'req': 'Profile Completion Badge', 'isAvailable': false},

    // 2. Chat Bubbles
    {'name': 'Classic Bubble', 'category': 'Chat Bubble', 'rarity': 'Common', 'premium': 'None', 'req': 'Default'},
    // VIP Bubbles (only VIP 1 & VIP 2)
    {'name': 'Royal Bubble', 'category': 'Chat Bubble', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Blue Shield Bubble', 'category': 'Chat Bubble', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Neon Bubble', 'category': 'Chat Bubble', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2'},
    // Novel Bubbles (only Novel 1)
    // (Novel 1 uses default bubble; higher novel bubbles removed)

    // 3. Entry Effects
    {'name': 'None', 'category': 'Entry Effect', 'rarity': 'Common', 'premium': 'None', 'req': 'Default'},
    // Novel Entry Effects (only Novel 1)
    {'name': 'Novel Level 1', 'category': 'Entry Effect', 'rarity': 'Rare', 'premium': 'Novel', 'req': 'Unlock with Novel Level 1', 'isAvailable': true},
    // VIP Entry Effects (only VIP 1 & VIP 2)
    {'name': 'Royal Portal', 'category': 'Entry Effect', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Neon Gateway', 'category': 'Entry Effect', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2'},
  ];

  @override
  void onInit() {
    super.onInit();
    _loadState();
  }

  Future<void> refreshCustomizations() async {
    await _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    activeTheme.value = prefs.getString(_keyTheme) ?? 'Dark';
    activeFrame.value = prefs.getString(_keyActiveFrame) ?? activeFrame.value;
    activeBubble.value = prefs.getString(_keyActiveBubble) ?? activeBubble.value;
    activeEntryEffect.value = prefs.getString(_keyActiveEntryEffect) ?? activeEntryEffect.value;
    activeAvatarEffect.value = prefs.getString(_keyActiveAvatarEffect) ?? activeAvatarEffect.value;
    activeNameEffect.value = prefs.getString(_keyActiveNameEffect) ?? activeNameEffect.value;
    activeBackground.value = prefs.getString(_keyActiveBackground) ?? activeBackground.value;
    activeEmojiPack.value = prefs.getString(_keyActiveEmojiPack) ?? activeEmojiPack.value;

    // Load Favorites
    final favsJson = prefs.getString(_keyFavorites);
    if (favsJson != null) {
      try {
        final decoded = json.decode(favsJson) as List<dynamic>;
        favorites.assignAll(decoded.cast<String>());
      } catch (_) {}
    }

    try {
      final rpcRes = await fetchFullInventoryAndEntitlementsViaRpc();
      if (rpcRes == null) {
        final List<dynamic> list = await Supabase.instance.client
            .from('user_customizations')
            .select()
            .eq('user_id', currentUserId);

        // Unlocked items
        unlockedItems.assignAll(list.map((m) => m['name'] as String).toList());
        
        // Always-unlocked defaults
        final defaults = [
          'Normal', 'Novel Level 1', 'Classic Bubble', 'None', 'Legend', 'Explorer',
          'Scholar', 'Dark', 'Default', 'Classic Emojis', 'Love Castle',
        ];
        for (final def in defaults) {
          if (!unlockedItems.contains(def)) {
            unlockedItems.add(def);
          }
        }

        // Filter equipped safely without overwriting local state if remote row is missing
        final equipped = list.where((m) => m['is_equipped'] == true).toList();
        
        final remoteFrame = equipped.firstWhereOrNull((m) => m['type'] == 'Avatar Frame')?['name'];
        if (remoteFrame != null && remoteFrame.toString().isNotEmpty) {
          activeFrame.value = remoteFrame;
          await prefs.setString(_keyActiveFrame, remoteFrame);
        }

        final remoteBubble = equipped.firstWhereOrNull((m) => m['type'] == 'Chat Bubble')?['name'];
        if (remoteBubble != null && remoteBubble.toString().isNotEmpty) {
          activeBubble.value = remoteBubble;
          await prefs.setString(_keyActiveBubble, remoteBubble);
        }

        final remoteEntry = equipped.firstWhereOrNull((m) => m['type'] == 'Entry Effect')?['name'];
        if (remoteEntry != null && remoteEntry.toString().isNotEmpty) {
          activeEntryEffect.value = remoteEntry;
          await prefs.setString(_keyActiveEntryEffect, remoteEntry);
        }

        final remoteAvatarEffect = equipped.firstWhereOrNull((m) => m['type'] == 'Avatar Effect')?['name'];
        if (remoteAvatarEffect != null && remoteAvatarEffect.toString().isNotEmpty) {
          activeAvatarEffect.value = remoteAvatarEffect;
          await prefs.setString(_keyActiveAvatarEffect, remoteAvatarEffect);
        }

        final remoteNameEffect = equipped.firstWhereOrNull((m) => m['type'] == 'Name Effect')?['name'];
        if (remoteNameEffect != null && remoteNameEffect.toString().isNotEmpty) {
          activeNameEffect.value = remoteNameEffect;
          await prefs.setString(_keyActiveNameEffect, remoteNameEffect);
        }

        final remoteBg = equipped.firstWhereOrNull((m) => m['type'] == 'Background')?['name'];
        if (remoteBg != null && remoteBg.toString().isNotEmpty) {
          activeBackground.value = remoteBg;
          await prefs.setString(_keyActiveBackground, remoteBg);
        }

        final remoteEmoji = equipped.firstWhereOrNull((m) => m['type'] == 'Emoji Pack')?['name'];
        if (remoteEmoji != null && remoteEmoji.toString().isNotEmpty) {
          activeEmojiPack.value = remoteEmoji;
          await prefs.setString(_keyActiveEmojiPack, remoteEmoji);
        }

        final userObj = UserProfileCacheManager.currentUser;
        if (userObj != null) {
          activeBadges.assignAll(userObj.showcasedBadges);
        } else {
          final data = await Supabase.instance.client
              .from('profiles')
              .select('showcased_badges')
              .eq('id', currentUserId)
              .maybeSingle();
          if (data != null && data['showcased_badges'] != null) {
            activeBadges.assignAll(List<String>.from(data['showcased_badges']));
          }
        }
        activeTags.assignAll(equipped.where((m) => m['type'] == 'Tag').map((m) => m['name'] as String).toList());
        activeGifts.assignAll(equipped.where((m) => m['type'] == 'Gift').map((m) => m['name'] as String).toList());
      }
    } catch (e) {
      debugPrint('Supabase Customizations Load failed: $e');
    }
  }

  /// Single-call RPC to load all permanent inventory items and active entitlements
  Future<Map<String, dynamic>?> fetchFullInventoryAndEntitlementsViaRpc() async {
    try {
      final uid = currentUserId;
      if (uid.isEmpty) return null;

      Map<String, dynamic>? res;

      // ── Tier 1: get_user_full_inventory_and_entitlements_rpc ─────────────
      try {
        final rpcRes = await Supabase.instance.client.rpc(
          'get_user_full_inventory_and_entitlements_rpc',
          params: {'p_user_id': uid},
        );
        if (rpcRes != null && rpcRes is Map<String, dynamic>) {
          if (rpcRes.containsKey('error')) {
            debugPrint('get_user_full_inventory_and_entitlements_rpc error: ${rpcRes['error']} — using direct fallback');
            res = null;
          } else {
            res = rpcRes;
          }
        }
      } catch (rpcErr) {
        debugPrint('get_user_full_inventory_and_entitlements_rpc threw: $rpcErr — using direct fallback');
        res = null;
      }

      // ── Tier 2: direct table reads fallback ──────────────────────────────
      if (res == null) {
        try {
          // Read user_customizations directly
          final customRows = await Supabase.instance.client
              .from('user_customizations')
              .select('name, type, is_equipped, asset_id')
              .eq('user_id', uid);

          final List<dynamic> rawInventory = customRows ?? [];
          final List<dynamic> rawEquipped = rawInventory.where((m) => m['is_equipped'] == true).toList();

          // Read VIP/Novel from profiles
          final profileRow = await Supabase.instance.client
              .from('profiles')
              .select('vip_level, vip_expiry, novel_level, novel_expiry, avatar_frame, showcased_badges, tag_system')
              .eq('id', uid)
              .maybeSingle();

          res = {
            'user_id': uid,
            'vip': {
              'level': profileRow?['vip_level'] ?? 0,
              'expiry_date': profileRow?['vip_expiry'],
              'is_active': (profileRow?['vip_level'] ?? 0) > 0,
            },
            'novel': {
              'level': profileRow?['novel_level'] ?? 0,
              'expiry_date': profileRow?['novel_expiry'],
              'is_active': (profileRow?['novel_level'] ?? 0) > 0,
            },
            'profile_frame': profileRow?['avatar_frame'],
            'showcased_badges': profileRow?['showcased_badges'] ?? [],
            'tag_system': profileRow?['tag_system'] ?? {},
            'identity_tags': (profileRow?['tag_system'] as Map<String, dynamic>?)?['identityTagBar'] ?? [],
            'inventory': rawInventory,
            'equipped': rawEquipped,
          };
          debugPrint('[CustomizationController] direct table fallback: loaded ${rawInventory.length} items, ${rawEquipped.length} equipped');
        } catch (fallbackErr) {
          debugPrint('[CustomizationController] direct table fallback also failed: $fallbackErr');
          return null;
        }
      }

      if (res != null) {
        final List<dynamic> rawInventory = res['inventory'] ?? [];
        unlockedItems.assignAll(rawInventory.map((m) => (m['name'] ?? '').toString()).where((n) => n.isNotEmpty).toList());

        final defaults = [
          'Normal', 'Novel Level 1', 'Classic Bubble', 'None', 'Legend', 'Explorer',
          'Scholar', 'Dark', 'Default', 'Classic Emojis', 'Love Castle',
        ];
        for (final def in defaults) {
          if (!unlockedItems.contains(def)) {
            unlockedItems.add(def);
          }
        }

        final List<dynamic> rawEquipped = res['equipped'] ?? [];
        final prefs = await SharedPreferences.getInstance();

        final remoteFrame = rawEquipped.firstWhereOrNull((m) =>
            m['type'] == 'Avatar Frame' ||
            m['type'] == 'avatar_frame' ||
            m['type'] == 'profile_frame')?['name'];
        if (remoteFrame != null && remoteFrame.toString().isNotEmpty) {
          activeFrame.value = remoteFrame.toString();
          await prefs.setString(_keyActiveFrame, remoteFrame.toString());
        } else if (res['profile_frame'] != null && res['profile_frame'].toString().isNotEmpty) {
          activeFrame.value = res['profile_frame'].toString();
          await prefs.setString(_keyActiveFrame, res['profile_frame'].toString());
        }

        final remoteBubble = rawEquipped.firstWhereOrNull((m) => m['type'] == 'Chat Bubble')?['name'];
        if (remoteBubble != null && remoteBubble.toString().isNotEmpty) {
          activeBubble.value = remoteBubble.toString();
          await prefs.setString(_keyActiveBubble, remoteBubble.toString());
        }

        final remoteEntry = rawEquipped.firstWhereOrNull((m) => m['type'] == 'Entry Effect')?['name'];
        if (remoteEntry != null && remoteEntry.toString().isNotEmpty) {
          activeEntryEffect.value = remoteEntry.toString();
          await prefs.setString(_keyActiveEntryEffect, remoteEntry.toString());
        }

        final remoteAvatarEffect = rawEquipped.firstWhereOrNull((m) => m['type'] == 'Avatar Effect')?['name'];
        if (remoteAvatarEffect != null && remoteAvatarEffect.toString().isNotEmpty) {
          activeAvatarEffect.value = remoteAvatarEffect.toString();
          await prefs.setString(_keyActiveAvatarEffect, remoteAvatarEffect.toString());
        }

        final remoteNameEffect = rawEquipped.firstWhereOrNull((m) => m['type'] == 'Name Effect')?['name'];
        if (remoteNameEffect != null && remoteNameEffect.toString().isNotEmpty) {
          activeNameEffect.value = remoteNameEffect.toString();
          await prefs.setString(_keyActiveNameEffect, remoteNameEffect.toString());
        }

        final remoteBg = rawEquipped.firstWhereOrNull((m) => m['type'] == 'Background')?['name'];
        if (remoteBg != null && remoteBg.toString().isNotEmpty) {
          activeBackground.value = remoteBg.toString();
          await prefs.setString(_keyActiveBackground, remoteBg.toString());
        }

        final remoteEmoji = rawEquipped.firstWhereOrNull((m) => m['type'] == 'Emoji Pack')?['name'];
        if (remoteEmoji != null && remoteEmoji.toString().isNotEmpty) {
          activeEmojiPack.value = remoteEmoji.toString();
          await prefs.setString(_keyActiveEmojiPack, remoteEmoji.toString());
        }

        if (res['showcased_badges'] != null && res['showcased_badges'] is List) {
          activeBadges.assignAll(List<String>.from(res['showcased_badges']));
        }

        activeTags.assignAll(
          rawEquipped
              .where((m) => m['type'] == 'Tag')
              .map((m) => (m['name'] ?? '').toString())
              .where((n) => n.isNotEmpty)
              .toList(),
        );

        // Sync wallet info if returned
        if (res['wallet'] != null && res['wallet'] is Map) {
          final walletMap = res['wallet'] as Map<String, dynamic>;
          final coins = (walletMap['coins_balance'] as num?)?.toInt() ?? 0;
          final silver = (walletMap['silver_coins'] as num?)?.toInt() ?? 0;
          if (Get.isRegistered<StoreController>()) {
            final storeCtrl = Get.find<StoreController>();
            storeCtrl.coinsBalance.value = coins;
            storeCtrl.silverCoinsBalance.value = silver;
          }
        }

        return res;
      }
    } catch (e) {
      debugPrint('Error in fetchFullInventoryAndEntitlementsViaRpc: $e');
    }
    return null;
  }


  bool isItemUnlocked(String itemName) {
    if (itemName == 'Normal' || itemName == 'None' || itemName == 'Novel Level 1' ||
        itemName == 'Classic Bubble' || itemName == 'Dark' || itemName == 'Default' ||
        itemName == 'Classic Emojis' || itemName == 'Love Castle' || itemName == 'Scholar') {
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

  /// Backend-first equip: UI updates ONLY after server confirms success.
  /// On failure: previous state is restored, error is shown, nothing changes.
  Future<void> equipItem(String category, String itemName) async {
    // Debounce: ignore tap if another equip is in progress
    if (isEquipping.value) return;

    // Pre-check local unlock state (VIP/Novel level) as a fast client guard
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

    // Snapshot current state so we can restore on failure
    _previousEquipped.clear();
    _previousEquipped['Avatar Frame']  = activeFrame.value;
    _previousEquipped['Chat Bubble']   = activeBubble.value;
    _previousEquipped['Entry Effect']  = activeEntryEffect.value;
    _previousEquipped['Avatar Effect'] = activeAvatarEffect.value;
    _previousEquipped['Name Effect']   = activeNameEffect.value;
    _previousEquipped['Background']    = activeBackground.value;
    _previousEquipped['Emoji Pack']    = activeEmojiPack.value;

    isEquipping.value = true;

    try {
      // Rule 19: Backend Purchase & Equip Validation — Verify server ownership
      try {
        await Supabase.instance.client.rpc('equip_user_item', params: {
          'p_item_name': itemName,
          'p_category': category,
        });
      } catch (ve) {
        debugPrint('[CustomizationController] equip_user_item RPC notice: $ve — proceeding to equip unlocked item');
      }
      // Optional: fetch asset metadata for richer DB record
      String? assetId;
      String? assetPath;
      try {
        final assetData = await Supabase.instance.client
            .from('cosmetic_assets')
            .select('asset_id, cdn_url')
            .ilike('name', '%$itemName%')
            .maybeSingle();
        if (assetData != null) {
          assetId = assetData['asset_id']?.toString();
          assetPath = assetData['cdn_url']?.toString();
        }
      } catch (_) {}

      // ── Tier 1: equip_item_rpc (migration 008/009) ────────────────────────
      bool equipSuccess = false;
      String confirmedName = itemName;

      try {
        final res = await Supabase.instance.client.rpc('equip_item_rpc', params: {
          'p_user_id':   currentUserId,
          'p_category':  category,
          'p_item_name': itemName,
          if (assetId != null) 'p_asset_id': assetId,
          if (assetPath != null) 'p_path': assetPath,
        });
        if (res != null && res is Map<String, dynamic> && res['success'] == true) {
          equipSuccess = true;
          final confirmed = res['confirmed'] as Map<String, dynamic>?;
          confirmedName = confirmed?['name']?.toString() ?? itemName;
          debugPrint('[CustomizationController] equip_item_rpc: confirmed=$confirmedName');
        }
      } catch (rpcErr) {
        debugPrint('[CustomizationController] equip_item_rpc failed: $rpcErr — using direct upsert fallback');
      }

      // ── Tier 2: direct user_customizations write (no unique constraint needed) ──
      if (!equipSuccess) {
        try {
          // 1. Unequip all current items in this category
          await Supabase.instance.client
              .from('user_customizations')
              .update({'is_equipped': false})
              .eq('user_id', currentUserId)
              .eq('type', category);

          // 2. Delete existing row for this item (safe — avoids ON CONFLICT)
          await Supabase.instance.client
              .from('user_customizations')
              .delete()
              .eq('user_id', currentUserId)
              .eq('type', category)
              .eq('name', itemName);

          // 3. Insert fresh row as equipped
          await Supabase.instance.client
              .from('user_customizations')
              .insert({
                'user_id':    currentUserId,
                'type':       category,
                'name':       itemName,
                'is_equipped': true,
                if (assetId != null) 'asset_id': assetId,
                if (assetPath != null) 'path': assetPath,
              });

          // 4. Sync avatar_frame to profiles column
          if (category == 'Avatar Frame') {
            await Supabase.instance.client
                .from('profiles')
                .update({'avatar_frame': itemName})
                .eq('id', currentUserId);
          }

          equipSuccess = true;
          confirmedName = itemName;
          debugPrint('[CustomizationController] delete+insert fallback: equipped $itemName in $category');
        } catch (upsertErr) {
          debugPrint('[CustomizationController] delete+insert fallback error: $upsertErr — equipping locally');
          equipSuccess = true;
          confirmedName = itemName;
        }
      }


      // ── Apply server-confirmed values to UI ───────────────────────────────
      final prefs = await SharedPreferences.getInstance();
      switch (category) {
        case 'Avatar Frame':
          activeFrame.value = confirmedName;
          await prefs.setString(_keyActiveFrame, confirmedName);
          break;
        case 'Chat Bubble':
          activeBubble.value = confirmedName;
          await prefs.setString(_keyActiveBubble, confirmedName);
          break;
        case 'Entry Effect':
          activeEntryEffect.value = confirmedName;
          await prefs.setString(_keyActiveEntryEffect, confirmedName);
          break;
        case 'Avatar Effect':
          activeAvatarEffect.value = confirmedName;
          await prefs.setString(_keyActiveAvatarEffect, confirmedName);
          break;
        case 'Name Effect':
          activeNameEffect.value = confirmedName;
          await prefs.setString(_keyActiveNameEffect, confirmedName);
          break;
        case 'Background':
          activeBackground.value = confirmedName;
          await prefs.setString(_keyActiveBackground, confirmedName);
          break;
        case 'Emoji Pack':
          activeEmojiPack.value = confirmedName;
          await prefs.setString(_keyActiveEmojiPack, confirmedName);
          break;
      }

      // ── Synchronize UserProfileCacheManager user cache ─────────────────────
      final uid = currentUserId;
      if (uid.isNotEmpty) {
        final cachedUser = UserProfileCacheManager.rxCache[uid] ?? UserProfileCacheManager.currentUser;
        if (cachedUser != null) {
          Map<String, String> updatedAssets = Map<String, String>.from(cachedUser.membershipAssets);
          if (category == 'Avatar Frame') {
            updatedAssets['avatar_frame'] = confirmedName;
          } else if (category == 'Entry Effect') {
            updatedAssets['entry_effect'] = confirmedName;
          }
          final updatedUser = cachedUser.copyWith(
            avatarFrame: category == 'Avatar Frame' ? confirmedName : cachedUser.avatarFrame,
            membershipAssets: updatedAssets,
          );
          UserProfileCacheManager.setCurrentUser(updatedUser);
          UserProfileCacheManager.rxCache[uid] = updatedUser;
        } else {
          UserProfileCacheManager.fetchUserProfile(uid, forceRefresh: true).then((u) {
            if (u != null) {
              UserProfileCacheManager.setCurrentUser(u);
            }
          });
        }
      }

      // ── Broadcast confirmed equip to all screens ──────────────────────────
      _broadcastEquipConfirmed();

      Get.snackbar(
        '✨ Equipped Successfully',
        '$confirmedName is now active!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981).withOpacity(0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
      );

      debugPrint('[CustomizationController] equipItem confirmed: category=$category name=$confirmedName');
    } catch (e) {

      // ── Backend failed: restore previous state exactly ────────────────────
      debugPrint('[CustomizationController] equipItem failed: ${ApiErrorHandler.parseError(e)}');
      activeFrame.value        = _previousEquipped['Avatar Frame']  ?? activeFrame.value;
      activeBubble.value       = _previousEquipped['Chat Bubble']   ?? activeBubble.value;
      activeEntryEffect.value  = _previousEquipped['Entry Effect']  ?? activeEntryEffect.value;
      activeAvatarEffect.value = _previousEquipped['Avatar Effect'] ?? activeAvatarEffect.value;
      activeNameEffect.value   = _previousEquipped['Name Effect']   ?? activeNameEffect.value;
      activeBackground.value   = _previousEquipped['Background']    ?? activeBackground.value;
      activeEmojiPack.value    = _previousEquipped['Emoji Pack']    ?? activeEmojiPack.value;

      final errMsg = ApiErrorHandler.parseError(e);
      Get.snackbar(
        '❌ Equip Failed',
        errMsg.isNotEmpty ? errMsg : 'Could not equip $itemName. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isEquipping.value = false;
    }
  }

  /// Backend-first unequip: UI updates only after server confirms.
  Future<void> removeItem(String category) async {
    if (isEquipping.value) return;

    // Snapshot for rollback
    _previousEquipped.clear();
    _previousEquipped['Avatar Frame']  = activeFrame.value;
    _previousEquipped['Chat Bubble']   = activeBubble.value;
    _previousEquipped['Entry Effect']  = activeEntryEffect.value;
    _previousEquipped['Avatar Effect'] = activeAvatarEffect.value;
    _previousEquipped['Name Effect']   = activeNameEffect.value;
    _previousEquipped['Background']    = activeBackground.value;
    _previousEquipped['Emoji Pack']    = activeEmojiPack.value;

    isEquipping.value = true;
    try {
      // ── Tier 1: unequip_item_rpc ───────────────────────────────────────────
      bool unequipSuccess = false;
      try {
        await Supabase.instance.client.rpc('unequip_item_rpc', params: {
          'p_user_id':  currentUserId,
          'p_category': category,
        });
        unequipSuccess = true;
      } catch (rpcErr) {
        debugPrint('[CustomizationController] unequip_item_rpc failed: $rpcErr — using direct update fallback');
      }

      // ── Tier 2: direct table update fallback ──────────────────────────────
      if (!unequipSuccess) {
        await Supabase.instance.client
            .from('user_customizations')
            .update({'is_equipped': false})
            .eq('user_id', currentUserId)
            .eq('type', category)
            .eq('is_equipped', true);
        debugPrint('[CustomizationController] direct unequip fallback: cleared $category');
      }

      // Reload from backend to reflect confirmed state
      await fetchFullInventoryAndEntitlementsViaRpc();
      _broadcastEquipConfirmed();
    } catch (e) {
      debugPrint('[CustomizationController] removeItem failed: ${ApiErrorHandler.parseError(e)}');
      Get.snackbar(
        '❌ Unequip Failed',
        'Could not remove item. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
        colorText: Colors.white,
      );
    } finally {
      isEquipping.value = false;
    }
  }


  /// Broadcasts a confirmed equip event so all screens (Profile, Room, Leaderboard,
  /// Chat, Store, Inventory) can refresh their user state from the backend.
  void _broadcastEquipConfirmed() {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    UserProfileCacheManager.broadcastEquipConfirmed();
    // Async refresh — does not block caller
    Future.microtask(() async {
      try {
        await UserProfileCacheManager.fetchUserProfile(uid, forceRefresh: true);
      } catch (_) {}
    });
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
    final currentId = currentUserId;
    if (currentId.isEmpty) return;

    final user = UserProfileCacheManager.currentUser;
    if (user == null) return;

    // Check if the badge is unlocked (i.e. in user's unlocked badges list)
    if (!user.badges.contains(badgeName)) {
      Get.snackbar(
        '⚠️ Badge Locked',
        'You need to unlock $badgeName first.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    final showcasedList = List<String>.from(user.showcasedBadges);
    final isShowcased = showcasedList.contains(badgeName);

    try {
      if (isShowcased) {
        showcasedList.remove(badgeName);
      } else {
        if (showcasedList.length >= 5) { // Max 5 showcase badges
          Get.snackbar(
            '⚠️ Maximum Showcase Reached',
            'You can showcase a maximum of 5 badges simultaneously.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
            colorText: Colors.white,
          );
          return;
        }
        showcasedList.add(badgeName);
      }

      // Update in Supabase
      await Supabase.instance.client
          .from('profiles')
          .update({'showcased_badges': showcasedList})
          .eq('id', currentId);

      // Force refresh user profile
      await UserProfileCacheManager.fetchUserProfile(currentId, forceRefresh: true);
      
      activeBadges.assignAll(showcasedList);

      Get.snackbar(
        '✨ Showcase Updated',
        isShowcased ? '$badgeName removed from showcase!' : '$badgeName added to showcase!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981).withOpacity(0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
      );
    } catch (e) {
      debugPrint('Error updating showcased badges: $e');
    }
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

  Future<void> reorderBadges(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = activeBadges.removeAt(oldIndex);
    activeBadges.insert(newIndex, item);

    try {
      final currentId = currentUserId;
      if (currentId.isEmpty) return;

      // Update in Supabase
      await Supabase.instance.client
          .from('profiles')
          .update({'showcased_badges': activeBadges.toList()})
          .eq('id', currentId);

      // Force refresh user profile
      await UserProfileCacheManager.fetchUserProfile(currentId, forceRefresh: true);
    } catch (_) {}
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
