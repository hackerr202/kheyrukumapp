import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/announcement.dart';
import 'notification_center_service.dart';
import 'push_notification_service.dart';
import 'supabase_service.dart';

/// Service to handle real-time announcement broadcasting, streaming,
/// and instant notification delivery for Kheyrukum.
class AnnouncementService {
  AnnouncementService._() {
    _initRealtimeSubscription();
  }
  static final AnnouncementService instance = AnnouncementService._();

  final Set<String> _readIds = {};
  final StreamController<Announcement> _incomingAlertController =
      StreamController<Announcement>.broadcast();
  RealtimeChannel? _realtimeSubscription;
  final Set<String> _handledAnnouncementIds = {};

  /// Stream of newly arrived announcements for triggering immediate popup notifications
  Stream<Announcement> get onNewAnnouncementAlert =>
      _incomingAlertController.stream;

  Set<String> get readIds => _readIds;

  void markAsRead(String id) {
    _readIds.add(id);
  }

  bool isRead(String id) => _readIds.contains(id);

  /// Listen for real-time announcements broadcast by other devices/admins
  void _initRealtimeSubscription() {
    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      _realtimeSubscription?.unsubscribe();
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
      debugPrint('[AnnouncementService] Supabase Realtime announcements channel subscribed.');
    } catch (e) {
      debugPrint('[AnnouncementService] Realtime subscription note: $e');
    }
  }

  void _handleIncomingAnnouncement(Map<String, dynamic> json) {
    try {
      final announcement = Announcement.fromJson(json);
      if (_handledAnnouncementIds.contains(announcement.id)) return;
      _handledAnnouncementIds.add(announcement.id);

      // Trigger in-app toast banner
      _incomingAlertController.add(announcement);

      // Show real system notification in phone status bar & lock screen
      PushNotificationService.instance.showNotification(
        title: announcement.title.isNotEmpty ? announcement.title : 'New Announcement 📢',
        body: announcement.content,
        payload: announcement.id,
      );

      // Record in notification center
      NotificationCenterService.instance.addNotification(
        title: announcement.title.isNotEmpty ? announcement.title : 'New Announcement 📢',
        body: announcement.content,
        type: 'broadcast',
      );
    } catch (e) {
      debugPrint('[AnnouncementService] Error handling incoming announcement: $e');
    }
  }

  /// 1. Real-time stream of all announcements from Supabase
  Stream<List<Announcement>> streamAnnouncements() {
    final client = SupabaseService.instance.client;

    if (client == null) {
      // Fallback mock stream for preview / demo
      return Stream.value([
        Announcement(
          id: 'mock-1',
          title: 'Welcome to Kheyrukum Quranic Portal (ኸይሩኩም)',
          content:
              'Assalamu Alaikum. Welcome to the official parent-teacher communication system. Daily recitation submissions and Halaqah attendance tracking are now active.',
          targetAudience: 'all',
          authorName: 'Center Administration',
          isPinned: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ]);
    }

    // Subscribe to PostgreSQL Realtime changes on 'announcements' table
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
  /// Triggers immediate real-time broadcast via Supabase Realtime to all devices
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

    if (client == null) {
      debugPrint('[AnnouncementService] Supabase not initialized, mock broadcast.');
      final mock = Announcement(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        content: content,
        targetAudience: targetAudience,
        authorName: authorName,
        isPinned: isPinned,
        attachmentUrl: attachmentUrl,
        attachmentName: attachmentName,
        createdAt: DateTime.now(),
      );
      _incomingAlertController.add(mock);
      return {'success': true, 'data': mock};
    }

    try {
      final res = await client.from('announcements').insert(newRecord).select().single();
      final announcement = Announcement.fromJson(res);
      _handledAnnouncementIds.add(announcement.id);
      _incomingAlertController.add(announcement);

      // Trigger off-app background push notifications to all users' devices
      await PushNotificationService.instance.dispatchPushNotificationToAll(
        title: title,
        body: content,
        data: {'announcement_id': announcement.id},
      );

      return {'success': true, 'data': announcement};
    } catch (e) {
      debugPrint('[AnnouncementService] Error posting announcement: $e');
      return {'success': false, 'error': SupabaseService.cleanErrorMessage(e)};
    }
  }

  /// 3. Delete an announcement (Admin)
  Future<bool> deleteAnnouncement(String id) async {
    final client = SupabaseService.instance.client;
    if (client == null) return true;

    try {
      await client.from('announcements').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[AnnouncementService] Delete failed: $e');
      return false;
    }
  }
}
