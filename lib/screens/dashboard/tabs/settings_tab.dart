import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_notifier.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/absence_service.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/halaqah_service.dart';
import '../../../core/services/homework_service.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/storage_service.dart';
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
  bool _isUploadingAvatar = false;

  Future<void> _pickAndUploadAvatar() async {
    final p = AppColors.of(context);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingAvatar = true);
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last;
      final userId = AuthSessionService.instance.userId;

      final url = await StorageService.uploadAvatar(
        userIdOrName: userId.isNotEmpty ? userId : 'my_profile',
        bytes: bytes,
        extension: ext.isNotEmpty ? ext : 'jpg',
      );

      if (url == null) {
        throw Exception('Storage upload failed.');
      }

      final client = SupabaseService.instance.client;
      if (client != null && userId.isNotEmpty) {
        await client
            .from('profiles')
            .update({
              'avatar_url': url,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', userId);
      }

      AuthSessionService.instance.updateDetails(avatarUrl: url);

      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile photo updated successfully.'),
            backgroundColor: p.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not update photo: ${SupabaseService.cleanErrorMessage(e)}'),
            backgroundColor: p.danger,
          ),
        );
      }
    }
  }

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
            final isSuperAdmin = currentRole == 'superadmin';
            final isAdmin = currentRole == 'admin' || isSuperAdmin;
            final isTeacher = currentRole == 'teacher';
            final fullName = AuthSessionService.instance.userName;
            final userEmail = AuthSessionService.instance.userEmail;
            final avatarUrl = AuthSessionService.instance.avatarUrl;
            final roleColor = isSuperAdmin
                ? p.gold
                : (isAdmin ? p.gold : (isTeacher ? p.primary : p.info));
            final roleLabel = isSuperAdmin
                ? 'Superadmin'
                : (isAdmin ? 'Director' : (isTeacher ? 'Ustaz' : 'Parent'));

            return ValueListenableBuilder<Locale>(
              valueListenable: LocaleNotifier.instance,
              builder: (context, appLocale, _) {
                final loc = AppLocalizations.of(context);
                final currentLang = appLocale.languageCode;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 48),
                  children: [
                    // User Profile Card
                    ProCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              ProAvatar(
                                name: fullName,
                                imageUrl: avatarUrl,
                                radius: 26,
                                color: roleColor,
                                showGoldRing: isAdmin,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: _isUploadingAvatar
                                      ? null
                                      : _pickAndUploadAvatar,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: p.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: p.surface, width: 1.5),
                                    ),
                                    child: _isUploadingAvatar
                                        ? const SizedBox(
                                            width: 10,
                                            height: 10,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 11,
                                            color: Colors.white,
                                          ),
                                  ),
                                ),
                              ),
                            ],
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
                                        AuthSessionService.instance
                                            .assignedHalaqahName.isNotEmpty)
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

                    // Language Selection Section (English, Arabic RTL, Amharic)
                    Text(
                      loc.language,
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
                          child: _LanguageOptionCard(
                            code: 'en',
                            label: 'English',
                            nativeLabel: 'English',
                            isSelected: currentLang == 'en',
                            p: p,
                            onTap: () =>
                                LocaleNotifier.instance.setLocale('en'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _LanguageOptionCard(
                            code: 'ar',
                            label: 'Arabic',
                            nativeLabel: 'العربية (RTL)',
                            isSelected: currentLang == 'ar',
                            p: p,
                            onTap: () =>
                                LocaleNotifier.instance.setLocale('ar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _LanguageOptionCard(
                            code: 'am',
                            label: 'Amharic',
                            nativeLabel: 'አማርኛ',
                            isSelected: currentLang == 'am',
                            p: p,
                            onTap: () =>
                                LocaleNotifier.instance.setLocale('am'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // Visual Theme Appearance Picker
                    Text(
                      loc.appearance,
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
                            title: loc.warmSanctuary,
                            subtitle: loc.daylightIvory,
                            previewCanvas: AppColors.canvasLight,
                            previewSurface: AppColors.surfaceCardLight,
                            previewBarColor: const Color(0xFFE6E1D6),
                            previewAccent: AppColors.pinePrimary,
                            isSelected: !isDark,
                            p: p,
                            onTap: () =>
                                AppTheme.setThemeMode(ThemeMode.light),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ThemeOptionCard(
                            title: loc.emeraldNight,
                            subtitle: loc.midnightPine,
                            previewCanvas: AppColors.background,
                            previewSurface: const Color(0xFF132D2B),
                            previewBarColor: const Color(0xFF1F3E3B),
                            previewAccent: AppColors.pineJade,
                            isSelected: isDark,
                            p: p,
                            onTap: () =>
                                AppTheme.setThemeMode(ThemeMode.dark),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _handleSignOut,
                        icon: Icon(Icons.logout_rounded,
                            size: 17, color: p.danger),
                        label: Text(
                          loc.signOut,
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
      },
    );
  }
}

class _LanguageOptionCard extends StatelessWidget {
  final String code;
  final String label;
  final String nativeLabel;
  final bool isSelected;
  final AppPalette p;
  final VoidCallback onTap;

  const _LanguageOptionCard({
    required this.code,
    required this.label,
    required this.nativeLabel,
    required this.isSelected,
    required this.p,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? p.primary.withOpacity(0.12) : p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? p.primary : p.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              nativeLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? p.primary : p.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? p.primary : p.inkSecondary,
              ),
            ),
          ],
        ),
      ),
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
