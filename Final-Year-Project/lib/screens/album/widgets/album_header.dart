import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fyp/models/album_model.dart';

class AlbumHeader extends StatelessWidget {
  final Album album;

  const AlbumHeader({Key? key, required this.album}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Background cover image
        _buildBackgroundImage(),
        // Foreground album cover
        _buildForegroundAlbumCover(),
      ],
    );
  }

  Widget _buildBackgroundImage() {
    return SizedBox(
      width: double.infinity,
      height: 260,
      child: CachedNetworkImage(
        imageUrl: album.coverImageUrl,
        fit: BoxFit.cover,
        memCacheWidth: 800, // Optimize memory usage
        memCacheHeight: 520, // Maintain aspect ratio
        placeholder: (context, url) => _buildImagePlaceholder(
          width: double.infinity,
          height: 260,
          showShimmer: true,
        ),
        errorWidget: (context, url, error) => _buildErrorWidget(
          width: double.infinity,
          height: 260,
        ),
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 100),
      ),
    );
  }

  Widget _buildForegroundAlbumCover() {
    return Positioned(
      bottom: -90,
      child: Container(
        width: 160,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Hero(
          tag: 'album_cover_${album.id}', // Add Hero animation
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: album.coverImageUrl,
              fit: BoxFit.cover,
              memCacheWidth: 320, // 2x for high DPI
              memCacheHeight: 440,
              placeholder: (context, url) => _buildImagePlaceholder(
                width: 160,
                height: 220,
              ),
              errorWidget: (context, url, error) => _buildErrorWidget(
                width: 160,
                height: 220,
              ),
              fadeInDuration: const Duration(milliseconds: 200),
              fadeOutDuration: const Duration(milliseconds: 100),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder({
    required double width,
    required double height,
    bool showShimmer = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: width == 160 ? BorderRadius.circular(8) : null,
      ),
      child: showShimmer
          ? _buildShimmerEffect()
          : Icon(
        Icons.image,
        size: width == 160 ? 40 : 60,
        color: Colors.grey[500],
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-1.0, -0.3),
          end: Alignment(1.0, 0.3),
          colors: [
            Color(0xFFE0E0E0),
            Color(0xFFF5F5F5),
            Color(0xFFE0E0E0),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: const _ShimmerAnimation(),
    );
  }

  Widget _buildErrorWidget({
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: width == 160 ? BorderRadius.circular(8) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: width == 160 ? 32 : 48,
            color: Colors.grey[500],
          ),
          if (width == 160) ...[
            const SizedBox(height: 8),
            Text(
              'Image\nUnavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Custom shimmer animation widget
class _ShimmerAnimation extends StatefulWidget {
  const _ShimmerAnimation();

  @override
  _ShimmerAnimationState createState() => _ShimmerAnimationState();
}

class _ShimmerAnimationState extends State<_ShimmerAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: const [
                Colors.transparent,
                Colors.white38,
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }
}

// // Alternative version with preloading capability
// class PreloadedAlbumHeader extends StatefulWidget {
//   final Album album;
//
//   const PreloadedAlbumHeader({Key? key, required this.album}) : super(key: key);
//
//   @override
//   _PreloadedAlbumHeaderState createState() => _PreloadedAlbumHeaderState();
// }
//
// class _PreloadedAlbumHeaderState extends State<PreloadedAlbumHeader> {
//   bool _isImageCached = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _preloadImage();
//   }
//
//   Future<void> _preloadImage() async {
//     try {
//       // Preload the image to cache
//       await precacheImage(
//         CachedNetworkImageProvider(widget.album.coverImageUrl),
//         context,
//       );
//       if (mounted) {
//         setState(() {
//           _isImageCached = true;
//         });
//       }
//     } catch (e) {
//       // Handle preload error
//       if (mounted) {
//         setState(() {
//           _isImageCached = true; // Show anyway, let CachedNetworkImage handle error
//         });
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedOpacity(
//       opacity: _isImageCached ? 1.0 : 0.0,
//       duration: const Duration(milliseconds: 300),
//       child: AlbumHeader(album: widget.album),
//     );
//   }
// }
