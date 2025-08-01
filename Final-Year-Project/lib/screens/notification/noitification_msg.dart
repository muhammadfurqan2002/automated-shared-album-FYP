import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class NotificationItem extends StatelessWidget {
  final String imagePath;
  final String message;
  final String time;

  const NotificationItem({
    Key? key,
    required this.imagePath,
    required this.message,
    required this.time,
  }) : super(key: key);

  static const double _imageSize = 60.0;
  static const double _borderRadius = 35.0;
  static const double _spacing = 15.0;
  static const double _messageTextSize = 12.0;
  static const double _timeTextSize = 10.0;

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          _buildNotificationImage(),
          const SizedBox(width: _spacing),
          _buildNotificationContent(),
        ],
      ),
    );
  }

  Widget _buildNotificationImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_borderRadius),
      child: CachedNetworkImage(
        imageUrl: imagePath,
        width: _imageSize,
        height: _imageSize,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: _imageSize,
          height: _imageSize,
          color: Colors.grey[300],
          alignment: Alignment.center,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (context, url, error) => Container(
          width: _imageSize,
          height: _imageSize,
          color: Colors.grey[300],
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildNotificationContent() {
    final parsedDate = DateTime.parse(time);
    final formatted = DateFormat('MMM dd, yyyy – hh:mm a').format(parsedDate);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              fontSize: _messageTextSize,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            formatted,
            style: const TextStyle(
              fontSize: _timeTextSize,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
