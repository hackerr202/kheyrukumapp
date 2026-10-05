import 'package:flutter/material.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/splash/splash_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String auth = '/auth';
  static const String dashboard = '/dashboard';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        auth: (context) => const AuthScreen(),
        dashboard: (context) => const DashboardScreen(),
      };
}

