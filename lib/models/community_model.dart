class Community {

  Community({
    required this.id,
    required this.name,
    required this.description,
    this.image,
    this.banner,
    required this.category,
    required this.type,
    required this.owner,
    required this.admins,
    required this.members,
    required this.memberCount,
    required this.isVerified,
    this.price,
    required this.createdAt,
  });

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      image: json['image'],
      banner: json['banner'],
      category: json['category'] ?? '',
      type: json['type'] ?? 'public',
      owner: json['owner'] ?? '',
      admins: List<String>.from(json['admins'] ?? []),
      members: List<String>.from(json['members'] ?? []),
      memberCount: json['memberCount'] ?? 0,
      isVerified: json['isVerified'] ?? false,
      price: json['price']?.toDouble(),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
  final String id;
  final String name;
  final String description;
  final String? image;
  final String? banner;
  final String category;
  final String type; // public, private, paid
  final String owner;
  final List<String> admins;
  final List<String> members;
  final int memberCount;
  final bool isVerified;
  final double? price; // for paid communities
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'image': image,
    'banner': banner,
    'category': category,
    'type': type,
    'owner': owner,
    'admins': admins,
    'members': members,
    'memberCount': memberCount,
    'isVerified': isVerified,
    'price': price,
    'createdAt': createdAt.toIso8601String(),
  };
}
