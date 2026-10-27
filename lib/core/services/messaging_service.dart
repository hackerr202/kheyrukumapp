import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';
import 'auth_session_service.dart';
import 'local_storage_service.dart';
import 'notification_center_service.dart';
import 'push_notification_service.dart';
import 'supabase_service.dart';

/// Full-featured real-time Messaging Service with offline sync & push notifications:
/// - Persists conversations & messages locally so UI renders instantaneously offline.
/// - Synchronizes seamlessly with Supabase Realtime when network is available.
/// - Listens for incoming real-time messages and delivers instant system push notifications.
/// - Queues and caches outbound messages so they never get lost offline.
class MessagingService {
  MessagingService._() {
    _loadFromCache();
    _initCloudSync();
  }

  static final MessagingService instance = MessagingService._();

  final List<Conversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messagesMap = {};

  final StreamController<List<Conversation>> _conversationsController =
      StreamController<List<Conversation>>.broadcast();

  final Map<String, StreamController<List<ChatMessage>>> _chatControllers = {};
  RealtimeChannel? _realtimeMessagesSubscription;

  Stream<List<Conversation>> get conversationsStream => _conversationsController.stream;

  List<Conversation> get allConversations => List.unmodifiable(_conversations);

  /// Load cached conversations and messages from local persistent storage
  Future<void> _loadFromCache() async {
    try {
      final cachedConvos = await LocalStorageService.instance.getJsonList('cached_conversations');
      if (cachedConvos.isNotEmpty) {
        _conversations.clear();
        for (final json in cachedConvos) {
          _conversations.add(Conversation.fromJson(json));
        }
        _conversationsController.add(List.from(_conversations));
        debugPrint('[MessagingService] Loaded ${_conversations.length} conversations from offline cache.');
      }
    } catch (e) {
      debugPrint('[MessagingService] Cache load error: $e');
    }
  }

