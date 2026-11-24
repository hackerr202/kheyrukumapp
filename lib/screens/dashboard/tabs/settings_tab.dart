import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_notifier.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/absence_service.dart';
import '../../../core/services/announcement_service.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/halaqah_service.dart';
import '../../../core/services/homework_service.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/services/notification_center_service.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/student_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/pro_ui_kit.dart';

/// Executive Account & Portal Settings screen / sheet body:
/// 1. Account Profile Hero Card (avatar photo picker [Gallery/Camera/Remove],
///    live name/phone/email/role pill, Edit Profile CTA)
/// 2. Account & Security (Edit Name & Phone, Change Password)
/// 3. Language Switcher (English / العربية RTL / አማርኛ)
/// 4. 3-Mode Theme Switcher (Warm Sanctuary Light / Emerald Night Dark / System Auto)
/// 5. Notifications Status & About
/// 6. Confirmed Safe Sign Out
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _isUploadingAvatar = false;
  bool? _notificationsEnabled;
  bool _isCheckingNotifications = false;

  @override
  void initState() {
    super.initState();
    _refreshNotificationStatus();
  }

  Future<void> _refreshNotificationStatus() async {
    final enabled =
        await PushNotificationService.instance.areNotificationsEnabled();
    if (!mounted) return;
    setState(() => _notificationsEnabled = enabled);
  }

  Future<void> _enableOrSyncNotifications() async {
    if (_isCheckingNotifications) return;
    setState(() => _isCheckingNotifications = true);
    final enabled =
        await PushNotificationService.instance.promptAndSyncNotifications();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
      _isCheckingNotifications = false;
    });
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (!mounted || picked == null) return;

      setState(() => _isUploadingAvatar = true);
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      final userId = AuthSessionService.instance.userId;

      final url = await StorageService.uploadAvatar(
        userIdOrName: userId.isNotEmpty ? userId : 'my_profile',
        bytes: bytes,
        extension: ext.isNotEmpty ? ext : 'jpg',
      );
      if (url == null) {
        throw Exception('Storage upload failed.');
      }

      await AuthSessionService.instance.updateAvatarUrl(url);

      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.profilePhotoUpdated),
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
              '${loc.updatePhoto}: ${SupabaseService.cleanErrorMessage(e)}',
            ),
            backgroundColor: p.danger,
          ),
        );
      }
    }
  }

  Future<void> _removeAvatar() async {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    setState(() => _isUploadingAvatar = true);
    try {
      await AuthSessionService.instance.updateAvatarUrl(null);
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.profilePhotoRemoved),
            backgroundColor: p.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SupabaseService.cleanErrorMessage(e)),
            backgroundColor: p.danger,
          ),
        );
      }
    }
  }

  Future<void> _showAvatarOptions() async {
    if (_isUploadingAvatar) return;
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final hasAvatar = AuthSessionService.instance.avatarUrl != null &&
        AuthSessionService.instance.avatarUrl!.trim().isNotEmpty;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: p.border),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                loc.updatePhoto,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: p.primary),
                title: Text(loc.chooseFromGallery),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: p.gold),
                title: Text(loc.takePhoto),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              if (hasAvatar)
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: p.danger),
                  title: Text(
                    loc.removePhoto,
                    style: TextStyle(color: p.danger),
                  ),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == 'gallery') {
      await _pickAndUploadAvatar(ImageSource.gallery);
    } else if (action == 'camera') {
      await _pickAndUploadAvatar(ImageSource.camera);
    } else if (action == 'remove') {
      await _removeAvatar();
    }
  }

  Future<void> _showEditProfileDialog() async {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _EditProfileDialog(palette: p, loc: loc),
    );
    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.profileUpdated),
          backgroundColor: p.success,
        ),
      );
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangePasswordDialog(palette: p, loc: loc),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.passwordUpdated),
          backgroundColor: p.success,
        ),
      );
    }
  }

  Future<void> _confirmAndSignOut() async {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.signOut),
        content: Text(loc.signOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: p.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.signOut),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _handleSignOut();
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await PushNotificationService.instance.unregisterOnLogout();
    } catch (_) {}

    try {
      AuthSessionService.instance.clearSession();
      await Future.wait([
        PaymentService.instance.clearOnLogout(),
        AnnouncementService.instance.clearOnLogout(),
        NotificationCenterService.instance.clearOnLogout(),
        StudentService.instance.clearOnLogout(),
        HalaqahService.instance.clearOnLogout(),
        HomeworkService.instance.clearOnLogout(),
        AbsenceService.instance.clearOnLogout(),
        MessagingService.instance.clearOnLogout(),
      ]);
    } catch (_) {} finally {
      try {
        await SupabaseService.instance.signOut();
      } catch (_) {}
      if (mounted) {
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil(AppRoutes.auth, (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        final p = AppColors.of(context);

        return ValueListenableBuilder<String>(
          valueListenable: AuthSessionService.instance.roleNotifier,
          builder: (context, currentRole, _) {
            final isSuperAdmin = currentRole == 'superadmin';
            final isAdmin = currentRole == 'admin' || isSuperAdmin;
            final isTeacher = currentRole == 'teacher';
            final fullName = AuthSessionService.instance.userName;
            final userEmail = AuthSessionService.instance.userEmail;
            final userPhone = AuthSessionService.instance.userPhone;
            final avatarUrl = AuthSessionService.instance.avatarUrl;
            final roleColor = isSuperAdmin
                ? p.gold
                : (isAdmin ? p.gold : (isTeacher ? p.primary : p.info));

            return ValueListenableBuilder<Locale>(
              valueListenable: LocaleNotifier.instance,
              builder: (context, appLocale, _) {
                final loc = AppLocalizations.of(context);
                final currentLang = appLocale.languageCode;
                final roleLabel = isSuperAdmin
                    ? loc.roleSuperadmin
                    : (isAdmin
                        ? loc.roleAdmin
                        : (isTeacher ? loc.roleTeacher : loc.roleParent));

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Account Profile Hero Card
                      ProCard(
                        padding: const EdgeInsets.all(16),
                        borderRadius: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                InkWell(
                                  onTap: _showAvatarOptions,
                                  borderRadius: BorderRadius.circular(36),
                                  child: Stack(
                                    children: [
                                      ProAvatar(
                                        name: fullName,
                                        imageUrl: avatarUrl,
                                        radius: 30,
                                        color: roleColor,
                                        showGoldRing: isAdmin,
                                      ),
                                      PositionedDirectional(
                                        bottom: 0,
                                        end: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: p.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: p.surface,
                                              width: 1.8,
                                            ),
                                          ),
                                          child: _isUploadingAvatar
                                              ? const SizedBox(
                                                  width: 11,
                                                  height: 11,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 1.5,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.camera_alt_rounded,
                                                  size: 12,
                                                  color: Colors.white,
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: p.ink,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16.5,
                                        ),
                                      ),
                                      if (userEmail.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          userEmail,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: p.inkSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      if (userPhone.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          userPhone,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: p.inkMuted,
                                            fontSize: 11.5,
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
                                                  .assignedHalaqahId.isNotEmpty)
                                            ProStatusPill(
                                              label: AuthSessionService.instance
                                                  .assignedHalaqahName,
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
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _showEditProfileDialog,
                                icon: Icon(
                                  Icons.edit_rounded,
                                  size: 16,
                                  color: p.primary,
                                ),
                                label: Text(
                                  loc.editProfile,
                                  style: TextStyle(
                                    color: p.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: p.primary.withOpacity(0.4)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // 2. Account & Security
                      Text(
                        loc.accountAndSecurity,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: p.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ProCard(
                        padding: EdgeInsets.zero,
                        borderRadius: 18,
                        child: Column(
                          children: [
                            _SettingsRowTile(
                              icon: Icons.badge_outlined,
                              iconColor: p.primary,
                              title: loc.editNameAndPhone,
                              subtitle: userPhone.isNotEmpty
                                  ? '$fullName • $userPhone'
                                  : fullName,
                              p: p,
                              onTap: _showEditProfileDialog,
                            ),
                            Divider(
                              height: 1,
                              indent: 58,
                              color: p.border.withOpacity(0.65),
                            ),
                            _SettingsRowTile(
                              icon: Icons.camera_enhance_outlined,
                              iconColor: p.gold,
                              title: loc.updatePhoto,
                              subtitle: loc.chooseFromGallery,
                              p: p,
                              onTap: _showAvatarOptions,
                            ),
                            Divider(
                              height: 1,
                              indent: 58,
                              color: p.border.withOpacity(0.65),
                            ),
                            _SettingsRowTile(
                              icon: Icons.lock_reset_rounded,
                              iconColor: p.info,
                              title: loc.changePassword,
                              subtitle: '••••••••',
                              p: p,
                              onTap: _showChangePasswordDialog,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // 3. Language Section
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
                              label: 'English',
                              nativeLabel: 'English',
                              isSelected: currentLang == 'en',
                              p: p,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                LocaleNotifier.instance.setLocale('en');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _LanguageOptionCard(
                              label: 'Arabic',
                              nativeLabel: 'العربية',
                              isSelected: currentLang == 'ar',
                              p: p,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                LocaleNotifier.instance.setLocale('ar');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _LanguageOptionCard(
                              label: 'Amharic',
                              nativeLabel: 'አማርኛ',
                              isSelected: currentLang == 'am',
                              p: p,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                LocaleNotifier.instance.setLocale('am');
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // 4. 3-Mode Appearance Section
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
                              isSystemSplit: false,
                              isSelected: themeMode == ThemeMode.light,
                              p: p,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                AppTheme.setThemeMode(ThemeMode.light);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ThemeOptionCard(
                              title: loc.emeraldNight,
                              subtitle: loc.midnightPine,
                              previewCanvas: AppColors.background,
                              previewSurface: const Color(0xFF132D2B),
                              previewBarColor: const Color(0xFF1F3E3B),
                              previewAccent: AppColors.pineJade,
                              isSystemSplit: false,
                              isSelected: themeMode == ThemeMode.dark,
                              p: p,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                AppTheme.setThemeMode(ThemeMode.dark);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ThemeOptionCard(
                              title: loc.systemTheme,
                              subtitle: loc.systemAuto,
                              previewCanvas: AppColors.canvasLight,
                              previewSurface: const Color(0xFF132D2B),
                              previewBarColor: const Color(0xFF7D908C),
                              previewAccent: AppColors.goldPrimary,
                              isSystemSplit: true,
                              isSelected: themeMode == ThemeMode.system,
                              p: p,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                AppTheme.setThemeMode(ThemeMode.system);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // 5. Notifications & About
                      Text(
                        loc.notifications,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: p.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ProCard(
                        padding: EdgeInsets.zero,
                        borderRadius: 18,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: (_notificationsEnabled == true
                                              ? p.success
                                              : p.gold)
                                          .withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: Icon(
                                      _notificationsEnabled == true
                                          ? Icons.notifications_active_rounded
                                          : Icons.notifications_off_outlined,
                                      size: 18,
                                      color: _notificationsEnabled == true
                                          ? p.success
                                          : p.gold,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _notificationsEnabled == true
                                              ? loc.notificationsEnabled
                                              : loc.notificationsDisabled,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: p.ink,
                                          ),
                                        ),
                                        Text(
                                          loc.monthlyFeeReminder,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: p.inkSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_notificationsEnabled != true)
                                    TextButton(
                                      onPressed: _isCheckingNotifications
                                          ? null
                                          : _enableOrSyncNotifications,
                                      child: Text(
                                        _isCheckingNotifications
                                            ? loc.loading
                                            : loc.enableNotifications,
                                        style: TextStyle(
                                          color: p.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  else
                                    IconButton(
                                      onPressed: _isCheckingNotifications
                                          ? null
                                          : _enableOrSyncNotifications,
                                      icon: Icon(
                                        Icons.sync_rounded,
                                        size: 18,
                                        color: p.inkMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Divider(
                              height: 1,
                              indent: 58,
                              color: p.border.withOpacity(0.65),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: p.primary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: Icon(
                                      Icons.verified_user_outlined,
                                      size: 18,
                                      color: p.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          loc.aboutApp,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: p.ink,
                                          ),
                                        ),
                                        Text(
                                          loc.appVersion,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: p.inkSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 6. Confirmed Sign Out
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _confirmAndSignOut,
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
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SettingsRowTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final AppPalette p;
  final VoidCallback onTap;

  const _SettingsRowTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.p,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.13),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: p.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: p.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final AppPalette palette;
  final AppLocalizations loc;

  const _EditProfileDialog({required this.palette, required this.loc});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: AuthSessionService.instance.userName);
    _phoneCtrl =
        TextEditingController(text: AuthSessionService.instance.userPhone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final loc = widget.loc;
    final canSave = !_isSaving && _nameCtrl.text.trim().isNotEmpty;

    return AlertDialog(
      title: Text(loc.editNameAndPhone),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              enabled: !_isSaving,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: loc.fullName,
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 19),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              enabled: !_isSaving,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: loc.phoneOptional,
                prefixIcon: const Icon(Icons.phone_outlined, size: 19),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        ElevatedButton(
          onPressed: canSave
              ? () async {
                  setState(() => _isSaving = true);
                  try {
                    await AuthSessionService.instance.updateProfile(
                      fullName: _nameCtrl.text.trim(),
                      phone: _phoneCtrl.text.trim(),
                    );
                    if (!mounted) return;
                    Navigator.pop(context, true);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(SupabaseService.cleanErrorMessage(e)),
                        backgroundColor: p.danger,
                      ),
                    );
                  }
                }
              : null,
          child: Text(_isSaving ? loc.loading : loc.save),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  final AppPalette palette;
  final AppLocalizations loc;

  const _ChangePasswordDialog({required this.palette, required this.loc});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isSaving = false;
  String? _validationError;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final loc = widget.loc;
    final p = widget.palette;
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (pass.length < 6) {
      setState(() => _validationError = loc.passwordTooShort);
      return;
    }
    if (pass != confirm) {
      setState(() => _validationError = loc.passwordsDoNotMatch);
      return;
    }

    setState(() {
      _validationError = null;
      _isSaving = true;
    });

    try {
      await AuthSessionService.instance.changePassword(pass);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _validationError = SupabaseService.cleanErrorMessage(e);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_validationError!),
          backgroundColor: p.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final loc = widget.loc;

    return AlertDialog(
      title: Text(loc.changePassword),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _passCtrl,
              enabled: !_isSaving,
              obscureText: _obscure1,
              decoration: InputDecoration(
                labelText: loc.newPassword,
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure1
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure1 = !_obscure1),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              enabled: !_isSaving,
              obscureText: _obscure2,
              decoration: InputDecoration(
                labelText: loc.confirmPassword,
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure2
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure2 = !_obscure2),
                ),
              ),
            ),
            if (_validationError != null) ...[
              const SizedBox(height: 10),
              Text(
                _validationError!,
                style: TextStyle(
                  color: p.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: Text(_isSaving ? loc.loading : loc.save),
        ),
      ],
    );
  }
}

class _LanguageOptionCard extends StatelessWidget {
  final String label;
  final String nativeLabel;
  final bool isSelected;
  final AppPalette p;
  final VoidCallback onTap;

  const _LanguageOptionCard({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? p.primary : p.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
  final bool isSystemSplit;
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
    required this.isSystemSplit,
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? p.primary : p.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: p.primary.withOpacity(0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: previewCanvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: p.isDark
                      ? Colors.white.withOpacity(0.10)
                      : p.border,
                ),
              ),
              child: isSystemSplit
                  ? Row(
                      children: [
                        Expanded(
                          child: Container(
                            color: AppColors.canvasLight,
                            padding: const EdgeInsets.all(6),
                            child: Align(
                              alignment: AlignmentDirectional.topStart,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.pinePrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            color: AppColors.background,
                            padding: const EdgeInsets.all(6),
                            child: Align(
                              alignment: AlignmentDirectional.bottomEnd,
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF132D2B),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: previewAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Container(
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: previewBarColor,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: previewSurface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: previewBarColor.withOpacity(0.6)),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9.5, color: p.inkMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
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
