import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/locale_notifier.dart';
import 'core/routes/app_routes.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('[main] Firebase early initialization note: $e');
    }
  }

  try {
    await LocalStorageService.instance.initialize();
  } catch (e) {
    debugPrint('[main] LocalStorage initialization note: $e');
  }

  try {
    await ConnectivityService.instance.initialize();
  } catch (e) {
    debugPrint('[main] Connectivity initialization note: $e');
  }

  try {
    await AppTheme.loadSavedTheme();
  } catch (e) {
    debugPrint('[main] Theme load note: $e');
  }

  try {
    await LocaleNotifier.instance.loadSavedLocale();
  } catch (e) {
    debugPrint('[main] Locale load note: $e');
  }

  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('[main] Supabase initialization note: $e');
  }

  try {
    await PushNotificationService.instance.initialize();
  } catch (e) {
    debugPrint('[main] Push notification initialization note: $e');
  }

  runApp(const KheyrukumApp());
}

class KheyrukumApp extends StatelessWidget {
  const KheyrukumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: LocaleNotifier.instance,
          builder: (context, appLocale, _) {
            return MaterialApp(
              navigatorKey: AppRoutes.navigatorKey,
              title: 'Kheyrukum - خيركم',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.themeFor(Brightness.light, appLocale),
              darkTheme: AppTheme.themeFor(Brightness.dark, appLocale),
              themeMode: themeMode,
              locale: appLocale,
              supportedLocales: const [
                Locale('en'),
                Locale('ar'),
                Locale('am'),
              ],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                FallbackMaterialLocalizationsDelegate(),
                FallbackCupertinoLocalizationsDelegate(),
              ],
              builder: (context, child) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness:
                        isDark ? Brightness.light : Brightness.dark,
                    statusBarBrightness:
                        isDark ? Brightness.dark : Brightness.light,
                    systemNavigationBarColor: Colors.transparent,
                    systemNavigationBarIconBrightness:
                        isDark ? Brightness.light : Brightness.dark,
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },
              initialRoute: AppRoutes.splash,
              routes: AppRoutes.routes,
            );
          },
        );
      },
    );
  }
}
