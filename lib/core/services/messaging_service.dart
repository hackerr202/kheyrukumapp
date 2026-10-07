import 'dart:async';
import '../models/chat_message.dart';
import 'notification_center_service.dart';

/// Messaging service managing:
/// - Admin creating groups with parents or direct 1-on-1 chats
/// - Teacher starting 1-on-1 chats with parents of his class students
/// - Parent initiating conversations with Admin or child's halaqah Teachers
/// - Real-time message streaming
class MessagingService {
  MessagingService._();

  static final MessagingService instance = MessagingService._();

  final List<Conversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messagesMap = {};

  final StreamController<List<Conversation>> _conversationsController =
      StreamController<List<Conversation>>.broadcast();

  final Map<String, StreamController<List<ChatMessage>>> _chatControllers = {};

  Stream<List<Conversation>> get conversationsStream => _conversationsController.stream;

  List<Conversation> get allConversations => List.unmodifiable(_conversations);

  /// Get conversations relevant for a user based on user ID and role
  List<Conversation> getConversationsForUser(String userId, {String role = 'admin'}) {
    if (role == 'admin') return _conversations;
    return _conversations.where((c) {
      if (c.participantIds.contains(userId)) return true;
      if (c.isGroup && role == 'parent' && c.groupType == 'parent_group') return true;
      return false;
    }).toList();
  }

