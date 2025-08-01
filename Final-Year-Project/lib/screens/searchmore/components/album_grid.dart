// albums_grid_section.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fyp/models/album_model.dart';
import 'package:fyp/screens/album/screens/album_screen.dart';

class AlbumsGridSection extends StatelessWidget {
  final List<Album> filteredAlbums;
  final ScrollController scrollController;
  final bool isLoadingMore;

  const AlbumsGridSection({
    Key? key,
    required this.filteredAlbums,
    required this.scrollController,
    required this.isLoadingMore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    if (filteredAlbums.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 12),
            Text(
              'No albums found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }


    return Stack(
      children: [
        GridView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 148 / 176,
          ),
          itemCount: filteredAlbums.length,
          itemBuilder: (context, index) {
            final album = filteredAlbums[index];
            return GestureDetector(
              onTap: (){
                Navigator.push(context,MaterialPageRoute(builder: (context)=>AlbumDetailScreen(album: album)));
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color.fromARGB(255, 224, 224, 224)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: album.coverImageUrl,
                        height: h * 0.17,
                        width: w * 0.35,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: h * 0.17,
                          width: w * 0.35,
                          color: Colors.grey.shade300,
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: h * 0.17,
                          width: w * 0.35,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        album.albumTitle,
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

      ],
    );
  }
}
