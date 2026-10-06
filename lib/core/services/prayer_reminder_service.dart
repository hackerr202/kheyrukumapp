import 'dart:async';
import 'package:flutter/foundation.dart';
import 'notification_center_service.dart';

/// Periodic Prayer Reminder Service:
/// Dispatches prayer and Dhikr notifications every 10 minutes to all users (parents, teachers, and admin).
class PrayerReminderService {
  PrayerReminderService._();
  static final PrayerReminderService instance = PrayerReminderService._();

  Timer? _periodicTimer;
  Timer? _initialTimer;
  bool _isRunning = false;

  final StreamController<Map<String, String>> _prayerAlertController =
      StreamController<Map<String, String>>.broadcast();

  Stream<Map<String, String>> get onPrayerAlert => _prayerAlertController.stream;

  final List<Map<String, String>> _reminders = const [
    {
      'title': 'Prayer & Dhikr Reminder 🕌',
      'body': 'حَيَّ عَلَى الصَّلَاةِ - Turn your heart towards Allah. It is time for prayer and remembrance.',
    },
    {
      'title': 'Dhikr Reminder: Remembrance of Allah 📿',
      'body': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ - Take a moment to remember Allah.',
    },
    {
      'title': 'Salawat Reminder: Blessings on the Prophet 🤲',
      'body': 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ - Send peace and blessings upon our beloved Prophet ﷺ.',
    },
    {
      'title': 'Quran Reflection & Dua 📖',
      'body': 'رَبِّ زِدْنِي عِلْمًا - Renew your intention and maintain consistency in daily Quran memorization.',
    },
    {
      'title': 'Prayer Time Alert ⏱️',
      'body': 'Do not delay your prayer; prayer at its appointed time is among the most beloved deeds to Allah.',
    },
    {
      'title': 'Istighfar & Repentance 🤍',
      'body': 'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ وَأَتُوبُ إِلَيْهِ - Seek forgiveness and purify your heart.',
    },
  ];

  int _currentIndex = 0;

  /// Start the 10-minute prayer reminder loop
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    debugPrint('[PrayerReminderService] Started 10-minute prayer reminder schedule.');

    // 1. Initial reminder 8 seconds after app start so user immediately verifies it
    _initialTimer?.cancel();
    _initialTimer = Timer(const Duration(seconds: 8), () {
      triggerPrayerReminderNow();
    });

    // 2. Periodic reminder every 10 minutes
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      triggerPrayerReminderNow();
    });
  }

  /// Stop the reminder loop
  void stop() {
    _isRunning = false;
    _initialTimer?.cancel();
    _periodicTimer?.cancel();
  }

  /// Trigger a prayer reminder immediately
  void triggerPrayerReminderNow() {
    final reminder = _reminders[_currentIndex % _reminders.length];
    _currentIndex++;

    final title = reminder['title']!;
    final body = reminder['body']!;

    // 1. Add to central NotificationCenterService (available to all users & admin)
    NotificationCenterService.instance.addNotification(
      title: title,
      body: body,
      type: 'prayer',
      data: {
        'scheduled': '10_minute_prayer_interval',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    // 2. Broadcast for real-time in-app alert banner
    _prayerAlertController.add({'title': title, 'body': body});

    debugPrint('[PrayerReminderService] Dispatched prayer reminder: $title');
  }
}
