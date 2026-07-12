// Creania Premium Cosmetic Asset Registry
// Statically typed configurations and asset paths for all 15 VIP & Novel collections.

class CosmeticAsset {
  final String id;
  final String name;
  final String path;
  final String animatedPath;
  final String category;
  final Map<String, dynamic> metadata;

  const CosmeticAsset({
    required this.id,
    required this.name,
    required this.path,
    required this.animatedPath,
    required this.category,
    this.metadata = const {},
  });
}

class CosmeticCollection {
  final String id;
  final String name;
  final String tier; // VIP or Novel
  final int requiredLevel;
  final String theme;
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final List<String> designElements;

  // Asset configurations
  final CosmeticAsset avatarFrame;
  final CosmeticAsset chatBubble;
  final CosmeticAsset nameGlow;
  final CosmeticAsset avatarAura;
  final CosmeticAsset entryEffect;
  final CosmeticAsset badge;
  final CosmeticAsset tag;
  final CosmeticAsset profileTheme;
  final CosmeticAsset background;
  final CosmeticAsset gift;
  final CosmeticAsset emojiPack;
  final CosmeticAsset storePreview;
  final CosmeticAsset thumbnail;

  const CosmeticCollection({
    required this.id,
    required this.name,
    required this.tier,
    required this.requiredLevel,
    required this.theme,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.designElements,
    required this.avatarFrame,
    required this.chatBubble,
    required this.nameGlow,
    required this.avatarAura,
    required this.entryEffect,
    required this.badge,
    required this.tag,
    required this.profileTheme,
    required this.background,
    required this.gift,
    required this.emojiPack,
    required this.storePreview,
    required this.thumbnail,
  });
}

class CosmeticsRegistry {
  static const String basePath = 'assets/images/cosmetics';

