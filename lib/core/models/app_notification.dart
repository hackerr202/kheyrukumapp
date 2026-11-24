import '../utils/json_parsers.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: JsonParsers.asString(json['id']),
      title: JsonParsers.asNullableString(json['title']) ?? 'Notification',
      body: JsonParsers.asString(json['body']),
      type: JsonParsers.asNullableString(json['type']) ?? 'general',
      createdAt: JsonParsers.asDateTime(json['created_at']),
      isRead: JsonParsers.asBool(json['is_read']),
      data: JsonParsers.asMap(json['data']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'data': data,
    };
  }
}
