import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_notifier.dart';
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
        builder: (_, __, ___) => ValueListenableBuilder<Locale>(
          valueListenable: LocaleNotifier.instance,
          builder: (sheetCtx, ___, ____) {
            final p = AppColors.of(sheetCtx);
            final loc = AppLocalizations.of(sheetCtx);
            return ProBottomSheetShell(
              title: loc.portalSettings,
              subtitle: loc.portalSettingsSubtitle,
              icon: Icons.settings_rounded,
              iconColor: p.primary,
              heightFactor: 0.88,
              child: const SettingsTab(),
            );
          },
        ),
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
