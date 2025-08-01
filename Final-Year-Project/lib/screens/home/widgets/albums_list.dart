import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../models/album_model.dart';
import '../../album/screens/album_screen.dart';

class AlbumsList extends StatelessWidget {
  final List<Album> albums;
  final bool isLoading;
  final ScrollController? controller;
  final bool isLoadingMore;
  final bool hasMore;

  const AlbumsList({
    super.key,
    required this.albums,
    required this.isLoading,
    this.controller,
    this.isLoadingMore = false,
    this.hasMore = false,
  });

  static const double _itemHeight = 180.0;
  static const double _itemWidth = 130.0;
  static const double _itemMargin = 15.0;
  static const double _borderRadius = 25.0;
  static const double _imageHeight = 125.0;
  static const double _imageWidth = 120.0;
  static const double _imageRadius = 20.0;
  static const int _shimmerItemCount = 4;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _itemHeight,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_shouldShowShimmer()) {
      return _buildShimmerList();
    }

    if (_shouldShowEmptyState()) {
      return _buildEmptyState();
    }

    return _buildAlbumsList();
  }

  bool _shouldShowShimmer() => isLoading && albums.isEmpty;
  bool _shouldShowEmptyState() => !isLoading && albums.isEmpty;

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No albums available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Albums will appear here when available',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _shimmerItemCount,
      itemBuilder: (context, index) => _buildShimmerItem(),
    );
  }

  Widget _buildAlbumsList() {
    return ListView.builder(
      controller: controller,
      scrollDirection: Axis.horizontal,
      itemCount: _getItemCount(),
      itemBuilder: _buildListItem,
    );
  }

  int _getItemCount() {
    return albums.length + (_shouldShowLoadingIndicator() ? 1 : 0);
  }

  bool _shouldShowLoadingIndicator() => isLoadingMore && hasMore;

  Widget _buildListItem(BuildContext context, int index) {
    if (_isLoadingIndicatorIndex(index)) {
      return _buildLoadingIndicator();
    }
    return _buildAlbumItem(context, albums[index]);
  }

  bool _isLoadingIndicatorIndex(int index) {
    return index == albums.length && _shouldShowLoadingIndicator();
  }

  Widget _buildShimmerItem() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.only(left: _itemMargin),
        height: _itemHeight,
        width: _itemWidth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_borderRadius),
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildAlbumItem(BuildContext context, Album album) {
    return GestureDetector(
      onTap: () => _navigateToAlbumDetail(context, album),
      child: Container(
        margin: const EdgeInsets.only(left: _itemMargin),
        height: _itemHeight,
        width: _itemWidth,
        decoration: _buildItemDecoration(),
        child: _buildItemContent(album),
      ),
    );
  }

  void _navigateToAlbumDetail(BuildContext context, Album album) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlbumDetailScreen(album: album),
      ),
    );
  }

  BoxDecoration _buildItemDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(_borderRadius),
      border: Border.all(
        color: const Color.fromARGB(255, 224, 224, 224),
      ),
    );
  }

  Widget _buildItemContent(Album album) {
    return Column(
      children: [
        const SizedBox(height: 5),
        _buildAlbumImage(album),
        const SizedBox(height: 12),
        _buildAlbumTitle(album),
      ],
    );
  }

  Widget _buildAlbumImage(Album album) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_imageRadius),
        child: _buildImageWidget(album),
      ),
    );
  }

  Widget _buildImageWidget(Album album) {
    if (album.coverImageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: album.coverImageUrl,
        height: _imageHeight,
        width: _imageWidth,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: _imageHeight,
          width: _imageWidth,
          color: Colors.grey.shade300,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => _buildFallbackImage(),
      );
    }
    return _buildFallbackImage();
  }


  Widget _buildFallbackImage() {
    return Image.asset(
      'assets/party.png',
      height: _imageHeight,
      width: _imageWidth,
      fit: BoxFit.cover,
    );
  }

  Widget _buildAlbumTitle(Album album) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(
          album.albumTitle,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}