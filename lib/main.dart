import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/locale_notifier.dart';
import 'core/routes/app_routes.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.instance.initialize();
  await AppTheme.loadSavedTheme();
  await SupabaseService.initialize();
  await PushNotificationService.instance.initialize();
  runApp(const KheyrukumApp());
}

class KheyrukumApp extends StatelessWidget {
  const KheyrukumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
        );

        return ValueListenableBuilder<Locale>(
          valueListenable: LocaleNotifier.instance,
          builder: (context, appLocale, _) {
            return MaterialApp(
              title: 'Kheyrukum - خيركم',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
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
              ],
              initialRoute: AppRoutes.splash,
              routes: AppRoutes.routes,
            );
          },
        );
      },
    );
  }
}
