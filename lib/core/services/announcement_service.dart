import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/announcement.dart';
import 'local_storage_service.dart';
import 'push_notification_service.dart';
import 'supabase_service.dart';

/// Service to handle real-time announcement broadcasting, streaming,
/// and instant notification delivery for Kheyrukum.
class AnnouncementService {
  AnnouncementService._();
  static final AnnouncementService instance = AnnouncementService._();

  final Set<String> _readIds = {};
  final Set<String> _knownIds = {};
  final StreamController<Announcement> _incomingAlertController =
      StreamController<Announcement>.broadcast();
  RealtimeChannel? _realtimeSubscription;
  final Set<String> _handledAnnouncementIds = {};

  Future<void> _loadReadIds() async {
    try {
      final raw =
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
      await LocalStorageService.instance.saveString(
        'read_announcement_ids',
        _readIds.join(','),
      );
    } catch (e) {
      debugPrint('[AnnouncementService] Error saving read IDs: $e');
    }
  }

  /// Stream of newly arrived announcements for triggering immediate popup notifications
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
    await _initRealtimeSubscription();
  }

  Future<void> clearOnLogout() async {
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
    _readIds.clear();
    _knownIds.clear();
    _handledAnnouncementIds.clear();
    await LocalStorageService.instance.remove('read_announcement_ids');
  }

  /// Listen for real-time announcements broadcast by other devices/admins
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
      debugPrint('[AnnouncementService] Error handling incoming announcement: $e');
    }
  }

  /// 1. Real-time stream of all announcements from Supabase
  Stream<List<Announcement>> streamAnnouncements() {
    final client = SupabaseService.instance.client;

    if (client == null || SupabaseService.instance.currentUser == null) {
      return Stream.value(<Announcement>[]);
    }

    return client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .map((data) {
          final list = data.map((json) => Announcement.fromJson(json)).toList();
          return list;
        });
  }

  /// 2. Post an announcement (Admin function)
  Future<Map<String, dynamic>> broadcastAnnouncement({
    required String title,
    required String content,
    String targetAudience = 'all',
    String authorName = 'Center Administration',
    bool isPinned = false,
    String? attachmentUrl,
    String? attachmentName,
  }) async {
    final client = SupabaseService.instance.client;
    if (client == null) {
      return {
        'success': false,
        'message':
            'Unable to connect to cloud service. Please check your internet connection.',
      };
    }

    final newRecord = {
      'title': title.trim(),
      'content': content.trim(),
      'target_audience': targetAudience,
      'author_name': authorName.trim(),
      'is_pinned': isPinned,
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final res =
          await client.from('announcements').insert(newRecord).select().single();
      final announcement = Announcement.fromJson(res);
      _handledAnnouncementIds.add(announcement.id);
      if (!_incomingAlertController.isClosed) {
        _incomingAlertController.add(announcement);
      }

      await PushNotificationService.instance.dispatchPushNotificationToAll(
        title: title,
        body: content,
        targetAudience: targetAudience,
        type: 'announcement',
        data: {
          'announcement_id': announcement.id,
          'target_audience': targetAudience,
        },
      );

      return {'success': true, 'data': announcement};
    } catch (e) {
      debugPrint('[AnnouncementService] Error posting announcement: $e');
      return {
        'success': false,
        'message': SupabaseService.cleanErrorMessage(e),
        'error': SupabaseService.cleanErrorMessage(e),
      };
    }
  }

  /// 3. Delete an announcement (Admin)
  Future<bool> deleteAnnouncement(String id) async {
    final client = SupabaseService.instance.client;
    if (client == null) return false;

    try {
      await client.from('announcements').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[AnnouncementService] Delete failed: $e');
      return false;
    }
  }
}
