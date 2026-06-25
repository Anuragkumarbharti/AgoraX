class User {

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    this.avatar,
    this.coverPhoto,
    this.bio,
    required this.interests,
    required this.communities,
    required this.followers,
    required this.following,
    required this.isVerified,
    required this.isPremium,
    required this.reputation,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      avatar: json['avatar'],
      coverPhoto: json['coverPhoto'],
      bio: json['bio'],
      interests: List<String>.from(json['interests'] ?? []),
      communities: List<String>.from(json['communities'] ?? []),
      followers: json['followers'] ?? 0,
      following: json['following'] ?? 0,
      isVerified: json['isVerified'] ?? false,
      isPremium: json['isPremium'] ?? false,
      reputation: json['reputation'] ?? 0,
    );
  }
  final String id;
  final String username;
  final String email;
  final String displayName;
  final String? avatar;
  final String? coverPhoto;
  final String? bio;
  final List<String> interests;
  final List<String> communities;
  final int followers;
  final int following;
  final bool isVerified;
  final bool isPremium;
  final int reputation;

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'displayName': displayName,
    'avatar': avatar,
    'coverPhoto': coverPhoto,
    'bio': bio,
    'interests': interests,
    'communities': communities,
    'followers': followers,
    'following': following,
    'isVerified': isVerified,
    'isPremium': isPremium,
    'reputation': reputation,
  };
}
