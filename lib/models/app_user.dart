class AppUser {
  final String id;
  final String email;
  final String username;
  final String? displayName;
  final String? bio;
  final String? profilePicUrl;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.email,
    required this.username,
    this.displayName,
    this.bio,
    this.profilePicUrl,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
      bio: json['bio'] as String?,
      profilePicUrl: json['profile_pic_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'display_name': displayName,
      'bio': bio,
      'profile_pic_url': profilePicUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}