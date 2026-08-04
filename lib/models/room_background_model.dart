import 'package:flutter/material.dart';

enum RoomBackgroundType {
  staticWallpaper,
  gradientWallpaper,
  animatedBackground,
  videoBackground,
  seasonal,
  festival,
  vipExclusive,
  customUpload,
}

enum AnimatedBackgroundType {
  particles,
  floatingLights,
  stars,
  snow,
  rain,
  bubbles,
  fireflies,
  aurora,
  animatedGradient,
}

class RoomBackgroundItem {
  final String id;
  final String title;
  final String category; // Classic, Minimal, Luxury, Gaming, Neon, Space, Ocean, Nature, Sunset, Night, Galaxy, Festival, Anime, VIP, Royal, Cute, Modern, Dark, Light, Seasonal, Trending
  final RoomBackgroundType type;
  final AnimatedBackgroundType? animatedType;
  final String? wallpaperUrl;
  final List<Color>? gradientColors;
  final AlignmentGeometry gradientBegin;
  final AlignmentGeometry gradientEnd;
  final bool isVip;
  final int requiredVipLevel;
  final bool isLightBackground;
  final double overlayDarkness; // 0.15 - 0.65
  final double blurOpacity; // 0.20 - 0.35
  final String? videoUrl;

  const RoomBackgroundItem({
    required this.id,
    required this.title,
    required this.category,
    required this.type,
    this.animatedType,
    this.wallpaperUrl,
    this.gradientColors,
    this.gradientBegin = Alignment.topCenter,
    this.gradientEnd = Alignment.bottomCenter,
    this.isVip = false,
    this.requiredVipLevel = 0,
    this.isLightBackground = false,
    this.overlayDarkness = 0.25,
    this.blurOpacity = 0.25,
    this.videoUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'type': type.name,
      'animatedType': animatedType?.name,
      'wallpaperUrl': wallpaperUrl,
      'gradientColors': gradientColors?.map((c) => c.value).toList(),
      'isVip': isVip,
      'requiredVipLevel': requiredVipLevel,
      'isLightBackground': isLightBackground,
      'overlayDarkness': overlayDarkness,
      'blurOpacity': blurOpacity,
      'videoUrl': videoUrl,
    };
  }

  factory RoomBackgroundItem.fromJson(Map<String, dynamic> json) {
    List<Color>? colors;
    if (json['gradientColors'] != null) {
      colors = (json['gradientColors'] as List)
          .map((c) => Color(c as int))
          .toList();
    }
    return RoomBackgroundItem(
      id: json['id'] ?? 'midnight_galaxy',
      title: json['title'] ?? 'Midnight Galaxy',
      category: json['category'] ?? 'Galaxy',
      type: RoomBackgroundType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => RoomBackgroundType.gradientWallpaper,
      ),
      animatedType: json['animatedType'] != null
          ? AnimatedBackgroundType.values.firstWhere(
              (e) => e.name == json['animatedType'],
              orElse: () => AnimatedBackgroundType.particles,
            )
          : null,
      wallpaperUrl: json['wallpaperUrl'],
      gradientColors: colors,
      isVip: json['isVip'] ?? false,
      requiredVipLevel: json['requiredVipLevel'] ?? 0,
      isLightBackground: json['isLightBackground'] ?? false,
      overlayDarkness: (json['overlayDarkness'] as num?)?.toDouble() ?? 0.25,
      blurOpacity: (json['blurOpacity'] as num?)?.toDouble() ?? 0.25,
      videoUrl: json['videoUrl'],
    );
  }
}

class RoomBackgroundCatalog {
  static const String defaultBackgroundId = 'midnight_galaxy';

