import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';

/// Central Notification Hub for Kheyrukum:
/// - Daily Attendance notifications for parents
/// - Weekly Progress report notifications for parents
/// - Monthly Fee payment reminders for parents
/// - Overdue Fee alerts for administrators
/// - Payment Submission alerts for administrators
/// - Payment Approval / Rejection (with reason) notifications for parents
class NotificationCenterService {
  NotificationCenterService._() {
    _initSampleNotifications();
  }

  static final NotificationCenterService instance = NotificationCenterService._();

  final List<AppNotification> _notifications = [];
  final StreamController<List<AppNotification>> _controller =
      StreamController<List<AppNotification>>.broadcast();

  Stream<List<AppNotification>> get stream => _controller.stream;
  List<AppNotification> get currentNotifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void _initSampleNotifications() {
    _notifications.addAll([
      AppNotification(
        id: 'notif-1',
        title: 'Daily Attendance: Present ✅',
        body: 'Abdur-Rahman arrived on time for Fajr Halaqah. Tajweed recitation was attentive.',
        type: 'attendance',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        data: {'student_name': 'Abdur-Rahman Muhammed', 'status': 'present'},
      ),
      AppNotification(
        id: 'notif-2',
        title: 'Weekly Quran Progress Report 📜',
        body: 'Weekly review for Abdur-Rahman completed: Surah Al-Mulk mastered with Excellent rating.',
        type: 'weekly_report',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        data: {'student_name': 'Abdur-Rahman Muhammed', 'grade': 'Excellent'},
      ),
      AppNotification(
        id: 'notif-3',
        title: 'Monthly Tuition Reminder 💳',
        body: 'Monthly halaqah tuition for October is due. Please upload your payment receipt screenshot.',
        type: 'payment_reminder',
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
        data: {'month': 'October 2026', 'amount': 50.0},
      ),
    ]);
    _controller.add(List.from(_notifications));
  }

  void addNotification({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) {
    final notif = AppNotification(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      data: data,
    );
    _notifications.insert(0, notif);
    _controller.add(List.from(_notifications));
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
    _controller.add(List.from(_notifications));
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
      _controller.add(List.from(_notifications));
    }
  }
}
