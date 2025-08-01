
class Album {
  final int id;
  final int userId;
  late final String albumTitle;
  late final String coverImageUrl;
  final DateTime createdAt;

  Album({
    required this.id,
    required this.userId,
    required this.albumTitle,
    required this.coverImageUrl,
    required this.createdAt,
  });

  // Creates a new Album by overriding only the fields you pass in.
  Album copyWith({
    String? albumTitle,
    String? coverImageUrl,
    // you could add other overrides here if needed
  }) {
    return Album(
      id: id,
      userId: userId,
      albumTitle: albumTitle ?? this.albumTitle,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      createdAt: createdAt,
    );
  }

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'],
      userId: json['user_id'],
      albumTitle: json['album_title'],
      coverImageUrl: json['cover_image_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'album_title': albumTitle,
      'cover_image_url': coverImageUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
