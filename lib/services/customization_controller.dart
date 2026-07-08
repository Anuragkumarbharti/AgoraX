import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'vip_controller.dart';
import 'novel_controller.dart';

class CustomizationController extends GetxController {
  // SharedPreferences Keys
  static const String _keyFrame = 'cust_active_frame';
  static const String _keyBubble = 'cust_active_bubble';
  static const String _keyEntryEffect = 'cust_active_entry_effect';
  static const String _keyEntryAnim = 'cust_active_entry_anim';
  static const String _keyAvatarEffect = 'cust_active_avatar_effect';
  static const String _keyNameEffect = 'cust_active_name_effect';
  static const String _keyTheme = 'cust_active_theme';
  static const String _keyBackground = 'cust_active_background';
  static const String _keyStatusStyle = 'cust_active_status_style';
  static const String _keyBadges = 'cust_active_badges';
  static const String _keyFavorites = 'cust_favorites';
  static const String _keyUnlocked = 'cust_unlocked_items';
  static const String _keyAvatar = 'cust_active_avatar';
  static const String _keyTags = 'cust_active_tags';
  static const String _keyEmojiPack = 'cust_active_emoji_pack';
  static const String _keyGifts = 'cust_active_gifts';

  // Observables
  final RxString activeFrame = 'Normal'.obs;
  final RxString activeBubble = 'Classic Bubble'.obs;
  final RxString activeEntryEffect = 'None'.obs;
  final RxString activeEntryAnimation = 'None'.obs;
  final RxString activeAvatarEffect = 'None'.obs;
  final RxString activeNameEffect = 'None'.obs;
  final RxString activeTheme = 'Dark'.obs;
  final RxString activeBackground = 'None'.obs;
  final RxString activeStatusStyle = 'None'.obs;
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

