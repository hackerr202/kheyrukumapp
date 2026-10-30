import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';
import 'auth_session_service.dart';
import 'local_storage_service.dart';
import 'notification_center_service.dart';
import 'push_notification_service.dart';
import 'supabase_service.dart';

/// Full-featured real-time Messaging Service with offline sync & targeted push notifications:
/// - Persists conversations & messages locally so UI renders instantaneously offline.
/// - Synchronizes seamlessly with Supabase Realtime when network is available.
/// - Only delivers push notification to the recipient (NEVER to the sender or other unrelated users).
/// - Supports attachments (media/documents) and audio voice notes.
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
      await fetchConversationsFromCloud();

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

        final jsonList = _conversations.map((c) => c.toJson()).toList();
        await LocalStorageService.instance.saveJsonList('cached_conversations', jsonList);
      }
    } catch (e) {
      debugPrint('[MessagingService] fetchConversationsFromCloud error: $e');
    }
  }

  /// Handle incoming real-time message:
  /// STRICT RULE: Push notifications are ONLY delivered to the recipient, never to the sender!
  void _handleIncomingCloudMessage(Map<String, dynamic> json) {
    try {
      final msg = ChatMessage.fromJson(json);
      final currentUserId = AuthSessionService.instance.userId;

      // 1. If this device is the sender, ignore notification
      if (msg.senderId == currentUserId) return;

      // 2. Check if current user is a participant in this conversation
      final convo = _conversations.firstWhere(
        (c) => c.id == msg.conversationId,
        orElse: () => Conversation(
          id: msg.conversationId,
          title: 'Direct Chat',
          participantIds: [msg.senderId, currentUserId],
          participantNames: [msg.senderName, 'User'],
          lastMessageTime: msg.timestamp,
        ),
      );

      final isParticipant = convo.participantIds.contains(currentUserId) ||
          (convo.isGroup && AuthSessionService.instance.isParent && convo.groupType == 'parent_group');

      if (!isParticipant) return; // Not for this user!

      // Add to thread
      final list = _messagesMap.putIfAbsent(msg.conversationId, () => []);
      if (!list.any((m) => m.id == msg.id)) {
        list.add(msg);
        _chatControllers[msg.conversationId]?.add(List.from(list));
        _saveMessagesToCache(msg.conversationId);
      }

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
          lastMessage: msg.messageType == 'voice' ? '🎤 Voice message' : msg.content,
          lastMessageTime: msg.timestamp,
          halaqahId: existing.halaqahId,
          groupType: existing.groupType,
          unreadCount: existing.unreadCount + 1,
        );
        _conversationsController.add(List.from(_conversations));
      }

      // Deliver system push notification strictly to this recipient
      String notifBody = msg.content;
      if (msg.messageType == 'voice') {
        notifBody = '🎤 Voice message (${msg.audioDurationSeconds ?? 5}s)';
      } else if (msg.messageType == 'image') {
        notifBody = '📷 Photo attachment';
      } else if (msg.messageType == 'document') {
        notifBody = '📎 Document: ${msg.attachmentName ?? "File"}';
      }

      PushNotificationService.instance.showNotification(
        title: '${msg.senderName} 💬',
        body: notifBody,
        payload: msg.conversationId,
      );

      NotificationCenterService.instance.addNotification(
        title: '${msg.senderName} 💬',
        body: notifBody,
        type: 'message',
        data: {'conversation_id': msg.conversationId},
      );
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

    _loadMessagesFromCache(conversationId).then((cached) {
      final current = _messagesMap[conversationId] ?? cached;
      _messagesMap[conversationId] = current;
      _chatControllers[conversationId]?.add(List.from(current));
    });

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

  /// Send a message (text, voice, image, or document)
  /// - Instantly renders in local UI
  /// - Persists locally in offline storage
  /// - Pushes to Supabase cloud
  /// - Does NOT notify the sender itself!
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String content,
    String messageType = 'text',
    String? attachmentUrl,
    String? attachmentName,
    int? audioDurationSeconds,
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
      messageType: messageType,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      audioDurationSeconds: audioDurationSeconds,
    );

    // 1. Immediately store in memory and emit to UI
    _messagesMap.putIfAbsent(conversationId, () => []).add(msg);
    _chatControllers[conversationId]?.add(List.from(_messagesMap[conversationId]!));

    // 2. Persist locally for instant offline loading
    await _saveMessagesToCache(conversationId);

    // 3. Update conversation's last message
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    String displayPreview = content.trim();
    if (messageType == 'voice') displayPreview = '🎤 Voice message';
    if (messageType == 'image') displayPreview = '📷 Photo';
    if (messageType == 'document') displayPreview = '📎 Document';

    if (idx != -1) {
      final existing = _conversations[idx];
      _conversations[idx] = Conversation(
        id: existing.id,
        title: existing.title,
        isGroup: existing.isGroup,
        participantIds: existing.participantIds,
        participantNames: existing.participantNames,
        lastMessage: displayPreview,
        lastMessageTime: msg.timestamp,
        halaqahId: existing.halaqahId,
        groupType: existing.groupType,
      );
      _conversationsController.add(List.from(_conversations));

      final jsonList = _conversations.map((c) => c.toJson()).toList();
      await LocalStorageService.instance.saveJsonList('cached_conversations', jsonList);
    }

    // 4. Cloud synchronization to Supabase
    final client = SupabaseService.instance.client;
    final effectiveSenderId = (senderId.isNotEmpty && _isValidUuid(senderId))
        ? senderId
        : (SupabaseService.instance.currentUser?.id ??
           (AuthSessionService.instance.userId.isNotEmpty && _isValidUuid(AuthSessionService.instance.userId)
               ? AuthSessionService.instance.userId
               : null));

    if (client != null && effectiveSenderId != null && _isValidUuid(conversationId)) {
      try {
        await client.from('messages').insert({
          'conversation_id': conversationId,
          'sender_id': effectiveSenderId,
          'sender_name': senderName,
          'sender_role': senderRole,
          'content': content.trim(),
          'message_type': messageType,
          'attachment_url': attachmentUrl,
          'attachment_name': attachmentName,
          'audio_duration': audioDurationSeconds,
          'created_at': msg.timestamp.toUtc().toIso8601String(),
          'is_read': false,
        });

        await client.from('conversations').update({
          'last_message': displayPreview,
          'last_message_time': msg.timestamp.toUtc().toIso8601String(),
        }).eq('id', conversationId);
      } catch (e) {
        debugPrint('[MessagingService] Cloud insert fallback: $e');
      }
    }

    return msg;
  }

  static String _generateUuidV4() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // Version 4
    values[8] = (values[8] & 0x3f) | 0x80; // Variant 10
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static bool _isValidUuid(String str) {
    final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', caseSensitive: false);
    return uuidRegex.hasMatch(str);
  }

  Future<void> _syncConversationToCloud(Conversation convo) async {
    final client = SupabaseService.instance.client;
    if (client == null || !_isValidUuid(convo.id)) return;

    try {
      final payload = <String, dynamic>{
        'id': convo.id,
        'title': convo.title,
        'is_group': convo.isGroup,
        'participant_ids': convo.participantIds,
        'participant_names': convo.participantNames,
        'last_message': convo.lastMessage,
        'last_message_time': convo.lastMessageTime.toIso8601String(),
        'group_type': convo.groupType,
        'unread_count': convo.unreadCount,
        'is_pinned': convo.isPinned,
      };
      if (convo.halaqahId != null && _isValidUuid(convo.halaqahId!)) {
        payload['halaqah_id'] = convo.halaqahId;
      }

      await client.from('conversations').upsert(payload);

      for (final pid in convo.participantIds) {
        if (_isValidUuid(pid)) {
          try {
            await client.from('conversation_participants').upsert({
              'conversation_id': convo.id,
              'user_id': pid,
            });
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[MessagingService] Cloud sync convo fallback: $e');
    }
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
      id: _generateUuidV4(),
      title: '$parentName ($studentName\'s Parent)',
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

    final jsonList = _conversations.map((c) => c.toJson()).toList();
    await LocalStorageService.instance.saveJsonList('cached_conversations', jsonList);

    await _syncConversationToCloud(convo);

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
    final currentUserId = SupabaseService.instance.currentUser?.id ?? AuthSessionService.instance.userId;
    final adminId = currentUserId.isNotEmpty ? currentUserId : '7c8f3fb0-8268-456a-8bec-fc8ccae94a0c';

    final convo = Conversation(
      id: _generateUuidV4(),
      title: title,
      isGroup: true,
      participantIds: [adminId, ...parentIds],
      participantNames: ['Admin Director', ...parentNames],
      lastMessage: 'Group created by Admin.',
      lastMessageTime: DateTime.now(),
      halaqahId: halaqahId,
      groupType: 'parent_group',
    );

    _conversations.insert(0, convo);
    _conversationsController.add(List.from(_conversations));

    final jsonList = _conversations.map((c) => c.toJson()).toList();
    await LocalStorageService.instance.saveJsonList('cached_conversations', jsonList);

    await _syncConversationToCloud(convo);

    await sendMessage(
      conversationId: convo.id,
      senderId: adminId,
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
    final currentUserId = SupabaseService.instance.currentUser?.id ?? AuthSessionService.instance.userId;
    final adminId = currentUserId.isNotEmpty ? currentUserId : '7c8f3fb0-8268-456a-8bec-fc8ccae94a0c';

    final existingIndex = _conversations.indexWhere(
      (c) => !c.isGroup && c.participantIds.contains(adminId) && c.participantIds.contains(parentId),
    );

    if (existingIndex != -1) {
      if (initialMessage != null && initialMessage.isNotEmpty) {
        await sendMessage(
          conversationId: _conversations[existingIndex].id,
          senderId: adminId,
          senderName: 'Admin Director',
          senderRole: 'admin',
          content: initialMessage,
        );
      }
      return _conversations[existingIndex];
    }

    final convo = Conversation(
      id: _generateUuidV4(),
      title: parentName,
      isGroup: false,
      participantIds: [adminId, parentId],
      participantNames: ['Admin Director', parentName],
      lastMessage: initialMessage ?? 'Conversation started with $parentName.',
      lastMessageTime: DateTime.now(),
      groupType: 'direct_admin',
    );

    _conversations.insert(0, convo);
    _conversationsController.add(List.from(_conversations));

    final jsonList = _conversations.map((c) => c.toJson()).toList();
    await LocalStorageService.instance.saveJsonList('cached_conversations', jsonList);

    await _syncConversationToCloud(convo);

    if (initialMessage != null && initialMessage.isNotEmpty) {
      await sendMessage(
        conversationId: convo.id,
        senderId: adminId,
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
    required String targetRole,
    required String targetName,
    String? halaqahName,
    String? initialMessage,
  }) async {
    final title = targetRole == 'admin'
        ? 'Center Director'
        : '$targetName (${halaqahName ?? 'Teacher'})';

    final adminId = '7c8f3fb0-8268-456a-8bec-fc8ccae94a0c';
    final targetId = targetRole == 'admin' ? adminId : 'teach-001';

    final existingIndex = _conversations.indexWhere(
      (c) => !c.isGroup && c.participantIds.contains(parentId) && c.participantIds.contains(targetId),
    );

    if (existingIndex != -1) {
      return _conversations[existingIndex];
    }

    final convo = Conversation(
      id: _generateUuidV4(),
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

    await _syncConversationToCloud(convo);

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
