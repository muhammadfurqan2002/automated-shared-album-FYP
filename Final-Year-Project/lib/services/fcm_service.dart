// lib/services/fcm_service.dart

import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fyp/providers/album_provider.dart';
import 'package:fyp/screens/album/screens/album_screen.dart';
import 'package:fyp/screens/album/screens/flagged_images.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../firebase_options.dart';
import '../models/album_model.dart';
import '../models/notification.dart';
import '../providers/notification_provider.dart';
import '../providers/sharedAlbum_provider.dart';
import '../screens/notification/notifications.dart';
import 'album_notification_service.dart';
import 'fcm_background_handler.dart';

/// Handles all Firebase Cloud Messaging setup and functionality
class FCMService {
  // Singleton instance
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  // Navigation key to access context from outside of widgets
  GlobalKey<NavigatorState>? navigatorKey;

  // Provider reference
  SharedAlbumProvider? _sharedAlbumProvider;

  // Create a global instance for flutter_local_notifications
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Define an Android notification channel for high importance notifications
  final AndroidNotificationChannel channel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  // In FCMService class
  AlbumNotificationService? _albumNotificationService;

  Future<void> initialize({
    required GlobalKey<NavigatorState> navKey,
    AlbumNotificationService? albumNotificationService,
  }) async {
    // Rest of your initialization...
    try {
      navigatorKey = navKey;
      _albumNotificationService = albumNotificationService;

      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Set up notifications
      await setupFlutterNotifications();
      await requestNotificationPermissions();
      await requestNotificationPermissionAndroid();

      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Set up foreground notification handling
      await setupForegroundNotificationHandling();

      // Get FCM token and print it
      String? token = await FirebaseMessaging.instance.getToken();
      print("FCM Token: $token");

      // Check if app was opened from a terminated state notification
      await _checkInitialMessage();
    } catch (e) {
      print("FCM initialization error: $e");
    }
  }

