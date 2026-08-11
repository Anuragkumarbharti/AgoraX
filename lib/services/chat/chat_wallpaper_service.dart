import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/chat_message.dart';
import '../user/user_profile_cache_manager.dart';

enum WallpaperType {
  preset,
  customImage,
  solidColor,
}

class ChatWallpaper {
  final String conversationId;
  final WallpaperType type;
  final String value; // Preset ID, image file path, or color hex
  final double dimness; // 0.0 to 0.8
  final double blur; // 0.0 to 20.0
  final String fitMode; // 'cover', 'contain', 'fill'

  ChatWallpaper({
    required this.conversationId,
    this.type = WallpaperType.preset,
    this.value = 'default_dark',
    this.dimness = 0.25,
    this.blur = 0.0,
    this.fitMode = 'cover',
  });

  ChatWallpaper copyWith({
    WallpaperType? type,
    String? value,
    double? dimness,
    double? blur,
    String? fitMode,
  }) {
    return ChatWallpaper(
      conversationId: conversationId,
      type: type ?? this.type,
      value: value ?? this.value,
      dimness: dimness ?? this.dimness,
      blur: blur ?? this.blur,
      fitMode: fitMode ?? this.fitMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'conversationId': conversationId,
        'type': type.name,
        'value': value,
        'dimness': dimness,
        'blur': blur,
        'fitMode': fitMode,
      };

  factory ChatWallpaper.fromJson(Map<String, dynamic> json) {
    return ChatWallpaper(
      conversationId: json['conversationId'] ?? 'global',
      type: WallpaperType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => WallpaperType.preset,
      ),
      value: json['value'] ?? 'default_dark',
      dimness: (json['dimness'] as num?)?.toDouble() ?? 0.25,
      blur: (json['blur'] as num?)?.toDouble() ?? 0.0,
      fitMode: json['fitMode'] ?? 'cover',
    );
  }

  String get displayName {
    switch (type) {
      case WallpaperType.customImage:
        return 'Custom Image (${(dimness * 100).round()}% Dim)';
      case WallpaperType.solidColor:
        return 'Solid Color ($value)';
      case WallpaperType.preset:
        final p = ChatWallpaperService.presets.firstWhereOrNull((x) => x['id'] == value);
        return p != null ? p['name'] : 'Default Dark';
    }
  }
}

class ChatWallpaperService extends GetxService {
  static ChatWallpaperService get to {
    if (!Get.isRegistered<ChatWallpaperService>()) {
      Get.put(ChatWallpaperService(), permanent: true);
    }
    return Get.find<ChatWallpaperService>();
  }

  static const String _prefKeyPrefix = 'chat_wallpaper_';
  static const String _clearedAtPrefix = 'chat_cleared_at_';

  final RxMap<String, ChatWallpaper> _wallpapers = <String, ChatWallpaper>{}.obs;
  final RxMap<String, int> _clearedAtTimestamps = <String, int>{}.obs;
  SharedPreferences? _prefs;

  static const List<Map<String, dynamic>> presets = [
    {
      'id': 'default_dark',
      'name': 'Default Dark',
      'colors': [Color(0xFF0F172A), Color(0xFF1E293B)],
      'icon': Icons.dark_mode_rounded,
    },
    {
      'id': 'cyber_purple',
      'name': 'Cyber Purple',
      'colors': [Color(0xFF2E1065), Color(0xFF581C87), Color(0xFF0F172A)],
      'icon': Icons.auto_awesome_rounded,
    },
    {
      'id': 'midnight_blue',
      'name': 'Midnight Space',
      'colors': [Color(0xFF030712), Color(0xFF0B192C), Color(0xFF1E3E62)],
      'icon': Icons.nights_stay_rounded,
    },
    {
      'id': 'emerald_forest',
      'name': 'Emerald Dusk',
      'colors': [Color(0xFF022C22), Color(0xFF064E3B), Color(0xFF0F172A)],
      'icon': Icons.eco_rounded,
    },
    {
      'id': 'sunset_glow',
      'name': 'Warm Sunset',
      'colors': [Color(0xFF451A03), Color(0xFF7C2D12), Color(0xFF9A3412)],
      'icon': Icons.wb_sunny_rounded,
    },
    {
      'id': 'amoled_black',
      'name': 'Pitch Black',
      'colors': [Color(0xFF000000), Color(0xFF000000)],
      'icon': Icons.contrast_rounded,
    },
  ];