  static final RoomBackgroundItem defaultBackground = RoomBackgroundItem(
    id: 'midnight_galaxy',
    title: 'Midnight Galaxy',
    category: 'Galaxy',
    type: RoomBackgroundType.animatedBackground,
    animatedType: AnimatedBackgroundType.stars,
    gradientColors: const [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF020617)],
    overlayDarkness: 0.20,
    blurOpacity: 0.25,
  );

  static final List<String> categories = [
    'All',
    'Trending',
    'Study',
    'Library',
    'Technology',
    'Gaming',
    'Luxury',
    'Night',
    'Minimal',
    'Space',
    'Galaxy',
    'Cyberpunk',
    'Festival',
    'Nature',
    'Rain',
    'Snow',
    'Ocean',
    'Sunset',
    'Cafe',
    'Neon',
    'Music',
    'Debate',
    'Podcast',
    'Education',
    'Anime Style',
    'Royal',
    'Premium VIP',
    'Seasonal',
  ];

  static final List<RoomBackgroundItem> allBackgrounds = [
    // 1. Galaxy & Space
    RoomBackgroundItem(
      id: 'midnight_galaxy',
      title: 'Midnight Galaxy',
      category: 'Galaxy',
      type: RoomBackgroundType.animatedBackground,
      animatedType: AnimatedBackgroundType.stars,
      gradientColors: const [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF020617)],
      overlayDarkness: 0.20,
    ),
    RoomBackgroundItem(
      id: 'deep_space_nebula',
      title: 'Deep Space Nebula',
      category: 'Space',
      type: RoomBackgroundType.animatedBackground,
      animatedType: AnimatedBackgroundType.aurora,
      gradientColors: const [Color(0xFF180E29), Color(0xFF2D124D), Color(0xFF07040D)],
      wallpaperUrl: 'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?w=1080&auto=format&fit=crop&q=80',
      overlayDarkness: 0.25,
    ),

    // 2. VIP & Royal
    RoomBackgroundItem(
      id: 'vip_gold_aura',
      title: 'Royal Gold Aura',
      category: 'VIP',
      type: RoomBackgroundType.animatedBackground,
      animatedType: AnimatedBackgroundType.fireflies,
      gradientColors: const [Color(0xFF2A1C00), Color(0xFF4A340B), Color(0xFF120B00)],
      wallpaperUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=1080&auto=format&fit=crop&q=80',
      isVip: true,
      requiredVipLevel: 1,
      overlayDarkness: 0.25,
    ),
    RoomBackgroundItem(
      id: 'royal_amethyst',
      title: 'Royal Amethyst',
      category: 'Royal',
      type: RoomBackgroundType.animatedBackground,
      animatedType: AnimatedBackgroundType.floatingLights,
      gradientColors: const [Color(0xFF3B0764), Color(0xFF581C87), Color(0xFF1E0136)],
      isVip: true,
      requiredVipLevel: 2,
      overlayDarkness: 0.20,
    ),

    // 3. Neon & Gaming
    RoomBackgroundItem(
      id: 'cyberpunk_neon',
      title: 'Cyberpunk Neon',
      category: 'Neon',
      type: RoomBackgroundType.animatedBackground,
      animatedType: AnimatedBackgroundType.particles,
      gradientColors: const [Color(0xFF030712), Color(0xFF1F0933), Color(0xFF020617)],
      wallpaperUrl: 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=1080&auto=format&fit=crop&q=80',
      overlayDarkness: 0.30,
    ),
    RoomBackgroundItem(
      id: 'gaming_arena',
      title: 'Esports Gaming',
      category: 'Gaming',
      type: RoomBackgroundType.animatedBackground,
      animatedType: AnimatedBackgroundType.animatedGradient,
      gradientColors: const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF090D16)],
      overlayDarkness: 0.25,
    ),

    // 4. Sunset & Nature
    RoomBackgroundItem(
      id: 'violet_sunset',
      title: 'Violet Sunset',
      category: 'Sunset',
      type: RoomBackgroundType.animatedBackground,
      animatedType: AnimatedBackgroundType.particles,
      gradientColors: const [Color(0xFF4C0519), Color(0xFF831843), Color(0xFF1F030B)],
      wallpaperUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1080&auto=format&fit=crop&q=80',
      overlayDarkness: 0.35,
    ),
    RoomBackgroundItem(
      id: 'emerald_forest',
      title: 'Emerald Forest',
      category: 'Nature',
      type: RoomBackgroundType.animatedBackground,
      animatedType: AnimatedBackgroundType.fireflies,
      gradientColors: const [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF022C22)],
      wallpaperUrl: 'https://images.unsplash.com/photo-1448375240586-882707db888b?w=1080&auto=format&fit=crop&q=80',
      overlayDarkness: 0.30,
    ),

    // 5. Ocean & Seasonal
    RoomBackgroundItem(
      id: 'deep_ocean',
      title: 'Deep Ocean Waves',
      category: 'Ocean',
      type: RoomBackgroundType.animatedBackground,
      animatedType: AnimatedBackgroundType.bubbles,
      gradientColors: const [Color(0xFF0C4A6E), Color(0xFF0369A1), Color(0xFF082F49)],
      wallpaperUrl: 'https://images.unsplash.com/photo-1518837695005-2083093ee35b?w=1080&auto=format&fit=crop&q=80',
      overlayDarkness: 0.25,
    ),
    RoomBackgroundItem(
      id: 'winter_snowfall',
      title: 'Winter Snowfall',
      category: 'Seasonal',
      type: RoomBackgroundType.animatedBackground,
      animatedType: AnimatedBackgroundType.snow,
      gradientColors: const [Color(0xFF1E293B), Color(0xFF334155), Color(0xFF0F172A)],
      overlayDarkness: 0.25,
    ),
    RoomBackgroundItem(
      id: 'monsoon_rain',
      title: 'Monsoon Rain',
      category: 'Seasonal',
      type: RoomBackgroundType.animatedBackground,
      animatedType: AnimatedBackgroundType.rain,
      gradientColors: const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF020617)],
      overlayDarkness: 0.25,
    ),

    // 6. Festival & Trending
    RoomBackgroundItem(
      id: 'diwali_festival_lights',
      title: 'Festival of Lights',
      category: 'Festival',
      type: RoomBackgroundType.animatedBackground,
      animatedType: AnimatedBackgroundType.floatingLights,
      gradientColors: const [Color(0xFF451A03), Color(0xFF78350F), Color(0xFF1C0A00)],
      wallpaperUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=1080&auto=format&fit=crop&q=80',
      overlayDarkness: 0.30,
    ),
    RoomBackgroundItem(
      id: 'sakura_anime',
      title: 'Sakura Dreams',
      category: 'Anime',
      type: RoomBackgroundType.animatedBackground,
      animatedType: AnimatedBackgroundType.particles,
      gradientColors: const [Color(0xFF831843), Color(0xFF9D174D), Color(0xFF4C0519)],
      wallpaperUrl: 'https://images.unsplash.com/photo-1522383225653-ed111181a951?w=1080&auto=format&fit=crop&q=80',
      overlayDarkness: 0.35,
    ),

    // 7. Minimal, Luxury, Classic & Modern
    RoomBackgroundItem(
      id: 'luxury_velvet',
      title: 'Luxury Velvet',
      category: 'Luxury',
      type: RoomBackgroundType.gradientWallpaper,
      gradientColors: const [Color(0xFF2D0612), Color(0xFF500B1E), Color(0xFF140207)],
      overlayDarkness: 0.20,
    ),
    RoomBackgroundItem(
      id: 'minimal_slate',
      title: 'Minimal Dark Slate',
      category: 'Minimal',
      type: RoomBackgroundType.gradientWallpaper,
      gradientColors: const [Color(0xFF18181B), Color(0xFF27272A), Color(0xFF09090B)],
      overlayDarkness: 0.15,
    ),
    RoomBackgroundItem(
      id: 'classic_dark',
      title: 'Classic Arena',
      category: 'Classic',
      type: RoomBackgroundType.gradientWallpaper,
      gradientColors: const [Color(0xFF0F172A), Color(0xFF020617)],
      overlayDarkness: 0.20,
    ),
    RoomBackgroundItem(
      id: 'cute_pastel_aurora',
      title: 'Pastel Dream',
      category: 'Cute',
      type: RoomBackgroundType.animatedBackground,
      animatedType: AnimatedBackgroundType.aurora,
      gradientColors: const [Color(0xFFF472B6), Color(0xFFC084FC), Color(0xFF38BDF8)],
      isLightBackground: true,
      overlayDarkness: 0.55,
    ),
    RoomBackgroundItem(
      id: 'modern_light_glass',
      title: 'Modern Light Glass',
      category: 'Light',
      type: RoomBackgroundType.gradientWallpaper,
      gradientColors: const [Color(0xFFE2E8F0), Color(0xFFCBD5E1), Color(0xFF94A3B8)],
      isLightBackground: true,
      overlayDarkness: 0.60,
    ),
    RoomBackgroundItem(
      id: 'trending_synthwave',
      title: 'Synthwave Skyline',
      category: 'Trending',
      type: RoomBackgroundType.animatedBackground,
      animatedType: AnimatedBackgroundType.animatedGradient,
      gradientColors: const [Color(0xFF31103F), Color(0xFF701A75), Color(0xFF0F172A)],
      wallpaperUrl: 'https://images.unsplash.com/photo-1508739773434-c26b3d09e071?w=1080&auto=format&fit=crop&q=80',
      overlayDarkness: 0.30,
    ),
  ];
}
