import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'album_role_botton.dart';

class ParticipantCard extends StatelessWidget {
  final Map<String, dynamic> participant;
  final ValueChanged<String> onRoleChanged;
  final bool isDisabled;

  const ParticipantCard({
    Key? key,
    required this.participant,
    required this.onRoleChanged,
    this.isDisabled = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shadowColor: Colors.grey.withOpacity(1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Clip to circle and use CachedNetworkImage with shimmer placeholder
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: participant["photo_url"].toString(),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    width: 48,
                    height: 48,
                    color: Colors.white,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey.shade200,
                  child: Icon(Icons.error, color: Colors.red, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                participant['display_name'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            RoleButton(
              currentRole: participant['access_role'] ?? '',
              onRoleSelected: onRoleChanged,
              isDisabled: isDisabled,
            ),
          ],
        ),
      ),
    );
  }
}
