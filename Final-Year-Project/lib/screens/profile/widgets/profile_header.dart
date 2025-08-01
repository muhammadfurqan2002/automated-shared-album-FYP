import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../models/user.dart';

class ProfileHeader extends StatelessWidget {
  final User? user;

  const ProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final String username = user?.username ?? 'Guest User';
    final String email = user?.email ?? 'Email unavailable';
    final String? profileImage = user?.profileImageUrl;
    final DateTime? imageUpdated = user?.imageUpdated;

    // Append timestamp if available
    final String? imageUrlWithTimestamp = (profileImage != null && imageUpdated != null)
        ? '$profileImage?t=${imageUpdated.millisecondsSinceEpoch}'
        : profileImage;

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: imageUrlWithTimestamp != null
              ? CachedNetworkImage(
            imageUrl: imageUrlWithTimestamp,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 100,
              height: 100,
              alignment: Alignment.center,
              color: Colors.grey[300],
              child: const CircularProgressIndicator(),
            ),
            errorWidget: (context, url, error) => Container(
              width: 100,
              height: 100,
              alignment: Alignment.center,
              color: Colors.grey[300],
              child: const Icon(
                Icons.person,
                size: 50,
                color: Colors.white,
              ),
            ),
          )
              : Container(
            width: 100,
            height: 100,
            alignment: Alignment.center,
            color: Colors.grey[300],
            child: const Icon(Icons.person, size: 50, color: Colors.white),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  decoration: TextDecoration.underline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
