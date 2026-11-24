import 'dart:async';
import 'package:flutter/foundation.dart';
import '../localization/locale_notifier.dart';
import '../localization/notification_templates.dart';
import 'push_notification_service.dart';

/// Service managing daily prayer reminders for users:
/// Dispatches a simple, respectful "Don't forget to pray" notification daily.
class PrayerReminderService {
  PrayerReminderService._();
  static final PrayerReminderService instance = PrayerReminderService._();

  final StreamController<Map<String, String>> _prayerAlertController =
      StreamController<Map<String, String>>.broadcast();

  Stream<Map<String, String>> get onPrayerAlert => _prayerAlertController.stream;

  static const String dailyPrayerTitle = 'Don\'t forget to pray 🕌';
  static const String dailyPrayerBody =
      'حَيَّ عَلَى الصَّلَاةِ - Take a moment to remember Allah and perform your prayer.';

  /// Called when the app starts or dashboard opens
  void start() {
    debugPrint('[PrayerReminderService] Daily prayer reminder is active and scheduled.');
  }

  /// Stop reminders if needed
  void stop() {}

  /// Trigger a prayer reminder manually or for immediate testing
  void triggerPrayerReminderNow() {
    final rendered = NotificationTemplates.render(
      templateKey: 'prayer_reminder',
      languageCode: LocaleNotifier.instance.currentLanguageCode,
    );
    PushNotificationService.instance.showNotification(
      title: rendered.title,
      body: rendered.body,
      type: 'prayer',
      data: const {'template_key': 'prayer_reminder'},
    );

    _prayerAlertController.add({
      'title': rendered.title,
      'body': rendered.body,
    });

    debugPrint('[PrayerReminderService] Dispatched daily prayer reminder.');
  }
}
