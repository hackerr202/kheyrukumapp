import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/invite_code_dialog.dart';
import '../../announcements/announcements_sheet.dart';
import '../../announcements/post_announcement_dialog.dart';
import '../../settings/settings_sheet.dart';

/// The "More" Tab: Hub for administrative menus, separated Teacher/Parent
/// invite generators, center announcements, halaqah fees, and future services.
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  void _showFeesDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.payments_rounded, color: Color(0xFF8B5CF6), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Halaqah Fees & Tuition',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: subtextColor),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Tuition & Contribution Tracking',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                'Monitor monthly halaqah contributions, parent payments, and educational sponsorships.',
                style: TextStyle(fontSize: 11.5, color: subtextColor, height: 1.4),
              ),
              const SizedBox(height: 16),
              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Monthly Rate', style: TextStyle(fontSize: 10.5, color: subtextColor)),
                          const SizedBox(height: 4),
                          const Text(
                            '\$50 / month',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Collection Status', style: TextStyle(fontSize: 10.5, color: subtextColor)),
                          const SizedBox(height: 4),
                          const Text(
                            'Active & Synced',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.accentTeal),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fee payment processing module will be configured for your center.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long_rounded, size: 16, color: Colors.white),
                  label: const Text('Record Student Fee Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHalaqahsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accentEmerald.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.menu_book_rounded, color: AppColors.accentEmerald, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Memorization Circles',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: subtextColor),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Active Study Circles (حلقات التحفيظ)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                'Students and teachers connected via realtime invite codes are grouped into circles for daily Sabaq (new memorization), Sabqi (recent revision), and Manzil (cumulative retention).',
                style: TextStyle(fontSize: 11.5, color: subtextColor, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: AppColors.accentEmerald, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Database synced. Ready for automated recitation attendance logging.',
                        style: TextStyle(fontSize: 11.5, color: textColor, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentEmerald,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.surfaceCard : AppColors.surfaceCardLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        // Header Section
        Text(
          'More Menus & Services',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 4),
        Text(
          'Administrative controls, invitation hubs, and center resources.',
          style: TextStyle(fontSize: 12, color: subtextColor),
        ),
        const SizedBox(height: 20),

        // 1. TEACHERS INVITE (ALONE)
        _buildMenuCard(
          context: context,
          icon: Icons.school_rounded,
          iconBg: AppColors.accentTeal.withOpacity(0.15),
          iconColor: AppColors.accentTeal,
          title: 'Teachers Invite',
          subtitle: 'Generate & share real-time codes for ustazs to manage halaqahs',
          badgeText: 'TEACHER CODE',
          badgeColor: AppColors.accentTeal,
          onTap: () => InviteCodeDialog.show(context, initialRole: 'teacher'),
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          textColor: textColor,
          subtextColor: subtextColor,
        ),
        const SizedBox(height: 12),

        // 2. PARENTS INVITE (ALONE)
        _buildMenuCard(
          context: context,
          icon: Icons.family_restroom_rounded,
          iconBg: AppColors.accentAmber.withOpacity(0.15),
          iconColor: AppColors.accentAmber,
          title: 'Parents Invite',
          subtitle: 'Generate & share real-time codes for parents to link student recitation',
          badgeText: 'PARENT CODE',
          badgeColor: AppColors.accentAmber,
          onTap: () => InviteCodeDialog.show(context, initialRole: 'parent'),
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          textColor: textColor,
          subtextColor: subtextColor,
        ),
        const SizedBox(height: 12),

        // 3. ANNOUNCEMENTS
        _buildMenuCard(
          context: context,
          icon: Icons.campaign_rounded,
          iconBg: const Color(0xFFFF4B72).withOpacity(0.15),
          iconColor: const Color(0xFFFF4B72),
          title: 'Center Announcements',
          subtitle: 'Broadcast circulars to teachers & parents, or review all notices',
          badgeText: 'REALTIME FEED',
          badgeColor: const Color(0xFFFF4B72),
          onTap: () => AnnouncementsSheet.show(context),
          extraActionText: '+ Post',
          onExtraAction: () {
            showDialog(
              context: context,
              builder: (_) => const PostAnnouncementDialog(),
            );
          },
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          textColor: textColor,
          subtextColor: subtextColor,
        ),
        const SizedBox(height: 12),

        // 4. FEES & TUITION
        _buildMenuCard(
          context: context,
          icon: Icons.payments_rounded,
          iconBg: const Color(0xFF8B5CF6).withOpacity(0.15),
          iconColor: const Color(0xFF8B5CF6),
          title: 'Halaqah Fees & Tuition',
          subtitle: 'Student monthly contributions, payment status, and sponsorship receipts',
          badgeText: 'FINANCIAL',
          badgeColor: const Color(0xFF8B5CF6),
          onTap: () => _showFeesDialog(context),
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          textColor: textColor,
          subtextColor: subtextColor,
        ),
        const SizedBox(height: 12),

        // 5. HALAQAHS & CIRCLES
        _buildMenuCard(
          context: context,
          icon: Icons.menu_book_rounded,
          iconBg: AppColors.accentEmerald.withOpacity(0.15),
          iconColor: AppColors.accentEmerald,
          title: 'Memorization Circles (Halaqahs)',
          subtitle: 'Manage recitation groups, student circles & curriculum milestones',
          badgeText: 'CIRCLES',
          badgeColor: AppColors.accentEmerald,
          onTap: () => _showHalaqahsDialog(context),
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          textColor: textColor,
          subtextColor: subtextColor,
        ),
        const SizedBox(height: 12),

        // 6. PORTAL SETTINGS SHORTCUT
        _buildMenuCard(
          context: context,
          icon: Icons.settings_rounded,
          iconBg: const Color(0xFF00BCD4).withOpacity(0.15),
          iconColor: const Color(0xFF00BCD4),
          title: 'Portal Settings',
          subtitle: 'Light/Dark theme toggle, profile settings, and notification alerts',
          badgeText: 'SETTINGS',
          badgeColor: const Color(0xFF00BCD4),
          onTap: () => SettingsSheet.show(context),
          isDark: isDark,
          cardBg: cardBg,
          borderColor: borderColor,
          textColor: textColor,
          subtextColor: subtextColor,
        ),
      ],
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
    String? extraActionText,
    VoidCallback? onExtraAction,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Box
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 11.5, color: subtextColor, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Optional Extra Action button or Chevron
                if (extraActionText != null && onExtraAction != null)
                  InkWell(
                    onTap: onExtraAction,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        extraActionText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: subtextColor.withOpacity(0.7),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
