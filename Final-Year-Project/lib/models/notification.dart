import 'dart:convert';

class NotificationModel {
  int? id;
  int? userId;
  String title;
  String body;
  Map<String, dynamic> data;
  DateTime timestamp;

  NotificationModel({
    this.id,
    this.userId,
    required this.title,
    required this.body,
    required this.data,
    required this.timestamp,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] is String ? int.tryParse(json['id']) : json['id'],
      userId: json['user_id'] is String ? int.tryParse(json['user_id']) : json['user_id'],
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      data: json['data'] is String
          ? jsonDecode(json['data'])
          : (json['data'] as Map<String, dynamic>? ?? {}),
      timestamp: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'data': data,
      'created_at': timestamp.toIso8601String(),
    };
  }
}
