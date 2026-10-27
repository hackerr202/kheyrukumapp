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
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Announcement',
      content: json['content'] as String? ?? '',
      targetAudience: json['target_audience'] as String? ?? 'all',
      authorName: json['author_name'] as String? ?? 'Center Administration',
      isPinned: json['is_pinned'] as bool? ?? false,
      attachmentUrl: json['attachment_url'] as String?,
      attachmentName: json['attachment_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