  /// Set up the Flutter Local Notifications plugin
  Future<void> setupFlutterNotifications() async {
    // Initialize the plugin with proper settings
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize the plugin with notification tap handler
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('Notification clicked: ${response.payload}');

        // Parse payload and handle navigation
        if (response.payload != null) {
          _handleNotificationTap(json.decode(response.payload!));
        }
      },
    );

    // Create the notification channel
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print("Flutter notifications setup completed");
  }

  /// Request notification permissions for iOS
  Future<void> requestNotificationPermissions() async {
    // For iOS/Firebase Messaging permission
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    print('User granted iOS permission: ${settings.authorizationStatus}');
  }

  /// Request notification permissions for Android
  Future<void> requestNotificationPermissionAndroid() async {
    if (Platform.isAndroid) {
      var status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
        print('Android notification permission requested');
      } else {
        print('Android notification permission already granted');
      }
    }
  }

  /// Set up foreground notification handling
  Future<void> setupForegroundNotificationHandling() async {
    // Set up foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print("Foreground message received: ${message.messageId}");
      print("Full message content: ${message.data}");
      print("Notification present? ${message.notification != null}");

      final context = navigatorKey?.currentContext;
      if (context != null) {
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        final RemoteNotification? notification = message.notification;

        if (notification != null) {
          final model = NotificationModel(
            title: notification.title ?? '',
            body: notification.body ?? '',
            data: message.data,
            timestamp: DateTime.now(),
          );

          notificationProvider.addNotification(model);
        }
      } else {
        debugPrint('❗️NotificationProvider context is null — cannot add notification');
      }


      // Refresh data based on notification type
      _refreshDataBasedOnNotification(message.data);

      RemoteNotification? notification = message.notification;
      if (notification != null) {
        print("Title: ${notification.title}");
        print("Body: ${notification.body}");

        try {
          try {
            final String? albumCoverUrl = message.data['albumCover'];
            File? downloadedImage;

            if (albumCoverUrl != null && albumCoverUrl.isNotEmpty) {
              final response = await http.get(Uri.parse(albumCoverUrl));
              if (response.statusCode == 200) {
                final directory = await getTemporaryDirectory();
                final filePath = '${directory.path}/album_cover.jpg';
                downloadedImage = File(filePath);
                await downloadedImage.writeAsBytes(response.bodyBytes);
              }
            }

            final style = downloadedImage != null
                ? BigPictureStyleInformation(
              FilePathAndroidBitmap(downloadedImage.path),
              largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
              contentTitle: notification.title,
              summaryText: notification.body,
              htmlFormatContentTitle: true,
              htmlFormatSummaryText: true,
            )
                : null;

            await flutterLocalNotificationsPlugin.show(
              notification.hashCode,
              notification.title,
              notification.body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  channel.id,
                  channel.name,
                  channelDescription: channel.description,
                  styleInformation: style,
                  icon: '@mipmap/ic_launcher',
                ),
              ),
              payload: json.encode(message.data),
            );
            print("Foreground notification shown successfully");
          } catch (e) {
            print("Error showing foreground notification: $e");
          }

          print("Foreground notification shown successfully");
        } catch (e) {
          print("Error showing foreground notification: $e");
        }
      }
    });

    // Handle notification taps when app is in background but open
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification caused app to open: ${message.data}");

      // Refresh data and handle navigation
      _refreshDataBasedOnNotification(message.data);
      _handleNotificationTap(message.data);
    });
  }

  /// Check if app was opened from a terminated state notification
  Future<void> _checkInitialMessage() async {
    // Get any messages which caused the application to open
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      print("App opened from terminated state with message: ${initialMessage.data}");

      // Refresh data and handle navigation
      _refreshDataBasedOnNotification(initialMessage.data);
      _handleNotificationTap(initialMessage.data);
    }
  }

  /// Handle notification tap by navigating to appropriate screen
  void _handleNotificationTap(Map<String, dynamic> data) {
    try {



      // Check notification type
      final String notificationType = data['type'] ?? '';

      final album = Album.fromJson({
        'id': int.parse(data['albumId']),
        'user_id': int.parse(data['userId']),
        'album_title': data['albumTitle'],
        'cover_image_url': data['albumCover'],
        'created_at': data['createdAt'],
      });
      final String albumId = data['albumId'] ?? '';

      print("notification_type");
      print(notificationType);

      // For shared album notifications, navigate to album detail
      if (notificationType == 'album_shared' || notificationType == 'album_created' || notificationType == 'album_role_updated') {
        
        if (albumId.isNotEmpty && navigatorKey?.currentState != null) {
          // Add a slight delay to ensure data is refreshed before navigation

          Future.delayed(const Duration(milliseconds: 500), () {
            navigatorKey!.currentState!.push(
              MaterialPageRoute(
                builder: (context) => AlbumDetailScreen(album: album,),
              ),
            );
          });
        }
      }else if(notificationType=='blur_report' || notificationType=='duplicate_report'){
        if (albumId.isNotEmpty && navigatorKey?.currentState != null) {
          // Add a slight delay to ensure data is refreshed before navigation
          print("inside blur an duplicate report");
          Future.delayed(const Duration(milliseconds: 500), () {
            navigatorKey!.currentState!.push(
              MaterialPageRoute(
                builder: (context) => FlaggedImages(album: album),
              ),
            );
          });
        }

      }else{
        if (albumId.isNotEmpty && navigatorKey?.currentState != null) {
          // Add a slight delay to ensure data is refreshed before navigation
          print("inside blur an duplicate report");
          Future.delayed(const Duration(milliseconds: 500), () {
            navigatorKey!.currentState!.push(
              MaterialPageRoute(
                builder: (context) =>const  NotificationsScreen(),
              ),
            );
          });
        }

      }
    } catch (e) {
      print('Error handling notification tap: $e');
    }
  }

  Future<void> _refreshDataBasedOnNotification(Map<String, dynamic> data) async {
    try {


      final String notificationType = data['type'] ?? '';
      final int albumId = int.tryParse(data['albumId'].toString()) ?? -1;
      // Add a slight delay to ensure data is refreshed before navigation
      final album = Album.fromJson({
        'id': int.parse(data['albumId']),
        'user_id': int.parse(data['userId']),
        'album_title': data['albumTitle'],
        'cover_image_url': data['albumCover'],
        'created_at': data['createdAt'],
      });
      final context = navigatorKey?.currentContext;

      if (notificationType == 'album_role_updated' && _albumNotificationService != null) {
        await _albumNotificationService!.handleRoleUpdate(albumId);
      }
      if(notificationType=='album_access_removed' && _albumNotificationService!=null){
          if(context!=null){
            final albumProvider = Provider.of<AlbumProvider>(context, listen: false);
            await albumProvider.removeSharedAlbum(albumId);
          }
      }
      if(notificationType=='album_shared' && _albumNotificationService!=null){

          // await _albumNotificationService!.handleSharedAlbum();

        if (context != null) {
          final albumProvider = Provider.of<AlbumProvider>(context, listen: false);

          await albumProvider.addSharedAlbum(album);
        }
      }
    } catch (e) {
      print('Error refreshing data based on notification: $e');
    }
  }

  /// Test function to manually show a notification
  Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    try {
      await flutterLocalNotificationsPlugin.show(
        0,
        'Test Notification',
        'This is a test notification',
        platformDetails,
        payload: json.encode({
          'type': 'album_shared',
          'albumId': '123',
        }),
      );
      print("Test notification shown successfully");
    } catch (e) {
      print("Error showing test notification: $e");
    }
  }

  /// Get the FCM token for this device
  Future<String?> getToken() async {
    return await FirebaseMessaging.instance.getToken();
  }
}