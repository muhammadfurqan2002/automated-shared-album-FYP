class User {
  final String email;
  final String username;
  final String? profileImageUrl;
  final String? password;
  final bool isVerified;
  final DateTime? imageUpdated; // <-- Added

  User({
    required this.email,
    required this.username,
    this.profileImageUrl,
    this.password,
    this.isVerified = false,
    this.imageUpdated, // <-- Added
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json["email"],
      username: json["username"],
      profileImageUrl: json["profileImageUrl"],
      isVerified: json["isVerified"] ?? false,
      imageUpdated: json["imageUpdated"] != null
          ? DateTime.tryParse(json["imageUpdated"])
          : null, // <-- Added
    );
  }

  Map<String, dynamic> toJson() {
    final data = {
      "email": email,
      "username": username,
      "profileImageUrl": profileImageUrl,
      "isVerified": isVerified,
      "imageUpdated": imageUpdated?.toIso8601String(), // <-- Added
    };
    if (password != null) {
      data["password"] = password;
    }
    return data;
  }

  User copyWith({
    String? email,
    String? username,
    String? profileImageUrl,
    String? password,
    bool? isVerified,
    DateTime? imageUpdated,
  }) {
    return User(
      email: email ?? this.email,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      password: password ?? this.password,
      isVerified: isVerified ?? this.isVerified,
      imageUpdated: imageUpdated ?? this.imageUpdated, // <-- Added
    );
  }
}
