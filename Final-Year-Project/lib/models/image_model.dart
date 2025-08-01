class ImageModel {
  final int id;
  final int albumId;
  final int userId;
  final String fileName;
  final String s3Url;
  final String status;
  final bool duplicate;
  final DateTime uploadedAt;

  ImageModel({
    required this.id,
    required this.albumId,
    required this.userId,
    required this.fileName,
    required this.s3Url,
    required this.status,
    required this.duplicate,
    required this.uploadedAt,
  });

  factory ImageModel.fromJson(Map<String, dynamic> json) {
    return ImageModel(
      id: json['id'],
      albumId: json['album_id'],
      userId: json['user_id'],
      fileName: json['file_name'],
      s3Url: json['s3_url'],
      status: json['status'],
      duplicate: json['duplicate'],
      uploadedAt: DateTime.parse(json['uploaded_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'album_id': albumId,
      'user_id': userId,
      'file_name': fileName,
      's3_url': s3Url,
      'status':status,
      'duplicate':duplicate,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }
}
