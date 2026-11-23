import 'package:flutter/material.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/student_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/pro_ui_kit.dart';
import '../../admin/halaqah_management_sheet.dart';
import '../../admin/invite_codes_bottom_sheet.dart';
import '../../admin/user_management_screen.dart';
import '../../announcements/announcements_sheet.dart';
import '../../announcements/post_announcement_dialog.dart';
import '../../payments/payments_screen.dart';
import '../../settings/settings_sheet.dart';

/// Flagship "More" Hub:
/// - Profile summary hero card
/// - Grouped service menus separated cleanly by role (Admin, Teacher, Parent)
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  void _showTeacherHalaqahDialog(BuildContext context) {
    final p = AppColors.of(context);
    final assignedHalaqah = AuthSessionService.instance.assignedHalaqahName;
    final classStudents = StudentService.instance.getStudentsForHalaqah(
      assignedHalaqah,
      halaqahId: AuthSessionService.instance.assignedHalaqahId,
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: p.border),
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
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: p.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.school_rounded,
                            color: p.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Assigned Circle',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 19, color: p.inkSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                assignedHalaqah,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ustaz: ${AuthSessionService.instance.userName} • ${classStudents.length} ${classStudents.length == 1 ? 'Student' : 'Students'} Enrolled',
                style: TextStyle(
                  fontSize: 12.5,
                  color: p.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Daily Curriculum: Sabaq (new memorization), Sabqi (recent revision), and Manzil (cumulative revision). Record daily attendance and keep parents updated.',
                style: TextStyle(
                  fontSize: 12,
                  color: p.inkSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.surfaceSubtle,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLASS ROSTER',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: p.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (classStudents.isEmpty)
                      Text(
                        'No students currently assigned.',
                        style: TextStyle(fontSize: 12, color: p.inkSecondary),
                      )
                    else
                      ...classStudents.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '• ${s.fullName}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: p.ink,
                                ),
                              ),
                              Text(
                                'Juz ${s.currentJuz}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: p.inkSecondary,
                                ),
                              ),
                            ],
                          ),
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
                  child: const Text('Close'),
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
    final p = AppColors.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: AuthSessionService.instance.roleNotifier,
      builder: (context, currentRole, _) {
        final isSuperAdmin = currentRole == 'superadmin';
        final isAdmin = currentRole == 'admin' || isSuperAdmin;
        final isTeacher = currentRole == 'teacher';
        final isParent = currentRole == 'parent';

        final userName = AuthSessionService.instance.userName;
        final userEmail = AuthSessionService.instance.userEmail;
        final avatarUrl = AuthSessionService.instance.avatarUrl;
        final roleLabel = isSuperAdmin
            ? 'Super Admin'
            : (isAdmin
                ? 'Director'
                : (isTeacher ? 'Ustaz' : 'Parent'));

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 124),
          children: [
            // Profile Summary Hero Card
            ProHeroCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  ProAvatar(
                    name: userName,
                    imageUrl: avatarUrl,
                    radius: 26,
                    color: AppColors.goldWarm,
                    showGoldRing: true,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (userEmail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            userEmail,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.76),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFFAD882).withOpacity(0.35),
                            ),
                          ),
                          child: Text(
                            roleLabel,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFAD882),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            if (isAdmin) ...[
              _buildGroupLabel(p, 'ADMINISTRATION'),
              const SizedBox(height: 8),
              ProCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildMenuTile(
                      p: p,
                      icon: Icons.manage_accounts_rounded,
                      iconColor: p.primary,
                      title: 'User Management',
                      subtitle:
                          'Manage teachers, parents, circle assignments & access',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UserManagementScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDivider(p),
                    _buildMenuTile(
                      p: p,
                      icon: Icons.menu_book_rounded,
                      iconColor: p.primary,
                      title: 'Study Circles (Halaqahs)',
                      subtitle: 'Create circles, assign Ustazs & view enrollment',
                      onTap: () => HalaqahManagementSheet.show(context),
                    ),
                    _buildDivider(p),
                    _buildMenuTile(
                      p: p,
                      icon: Icons.vpn_key_rounded,
                      iconColor: p.gold,
                      title: 'Registration & Invite Codes',
                      subtitle:
                          'Generate sign-up codes for teachers & parents',
                      onTap: () => InviteCodesBottomSheet.show(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],

            if (isTeacher) ...[
              _buildGroupLabel(p, 'MY CLASS'),
              const SizedBox(height: 8),
              ProCard(
                padding: EdgeInsets.zero,
                child: _buildMenuTile(
                  p: p,
                  icon: Icons.school_rounded,
                  iconColor: p.primary,
                  title: 'My Assigned Halaqah',
                  subtitle:
                      '${AuthSessionService.instance.assignedHalaqahName} • Roster & Curriculum',
                  onTap: () => _showTeacherHalaqahDialog(context),
                ),
              ),
              const SizedBox(height: 22),
            ],

            _buildGroupLabel(p, 'ACADEMY & COMMUNITY'),
            const SizedBox(height: 8),
            ProCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuTile(
                    p: p,
                    icon: Icons.campaign_rounded,
                    iconColor: p.gold,
                    title: 'Center Announcements',
                    subtitle: isAdmin
                        ? 'Broadcast notices to parents & teachers'
                        : 'Official circulars, reminders & schedule updates',
                    onTap: () => AnnouncementsSheet.show(context, initialTab: 1),
                    trailing: isAdmin
                        ? InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => const PostAnnouncementDialog(),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: p.goldSoft,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: p.gold.withOpacity(0.35)),
                              ),
                              child: Text(
                                '+ Post',
                                style: TextStyle(
                                  color: p.gold,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                  if (isSuperAdmin || isParent) ...[
                    _buildDivider(p),
                    _buildMenuTile(
                      p: p,
                      icon: Icons.payments_rounded,
                      iconColor: p.primary,
                      title: isParent
                          ? 'Tuition & Fee Receipts'
                          : 'Halaqah Fees & Tuition',
                      subtitle: isParent
                          ? 'Upload bank receipts & check monthly fee status'
                          : 'Issue monthly tuition, verify receipts & overdue alerts',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaymentsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 22),

            _buildGroupLabel(p, 'ACCOUNT & PREFERENCES'),
            const SizedBox(height: 8),
            ProCard(
              padding: EdgeInsets.zero,
              child: _buildMenuTile(
                p: p,
                icon: Icons.settings_rounded,
                iconColor: p.primary,
                title: 'Portal Settings',
                subtitle: 'Theme appearance, account details & sign out',
                onTap: () => SettingsSheet.show(context),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroupLabel(AppPalette p, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: p.inkMuted,
        ),
      ),
    );
  }

  Widget _buildDivider(AppPalette p) {
    return Divider(height: 1, indent: 68, color: p.border.withOpacity(0.75));
  }

  Widget _buildMenuTile({
    required AppPalette p,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: p.inkSecondary,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(Icons.chevron_right_rounded, size: 20, color: p.inkMuted),
          ],
        ),
      ),
    );
  }
}
