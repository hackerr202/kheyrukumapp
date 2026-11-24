import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';
import 'auth_session_service.dart';
import 'local_storage_service.dart';
import 'push_notification_service.dart';
import 'supabase_service.dart';

/// Full-featured real-time Messaging Service with offline sync & targeted push notifications.
class MessagingService {
  MessagingService._();

  static final MessagingService instance = MessagingService._();

  final List<Conversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messagesMap = {};
  bool _cacheLoaded = false;

  final StreamController<List<Conversation>> _conversationsController =
      StreamController<List<Conversation>>.broadcast();

  final Map<String, StreamController<List<ChatMessage>>> _chatControllers = {};
  RealtimeChannel? _realtimeMessagesSubscription;
  RealtimeChannel? _realtimeConvosSubscription;

  Stream<List<Conversation>> get conversationsStream =>
      _conversationsController.stream;

  List<Conversation> get allConversations => List.unmodifiable(_conversations);

  Future<void> refreshAndSubscribe() async {
    await _loadFromCache();
    await _initCloudSync();
  }

  Future<void> clearOnLogout() async {
    final client = SupabaseService.instance.client;
    final msgCh = _realtimeMessagesSubscription;
    final convoCh = _realtimeConvosSubscription;
    _realtimeMessagesSubscription = null;
    _realtimeConvosSubscription = null;

    if (msgCh != null) {
      try {
        await client?.removeChannel(msgCh);
      } catch (e) {
        debugPrint('[MessagingService] remove messages channel note: $e');
      }
    }
    if (convoCh != null) {
      try {
        await client?.removeChannel(convoCh);
      } catch (e) {
        debugPrint('[MessagingService] remove convos channel note: $e');
      }
    }

    for (final ctrl in _chatControllers.values) {
      if (!ctrl.isClosed) {
        await ctrl.close();
      }
    }
    _chatControllers.clear();
    _conversations.clear();
    _messagesMap.clear();
    _cacheLoaded = false;

    if (!_conversationsController.isClosed) {
      _conversationsController.add([]);
    }
    await LocalStorageService.instance.remove('cached_conversations');
    await LocalStorageService.instance.removeByPrefix('cache_msgs_');
  }

  Future<void> _loadFromCache() async {
    if (_cacheLoaded) return;
    _cacheLoaded = true;
    try {
      final cachedConvos =
          await LocalStorageService.instance.getJsonList('cached_conversations');
      if (cachedConvos.isNotEmpty && _conversations.isEmpty) {
        _conversations.clear();
        for (final json in cachedConvos) {
          _conversations.add(Conversation.fromJson(json));
        }
        if (!_conversationsController.isClosed) {
          _conversationsController.add(List.from(_conversations));
        }
        debugPrint(
            '[MessagingService] Loaded ${_conversations.length} conversations from offline cache.');
      }
    } catch (e) {
      debugPrint('[MessagingService] Cache load error: $e');
    }
  }

  Future<void> _initCloudSync() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;

    try {
      await fetchConversationsFromCloud();

      final oldConvoCh = _realtimeConvosSubscription;
      _realtimeConvosSubscription = null;
      if (oldConvoCh != null) {
        await client.removeChannel(oldConvoCh);
      }
      _realtimeConvosSubscription = client
          .channel('public:conversations')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'conversations',
            callback: (_) => fetchConversationsFromCloud(),
          )
          .subscribe();