  /// Stream messages for a specific conversation
  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    if (!_chatControllers.containsKey(conversationId)) {
      _chatControllers[conversationId] = StreamController<List<ChatMessage>>.broadcast();
    }
    Timer.run(() {
      _chatControllers[conversationId]?.add(List.from(_messagesMap[conversationId] ?? []));
    });
    return _chatControllers[conversationId]!.stream;
  }

  List<ChatMessage> getMessages(String conversationId) {
    return _messagesMap[conversationId] ?? [];
  }

  /// Send message in conversation
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String content,
  }) async {
    final msg = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      content: content.trim(),
      timestamp: DateTime.now(),
      isRead: false,
    );

    _messagesMap.putIfAbsent(conversationId, () => []).add(msg);
    _chatControllers[conversationId]?.add(List.from(_messagesMap[conversationId]!));

    // Update conversation last message
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      final existing = _conversations[idx];
      _conversations[idx] = Conversation(
        id: existing.id,
        title: existing.title,
        isGroup: existing.isGroup,
        participantIds: existing.participantIds,
        participantNames: existing.participantNames,
        lastMessage: msg.content,
        lastMessageTime: msg.timestamp,
        halaqahId: existing.halaqahId,
        groupType: existing.groupType,
      );
      _conversationsController.add(List.from(_conversations));
    }

    return msg;
  }

  /// Teacher starts a direct 1-on-1 chat with a parent of his class students
  Future<Conversation> startTeacherChatWithParent({
    required String teacherId,
    required String teacherName,
    required String parentId,
    required String parentName,
    required String studentName,
    String? halaqahId,
    String? initialMessage,
  }) async {
    // Check if direct conversation already exists between teacher and parent
    final existingIndex = _conversations.indexWhere(
      (c) =>
          !c.isGroup &&
          c.participantIds.contains(teacherId) &&
          c.participantIds.contains(parentId),
    );

    if (existingIndex != -1) {
      final existing = _conversations[existingIndex];
      if (initialMessage != null && initialMessage.isNotEmpty) {
        await sendMessage(
          conversationId: existing.id,
          senderId: teacherId,
          senderName: teacherName,
          senderRole: 'teacher',
          content: initialMessage,
        );
      }
      return existing;
    }

    final convo = Conversation(
      id: 'convo-teach-par-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Parent: $parentName ($studentName\'s Parent)',
      isGroup: false,
      participantIds: [teacherId, parentId],
      participantNames: [teacherName, parentName],
      lastMessage: initialMessage ?? 'Ustaz $teacherName started a conversation regarding $studentName.',
      lastMessageTime: DateTime.now(),
      halaqahId: halaqahId,
      groupType: 'direct_teacher',
    );

    _conversations.insert(0, convo);
    _conversationsController.add(List.from(_conversations));

    if (initialMessage != null && initialMessage.isNotEmpty) {
      await sendMessage(
        conversationId: convo.id,
        senderId: teacherId,
        senderName: teacherName,
        senderRole: 'teacher',
        content: initialMessage,
      );
    }

    // Notification for Parent
    NotificationCenterService.instance.addNotification(
      title: 'Message from Ustaz $teacherName 💬',
      body: 'Ustaz $teacherName started a discussion regarding $studentName.',
      type: 'chat',
      data: {'conversation_id': convo.id},
    );

    return convo;
  }

  /// Admin creates a new group conversation with parents
  Future<Conversation> createGroup({
    required String title,
    required List<String> parentIds,
    required List<String> parentNames,
    String? halaqahId,
  }) async {
    final convo = Conversation(
      id: 'convo-grp-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      isGroup: true,
      participantIds: ['admin-001', ...parentIds],
      participantNames: ['Admin Director', ...parentNames],
      lastMessage: 'Group created by Admin.',
      lastMessageTime: DateTime.now(),
      halaqahId: halaqahId,
      groupType: 'parent_group',
    );

    _conversations.insert(0, convo);
    _conversationsController.add(List.from(_conversations));

    await sendMessage(
      conversationId: convo.id,
      senderId: 'admin-001',
      senderName: 'Admin Director',
      senderRole: 'admin',
      content: 'As-salamu alaykum parents. Welcome to "$title".',
    );

    NotificationCenterService.instance.addNotification(
      title: 'New Group Created 👥',
      body: 'Admin created a new discussion group: "$title".',
      type: 'chat',
      data: {'conversation_id': convo.id},
    );

    return convo;
  }

  /// Admin starts a 1-on-1 direct conversation with an individual parent
  Future<Conversation> startDirectChatWithParent({
    required String parentId,
    required String parentName,
    String? initialMessage,
  }) async {
    final existingIndex = _conversations.indexWhere(
      (c) => !c.isGroup && c.participantIds.contains('admin-001') && c.participantIds.contains(parentId),
    );

    if (existingIndex != -1) {
      if (initialMessage != null && initialMessage.isNotEmpty) {
        await sendMessage(
          conversationId: _conversations[existingIndex].id,
          senderId: 'admin-001',
          senderName: 'Admin Director',
          senderRole: 'admin',
          content: initialMessage,
        );
      }
      return _conversations[existingIndex];
    }

    final convo = Conversation(
      id: 'convo-dir-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Direct Chat: $parentName',
      isGroup: false,
      participantIds: ['admin-001', parentId],
      participantNames: ['Admin Director', parentName],
      lastMessage: initialMessage ?? 'Conversation started with $parentName.',
      lastMessageTime: DateTime.now(),
      groupType: 'direct_admin',
    );

    _conversations.insert(0, convo);
    _conversationsController.add(List.from(_conversations));

    if (initialMessage != null && initialMessage.isNotEmpty) {
      await sendMessage(
        conversationId: convo.id,
        senderId: 'admin-001',
        senderName: 'Admin Director',
        senderRole: 'admin',
        content: initialMessage,
      );
    }

    return convo;
  }

  /// Parent starts conversation with Admin or child's halaqah Teacher
  Future<Conversation> startParentChat({
    required String parentId,
    required String parentName,
    required String targetRole, // 'admin' or 'teacher'
    required String targetName,
    String? halaqahName,
    String? initialMessage,
  }) async {
    final title = targetRole == 'admin'
        ? 'Center Director (Ustaz Muhammed)'
        : '$targetName (${halaqahName ?? 'Halaqah Teacher'})';

    final targetId = targetRole == 'admin' ? 'admin-001' : 'teach-001';

    final existingIndex = _conversations.indexWhere(
      (c) => !c.isGroup && c.participantIds.contains(parentId) && c.participantIds.contains(targetId),
    );

    if (existingIndex != -1) {
      return _conversations[existingIndex];
    }

    final convo = Conversation(
      id: 'convo-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      isGroup: false,
      participantIds: [parentId, targetId],
      participantNames: [parentName, targetName],
      lastMessage: initialMessage ?? 'Conversation initiated.',
      lastMessageTime: DateTime.now(),
      groupType: targetRole == 'admin' ? 'direct_admin' : 'direct_teacher',
    );

    _conversations.insert(0, convo);
    _conversationsController.add(List.from(_conversations));

    if (initialMessage != null && initialMessage.isNotEmpty) {
      await sendMessage(
        conversationId: convo.id,
        senderId: parentId,
        senderName: parentName,
        senderRole: 'parent',
        content: initialMessage,
      );
    }

    return convo;
  }
}