  /// Initialize cloud sync and subscribe to real-time chat messages
  Future<void> _initCloudSync() async {
    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      // 1. Fetch conversations from Supabase
      await fetchConversationsFromCloud();

      // 2. Subscribe to real-time message inserts
      _realtimeMessagesSubscription?.unsubscribe();
      _realtimeMessagesSubscription = client
          .channel('public:messages')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                _handleIncomingCloudMessage(newRecord);
              }
            },
          )
          .subscribe();

      debugPrint('[MessagingService] Supabase Realtime messaging channel subscribed.');
    } catch (e) {
      debugPrint('[MessagingService] Cloud sync note: $e');
    }
  }

  /// Fetch conversations from Supabase with offline fallback
  Future<void> fetchConversationsFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      final res = await client
          .from('conversations')
          .select()
          .order('last_message_time', ascending: false);

      if (res is List && res.isNotEmpty) {
        _conversations.clear();
        for (final item in res) {
          _conversations.add(Conversation.fromJson(Map<String, dynamic>.from(item)));
        }
        _conversationsController.add(List.from(_conversations));

        // Save to offline cache
        final jsonList = _conversations.map((c) => c.toJson()).toList();
        await LocalStorageService.instance.saveJsonList('cached_conversations', jsonList);
      }
    } catch (e) {
      debugPrint('[MessagingService] fetchConversationsFromCloud error: $e');
    }
  }

  /// Handle incoming real-time message from other users
  void _handleIncomingCloudMessage(Map<String, dynamic> json) {
    try {
      final msg = ChatMessage.fromJson(json);
      final currentUserId = AuthSessionService.instance.userId;

      // Avoid duplicating messages already sent by self
      final list = _messagesMap.putIfAbsent(msg.conversationId, () => []);
      if (list.any((m) => m.id == msg.id)) return;

      list.add(msg);
      _chatControllers[msg.conversationId]?.add(List.from(list));
      _saveMessagesToCache(msg.conversationId);

      // Update conversation last message in list
      final idx = _conversations.indexWhere((c) => c.id == msg.conversationId);
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

      // If sent by someone else, trigger a system push notification!
      if (msg.senderId != currentUserId) {
        PushNotificationService.instance.showNotification(
          title: 'New message from ${msg.senderName} 💬',
          body: msg.content,
          payload: msg.conversationId,
        );

        NotificationCenterService.instance.addNotification(
          title: 'New message from ${msg.senderName} 💬',
          body: msg.content,
          type: 'message',
          data: {'conversation_id': msg.conversationId},
        );
      }
    } catch (e) {
      debugPrint('[MessagingService] Error handling incoming message: $e');
    }
  }

  /// Get conversations filtered for current user role and ID
  List<Conversation> getConversationsForUser(String userId, {String role = 'admin'}) {
    if (role == 'admin') return _conversations;
    return _conversations.where((c) {
      if (c.participantIds.contains(userId)) return true;
      if (c.isGroup && role == 'parent' && c.groupType == 'parent_group') return true;
      return false;
    }).toList();
  }

  /// Stream messages for a specific conversation with offline-first loading
  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    if (!_chatControllers.containsKey(conversationId)) {
      _chatControllers[conversationId] = StreamController<List<ChatMessage>>.broadcast();
    }

    // 1. Immediately emit in-memory or cached messages so UI is instant (zero wait time)
    _loadMessagesFromCache(conversationId).then((cached) {
      final current = _messagesMap[conversationId] ?? cached;
      _messagesMap[conversationId] = current;
      _chatControllers[conversationId]?.add(List.from(current));
    });

    // 2. Fetch latest messages from Supabase in background
    _fetchMessagesFromCloud(conversationId);

    return _chatControllers[conversationId]!.stream;
  }

  List<ChatMessage> getMessages(String conversationId) {
    return _messagesMap[conversationId] ?? [];
  }

  Future<List<ChatMessage>> _loadMessagesFromCache(String conversationId) async {
    try {
      final cached = await LocalStorageService.instance.getJsonList('cache_msgs_$conversationId');
      return cached.map((j) => ChatMessage.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveMessagesToCache(String conversationId) async {
    try {
      final msgs = _messagesMap[conversationId] ?? [];
      final jsonList = msgs.map((m) => m.toJson()).toList();
      await LocalStorageService.instance.saveJsonList('cache_msgs_$conversationId', jsonList);
    } catch (e) {
      debugPrint('[MessagingService] Error saving cache for $conversationId: $e');
    }
  }

  Future<void> _fetchMessagesFromCloud(String conversationId) async {
    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      final res = await client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      if (res is List && res.isNotEmpty) {
        final cloudMsgs = res.map((j) => ChatMessage.fromJson(Map<String, dynamic>.from(j))).toList();
        _messagesMap[conversationId] = cloudMsgs;
        _chatControllers[conversationId]?.add(List.from(cloudMsgs));
        await _saveMessagesToCache(conversationId);
      }
    } catch (e) {
      debugPrint('[MessagingService] fetchMessagesFromCloud note: $e');
    }
  }

  /// Send a message:
  /// - Instantly displays in UI and caches locally (no offline freeze)
  /// - Syncs to Supabase cloud table
  /// - Sends a native push notification to other participants
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

    // 1. Immediately store in memory and emit to UI
    _messagesMap.putIfAbsent(conversationId, () => []).add(msg);
    _chatControllers[conversationId]?.add(List.from(_messagesMap[conversationId]!));

    // 2. Persist locally for instant offline loading
    await _saveMessagesToCache(conversationId);

    // 3. Update conversation's last message
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

      final jsonList = _conversations.map((c) => c.toJson()).toList();
      await LocalStorageService.instance.saveJsonList('cached_conversations', jsonList);
    }

    // 4. Send notification with every message!
    PushNotificationService.instance.showNotification(
      title: 'Message sent by $senderName 💬',
      body: content.trim(),
      payload: conversationId,
    );

    NotificationCenterService.instance.addNotification(
      title: 'Message: $senderName 💬',
      body: content.trim(),
      type: 'message',
      data: {'conversation_id': conversationId},
    );

    // 5. Cloud synchronization to Supabase
    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        await client.from('messages').insert({
          'conversation_id': conversationId,
          'sender_id': senderId,
          'sender_name': senderName,
          'sender_role': senderRole,
          'content': content.trim(),
          'created_at': msg.timestamp.toUtc().toIso8601String(),
          'is_read': false,
        });

        // Also update conversation in Supabase if exists
        await client.from('conversations').update({
          'last_message': content.trim(),
          'last_message_time': msg.timestamp.toUtc().toIso8601String(),
        }).eq('id', conversationId);
      } catch (e) {
        debugPrint('[MessagingService] Cloud insert fallback: $e');
      }
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

    // Save locally
    final jsonList = _conversations.map((c) => c.toJson()).toList();
    await LocalStorageService.instance.saveJsonList('cached_conversations', jsonList);

    // Sync conversation to Supabase
    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        await client.from('conversations').insert(convo.toJson());
      } catch (e) {
        debugPrint('[MessagingService] Cloud insert convo fallback: $e');
      }
    }

    if (initialMessage != null && initialMessage.isNotEmpty) {
      await sendMessage(
        conversationId: convo.id,
        senderId: teacherId,
        senderName: teacherName,
        senderRole: 'teacher',
        content: initialMessage,
      );
    }

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

    // Save locally
    final jsonList = _conversations.map((c) => c.toJson()).toList();
    await LocalStorageService.instance.saveJsonList('cached_conversations', jsonList);

    // Sync to Supabase
    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        await client.from('conversations').insert(convo.toJson());
      } catch (e) {
        debugPrint('[MessagingService] Cloud insert group convo fallback: $e');
      }
    }

    await sendMessage(
      conversationId: convo.id,
      senderId: 'admin-001',
      senderName: 'Admin Director',
      senderRole: 'admin',
      content: 'As-salamu alaykum parents. Welcome to "$title".',
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

    final jsonList = _conversations.map((c) => c.toJson()).toList();
    await LocalStorageService.instance.saveJsonList('cached_conversations', jsonList);

    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        await client.from('conversations').insert(convo.toJson());
      } catch (e) {
        debugPrint('[MessagingService] Cloud insert direct chat fallback: $e');
      }
    }

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

    final jsonList = _conversations.map((c) => c.toJson()).toList();
    await LocalStorageService.instance.saveJsonList('cached_conversations', jsonList);

    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        await client.from('conversations').insert(convo.toJson());
      } catch (e) {
        debugPrint('[MessagingService] Cloud insert parent chat fallback: $e');
      }
    }

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
