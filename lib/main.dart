import 'package:flutter/material.dart';
import 'core/routes/app_routes.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const KheyrukumApp());
}


class KheyrukumApp extends StatelessWidget {
  const KheyrukumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kheyrukum - خيركم',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}
