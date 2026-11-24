import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/announcement.dart';
import '../utils/uuid_v4.dart';
import 'auth_session_service.dart';
import 'connectivity_service.dart';
import 'local_storage_service.dart';
import 'offline_sync_service.dart';
import 'push_notification_service.dart';
import 'supabase_service.dart';

/// Service to handle real-time announcement broadcasting, local-first streaming,
/// offline outbox queuing, and instant notification delivery for Kheyrukum.
class AnnouncementService {
  AnnouncementService._();
  static final AnnouncementService instance = AnnouncementService._();

  final List<Announcement> _announcements = [];
  bool _cacheLoaded = false;
  final Set<String> _readIds = {};
  final Set<String> _knownIds = {};
  final StreamController<Announcement> _incomingAlertController =
      StreamController<Announcement>.broadcast();
  final StreamController<List<Announcement>> _announcementsController =
      StreamController<List<Announcement>>.broadcast();
  RealtimeChannel? _realtimeSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _cloudListSub;
  final Set<String> _handledAnnouncementIds = {};

  String get _uid => AuthSessionService.instance.userId.isNotEmpty
      ? AuthSessionService.instance.userId
      : (SupabaseService.instance.currentUser?.id ?? '');

  List<Announcement> get cachedAnnouncements =>
      List.unmodifiable(_announcements);

