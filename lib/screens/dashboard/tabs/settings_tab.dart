import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';

/// Settings & Profile Tab connected to authenticated Supabase user profile.
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
    final user = SupabaseService.instance.currentUser;
    final fullName = _userProfile?['full_name'] ?? 'Ustaz Muhammed Yakut';
    final userRole = (_userProfile?['role'] ?? 'admin').toString().toUpperCase();
    final userEmail = user?.email ?? 'admin@kheyrukum.com';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        const Text(
          'Portal Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),

        // User Account Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderSubtle),
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
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userEmail,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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

        // Notification Preferences
        const Text(
          'Notifications & Reminders',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              SwitchListTile(
                value: _dailyReminder,
                onChanged: (val) => setState(() => _dailyReminder = val),
                title: const Text('Daily Quran Revision Reminder', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('7:00 AM & 5:00 PM', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                activeColor: AppColors.accentAmber,
              ),
              const Divider(height: 1, color: AppColors.borderSubtle),
              SwitchListTile(
                value: _teacherAlerts,
                onChanged: (val) => setState(() => _teacherAlerts = val),
                title: const Text('Instant Halaqah Push Alerts', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Notifications when notices and homework are posted', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
