import 'package:flutter/material.dart';

class RoomBackgroundItem {
  final String id;
  final String title;
  final String assetPath;
  final bool isDefault;
  final bool isLightBackground;
  final double overlayDarkness;

  const RoomBackgroundItem({
    required this.id,
    required this.title,
    required this.assetPath,
    this.isDefault = false,
    this.isLightBackground = false,
    this.overlayDarkness = 0.20,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'assetPath': assetPath,
      'isDefault': isDefault,
      'isLightBackground': isLightBackground,
      'overlayDarkness': overlayDarkness,
    };
  }

  factory RoomBackgroundItem.fromJson(Map<String, dynamic> json) {
    final String jsonId = json['id'] ?? 'theme_1';
    final found = RoomBackgroundCatalog.allBackgrounds.firstWhere(
      (bg) => bg.id == jsonId || bg.title.toLowerCase() == (json['title'] ?? '').toString().toLowerCase(),
      orElse: () => RoomBackgroundCatalog.defaultBackground,
    );
    return found;
  }
}

class RoomBackgroundCatalog {
  static const String defaultBackgroundId = 'theme_1';

  static const RoomBackgroundItem defaultBackground = RoomBackgroundItem(
    id: 'theme_1',
    title: 'Theme 1',
    assetPath: 'assets/backgroundroom/1.webp',
    isDefault: true,
  );

  static const List<RoomBackgroundItem> allBackgrounds = [
    RoomBackgroundItem(
      id: 'theme_1',
      title: 'Theme 1',
      assetPath: 'assets/backgroundroom/1.webp',
      isDefault: true,
    ),
    RoomBackgroundItem(
      id: 'theme_2',
      title: 'Theme 2',
      assetPath: 'assets/backgroundroom/2.webp',
    ),
    RoomBackgroundItem(
      id: 'theme_3',
      title: 'Theme 3',
      assetPath: 'assets/backgroundroom/3.webp',
    ),
    RoomBackgroundItem(
      id: 'theme_4',
      title: 'Theme 4',
      assetPath: 'assets/backgroundroom/4.webp',
    ),
    RoomBackgroundItem(
      id: 'theme_5',
      title: 'Theme 5',
      assetPath: 'assets/backgroundroom/5.webp',
    ),
    RoomBackgroundItem(
      id: 'theme_6',
      title: 'Theme 6',
      assetPath: 'assets/backgroundroom/6.webp',
    ),
    RoomBackgroundItem(
      id: 'theme_7',
      title: 'Theme 7',
      assetPath: 'assets/backgroundroom/7.webp',
    ),
    RoomBackgroundItem(
      id: 'theme_8',
      title: 'Theme 8',
      assetPath: 'assets/backgroundroom/8.webp',
    ),
  ];

  static RoomBackgroundItem findById(String? id) {
    if (id == null || id.isEmpty) return defaultBackground;
    return allBackgrounds.firstWhere(
      (bg) => bg.id == id || bg.title.toLowerCase() == id.toLowerCase(),
      orElse: () => defaultBackground,
    );
  }
}
