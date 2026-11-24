import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'local_storage_service.dart';
import 'notification_center_service.dart';
import 'supabase_service.dart';

/// Top-level background handler invoked by Firebase Cloud Messaging when a
/// push message arrives while the app is terminated or in background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    if (!kIsWeb && Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('[FCM Background] Firebase init note: $e');
  }

  // Messages carrying a `notification` block are displayed natively by the OS tray.
  // Only render locally in background for pure data-only payloads so users never see duplicates.
  if (message.notification == null && message.data.isNotEmpty) {
    final title =
        message.data['title']?.toString() ?? 'Kheyrukum Islamic Center';
    final body = message.data['body']?.toString() ?? '';
    if (body.isNotEmpty) {
      await PushNotificationService.showBackgroundNotification(
        title: title,
        body: body,
        payload: jsonEncode({
          'type': message.data['type']?.toString() ?? 'general',
          if (message.data['conversation_id'] != null)
            'conversation_id': message.data['conversation_id']?.toString(),
        }),
      );
    }
  }
}

/// Service managing Firebase Cloud Messaging (free Spark plan), native Android/iOS
/// system notifications, background schedules, and Supabase token synchronization.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<Map<String, dynamic>> _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _isInitialized = false;
  bool _firebaseReady = false;
  bool _permissionsRequested = false;
  String? _cachedDeviceToken;
  String? _pendingRefreshToken;
  Map<String, dynamic>? _pendingNavigationIntent;
  final Map<String, DateTime> _recentShownNotifications = {};

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMsgSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  String? get deviceToken => _cachedDeviceToken;
  bool get isFirebaseReady => _firebaseReady;
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  static const String channelId = 'kheyrukum_channel';
  static const String channelName = 'Kheyrukum Center Notifications';
  static const String channelDescription =
      'Real-time alerts for messages, attendance, homework, announcements, and tuition';
  static const String _androidSmallIcon = '@drawable/ic_stat_kheyrukum';
  static const String _tokenStorageKey = 'persistent_device_token';
  static const String _tokenProviderKey = 'persistent_token_provider';
  static const String _cachedRoleKey = 'cached_push_role';

  /// Notification ID reservations
  static const int idDailyPrayer = 1001;
  static const int idMonthlyFee = 1002;
  static int _nextNotificationId = 2000;

  static int _allocateNotificationId() {
    final id = _nextNotificationId;
    _nextNotificationId =
        _nextNotificationId >= 2000000000 ? 2000 : _nextNotificationId + 1;
    return id;
  }

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Consume and clear a pending notification tap intent captured from a cold start.
  Map<String, dynamic>? consumePendingNavigationIntent() {
    final intent = _pendingNavigationIntent;
    _pendingNavigationIntent = null;
    return intent;
  }

  /// Configure tz.local using the device's current UTC offset (defaulting to Africa/Addis_Ababa).
  void _configureLocalTimeZone() {
    tz.initializeTimeZones();
    final targetOffset = DateTime.now().timeZoneOffset;
    try {
      final preferred = tz.getLocation('Africa/Addis_Ababa');
      if (tz.TZDateTime.now(preferred).timeZoneOffset == targetOffset) {
        tz.setLocalLocation(preferred);
        return;
      }
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (!loc.name.startsWith('Etc/') &&
            tz.TZDateTime.now(loc).timeZoneOffset == targetOffset) {
          tz.setLocalLocation(loc);
          return;
        }
      }
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (tz.TZDateTime.now(loc).timeZoneOffset == targetOffset) {
          tz.setLocalLocation(loc);
          return;
        }
      }
      tz.setLocalLocation(preferred);
    } catch (e) {
      debugPrint('[PushNotificationService] Timezone fallback note: $e');
    }
  }

  void _recordNotificationTap(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    final copy = Map<String, dynamic>.from(data);
    _pendingNavigationIntent = copy;
    if (!_notificationTapController.isClosed) {
      _notificationTapController.add(copy);
    }
  }

  Map<String, dynamic> _parseLocalPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return {};
    final trimmed = payload.trim();
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    if (_uuidRegex.hasMatch(trimmed)) {
      return {'type': 'message', 'conversation_id': trimmed};
    }
    return {'type': trimmed};
  }

  /// Helper used exclusively inside a background isolate when a data-only FCM
  /// push wakes the app without the main UI isolate running.
  static Future<void> showBackgroundNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      DartPluginRegistrant.ensureInitialized();
      final plugin = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings(_androidSmallIcon);
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
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
        2000 + (DateTime.now().millisecondsSinceEpoch % 90000),
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.max,
            priority: Priority.max,
            visibility: NotificationVisibility.public,
            playSound: true,
            enableVibration: true,
            icon: _androidSmallIcon,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(
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

  /// Initialize native notification channels and Firebase listeners (no OS permission prompts on boot).
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[PushNotificationService] Initializing notifications & FCM...');
      _configureLocalTimeZone();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings(_androidSmallIcon);

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          final parsed = _parseLocalPayload(details.payload);
          if (parsed.isNotEmpty) {
            _recordNotificationTap(parsed);
          }
        },
      );

      final launchDetails =
          await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        final parsed =
            _parseLocalPayload(launchDetails?.notificationResponse?.payload);
        if (parsed.isNotEmpty) {
          _pendingNavigationIntent = parsed;
        }
      }

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
      }

      _isInitialized = true;
      final cachedRole =
          await LocalStorageService.instance.getString(_cachedRoleKey);
      await scheduleMajorBackgroundNotifications(role: cachedRole);
      await _initializeFirebaseMessaging();
      await registerDeviceToken();
    } catch (e) {
      debugPrint('[PushNotificationService] Initialization error: $e');
    }
  }

  /// Request OS-level notification permissions cleanly after the user enters Dashboard.
  Future<void> requestNotificationPermissions() async {
    if (kIsWeb || _permissionsRequested) return;
    _permissionsRequested = true;

    try {
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      if (_firebaseReady) {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      }

      await registerDeviceToken();
    } catch (e) {
      debugPrint('[PushNotificationService] Permission request note: $e');
    }
  }

  /// Returns true when notifications are enabled for the app on this device.
  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    try {
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final enabled = await androidImplementation.areNotificationsEnabled();
        if (enabled != null) return enabled;
      }
      if (_firebaseReady) {
        final settings =
            await FirebaseMessaging.instance.getNotificationSettings();
        return settings.authorizationStatus ==
                AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Permission check note: $e');
    }
    return false;
  }

  /// Prompts for OS notification permission even if requested earlier, and re-syncs FCM token.
  Future<bool> promptAndSyncNotifications() async {
    _permissionsRequested = false;
    await requestNotificationPermissions();
    await registerDeviceToken();
    final cachedRole =
        await LocalStorageService.instance.getString(_cachedRoleKey);
    if (cachedRole != null && cachedRole.isNotEmpty) {
      await syncRoleSubscription(cachedRole);
    }
    return await areNotificationsEnabled();
  }

  /// Initialize Firebase Cloud Messaging without falling back to synthetic dummy tokens.
  Future<void> _initializeFirebaseMessaging() async {
    if (kIsWeb) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseReady = true;

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
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
        if (fcmToken != null &&
            fcmToken.isNotEmpty &&
            !fcmToken.startsWith('dev_')) {
          _cachedDeviceToken = fcmToken;
          await LocalStorageService.instance
              .saveString(_tokenStorageKey, fcmToken);
          await LocalStorageService.instance
              .saveString(_tokenProviderKey, 'fcm');
        }
      } catch (e) {
        debugPrint('[PushNotificationService] FCM getToken error: $e');
      }

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[PushNotificationService] FCM token refreshed.');
        final oldToken = _cachedDeviceToken;
        _cachedDeviceToken = newToken;
        await LocalStorageService.instance
            .saveString(_tokenStorageKey, newToken);
        await LocalStorageService.instance.saveString(_tokenProviderKey, 'fcm');

        final client = SupabaseService.instance.client;
        final user = SupabaseService.instance.currentUser;
        if (client == null || user == null) {
          _pendingRefreshToken = newToken;
          return;
        }

        if (oldToken != null &&
            oldToken.isNotEmpty &&
            oldToken != newToken) {
          try {
            await client
                .from('user_device_tokens')
                .delete()
                .eq('user_id', user.id)
                .eq('device_token', oldToken);
          } catch (e) {
            debugPrint(
                '[PushNotificationService] Stale token delete note: $e');
          }
        }
        await registerDeviceToken(newToken);
      });

      await _foregroundMsgSub?.cancel();
      _foregroundMsgSub =
          FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
        final title = msg.notification?.title ??
            msg.data['title']?.toString() ??
            'Kheyrukum Islamic Center';
        final body = msg.notification?.body ??
            msg.data['body']?.toString() ??
            '';
        final type = msg.data['type']?.toString() ?? 'general';
        if (title.isEmpty && body.isEmpty) return;

        final isIosForegroundNotification =
            !kIsWeb && Platform.isIOS && msg.notification != null;
        if (isIosForegroundNotification) {
          NotificationCenterService.instance.addNotification(
            title: title,
            body: body,
            type: type,
            data: msg.data,
          );
          return;
        }

        final payloadMap = {
          'type': type,
          if (msg.data['conversation_id'] != null)
            'conversation_id': msg.data['conversation_id']?.toString(),
        };
        showNotification(
          title: title,
          body: body,
          payload: jsonEncode(payloadMap),
          type: type,
          data: msg.data,
        );
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
        _recordNotificationTap({
          ...msg.data,
          'type': type,
        });
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
        _recordNotificationTap({
          ...initialMsg.data,
          'type': type,
        });
      }

      debugPrint('[PushNotificationService] Firebase Cloud Messaging active.');
    } catch (e, st) {
      _firebaseReady = false;
      debugPrint(
          '[PushNotificationService] CRITICAL: Firebase initialization failed: $e\n$st');
    }
  }

  /// Subscribe to the current user role topics and align recurring parent schedules.
  Future<void> syncRoleSubscription(String role) async {
    final cleanRole = role.toLowerCase().trim();
    if (!['superadmin', 'admin', 'teacher', 'parent'].contains(cleanRole)) {
      return;
    }

    await LocalStorageService.instance.saveString(_cachedRoleKey, cleanRole);
    await scheduleMajorBackgroundNotifications(role: cleanRole);

    if (kIsWeb || !_firebaseReady) return;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.subscribeToTopic('all_users');

      final desiredTopics = <String>{
        'role_$cleanRole',
        if (cleanRole == 'superadmin') ...['role_admin', 'admins'],
        if (cleanRole == 'admin') 'admins',
      };
      const allRoleTopics = [
        'role_superadmin',
        'role_admin',
        'admins',
        'role_teacher',
        'role_parent',
      ];
      for (final topic in allRoleTopics) {
        if (desiredTopics.contains(topic)) {
          await messaging.subscribeToTopic(topic);
        } else {
          await messaging.unsubscribeFromTopic(topic);
        }
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Role topic sync note: $e');
    }
  }

  /// Unlink current device token, topics, and parent schedules on sign-out.
  Future<void> unregisterOnLogout() async {
    final client = SupabaseService.instance.client;
    final user = SupabaseService.instance.currentUser;
    final tokenToDelete = _cachedDeviceToken ??
        await LocalStorageService.instance.getString(_tokenStorageKey);

    if (client != null &&
        user != null &&
        tokenToDelete != null &&
        tokenToDelete.isNotEmpty) {
      try {
        await client
            .from('user_device_tokens')
            .delete()
            .eq('user_id', user.id)
            .eq('device_token', tokenToDelete);
      } catch (e) {
        debugPrint('[PushNotificationService] Logout token cleanup note: $e');
      }
    }

    if (!kIsWeb && _firebaseReady) {
      try {
        final messaging = FirebaseMessaging.instance;
        const topicsToClear = [
          'all_users',
          'admins',
          'role_superadmin',
          'role_admin',
          'role_teacher',
          'role_parent',
        ];
        for (final topic in topicsToClear) {
          await messaging.unsubscribeFromTopic(topic);
        }
      } catch (_) {}
    }

    try {
      await _notificationsPlugin.cancel(idMonthlyFee);
    } catch (_) {}

    _cachedDeviceToken = null;
    _pendingRefreshToken = null;
    _pendingNavigationIntent = null;
    _recentShownNotifications.clear();
    await LocalStorageService.instance.remove(_tokenStorageKey);
    await LocalStorageService.instance.remove(_tokenProviderKey);
    await LocalStorageService.instance.remove(_cachedRoleKey);
  }

  /// Schedule background recurring notifications (Daily Prayer for all, Monthly Fee for parents only).
  Future<void> scheduleMajorBackgroundNotifications({String? role}) async {
    try {
      const prayerTitle = 'Daily Prayer Reminder 🕌';
      const prayerBody =
          'Don\'t forget to pray. Take a peaceful moment to remember Allah (حَيَّ عَلَى الصَّلَاةِ).';
      const feeTitle = 'Monthly Tuition Fee Reminder 💳';
      const feeBody =
          'Monthly Quran memorization fee is due. Please submit payment and upload receipt proof.';

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final prayerPlatformDetails = NotificationDetails(
        android: AndroidNotificationDetails(
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
          icon: _androidSmallIcon,
          styleInformation: BigTextStyleInformation(prayerBody),
        ),
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
        prayerTitle,
        prayerBody,
        prayerTime,
        prayerPlatformDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      final normalizedRole = role?.toLowerCase().trim() ?? '';
      if (normalizedRole == 'parent') {
        final feePlatformDetails = NotificationDetails(
          android: AndroidNotificationDetails(
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
            icon: _androidSmallIcon,
            styleInformation: BigTextStyleInformation(feeBody),
          ),
          iOS: iosDetails,
        );

        var feeTime = tz.TZDateTime(tz.local, now.year, now.month, 1, 9, 0);
        if (feeTime.isBefore(now)) {
          feeTime = (now.month == 12)
              ? tz.TZDateTime(tz.local, now.year + 1, 1, 1, 9, 0)
              : tz.TZDateTime(tz.local, now.year, now.month + 1, 1, 9, 0);
        }

        await _notificationsPlugin.zonedSchedule(
          idMonthlyFee,
          feeTitle,
          feeBody,
          feeTime,
          feePlatformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );
      } else {
        await _notificationsPlugin.cancel(idMonthlyFee);
      }
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
    Map<String, dynamic>? data,
  }) async {
    try {
      final dedupKey =
          '${type.toLowerCase().trim()}|${title.trim()}|${body.trim()}';
      final now = DateTime.now();
      _recentShownNotifications.removeWhere(
        (_, shownAt) => now.difference(shownAt).inSeconds >= 30,
      );
      final lastShown = _recentShownNotifications[dedupKey];
      if (lastShown != null && now.difference(lastShown).inSeconds < 15) {
        debugPrint(
            '[PushNotificationService] Suppressed duplicate local notification within 15s: $dedupKey');
        return;
      }
      _recentShownNotifications[dedupKey] = now;

      final notifId = id ?? _allocateNotificationId();

      final NotificationDetails platformDetails = NotificationDetails(
        android: AndroidNotificationDetails(
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
          icon: _androidSmallIcon,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _notificationsPlugin.show(
        notifId,
        title,
        body,
        platformDetails,
        payload: payload ?? jsonEncode({'type': type}),
      );

      NotificationCenterService.instance.addNotification(
        title: title,
        body: body,
        type: type,
        data: data,
      );
    } catch (e) {
      debugPrint(
          '[PushNotificationService] Error displaying notification: $e');
    }
  }

  /// Register or update the user's real FCM device token in Supabase.
  Future<void> registerDeviceToken([String? token]) async {
    if (kIsWeb) return;
    final client = SupabaseService.instance.client;
    final user = SupabaseService.instance.currentUser;
    if (client == null || user == null) {
      if (token != null && token.isNotEmpty && !token.startsWith('dev_')) {
        _pendingRefreshToken = token;
      }
      return;
    }

    if (!_firebaseReady) {
      debugPrint(
          '[PushNotificationService] Cannot register FCM token: Firebase is not initialized.');
      return;
    }

    String? tokenToSave = token ?? _pendingRefreshToken;
    if (tokenToSave == null ||
        tokenToSave.isEmpty ||
        tokenToSave.startsWith('dev_')) {
      try {
        tokenToSave = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        debugPrint('[PushNotificationService] FCM getToken failed: $e');
      }
    }

    if ((tokenToSave == null ||
            tokenToSave.isEmpty ||
            tokenToSave.startsWith('dev_')) &&
        _cachedDeviceToken != null &&
        _cachedDeviceToken!.isNotEmpty &&
        !_cachedDeviceToken!.startsWith('dev_')) {
      tokenToSave = _cachedDeviceToken;
    }

    if (tokenToSave == null ||
        tokenToSave.isEmpty ||
        tokenToSave.startsWith('dev_')) {
      debugPrint(
          '[PushNotificationService] Skipping device token registration: valid FCM token unavailable.');
      return;
    }

    _pendingRefreshToken = null;
    _cachedDeviceToken = tokenToSave;
    await LocalStorageService.instance.saveString(_tokenStorageKey, tokenToSave);
    await LocalStorageService.instance.saveString(_tokenProviderKey, 'fcm');

    try {
      final platform =
          Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'mobile');

      // Prune legacy synthetic local tokens if any remain from older builds
      try {
        await client
            .from('user_device_tokens')
            .delete()
            .eq('user_id', user.id)
            .like('device_token', 'dev_%');
      } catch (_) {}

      await client.from('user_device_tokens').upsert({
        'user_id': user.id,
        'device_token': tokenToSave,
        'device_type': platform,
        'platform': platform,
        'provider': 'fcm',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id, device_token');

      debugPrint('[PushNotificationService] Registered FCM device token.');
      await syncUnreadDatabaseNotifications();
    } catch (e) {
      debugPrint('[PushNotificationService] Device token registration error: $e');
    }
  }

  /// Sync unread notifications from database that occurred while the app was closed,
  /// marking global (user_id IS NULL) announcements read per-user via notification_reads.
  Future<void> syncUnreadDatabaseNotifications() async {
    final client = SupabaseService.instance.client;
    final user = SupabaseService.instance.currentUser;
    if (client == null || user == null) return;

    try {
      final rows = await client
          .from('notifications')
          .select('id, user_id, title, body, type, data, is_read, created_at')
          .or('user_id.eq.${user.id},user_id.is.null')
          .order('created_at', ascending: true)
          .limit(50);

      if (rows is! List || rows.isEmpty) return;

      final readGlobalIds = <String>{};
      try {
        final readRows = await client
            .from('notification_reads')
            .select('notification_id')
            .eq('user_id', user.id);
        if (readRows is List) {
          for (final r in readRows) {
            final nid = r['notification_id']?.toString();
            if (nid != null && nid.isNotEmpty) {
              readGlobalIds.add(nid);
            }
          }
        }
      } catch (e) {
        debugPrint(
            '[PushNotificationService] notification_reads lookup note: $e');
      }

      final directIdsToMark = <String>[];
      final globalIdsToMark = <String>[];

      for (final row in rows) {
        final notifId = row['id']?.toString() ?? '';
        final rowUserId = row['user_id']?.toString();
        final isDirect = rowUserId != null && rowUserId == user.id;

        if (isDirect) {
          if (row['is_read'] == true) continue;
          if (notifId.isNotEmpty) directIdsToMark.add(notifId);
        } else {
          if (notifId.isNotEmpty && readGlobalIds.contains(notifId)) continue;
          if (notifId.isNotEmpty) globalIdsToMark.add(notifId);
        }

        final title = row['title']?.toString() ?? 'Notification';
        final body = row['body']?.toString() ?? '';
        final type = row['type']?.toString() ?? 'general';
        final rowData = row['data'] is Map
            ? Map<String, dynamic>.from(row['data'] as Map)
            : null;
        NotificationCenterService.instance.addNotification(
          title: title,
          body: body,
          type: type,
          data: rowData,
        );
      }

      if (directIdsToMark.isNotEmpty) {
        await client
            .from('notifications')
            .update({'is_read': true})
            .inFilter('id', directIdsToMark)
            .eq('user_id', user.id);
      }

      if (globalIdsToMark.isNotEmpty) {
        await client.from('notification_reads').upsert(
          [
            for (final nid in globalIdsToMark)
              {
                'notification_id': nid,
                'user_id': user.id,
              },
          ],
          onConflict: 'notification_id,user_id',
        );
      }
    } catch (e) {
      debugPrint('[PushNotificationService] DB notification sync note: $e');
    }
  }

  /// Broadcast a remote FCM push notification to all devices matching [targetAudience]
  /// ('all', 'parents', 'teachers', or 'admins'). Requires admin/superadmin JWT.
  Future<void> dispatchPushNotificationToAll({
    required String title,
    required String body,
    String targetAudience = 'all',
    String type = 'broadcast',
    bool showLocally = true,
    Map<String, dynamic>? data,
  }) async {
    if (showLocally) {
      await showNotification(
        title: title,
        body: body,
        type: type,
        data: data,
      );
    }

    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      await client.functions.invoke('send-push-notification', body: {
        'title': title,
        'body': body,
        'target_audience': targetAudience,
        'type': type,
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

  /// Send a targeted remote FCM push notification to specific user IDs.
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
        if (cleanIds.isEmpty &&
            fallbackAudience != null &&
            fallbackAudience.isNotEmpty)
          'target_audience': fallbackAudience,
        'type': type,
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