  static const List<Map<String, dynamic>> solidColors = [
    {'name': 'Pitch Black', 'color': Color(0xFF000000), 'hex': '#000000'},
    {'name': 'Slate Grey', 'color': Color(0xFF1E293B), 'hex': '#1E293B'},
    {'name': 'Deep Navy', 'color': Color(0xFF0F172A), 'hex': '#0F172A'},
    {'name': 'Dark Violet', 'color': Color(0xFF2E1065), 'hex': '#2E1065'},
    {'name': 'Deep Forest', 'color': Color(0xFF022C22), 'hex': '#022C22'},
  ];

  @override
  void onInit() {
    super.onInit();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _loadAllWallpapers();
    } catch (e) {
      debugPrint('[ChatWallpaperService] SharedPreferences init error: $e');
    }
  }

  void _loadAllWallpapers() {
    if (_prefs == null) return;
    final keys = _prefs!.getKeys();
    for (final k in keys) {
      if (k.startsWith(_prefKeyPrefix)) {
        final convId = k.replaceFirst(_prefKeyPrefix, '');
        final jsonStr = _prefs!.getString(k);
        if (jsonStr != null) {
          try {
            _wallpapers[convId] = ChatWallpaper.fromJson(jsonDecode(jsonStr));
          } catch (_) {}
        }
      } else if (k.startsWith(_clearedAtPrefix)) {
        final convId = k.replaceFirst(_clearedAtPrefix, '');
        final ts = _prefs!.getInt(k);
        if (ts != null) {
          _clearedAtTimestamps[convId] = ts;
        }
      }
    }
  }

  ChatWallpaper getWallpaper(String conversationId) {
    if (_wallpapers.containsKey(conversationId)) {
      return _wallpapers[conversationId]!;
    }
    if (_wallpapers.containsKey('global')) {
      return _wallpapers['global']!;
    }
    return ChatWallpaper(conversationId: conversationId);
  }

  Future<void> saveWallpaper(ChatWallpaper wallpaper) async {
    _wallpapers[wallpaper.conversationId] = wallpaper;
    _wallpapers.refresh();
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    await _prefs?.setString(
      '$_prefKeyPrefix${wallpaper.conversationId}',
      jsonEncode(wallpaper.toJson()),
    );
  }

  Future<void> resetWallpaper(String conversationId) async {
    _wallpapers.remove(conversationId);
    _wallpapers.refresh();
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    await _prefs?.remove('$_prefKeyPrefix$conversationId');
  }

  // ─── Custom Image Picker ───
  Future<String?> pickCustomWallpaperImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      return file?.path;
    } catch (e) {
      debugPrint('[ChatWallpaperService] Pick image error: $e');
      return null;
    }
  }

  // ─── Cleared At Timestamp Persistence ───
  Future<void> setConversationClearedAt(String conversationId, DateTime timestamp) async {
    final ms = timestamp.millisecondsSinceEpoch;
    _clearedAtTimestamps[conversationId] = ms;
    _clearedAtTimestamps.refresh();
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    await _prefs?.setInt('$_clearedAtPrefix$conversationId', ms);
  }

  int? getConversationClearedAt(String conversationId, {String? otherUserId}) {
    int? maxTs;
    final List<String> keys = [conversationId];
    if (otherUserId != null && otherUserId.isNotEmpty) {
      keys.add(otherUserId);
      final currentUid = UserProfileCacheManager.currentUserId;
      if (currentUid.isNotEmpty) {
        keys.add(ChatMessage.getDeterministicConversationId(currentUid, otherUserId));
      }
    }

    for (final key in keys) {
      int? ts = _clearedAtTimestamps[key];
      if (ts == null && _prefs != null) {
        ts = _prefs?.getInt('$_clearedAtPrefix$key');
        if (ts != null) {
          _clearedAtTimestamps[key] = ts;
        }
      }
      if (ts != null) {
        if (maxTs == null || ts > maxTs) {
          maxTs = ts;
        }
      }
    }
    return maxTs;
  }
}
