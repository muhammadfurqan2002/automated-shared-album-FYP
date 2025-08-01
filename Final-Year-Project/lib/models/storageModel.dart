class StorageUsage {
  final int totalImages;
  final int totalAlbums;
  final double memoryUsedMB;

  StorageUsage({
    required this.totalImages,
    required this.totalAlbums,
    required this.memoryUsedMB,
  });

  factory StorageUsage.fromJson(Map<String, dynamic> json) {
    return StorageUsage(
      totalImages: json['totalImages'] ?? 0,
      totalAlbums: json['totalAlbums'] ?? 0,
      memoryUsedMB: (json['memoryUsedMB'] as num).toDouble(),
    );
  }
}
