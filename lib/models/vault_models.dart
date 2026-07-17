// lib/models/vault_models.dart

class VaultItem {
  final String id;
  final String assetId;
  final String category;
  final String subCategory;
  final String displayName;
  final String? shortDescription;
  final String? longDescription;
  final String? thumbnailUrl;
  final String? animationUrl;
  final String? previewUrl;
  final String rarity;
  final int quantity;
  final String status;
  final String? purchaseSource;
  final DateTime purchaseDate;
  final DateTime? expiresAt;
  final DateTime? activatedAt;
  final bool isEquipped;
  final DateTime? lastEquippedAt;
  final Map<String, dynamic> customMetadata;
  final bool tradable;
  final bool giftable;
  final bool stackable;
  final bool consumable;
  final bool permanent;
  final int? durationSeconds;

  VaultItem({
    required this.id,
    required this.assetId,
    required this.category,
    required this.subCategory,
    required this.displayName,
    this.shortDescription,
    this.longDescription,
    this.thumbnailUrl,
    this.animationUrl,
    this.previewUrl,
    required this.rarity,
    required this.quantity,
    required this.status,
    this.purchaseSource,
    required this.purchaseDate,
    this.expiresAt,
    this.activatedAt,
    required this.isEquipped,
    this.lastEquippedAt,
    required this.customMetadata,
    required this.tradable,
    required this.giftable,
    required this.stackable,
    required this.consumable,
    required this.permanent,
    this.durationSeconds,
  });

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id'] ?? '',
      assetId: json['asset_id'] ?? '',
      category: json['category'] ?? 'Cosmetics',
      subCategory: json['sub_category'] ?? 'avatar_frame',
      displayName: json['display_name'] ?? '',
      shortDescription: json['short_description'],
      longDescription: json['long_description'],
      thumbnailUrl: json['thumbnail_url'],
      animationUrl: json['animation_url'],
      previewUrl: json['preview_url'],
      rarity: json['rarity'] ?? 'Common',
      quantity: json['quantity'] ?? 1,
      status: json['status'] ?? 'Unlocked',
      purchaseSource: json['purchase_source'],
      purchaseDate: json['purchase_date'] != null
          ? DateTime.parse(json['purchase_date'].toString())
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      activatedAt: json['activated_at'] != null
          ? DateTime.tryParse(json['activated_at'].toString())
          : null,
      isEquipped: json['is_equipped'] ?? false,
      lastEquippedAt: json['last_equipped_at'] != null
          ? DateTime.tryParse(json['last_equipped_at'].toString())
          : null,
      customMetadata: json['custom_metadata'] is Map
          ? Map<String, dynamic>.from(json['custom_metadata'])
          : {},
      tradable: json['tradable'] ?? false,
      giftable: json['giftable'] ?? true,
      stackable: json['stackable'] ?? true,
      consumable: json['consumable'] ?? false,
      permanent: json['permanent'] ?? true,
      durationSeconds: json['duration_seconds'] != null
          ? int.tryParse(json['duration_seconds'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'asset_id': assetId,
      'category': category,
      'sub_category': subCategory,
      'display_name': displayName,
      'short_description': shortDescription,
      'long_description': longDescription,
      'thumbnail_url': thumbnailUrl,
      'animation_url': animationUrl,
      'preview_url': previewUrl,
      'rarity': rarity,
      'quantity': quantity,
      'status': status,
      'purchase_source': purchaseSource,
      'purchase_date': purchaseDate.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'activated_at': activatedAt?.toIso8601String(),
      'is_equipped': isEquipped,
      'last_equipped_at': lastEquippedAt?.toIso8601String(),
      'custom_metadata': customMetadata,
      'tradable': tradable,
      'giftable': giftable,
      'stackable': stackable,
      'consumable': consumable,
      'permanent': permanent,
      'duration_seconds': durationSeconds,
    };
  }

  // Helper getter to calculate remaining duration
  Duration? get remainingDuration {
    if (permanent || expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}

class VaultHistoryEntry {
  final String id;
  final String actionType;
  final int quantity;
  final Map<String, dynamic> details;
  final DateTime createdAt;
  final String assetName;
  final String? thumbnailUrl;
  final String rarity;

  VaultHistoryEntry({
    required this.id,
    required this.actionType,
    required this.quantity,
    required this.details,
    required this.createdAt,
    required this.assetName,
    this.thumbnailUrl,
    required this.rarity,
  });

  factory VaultHistoryEntry.fromJson(Map<String, dynamic> json) {
    return VaultHistoryEntry(
      id: json['id'] ?? '',
      actionType: json['action_type'] ?? 'Received',
      quantity: json['quantity'] ?? 1,
      details: json['details'] is Map ? Map<String, dynamic>.from(json['details']) : {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      assetName: json['asset_name'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      rarity: json['rarity'] ?? 'Common',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action_type': actionType,
      'quantity': quantity,
      'details': details,
      'created_at': createdAt.toIso8601String(),
      'asset_name': assetName,
      'thumbnail_url': thumbnailUrl,
      'rarity': rarity,
    };
  }
}
