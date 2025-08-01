
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fyp/models/album_model.dart';
import 'package:intl/intl.dart';
import '../../../models/sharedalbum.dart';
import '../screens/album_screen.dart';

class SharedAlbumCard extends StatelessWidget {
  final Album album;

  const SharedAlbumCard({Key? key, required this.album}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd MMM yyyy').format(album.createdAt);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlbumDetailScreen(album: album),
          ),
        );
      },
      child: Card(
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.only(bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: album.coverImageUrl,
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: double.infinity,
                  height: 150,
                  color: Colors.grey.shade300,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) => Container(
                  width: double.infinity,
                  height: 150,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                ),
              ),
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: _buildTextContainer(album.albumTitle, 18, FontWeight.bold),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: _buildTextContainer(formattedDate, 12, FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildTextContainer(String text, double fontSize, FontWeight fontWeight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
    );
  }
}