import 'dart:async';
import '../models/chat_message.dart';
import 'notification_center_service.dart';

/// Messaging service managing:
/// - Admin creating groups with parents or direct 1-on-1 chats
/// - Parent initiating conversations with Admin or child's halaqah Teachers
/// - Real-time message streaming
class MessagingService {
  MessagingService._() {
    _initSampleConversations();
  }

  static final MessagingService instance = MessagingService._();

  final List<Conversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messagesMap = {};

  final StreamController<List<Conversation>> _conversationsController =
      StreamController<List<Conversation>>.broadcast();

  final Map<String, StreamController<List<ChatMessage>>> _chatControllers = {};

  Stream<List<Conversation>> get conversationsStream => _conversationsController.stream;

  List<Conversation> get allConversations => List.unmodifiable(_conversations);

  void _initSampleConversations() {
    // 1. Group conversation created by Admin with all parents
    final groupConvo = Conversation(
      id: 'convo-group-01',
      title: 'Halaqah Abu Bakr - All Parents 📢',
      isGroup: true,
      participantIds: ['admin-001', 'par-001', 'par-002'],
      participantNames: ['Admin Director', 'Muhammed Yakut', 'Khalid Al-Mansoor'],
      lastMessage: 'As-salamu alaykum parents. Tomorrow will be cumulative Juz 30 review.',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
      halaqahId: 'hal-001',
      groupType: 'parent_group',
    );

    // 2. Direct chat between Admin and Parent (Muhammed Yakut)
    final directConvo = Conversation(
      id: 'convo-direct-01',
      title: 'Direct Chat: Ustaz Muhammed Yakut (Admin)',
      isGroup: false,
      participantIds: ['admin-001', 'par-001'],
      participantNames: ['Admin Director', 'Muhammed Yakut'],
      lastMessage: 'Abdur-Rahman has shown great progress in Surah Al-Mulk this week.',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 45)),
      groupType: 'direct_admin',
    );

    // 3. Direct chat between Parent and Teacher (Ustadha Maryam - Fatima's teacher)
    final teacherConvo = Conversation(
      id: 'convo-teacher-01',
      title: 'Ustadha Maryam (Halaqah Aisha)',
      isGroup: false,
      participantIds: ['teach-002', 'par-001'],
      participantNames: ['Ustadha Maryam', 'Muhammed Yakut'],
      lastMessage: 'Fatima\'s Tajweed recitation was lovely today. Please practice Ayah 10 at home.',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
      groupType: 'direct_teacher',
    );

    _conversations.addAll([groupConvo, directConvo, teacherConvo]);

    // Initial messages for group
    _messagesMap['convo-group-01'] = [
      ChatMessage(
        id: 'msg-01',
        conversationId: 'convo-group-01',
        senderId: 'admin-001',
        senderName: 'Admin Director',
        senderRole: 'admin',
        content: 'Bismillah. Welcome to the official parents group for Halaqah Abu Bakr.',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        isRead: true,
      ),
      ChatMessage(
        id: 'msg-02',
        conversationId: 'convo-group-01',
        senderId: 'par-001',
        senderName: 'Muhammed Yakut',
        senderRole: 'parent',
        content: 'Jazakumullahu Khayran Ustaz for organizing this.',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isRead: true,
      ),
      ChatMessage(
        id: 'msg-03',
        conversationId: 'convo-group-01',
        senderId: 'admin-001',
        senderName: 'Admin Director',
        senderRole: 'admin',
        content: 'As-salamu alaykum parents. Tomorrow will be cumulative Juz 30 review.',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: true,
      ),
    ];

    // Initial messages for direct admin chat
    _messagesMap['convo-direct-01'] = [
      ChatMessage(
        id: 'msg-04',
        conversationId: 'convo-direct-01',
        senderId: 'par-001',
        senderName: 'Muhammed Yakut',
        senderRole: 'parent',
        content: 'As-salamu alaykum Ustaz, how is Abdur-Rahman performing in his daily Sabaq?',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        isRead: true,
      ),
      ChatMessage(
        id: 'msg-05',
        conversationId: 'convo-direct-01',
        senderId: 'admin-001',
        senderName: 'Admin Director',
        senderRole: 'admin',
        content: 'Abdur-Rahman has shown great progress in Surah Al-Mulk this week.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
        isRead: true,
      ),
    ];

    // Initial messages for teacher chat
    _messagesMap['convo-teacher-01'] = [
      ChatMessage(
        id: 'msg-06',
        conversationId: 'convo-teacher-01',
        senderId: 'teach-002',
        senderName: 'Ustadha Maryam',
        senderRole: 'teacher',
        content: 'Fatima\'s Tajweed recitation was lovely today. Please practice Ayah 10 at home.',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isRead: true,
      ),
    ];

    _conversationsController.add(List.from(_conversations));
  }

  /// Get conversations relevant for a user (or all if admin)
  List<Conversation> getConversationsForUser(String userId, {bool isAdmin = false}) {
    if (isAdmin) return _conversations;
    return _conversations.where((c) => c.participantIds.contains(userId) || c.isGroup).toList();
  }

  /// Stream messages for a specific conversation
  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    if (!_chatControllers.containsKey(conversationId)) {
      _chatControllers[conversationId] = StreamController<List<ChatMessage>>.broadcast();
    }
    // Emit current messages immediately
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

    // Add first message
    await sendMessage(
      conversationId: convo.id,
      senderId: 'admin-001',
      senderName: 'Admin Director',
      senderRole: 'admin',
      content: 'As-salamu alaykum parents. Welcome to "$title".',
    );

    // Notify parents
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
    // Check if direct conversation already exists
    final existingIndex = _conversations.indexWhere(
      (c) => !c.isGroup && c.participantIds.contains(parentId),
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

    final convo = Conversation(
      id: 'convo-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      isGroup: false,
      participantIds: [parentId, targetRole == 'admin' ? 'admin-001' : 'teach-001'],
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
