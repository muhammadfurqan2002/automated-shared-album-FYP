import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fyp/models/album_model.dart';
import '../../album/screens/album_screen.dart';
import 'home_recenlty_added_header.dart';


class RecentlyAddedList extends StatefulWidget {
  final List<Album> recentlyAddedAlbums;
  final bool isLoading;

  const RecentlyAddedList({
    super.key,
    required this.recentlyAddedAlbums,
    required this.isLoading,
  });

  @override
  State<RecentlyAddedList> createState() => _RecentlyAddedListState();
}

class _RecentlyAddedListState extends State<RecentlyAddedList> {
  bool _isExpanded = true;
  int _crossAxisCount = 2;

  // Toggle between different grid layouts
  void _toggleGridLayout() {
    setState(() {
      if (_crossAxisCount == 2) {
        _crossAxisCount = 3;
      } else if (_crossAxisCount == 3) {
        _crossAxisCount = 1;
      } else {
        _crossAxisCount = 2;
      }
    });
  }

  // Toggle visibility of the grid
  void _toggleVisibility() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with functional icons
        RecentlyAddedHeader(
          isExpanded: _isExpanded,
          crossAxisCount: _crossAxisCount,
          onToggleVisibility: _toggleVisibility,
          onToggleGridLayout: _toggleGridLayout,
        ),
        const SizedBox(height: 20),

        // Animated grid content
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isExpanded ? null : 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _isExpanded ? 1.0 : 0.0,
            child: _buildGridContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildGridContent() {
    if (widget.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: MasonryGridView.builder(
          shrinkWrap: true,
          mainAxisSpacing: 5.0,
          crossAxisSpacing: 15.0,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _crossAxisCount,
          ),
          itemCount: _crossAxisCount == 1 ? 2 : 4,
          itemBuilder: (context, index) {
            return Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                height: _getItemHeight(index),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 7,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } else if (widget.recentlyAddedAlbums.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40.0),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 60,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                "No Albums Found",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Display actual album items
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: MasonryGridView.builder(
          shrinkWrap: true,
          mainAxisSpacing: 5.0,
          crossAxisSpacing: 15.0,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _crossAxisCount,
          ),
          itemCount: widget.recentlyAddedAlbums.length,
          itemBuilder: (context, index) {
            final album = widget.recentlyAddedAlbums[index];
            return _buildAlbumItem(album, index);
          },
        ),
      );
    }
  }

  Widget _buildAlbumItem(Album album, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlbumDetailScreen(album: album),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: _getItemHeight(index),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: album.coverImageUrl.toString(),
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) =>
                const Center(child: Icon(Icons.error)),
              ),
              if (_crossAxisCount == 1) _buildListOverlay(album),
            ],
          ),
        ),
      ),
    );
  }

  // Overlay for list view (single column)
  Widget _buildListOverlay(Album album) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            album.albumTitle ?? 'Unknown Album',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Dynamic height based on grid layout and index
  double _getItemHeight(int index) {
    if (_crossAxisCount == 1) {
      return 120; // List view height
    } else if (_crossAxisCount == 2) {
      return index.isEven ? 150 : 200; // Original masonry heights
    } else {
      // For 3 columns, use more varied heights
      switch (index % 3) {
        case 0:
          return 140;
        case 1:
          return 180;
        case 2:
          return 160;
        default:
          return 150;
      }
    }
  }
}