import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/absence_service.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/halaqah_service.dart';
import '../../../core/services/homework_service.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/student_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/pro_ui_kit.dart';

/// Flagship Settings & Profile Tab:
/// 1. User profile card with unified role pill
/// 2. Visual side-by-side Appearance Picker (Warm Sanctuary Light vs Emerald Night Dark)
/// 3. Clean Sign Out clearing stack to Auth screen
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  Future<void> _handleSignOut() async {
    await PushNotificationService.instance.unregisterOnLogout();
    AuthSessionService.instance.clearSession();
    await Future.wait([
      StudentService.instance.clearOnLogout(),
      HalaqahService.instance.clearOnLogout(),
      HomeworkService.instance.clearOnLogout(),
      AbsenceService.instance.clearOnLogout(),
      MessagingService.instance.clearOnLogout(),
    ]);
    await SupabaseService.instance.signOut();
    if (mounted) {
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil(AppRoutes.auth, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        final p = AppColors.of(context);
        final isDark = themeMode == ThemeMode.dark;

        return ValueListenableBuilder<String>(
          valueListenable: AuthSessionService.instance.roleNotifier,
          builder: (context, currentRole, _) {
            final isAdmin = currentRole == 'admin';
            final isTeacher = currentRole == 'teacher';
            final fullName = AuthSessionService.instance.userName;
            final userEmail = AuthSessionService.instance.userEmail;
            final roleColor =
                isAdmin ? p.gold : (isTeacher ? p.primary : p.info);
            final roleLabel =
                isAdmin ? 'Director' : (isTeacher ? 'Ustaz' : 'Parent');

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 48),
              children: [
                // User Profile Card
                ProCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      ProAvatar(
                        name: fullName,
                        radius: 26,
                        color: roleColor,
                        showGoldRing: isAdmin,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: TextStyle(
                                color: p.ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            if (userEmail.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                userEmail,
                                style: TextStyle(
                                  color: p.inkSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ProStatusPill(
                                  label: roleLabel,
                                  color: roleColor,
                                ),
                                if (isTeacher &&
                                    AuthSessionService
                                        .instance.assignedHalaqahName.isNotEmpty)
                                  ProStatusPill(
                                    label: AuthSessionService
                                        .instance.assignedHalaqahName,
                                    icon: Icons.auto_stories_rounded,
                                    color: p.primary,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Visual Theme Appearance Picker
                Text(
                  'APPEARANCE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: p.inkMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ThemeOptionCard(
                        title: 'Warm Sanctuary',
                        subtitle: 'Daylight Ivory',
                        previewCanvas: AppColors.canvasLight,
                        previewSurface: AppColors.surfaceCardLight,
                        previewBarColor: const Color(0xFFE6E1D6),
                        previewAccent: AppColors.pinePrimary,
                        isSelected: !isDark,
                        p: p,
                        onTap: () => AppTheme.setThemeMode(ThemeMode.light),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ThemeOptionCard(
                        title: 'Emerald Night',
                        subtitle: 'Midnight Pine',
                        previewCanvas: AppColors.background,
                        previewSurface: const Color(0xFF132D2B),
                        previewBarColor: const Color(0xFF1F3E3B),
                        previewAccent: AppColors.pineJade,
                        isSelected: isDark,
                        p: p,
                        onTap: () => AppTheme.setThemeMode(ThemeMode.dark),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _handleSignOut,
                    icon: Icon(Icons.logout_rounded, size: 17, color: p.danger),
                    label: Text(
                      'Sign Out of Account',
                      style: TextStyle(
                        color: p.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: p.danger.withOpacity(0.55)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color previewCanvas;
  final Color previewSurface;
  final Color previewBarColor;
  final Color previewAccent;
  final bool isSelected;
  final AppPalette p;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    required this.title,
    required this.subtitle,
    required this.previewCanvas,
    required this.previewSurface,
    required this.previewBarColor,
    required this.previewAccent,
    required this.isSelected,
    required this.p,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? p.primary : p.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 54,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: previewCanvas,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: p.isDark
                      ? Colors.white.withOpacity(0.10)
                      : p.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: previewAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: previewBarColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: previewSurface,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: previewBarColor.withOpacity(0.6)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 10.5, color: p.inkMuted),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: isSelected ? p.primary : p.inkMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