  static final List<CosmeticCollection> collections = [
    // ==========================================
    // VIP COLLECTIONS (VIP 1 - 7)
    // ==========================================

    CosmeticCollection(
      id: 'vip_1_royal_silver',
      name: 'Royal Silver Collection',
      tier: 'VIP',
      requiredLevel: 1,
      theme: 'Classical silver royalty and blue velvet',
      primaryColor: '#CBD5E1', // Silver
      secondaryColor: '#2563EB', // Blue
      accentColor: '#1E40AF',
      designElements: ['Silver Filigree', 'Royal Blue Velvet', 'Sparkles'],
      avatarFrame: const CosmeticAsset(
        id: 'royal_silver_frame',
        name: 'Royal Silver Frame',
        path: '$basePath/vip_1/frame.png',
        animatedPath: '$basePath/vip_1/frame.webp',
        category: 'Avatar Frame',
      ),
      chatBubble: const CosmeticAsset(
        id: 'royal_silver_bubble',
        name: 'Royal Silver Bubble',
        path: '$basePath/vip_1/bubble.png',
        animatedPath: '$basePath/vip_1/bubble_anim.webp',
        category: 'Chat Bubble',
      ),
      nameGlow: const CosmeticAsset(
        id: 'royal_silver_name',
        name: 'Royal Silver Glow',
        path: '$basePath/vip_1/name_glow.png',
        animatedPath: '$basePath/vip_1/name_glow.webp',
        category: 'Name Effect',
      ),
      avatarAura: const CosmeticAsset(
        id: 'royal_silver_aura',
        name: 'Royal Silver Aura',
        path: '$basePath/vip_1/aura.png',
        animatedPath: '$basePath/vip_1/aura.webp',
        category: 'Avatar Effect',
      ),
      entryEffect: const CosmeticAsset(
        id: 'royal_silver_entry',
        name: 'Royal Silver Teleport',
        path: '$basePath/vip_1/entry.png',
        animatedPath: '$basePath/vip_1/entry.webm',
        category: 'Entry Effect',
      ),
      badge: const CosmeticAsset(
        id: 'royal_silver_badge',
        name: 'Royal Silver Badge',
        path: '$basePath/vip_1/badge.png',
        animatedPath: '$basePath/vip_1/badge_anim.webp',
        category: 'Badges',
      ),
      tag: const CosmeticAsset(
        id: 'royal_silver_tag',
        name: 'Royal Silver Tag',
        path: '$basePath/vip_1/tag.png',
        animatedPath: '$basePath/vip_1/tag_anim.webp',
        category: 'Tags',
      ),
      profileTheme: const CosmeticAsset(
        id: 'royal_silver_theme',
        name: 'Royal Silver Theme',
        path: '$basePath/vip_1/theme.json',
        animatedPath: '',
        category: 'Profile Theme',
      ),
      background: const CosmeticAsset(
        id: 'royal_silver_bg',
        name: 'Royal Silver Background',
        path: '$basePath/vip_1/bg.jpg',
        animatedPath: '',
        category: 'Background',
      ),
      gift: const CosmeticAsset(
        id: 'royal_silver_gift',
        name: 'Royal Silver Gift',
        path: '$basePath/vip_1/gift.png',
        animatedPath: '$basePath/vip_1/gift.webp',
        category: 'Gift Showcase',
      ),
      emojiPack: const CosmeticAsset(
        id: 'royal_silver_emojis',
        name: 'Royal Silver Emojis',
        path: '$basePath/vip_1/emojis/',
        animatedPath: '$basePath/vip_1/emojis_anim/',
        category: 'Emoji Pack',
      ),
      storePreview: const CosmeticAsset(
        id: 'royal_silver_preview',
        name: 'Royal Silver Preview',
        path: '$basePath/vip_1/preview.jpg',
        animatedPath: '',
        category: 'Store Preview',
      ),
      thumbnail: const CosmeticAsset(
        id: 'royal_silver_thumb',
        name: 'Royal Silver Thumbnail',
        path: '$basePath/vip_1/thumb.png',
        animatedPath: '',
        category: 'Thumbnail',
      ),
    ),

    CosmeticCollection(
      id: 'vip_2_neon_crystal',
      name: 'Neon Crystal Collection',
      tier: 'VIP',
      requiredLevel: 2,
      theme: 'Cyberpunk glassmorphism and glowing neon tubes',
      primaryColor: '#FF007F', // Neon Pink
      secondaryColor: '#00F0FF', // Neon Cyan
      accentColor: '#8B5CF6',
      designElements: ['Hexagonal Grid', 'Glowing Tubes', 'Glassmorphism'],
      avatarFrame: const CosmeticAsset(
        id: 'neon_crystal_frame',
        name: 'Neon Crystal Frame',
        path: '$basePath/vip_2/frame.png',
        animatedPath: '$basePath/vip_2/frame.webp',
        category: 'Avatar Frame',
      ),
      chatBubble: const CosmeticAsset(
        id: 'neon_crystal_bubble',
        name: 'Neon Crystal Bubble',
        path: '$basePath/vip_2/bubble.png',
        animatedPath: '$basePath/vip_2/bubble_anim.webp',
        category: 'Chat Bubble',
      ),
      nameGlow: const CosmeticAsset(
        id: 'neon_crystal_name',
        name: 'Neon Crystal Glow',
        path: '$basePath/vip_2/name_glow.png',
        animatedPath: '$basePath/vip_2/name_glow.webp',
        category: 'Name Effect',
      ),
      avatarAura: const CosmeticAsset(
        id: 'neon_crystal_aura',
        name: 'Neon Crystal Aura',
        path: '$basePath/vip_2/aura.png',
        animatedPath: '$basePath/vip_2/aura.webp',
        category: 'Avatar Effect',
      ),
      entryEffect: const CosmeticAsset(
        id: 'neon_crystal_entry',
        name: 'Neon Crystal Warp',
        path: '$basePath/vip_2/entry.png',
        animatedPath: '$basePath/vip_2/entry.webm',
        category: 'Entry Effect',
      ),
      badge: const CosmeticAsset(
        id: 'neon_crystal_badge',
        name: 'Neon Crystal Badge',
        path: '$basePath/vip_2/badge.png',
        animatedPath: '$basePath/vip_2/badge_anim.webp',
        category: 'Badges',
      ),
      tag: const CosmeticAsset(
        id: 'neon_crystal_tag',
        name: 'Neon Crystal Tag',
        path: '$basePath/vip_2/tag.png',
        animatedPath: '$basePath/vip_2/tag_anim.webp',
        category: 'Tags',
      ),
      profileTheme: const CosmeticAsset(
        id: 'neon_crystal_theme',
        name: 'Neon Crystal Theme',
        path: '$basePath/vip_2/theme.json',
        animatedPath: '',
        category: 'Profile Theme',
      ),
      background: const CosmeticAsset(
        id: 'neon_crystal_bg',
        name: 'Neon Crystal Background',
        path: '$basePath/vip_2/bg.jpg',
        animatedPath: '',
        category: 'Background',
      ),
      gift: const CosmeticAsset(
        id: 'neon_crystal_gift',
        name: 'Neon Crystal Gift',
        path: '$basePath/vip_2/gift.png',
        animatedPath: '$basePath/vip_2/gift.webp',
        category: 'Gift Showcase',
      ),
      emojiPack: const CosmeticAsset(
        id: 'neon_crystal_emojis',
        name: 'Neon Crystal Emojis',
        path: '$basePath/vip_2/emojis/',
        animatedPath: '$basePath/vip_2/emojis_anim/',
        category: 'Emoji Pack',
      ),
      storePreview: const CosmeticAsset(
        id: 'neon_crystal_preview',
        name: 'Neon Crystal Preview',
        path: '$basePath/vip_2/preview.jpg',
        animatedPath: '',
        category: 'Store Preview',
      ),
      thumbnail: const CosmeticAsset(
        id: 'neon_crystal_thumb',
        name: 'Neon Crystal Thumbnail',
        path: '$basePath/vip_2/thumb.png',
        animatedPath: '',
        category: 'Thumbnail',
      ),
    ),

    CosmeticCollection(
      id: 'vip_3_golden_emperor',
      name: 'Golden Emperor Collection',
      tier: 'VIP',
      requiredLevel: 3,
      theme: 'Polished liquid gold, gilding, and sparkling crowns',
      primaryColor: '#FFD700', // Gold
      secondaryColor: '#B45309', // Amber
      accentColor: '#D4AF37',
      designElements: ['Gilded Carvings', 'Reflective Stars', 'Crowns'],
      avatarFrame: const CosmeticAsset(
        id: 'golden_emperor_frame',
        name: 'Golden Emperor Frame',
        path: '$basePath/vip_3/frame.png',
        animatedPath: '$basePath/vip_3/frame.webp',
        category: 'Avatar Frame',
      ),
      chatBubble: const CosmeticAsset(
        id: 'golden_emperor_bubble',
        name: 'Golden Emperor Bubble',
        path: '$basePath/vip_3/bubble.png',
        animatedPath: '$basePath/vip_3/bubble_anim.webp',
        category: 'Chat Bubble',
      ),
      nameGlow: const CosmeticAsset(
        id: 'golden_emperor_name',
        name: 'Golden Emperor Glow',
        path: '$basePath/vip_3/name_glow.png',
        animatedPath: '$basePath/vip_3/name_glow.webp',
        category: 'Name Effect',
      ),
      avatarAura: const CosmeticAsset(
        id: 'golden_emperor_aura',
        name: 'Golden Emperor Aura',
        path: '$basePath/vip_3/aura.png',
        animatedPath: '$basePath/vip_3/aura.webp',
        category: 'Avatar Effect',
      ),
      entryEffect: const CosmeticAsset(
        id: 'golden_emperor_entry',
        name: 'Golden Emperor Arrival',
        path: '$basePath/vip_3/entry.png',
        animatedPath: '$basePath/vip_3/entry.webm',
        category: 'Entry Effect',
      ),
      badge: const CosmeticAsset(
        id: 'golden_emperor_badge',
        name: 'Golden Emperor Badge',
        path: '$basePath/vip_3/badge.png',
        animatedPath: '$basePath/vip_3/badge_anim.webp',
        category: 'Badges',
      ),
      tag: const CosmeticAsset(
        id: 'golden_emperor_tag',
        name: 'Golden Emperor Tag',
        path: '$basePath/vip_3/tag.png',
        animatedPath: '$basePath/vip_3/tag_anim.webp',
        category: 'Tags',
      ),
      profileTheme: const CosmeticAsset(
        id: 'golden_emperor_theme',
        name: 'Golden Emperor Theme',
        path: '$basePath/vip_3/theme.json',
        animatedPath: '',
        category: 'Profile Theme',
      ),
      background: const CosmeticAsset(
        id: 'golden_emperor_bg',
        name: 'Golden Emperor Background',
        path: '$basePath/vip_3/bg.jpg',
        animatedPath: '',
        category: 'Background',
      ),
      gift: const CosmeticAsset(
        id: 'golden_emperor_gift',
        name: 'Golden Emperor Gift',
        path: '$basePath/vip_3/gift.png',
        animatedPath: '$basePath/vip_3/gift.webp',
        category: 'Gift Showcase',
      ),
      emojiPack: const CosmeticAsset(
        id: 'golden_emperor_emojis',
        name: 'Golden Emperor Emojis',
        path: '$basePath/vip_3/emojis/',
        animatedPath: '$basePath/vip_3/emojis_anim/',
        category: 'Emoji Pack',
      ),
      storePreview: const CosmeticAsset(
        id: 'golden_emperor_preview',
        name: 'Golden Emperor Preview',
        path: '$basePath/vip_3/preview.jpg',
        animatedPath: '',
        category: 'Store Preview',
      ),
      thumbnail: const CosmeticAsset(
        id: 'golden_emperor_thumb',
        name: 'Golden Emperor Thumbnail',
        path: '$basePath/vip_3/thumb.png',
        animatedPath: '',
        category: 'Thumbnail',
      ),
    ),

    CosmeticCollection(
      id: 'vip_4_diamond',
      name: 'Diamond Collection',
      tier: 'VIP',
      requiredLevel: 4,
      theme: 'Pristine diamond crystals, light refractions, and platinum details',
      primaryColor: '#F8FAFC', // Diamond White
      secondaryColor: '#CBD5E1', // Silver
      accentColor: '#E2E8F0',
      designElements: ['Diamond Facets', 'Rainbow Prisms', 'Flares'],
      avatarFrame: const CosmeticAsset(
        id: 'diamond_frame',
        name: 'Diamond Frame',
        path: '$basePath/vip_4/frame.png',
        animatedPath: '$basePath/vip_4/frame.webp',
        category: 'Avatar Frame',
      ),
      chatBubble: const CosmeticAsset(
        id: 'diamond_bubble',
        name: 'Diamond Bubble',
        path: '$basePath/vip_4/bubble.png',
        animatedPath: '$basePath/vip_4/bubble_anim.webp',
        category: 'Chat Bubble',
      ),
      nameGlow: const CosmeticAsset(
        id: 'diamond_name',
        name: 'Diamond Glow',
        path: '$basePath/vip_4/name_glow.png',
        animatedPath: '$basePath/vip_4/name_glow.webp',
        category: 'Name Effect',
      ),
      avatarAura: const CosmeticAsset(
        id: 'diamond_aura',
        name: 'Diamond Aura',
        path: '$basePath/vip_4/aura.png',
        animatedPath: '$basePath/vip_4/aura.webp',
        category: 'Avatar Effect',
      ),
      entryEffect: const CosmeticAsset(
        id: 'diamond_entry',
        name: 'Diamond Portal',
        path: '$basePath/vip_4/entry.png',
        animatedPath: '$basePath/vip_4/entry.webm',
        category: 'Entry Effect',
      ),
      badge: const CosmeticAsset(
        id: 'diamond_badge',
        name: 'Diamond Badge',
        path: '$basePath/vip_4/badge.png',
        animatedPath: '$basePath/vip_4/badge_anim.webp',
        category: 'Badges',
      ),
      tag: const CosmeticAsset(
        id: 'diamond_tag',
        name: 'Diamond Tag',
        path: '$basePath/vip_4/tag.png',
        animatedPath: '$basePath/vip_4/tag_anim.webp',
        category: 'Tags',
      ),
      profileTheme: const CosmeticAsset(
        id: 'diamond_theme',
        name: 'Diamond Theme',
        path: '$basePath/vip_4/theme.json',
        animatedPath: '',
        category: 'Profile Theme',
      ),
      background: const CosmeticAsset(
        id: 'diamond_bg',
        name: 'Diamond Background',
        path: '$basePath/vip_4/bg.jpg',
        animatedPath: '',
        category: 'Background',
      ),
      gift: const CosmeticAsset(
        id: 'diamond_gift',
        name: 'Diamond Gift',
        path: '$basePath/vip_4/gift.png',
        animatedPath: '$basePath/vip_4/gift.webp',
        category: 'Gift Showcase',
      ),
      emojiPack: const CosmeticAsset(
        id: 'diamond_emojis',
        name: 'Diamond Emojis',
        path: '$basePath/vip_4/emojis/',
        animatedPath: '$basePath/vip_4/emojis_anim/',
        category: 'Emoji Pack',
      ),
      storePreview: const CosmeticAsset(
        id: 'diamond_preview',
        name: 'Diamond Preview',
        path: '$basePath/vip_4/preview.jpg',
        animatedPath: '',
        category: 'Store Preview',
      ),
      thumbnail: const CosmeticAsset(
        id: 'diamond_thumb',
        name: 'Diamond Thumbnail',
        path: '$basePath/vip_4/thumb.png',
        animatedPath: '',
        category: 'Thumbnail',
      ),
    ),

    CosmeticCollection(
      id: 'vip_5_crystal_cyan',
      name: 'Crystal Cyan Collection',
      tier: 'VIP',
      requiredLevel: 5,
      theme: 'Frozen shards, icy mist, and deep teal lighting',
      primaryColor: '#06B6D4', // Cyan
      secondaryColor: '#0891B2', // Teal
      accentColor: '#FFFFFF', // Glacier White
      designElements: ['Icicle Spikes', 'Frost Textures', 'Chilled Vapor'],
      avatarFrame: const CosmeticAsset(
        id: 'crystal_cyan_frame',
        name: 'Crystal Cyan Frame',
        path: '$basePath/vip_5/frame.png',
        animatedPath: '$basePath/vip_5/frame.webp',
        category: 'Avatar Frame',
      ),
      chatBubble: const CosmeticAsset(
        id: 'crystal_cyan_bubble',
        name: 'Crystal Cyan Bubble',
        path: '$basePath/vip_5/bubble.png',
        animatedPath: '$basePath/vip_5/bubble_anim.webp',
        category: 'Chat Bubble',
      ),
      nameGlow: const CosmeticAsset(
        id: 'crystal_cyan_name',
        name: 'Crystal Cyan Glow',
        path: '$basePath/vip_5/name_glow.png',
        animatedPath: '$basePath/vip_5/name_glow.webp',
        category: 'Name Effect',
      ),
      avatarAura: const CosmeticAsset(
        id: 'crystal_cyan_aura',
        name: 'Crystal Cyan Aura',
        path: '$basePath/vip_5/aura.png',
        animatedPath: '$basePath/vip_5/aura.webp',
        category: 'Avatar Effect',
      ),
      entryEffect: const CosmeticAsset(
        id: 'crystal_cyan_entry',
        name: 'Crystal Cyan Blizzard',
        path: '$basePath/vip_5/entry.png',
        animatedPath: '$basePath/vip_5/entry.webm',
        category: 'Entry Effect',
      ),
      badge: const CosmeticAsset(
        id: 'crystal_cyan_badge',
        name: 'Crystal Cyan Badge',
        path: '$basePath/vip_5/badge.png',
        animatedPath: '$basePath/vip_5/badge_anim.webp',
        category: 'Badges',
      ),
      tag: const CosmeticAsset(
        id: 'crystal_cyan_tag',
        name: 'Crystal Cyan Tag',
        path: '$basePath/vip_5/tag.png',
        animatedPath: '$basePath/vip_5/tag_anim.webp',
        category: 'Tags',
      ),
      profileTheme: const CosmeticAsset(
        id: 'crystal_cyan_theme',
        name: 'Crystal Cyan Theme',
        path: '$basePath/vip_5/theme.json',
        animatedPath: '',
        category: 'Profile Theme',
      ),
      background: const CosmeticAsset(
        id: 'crystal_cyan_bg',
        name: 'Crystal Cyan Background',
        path: '$basePath/vip_5/bg.jpg',
        animatedPath: '',
        category: 'Background',
      ),
      gift: const CosmeticAsset(
        id: 'crystal_cyan_gift',
        name: 'Crystal Cyan Gift',
        path: '$basePath/vip_5/gift.png',
        animatedPath: '$basePath/vip_5/gift.webp',
        category: 'Gift Showcase',
      ),
      emojiPack: const CosmeticAsset(
        id: 'crystal_cyan_emojis',
        name: 'Crystal Cyan Emojis',
        path: '$basePath/vip_5/emojis/',
        animatedPath: '$basePath/vip_5/emojis_anim/',
        category: 'Emoji Pack',
      ),
      storePreview: const CosmeticAsset(
        id: 'crystal_cyan_preview',
        name: 'Crystal Cyan Preview',
        path: '$basePath/vip_5/preview.jpg',
        animatedPath: '',
        category: 'Store Preview',
      ),
      thumbnail: const CosmeticAsset(
        id: 'crystal_cyan_thumb',
        name: 'Crystal Cyan Thumbnail',
        path: '$basePath/vip_5/thumb.png',
        animatedPath: '',
        category: 'Thumbnail',
      ),
    ),

    CosmeticCollection(
      id: 'vip_6_rainbow_divine',
      name: 'Rainbow Divine Collection',
      tier: 'VIP',
      requiredLevel: 6,
      theme: 'Prism sweeps, light wave cycles, and color flows',
      primaryColor: '#FF007F', // Magenta
      secondaryColor: '#FFBF00', // Amber
      accentColor: '#00F0FF', // Cyan
      designElements: ['Spectrum Waves', 'Holographic Overlays', 'Star Glints'],
      avatarFrame: const CosmeticAsset(
        id: 'rainbow_divine_frame',
        name: 'Rainbow Divine Frame',
        path: '$basePath/vip_6/frame.png',
        animatedPath: '$basePath/vip_6/frame.webp',
        category: 'Avatar Frame',
      ),
      chatBubble: const CosmeticAsset(
        id: 'rainbow_divine_bubble',
        name: 'Rainbow Divine Bubble',
        path: '$basePath/vip_6/bubble.png',
        animatedPath: '$basePath/vip_6/bubble_anim.webp',
        category: 'Chat Bubble',
      ),
      nameGlow: const CosmeticAsset(
        id: 'rainbow_divine_name',
        name: 'Rainbow Divine Glow',
        path: '$basePath/vip_6/name_glow.png',
        animatedPath: '$basePath/vip_6/name_glow.webp',
        category: 'Name Effect',
      ),
      avatarAura: const CosmeticAsset(
        id: 'rainbow_divine_aura',
        name: 'Rainbow Divine Aura',
        path: '$basePath/vip_6/aura.png',
        animatedPath: '$basePath/vip_6/aura.webp',
        category: 'Avatar Effect',
      ),
      entryEffect: const CosmeticAsset(
        id: 'rainbow_divine_entry',
        name: 'Rainbow Divine Bridge',
        path: '$basePath/vip_6/entry.png',
        animatedPath: '$basePath/vip_6/entry.webm',
        category: 'Entry Effect',
      ),
      badge: const CosmeticAsset(
        id: 'rainbow_divine_badge',
        name: 'Rainbow Divine Badge',
        path: '$basePath/vip_6/badge.png',
        animatedPath: '$basePath/vip_6/badge_anim.webp',
        category: 'Badges',
      ),
      tag: const CosmeticAsset(
        id: 'rainbow_divine_tag',
        name: 'Rainbow Divine Tag',
        path: '$basePath/vip_6/tag.png',
        animatedPath: '$basePath/vip_6/tag_anim.webp',
        category: 'Tags',
      ),
      profileTheme: const CosmeticAsset(
        id: 'rainbow_divine_theme',
        name: 'Rainbow Divine Theme',
        path: '$basePath/vip_6/theme.json',
        animatedPath: '',
        category: 'Profile Theme',
      ),
      background: const CosmeticAsset(
        id: 'rainbow_divine_bg',
        name: 'Rainbow Divine Background',
        path: '$basePath/vip_6/bg.jpg',
        animatedPath: '',
        category: 'Background',
      ),
      gift: const CosmeticAsset(
        id: 'rainbow_divine_gift',
        name: 'Rainbow Divine Gift',
        path: '$basePath/vip_6/gift.png',
        animatedPath: '$basePath/vip_6/gift.webp',
        category: 'Gift Showcase',
      ),
      emojiPack: const CosmeticAsset(
        id: 'rainbow_divine_emojis',
        name: 'Rainbow Divine Emojis',
        path: '$basePath/vip_6/emojis/',
        animatedPath: '$basePath/vip_6/emojis_anim/',
        category: 'Emoji Pack',
      ),
      storePreview: const CosmeticAsset(
        id: 'rainbow_divine_preview',
        name: 'Rainbow Divine Preview',
        path: '$basePath/vip_6/preview.jpg',
        animatedPath: '',
        category: 'Store Preview',
      ),
      thumbnail: const CosmeticAsset(
        id: 'rainbow_divine_thumb',
        name: 'Rainbow Divine Thumbnail',
        path: '$basePath/vip_6/thumb.png',
        animatedPath: '',
        category: 'Thumbnail',
      ),
    ),

    CosmeticCollection(
      id: 'vip_7_royal_emperor',
      name: 'Royal Emperor Collection',
      tier: 'VIP',
      requiredLevel: 7,
      theme: 'Imperial gold dragon, obsidian plates, and volcanic glowing cracks',
      primaryColor: '#1C1917', // Onyx/Obsidian
      secondaryColor: '#D4AF37', // Imperial Gold
      accentColor: '#991B1B', // Crimson
      designElements: ['Gold Dragon scales', 'Obsidian Carvings', 'Volcanic Glow'],
      avatarFrame: const CosmeticAsset(
        id: 'royal_emperor_frame',
        name: 'Royal Emperor Frame',
        path: '$basePath/vip_7/frame.png',
        animatedPath: '$basePath/vip_7/frame.webp',
        category: 'Avatar Frame',
      ),
      chatBubble: const CosmeticAsset(
        id: 'royal_emperor_bubble',
        name: 'Royal Emperor Bubble',
        path: '$basePath/vip_7/bubble.png',
        animatedPath: '$basePath/vip_7/bubble_anim.webp',
        category: 'Chat Bubble',
      ),
      nameGlow: const CosmeticAsset(
        id: 'royal_emperor_name',
        name: 'Royal Emperor Glow',
        path: '$basePath/vip_7/name_glow.png',
        animatedPath: '$basePath/vip_7/name_glow.webp',
        category: 'Name Effect',
      ),
      avatarAura: const CosmeticAsset(
        id: 'royal_emperor_aura',
        name: 'Royal Emperor Aura',
        path: '$basePath/vip_7/aura.png',
        animatedPath: '$basePath/vip_7/aura.webp',
        category: 'Avatar Effect',
      ),
      entryEffect: const CosmeticAsset(
        id: 'royal_emperor_entry',
        name: 'Royal Emperor Throne Room',
        path: '$basePath/vip_7/entry.png',
        animatedPath: '$basePath/vip_7/entry.webm',
        category: 'Entry Effect',
      ),
      badge: const CosmeticAsset(
        id: 'royal_emperor_badge',
        name: 'Royal Emperor Badge',
        path: '$basePath/vip_7/badge.png',
        animatedPath: '$basePath/vip_7/badge_anim.webp',
        category: 'Badges',
      ),
      tag: const CosmeticAsset(
        id: 'royal_emperor_tag',
        name: 'Royal Emperor Tag',
        path: '$basePath/vip_7/tag.png',
        animatedPath: '$basePath/vip_7/tag_anim.webp',
        category: 'Tags',
      ),
      profileTheme: const CosmeticAsset(
        id: 'royal_emperor_theme',
        name: 'Royal Emperor Theme',
        path: '$basePath/vip_7/theme.json',
        animatedPath: '',
        category: 'Profile Theme',
      ),
      background: const CosmeticAsset(
        id: 'royal_emperor_bg',
        name: 'Royal Emperor Background',
        path: '$basePath/vip_7/bg.jpg',
        animatedPath: '',
        category: 'Background',
      ),
      gift: const CosmeticAsset(
        id: 'royal_emperor_gift',
        name: 'Royal Emperor Gift',
        path: '$basePath/vip_7/gift.png',
        animatedPath: '$basePath/vip_7/gift.webp',
        category: 'Gift Showcase',
      ),
      emojiPack: const CosmeticAsset(
        id: 'royal_emperor_emojis',
        name: 'Royal Emperor Emojis',
        path: '$basePath/vip_7/emojis/',
        animatedPath: '$basePath/vip_7/emojis_anim/',
        category: 'Emoji Pack',
      ),
      storePreview: const CosmeticAsset(
        id: 'royal_emperor_preview',
        name: 'Royal Emperor Preview',
        path: '$basePath/vip_7/preview.jpg',
        animatedPath: '',
        category: 'Store Preview',
      ),
      thumbnail: const CosmeticAsset(
        id: 'royal_emperor_thumb',
        name: 'Royal Emperor Thumbnail',
        path: '$basePath/vip_7/thumb.png',
        animatedPath: '',
        category: 'Thumbnail',
      ),
    ),

    // ==========================================
    // NOVEL COLLECTIONS (NOVEL II - VII)
    // ==========================================

    CosmeticCollection(
      id: 'novel_2_galaxy',
      name: 'Galaxy Collection',
      tier: 'Novel',
      requiredLevel: 2,
      theme: 'Nebula swirls, orbit rings, and starry constellation dust',
      primaryColor: '#3B0764', // Deep Purple
      secondaryColor: '#D946EF', // Nebula Pink
      accentColor: '#60A5FA', // Galaxy Blue
      designElements: ['Nebula Clouds', 'Orbits', 'Constellations', 'Stars'],
      avatarFrame: const CosmeticAsset(
        id: 'galaxy_frame',
        name: 'Galaxy Frame',
        path: '$basePath/novel_2/frame.png',
        animatedPath: '$basePath/novel_2/frame.webp',
        category: 'Avatar Frame',
      ),
      chatBubble: const CosmeticAsset(
        id: 'galaxy_bubble',
        name: 'Galaxy Bubble',
        path: '$basePath/novel_2/bubble.png',
        animatedPath: '$basePath/novel_2/bubble_anim.webp',
        category: 'Chat Bubble',
      ),
      nameGlow: const CosmeticAsset(
        id: 'galaxy_name',
        name: 'Galaxy Glow',
        path: '$basePath/novel_2/name_glow.png',
        animatedPath: '$basePath/novel_2/name_glow.webp',
        category: 'Name Effect',
      ),
      avatarAura: const CosmeticAsset(
        id: 'galaxy_aura',
        name: 'Galaxy Aura',
        path: '$basePath/novel_2/aura.png',
        animatedPath: '$basePath/novel_2/aura.webp',
        category: 'Avatar Effect',
      ),
      entryEffect: const CosmeticAsset(
        id: 'galaxy_entry',
        name: 'Galaxy Warp Effect',
        path: '$basePath/novel_2/entry.png',
        animatedPath: '$basePath/novel_2/entry.webm',
        category: 'Entry Effect',
      ),
      badge: const CosmeticAsset(
        id: 'galaxy_badge',
        name: 'Galaxy Badge',
        path: '$basePath/novel_2/badge.png',
        animatedPath: '$basePath/novel_2/badge_anim.webp',
        category: 'Badges',
      ),
      tag: const CosmeticAsset(
        id: 'galaxy_tag',
        name: 'Galaxy Tag',
        path: '$basePath/novel_2/tag.png',
        animatedPath: '$basePath/novel_2/tag_anim.webp',
        category: 'Tags',
      ),
      profileTheme: const CosmeticAsset(
        id: 'galaxy_theme',
        name: 'Galaxy Theme',
        path: '$basePath/novel_2/theme.json',
        animatedPath: '',
        category: 'Profile Theme',
      ),
      background: const CosmeticAsset(
        id: 'galaxy_bg',
        name: 'Galaxy Background',
        path: '$basePath/novel_2/bg.jpg',
        animatedPath: '',
        category: 'Background',
      ),
      gift: const CosmeticAsset(
        id: 'galaxy_gift',
        name: 'Galaxy Supernova Gift',
        path: '$basePath/novel_2/gift.png',
        animatedPath: '$basePath/novel_2/gift.webp',
        category: 'Gift Showcase',
      ),
      emojiPack: const CosmeticAsset(
        id: 'galaxy_emojis',
        name: 'Galaxy Emojis',
        path: '$basePath/novel_2/emojis/',
        animatedPath: '$basePath/novel_2/emojis_anim/',
        category: 'Emoji Pack',
      ),
      storePreview: const CosmeticAsset(
        id: 'galaxy_preview',
        name: 'Galaxy Preview',
        path: '$basePath/novel_2/preview.jpg',
        animatedPath: '',
        category: 'Store Preview',
      ),
      thumbnail: const CosmeticAsset(
        id: 'galaxy_thumb',
        name: 'Galaxy Thumbnail',
        path: '$basePath/novel_2/thumb.png',
        animatedPath: '',
        category: 'Thumbnail',
      ),
    ),

    CosmeticCollection(
      id: 'novel_3_royal_palace',
      name: 'Royal Palace Collection',
      tier: 'Novel',
      requiredLevel: 3,
      theme: 'Polished white marble arches, baroque gold ivy, and emerald gems',
      primaryColor: '#FCD34D', // Champagne Gold
      secondaryColor: '#065F46', // Emerald
      accentColor: '#F8FAFC', // Marble White
      designElements: ['Marble Arches', 'Baroque Gold Leaves', 'Emerald Gems'],
      avatarFrame: const CosmeticAsset(
        id: 'royal_palace_frame',
        name: 'Royal Palace Frame',
        path: '$basePath/novel_3/frame.png',
        animatedPath: '$basePath/novel_3/frame.webp',
        category: 'Avatar Frame',
      ),
      chatBubble: const CosmeticAsset(
        id: 'royal_palace_bubble',
        name: 'Royal Palace Bubble',
        path: '$basePath/novel_3/bubble.png',
        animatedPath: '$basePath/novel_3/bubble_anim.webp',
        category: 'Chat Bubble',
      ),
      nameGlow: const CosmeticAsset(
        id: 'royal_palace_name',
        name: 'Royal Palace Glow',
        path: '$basePath/novel_3/name_glow.png',
        animatedPath: '$basePath/novel_3/name_glow.webp',
        category: 'Name Effect',
      ),
      avatarAura: const CosmeticAsset(
        id: 'royal_palace_aura',
        name: 'Royal Palace Aura',
        path: '$basePath/novel_3/aura.png',
        animatedPath: '$basePath/novel_3/aura.webp',
        category: 'Avatar Effect',
      ),
      entryEffect: const CosmeticAsset(
        id: 'royal_palace_entry',
        name: 'Royal Palace Gate Entrance',
        path: '$basePath/novel_3/entry.png',
        animatedPath: '$basePath/novel_3/entry.webm',
        category: 'Entry Effect',
      ),
      badge: const CosmeticAsset(
        id: 'royal_palace_badge',
        name: 'Royal Palace Badge',
        path: '$basePath/novel_3/badge.png',
        animatedPath: '$basePath/novel_3/badge_anim.webp',
        category: 'Badges',
      ),
      tag: const CosmeticAsset(
        id: 'royal_palace_tag',
        name: 'Royal Palace Tag',
        path: '$basePath/novel_3/tag.png',
        animatedPath: '$basePath/novel_3/tag_anim.webp',
        category: 'Tags',
      ),
      profileTheme: const CosmeticAsset(
        id: 'royal_palace_theme',
        name: 'Royal Palace Theme',
        path: '$basePath/novel_3/theme.json',
        animatedPath: '',
        category: 'Profile Theme',
      ),
      background: const CosmeticAsset(
        id: 'royal_palace_bg',
        name: 'Royal Palace Background',
        path: '$basePath/novel_3/bg.jpg',
        animatedPath: '',
        category: 'Background',
      ),
      gift: const CosmeticAsset(
        id: 'royal_palace_gift',
        name: 'Royal Palace Carriage',
        path: '$basePath/novel_3/gift.png',
        animatedPath: '$basePath/novel_3/gift.webp',
        category: 'Gift Showcase',
      ),
      emojiPack: const CosmeticAsset(
        id: 'royal_palace_emojis',
        name: 'Royal Palace Emojis',
        path: '$basePath/novel_3/emojis/',
        animatedPath: '$basePath/novel_3/emojis_anim/',
        category: 'Emoji Pack',
      ),
      storePreview: const CosmeticAsset(
        id: 'royal_palace_preview',
        name: 'Royal Palace Preview',
        path: '$basePath/novel_3/preview.jpg',
        animatedPath: '',
        category: 'Store Preview',
      ),
      thumbnail: const CosmeticAsset(
        id: 'royal_palace_thumb',
        name: 'Royal Palace Thumbnail',
        path: '$basePath/novel_3/thumb.png',
        animatedPath: '',
        category: 'Thumbnail',
      ),
    ),

    CosmeticCollection(
      id: 'novel_4_dragon',
      name: 'Dragon Collection',
      tier: 'Novel',
      requiredLevel: 4,
      theme: 'Crimson scales, obsidian wings, and glowing lava rivers',
      primaryColor: '#DC2626', // Crimson Red
      secondaryColor: '#F97316', // Molten Orange
      accentColor: '#09090B', // Obsidian Black
      designElements: ['Obsidian Dragon Wings', 'Lava Cracks', 'Scale Patterns'],
      avatarFrame: const CosmeticAsset(
        id: 'dragon_frame',
        name: 'Dragon Frame',
        path: '$basePath/novel_4/frame.png',
        animatedPath: '$basePath/novel_4/frame.webp',
        category: 'Avatar Frame',
      ),
      chatBubble: const CosmeticAsset(
        id: 'dragon_bubble',
        name: 'Dragon Bubble',
        path: '$basePath/novel_4/bubble.png',
        animatedPath: '$basePath/novel_4/bubble_anim.webp',
        category: 'Chat Bubble',
      ),
      nameGlow: const CosmeticAsset(
        id: 'dragon_name',
        name: 'Dragon Glow',
        path: '$basePath/novel_4/name_glow.png',
        animatedPath: '$basePath/novel_4/name_glow.webp',
        category: 'Name Effect',
      ),
      avatarAura: const CosmeticAsset(
        id: 'dragon_aura',
        name: 'Dragon Aura',
        path: '$basePath/novel_4/aura.png',
        animatedPath: '$basePath/novel_4/aura.webp',
        category: 'Avatar Effect',
      ),
      entryEffect: const CosmeticAsset(
        id: 'dragon_entry',
        name: 'Dragon Flight Arrival',
        path: '$basePath/novel_4/entry.png',
        animatedPath: '$basePath/novel_4/entry.webm',
        category: 'Entry Effect',
      ),
      badge: const CosmeticAsset(
        id: 'dragon_badge',
        name: 'Dragon Badge',
        path: '$basePath/novel_4/badge.png',
        animatedPath: '$basePath/novel_4/badge_anim.webp',
        category: 'Badges',
      ),
      tag: const CosmeticAsset(
        id: 'dragon_tag',
        name: 'Dragon Tag',
        path: '$basePath/novel_4/tag.png',
        animatedPath: '$basePath/novel_4/tag_anim.webp',
        category: 'Tags',
      ),
      profileTheme: const CosmeticAsset(
        id: 'dragon_theme',
        name: 'Dragon Theme',
        path: '$basePath/novel_4/theme.json',
        animatedPath: '',
        category: 'Profile Theme',
      ),
      background: const CosmeticAsset(
        id: 'dragon_bg',
        name: 'Dragon Background',
        path: '$basePath/novel_4/bg.jpg',
        animatedPath: '',
        category: 'Background',
      ),
      gift: const CosmeticAsset(
        id: 'dragon_gift',
        name: 'Dragon Flame Gift',
        path: '$basePath/novel_4/gift.png',
        animatedPath: '$basePath/novel_4/gift.webp',
        category: 'Gift Showcase',
      ),
      emojiPack: const CosmeticAsset(
        id: 'dragon_emojis',
        name: 'Dragon Emojis',
        path: '$basePath/novel_4/emojis/',
        animatedPath: '$basePath/novel_4/emojis_anim/',
        category: 'Emoji Pack',
      ),
      storePreview: const CosmeticAsset(
        id: 'dragon_preview',
        name: 'Dragon Preview',
        path: '$basePath/novel_4/preview.jpg',
        animatedPath: '',
        category: 'Store Preview',
      ),
      thumbnail: const CosmeticAsset(
        id: 'dragon_thumb',
        name: 'Dragon Thumbnail',
        path: '$basePath/novel_4/thumb.png',
        animatedPath: '',
        category: 'Thumbnail',
      ),
    ),

    CosmeticCollection(
      id: 'novel_5_phoenix',
      name: 'Phoenix Collection',
      tier: 'Novel',
      requiredLevel: 5,
      theme: 'Glowing golden feathers, solar sweeps, and deep purple dust',
      primaryColor: '#EA580C', // Phoenix Orange
      secondaryColor: '#4C1D95', // Purple
      accentColor: '#FACC15', // Solar Yellow
      designElements: ['Phoenix Feathers', 'Solar Eclipse Arc', 'Flame Embers'],
      avatarFrame: const CosmeticAsset(
        id: 'phoenix_frame',
        name: 'Phoenix Frame',
        path: '$basePath/novel_5/frame.png',
        animatedPath: '$basePath/novel_5/frame.webp',
        category: 'Avatar Frame',
      ),
      chatBubble: const CosmeticAsset(
        id: 'phoenix_bubble',
        name: 'Phoenix Bubble',
        path: '$basePath/novel_5/bubble.png',
        animatedPath: '$basePath/novel_5/bubble_anim.webp',
        category: 'Chat Bubble',
      ),
      nameGlow: const CosmeticAsset(
        id: 'phoenix_name',
        name: 'Phoenix Glow',
        path: '$basePath/novel_5/name_glow.png',
        animatedPath: '$basePath/novel_5/name_glow.webp',
        category: 'Name Effect',
      ),
      avatarAura: const CosmeticAsset(
        id: 'phoenix_aura',
        name: 'Phoenix Aura',
        path: '$basePath/novel_5/aura.png',
        animatedPath: '$basePath/novel_5/aura.webp',
        category: 'Avatar Effect',
      ),
      entryEffect: const CosmeticAsset(
        id: 'phoenix_entry',
        name: 'Phoenix Rebirth Entrance',
        path: '$basePath/novel_5/entry.png',
        animatedPath: '$basePath/novel_5/entry.webm',
        category: 'Entry Effect',
      ),
      badge: const CosmeticAsset(
        id: 'phoenix_badge',
        name: 'Phoenix Badge',
        path: '$basePath/novel_5/badge.png',
        animatedPath: '$basePath/novel_5/badge_anim.webp',
        category: 'Badges',
      ),
      tag: const CosmeticAsset(
        id: 'phoenix_tag',
        name: 'Phoenix Tag',
        path: '$basePath/novel_5/tag.png',
        animatedPath: '$basePath/novel_5/tag_anim.webp',
        category: 'Tags',
      ),
      profileTheme: const CosmeticAsset(
        id: 'phoenix_theme',
        name: 'Phoenix Theme',
        path: '$basePath/novel_5/theme.json',
        animatedPath: '',
        category: 'Profile Theme',
      ),
      background: const CosmeticAsset(
        id: 'phoenix_bg',
        name: 'Phoenix Background',
        path: '$basePath/novel_5/bg.jpg',
        animatedPath: '',
        category: 'Background',
      ),
      gift: const CosmeticAsset(
        id: 'phoenix_gift',
        name: 'Phoenix Rise Gift',
        path: '$basePath/novel_5/gift.png',
        animatedPath: '$basePath/novel_5/gift.webp',
        category: 'Gift Showcase',
      ),
      emojiPack: const CosmeticAsset(
        id: 'phoenix_emojis',
        name: 'Phoenix Emojis',
        path: '$basePath/novel_5/emojis/',
        animatedPath: '$basePath/novel_5/emojis_anim/',
        category: 'Emoji Pack',
      ),
      storePreview: const CosmeticAsset(
        id: 'phoenix_preview',
        name: 'Phoenix Preview',
        path: '$basePath/novel_5/preview.jpg',
        animatedPath: '',
        category: 'Store Preview',
      ),
      thumbnail: const CosmeticAsset(
        id: 'phoenix_thumb',
        name: 'Phoenix Thumbnail',
        path: '$basePath/novel_5/thumb.png',
        animatedPath: '',
        category: 'Thumbnail',
      ),
    ),

    CosmeticCollection(
      id: 'novel_6_celestial',
      name: 'Celestial Collection',
      tier: 'Novel',
      requiredLevel: 6,
      theme: 'Platinum wings, holy light beams, and cosmic celestial gates',
      primaryColor: '#F1F5F9', // Platinum White
      secondaryColor: '#60A5FA', // Pearlescent Blue
      accentColor: '#312E81', // Celestial Indigo
      designElements: ['Platinum Angel Wings', 'Star Glints', 'Temple Arches'],
      avatarFrame: const CosmeticAsset(
        id: 'celestial_frame',
        name: 'Celestial Frame',
        path: '$basePath/novel_6/frame.png',
        animatedPath: '$basePath/novel_6/frame.webp',
        category: 'Avatar Frame',
      ),
      chatBubble: const CosmeticAsset(
        id: 'celestial_bubble',
        name: 'Celestial Bubble',
        path: '$basePath/novel_6/bubble.png',
        animatedPath: '$basePath/novel_6/bubble_anim.webp',
        category: 'Chat Bubble',
      ),
      nameGlow: const CosmeticAsset(
        id: 'celestial_name',
        name: 'Celestial Glow',
        path: '$basePath/novel_6/name_glow.png',
        animatedPath: '$basePath/novel_6/name_glow.webp',
        category: 'Name Effect',
      ),
      avatarAura: const CosmeticAsset(
        id: 'celestial_aura',
        name: 'Celestial Aura',
        path: '$basePath/novel_6/aura.png',
        animatedPath: '$basePath/novel_6/aura.webp',
        category: 'Avatar Effect',
      ),
      entryEffect: const CosmeticAsset(
        id: 'celestial_entry',
        name: 'Celestial Portal Arrival',
        path: '$basePath/novel_6/entry.png',
        animatedPath: '$basePath/novel_6/entry.webm',
        category: 'Entry Effect',
      ),
      badge: const CosmeticAsset(
        id: 'celestial_badge',
        name: 'Celestial Badge',
        path: '$basePath/novel_6/badge.png',
        animatedPath: '$basePath/novel_6/badge_anim.webp',
        category: 'Badges',
      ),
      tag: const CosmeticAsset(
        id: 'celestial_tag',
        name: 'Celestial Tag',
        path: '$basePath/novel_6/tag.png',
        animatedPath: '$basePath/novel_6/tag_anim.webp',
        category: 'Tags',
      ),
      profileTheme: const CosmeticAsset(
        id: 'celestial_theme',
        name: 'Celestial Theme',
        path: '$basePath/novel_6/theme.json',
        animatedPath: '',
        category: 'Profile Theme',
      ),
      background: const CosmeticAsset(
        id: 'celestial_bg',
        name: 'Celestial Background',
        path: '$basePath/novel_6/bg.jpg',
        animatedPath: '',
        category: 'Background',
      ),
      gift: const CosmeticAsset(
        id: 'celestial_gift',
        name: 'Celestial Harp Gift',
        path: '$basePath/novel_6/gift.png',
        animatedPath: '$basePath/novel_6/gift.webp',
        category: 'Gift Showcase',
      ),
      emojiPack: const CosmeticAsset(
        id: 'celestial_emojis',
        name: 'Celestial Emojis',
        path: '$basePath/novel_6/emojis/',
        animatedPath: '$basePath/novel_6/emojis_anim/',
        category: 'Emoji Pack',
      ),
      storePreview: const CosmeticAsset(
        id: 'celestial_preview',
        name: 'Celestial Preview',
        path: '$basePath/novel_6/preview.jpg',
        animatedPath: '',
        category: 'Store Preview',
      ),
      thumbnail: const CosmeticAsset(
        id: 'celestial_thumb',
        name: 'Celestial Thumbnail',
        path: '$basePath/novel_6/thumb.png',
        animatedPath: '',
        category: 'Thumbnail',
      ),
    ),

    CosmeticCollection(
      id: 'novel_7_cosmic_emperor',
      name: 'Cosmic Emperor Collection',
      tier: 'Novel',
      requiredLevel: 7,
      theme: 'Primordial cosmic void, star constellations, and black hole portals',
      primaryColor: '#030712', // Space Void Black
      secondaryColor: '#F59E0B', // Constellation Gold
      accentColor: '#1E1B4B', // Void Indigo
      designElements: ['Rotating Void', 'Constellation Lines', 'Golden Supernovas'],
      avatarFrame: const CosmeticAsset(
        id: 'cosmic_emperor_frame',
        name: 'Cosmic Emperor Frame',
        path: '$basePath/novel_7/frame.png',
        animatedPath: '$basePath/novel_7/frame.webp',
        category: 'Avatar Frame',
      ),
      chatBubble: const CosmeticAsset(
        id: 'cosmic_emperor_bubble',
        name: 'Cosmic Emperor Bubble',
        path: '$basePath/novel_7/bubble.png',
        animatedPath: '$basePath/novel_7/bubble_anim.webp',
        category: 'Chat Bubble',
      ),
      nameGlow: const CosmeticAsset(
        id: 'cosmic_emperor_name',
        name: 'Cosmic Emperor Glow',
        path: '$basePath/novel_7/name_glow.png',
        animatedPath: '$basePath/novel_7/name_glow.webp',
        category: 'Name Effect',
      ),
      avatarAura: const CosmeticAsset(
        id: 'cosmic_emperor_aura',
        name: 'Cosmic Emperor Aura',
        path: '$basePath/novel_7/aura.png',
        animatedPath: '$basePath/novel_7/aura.webp',
        category: 'Avatar Effect',
      ),
      entryEffect: const CosmeticAsset(
        id: 'cosmic_emperor_entry',
        name: 'Cosmic Rift Portal',
        path: '$basePath/novel_7/entry.png',
        animatedPath: '$basePath/novel_7/entry.webm',
        category: 'Entry Effect',
      ),
      badge: const CosmeticAsset(
        id: 'cosmic_emperor_badge',
        name: 'Cosmic Emperor Badge',
        path: '$basePath/novel_7/badge.png',
        animatedPath: '$basePath/novel_7/badge_anim.webp',
        category: 'Badges',
      ),
      tag: const CosmeticAsset(
        id: 'cosmic_emperor_tag',
        name: 'Cosmic Emperor Tag',
        path: '$basePath/novel_7/tag.png',
        animatedPath: '$basePath/novel_7/tag_anim.webp',
        category: 'Tags',
      ),
      profileTheme: const CosmeticAsset(
        id: 'cosmic_emperor_theme',
        name: 'Cosmic Emperor Theme',
        path: '$basePath/novel_7/theme.json',
        animatedPath: '',
        category: 'Profile Theme',
      ),
      background: const CosmeticAsset(
        id: 'cosmic_emperor_bg',
        name: 'Cosmic Emperor Background',
        path: '$basePath/novel_7/bg.jpg',
        animatedPath: '',
        category: 'Background',
      ),
      gift: const CosmeticAsset(
        id: 'cosmic_emperor_gift',
        name: 'Cosmic Emperor Star Gate',
        path: '$basePath/novel_7/gift.png',
        animatedPath: '$basePath/novel_7/gift.webp',
        category: 'Gift Showcase',
      ),
      emojiPack: const CosmeticAsset(
        id: 'cosmic_emperor_emojis',
        name: 'Cosmic Emperor Emojis',
        path: '$basePath/novel_7/emojis/',
        animatedPath: '$basePath/novel_7/emojis_anim/',
        category: 'Emoji Pack',
      ),
      storePreview: const CosmeticAsset(
        id: 'cosmic_emperor_preview',
        name: 'Cosmic Emperor Preview',
        path: '$basePath/novel_7/preview.jpg',
        animatedPath: '',
        category: 'Store Preview',
      ),
      thumbnail: const CosmeticAsset(
        id: 'cosmic_emperor_thumb',
        name: 'Cosmic Emperor Thumbnail',
        path: '$basePath/novel_7/thumb.png',
        animatedPath: '',
        category: 'Thumbnail',
      ),
    ),

    CosmeticCollection(
      id: 'novel_8_starlight_seraph',
      name: 'Starlight Seraph Collection',
      tier: 'Novel',
      requiredLevel: 8,
      theme: 'Winged celestial halo, silver stardust, and a radiant cosmic sky',
      primaryColor: '#EDE9FE', // Starlight White
      secondaryColor: '#6366F1', // Seraph Blue
      accentColor: '#C7D2FE', // Cloud Silver
      designElements: ['Winged Halo', 'Star Trails', 'Astral Glow', 'Floating Clouds'],
      avatarFrame: const CosmeticAsset(
        id: 'starlight_seraph_frame',
        name: 'Starlight Seraph Frame',
        path: '$basePath/novel_8/frame.png',
        animatedPath: '$basePath/novel_8/frame.webp',
        category: 'Avatar Frame',
      ),
      chatBubble: const CosmeticAsset(
        id: 'starlight_seraph_bubble',
        name: 'Starlight Seraph Bubble',
        path: '$basePath/novel_8/bubble.png',
        animatedPath: '$basePath/novel_8/bubble_anim.webp',
        category: 'Chat Bubble',
      ),
      nameGlow: const CosmeticAsset(
        id: 'starlight_seraph_name',
        name: 'Starlight Seraph Glow',
        path: '$basePath/novel_8/name_glow.png',
        animatedPath: '$basePath/novel_8/name_glow.webp',
        category: 'Name Effect',
      ),
      avatarAura: const CosmeticAsset(
        id: 'starlight_seraph_aura',
        name: 'Starlight Seraph Aura',
        path: '$basePath/novel_8/aura.png',
        animatedPath: '$basePath/novel_8/aura.webp',
        category: 'Avatar Effect',
      ),
      entryEffect: const CosmeticAsset(
        id: 'starlight_seraph_entry',
        name: 'Starlight Seraph Arrival',
        path: '$basePath/novel_8/entry.png',
        animatedPath: '$basePath/novel_8/entry.webm',
        category: 'Entry Effect',
      ),
      badge: const CosmeticAsset(
        id: 'starlight_seraph_badge',
        name: 'Starlight Seraph Badge',
        path: '$basePath/novel_8/badge.png',
        animatedPath: '$basePath/novel_8/badge_anim.webp',
        category: 'Badges',
      ),
      tag: const CosmeticAsset(
        id: 'starlight_seraph_tag',
        name: 'Starlight Seraph Tag',
        path: '$basePath/novel_8/tag.png',
        animatedPath: '$basePath/novel_8/tag_anim.webp',
        category: 'Tags',
      ),
      profileTheme: const CosmeticAsset(
        id: 'starlight_seraph_theme',
        name: 'Starlight Seraph Theme',
        path: '$basePath/novel_8/theme.json',
        animatedPath: '',
        category: 'Profile Theme',
      ),
      background: const CosmeticAsset(
        id: 'starlight_seraph_bg',
        name: 'Starlight Seraph Background',
        path: '$basePath/novel_8/bg.jpg',
        animatedPath: '',
        category: 'Background',
      ),
      gift: const CosmeticAsset(
        id: 'starlight_seraph_gift',
        name: 'Starlight Seraph Gift',
        path: '$basePath/novel_8/gift.png',
        animatedPath: '$basePath/novel_8/gift.webp',
        category: 'Gift Showcase',
      ),
      emojiPack: const CosmeticAsset(
        id: 'starlight_seraph_emojis',
        name: 'Starlight Seraph Emojis',
        path: '$basePath/novel_8/emojis/',
        animatedPath: '$basePath/novel_8/emojis_anim/',
        category: 'Emoji Pack',
      ),
      storePreview: const CosmeticAsset(
        id: 'starlight_seraph_preview',
        name: 'Starlight Seraph Preview',
        path: '$basePath/novel_8/preview.jpg',
        animatedPath: '',
        category: 'Store Preview',
      ),
      thumbnail: const CosmeticAsset(
        id: 'starlight_seraph_thumb',
        name: 'Starlight Seraph Thumbnail',
        path: '$basePath/novel_8/thumb.png',
        animatedPath: '',
        category: 'Thumbnail',
      ),
    ),
  ];

  static CosmeticCollection? getCollectionById(String id) {
    try {
      return collections.firstWhere((col) => col.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<CosmeticCollection> getcollectionsByTier(String tier) {
    return collections.where((col) => col.tier == tier).toList();
  }
}
