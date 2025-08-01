import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageSlideshow extends StatelessWidget {
  final List<String> images;
  final int currentIndex;
  static const String prefixUrl = 'https://ik.imagekit.io//tr:w-500,h-400,fo-auto,e-sharpen/';

  const ImageSlideshow({Key? key, required this.images, required this.currentIndex}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imageUrl = prefixUrl + images[currentIndex];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: CachedNetworkImage(
        key: ValueKey<int>(currentIndex),
        imageUrl: imageUrl,
        fit: BoxFit.fill,
        width: 500.0,
        height: 400.0,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.error_outline, color: Colors.red),
        ),
      ),
    );
  }
}
