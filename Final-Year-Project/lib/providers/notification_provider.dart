import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import '../models/notification.dart';
import '../utils/ip.dart';

class NotificationProvider extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  List<NotificationModel> _notifications = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoading = false;
  int _liveCount = 0;                // ← count of real-time arrivals
  int get liveCount => _liveCount;   // ← expose it

  /// Call this to zero out the live counter (e.g. when opening the screen)
  void resetLiveCount() {
    _liveCount = 0;
    notifyListeners();
  }

  List<NotificationModel> get notifications => _notifications;

  Future<String> getToken() async {
    try {
      final token = await _storage.read(key: 'jwt');
      return token ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> init() async {
    await fetchNotificationsFromServer(reset: true);
  }

  /// Fetch notifications from server with optional reset
  Future<void> fetchNotificationsFromServer({bool reset = false}) async {
    if (_isLoading) return;
    _isLoading = true;

    if (reset) {
      _currentPage = 1;
      _hasMore = true;
      _notifications.clear();
    }

    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('${IP.ip}/notifications?page=$_currentPage&limit=10'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📨 Response body: ${response.body}');
      print('📨 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);
        print('📨 Parsed response data: $responseData');

        if (responseData is! List) {
          print('Response is not a List');
          return;
        }

        final newItems = <NotificationModel>[];
        for (int i = 0; i < responseData.length; i++) {
          try {
            final json = responseData[i];
            final notification = NotificationModel.fromJson(json);
            newItems.add(notification);
          } catch (e) {
            print('Error processing notification at index $i: $e');
          }
        }

        _notifications.addAll(newItems);
        if (newItems.length < 10) _hasMore = false;

        _currentPage++;
        notifyListeners();
      } else {
        print('Failed to fetch notifications: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Error fetching notifications: $e');
      print('Stack trace: $stackTrace');
    } finally {
      _isLoading = false;
    }
  }

  /// Used by infinite scroll
  Future<void> fetchMoreNotifications() async {
    if (_hasMore && !_isLoading) {
      await fetchNotificationsFromServer();
    }
  }


  Future<String?> getUserIdFromToken() async {
    final token = await getToken();
    if (token.isEmpty || JwtDecoder.isExpired(token)) return null;
    final Map<String, dynamic> payload = JwtDecoder.decode(token);
    final id = payload['id'];
    return id?.toString();
  }
  /// Add new notification (e.g., from FCM) only if it belongs to the current user
  Future<void> addNotification(NotificationModel model) async {
    final currentUserId = await getUserIdFromToken();
    final modelUserId   = model.data['receiverId']?.toString();


    if (currentUserId != null && modelUserId == currentUserId) {
      _notifications.insert(0, model);
      _liveCount++;
      notifyListeners();
    } else {
      print(
          '🚫 Skipping notification—'
              ' model.userId=$modelUserId does not match currentUserId=$currentUserId'
      );
    }
  }


  /// Remove a notification using notificationId (UUID)
  Future<void> removeNotificationById(String notificationId) async {
    final token = await getToken();
    try {
      final response = await http.delete(
        Uri.parse('${IP.ip}/notifications/$notificationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Remove locally
        _notifications.removeWhere(
              (n) => n.data['notificationId'] == notificationId,
        );
        notifyListeners();
        print('✅ Notification $notificationId removed');
      } else {
        print('❌ Failed to remove notification: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }

  /// Clear all notifications from backend
  Future<void> clearAllNotificationsFromServer() async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('${IP.ip}/notifications/user'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _notifications.clear();
        notifyListeners();
        print('✅ All notifications cleared');
      } else {
        print('❌ Failed to clear notifications: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error clearing notifications: $e');
    }
  }

}