    // 2. Avatar Images (Profile Pics)
    {'name': 'Default', 'category': 'Avatar', 'rarity': 'Common', 'premium': 'None', 'req': 'Default profile picture'},
    {'name': 'VIP Gold Crown', 'category': 'Avatar', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Neon Gamer Tech', 'category': 'Avatar', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Galaxy Mage Cosmic', 'category': 'Avatar', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Galaxy Novel II'},
    {'name': 'Cyberpunk Samurai', 'category': 'Avatar', 'rarity': 'Epic', 'premium': 'None', 'req': 'Unlock at Level 10'},
    {'name': 'Crimson Dragon Lord', 'category': 'Avatar', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Dragon Novel IV'},

    // 3. Avatar Effects (Avatar Aura)
    {'name': 'None', 'category': 'Avatar Effect', 'rarity': 'Common', 'premium': 'None', 'req': 'Default'},
    // VIP Auras
    {'name': 'Royal Aura', 'category': 'Avatar Effect', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Pulsing Glow', 'category': 'Avatar Effect', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2'}, // Neon fallback
    {'name': 'Neon Aura', 'category': 'Avatar Effect', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2'},
    {'name': 'Golden Aura', 'category': 'Avatar Effect', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Diamond Aura', 'category': 'Avatar Effect', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 4'},
    {'name': 'Crystal Aura', 'category': 'Avatar Effect', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 5'},
    {'name': 'Rainbow Aura', 'category': 'Avatar Effect', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 6'},
    {'name': 'Emperor Aura', 'category': 'Avatar Effect', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 7'},
    // Novel Auras
    {'name': 'Galaxy Aura', 'category': 'Avatar Effect', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Galaxy Novel II'},
    {'name': 'Royal Palace Aura', 'category': 'Avatar Effect', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Royal Novel III'},
    {'name': 'Red Flame Aura', 'category': 'Avatar Effect', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Dragon Novel IV'},
    {'name': 'Dragon Aura', 'category': 'Avatar Effect', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Dragon Novel IV'},
    {'name': 'Phoenix Aura', 'category': 'Avatar Effect', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Phoenix Novel V'},
    {'name': 'Celestial Aura', 'category': 'Avatar Effect', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Celestial Novel VI'},
    {'name': 'Cosmic Stardust', 'category': 'Avatar Effect', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII'},
    {'name': 'Cosmic Emperor Aura', 'category': 'Avatar Effect', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII'},

    // 4. Chat Bubbles
    {'name': 'Classic Bubble', 'category': 'Chat Bubble', 'rarity': 'Common', 'premium': 'None', 'req': 'Default'},
    // VIP Bubbles
    {'name': 'Royal Bubble', 'category': 'Chat Bubble', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Blue Shield Bubble', 'category': 'Chat Bubble', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Neon Bubble', 'category': 'Chat Bubble', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2'},
    {'name': 'VIP Bubble', 'category': 'Chat Bubble', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Golden Shimmer', 'category': 'Chat Bubble', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Golden Shimmer Bubble', 'category': 'Chat Bubble', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Diamond Bubble', 'category': 'Chat Bubble', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 4'},
    {'name': 'Crystal Cyan Neon', 'category': 'Chat Bubble', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 5'},
    {'name': 'Crystal Cyan Neon Bubble', 'category': 'Chat Bubble', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 5'},
    {'name': 'Rainbow Bubble', 'category': 'Chat Bubble', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 6'},
    {'name': 'Emperor Bubble', 'category': 'Chat Bubble', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 7'},
    // Novel Bubbles
    {'name': 'Galaxy Bubble', 'category': 'Chat Bubble', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Galaxy Novel II'},
    {'name': 'Royal Palace Bubble', 'category': 'Chat Bubble', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Royal Novel III'},
    {'name': 'Dragon Fire Bubble', 'category': 'Chat Bubble', 'rarity': 'Limited', 'premium': 'Novel', 'req': 'Unlock with Dragon Novel IV'},
    {'name': 'Phoenix Bubble', 'category': 'Chat Bubble', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Phoenix Novel V'},
    {'name': 'Celestial Bubble', 'category': 'Chat Bubble', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Celestial Novel VI'},
    {'name': 'Cosmic Gold Bubble', 'category': 'Chat Bubble', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII'},
    {'name': 'Cosmic Emperor Bubble', 'category': 'Chat Bubble', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII'},

    // 5. Entry Effects
    {'name': 'None', 'category': 'Entry Effect', 'rarity': 'Common', 'premium': 'None', 'req': 'Default'},
    // VIP Entry Effects
    {'name': 'Royal Portal', 'category': 'Entry Effect', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Neon Gateway', 'category': 'Entry Effect', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2'},
    {'name': 'Fireworks', 'category': 'Entry Effect', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Golden Explosion', 'category': 'Entry Effect', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Diamond Shatter', 'category': 'Entry Effect', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 4'},
    {'name': 'Crystal Blizzard', 'category': 'Entry Effect', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 5'},
    {'name': 'Magic Circle', 'category': 'Entry Effect', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 6'},
    {'name': 'Rainbow Bridge', 'category': 'Entry Effect', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 6'},
    {'name': 'Emperor Throne Room', 'category': 'Entry Effect', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 7'},
    // Novel Entry Effects
    {'name': 'Galaxy Warp', 'category': 'Entry Effect', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Galaxy Novel II'},
    {'name': 'Royal Palace Entry', 'category': 'Entry Effect', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Royal Novel III'},
    {'name': 'Lightning Strike', 'category': 'Entry Effect', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Dragon Novel IV'},
    {'name': 'Dragon Arrival', 'category': 'Entry Effect', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Dragon Novel IV'},
    {'name': 'Phoenix Rise', 'category': 'Entry Effect', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Phoenix Novel V'},
    {'name': 'Celestial Portal', 'category': 'Entry Effect', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Celestial Novel VI'},
    {'name': 'Cosmic Rift', 'category': 'Entry Effect', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII'},

    // 6. Entry Animations
    {'name': 'None', 'category': 'Entry Animation', 'rarity': 'Common', 'premium': 'None', 'req': 'Default'},
    {'name': 'Slide In', 'category': 'Entry Animation', 'rarity': 'Rare', 'premium': 'None', 'req': 'Default'},
    {'name': 'Teleport', 'category': 'Entry Animation', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 4'},
    {'name': 'Spin In', 'category': 'Entry Animation', 'rarity': 'Epic', 'premium': 'None', 'req': 'Level 15 Reward'},
    {'name': 'Celestial Join', 'category': 'Entry Animation', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Celestial Novel VI'},

    // 7. Badges
    {'name': 'Legend', 'category': 'Badges', 'rarity': 'Legendary', 'premium': 'None', 'req': 'Achieve Hall of Fame'},
    {'name': 'Explorer', 'category': 'Badges', 'rarity': 'Common', 'premium': 'None', 'req': 'Default badge'},
    {'name': 'Scholar', 'category': 'Badges', 'rarity': 'Rare', 'premium': 'None', 'req': 'Complete 5 courses'},
    {'name': 'Champion', 'category': 'Badges', 'rarity': 'Epic', 'premium': 'None', 'req': 'Win room battle'},
    {'name': 'Mastermind', 'category': 'Badges', 'rarity': 'Legendary', 'premium': 'None', 'req': 'UPSC level 10'},
    // VIP Badges
    {'name': 'Royal Badge', 'category': 'Badges', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Neon Badge', 'category': 'Badges', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2'},
    {'name': 'Golden Badge', 'category': 'Badges', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Diamond Badge', 'category': 'Badges', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 4'},
    {'name': 'Crystal Badge', 'category': 'Badges', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 5'},
    {'name': 'Rainbow Badge', 'category': 'Badges', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 6'},
    {'name': 'Elite', 'category': 'Badges', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 7'},
    {'name': 'Emperor Badge', 'category': 'Badges', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 7'},
    // Novel Badges
    {'name': 'Star Star', 'category': 'Badges', 'rarity': 'Epic', 'premium': 'Novel', 'req': 'Unlock with Galaxy Novel II'},
    {'name': 'Galaxy Badge', 'category': 'Badges', 'rarity': 'Epic', 'premium': 'Novel', 'req': 'Unlock with Galaxy Novel II'},
    {'name': 'Royal Palace Badge', 'category': 'Badges', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Royal Novel III'},
    {'name': 'Dragon Badge', 'category': 'Badges', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Dragon Novel IV'},
    {'name': 'Phoenix Badge', 'category': 'Badges', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Phoenix Novel V'},
    {'name': 'Celestial Badge', 'category': 'Badges', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Celestial Novel VI'},
    {'name': 'Cosmic Emperor Badge', 'category': 'Badges', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII'},

    // 8. Tags
    {'name': 'Scholar', 'category': 'Tags', 'rarity': 'Common', 'premium': 'None', 'req': 'Course graduate'},
    {'name': 'Topper', 'category': 'Tags', 'rarity': 'Rare', 'premium': 'None', 'req': 'Top score in CS exam'},
    {'name': 'VIP Star', 'category': 'Tags', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'VIP 3+'},
    // VIP Tags
    {'name': 'Royal Tag', 'category': 'Tags', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Neon Tag', 'category': 'Tags', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2'},
    {'name': 'Golden Tag', 'category': 'Tags', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Diamond Tag', 'category': 'Tags', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 4'},
    {'name': 'Crystal Tag', 'category': 'Tags', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 5'},
    {'name': 'Rainbow Tag', 'category': 'Tags', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 6'},
    {'name': 'Emperor Tag', 'category': 'Tags', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 7'},
    // Novel Tags
    {'name': 'Galaxy Tag', 'category': 'Tags', 'rarity': 'Epic', 'premium': 'Novel', 'req': 'Unlock with Galaxy Novel II'},
    {'name': 'Royal Palace Tag', 'category': 'Tags', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Royal Novel III'},
    {'name': 'Dragon Tag', 'category': 'Tags', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Dragon Novel IV'},
    {'name': 'Phoenix Tag', 'category': 'Tags', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Phoenix Novel V'},
    {'name': 'Celestial Tag', 'category': 'Tags', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Celestial Novel VI'},
    {'name': 'Cosmic Emperor Tag', 'category': 'Tags', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII'},

    // 9. Name Effects
    {'name': 'None', 'category': 'Name Effect', 'rarity': 'Common', 'premium': 'None', 'req': 'Default'},
    // VIP Name Glows
    {'name': 'Royal Blue Glow', 'category': 'Name Effect', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Neon Pink Glow', 'category': 'Name Effect', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2'},
    {'name': 'Gold Glow', 'category': 'Name Effect', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Diamond Glow', 'category': 'Name Effect', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 4'},
    {'name': 'Neon Glow', 'category': 'Name Effect', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 4'},
    {'name': 'Crystal Glow', 'category': 'Name Effect', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 5'},
    {'name': 'Rainbow Fire', 'category': 'Name Effect', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 6'},
    {'name': 'Rainbow Fire Glow', 'category': 'Name Effect', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 6'},
    {'name': 'Emperor Glow', 'category': 'Name Effect', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 7'},
    // Novel Name Glows
    {'name': 'Galaxy Glow', 'category': 'Name Effect', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Galaxy Novel II'},
    {'name': 'Royal Palace Glow', 'category': 'Name Effect', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Royal Novel III'},
    {'name': 'Dragon Fire Glow', 'category': 'Name Effect', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Dragon Novel IV'},
    {'name': 'Phoenix Flame Glow', 'category': 'Name Effect', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Phoenix Novel V'},
    {'name': 'Celestial Glow', 'category': 'Name Effect', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Celestial Novel VI'},
    {'name': 'Cosmic Gold', 'category': 'Name Effect', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII'},
    {'name': 'Cosmic Emperor Glow', 'category': 'Name Effect', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII'},

    // 10. Profile Themes
    {'name': 'Dark', 'category': 'Profile Theme', 'rarity': 'Common', 'premium': 'None', 'req': 'Default'},
    // VIP Themes
    {'name': 'Royal Theme', 'category': 'Profile Theme', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Neon Theme', 'category': 'Profile Theme', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2'},
    {'name': 'Golden Theme', 'category': 'Profile Theme', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Diamond Theme', 'category': 'Profile Theme', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 4'},
    {'name': 'Crystal Theme', 'category': 'Profile Theme', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 5'},
    {'name': 'Rainbow Theme', 'category': 'Profile Theme', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 6'},
    {'name': 'Emperor Theme', 'category': 'Profile Theme', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 7'},
    // Novel Themes
    {'name': 'Galaxy Theme', 'category': 'Profile Theme', 'rarity': 'Epic', 'premium': 'Novel', 'req': 'Unlock with Galaxy Novel II'},
    {'name': 'Galaxy Purple', 'category': 'Profile Theme', 'rarity': 'Epic', 'premium': 'Novel', 'req': 'Unlock with Galaxy Novel II'},
    {'name': 'Royal Palace Theme', 'category': 'Profile Theme', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Royal Novel III'},
    {'name': 'Gold Palace', 'category': 'Profile Theme', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Royal Novel III'},
    {'name': 'Dragon Theme', 'category': 'Profile Theme', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Dragon Novel IV'},
    {'name': 'Phoenix Theme', 'category': 'Profile Theme', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Phoenix Novel V'},
    {'name': 'Celestial Theme', 'category': 'Profile Theme', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Celestial Novel VI'},
    {'name': 'Cosmic Emperor Theme', 'category': 'Profile Theme', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII'},

    // 11. Backgrounds
    {'name': 'None', 'category': 'Background', 'rarity': 'Common', 'premium': 'None', 'req': 'Default'},
    {'name': 'Aura Neon', 'category': 'Background', 'rarity': 'Rare', 'premium': 'None', 'req': 'Shop wallpaper'},
    // VIP Backgrounds
    {'name': 'Royal Palace Background', 'category': 'Background', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Neon Grid Background', 'category': 'Background', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2'},
    {'name': 'Gilded Background', 'category': 'Background', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Pristine Background', 'category': 'Background', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 4'},
    {'name': 'Glacial Background', 'category': 'Background', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 5'},
    {'name': 'Prism Background', 'category': 'Background', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 6'},
    {'name': 'Dynasty Background', 'category': 'Background', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 7'},
    // Novel Backgrounds
    {'name': 'Cosmic Background', 'category': 'Background', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Galaxy Novel II'},
    {'name': 'Marble Background', 'category': 'Background', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Royal Novel III'},
    {'name': 'Lava Cave Background', 'category': 'Background', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Dragon Novel IV'},
    {'name': 'Eclipse Background', 'category': 'Background', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Phoenix Novel V'},
    {'name': 'Sky Temple Background', 'category': 'Background', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Celestial Novel VI'},
    {'name': 'Cosmic Cosmic', 'category': 'Background', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII'},
    {'name': 'Void Background', 'category': 'Background', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII'},

    // 12. Emoji Packs
    {'name': 'Classic Emojis', 'category': 'Emoji Pack', 'rarity': 'Common', 'premium': 'None', 'req': 'Default pack'},
    // VIP Emoji Packs
    {'name': 'Royal Emojis', 'category': 'Emoji Pack', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'VIP Royal Pack', 'category': 'Emoji Pack', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2'},
    {'name': 'Neon Emojis', 'category': 'Emoji Pack', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2'},
    {'name': 'Golden Emojis', 'category': 'Emoji Pack', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Diamond Emojis', 'category': 'Emoji Pack', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 4'},
    {'name': 'Crystal Emojis', 'category': 'Emoji Pack', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 5'},
    {'name': 'Rainbow Emojis', 'category': 'Emoji Pack', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 6'},
    {'name': 'Emperor Emojis', 'category': 'Emoji Pack', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 7'},
    // Novel Emoji Packs
    {'name': 'Galaxy Emojis', 'category': 'Emoji Pack', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Galaxy Novel II'},
    {'name': 'Galaxy Animated Pack', 'category': 'Emoji Pack', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Galaxy Novel II'},
    {'name': 'Royal Palace Emojis', 'category': 'Emoji Pack', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Royal Novel III'},
    {'name': 'Dragon Emojis', 'category': 'Emoji Pack', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Dragon Novel IV'},
    {'name': 'Phoenix Emojis', 'category': 'Emoji Pack', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Phoenix Novel V'},
    {'name': 'Celestial Emojis', 'category': 'Emoji Pack', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Celestial Novel VI'},
    {'name': 'Cosmic Emperor Emojis', 'category': 'Emoji Pack', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII'},

    // 13. Gift Showcase
    {'name': 'Love Castle', 'category': 'Gift Showcase', 'rarity': 'Epic', 'premium': 'None', 'req': 'Received from room events'},
    // VIP Gifts
    {'name': 'Royal Crown Gift', 'category': 'Gift Showcase', 'rarity': 'Rare', 'premium': 'VIP', 'req': 'Unlock with VIP Level 1'},
    {'name': 'Cyber DJ Deck', 'category': 'Gift Showcase', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 2'},
    {'name': 'Golden Rose', 'category': 'Gift Showcase', 'rarity': 'Epic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 3'},
    {'name': 'Diamond Ring', 'category': 'Gift Showcase', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 4'},
    {'name': 'Golden Crown Gift', 'category': 'Gift Showcase', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 5'},
    {'name': 'Ice Castle', 'category': 'Gift Showcase', 'rarity': 'Legendary', 'premium': 'VIP', 'req': 'Unlock with VIP Level 5'},
    {'name': 'Unicorn Prism', 'category': 'Gift Showcase', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 6'},
    {'name': 'Imperial Throne', 'category': 'Gift Showcase', 'rarity': 'Mythic', 'premium': 'VIP', 'req': 'Unlock with VIP Level 7'},
    // Novel Gifts
    {'name': 'Supernova Explosion', 'category': 'Gift Showcase', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Galaxy Novel II'},
    {'name': 'Palace Carriage', 'category': 'Gift Showcase', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Royal Novel III'},
    {'name': 'Dragon Flame', 'category': 'Gift Showcase', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Dragon Novel IV'},
    {'name': 'Phoenix Rise Gift', 'category': 'Gift Showcase', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Phoenix Novel V'},
    {'name': 'Celestial Harp', 'category': 'Gift Showcase', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Celestial Novel VI'},
    {'name': 'Cosmic Ring Gift', 'category': 'Gift Showcase', 'rarity': 'Legendary', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII'},
    {'name': 'Cosmic Star Gate', 'category': 'Gift Showcase', 'rarity': 'Mythic', 'premium': 'Novel', 'req': 'Unlock with Immortal Novel VII'},
  ];

  @override
  void onInit() {
    super.onInit();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    activeFrame.value = prefs.getString(_keyFrame) ?? 'Normal';
    activeBubble.value = prefs.getString(_keyBubble) ?? 'Classic Bubble';
    activeEntryEffect.value = prefs.getString(_keyEntryEffect) ?? 'None';
    activeEntryAnimation.value = prefs.getString(_keyEntryAnim) ?? 'None';
    activeAvatarEffect.value = prefs.getString(_keyAvatarEffect) ?? 'None';
    activeNameEffect.value = prefs.getString(_keyNameEffect) ?? 'None';
    activeTheme.value = prefs.getString(_keyTheme) ?? 'Dark';
    activeBackground.value = prefs.getString(_keyBackground) ?? 'None';
    activeStatusStyle.value = prefs.getString(_keyStatusStyle) ?? 'None';
    activeAvatar.value = prefs.getString(_keyAvatar) ?? 'Default';
    customAvatarPath.value = prefs.getString('cust_custom_avatar_path') ?? '';
    activeEmojiPack.value = prefs.getString(_keyEmojiPack) ?? 'Classic Emojis';

    // Load Badges List
    final badgesJson = prefs.getString(_keyBadges);
    if (badgesJson != null) {
      try {
        final decoded = json.decode(badgesJson) as List<dynamic>;
        activeBadges.assignAll(decoded.cast<String>());
      } catch (_) {}
    } else {
      activeBadges.assignAll(['Legend', 'Explorer']);
    }

    // Load Tags List
    final tagsJson = prefs.getString(_keyTags);
    if (tagsJson != null) {
      try {
        final decoded = json.decode(tagsJson) as List<dynamic>;
        activeTags.assignAll(decoded.cast<String>());
      } catch (_) {}
    } else {
      activeTags.assignAll(['Scholar']);
    }

    // Load Gifts List
    final giftsJson = prefs.getString(_keyGifts);
    if (giftsJson != null) {
      try {
        final decoded = json.decode(giftsJson) as List<dynamic>;
        activeGifts.assignAll(decoded.cast<String>());
      } catch (_) {}
    } else {
      activeGifts.assignAll(['Love Castle']);
    }

    // Load Favorites
    final favsJson = prefs.getString(_keyFavorites);
    if (favsJson != null) {
      try {
        final decoded = json.decode(favsJson) as List<dynamic>;
        favorites.assignAll(decoded.cast<String>());
      } catch (_) {}
    }

    // Load Unlocked Items
    final unlockedJson = prefs.getString(_keyUnlocked);
    if (unlockedJson != null) {
      try {
        final decoded = json.decode(unlockedJson) as List<dynamic>;
        unlockedItems.assignAll(decoded.cast<String>());
      } catch (_) {}
      // Seed default unlocked items
      unlockedItems.assignAll([
        'Normal', 'Classic Bubble', 'None', 'Legend', 'Explorer', 'Scholar', 'Dark', 'Default', 'Classic Emojis', 'Love Castle'
      ]);
    }

    // Load Expiries Map
    final expStr = prefs.getString('cust_item_expiries');
    if (expStr != null) {
      try {
        final decoded = json.decode(expStr) as Map<String, dynamic>;
        itemExpiries.assignAll(
          decoded.map((key, value) => MapEntry(key, DateTime.parse(value as String))),
        );
      } catch (_) {}
    } else {
      // Seed default items with expiries for simulation
      final now = DateTime.now();
      itemExpiries.assignAll({
        'Neon Frame (Animated)': now.add(const Duration(days: 2)),
        'Gold Glow Frame': now.add(const Duration(hours: 12)),
        'Diamond Frame': now.subtract(const Duration(hours: 2)),
        'Pulsing Glow': now.add(const Duration(days: 1)),
      });
      for (final name in ['Neon Frame (Animated)', 'Gold Glow Frame', 'Diamond Frame', 'Pulsing Glow']) {
        if (!unlockedItems.contains(name)) {
          unlockedItems.add(name);
        }
      }
      await prefs.setString(_keyUnlocked, json.encode(unlockedItems.toList()));
      final expMap = itemExpiries.map((key, value) => MapEntry(key, value.toIso8601String()));
      await prefs.setString('cust_item_expiries', json.encode(expMap));
    }

    // Run expiration cleanup check
    checkExpirations();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFrame, activeFrame.value);
    await prefs.setString(_keyBubble, activeBubble.value);
    await prefs.setString(_keyEntryEffect, activeEntryEffect.value);
    await prefs.setString(_keyEntryAnim, activeEntryAnimation.value);
    await prefs.setString(_keyAvatarEffect, activeAvatarEffect.value);
    await prefs.setString(_keyNameEffect, activeNameEffect.value);
    await prefs.setString(_keyTheme, activeTheme.value);
    await prefs.setString(_keyBackground, activeBackground.value);
    await prefs.setString(_keyStatusStyle, activeStatusStyle.value);
    await prefs.setString(_keyAvatar, activeAvatar.value);
    await prefs.setString('cust_custom_avatar_path', customAvatarPath.value);
    await prefs.setString(_keyEmojiPack, activeEmojiPack.value);

    await prefs.setString(_keyBadges, json.encode(activeBadges.toList()));
    await prefs.setString(_keyTags, json.encode(activeTags.toList()));
    await prefs.setString(_keyGifts, json.encode(activeGifts.toList()));
    await prefs.setString(_keyFavorites, json.encode(favorites.toList()));
    await prefs.setString(_keyUnlocked, json.encode(unlockedItems.toList()));

    final expMap = itemExpiries.map((key, value) => MapEntry(key, value.toIso8601String()));
    await prefs.setString('cust_item_expiries', json.encode(expMap));
  }

  // Dynamic check to determine if an item is unlocked (handles manual unlocks, default, VIP, Novel levels)
  bool isItemUnlocked(String itemName) {
    if (itemName == 'Normal' || itemName == 'None' || itemName == 'Classic Bubble' || itemName == 'Dark' || itemName == 'Default' || itemName == 'Classic Emojis' || itemName == 'Love Castle' || itemName == 'Scholar') {
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

  // Get custom avatar image URL
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

  // Instant equip helper
  Future<void> equipItem(String category, String itemName) async {
    // Verify item is unlocked
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

    switch (category) {
      case 'Avatar Frame':
        activeFrame.value = itemName;
        break;
      case 'Avatar':
        activeAvatar.value = itemName;
        break;
      case 'Chat Bubble':
        activeBubble.value = itemName;
        break;
      case 'Entry Effect':
        activeEntryEffect.value = itemName;
        break;
      case 'Entry Animation':
        activeEntryAnimation.value = itemName;
        break;
      case 'Avatar Effect':
        activeAvatarEffect.value = itemName;
        break;
      case 'Name Effect':
        activeNameEffect.value = itemName;
        break;
      case 'Profile Theme':
        activeTheme.value = itemName;
        break;
      case 'Background':
        activeBackground.value = itemName;
        break;
      case 'Status Effect':
        activeStatusStyle.value = itemName;
        break;
      case 'Emoji Pack':
        activeEmojiPack.value = itemName;
        break;
    }

    await _saveState();
    
    Get.snackbar(
      '✨ Equipped Successfully',
      '$itemName is now active!',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF10B981).withOpacity(0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
    );
  }

  // Remove helper
  Future<void> removeItem(String category) async {
    switch (category) {
      case 'Avatar Frame':
        activeFrame.value = 'Normal';
        break;
      case 'Avatar':
        activeAvatar.value = 'Default';
        break;
      case 'Chat Bubble':
        activeBubble.value = 'Classic Bubble';
        break;
      case 'Entry Effect':
        activeEntryEffect.value = 'None';
        break;
      case 'Entry Animation':
        activeEntryAnimation.value = 'None';
        break;
      case 'Avatar Effect':
        activeAvatarEffect.value = 'None';
        break;
      case 'Name Effect':
        activeNameEffect.value = 'None';
        break;
      case 'Profile Theme':
        activeTheme.value = 'Dark';
        break;
      case 'Background':
        activeBackground.value = 'None';
        break;
      case 'Status Effect':
        activeStatusStyle.value = 'None';
        break;
      case 'Emoji Pack':
        activeEmojiPack.value = 'Classic Emojis';
        break;
    }
    await _saveState();
  }

  // Favorite toggle
  Future<void> toggleFavorite(String itemName) async {
    if (favorites.contains(itemName)) {
      favorites.remove(itemName);
    } else {
      favorites.add(itemName);
    }
    await _saveState();
  }

  // Toggle Badge equipment (Max 5)
  Future<void> toggleBadge(String badgeName) async {
    if (activeBadges.contains(badgeName)) {
      activeBadges.remove(badgeName);
      await _saveState();
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
      activeBadges.add(badgeName);
      await _saveState();
    }
  }

  // Toggle Tag equipment (Max 3)
  Future<void> toggleTag(String tagName) async {
    if (activeTags.contains(tagName)) {
      activeTags.remove(tagName);
      await _saveState();
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
      activeTags.add(tagName);
      await _saveState();
    }
  }

  // Reorder active tags
  Future<void> reorderTags(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = activeTags.removeAt(oldIndex);
    activeTags.insert(newIndex, item);
    await _saveState();
  }

  // Toggle Gift equipment (Max 3)
  Future<void> toggleGift(String giftName) async {
    if (activeGifts.contains(giftName)) {
      activeGifts.remove(giftName);
      await _saveState();
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
      activeGifts.add(giftName);
      await _saveState();
    }
  }

  // Reorder active gifts
  Future<void> reorderGifts(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = activeGifts.removeAt(oldIndex);
    activeGifts.insert(newIndex, item);
    await _saveState();
  }

  // Reorder active badges
  Future<void> reorderBadges(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = activeBadges.removeAt(oldIndex);
    activeBadges.insert(newIndex, item);
    await _saveState();
  }

  // Unlock simulation helper
  Future<void> unlockItem(String itemName) async {
    if (!unlockedItems.contains(itemName)) {
      unlockedItems.add(itemName);
      await _saveState();
    }
  }

  // Check and clean up expired premium items
  void checkExpirations() {
    final now = DateTime.now();
    bool changed = false;

    // Check individual items
    final expiredItems = <String>[];
    itemExpiries.forEach((itemName, expiry) {
      if (expiry.isBefore(now)) {
        expiredItems.add(itemName);
      }
    });

    for (final itemName in expiredItems) {
      itemExpiries.remove(itemName);
      changed = true;

      // Automatically unequip if currently equipped
      if (activeFrame.value == itemName) activeFrame.value = 'Normal';
      if (activeBubble.value == itemName) activeBubble.value = 'Classic Bubble';
      if (activeEntryEffect.value == itemName) activeEntryEffect.value = 'None';
      if (activeEntryAnimation.value == itemName) activeEntryAnimation.value = 'None';
      if (activeAvatarEffect.value == itemName) activeAvatarEffect.value = 'None';
      if (activeNameEffect.value == itemName) activeNameEffect.value = 'None';
      if (activeTheme.value == itemName) activeTheme.value = 'Dark';
      if (activeBackground.value == itemName) activeBackground.value = 'None';
      if (activeStatusStyle.value == itemName) activeStatusStyle.value = 'None';
      if (activeAvatar.value == itemName) activeAvatar.value = 'Default';
      if (activeEmojiPack.value == itemName) activeEmojiPack.value = 'Classic Emojis';

      if (activeBadges.contains(itemName)) activeBadges.remove(itemName);
      if (activeTags.contains(itemName)) activeTags.remove(itemName);
      if (activeGifts.contains(itemName)) activeGifts.remove(itemName);

      Get.snackbar(
        '🔒 Item Expired',
        'Your premium item "$itemName" has expired and has been unequipped.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    }

    if (changed) {
      _saveState();
    }
  }

  // Extend validity or purchase item
  Future<void> renewOrPurchaseItem(String itemName, Duration duration) async {
    final now = DateTime.now();
    final currentExpiry = itemExpiries[itemName];

    if (currentExpiry != null && currentExpiry.isAfter(now)) {
      itemExpiries[itemName] = currentExpiry.add(duration);
    } else {
      itemExpiries[itemName] = now.add(duration);
    }

    if (!unlockedItems.contains(itemName)) {
      unlockedItems.add(itemName);
    }

    await _saveState();
  }

  // Generate warning reminders for items expiring in <= 3 days
  List<String> getActiveReminders() {
    final List<String> reminders = [];
    final now = DateTime.now();

    // 1. VIP Membership Expiry
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

    // 2. Novel Membership Expiry
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

    // 3. Cosmetics Expiry
    itemExpiries.forEach((itemName, expiry) {
      if (expiry.isAfter(now)) {
        final diff = expiry.difference(now);
        if (diff.inDays <= 3) {
          final item = customizationDb.firstWhere(
            (element) => element['name'] == itemName,
            orElse: () => <String, dynamic>{},
          );
          final String category = item.isNotEmpty ? (item['category'] ?? 'Item') : 'Item';
          if (diff.inDays >= 1) {
            reminders.add('Your $category ($itemName) expires in ${diff.inDays} days.');
          } else if (diff.inHours >= 1) {
            reminders.add('Your $category ($itemName) expires in ${diff.inHours} hours.');
          } else {
            reminders.add('Your $category ($itemName) expires soon.');
          }
        }
      }
    });

    return reminders;
  }
}
