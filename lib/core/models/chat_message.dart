class Conversation {
  final String id;
  final String title;
  final bool isGroup;
  final List<String> participantIds;
  final List<String> participantNames;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String? halaqahId;
  final String groupType; // 'broadcast', 'parent_group', 'direct_admin', 'direct_teacher'
  int unreadCount;
  final bool isPinned;

  Conversation({
    required this.id,
    required this.title,
    this.isGroup = false,
    required this.participantIds,
    required this.participantNames,
    this.lastMessage = '',
    required this.lastMessageTime,
    this.halaqahId,
    this.groupType = 'direct_admin',
    this.unreadCount = 0,
    this.isPinned = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Conversation',
      isGroup: json['is_group'] == true,
      participantIds: (json['participant_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      participantNames: (json['participant_names'] as List?)?.map((e) => e.toString()).toList() ?? [],
      lastMessage: json['last_message']?.toString() ?? '',
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.tryParse(json['last_message_time'].toString()) ?? DateTime.now()
          : DateTime.now(),
      halaqahId: json['halaqah_id']?.toString(),
      groupType: json['group_type']?.toString() ?? 'direct_admin',
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      isPinned: json['is_pinned'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'is_group': isGroup,
      'participant_ids': participantIds,
      'participant_names': participantNames,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime.toIso8601String(),
      'halaqah_id': halaqahId,
      'group_type': groupType,
      'unread_count': unreadCount,
      'is_pinned': isPinned,
    };
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'admin', 'teacher', 'parent'
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final String messageType; // 'text', 'voice', 'image', 'document'
  final String? attachmentUrl;
  final String? attachmentName;
  final int? audioDurationSeconds;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.messageType = 'text',
    this.attachmentUrl,
    this.attachmentName,
    this.audioDurationSeconds,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? 'User',
      senderRole: json['sender_role']?.toString() ?? 'parent',
      content: json['content']?.toString() ?? '',
      timestamp: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['timestamp'] != null
              ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
              : DateTime.now()),
      isRead: json['is_read'] == true,
      messageType: json['message_type']?.toString() ?? 'text',
      attachmentUrl: json['attachment_url']?.toString(),
      attachmentName: json['attachment_name']?.toString(),
      audioDurationSeconds: (json['audio_duration'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'content': content,
      'created_at': timestamp.toIso8601String(),
      'is_read': isRead,
      'message_type': messageType,
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
      'audio_duration': audioDurationSeconds,
    };
  }
}
