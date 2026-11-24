import '../utils/json_parsers.dart';

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

  Conversation copyWith({
    String? title,
    bool? isPinned,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      isGroup: isGroup,
      participantIds: participantIds,
      participantNames: participantNames,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      halaqahId: halaqahId,
      groupType: groupType,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: JsonParsers.asString(json['id']),
      title: JsonParsers.asNullableString(json['title']) ?? 'Conversation',
      isGroup: JsonParsers.asBool(json['is_group']),
      participantIds: JsonParsers.asStringList(json['participant_ids']),
      participantNames: JsonParsers.asStringList(json['participant_names']),
      lastMessage: JsonParsers.asString(json['last_message']),
      lastMessageTime: JsonParsers.asDateTime(json['last_message_time']),
      halaqahId: JsonParsers.asNullableString(json['halaqah_id']),
      groupType:
          JsonParsers.asNullableString(json['group_type']) ?? 'direct_admin',
      unreadCount: JsonParsers.asInt(json['unread_count'], 0),
      isPinned: JsonParsers.asBool(json['is_pinned']),
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
      'last_message_time': lastMessageTime.toUtc().toIso8601String(),
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
  final bool isEdited;

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
    this.isEdited = false,
  });

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    String? messageType,
    String? attachmentUrl,
    String? attachmentName,
    int? audioDurationSeconds,
    bool? isEdited,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      messageType: messageType ?? this.messageType,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      isEdited: isEdited ?? this.isEdited,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: JsonParsers.asString(json['id']),
      conversationId: JsonParsers.asString(json['conversation_id']),
      senderId: JsonParsers.asString(json['sender_id']),
      senderName: JsonParsers.asNullableString(json['sender_name']) ?? 'User',
      senderRole: JsonParsers.asNullableString(json['sender_role']) ?? 'parent',
      content: JsonParsers.asString(json['content']),
      timestamp:
          JsonParsers.asDateTime(json['created_at'] ?? json['timestamp']),
      isRead: JsonParsers.asBool(json['is_read']),
      messageType:
          JsonParsers.asNullableString(json['message_type']) ?? 'text',
      attachmentUrl: JsonParsers.asNullableString(json['attachment_url']),
      attachmentName: JsonParsers.asNullableString(json['attachment_name']),
      audioDurationSeconds: JsonParsers.asNullableInt(json['audio_duration']),
      isEdited: JsonParsers.asBool(json['is_edited']),
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
      'created_at': timestamp.toUtc().toIso8601String(),
      'is_read': isRead,
      'message_type': messageType,
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
      'audio_duration': audioDurationSeconds,
      'is_edited': isEdited,
    };
  }
}
