/// Model representing an official Center Announcement
class Announcement {
  final String id;
  final String title;
  final String content;
  final String category; // 'general', 'urgent', 'event', 'quran_halaqah', 'holiday'
  final String targetAudience; // 'all', 'parents', 'teachers'
  final String authorName;
  final bool isPinned;
  final DateTime createdAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    this.category = 'general',
    this.targetAudience = 'all',
    this.authorName = 'Center Administration',
    this.isPinned = false,
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Announcement',
      content: json['content'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      targetAudience: json['target_audience'] as String? ?? 'all',
      authorName: json['author_name'] as String? ?? 'Center Administration',
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'category': category,
      'target_audience': targetAudience,
      'author_name': authorName,
      'is_pinned': isPinned,
    };
  }
}