  Future<void> _saveAnnouncementsCache() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    await LocalStorageService.instance.saveUserJsonList(
      uid,
      'announcements',
      _announcements.map((a) => a.toJson()).toList(),
    );
  }

  void _applyPendingAnnouncementOverlays() {
    final pending = OfflineSyncService.instance
        .pendingMutationsForEntity(OfflineEntityTypes.announcement);
    for (final mut in pending) {
      final p = mut.payload;
      final id = p['id']?.toString() ?? mut.id;
      if (id.isEmpty) continue;
      final item = Announcement.fromJson({
        ...p,
        'id': id,
        'created_at':
            p['created_at']?.toString() ?? mut.createdAt.toIso8601String(),
      });
      _announcements.removeWhere((a) => a.id == id);
      _announcements.insert(0, item);
    }
  }

  Future<void> _loadFromCache() async {
    if (_cacheLoaded) return;
    final uid = _uid;
    if (uid.isEmpty) return;
    _cacheLoaded = true;
    try {
      final cached = await LocalStorageService.instance
          .getUserJsonList(uid, 'announcements');
      if (cached.isNotEmpty && _announcements.isEmpty) {
        for (final item in cached) {
          _announcements.add(Announcement.fromJson(item));
        }
      }
      _applyPendingAnnouncementOverlays();
      if (_announcements.isNotEmpty && !_announcementsController.isClosed) {
        _announcementsController.add(List.from(_announcements));
      }
    } catch (e) {
      debugPrint('[AnnouncementService] Announcements cache load note: $e');
    }
  }

  Future<void> _loadReadIds() async {
    try {
      final uid = _uid;
      String? raw;
      if (uid.isNotEmpty) {
        final map = await LocalStorageService.instance
            .getUserJsonMap(uid, 'read_announcement_ids');
        raw = map?['ids']?.toString();
      }
      raw ??=
          await LocalStorageService.instance.getString('read_announcement_ids');
      _readIds.clear();
      if (raw != null && raw.isNotEmpty) {
        _readIds.addAll(raw.split(',').where((e) => e.isNotEmpty));
      }
    } catch (e) {
      debugPrint('[AnnouncementService] Error loading read IDs: $e');
    }
  }

  Future<void> _saveReadIds() async {
    try {
      final uid = _uid;
      if (uid.isNotEmpty) {
        await LocalStorageService.instance.saveUserJsonMap(
          uid,
          'read_announcement_ids',
          {'ids': _readIds.join(',')},
        );
      }
    } catch (e) {
      debugPrint('[AnnouncementService] Error saving read IDs: $e');
    }
  }

  /// Stream of newly arrived announcements for triggering immediate popup notifications.
  Stream<Announcement> get onNewAnnouncementAlert =>
      _incomingAlertController.stream;

  Set<String> get readIds => Set.unmodifiable(_readIds);

  void markAsRead(String id) {
    if (_readIds.add(id)) {
      _saveReadIds();
    }
  }

  void markAllAsRead() {
    if (_knownIds.isNotEmpty) {
      _readIds.addAll(_knownIds);
      _saveReadIds();
    }
  }

  void registerKnownIds(Iterable<String> ids) {
    _knownIds.addAll(ids);
  }

  bool isRead(String id) => _readIds.contains(id);

  Future<void> refreshAndSubscribe() async {
    await _loadReadIds();
    await _loadFromCache();
    await fetchFromCloud();
    _ensureCloudStream();
    await _initRealtimeSubscription();
  }

  /// Explicit cloud refresh used by pull-to-refresh and reconnect sync.
  Future<void> fetchFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;
    if (!ConnectivityService.instance.isOnline) return;
    try {
      final res = await client
          .from('announcements')
          .select()
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false)
          .limit(50);
      if (res is List) {
        _announcements
          ..clear()
          ..addAll(res.map(
            (j) => Announcement.fromJson(Map<String, dynamic>.from(j as Map)),
          ));
        _applyPendingAnnouncementOverlays();
        if (!_announcementsController.isClosed) {
          _announcementsController.add(List.from(_announcements));
        }
        await _saveAnnouncementsCache();
      }
    } catch (e) {
      debugPrint('[AnnouncementService] fetchFromCloud notice: $e');
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
      }
    }
  }

  Future<void> clearOnLogout() async {
    final uid = _uid;
    final client = SupabaseService.instance.client;
    final ch = _realtimeSubscription;
    _realtimeSubscription = null;
    if (ch != null) {
      try {
        await client?.removeChannel(ch);
      } catch (e) {
        debugPrint('[AnnouncementService] removeChannel note: $e');
      }
    }
    await _cloudListSub?.cancel();
    _cloudListSub = null;
    _announcements.clear();
    _cacheLoaded = false;
    _readIds.clear();
    _knownIds.clear();
    _handledAnnouncementIds.clear();
    if (!_announcementsController.isClosed) {
      _announcementsController.add([]);
    }
    if (uid.isNotEmpty) {
      await LocalStorageService.instance.removeUserCache(uid, 'announcements');
      await LocalStorageService.instance
          .removeUserCache(uid, 'read_announcement_ids');
    }
    await LocalStorageService.instance.remove('read_announcement_ids');
  }

  void _ensureCloudStream() {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;
    if (_cloudListSub != null) return;

    try {
      _cloudListSub = client
          .from('announcements')
          .stream(primaryKey: ['id'])
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false)
          .limit(50)
          .listen(
            (data) {
              _announcements
                ..clear()
                ..addAll(data.map((json) => Announcement.fromJson(json)));
              _applyPendingAnnouncementOverlays();
              if (!_announcementsController.isClosed) {
                _announcementsController.add(List.from(_announcements));
              }
              _saveAnnouncementsCache();
            },
            onError: (Object e) {
              debugPrint('[AnnouncementService] Stream error note: $e');
              if (ConnectivityService.isNetworkError(e)) {
                ConnectivityService.instance.reportNetworkFailure();
              }
            },
          );
    } catch (e) {
      debugPrint('[AnnouncementService] _ensureCloudStream note: $e');
    }
  }

  /// Listen for real-time announcements broadcast by other devices/admins.
  Future<void> _initRealtimeSubscription() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;

    try {
      final oldCh = _realtimeSubscription;
      _realtimeSubscription = null;
      if (oldCh != null) {
        await client.removeChannel(oldCh);
      }
      _realtimeSubscription = client
          .channel('public:announcements')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'announcements',
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                _handleIncomingAnnouncement(newRecord);
              }
            },
          )
          .subscribe();
      debugPrint(
          '[AnnouncementService] Supabase Realtime announcements channel subscribed.');
    } catch (e) {
      debugPrint('[AnnouncementService] Realtime subscription note: $e');
    }
  }

  void _handleIncomingAnnouncement(Map<String, dynamic> json) {
    try {
      final announcement = Announcement.fromJson(json);
      if (announcement.id.isEmpty ||
          _handledAnnouncementIds.contains(announcement.id)) {
        return;
      }
      _handledAnnouncementIds.add(announcement.id);

      _announcements.removeWhere((a) => a.id == announcement.id);
      _announcements.insert(0, announcement);
      if (!_announcementsController.isClosed) {
        _announcementsController.add(List.from(_announcements));
      }
      _saveAnnouncementsCache();

      if (!_incomingAlertController.isClosed) {
        _incomingAlertController.add(announcement);
      }

      PushNotificationService.instance.showNotification(
        title: announcement.title.isNotEmpty
            ? announcement.title
            : 'New Announcement 📢',
        body: announcement.content,
        payload: announcement.id,
        type: 'announcement',
      );
    } catch (e) {
      debugPrint(
          '[AnnouncementService] Error handling incoming announcement: $e');
    }
  }

  /// Local-first real-time stream of announcements (immediately emits cached + queued items).
  Stream<List<Announcement>> streamAnnouncements() {
    unawaited(_loadFromCache());
    _ensureCloudStream();

    return Stream<List<Announcement>>.multi((controller) {
      if (_announcements.isNotEmpty) {
        controller.add(List.from(_announcements));
      } else {
        unawaited(() async {
          await _loadFromCache();
          if (!controller.isClosed) {
            controller.add(List.from(_announcements));
          }
        }());
      }
      final sub = _announcementsController.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  /// Post an announcement (Admin function, queues cleanly when offline).
  Future<Map<String, dynamic>> broadcastAnnouncement({
    required String title,
    required String content,
    String targetAudience = 'all',
    String authorName = 'Center Administration',
    bool isPinned = false,
    String? attachmentUrl,
    String? attachmentName,
  }) async {
    final announcementId = UuidV4.generate();
    final createdAt = DateTime.now();
    final createdAtIso = createdAt.toUtc().toIso8601String();

    final newRecord = <String, dynamic>{
      'id': announcementId,
      'title': title.trim(),
      'content': content.trim(),
      'target_audience': targetAudience,
      'author_name': authorName.trim(),
      'is_pinned': isPinned,
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
      'created_at': createdAtIso,
    };

    Future<Announcement> applyLocally({
      required String resolvedId,
      required DateTime resolvedCreatedAt,
      required bool queueOffline,
    }) async {
      final announcement = Announcement(
        id: resolvedId,
        title: title.trim(),
        content: content.trim(),
        targetAudience: targetAudience,
        authorName: authorName.trim(),
        isPinned: isPinned,
        attachmentUrl: attachmentUrl,
        attachmentName: attachmentName,
        createdAt: resolvedCreatedAt,
      );
      _handledAnnouncementIds.add(resolvedId);
      _announcements.removeWhere((a) => a.id == resolvedId);
      _announcements.insert(0, announcement);
      if (!_announcementsController.isClosed) {
        _announcementsController.add(List.from(_announcements));
      }
      await _saveAnnouncementsCache();

      if (queueOffline) {
        await OfflineSyncService.instance.enqueue(
          entityType: OfflineEntityTypes.announcement,
          operation: 'upsert',
          id: resolvedId,
          payload: newRecord,
          displayLabel: 'Announcement: ${title.trim()}',
          triggerImmediateSync: false,
        );
      } else {
        if (!_incomingAlertController.isClosed) {
          _incomingAlertController.add(announcement);
        }
      }
      return announcement;
    }

    final client = SupabaseService.instance.client;
    if (!ConnectivityService.instance.isOnline || client == null) {
      final ann = await applyLocally(
        resolvedId: announcementId,
        resolvedCreatedAt: createdAt,
        queueOffline: true,
      );
      return {'success': true, 'data': ann, 'offline': true};
    }

    try {
      final res = await client
          .from('announcements')
          .upsert(newRecord, onConflict: 'id')
          .select()
          .single();
      final parsed = Announcement.fromJson(res);
      final ann = await applyLocally(
        resolvedId: parsed.id,
        resolvedCreatedAt: parsed.createdAt,
        queueOffline: false,
      );

      await PushNotificationService.instance.dispatchPushNotificationToAll(
        title: title,
        body: content,
        targetAudience: targetAudience,
        type: 'announcement',
        data: {
          'announcement_id': ann.id,
          'target_audience': targetAudience,
        },
      );

      return {'success': true, 'data': ann};
    } catch (e) {
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
        final ann = await applyLocally(
          resolvedId: announcementId,
          resolvedCreatedAt: createdAt,
          queueOffline: true,
        );
        return {'success': true, 'data': ann, 'offline': true};
      }
      debugPrint('[AnnouncementService] Error posting announcement: $e');
      return {
        'success': false,
        'message': SupabaseService.cleanErrorMessage(e),
        'error': SupabaseService.cleanErrorMessage(e),
      };
    }
  }

  /// Delete an announcement (Admin, online required).
  Future<bool> deleteAnnouncement(String id) async {
    if (!ConnectivityService.instance.isOnline &&
        !await ConnectivityService.instance.checkNow()) {
      return false;
    }
    final client = SupabaseService.instance.client;
    if (client == null) return false;

    try {
      await client.from('announcements').delete().eq('id', id);
      _announcements.removeWhere((a) => a.id == id);
      if (!_announcementsController.isClosed) {
        _announcementsController.add(List.from(_announcements));
      }
      await _saveAnnouncementsCache();
      return true;
    } catch (e) {
      debugPrint('[AnnouncementService] Delete failed: $e');
      return false;
    }
  }
}
