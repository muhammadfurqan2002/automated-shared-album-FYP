import 'package:flutter/material.dart';
import 'package:fyp/models/album_model.dart';

class AlbumTitleSection extends StatelessWidget {
  final Album album;
  final int memberCount;
  final int photoCount;

  const AlbumTitleSection({
    Key? key,
    required this.album,
    this.memberCount = 0,
    this.photoCount = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          album.albumTitle,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$memberCount members .',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              ' $photoCount photos',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}
