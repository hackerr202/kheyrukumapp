import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';
import '../utils/json_parsers.dart';
import '../utils/uuid_v4.dart';
import 'auth_session_service.dart';
import 'connectivity_service.dart';
import 'local_storage_service.dart';
import 'offline_sync_service.dart';
import 'push_notification_service.dart';
import 'supabase_service.dart';

/// Full-featured real-time Messaging Service with user-scoped offline caching,
/// durable outbox replay (including staged voice notes & images), and targeted push.
class MessagingService {
  MessagingService._();

  static final MessagingService instance = MessagingService._();

  final List<Conversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messagesMap = {};
  final Map<String, String> _profileNamesById = {};
  bool _cacheLoaded = false;

  final StreamController<List<Conversation>> _conversationsController =
      StreamController<List<Conversation>>.broadcast();

  final Map<String, StreamController<List<ChatMessage>>> _chatControllers = {};
  RealtimeChannel? _realtimeMessagesSubscription;
  RealtimeChannel? _realtimeConvosSubscription;
  Timer? _convosRealtimeDebounce;

  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);

  Stream<List<Conversation>> get conversationsStream =>
      _conversationsController.stream;

  List<Conversation> get allConversations => List.unmodifiable(_conversations);

  String get _uid => AuthSessionService.instance.userId.isNotEmpty
      ? AuthSessionService.instance.userId
      : (SupabaseService.instance.currentUser?.id ?? '');

  Future<void> refreshAndSubscribe() async {
    await _loadFromCache();
    await _initCloudSync();
  }

  /// Explicit message refresh for a single conversation (used after batch sync).
  Future<void> refreshConversationMessages(String conversationId) async {
    await _fetchMessagesFromCloud(conversationId);
  }

  Future<void> clearOnLogout() async {
    final uid = _uid;
    final client = SupabaseService.instance.client;
    _convosRealtimeDebounce?.cancel();
    _convosRealtimeDebounce = null;
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
    _profileNamesById.clear();
    _cacheLoaded = false;
    isLoadingNotifier.value = false;
    errorNotifier.value = null;

    if (!_conversationsController.isClosed) {
      _conversationsController.add([]);
    }
    if (uid.isNotEmpty) {
      await LocalStorageService.instance.removeUserCache(uid, 'conversations');
    }
    await LocalStorageService.instance.remove('cached_conversations');
    await LocalStorageService.instance.removeByPrefix('cache_msgs_');
  }

  Future<void> _saveConversationsCache() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    final jsonList = _conversations.map((c) => c.toJson()).toList();
    await LocalStorageService.instance
        .saveUserJsonList(uid, 'conversations', jsonList);
  }

  void _applyPendingConversationPreviews() {
    final pendingMsgs = OfflineSyncService.instance
        .pendingMutationsForEntity(OfflineEntityTypes.chatMessage);
    for (final mut in pendingMsgs) {
      final p = mut.payload;
      final convoId = p['conversation_id']?.toString() ?? '';
      if (convoId.isEmpty) continue;
      final idx = _conversations.indexWhere((c) => c.id == convoId);
      if (idx == -1) continue;
      final existing = _conversations[idx];
      final msgTime =
          JsonParsers.asDateTime(p['created_at'], mut.createdAt.toLocal());
      final preview =
          p['_preview_text']?.toString() ?? p['content']?.toString() ?? '';
      if (msgTime.isAfter(existing.lastMessageTime) ||
          msgTime.isAtSameMomentAs(existing.lastMessageTime)) {
        _conversations[idx] = Conversation(
          id: existing.id,
          title: existing.title,
          isGroup: existing.isGroup,
          participantIds: existing.participantIds,
          participantNames: existing.participantNames,
          lastMessage: preview,
          lastMessageTime: msgTime,
          halaqahId: existing.halaqahId,
          groupType: existing.groupType,
          unreadCount: existing.unreadCount,
          isPinned: existing.isPinned,
        );
      }
    }
  }

  void _applyPendingMessageOverlays(String conversationId) {
    final pendingMsgs = OfflineSyncService.instance
        .pendingMutationsForEntity(OfflineEntityTypes.chatMessage);
    final list = _messagesMap.putIfAbsent(conversationId, () => []);
    for (final mut in pendingMsgs) {
      final p = mut.payload;
      if (p['conversation_id']?.toString() != conversationId) continue;
      final msgId = p['id']?.toString() ?? mut.id;
      final localAttach = (mut.localMediaPath != null &&
              mut.localMediaPath!.trim().isNotEmpty)
          ? 'local://${mut.localMediaPath}'
          : p['attachment_url']?.toString();
      final overlayMsg = ChatMessage.fromJson({
        ...p,
        'id': msgId,
        'attachment_url': localAttach,
      });
      final existingIdx = list.indexWhere((m) => m.id == msgId);
      if (existingIdx != -1) {
        list[existingIdx] = overlayMsg;
      } else {
        list.add(overlayMsg);
      }
    }
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> _loadFromCache() async {
    if (_cacheLoaded) return;
    final uid = _uid;
    if (uid.isEmpty) return;
    _cacheLoaded = true;
    try {
      final cachedConvos = await LocalStorageService.instance
          .getUserJsonList(uid, 'conversations');
      if (cachedConvos.isNotEmpty && _conversations.isEmpty) {
        _conversations.clear();
        for (final json in cachedConvos) {
          _conversations.add(Conversation.fromJson(json));
        }
        _applyPendingConversationPreviews();
        if (!_conversationsController.isClosed) {
          _conversationsController.add(List.from(_conversations));
        }
        debugPrint(
          '[MessagingService] Loaded ${_conversations.length} conversations from user offline cache.',
        );
      }
    } catch (e) {
      debugPrint('[MessagingService] Cache load error: $e');
    }
  }

  void _scheduleConvosRefresh() {
    _convosRealtimeDebounce?.cancel();
    _convosRealtimeDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (SupabaseService.instance.currentUser != null) {
        fetchConversationsFromCloud();
      }
    });
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
            callback: (_) => _scheduleConvosRefresh(),
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
        '[MessagingService] Supabase Realtime messaging channel subscribed.',
      );
    } catch (e) {
      debugPrint('[MessagingService] Cloud sync note: $e');
    }
  }

  /// Fetch conversations from Supabase (preserves pending offline previews).
  Future<void> fetchConversationsFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;
    if (!ConnectivityService.instance.isOnline) {
      errorNotifier.value = null;
      return;
    }

    isLoadingNotifier.value = true;
    errorNotifier.value = null;
    try {
      final res = await client
          .from('conversations')
          .select()
          .order('last_message_time', ascending: false)
          .limit(100);

      if (res is List) {
        final parsed = <Conversation>[];
        for (final item in res) {
          if (item is Map) {
            try {
              parsed.add(
                Conversation.fromJson(Map<String, dynamic>.from(item)),
              );
            } catch (rowErr) {
              debugPrint(
                '[MessagingService] Skipped malformed conversation row: $rowErr',
              );
            }
          }
        }
        _conversations
          ..clear()
          ..addAll(parsed);
        _applyPendingConversationPreviews();
        if (!_conversationsController.isClosed) {
          _conversationsController.add(List.from(_conversations));
        }
        await _saveConversationsCache();
        unawaited(_hydrateParticipantNames(parsed));
      }
    } catch (e) {
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
        errorNotifier.value = null;
      } else {
        errorNotifier.value = SupabaseService.cleanErrorMessage(e);
      }
      debugPrint('[MessagingService] fetchConversationsFromCloud error: $e');
    } finally {
      isLoadingNotifier.value = false;
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
      await _saveConversationsCache();

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

  bool _isPlaceholderName(String? value) {
    final lower = value?.trim().toLowerCase() ?? '';
    if (lower.isEmpty) return true;
    return lower.contains('challenger') ||
        lower == 'test' ||
        lower.startsWith('test ') ||
        lower.startsWith('test_') ||
        lower == 'admin director' ||
        lower == 'center director';
  }

  Future<void> _hydrateParticipantNames(List<Conversation> convos) async {
    final client = SupabaseService.instance.client;
    if (client == null || convos.isEmpty) return;

    final ids = <String>{};
    for (final c in convos) {
      if (c.isGroup) continue;
      for (final pid in c.participantIds) {
        final clean = pid.trim();
        if (_isValidUuid(clean)) ids.add(clean);
      }
    }
    if (ids.isEmpty) return;

    var updated = false;
    try {
      final rpcRes = await client.rpc(
        'get_conversation_participant_names',
        params: {'p_user_ids': ids.toList()},
      );
      if (rpcRes is List) {
        for (final row in rpcRes) {
          if (row is! Map) continue;
          final id = row['id']?.toString().trim() ?? '';
          final name = row['full_name']?.toString().trim() ?? '';
          if (id.isNotEmpty &&
              name.isNotEmpty &&
              _profileNamesById[id] != name) {
            _profileNamesById[id] = name;
            updated = true;
          }
        }
      }
    } catch (_) {
      try {
        final contacts = await fetchMessageableContacts();
        for (final c in contacts) {
          final id = c['id']?.toString().trim() ?? '';
          final name = c['full_name']?.toString().trim() ?? '';
          if (id.isNotEmpty &&
              name.isNotEmpty &&
              _profileNamesById[id] != name) {
            _profileNamesById[id] = name;
            updated = true;
          }
        }
      } catch (_) {}
    }

    if (updated &&
        !_conversationsController.isClosed &&
        _conversations.isNotEmpty) {
      _conversationsController.add(List.from(_conversations));
    }
  }

  /// Returns a viewer-appropriate display title for a conversation, preferring
  /// the live `profiles.full_name` of the other participant for direct chats.
  String displayTitleFor(Conversation convo, String currentUserId) {
    if (!convo.isGroup && convo.participantIds.isNotEmpty) {
      if (currentUserId.isNotEmpty &&
          convo.participantIds.contains(currentUserId)) {
        for (var i = 0; i < convo.participantIds.length; i++) {
          final pid = convo.participantIds[i];
          if (pid != currentUserId) {
            final liveName = _profileNamesById[pid];
            if (liveName != null && liveName.trim().isNotEmpty) {
              return liveName.trim();
            }
            if (i < convo.participantNames.length &&
                convo.participantNames[i].trim().isNotEmpty) {
              return convo.participantNames[i].trim();
            }
          }
        }
      } else if (convo.participantIds.length >= 2) {
        final first = _profileNamesById[convo.participantIds[0]] ??
            (convo.participantNames.isNotEmpty
                ? convo.participantNames[0]
                : '');
        final second = _profileNamesById[convo.participantIds[1]] ??
            (convo.participantNames.length > 1
                ? convo.participantNames[1]
                : '');
        if (first.trim().isNotEmpty && second.trim().isNotEmpty) {
          return '${first.trim()} & ${second.trim()}';
        }
      } else if (convo.participantNames.length >= 2) {
        return '${convo.participantNames[0]} & ${convo.participantNames[1]}';
      }
    }
    return convo.title.isNotEmpty ? convo.title : 'Direct Chat';
  }

  /// Fetch contacts the signed-in user is permitted to message (online required).
  Future<List<Map<String, dynamic>>> fetchMessageableContacts() async {
    if (!ConnectivityService.instance.isOnline &&
        !await ConnectivityService.instance.checkNow()) {
      throw const OfflineActionException();
    }
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) {
      throw Exception('Please sign in to load contacts.');
    }
    try {
      final res = await client.rpc('get_messageable_contacts');
      if (res is List) {
        final contacts = <Map<String, dynamic>>[];
        for (final item in res) {
          if (item is Map) {
            contacts.add(Map<String, dynamic>.from(item));
          }
        }
        return contacts;
      }
      return [];
    } catch (e) {
      throw Exception(SupabaseService.cleanErrorMessage(e));
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
    await _saveConversationsCache();
  }

  /// Get conversations filtered for current user role and ID.
  List<Conversation> getConversationsForUser(
    String userId, {
    String role = 'admin',
  }) {
    if (role == 'admin' || role == 'superadmin') return _conversations;
    return _conversations.where((c) {
      if (userId.isNotEmpty && c.participantIds.contains(userId)) return true;
      if (c.isGroup && role == 'parent' && c.groupType == 'parent_group') {
        return true;
      }
      return false;
    }).toList();
  }

  /// Stream messages for a specific conversation with user-scoped offline-first loading.
  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    if (!_chatControllers.containsKey(conversationId) ||
        _chatControllers[conversationId]!.isClosed) {
      _chatControllers[conversationId] =
          StreamController<List<ChatMessage>>.broadcast();
    }

    _loadMessagesFromCache(conversationId).then((cached) {
      _messagesMap[conversationId] = cached;
      _applyPendingMessageOverlays(conversationId);
      final ctrl = _chatControllers[conversationId];
      if (ctrl != null && !ctrl.isClosed) {
        ctrl.add(List.from(_messagesMap[conversationId]!));
      }
    });

    _fetchMessagesFromCloud(conversationId);

    return _chatControllers[conversationId]!.stream;
  }

  List<ChatMessage> getMessages(String conversationId) {
    return _messagesMap[conversationId] ?? [];
  }

  Future<List<ChatMessage>> _loadMessagesFromCache(
    String conversationId,
  ) async {
    final uid = _uid;
    if (uid.isEmpty) return [];
    try {
      final cached = await LocalStorageService.instance
          .getUserJsonList(uid, 'msgs_$conversationId');
      return cached.map((j) => ChatMessage.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveMessagesToCache(String conversationId) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    try {
      final msgs = _messagesMap[conversationId] ?? [];
      final jsonList = msgs.map((m) => m.toJson()).toList();
      await LocalStorageService.instance
          .saveUserJsonList(uid, 'msgs_$conversationId', jsonList);
    } catch (e) {
      debugPrint(
          '[MessagingService] Error saving cache for $conversationId: $e');
    }
  }

  Future<void> _fetchMessagesFromCloud(String conversationId) async {
    final client = SupabaseService.instance.client;
    if (client == null ||
        SupabaseService.instance.currentUser == null ||
        !_isValidUuid(conversationId)) {
      return;
    }
    if (!ConnectivityService.instance.isOnline) return;

    try {
      final res = await client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(100);

      if (res is List) {
        final cloudMsgs = <ChatMessage>[];
        for (final item in res) {
          if (item is Map) {
            try {
              cloudMsgs.add(
                ChatMessage.fromJson(Map<String, dynamic>.from(item)),
              );
            } catch (rowErr) {
              debugPrint(
                '[MessagingService] Skipped malformed message row: $rowErr',
              );
            }
          }
        }
        final ordered = cloudMsgs.reversed.toList();
        _messagesMap[conversationId] = ordered;
        _applyPendingMessageOverlays(conversationId);

        final ctrl = _chatControllers[conversationId];
        if (ctrl != null && !ctrl.isClosed) {
          ctrl.add(List.from(_messagesMap[conversationId]!));
        }
        await _saveMessagesToCache(conversationId);
      }
    } catch (e) {
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
      } else {
        errorNotifier.value = SupabaseService.cleanErrorMessage(e);
      }
      debugPrint('[MessagingService] fetchMessagesFromCloud error: $e');
    }
  }

  /// Send a text or media message (online-first, automatically queues offline
  /// with genuine UUID v4 and durable staged media paths).
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
    String? localMediaPath,
    String? storageBucket,
    String? storagePath,
    String? mediaMimeType,
  }) async {
    final effectiveSenderId = (senderId.isNotEmpty && _isValidUuid(senderId))
        ? senderId
        : (SupabaseService.instance.currentUser?.id ??
            (AuthSessionService.instance.userId.isNotEmpty &&
                    _isValidUuid(AuthSessionService.instance.userId)
                ? AuthSessionService.instance.userId
                : null));

    if (effectiveSenderId == null || !_isValidUuid(conversationId)) {
      throw Exception('Cannot send message: invalid session or conversation.');
    }

    final createdAt = DateTime.now();
    final createdAtIso = createdAt.toUtc().toIso8601String();
    final trimmedContent = content.trim();

    final msg = ChatMessage(
      id: UuidV4.generate(),
      conversationId: conversationId,
      senderId: effectiveSenderId,
      senderName: senderName,
      senderRole: senderRole,
      content: trimmedContent,
      timestamp: createdAt,
      isRead: false,
      messageType: messageType,
      attachmentUrl: localMediaPath != null
          ? 'local://$localMediaPath'
          : attachmentUrl,
      attachmentName: attachmentName,
      audioDurationSeconds: audioDurationSeconds,
    );

    String displayPreview = trimmedContent;
    if (messageType == 'voice') displayPreview = '🎤 Voice message';
    if (messageType == 'image') displayPreview = '📷 Photo';
    if (messageType == 'video') displayPreview = '🎥 Video';
    if (messageType == 'document') displayPreview = '📎 Document';

    Future<ChatMessage> applyLocally({required bool queueOffline}) async {
      final list = _messagesMap.putIfAbsent(conversationId, () => []);
      if (!list.any((m) => m.id == msg.id)) {
        list.add(msg);
      }
      final ctrl = _chatControllers[conversationId];
      if (ctrl != null && !ctrl.isClosed) {
        ctrl.add(List.from(list));
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
        await _saveConversationsCache();
      }

      if (queueOffline) {
        await OfflineSyncService.instance.enqueue(
          entityType: OfflineEntityTypes.chatMessage,
          operation: 'upsert',
          id: msg.id,
          payload: {
            'id': msg.id,
            'conversation_id': conversationId,
            'sender_id': effectiveSenderId,
            'sender_name': senderName,
            'sender_role': senderRole,
            'content': trimmedContent,
            'message_type': messageType,
            'attachment_url': attachmentUrl,
            'attachment_name': attachmentName,
            'audio_duration': audioDurationSeconds,
            'created_at': createdAtIso,
            'is_read': false,
            '_preview_text': displayPreview,
          },
          localMediaPath: localMediaPath,
          storageBucket: storageBucket,
          storagePath: storagePath,
          mediaPayloadField:
              localMediaPath != null ? 'attachment_url' : null,
          mediaMimeType: mediaMimeType,
          displayLabel: displayPreview.length > 42
              ? '${displayPreview.substring(0, 42)}...'
              : displayPreview,
          triggerImmediateSync: false,
        );
      }

      return msg;
    }

    final client = SupabaseService.instance.client;
    if (localMediaPath != null ||
        !ConnectivityService.instance.isOnline ||
        client == null) {
      return await applyLocally(queueOffline: true);
    }

    try {
      await client.from('messages').upsert(
        {
          'id': msg.id,
          'conversation_id': conversationId,
          'sender_id': effectiveSenderId,
          'sender_name': senderName,
          'sender_role': senderRole,
          'content': trimmedContent,
          'message_type': messageType,
          'attachment_url': attachmentUrl,
          'attachment_name': attachmentName,
          'audio_duration': audioDurationSeconds,
          'created_at': createdAtIso,
          'is_read': false,
        },
        onConflict: 'id',
      );

      await client.from('conversations').update({
        'last_message': displayPreview,
        'last_message_time': createdAtIso,
      }).eq('id', conversationId);

      final savedMsg = await applyLocally(queueOffline: false);

      final idx = _conversations.indexWhere((c) => c.id == conversationId);
      if (idx != -1) {
        final convo = _conversations[idx];
        final recipientIds = convo.participantIds
            .where((id) => _isValidUuid(id) && id != effectiveSenderId)
            .toList();
        if (recipientIds.isNotEmpty) {
          final templateKey = switch (messageType) {
            'voice' => 'chat_voice',
            'image' => 'chat_photo',
            'document' => 'chat_document',
            _ => 'chat_message',
          };
          PushNotificationService.instance.dispatchPushToUsers(
            userIds: recipientIds,
            title: senderName,
            body: displayPreview,
            type: 'message',
            data: {
              'conversation_id': conversationId,
              'template_key': templateKey,
              'params': {
                'sender_name': senderName,
                'body': trimmedContent,
                'duration': '${audioDurationSeconds ?? 0}',
                'file_name': attachmentName ?? '',
              },
            },
          );
        }
      }

      return savedMsg;
    } catch (e) {
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
        return await applyLocally(queueOffline: true);
      }
      rethrow;
    }
  }

  /// Edit a sent message (online required).
  Future<bool> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
  }) async {
    if (!ConnectivityService.instance.isOnline &&
        !await ConnectivityService.instance.checkNow()) {
      throw const OfflineActionException();
    }
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
        await _saveConversationsCache();
      }
    }

    return true;
  }

  /// Delete a message (discards pending outbox item if still offline, otherwise online delete).
  Future<bool> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final list = _messagesMap[conversationId];
    if (list == null) return false;

    final index = list.indexWhere((m) => m.id == messageId);
    if (index == -1) return false;

    if (OfflineSyncService.instance
        .isRecordPending(OfflineEntityTypes.chatMessage, messageId)) {
      await OfflineSyncService.instance.discardMutation(messageId);
    } else {
      if (!ConnectivityService.instance.isOnline &&
          !await ConnectivityService.instance.checkNow()) {
        throw const OfflineActionException();
      }
      final client = SupabaseService.instance.client;
      if (client == null || !_isValidUuid(messageId)) {
        throw Exception('Cannot delete message: server offline or invalid ID.');
      }
      await client.from('messages').delete().eq('id', messageId);
    }

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
        lastMessageTime: list.isNotEmpty
            ? list.last.timestamp
            : existingConvo.lastMessageTime,
        halaqahId: existingConvo.halaqahId,
        groupType: existingConvo.groupType,
        unreadCount: existingConvo.unreadCount,
        isPinned: existingConvo.isPinned,
      );
      if (!_conversationsController.isClosed) {
        _conversationsController.add(List.from(_conversations));
      }
      await _saveConversationsCache();
    }

    return true;
  }

  static bool _isValidUuid(String str) => UuidV4.isValid(str);

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
      'last_message_time': convo.lastMessageTime.toUtc().toIso8601String(),
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
          Map<String, dynamic>.from(rpcRes['conversation'] as Map),
        );
      }
      if (rpcRes is Map && rpcRes['success'] == false) {
        throw Exception(
          rpcRes['message']?.toString() ?? 'Could not create conversation.',
        );
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

  Future<void> _saveConversationsCacheAndEmit(Conversation convo) async {
    _conversations.removeWhere((c) => c.id == convo.id);
    _conversations.insert(0, convo);
    if (!_conversationsController.isClosed) {
      _conversationsController.add(List.from(_conversations));
    }
    await _saveConversationsCache();
  }

  Future<Conversation> _startOrReuseDirectChat({
    required String callerId,
    required String callerName,
    required String callerRole,
    required String otherUserId,
    required String otherName,
    required String title,
    String? halaqahId,
    required String groupType,
    String? initialMessage,
  }) async {
    final validCallerId = _isValidUuid(callerId)
        ? callerId
        : (SupabaseService.instance.currentUser?.id ?? '');
    if (!_isValidUuid(validCallerId)) {
      throw Exception('Please sign in to start a conversation.');
    }
    if (!_isValidUuid(otherUserId)) {
      throw Exception('Recipient account could not be found.');
    }

    // If offline, return an already-cached direct conversation if present.
    if (!ConnectivityService.instance.isOnline &&
        !await ConnectivityService.instance.checkNow()) {
      for (final existing in _conversations) {
        if (!existing.isGroup &&
            existing.participantIds.contains(validCallerId) &&
            existing.participantIds.contains(otherUserId)) {
          return existing;
        }
      }
      throw const OfflineActionException();
    }

    final rpcConvo = await _createDirectConversationViaRpc(
      otherUserId: otherUserId,
      title: title,
      halaqahId: halaqahId,
      groupType: groupType,
    );

    Conversation convo;
    if (rpcConvo != null) {
      convo = rpcConvo;
    } else {
      final fallbackConvo = Conversation(
        id: UuidV4.generate(),
        title: title,
        isGroup: false,
        participantIds: [validCallerId, otherUserId],
        participantNames: [callerName, otherName],
        lastMessage:
            initialMessage ?? 'Conversation started with $otherName.',
        lastMessageTime: DateTime.now(),
        halaqahId: halaqahId,
        groupType: groupType,
      );
      await _syncConversationToCloud(fallbackConvo);
      convo = fallbackConvo;
    }

    await _saveConversationsCacheAndEmit(convo);
    if (!_isPlaceholderName(otherName)) {
      _profileNamesById[otherUserId] = otherName.trim();
    }
    unawaited(_hydrateParticipantNames([convo]));

    if (initialMessage != null && initialMessage.trim().isNotEmpty) {
      await sendMessage(
        conversationId: convo.id,
        senderId: validCallerId,
        senderName: callerName,
        senderRole: callerRole,
        content: initialMessage.trim(),
      );
    }

    return convo;
  }

  /// Start or open a direct 1-on-1 chat with any eligible contact.
  Future<Conversation> startDirectChatWithContact({
    required String otherUserId,
    required String otherName,
    required String otherRole,
    String? halaqahId,
    String? initialMessage,
  }) async {
    final callerId = SupabaseService.instance.currentUser?.id ??
        AuthSessionService.instance.userId;
    final callerName = AuthSessionService.instance.userName;
    final callerRole = AuthSessionService.instance.currentRole;

    final isAdminSide = callerRole == 'admin' ||
        callerRole == 'superadmin' ||
        otherRole == 'admin' ||
        otherRole == 'superadmin';

    return _startOrReuseDirectChat(
      callerId: callerId,
      callerName: callerName,
      callerRole: callerRole,
      otherUserId: otherUserId,
      otherName: otherName,
      title: otherName,
      halaqahId: halaqahId,
      groupType: isAdminSide ? 'direct_admin' : 'direct_teacher',
      initialMessage: initialMessage,
    );
  }

  /// Teacher starts a direct 1-on-1 chat with a parent of his class students.
  Future<Conversation> startTeacherChatWithParent({
    required String teacherId,
    required String teacherName,
    required String parentId,
    required String parentName,
    required String studentName,
    String? halaqahId,
    String? initialMessage,
  }) async {
    return _startOrReuseDirectChat(
      callerId: teacherId,
      callerName: teacherName,
      callerRole: 'teacher',
      otherUserId: parentId,
      otherName: parentName,
      title: '$parentName ($studentName\'s Parent)',
      halaqahId: halaqahId,
      groupType: 'direct_teacher',
      initialMessage: initialMessage,
    );
  }

  Future<({String id, String name})?> _resolveAdminContact() async {
    final client = SupabaseService.instance.client;
    if (client == null) return null;

    ({String id, String name})? pickBest(Iterable<Map<String, dynamic>> rows) {
      ({String id, String name, int rank})? best;
      for (final row in rows) {
        final id = row['id']?.toString().trim() ?? '';
        if (!_isValidUuid(id)) continue;
        if (row['is_suspended'] == true) continue;
        final role = row['role']?.toString().toLowerCase().trim() ?? '';
        if (role != 'superadmin' && role != 'admin') continue;

        final fullName = row['full_name']?.toString().trim() ?? '';
        final email = row['email']?.toString().trim() ?? '';
        final resolvedName = fullName.isNotEmpty
            ? fullName
            : (email.isNotEmpty ? email : 'Center Director');

        final isSuper = role == 'superadmin';
        final isRealName = !_isPlaceholderName(fullName);
        final rank = (isRealName ? 0 : 2) + (isSuper ? 0 : 1);
        if (best == null || rank < best.rank) {
          best = (id: id, name: resolvedName, rank: rank);
        }
      }
      return best != null ? (id: best.id, name: best.name) : null;
    }

    try {
      final contacts = await fetchMessageableContacts();
      final fromContacts = pickBest(contacts);
      if (fromContacts != null) return fromContacts;
    } catch (_) {}

    try {
      final res = await client
          .from('profiles')
          .select('id, full_name, email, role, is_suspended')
          .inFilter('role', ['superadmin', 'admin'])
          .or('is_suspended.is.null,is_suspended.eq.false')
          .limit(25);
      if (res is List) {
        final fromTable = pickBest(
          res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        );
        if (fromTable != null) return fromTable;
      }
    } catch (e) {
      debugPrint('[MessagingService] Failed to resolve admin contact: $e');
    }
    return null;
  }

  Future<String?> _resolveAdminUserId() async {
    final contact = await _resolveAdminContact();
    return contact?.id;
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
      final contacts = await fetchMessageableContacts();
      final teacher = contacts.where((c) => c['role'] == 'teacher').toList();
      if (teacher.isNotEmpty) {
        return teacher.first['id']?.toString();
      }
      return null;
    } catch (e) {
      debugPrint('[MessagingService] Failed to resolve teacher ID: $e');
      return null;
    }
  }

  /// Admin creates a new group conversation with parents (online required).
  Future<Conversation> createGroup({
    required String title,
    required List<String> parentIds,
    required List<String> parentNames,
    String? halaqahId,
  }) async {
    if (!ConnectivityService.instance.isOnline &&
        !await ConnectivityService.instance.checkNow()) {
      throw const OfflineActionException();
    }
    final currentUserId = SupabaseService.instance.currentUser?.id ??
        AuthSessionService.instance.userId;
    final adminId = currentUserId.isNotEmpty
        ? currentUserId
        : (await _resolveAdminUserId() ?? '');
    if (!_isValidUuid(adminId)) {
      throw Exception('Active admin session required to create a group.');
    }

    final validParentIds = <String>[];
    final validParentNames = <String>[];
    for (var i = 0; i < parentIds.length; i++) {
      if (_isValidUuid(parentIds[i]) &&
          !validParentIds.contains(parentIds[i])) {
        validParentIds.add(parentIds[i]);
        validParentNames.add(
          i < parentNames.length ? parentNames[i] : 'Parent',
        );
      }
    }

    final adminName = AuthSessionService.instance.userName.isNotEmpty
        ? AuthSessionService.instance.userName
        : 'Admin Director';

    final convo = Conversation(
      id: UuidV4.generate(),
      title: title,
      isGroup: true,
      participantIds: [adminId, ...validParentIds],
      participantNames: [adminName, ...validParentNames],
      lastMessage: 'Group created by Admin.',
      lastMessageTime: DateTime.now(),
      halaqahId: (halaqahId != null && _isValidUuid(halaqahId))
          ? halaqahId
          : null,
      groupType: 'parent_group',
    );

    await _syncConversationToCloud(convo);
    await _saveConversationsCacheAndEmit(convo);

    await sendMessage(
      conversationId: convo.id,
      senderId: adminId,
      senderName: adminName,
      senderRole: AuthSessionService.instance.currentRole,
      content: 'As-salamu alaykum parents. Welcome to "$title".',
    );

    return convo;
  }

  /// Admin starts a 1-on-1 direct conversation with an individual parent.
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
    final adminName = AuthSessionService.instance.userName.isNotEmpty
        ? AuthSessionService.instance.userName
        : 'Admin Director';

    return _startOrReuseDirectChat(
      callerId: adminId,
      callerName: adminName,
      callerRole: AuthSessionService.instance.currentRole,
      otherUserId: parentId,
      otherName: parentName,
      title: parentName,
      groupType: 'direct_admin',
      initialMessage: initialMessage,
    );
  }

  /// Parent starts conversation with Admin or child's halaqah Teacher.
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
    String resolvedTargetId = targetId ?? '';
    String resolvedTargetName = targetName;
    if (targetRole == 'admin') {
      if (!_isValidUuid(resolvedTargetId)) {
        final adminContact = await _resolveAdminContact();
        if (adminContact != null) {
          resolvedTargetId = adminContact.id;
          resolvedTargetName = adminContact.name;
        }
      } else if (_isPlaceholderName(resolvedTargetName)) {
        final live = _profileNamesById[resolvedTargetId];
        if (live != null && live.trim().isNotEmpty) {
          resolvedTargetName = live.trim();
        }
      }
    } else if (!_isValidUuid(resolvedTargetId)) {
      resolvedTargetId = await _resolveTeacherUserId(
            halaqahId: halaqahId,
            halaqahName: halaqahName,
          ) ??
          '';
    }

    if (!_isValidUuid(resolvedTargetId)) {
      if (!ConnectivityService.instance.isOnline) {
        throw const OfflineActionException();
      }
      throw Exception(
        targetRole == 'admin'
            ? 'No active Center Director account is available right now.'
            : 'No Ustaz is currently assigned to your child\'s study circle.',
      );
    }

    return _startOrReuseDirectChat(
      callerId: parentId,
      callerName: parentName,
      callerRole: 'parent',
      otherUserId: resolvedTargetId,
      otherName: resolvedTargetName,
      title: resolvedTargetName,
      halaqahId: halaqahId,
      groupType: targetRole == 'admin' ? 'direct_admin' : 'direct_teacher',
      initialMessage: initialMessage,
    );
  }
}
