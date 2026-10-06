import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../dashboard/tabs/settings_tab.dart';

import '../../core/theme/app_theme.dart';

/// Modal bottom sheet and standalone screen for Portal Settings.
/// Accessed directly from the top navigation bar beside the notifications bell.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ValueListenableBuilder<ThemeMode>(
        valueListenable: AppTheme.themeModeNotifier,
        builder: (context, themeMode, _) {
          final isDark = themeMode == ThemeMode.dark;
          final sheetBg = isDark ? const Color(0xFF161927) : const Color(0xFFFFFFFF);
          final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
          final subtextColor = isDark ? Colors.white70 : AppColors.textSecondaryLight;
          final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

          return Container(
            height: MediaQuery.of(sheetContext).size.height * 0.88,
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag Handle & Header
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00BCD4).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.settings_outlined, color: Color(0xFF00BCD4), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Portal Settings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: subtextColor,
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 16, color: borderColor),
                const Expanded(
                  child: SettingsTab(),
                ),
              ],
            ),
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
