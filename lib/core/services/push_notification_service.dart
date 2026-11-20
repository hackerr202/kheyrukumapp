import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'local_storage_service.dart';
import 'notification_center_service.dart';
import 'supabase_service.dart';

/// Top-level background handler invoked by Firebase Cloud Messaging when a
/// notification/data message arrives while the app is terminated or in background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('[FCM Background] Firebase init note: $e');
  }

  // If FCM delivered a notification payload, Android/iOS renders it natively in system tray.
  // If it is a data-only payload, render a native heads-up notification manually.
  if (message.notification == null && message.data.isNotEmpty) {
    final title =
        message.data['title']?.toString() ?? 'Kheyrukum Islamic Center';
    final body = message.data['body']?.toString() ?? '';
    if (body.isNotEmpty) {
      await PushNotificationService.showBackgroundNotification(
        title: title,
        body: body,
        payload: message.data['type']?.toString(),
      );
    }
  }
}

/// Service managing Firebase Cloud Messaging (free Spark plan) + native Android/iOS
/// system notifications, background schedules, and Supabase token synchronization.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _firebaseReady = false;
  String? _cachedDeviceToken;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMsgSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  String? get deviceToken => _cachedDeviceToken;
  bool get isFirebaseReady => _firebaseReady;

  static const String channelId = 'kheyrukum_channel';
  static const String channelName = 'Kheyrukum Center Notifications';
  static const String channelDescription =
      'Real-time alerts for messages, attendance, homework, announcements, and tuition';

  /// Notification ID reservations
  static const int idDailyPrayer = 1001;
  static const int idMonthlyFee = 1002;

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Helper used exclusively inside a background isolate when a data-only FCM
  /// push wakes the app without the main UI isolate running.
  static Future<void> showBackgroundNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );

      final androidImpl = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            showBadge: true,
          ),
        );
      }

      await plugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.max,
            priority: Priority.max,
            visibility: NotificationVisibility.public,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
            styleInformation: BigTextStyleInformation(''),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[PushNotificationService] Background notification note: $e');
    }
  }

  /// Initialize native notification channels, permissions, recurring schedules, and Firebase FCM.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[PushNotificationService] Initializing notifications & FCM...');
      tz.initializeTimeZones();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          debugPrint(
              '[PushNotificationService] Notification tapped: ${details.payload}');
        },
      );

      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        const AndroidNotificationChannel alertChannel =
            AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        );

        await androidImplementation.createNotificationChannel(alertChannel);
        await androidImplementation.requestNotificationsPermission();

        try {
          await androidImplementation.requestExactAlarmsPermission();
        } catch (e) {
          debugPrint('[PushNotificationService] Exact alarm request note: $e');
        }
      }

      _isInitialized = true;
      await scheduleMajorBackgroundNotifications();
      await _initializeFirebaseMessaging();
      await registerDeviceToken();
    } catch (e) {
      debugPrint('[PushNotificationService] Initialization error: $e');
    }
  }

  /// Initialize Firebase Cloud Messaging safely (gracefully degrades if google-services.json
  /// is not yet bundled in the APK).
  Future<void> _initializeFirebaseMessaging() async {
    if (kIsWeb) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseReady = true;

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      try {
        await messaging.subscribeToTopic('all_users');
      } catch (e) {
        debugPrint('[PushNotificationService] Topic subscribe note: $e');
      }

      try {
        final fcmToken = await messaging.getToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          _cachedDeviceToken = fcmToken;
          await LocalStorageService.instance
              .saveString('persistent_device_token', fcmToken);
          await LocalStorageService.instance
              .saveString('persistent_token_provider', 'fcm');
        }
      } catch (e) {
        debugPrint('[PushNotificationService] FCM getToken note: $e');
      }

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[PushNotificationService] FCM token refreshed.');
        _cachedDeviceToken = newToken;
        await registerDeviceToken(newToken);
      });

      await _foregroundMsgSub?.cancel();
      _foregroundMsgSub = FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
        final title = msg.notification?.title ??
            msg.data['title']?.toString() ??
            'Kheyrukum Islamic Center';
        final body = msg.notification?.body ??
            msg.data['body']?.toString() ??
            '';
        final type = msg.data['type']?.toString() ?? 'general';
        if (title.isNotEmpty || body.isNotEmpty) {
          showNotification(
            title: title,
            body: body,
            payload: msg.data['conversation_id']?.toString() ?? type,
            type: type,
          );
        }
      });

      await _openedAppSub?.cancel();
      _openedAppSub =
          FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
        final title = msg.notification?.title ??
            msg.data['title']?.toString() ??
            'Notification';
        final body =
            msg.notification?.body ?? msg.data['body']?.toString() ?? '';
        final type = msg.data['type']?.toString() ?? 'general';
        if (body.isNotEmpty) {
          NotificationCenterService.instance.addNotification(
            title: title,
            body: body,
            type: type,
            data: msg.data,
          );
        }
      });

      final initialMsg = await messaging.getInitialMessage();
      if (initialMsg != null) {
        final title = initialMsg.notification?.title ??
            initialMsg.data['title']?.toString() ??
            'Notification';
        final body = initialMsg.notification?.body ??
            initialMsg.data['body']?.toString() ??
            '';
        final type = initialMsg.data['type']?.toString() ?? 'general';
        if (body.isNotEmpty) {
          NotificationCenterService.instance.addNotification(
            title: title,
            body: body,
            type: type,
            data: initialMsg.data,
          );
        }
      }

      debugPrint('[PushNotificationService] Firebase Cloud Messaging active.');
    } catch (e) {
      _firebaseReady = false;
      debugPrint(
          '[PushNotificationService] Firebase config not active yet (local alerts remain active): $e');
    }
  }

  /// Subscribe to the current user role topic for free Spark-plan group broadcasts.
  Future<void> syncRoleSubscription(String role) async {
    if (!_firebaseReady) return;
    final cleanRole = role.toLowerCase().trim();
    if (!['admin', 'teacher', 'parent'].contains(cleanRole)) return;

    try {
      final messaging = FirebaseMessaging.instance;
      for (final candidate in ['admin', 'teacher', 'parent']) {
        final topic = 'role_$candidate';
        if (candidate == cleanRole) {
          await messaging.subscribeToTopic(topic);
        } else {
          await messaging.unsubscribeFromTopic(topic);
        }
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Role topic sync note: $e');
    }
  }

  /// Unlink current device token and role topics on sign-out so signed-out phones
  /// do not receive private notifications for the prior account.
  Future<void> unregisterOnLogout() async {
    final client = SupabaseService.instance.client;
    final user = SupabaseService.instance.currentUser;
    if (client != null &&
        user != null &&
        _cachedDeviceToken != null &&
        _cachedDeviceToken!.isNotEmpty) {
      try {
        await client
            .from('user_device_tokens')
            .delete()
            .eq('user_id', user.id)
            .eq('device_token', _cachedDeviceToken!);
      } catch (e) {
        debugPrint('[PushNotificationService] Logout token cleanup note: $e');
      }
    }

    if (_firebaseReady) {
      try {
        final messaging = FirebaseMessaging.instance;
        for (final candidate in ['admin', 'teacher', 'parent']) {
          await messaging.unsubscribeFromTopic('role_$candidate');
        }
      } catch (_) {}
    }
  }

  /// Schedule background recurring notifications (Daily Prayer & Monthly Fee)
  Future<void> scheduleMajorBackgroundNotifications() async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        channelShowBadge: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final now = tz.TZDateTime.now(tz.local);
      var prayerTime =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, 12, 30);
      if (prayerTime.isBefore(now)) {
        prayerTime = prayerTime.add(const Duration(days: 1));
      }

      await _notificationsPlugin.zonedSchedule(
        idDailyPrayer,
        'Daily Prayer Reminder 🕌',
        'Don\'t forget to pray. Take a peaceful moment to remember Allah (حَيَّ عَلَى الصَّلَاةِ).',
        prayerTime,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      var feeTime = tz.TZDateTime(tz.local, now.year, now.month, 1, 9, 0);
      if (feeTime.isBefore(now)) {
        feeTime = (now.month == 12)
            ? tz.TZDateTime(tz.local, now.year + 1, 1, 1, 9, 0)
            : tz.TZDateTime(tz.local, now.year, now.month + 1, 1, 9, 0);
      }

      await _notificationsPlugin.zonedSchedule(
        idMonthlyFee,
        'Monthly Tuition Fee Reminder 💳',
        'Monthly Quran memorization fee is due. Please submit payment and upload receipt proof.',
        feeTime,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    } catch (e) {
      debugPrint('[PushNotificationService] Note: background scheduling: $e');
    }
  }

  /// Display a real native Android/iOS system notification in the status bar & notification tray.
  Future<void> showNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
    String type = 'broadcast',
  }) async {
    try {
      final notifId =
          id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        channelShowBadge: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        notifId,
        title,
        body,
        platformDetails,
        payload: payload,
      );

      NotificationCenterService.instance.addNotification(
        title: title,
        body: body,
        type: type,
      );
    } catch (e) {
      debugPrint(
          '[PushNotificationService] Error displaying notification: $e');
    }
  }

  /// Register or update the user's persistent FCM device token in Supabase.
  Future<void> registerDeviceToken([String? token]) async {
    final client = SupabaseService.instance.client;
    final user = SupabaseService.instance.currentUser;
    if (client == null || user == null) return;

    String? tokenToSave = token;
    if ((tokenToSave == null || tokenToSave.isEmpty) && _firebaseReady) {
      try {
        tokenToSave = await FirebaseMessaging.instance.getToken();
      } catch (_) {}
    }

    if (tokenToSave == null || tokenToSave.isEmpty) {
      if (_cachedDeviceToken != null &&
          _cachedDeviceToken!.isNotEmpty &&
          (!_firebaseReady || !_cachedDeviceToken!.startsWith('dev_'))) {
        tokenToSave = _cachedDeviceToken;
      }
    }

    bool isRealFcm =
        tokenToSave != null && tokenToSave.isNotEmpty && !tokenToSave.startsWith('dev_');

    if (tokenToSave == null || tokenToSave.isEmpty) {
      final stored = await LocalStorageService.instance
          .getString('persistent_device_token');
      if (stored != null && stored.isNotEmpty) {
        tokenToSave = stored;
        isRealFcm = !stored.startsWith('dev_');
      } else {
        tokenToSave =
            'dev_${user.id.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}';
        isRealFcm = false;
      }
    }

    _cachedDeviceToken = tokenToSave;
    await LocalStorageService.instance
        .saveString('persistent_device_token', tokenToSave);
    await LocalStorageService.instance
        .saveString('persistent_token_provider', isRealFcm ? 'fcm' : 'local');

    try {
      final platform =
          Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web');

      if (isRealFcm) {
        // Prune old dummy local tokens for this user once a real FCM token is active
        try {
          await client
              .from('user_device_tokens')
              .delete()
              .eq('user_id', user.id)
              .like('device_token', 'dev_%');
        } catch (_) {}
      }

      await client.from('user_device_tokens').upsert({
        'user_id': user.id,
        'device_token': tokenToSave,
        'device_type': platform,
        'provider': isRealFcm ? 'fcm' : 'local',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id, device_token');

      debugPrint(
          '[PushNotificationService] Registered ${isRealFcm ? 'FCM' : 'local'} device token.');
    } catch (e) {
      debugPrint('[PushNotificationService] Device token registration note: $e');
    }
  }

  /// Broadcast a remote FCM push notification to all devices matching [targetAudience]
  /// ('all', 'parents', 'teachers', or 'admins').
  Future<void> dispatchPushNotificationToAll({
    required String title,
    required String body,
    String targetAudience = 'all',
    String type = 'broadcast',
    bool showLocally = true,
    Map<String, dynamic>? data,
  }) async {
    if (showLocally) {
      await showNotification(title: title, body: body, type: type);
    }

    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      await client.functions.invoke('send-push-notification', body: {
        'title': title,
        'body': body,
        'target_audience': targetAudience,
        'type': type,
        'exclude_user_id': SupabaseService.instance.currentUser?.id,
        'data': {
          ...?data,
          'type': type,
        },
      });
    } catch (e) {
      debugPrint(
          '[PushNotificationService] Cloud push broadcast invoke note: $e');
    }
  }

  /// Send a targeted remote FCM push notification to specific user IDs (e.g. parent, teacher, or chat recipient).
  Future<void> dispatchPushToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    String type = 'general',
    String? fallbackAudience,
    Map<String, dynamic>? data,
  }) async {
    final client = SupabaseService.instance.client;
    if (client == null) return;

    final selfId = SupabaseService.instance.currentUser?.id;
    final cleanIds = userIds
        .map((id) => id.trim())
        .where((id) => _uuidRegex.hasMatch(id) && id != selfId)
        .toSet()
        .toList();

    if (cleanIds.isEmpty &&
        (fallbackAudience == null || fallbackAudience.isEmpty)) {
      return;
    }

    try {
      await client.functions.invoke('send-push-notification', body: {
        'title': title,
        'body': body,
        'user_ids': cleanIds,
        if (fallbackAudience != null && fallbackAudience.isNotEmpty)
          'target_audience': fallbackAudience,
        'type': type,
        'exclude_user_id': selfId,
        'data': {
          ...?data,
          'type': type,
        },
      });
    } catch (e) {
      debugPrint(
          '[PushNotificationService] Cloud targeted push invoke note: $e');
    }
  }
}
