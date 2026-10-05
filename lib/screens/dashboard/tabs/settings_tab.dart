import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _dailyReminder = true;
  bool _teacherAlerts = true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        const Text(
          'Portal Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),

        // Active Child Account Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.accentAmber,
                child: Text('Z', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Zayd Ahmed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    SizedBox(height: 2),
                    Text('Halaqah Level 2 • Sheikh Abdullah', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.accentTeal),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                child: const Text('Switch Child', style: TextStyle(color: AppColors.accentTeal, fontSize: 11)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Notification Preferences
        const Text('Notifications & Reminders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
                title: const Text('Instant Teacher Voice Feedback', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Get notified when homework is reviewed', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                activeColor: AppColors.accentTeal,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Portal Security
        const Text('Security & Communication', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.verified_user_outlined, color: AppColors.accentTeal),
                title: const Text('Parent Verified Passkey', style: TextStyle(color: Colors.white, fontSize: 14)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                onTap: () {},
              ),
              const Divider(height: 1, color: AppColors.borderSubtle),
              ListTile(
                leading: const Icon(Icons.language, color: AppColors.accentAmber),
                title: const Text('App Language', style: TextStyle(color: Colors.white, fontSize: 14)),
                trailing: const Text('English / العربية', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}
