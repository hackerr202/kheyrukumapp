import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import '../utils/uuid_v4.dart';
import 'auth_session_service.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';

/// Central Notification Hub for Kheyrukum with user-scoped offline persistence.
class NotificationCenterService {
  NotificationCenterService._();

  static final NotificationCenterService instance =
      NotificationCenterService._();

  final List<AppNotification> _notifications = [];
  bool _cacheLoaded = false;
  final StreamController<List<AppNotification>> _controller =
      StreamController<List<AppNotification>>.broadcast();

  Stream<List<AppNotification>> get stream => _controller.stream;
  List<AppNotification> get currentNotifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  String get _uid => AuthSessionService.instance.userId.isNotEmpty
      ? AuthSessionService.instance.userId
      : (SupabaseService.instance.currentUser?.id ?? '');

  Future<void> _saveToCache() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    await LocalStorageService.instance.saveUserJsonList(
      uid,
      'notifications',
      _notifications.map((n) => n.toJson()).toList(),
    );
  }

  /// Restores saved in-app notifications for the currently authenticated user.
  Future<void> loadForCurrentUser() async {
    if (_cacheLoaded) return;
    final uid = _uid;
    if (uid.isEmpty) return;
    _cacheLoaded = true;
    try {
      final cached = await LocalStorageService.instance
          .getUserJsonList(uid, 'notifications');
      if (cached.isNotEmpty && _notifications.isEmpty) {
        for (final item in cached) {
          _notifications.add(AppNotification.fromJson(item));
        }
        if (!_controller.isClosed) {
          _controller.add(List.from(_notifications));
        }
      }
    } catch (e) {
      debugPrint('[NotificationCenter] Cache load note: $e');
    }
  }

  void addNotification({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) {
    final notif = AppNotification(
      id: UuidV4.generate(),
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      data: data,
    );
    _notifications.insert(0, notif);
    if (_notifications.length > 100) {
      _notifications.removeRange(100, _notifications.length);
    }
    if (!_controller.isClosed) {
      _controller.add(List.from(_notifications));
    }
    _saveToCache();
    debugPrint('[NotificationCenter] New notification: $title - $body');
  }

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = AppNotification(
        id: _notifications[i].id,
        title: _notifications[i].title,
        body: _notifications[i].body,
        type: _notifications[i].type,
        createdAt: _notifications[i].createdAt,
        isRead: true,
        data: _notifications[i].data,
      );
    }
    if (!_controller.isClosed) {
      _controller.add(List.from(_notifications));
    }
    _saveToCache();
  }

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = AppNotification(
        id: _notifications[idx].id,
        title: _notifications[idx].title,
        body: _notifications[idx].body,
        type: _notifications[idx].type,
        createdAt: _notifications[idx].createdAt,
        isRead: true,
        data: _notifications[idx].data,
      );
      if (!_controller.isClosed) {
        _controller.add(List.from(_notifications));
      }
      _saveToCache();
    }
  }

  Future<void> clearOnLogout() async {
    final uid = _uid;
    _notifications.clear();
    _cacheLoaded = false;
    if (!_controller.isClosed) {
      _controller.add([]);
    }
    if (uid.isNotEmpty) {
      await LocalStorageService.instance.removeUserCache(uid, 'notifications');
    }
  }
}
