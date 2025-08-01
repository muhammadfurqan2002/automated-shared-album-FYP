class ReelModel {
  final List<String> captions;
  final List<String> images;

  const ReelModel({
    required this.captions,
    required this.images,
  });

  // Optional: factory to parse from JSON
  factory ReelModel.fromJson(Map<String, dynamic> json) {
    return ReelModel(
      captions: List<String>.from(json['captions']),
      images: List<String>.from(json['images']),
    );
  }
}
