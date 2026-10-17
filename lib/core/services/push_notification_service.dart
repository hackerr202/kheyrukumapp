import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_center_service.dart';
import 'supabase_service.dart';

/// Service responsible for managing native Android & iOS system push notifications.
///
/// Ensures parents and teachers receive alerts on their phone status bar, heads-up banner,
/// and lock screen with sound and vibration.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _cachedDeviceToken;

  String? get deviceToken => _cachedDeviceToken;

  static const String channelId = 'kheyrukum_channel';
  static const String channelName = 'Kheyrukum Center Notifications';
  static const String channelDescription =
      'Realtime notifications for attendance, homework, announcements, and messaging';

  /// Initialize native notification channels and request system permissions
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[PushNotificationService] Initializing native notification handler...');

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
          debugPrint('[PushNotificationService] Notification clicked with payload: ${details.payload}');
        },
      );

      // Create high-importance Android Notification Channel
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

        // Request runtime permission for Android 13+ (API 33+)
        await androidImplementation.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('[PushNotificationService] Native notifications ready and channel created.');

      // Register device token with backend
      await registerDeviceToken();
    } catch (e) {
      debugPrint('[PushNotificationService] Initialization error: $e');
    }
  }

  /// Display a real native Android/iOS system notification in the status bar & notification tray
  Future<void> showNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final notifId = id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
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

      // Also sync to in-app notification center bell badge
      NotificationCenterService.instance.addNotification(
        title: title,
        body: body,
        type: 'broadcast',
      );

      debugPrint('[PushNotificationService] System notification posted: "$title"');
    } catch (e) {
      debugPrint('[PushNotificationService] Error displaying notification: $e');
    }
  }

  /// Register or update the user's phone device token in Supabase
  Future<void> registerDeviceToken([String? token]) async {
    final client = SupabaseService.instance.client;
    final user = SupabaseService.instance.currentUser;
    if (client == null) return;

    final tokenToSave = token ?? _cachedDeviceToken ?? 'dev_token_${DateTime.now().millisecondsSinceEpoch}';
    _cachedDeviceToken = tokenToSave;

    try {
      final platform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web');

      await client.from('user_device_tokens').upsert({
        'user_id': user?.id,
        'device_token': tokenToSave,
        'device_type': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id, device_token');

      debugPrint('[PushNotificationService] Device token registered: $tokenToSave');
    } catch (e) {
      debugPrint('[PushNotificationService] Note: Device token registration: $e');
    }
  }

  /// Trigger a remote push broadcast to all registered devices and show immediate native alert
  Future<void> dispatchPushNotificationToAll({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Show immediate native system notification on local device
    await showNotification(title: title, body: body);

    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      await client.functions.invoke('send-push-notification', body: {
        'title': title,
        'body': body,
        'data': data ?? {},
      });
    } catch (e) {
      debugPrint('[PushNotificationService] Cloud push webhook invoke note: $e');
    }
  }
}
