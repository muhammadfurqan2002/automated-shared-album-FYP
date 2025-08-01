import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fyp/screens/album/screens/flagged_images.dart';
import 'package:fyp/utils/ip.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../models/album_model.dart';
import 'package:http/http.dart' as http;
import '../../providers/notification_provider.dart';
import '../../providers/session_manager.dart';
import '../../utils/flashbar_helper.dart';
import '../../utils/navigation_helper.dart';
import '../album/screens/album_screen.dart';
import 'noitification_msg.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool isLoading = true;
  bool isFetchingMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SessionManager.checkJwtAndLogoutIfExpired(context);
      Provider.of<NotificationProvider>(context, listen: false)
          .resetLiveCount();
    });
    _fetchInitialData();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !isFetchingMore) {
        _fetchMoreNotifications();
      }
    });
  }

  Future<void> _fetchInitialData() async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);

    if (provider.notifications.isEmpty) {
      await provider.fetchNotificationsFromServer(reset: true);
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }


  Future<void> _fetchMoreNotifications() async {
    setState(() => isFetchingMore = true);
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    await provider.fetchNotificationsFromServer(); // fetches next page
    setState(() => isFetchingMore = false);
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      centerTitle: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Notifications',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep_sharp, color: Colors.red),
          tooltip: 'Clear All',
          onPressed: () async{
            await Provider.of<NotificationProvider>(context, listen: false)
                .clearAllNotificationsFromServer();
          },
        ),
      ],
    );
  }

  Widget _buildNotificationsList() {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final notifications = provider.notifications;

        if (isLoading) {
          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: 4,
            itemBuilder: (context, index) => _shimmerLoader(),
          );
        }

        if (notifications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 12),
                Text(
                  'No notifications',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }


        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(15),
          itemCount: notifications.length + (isFetchingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == notifications.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final notification = notifications[index];
            return Dismissible(
              key: Key('notification_${notification.timestamp.millisecondsSinceEpoch}_$index'),
              direction: DismissDirection.endToStart,
              background: Container(
                padding: const EdgeInsets.only(right: 20),
                alignment: Alignment.centerRight,
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) async {
                final notificationId = notification.data['notificationId'];
                if (notificationId != null) {
                  await Provider.of<NotificationProvider>(context, listen: false)
                      .removeNotificationById(notificationId);
                }
              },
              child: Material(
                color: Colors.white,
                child: InkWell(
                  onTap: () async {
                    final rawId = notification.data['albumId'] as String;
                    final albumId = int.parse(rawId);
                    final type=notification.data['type'];
                    print(type);
                    const storage = FlutterSecureStorage();
                    final token = await storage.read(key: 'jwt') ?? '';
                    final uri = Uri.parse('${IP.ip}/shared/$albumId/check-access');

                    try {
                      final response = await http.get(
                        uri,
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer $token',
                        },
                      );

                      if (response.statusCode == 200) {
                        final jsonMap = json.decode(response.body) as Map<String, dynamic>;
                        final album = Album.fromJson(jsonMap);

                        if (type == "duplicate_report" || type == "blur_report") {
                          navigateTo(context, FlaggedImages(album: album));
                        } else {
                          navigateTo(context, AlbumDetailScreen(album: album));
                        }

                      } else if (response.statusCode == 403) {
                        FlushbarHelper.show(
                          context,
                          message: 'You no longer have access to that album.',
                          icon: Icons.lock_open,
                          backgroundColor: Colors.redAccent,
                        );

                      } else {
                        FlushbarHelper.show(
                          context,
                          message: 'Failed to load album (code ${response.statusCode}).',
                          icon: Icons.error_outline,
                          backgroundColor: Colors.orangeAccent,
                        );
                      }
                    } catch (e) {
                      FlushbarHelper.show(
                        context,
                        message: 'Network error. Please try again.',
                        icon: Icons.wifi_off,
                        backgroundColor: Colors.blueGrey,
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: NotificationItem(
                      imagePath: notification.data['albumCover'] ?? '',
                      message: notification.body,
                      time: notification.timestamp.toIso8601String(),
                    ),
                  ),
                ),
              ),
            );

          },
        );
      },
    );
  }

  Widget _shimmerLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: _buildNotificationsList(),
    );
  }
}