      final oldMsgCh = _realtimeMessagesSubscription;
      _realtimeMessagesSubscription = null;
      if (oldMsgCh != null) {
        await client.removeChannel(oldMsgCh);
      }
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
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final updatedRecord = payload.newRecord;
              if (updatedRecord.isNotEmpty) {
                _handleUpdatedCloudMessage(updatedRecord);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final deletedRecord = payload.oldRecord;
              if (deletedRecord.isNotEmpty) {
                _handleDeletedCloudMessage(deletedRecord);
              }
            },
          )
          .subscribe();

      debugPrint(
          '[MessagingService] Supabase Realtime messaging channel subscribed.');
    } catch (e) {
      debugPrint('[MessagingService] Cloud sync note: $e');
    }
  }

  /// Fetch conversations from Supabase (clears stale cache when cloud returns empty).
  Future<void> fetchConversationsFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;

    try {
      final res = await client
          .from('conversations')
          .select()
          .order('last_message_time', ascending: false);

      if (res is List) {
        _conversations.clear();
        for (final item in res) {
          _conversations
              .add(Conversation.fromJson(Map<String, dynamic>.from(item as Map)));
        }
        if (!_conversationsController.isClosed) {
          _conversationsController.add(List.from(_conversations));
        }

        final jsonList = _conversations.map((c) => c.toJson()).toList();
        await LocalStorageService.instance
            .saveJsonList('cached_conversations', jsonList);
      }
    } catch (e) {
      debugPrint('[MessagingService] fetchConversationsFromCloud error: $e');
    }
  }

  Future<void> _handleIncomingCloudMessage(Map<String, dynamic> json) async {
    try {
      final msg = ChatMessage.fromJson(json);
      final currentUserId = AuthSessionService.instance.userId;
      if (currentUserId.isEmpty) return;

      if (msg.senderId == currentUserId) return;

      var idx = _conversations.indexWhere((c) => c.id == msg.conversationId);
      if (idx == -1) {
        await fetchConversationsFromCloud();
        idx = _conversations.indexWhere((c) => c.id == msg.conversationId);
        if (idx == -1) return;
      }

      final convo = _conversations[idx];
      final isParticipant = convo.participantIds.contains(currentUserId) ||
          AuthSessionService.instance.isAdmin ||
          (convo.isGroup &&
              AuthSessionService.instance.isParent &&
              convo.groupType == 'parent_group');

      if (!isParticipant) return;

      final list = _messagesMap.putIfAbsent(msg.conversationId, () => []);
      if (!list.any((m) => m.id == msg.id)) {
        list.add(msg);
        final ctrl = _chatControllers[msg.conversationId];
        if (ctrl != null && !ctrl.isClosed) {
          ctrl.add(List.from(list));
        }
        await _saveMessagesToCache(msg.conversationId);
      }

      _conversations[idx] = Conversation(
        id: convo.id,
        title: convo.title,
        isGroup: convo.isGroup,
        participantIds: convo.participantIds,
        participantNames: convo.participantNames,
        lastMessage:
            msg.messageType == 'voice' ? '🎤 Voice message' : msg.content,
        lastMessageTime: msg.timestamp,
        halaqahId: convo.halaqahId,
        groupType: convo.groupType,
        unreadCount: convo.unreadCount + 1,
        isPinned: convo.isPinned,
      );
      if (!_conversationsController.isClosed) {
        _conversationsController.add(List.from(_conversations));
      }

      String notifBody = msg.content;
      if (msg.messageType == 'voice') {
        notifBody = '🎤 Voice message (${msg.audioDurationSeconds ?? 5}s)';
      } else if (msg.messageType == 'image') {
        notifBody = '📷 Photo attachment';
      } else if (msg.messageType == 'document') {
        notifBody = '📎 Document: ${msg.attachmentName ?? "File"}';
      }

      PushNotificationService.instance.showNotification(
        title: msg.senderName,
        body: notifBody,
        payload: msg.conversationId,
        type: 'message',
      );
    } catch (e) {
      debugPrint('[MessagingService] Error handling incoming message: $e');
    }
  }

  void _handleUpdatedCloudMessage(Map<String, dynamic> json) {
    try {
      final msg = ChatMessage.fromJson(json);
      final list = _messagesMap[msg.conversationId];
      if (list == null) return;
      final idx = list.indexWhere((m) => m.id == msg.id);
      if (idx != -1) {
        list[idx] = msg;
        final ctrl = _chatControllers[msg.conversationId];
        if (ctrl != null && !ctrl.isClosed) {
          ctrl.add(List.from(list));
        }
        _saveMessagesToCache(msg.conversationId);
      }
    } catch (e) {
      debugPrint('[MessagingService] Error handling updated message: $e');
    }
  }

  void _handleDeletedCloudMessage(Map<String, dynamic> json) {
    try {
      final deletedId = json['id']?.toString();
      final convoId = json['conversation_id']?.toString();
      if (deletedId == null || convoId == null) return;
      final list = _messagesMap[convoId];
      if (list == null) return;
      list.removeWhere((m) => m.id == deletedId);
      final ctrl = _chatControllers[convoId];
      if (ctrl != null && !ctrl.isClosed) {
        ctrl.add(List.from(list));
      }
      _saveMessagesToCache(convoId);
    } catch (e) {
      debugPrint('[MessagingService] Error handling deleted message: $e');
    }
  }

  /// Mark a conversation read cleanly via service + emit updated list.
  Future<void> markConversationRead(String conversationId) async {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx == -1) return;
    if (_conversations[idx].unreadCount == 0) return;

    _conversations[idx].unreadCount = 0;
    if (!_conversationsController.isClosed) {
      _conversationsController.add(List.from(_conversations));
    }
    final jsonList = _conversations.map((c) => c.toJson()).toList();
    await LocalStorageService.instance
        .saveJsonList('cached_conversations', jsonList);
  }

  /// Get conversations filtered for current user role and ID
  List<Conversation> getConversationsForUser(String userId,
      {String role = 'admin'}) {
    if (role == 'admin' || role == 'superadmin') return _conversations;
    return _conversations.where((c) {
      if (userId.isNotEmpty && c.participantIds.contains(userId)) return true;
      if (c.isGroup && role == 'parent' && c.groupType == 'parent_group') {
        return true;
      }
      return false;
    }).toList();
  }

  /// Stream messages for a specific conversation with offline-first loading
  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    if (!_chatControllers.containsKey(conversationId) ||
        _chatControllers[conversationId]!.isClosed) {
      _chatControllers[conversationId] =
          StreamController<List<ChatMessage>>.broadcast();
    }

    _loadMessagesFromCache(conversationId).then((cached) {
      final current = _messagesMap[conversationId] ?? cached;
      _messagesMap[conversationId] = current;
      final ctrl = _chatControllers[conversationId];
      if (ctrl != null && !ctrl.isClosed) {
        ctrl.add(List.from(current));
      }
    });

    _fetchMessagesFromCloud(conversationId);

    return _chatControllers[conversationId]!.stream;
  }

  List<ChatMessage> getMessages(String conversationId) {
    return _messagesMap[conversationId] ?? [];
  }

  Future<List<ChatMessage>> _loadMessagesFromCache(
      String conversationId) async {
    try {
      final cached = await LocalStorageService.instance
          .getJsonList('cache_msgs_$conversationId');
      return cached.map((j) => ChatMessage.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveMessagesToCache(String conversationId) async {
    try {
      final msgs = _messagesMap[conversationId] ?? [];
      final jsonList = msgs.map((m) => m.toJson()).toList();
      await LocalStorageService.instance
          .saveJsonList('cache_msgs_$conversationId', jsonList);
    } catch (e) {
      debugPrint('[MessagingService] Error saving cache for $conversationId: $e');
    }
  }

  Future<void> _fetchMessagesFromCloud(String conversationId) async {
    final client = SupabaseService.instance.client;
    if (client == null ||
        SupabaseService.instance.currentUser == null ||
        !_isValidUuid(conversationId)) {
      return;
    }

    try {
      final res = await client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      if (res is List) {
        final cloudMsgs = res
            .map((j) => ChatMessage.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _messagesMap[conversationId] = cloudMsgs;
        final ctrl = _chatControllers[conversationId];
        if (ctrl != null && !ctrl.isClosed) {
          ctrl.add(List.from(cloudMsgs));
        }
        await _saveMessagesToCache(conversationId);
      }
    } catch (e) {
      debugPrint('[MessagingService] fetchMessagesFromCloud note: $e');
    }
  }

  /// Send a message (cloud first; rolls back and throws on failure so UI knows & no phantom push fires)
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
    final client = SupabaseService.instance.client;
    final effectiveSenderId = (senderId.isNotEmpty && _isValidUuid(senderId))
        ? senderId
        : (SupabaseService.instance.currentUser?.id ??
            (AuthSessionService.instance.userId.isNotEmpty &&
                    _isValidUuid(AuthSessionService.instance.userId)
                ? AuthSessionService.instance.userId
                : null));

    if (client == null ||
        effectiveSenderId == null ||
        !_isValidUuid(conversationId)) {
      throw Exception('Cannot send message: invalid session or server connection.');
    }

    final msg = ChatMessage(
      id: _generateUuidV4(),
      conversationId: conversationId,
      senderId: effectiveSenderId,
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

    String displayPreview = content.trim();
    if (messageType == 'voice') displayPreview = '🎤 Voice message';
    if (messageType == 'image') displayPreview = '📷 Photo';
    if (messageType == 'document') displayPreview = '📎 Document';

    await client.from('messages').insert({
      'id': msg.id,
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

    // Update memory & offline cache only after cloud persistence succeeds
    _messagesMap.putIfAbsent(conversationId, () => []).add(msg);
    final ctrl = _chatControllers[conversationId];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(List.from(_messagesMap[conversationId]!));
    }
    await _saveMessagesToCache(conversationId);

    final idx = _conversations.indexWhere((c) => c.id == conversationId);
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
        unreadCount: existing.unreadCount,
        isPinned: existing.isPinned,
      );
      if (!_conversationsController.isClosed) {
        _conversationsController.add(List.from(_conversations));
      }

      final jsonList = _conversations.map((c) => c.toJson()).toList();
      await LocalStorageService.instance
          .saveJsonList('cached_conversations', jsonList);

      final convo = _conversations[idx];
      final recipientIds = convo.participantIds
          .where((id) => _isValidUuid(id) && id != effectiveSenderId)
          .toList();
      if (recipientIds.isNotEmpty) {
        PushNotificationService.instance.dispatchPushToUsers(
          userIds: recipientIds,
          title: senderName,
          body: displayPreview,
          type: 'message',
          data: {'conversation_id': conversationId},
        );
      }
    }

    return msg;
  }

  /// Edit a sent message (cloud first)
  Future<bool> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
  }) async {
    final list = _messagesMap[conversationId];
    if (list == null) return false;

    final index = list.indexWhere((m) => m.id == messageId);
    if (index == -1) return false;

    final client = SupabaseService.instance.client;
    if (client == null || !_isValidUuid(messageId)) {
      throw Exception('Cannot edit message: server offline or invalid ID.');
    }

    await client.from('messages').update({
      'content': newContent.trim(),
      'is_edited': true,
    }).eq('id', messageId);

    final existing = list[index];
    list[index] = existing.copyWith(
      content: newContent.trim(),
      isEdited: true,
    );

    final ctrl = _chatControllers[conversationId];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(List.from(list));
    }
    await _saveMessagesToCache(conversationId);

    if (index == list.length - 1) {
      final convoIdx =
          _conversations.indexWhere((c) => c.id == conversationId);
      if (convoIdx != -1) {
        final existingConvo = _conversations[convoIdx];
        _conversations[convoIdx] = Conversation(
          id: existingConvo.id,
          title: existingConvo.title,
          isGroup: existingConvo.isGroup,
          participantIds: existingConvo.participantIds,
          participantNames: existingConvo.participantNames,
          lastMessage: newContent.trim(),
          lastMessageTime: existingConvo.lastMessageTime,
          halaqahId: existingConvo.halaqahId,
          groupType: existingConvo.groupType,
          unreadCount: existingConvo.unreadCount,
          isPinned: existingConvo.isPinned,
        );
        if (!_conversationsController.isClosed) {
          _conversationsController.add(List.from(_conversations));
        }
      }
    }

    return true;
  }

  /// Delete a message (cloud first)
  Future<bool> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final list = _messagesMap[conversationId];
    if (list == null) return false;

    final index = list.indexWhere((m) => m.id == messageId);
    if (index == -1) return false;

    final client = SupabaseService.instance.client;
    if (client == null || !_isValidUuid(messageId)) {
      throw Exception('Cannot delete message: server offline or invalid ID.');
    }

    await client.from('messages').delete().eq('id', messageId);

    list.removeAt(index);
    final ctrl = _chatControllers[conversationId];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(List.from(list));
    }
    await _saveMessagesToCache(conversationId);

    final convoIdx = _conversations.indexWhere((c) => c.id == conversationId);
    if (convoIdx != -1) {
      final existingConvo = _conversations[convoIdx];
      final newLastMsg = list.isNotEmpty ? list.last.content : '';
      _conversations[convoIdx] = Conversation(
        id: existingConvo.id,
        title: existingConvo.title,
        isGroup: existingConvo.isGroup,
        participantIds: existingConvo.participantIds,
        participantNames: existingConvo.participantNames,
        lastMessage: newLastMsg,
        lastMessageTime:
            list.isNotEmpty ? list.last.timestamp : existingConvo.lastMessageTime,
        halaqahId: existingConvo.halaqahId,
        groupType: existingConvo.groupType,
        unreadCount: existingConvo.unreadCount,
        isPinned: existingConvo.isPinned,
      );
      if (!_conversationsController.isClosed) {
        _conversationsController.add(List.from(_conversations));
      }
    }

    return true;
  }

  static String _generateUuidV4() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40;
    values[8] = (values[8] & 0x3f) | 0x80;
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static bool _isValidUuid(String str) {
    final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false);
    return uuidRegex.hasMatch(str);
  }

  static String _escapeIlikePattern(String raw) {
    return raw
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  Future<void> _syncConversationToCloud(Conversation convo) async {
    final client = SupabaseService.instance.client;
    if (client == null || !_isValidUuid(convo.id)) return;

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
        await client.from('conversation_participants').upsert({
          'conversation_id': convo.id,
          'user_id': pid,
        });
      }
    }
  }

  Future<Conversation?> _createDirectConversationViaRpc({
    required String otherUserId,
    required String title,
    String? halaqahId,
    String? groupType,
  }) async {
    final client = SupabaseService.instance.client;
    if (client == null || !_isValidUuid(otherUserId)) return null;
    try {
      final rpcRes = await client.rpc(
        'create_direct_conversation',
        params: {
          'p_other_user_id': otherUserId,
          'p_title': title,
          if (halaqahId != null && _isValidUuid(halaqahId))
            'p_halaqah_id': halaqahId,
          if (groupType != null) 'p_group_type': groupType,
        },
      );
      if (rpcRes is Map &&
          rpcRes['success'] == true &&
          rpcRes['conversation'] is Map) {
        return Conversation.fromJson(
            Map<String, dynamic>.from(rpcRes['conversation'] as Map));
      }
      if (rpcRes is Map && rpcRes['success'] == false) {
        throw Exception(
            rpcRes['message']?.toString() ?? 'Could not create conversation.');
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final missingRpc = msg.contains('42883') ||
          msg.contains('pgrst202') ||
          msg.contains('could not find the function');
      if (!missingRpc) rethrow;
    }
    return null;
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

    final rpcConvo = await _createDirectConversationViaRpc(
      otherUserId: parentId,
      title: '$parentName ($studentName\'s Parent)',
      halaqahId: halaqahId,
      groupType: 'direct_teacher',
    );

    final convo = rpcConvo ??
        Conversation(
          id: _generateUuidV4(),
          title: '$parentName ($studentName\'s Parent)',
          isGroup: false,
          participantIds: [teacherId, parentId],
          participantNames: [teacherName, parentName],
          lastMessage: initialMessage ??
              'Ustaz $teacherName started a conversation regarding $studentName.',
          lastMessageTime: DateTime.now(),
          halaqahId: halaqahId,
          groupType: 'direct_teacher',
        );

    _conversations.removeWhere((c) => c.id == convo.id);
    _conversations.insert(0, convo);
    if (!_conversationsController.isClosed) {
      _conversationsController.add(List.from(_conversations));
    }

    final jsonList = _conversations.map((c) => c.toJson()).toList();
    await LocalStorageService.instance
        .saveJsonList('cached_conversations', jsonList);

    if (rpcConvo == null) {
      await _syncConversationToCloud(convo);
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

  Future<String?> _resolveAdminUserId() async {
    final client = SupabaseService.instance.client;
    if (client == null) return null;
    try {
      final res = await client
          .from('profiles')
          .select('id')
          .inFilter('role', ['superadmin', 'admin'])
          .limit(1)
          .maybeSingle();
      return res?['id']?.toString();
    } catch (e) {
      debugPrint('[MessagingService] Failed to resolve admin ID: $e');
      return null;
    }
  }

  Future<String?> _resolveTeacherUserId({
    String? halaqahId,
    String? halaqahName,
  }) async {
    final client = SupabaseService.instance.client;
    if (client == null) return null;
    try {
      if (halaqahId != null && _isValidUuid(halaqahId)) {
        final byId = await client
            .from('halaqahs')
            .select('teacher_id')
            .eq('id', halaqahId)
            .not('teacher_id', 'is', null)
            .maybeSingle();
        if (byId?['teacher_id'] != null) {
          return byId!['teacher_id'].toString();
        }
      }
      if (halaqahName != null && halaqahName.trim().isNotEmpty) {
        final escaped = _escapeIlikePattern(halaqahName.trim());
        final res = await client
            .from('halaqahs')
            .select('teacher_id')
            .ilike('name', '%$escaped%')
            .not('teacher_id', 'is', null)
            .limit(1)
            .maybeSingle();
        if (res?['teacher_id'] != null) {
          return res!['teacher_id'].toString();
        }
      }
      final fallback = await client
          .from('profiles')
          .select('id')
          .eq('role', 'teacher')
          .limit(1)
          .maybeSingle();
      return fallback?['id']?.toString();
    } catch (e) {
      debugPrint('[MessagingService] Failed to resolve teacher ID: $e');
      return null;
    }
  }

  /// Admin creates a new group conversation with parents
  Future<Conversation> createGroup({
    required String title,
    required List<String> parentIds,
    required List<String> parentNames,
    String? halaqahId,
  }) async {
    final currentUserId = SupabaseService.instance.currentUser?.id ??
        AuthSessionService.instance.userId;
    final adminId = currentUserId.isNotEmpty
        ? currentUserId
        : (await _resolveAdminUserId() ?? '');

    final convo = Conversation(
      id: _generateUuidV4(),
      title: title,
      isGroup: true,
      participantIds: [if (adminId.isNotEmpty) adminId, ...parentIds],
      participantNames: ['Admin Director', ...parentNames],
      lastMessage: 'Group created by Admin.',
      lastMessageTime: DateTime.now(),
      halaqahId: halaqahId,
      groupType: 'parent_group',
    );

    await _syncConversationToCloud(convo);

    _conversations.insert(0, convo);
    if (!_conversationsController.isClosed) {
      _conversationsController.add(List.from(_conversations));
    }

    final jsonList = _conversations.map((c) => c.toJson()).toList();
    await LocalStorageService.instance
        .saveJsonList('cached_conversations', jsonList);

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
    final currentUserId = SupabaseService.instance.currentUser?.id ??
        AuthSessionService.instance.userId;
    final adminId = currentUserId.isNotEmpty
        ? currentUserId
        : (await _resolveAdminUserId() ?? '');

    final existingIndex = _conversations.indexWhere(
      (c) =>
          !c.isGroup &&
          c.participantIds.contains(adminId) &&
          c.participantIds.contains(parentId),
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

    final rpcConvo = await _createDirectConversationViaRpc(
      otherUserId: parentId,
      title: parentName,
      groupType: 'direct_admin',
    );

    final convo = rpcConvo ??
        Conversation(
          id: _generateUuidV4(),
          title: parentName,
          isGroup: false,
          participantIds: [if (adminId.isNotEmpty) adminId, parentId],
          participantNames: ['Admin Director', parentName],
          lastMessage: initialMessage ?? 'Conversation started with $parentName.',
          lastMessageTime: DateTime.now(),
          groupType: 'direct_admin',
        );

    _conversations.removeWhere((c) => c.id == convo.id);
    _conversations.insert(0, convo);
    if (!_conversationsController.isClosed) {
      _conversationsController.add(List.from(_conversations));
    }

    final jsonList = _conversations.map((c) => c.toJson()).toList();
    await LocalStorageService.instance
        .saveJsonList('cached_conversations', jsonList);

    if (rpcConvo == null) {
      await _syncConversationToCloud(convo);
    }

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
    String? targetId,
    String? halaqahId,
    String? halaqahName,
    String? initialMessage,
  }) async {
    final title = targetRole == 'admin'
        ? 'Center Director'
        : '$targetName (${halaqahName ?? 'Teacher'})';

    String resolvedTargetId = targetId ?? '';
    if (!_isValidUuid(resolvedTargetId)) {
      resolvedTargetId = (targetRole == 'admin'
              ? await _resolveAdminUserId()
              : await _resolveTeacherUserId(
                  halaqahId: halaqahId,
                  halaqahName: halaqahName,
                )) ??
          '';
    }

    final existingIndex = resolvedTargetId.isNotEmpty
        ? _conversations.indexWhere(
            (c) =>
                !c.isGroup &&
                c.participantIds.contains(parentId) &&
                c.participantIds.contains(resolvedTargetId),
          )
        : -1;

    if (existingIndex != -1) {
      final existing = _conversations[existingIndex];
      if (initialMessage != null && initialMessage.isNotEmpty) {
        await sendMessage(
          conversationId: existing.id,
          senderId: parentId,
          senderName: parentName,
          senderRole: 'parent',
          content: initialMessage,
        );
      }
      return existing;
    }

    final rpcConvo = resolvedTargetId.isNotEmpty
        ? await _createDirectConversationViaRpc(
            otherUserId: resolvedTargetId,
            title: title,
            halaqahId: halaqahId,
            groupType: targetRole == 'admin' ? 'direct_admin' : 'direct_teacher',
          )
        : null;

    final convo = rpcConvo ??
        Conversation(
          id: _generateUuidV4(),
          title: title,
          isGroup: false,
          participantIds: [
            parentId,
            if (resolvedTargetId.isNotEmpty) resolvedTargetId,
          ],
          participantNames: [parentName, targetName],
          lastMessage: initialMessage ?? 'Conversation initiated.',
          lastMessageTime: DateTime.now(),
          halaqahId: halaqahId,
          groupType: targetRole == 'admin' ? 'direct_admin' : 'direct_teacher',
        );

    _conversations.removeWhere((c) => c.id == convo.id);
    _conversations.insert(0, convo);
    if (!_conversationsController.isClosed) {
      _conversationsController.add(List.from(_conversations));
    }

    final jsonList = _conversations.map((c) => c.toJson()).toList();
    await LocalStorageService.instance
        .saveJsonList('cached_conversations', jsonList);

    if (rpcConvo == null) {
      await _syncConversationToCloud(convo);
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
