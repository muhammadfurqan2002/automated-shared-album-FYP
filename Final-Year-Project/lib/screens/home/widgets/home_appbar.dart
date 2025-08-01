import 'package:flutter/material.dart';
import 'package:fyp/screens/notification/notifications.dart';
import 'package:provider/provider.dart';

import '../../../providers/notification_provider.dart';
import '../../../utils/navigation_helper.dart';

import 'package:flutter/material.dart';

PreferredSizeWidget buildAppBar(BuildContext context) {
  return AppBar(
    automaticallyImplyLeading: false,
    // backgroundColor: Colors.transparent,
    // centerTitle: true,
    toolbarHeight: 50, // more breathing room
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.home, color: Colors.blueAccent, size: 28),
        const SizedBox(width: 8),
        // Gradient “Home” text
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.blue, Colors.purple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text(
            'Home',
            style: TextStyle(
              color: Colors.white,         // required for ShaderMask
              fontSize: 26,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(                    // subtle drop‑shadow
                  offset: Offset(0, 2),
                  blurRadius: 3,
                  color: Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    actions: [
      _buildNotificationBadge(context),
      const SizedBox(width: 12),
    ],
  );
}

Widget _buildNotificationBadge(BuildContext context) {
  return Consumer<NotificationProvider>(
    builder: (context, provider, _) {
      final count = provider.liveCount;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black, size: 24),
            onPressed: () {
              provider.resetLiveCount();
              navigateTo(context, const NotificationsScreen());
            },
          ),
          if (count > 0)
            Positioned(
              right: 6, top: 2,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
