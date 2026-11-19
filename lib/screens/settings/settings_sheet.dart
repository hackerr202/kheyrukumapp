import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/pro_ui_kit.dart';
import '../dashboard/tabs/settings_tab.dart';

/// Modal bottom sheet and standalone route for Portal Settings.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ValueListenableBuilder<ThemeMode>(
        valueListenable: AppTheme.themeModeNotifier,
        builder: (context, __, ___) {
          final p = AppColors.of(context);
          return ProBottomSheetShell(
            title: 'Portal Settings',
            subtitle: 'Appearance & account preferences',
            icon: Icons.settings_rounded,
            iconColor: p.primary,
            heightFactor: 0.78,
            child: const SettingsTab(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: SettingsTab(),
      ),
    );
  }
}
