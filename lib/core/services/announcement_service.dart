import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/announcement.dart';
import 'supabase_service.dart';

/// Service to handle real-time announcement broadcasting, streaming,
/// and instant notification delivery for Kheyrukum.
class AnnouncementService {
  AnnouncementService._();
  static final AnnouncementService instance = AnnouncementService._();

  final Set<String> _readIds = {};
  final StreamController<Announcement> _incomingAlertController =
      StreamController<Announcement>.broadcast();

  /// Stream of newly arrived announcements for triggering immediate popup notifications
  Stream<Announcement> get onNewAnnouncementAlert =>
      _incomingAlertController.stream;

  Set<String> get readIds => _readIds;

  void markAsRead(String id) {
    _readIds.add(id);
  }

  bool isRead(String id) => _readIds.contains(id);

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
          category: 'event',
          targetAudience: 'all',
          authorName: 'Ustaz Muhammed Yakut (Director)',
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
    String category = 'general',
    String targetAudience = 'all',
    String authorName = 'Ustaz Muhammed Yakut (Director)',
    bool isPinned = false,
  }) async {
    final client = SupabaseService.instance.client;

    final newRecord = {
      'title': title.trim(),
      'content': content.trim(),
      'category': category,
      'target_audience': targetAudience,
      'author_name': authorName.trim(),
      'is_pinned': isPinned,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (client == null) {
      debugPrint('[AnnouncementService] Supabase not initialized, mock broadcast.');
      final mock = Announcement(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        content: content,
        category: category,
        targetAudience: targetAudience,
        authorName: authorName,
        isPinned: isPinned,
        createdAt: DateTime.now(),
      );
      _incomingAlertController.add(mock);
      return {'success': true, 'data': mock};
    }

    try {
      final res = await client.from('announcements').insert(newRecord).select().single();
      final announcement = Announcement.fromJson(res);
      _incomingAlertController.add(announcement);
      return {'success': true, 'data': announcement};
    } catch (e) {
      debugPrint('[AnnouncementService] Error posting announcement: $e');
      return {'success': false, 'error': e.toString()};
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
