import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/invite_code_dialog.dart';

/// Settings & Profile Tab connected to authenticated Supabase user profile.
/// Includes:
/// 1. Functional Light/Dark theme toggle
/// 2. Admin Realtime Invite Code generator for Teachers and Parents
/// 3. Notification & reminder preferences
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _dailyReminder = true;
  bool _teacherAlerts = true;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final profile = await SupabaseService.instance.getUserProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    await SupabaseService.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.surfaceCard : AppColors.surfaceCardLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    final user = SupabaseService.instance.currentUser;
    final fullName = _userProfile?['full_name'] ?? 'Ustaz Muhammed Yakut';
    final userRole = (_userProfile?['role'] ?? 'admin').toString().toUpperCase();
    final userEmail = user?.email ?? 'admin@kheyrukum.com';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        Text(
          'Portal Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 16),

        // User Account Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.accentAmber,
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLoading ? 'Loading...' : fullName,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userEmail,
                      style: TextStyle(color: subtextColor, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        userRole,
                        style: const TextStyle(
                          color: AppColors.accentTeal,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // =====================================================================
        // REQUIREMENT 2: FUNCTIONAL LIGHT THEME TOGGLE IN SETTINGS
        // =====================================================================
        Text(
          'Appearance & Display',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: subtextColor),
        ),
        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: AppTheme.themeModeNotifier,
            builder: (context, currentMode, _) {
              final isLight = currentMode == ThemeMode.light;

              return SwitchListTile(
                value: isLight,
                onChanged: (val) {
                  AppTheme.setThemeMode(val ? ThemeMode.light : ThemeMode.dark);
                },
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isLight ? const Color(0xFFD97706) : AppColors.accentAmber).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isLight ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: isLight ? const Color(0xFFD97706) : AppColors.accentAmber,
                    size: 22,
                  ),
                ),
                title: Text(
                  'Light Theme Mode',
                  style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  isLight
                      ? 'Bright daylight mode active'
                      : 'Midnight dark aesthetic active',
                  style: TextStyle(color: subtextColor, fontSize: 12),
                ),
                activeColor: const Color(0xFFD97706),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        // =====================================================================
        // REQUIREMENT 3: ADMIN INVITATION CODES MANAGER IN SETTINGS
        // =====================================================================
        Text(
          'Administration & Access Control',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: subtextColor),
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.vpn_key_rounded, color: AppColors.accentTeal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite Codes Generator',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        Text(
                          'Generate realtime signup codes for Teachers and Parents',
                          style: TextStyle(fontSize: 11.5, color: subtextColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => InviteCodeDialog.show(context),
                  icon: const Icon(Icons.add_rounded, size: 16, color: Colors.black),
                  label: const Text(
                    'Manage & Generate Invite Codes',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Notification Preferences
        Text(
          'Notifications & Reminders',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: subtextColor),
        ),
        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              SwitchListTile(
                value: _dailyReminder,
                onChanged: (val) => setState(() => _dailyReminder = val),
                title: Text('Daily Quran Revision Reminder', style: TextStyle(color: textColor, fontSize: 14)),
                subtitle: Text('7:00 AM & 5:00 PM', style: TextStyle(color: subtextColor, fontSize: 12)),
                activeColor: AppColors.accentAmber,
              ),
              Divider(height: 1, color: borderColor),
              SwitchListTile(
                value: _teacherAlerts,
                onChanged: (val) => setState(() => _teacherAlerts = val),
                title: Text('Instant Halaqah Push Alerts', style: TextStyle(color: textColor, fontSize: 14)),
                subtitle: Text('Notifications when notices and homework are posted', style: TextStyle(color: subtextColor, fontSize: 12)),
                activeColor: AppColors.accentTeal,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Sign Out Button
        OutlinedButton.icon(
          onPressed: _handleSignOut,
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF4B72), size: 18),
          label: const Text(
            'Sign Out of Portal',
            style: TextStyle(color: Color(0xFFFF4B72), fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFF4B72), width: 1.2),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}
