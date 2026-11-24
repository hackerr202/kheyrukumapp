import '../utils/json_parsers.dart';

/// Model representing an official Center Announcement
class Announcement {
  final String id;
  final String title;
  final String content;
  final String targetAudience; // 'all', 'parents', 'teachers'
  final String authorName;
  final bool isPinned;
  final String? attachmentUrl;
  final String? attachmentName;
  final DateTime createdAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    this.targetAudience = 'all',
    this.authorName = 'Center Administration',
    this.isPinned = false,
    this.attachmentUrl,
    this.attachmentName,
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: JsonParsers.asString(json['id']),
      title: JsonParsers.asNullableString(json['title']) ?? 'Announcement',
      content: JsonParsers.asString(json['content']),
      targetAudience:
          JsonParsers.asNullableString(json['target_audience']) ?? 'all',
      authorName: JsonParsers.asNullableString(json['author_name']) ??
          'Center Administration',
      isPinned: JsonParsers.asBool(json['is_pinned']),
      attachmentUrl: JsonParsers.asNullableString(json['attachment_url']),
      attachmentName: JsonParsers.asNullableString(json['attachment_name']),
      createdAt: JsonParsers.asDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'target_audience': targetAudience,
      'author_name': authorName,
      'is_pinned': isPinned,
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
