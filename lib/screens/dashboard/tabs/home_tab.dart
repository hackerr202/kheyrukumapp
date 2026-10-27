import 'package:flutter/material.dart';
import '../../../core/models/announcement.dart';
import '../../../core/models/student.dart';
import '../../../core/services/announcement_service.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/halaqah_service.dart';
import '../../../core/services/student_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/add_student_dialog.dart';
import '../../admin/halaqah_management_sheet.dart';
import '../../admin/invite_codes_bottom_sheet.dart';
import '../../announcements/announcements_sheet.dart';
import '../../announcements/post_announcement_dialog.dart';

/// Redesigned Home Tab: Calm, spacious, and easy to scan.
/// Features clean onboarding checklist for new centers, streamlined 1-announcement card,
/// collapsed Invite Codes row, and an uncluttered 4-icon quick action row.
class HomeTab extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const HomeTab({super.key, this.onNavigateToTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const Color _limeAccent = Color(0xFFC9F24A);
  static const Color _alertRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subtleBorder = isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0);

    return ValueListenableBuilder<String>(
      valueListenable: AuthSessionService.instance.roleNotifier,
      builder: (context, currentRole, _) {
        final isAdmin = currentRole == 'admin';
        final isTeacher = currentRole == 'teacher';

        // 16px side padding, 120px bottom padding to avoid overlapping floating bottom nav
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            if (isAdmin) ...[
              // Latest Announcement at the top
              _buildAnnouncementsSection(
                context: context,
                isDark: isDark,
                isAdmin: true,
                cardBg: cardBg,
                textColor: textColor,
                subtextColor: subtextColor,
                subtleBorder: subtleBorder,
              ),

              const SizedBox(height: 24),

              // Quick Actions Row (4 icons: Post notice, Invite codes, Add student, Create halaqah)
              _buildQuickActionsRow(
                context: context,
                isDark: isDark,
                cardBg: cardBg,
                textColor: textColor,
                subtleBorder: subtleBorder,
              ),

              const SizedBox(height: 24),

              // Invite Codes collapsed single row
              _buildInviteCodesCollapsedRow(
                context: context,
                isDark: isDark,
                cardBg: cardBg,
                textColor: textColor,
                subtextColor: subtextColor,
                subtleBorder: subtleBorder,
              ),
            ] else if (isTeacher) ...[
              // Teacher Experience
              _buildAnnouncementsSection(
                context: context,
                isDark: isDark,
                isAdmin: false,
                cardBg: cardBg,
                textColor: textColor,
                subtextColor: subtextColor,
                subtleBorder: subtleBorder,
              ),
              const SizedBox(height: 24),
              _buildTeacherOverviewCard(
                isDark: isDark,
                cardBg: cardBg,
                textColor: textColor,
                subtextColor: subtextColor,
                subtleBorder: subtleBorder,
              ),
            ] else ...[
              // Parent Experience
              _buildAnnouncementsSection(
                context: context,
                isDark: isDark,
                isAdmin: false,
                cardBg: cardBg,
                textColor: textColor,
                subtextColor: subtextColor,
                subtleBorder: subtleBorder,
              ),
              const SizedBox(height: 24),
              _buildParentOverviewCard(
                isDark: isDark,
                cardBg: cardBg,
                textColor: textColor,
                subtextColor: subtextColor,
                subtleBorder: subtleBorder,
              ),
            ],
          ],
        );
      },
    );
  }

  // ===========================================================================
  // ADMIN SETUP CHECKLIST CARD / COMPACT STATS ROW
  // ===========================================================================
  Widget _buildAdminCenterStatusCard({
    required BuildContext context,
    required bool isDark,
    required Color cardBg,
    required Color textColor,
    required Color subtextColor,
    required Color subtleBorder,
  }) {
    return AnimatedBuilder(
      animation: HalaqahService.instance.halaqahsNotifier,
      builder: (context, _) {
        return StreamBuilder<List<Student>>(
          stream: StudentService.instance.studentsStream,
          initialData: StudentService.instance.allStudents,
          builder: (context, studentSnapshot) {
            final halaqahs = HalaqahService.instance.halaqahs;
            final students = studentSnapshot.data ?? StudentService.instance.allStudents;

            final hasHalaqah = halaqahs.isNotEmpty;
            final hasStudent = students.isNotEmpty;

            return StreamBuilder(
              stream: SupabaseService.instance.streamInviteCodes(),
              builder: (context, snapshot) {
                final codes = snapshot.data ?? [];
                final hasTeacherCode = codes.any((c) => c.role == 'teacher');

                int completedSteps = 0;
                if (hasHalaqah) completedSteps++;
                if (hasTeacherCode) completedSteps++;
                if (hasStudent) completedSteps++;

            // If setup is complete (or students exist), show calm, compact stats row
            if (hasStudent && completedSteps >= 3) {
              final teachersCount = halaqahs.map((h) => h.teacherId).where((id) => id != null && id.isNotEmpty).toSet().length;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: subtleBorder, width: 1),
                ),
                child: Row(
                  children: [
                    _buildStatItem(
                      label: 'Students',
                      value: '${students.length}',
                      textColor: textColor,
                      subtextColor: subtextColor,
                      onTap: () => widget.onNavigateToTab?.call(1),
                    ),
                    _buildStatDivider(subtleBorder),
                    _buildStatItem(
                      label: 'Halaqahs',
                      value: '${halaqahs.length}',
                      textColor: textColor,
                      subtextColor: subtextColor,
                      onTap: () => HalaqahManagementSheet.show(context),
                    ),
                    _buildStatDivider(subtleBorder),
                    _buildStatItem(
                      label: 'Teachers',
                      value: '$teachersCount',
                      textColor: textColor,
                      subtextColor: subtextColor,
                      onTap: () => InviteCodesBottomSheet.show(context),
                    ),
                  ],
                ),
              );
            }

            // Onboarding Setup Checklist Card (0 of 3, 1 of 3, 2 of 3)
            String nextStepTitle;
            String nextStepActionText;
            VoidCallback nextStepAction;

            if (!hasHalaqah) {
              nextStepTitle = 'Create a halaqah';
              nextStepActionText = 'Create halaqah';
              nextStepAction = () => HalaqahManagementSheet.show(context);
            } else if (!hasTeacherCode) {
              nextStepTitle = 'Generate a teacher invite code';
              nextStepActionText = 'Generate code';
              nextStepAction = () => InviteCodesBottomSheet.show(context);
            } else {
              nextStepTitle = 'Enroll the first student';
              nextStepActionText = 'Enroll student';
              nextStepAction = () => AddStudentDialog.show(context);
            }

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: subtleBorder, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Center setup',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _limeAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$completedSteps of 3',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _limeAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: completedSteps / 3,
                      minHeight: 5,
                      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(_limeAccent),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Steps Checklist
                  _buildChecklistStep(
                    stepNum: 1,
                    title: 'Create a halaqah',
                    isDone: hasHalaqah,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                  const SizedBox(height: 10),
                  _buildChecklistStep(
                    stepNum: 2,
                    title: 'Generate a teacher invite code',
                    isDone: hasTeacherCode,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                  const SizedBox(height: 10),
                  _buildChecklistStep(
                    stepNum: 3,
                    title: 'Enroll the first student',
                    isDone: hasStudent,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),

                  const SizedBox(height: 18),

                  // Single Primary Action Button for the next step
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: nextStepAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _limeAccent,
                        foregroundColor: const Color(0xFF0F172A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        nextStepActionText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
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

  Widget _buildChecklistStep({
    required int stepNum,
    required String title,
    required bool isDone,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? _limeAccent.withOpacity(0.2) : Colors.transparent,
            border: Border.all(
              color: isDone ? _limeAccent : subtextColor.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, size: 13, color: _limeAccent)
                : Text(
                    '$stepNum',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: subtextColor,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: isDone ? subtextColor : textColor,
              decoration: isDone ? TextDecoration.lineThrough : null,
              fontWeight: isDone ? FontWeight.normal : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color textColor,
    required Color subtextColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: subtextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatDivider(Color borderColor) {
    return Container(
      width: 1,
      height: 32,
      color: borderColor,
    );
  }

  // ===========================================================================
  // QUICK ACTIONS ROW (Post notice, Invite codes, Add student, Create halaqah)
  // ===========================================================================
  Widget _buildQuickActionsRow({
    required BuildContext context,
    required bool isDark,
    required Color cardBg,
    required Color textColor,
    required Color subtleBorder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick actions',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildActionItem(
              icon: Icons.campaign_outlined,
              label: 'Post notice',
              cardBg: cardBg,
              textColor: textColor,
              subtleBorder: subtleBorder,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => const PostAnnouncementDialog(),
                );
              },
            ),
            const SizedBox(width: 10),
            _buildActionItem(
              icon: Icons.vpn_key_outlined,
              label: 'Invite codes',
              cardBg: cardBg,
              textColor: textColor,
              subtleBorder: subtleBorder,
              onTap: () => InviteCodesBottomSheet.show(context),
            ),
            const SizedBox(width: 10),
            _buildActionItem(
              icon: Icons.person_add_outlined,
              label: 'Add student',
              cardBg: cardBg,
              textColor: textColor,
              subtleBorder: subtleBorder,
              onTap: () => AddStudentDialog.show(context),
            ),
            const SizedBox(width: 10),
            _buildActionItem(
              icon: Icons.menu_book_outlined,
              label: 'Create circle',
              cardBg: cardBg,
              textColor: textColor,
              subtleBorder: subtleBorder,
              onTap: () => HalaqahManagementSheet.show(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required Color cardBg,
    required Color textColor,
    required Color subtleBorder,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: subtleBorder, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: textColor),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ANNOUNCEMENTS: LATEST 1 ITEM AS A SIMPLE CARD
  // ===========================================================================
  Widget _buildAnnouncementsSection({
    required BuildContext context,
    required bool isDark,
    required bool isAdmin,
    required Color cardBg,
    required Color textColor,
    required Color subtextColor,
    required Color subtleBorder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Announcements',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAdmin)
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const PostAnnouncementDialog(),
                      );
                    },
                    icon: Icon(Icons.add_rounded, size: 20, color: textColor),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Post notice',
                  ),
                InkWell(
                  onTap: () => AnnouncementsSheet.show(context),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _limeAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        StreamBuilder<List<Announcement>>(
          stream: AnnouncementService.instance.streamAnnouncements(),
          builder: (context, snapshot) {
            final announcements = snapshot.data ?? [];

            // Friendly empty state
            if (announcements.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: subtleBorder, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.campaign_outlined, size: 24, color: subtextColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No announcements posted yet. Circulars and center notices will appear here.',
                        style: TextStyle(color: subtextColor, fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Exactly 1 latest announcement as a simple card without heavy borders
            final latest = announcements.first;

            return InkWell(
              onTap: () => AnnouncementsSheet.show(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: subtleBorder, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.campaign_rounded, size: 16, color: _limeAccent),
                            SizedBox(width: 6),
                            Text(
                              'CENTER NOTICE',
                              style: TextStyle(
                                color: _limeAccent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _formatDate(latest.createdAt),
                          style: TextStyle(fontSize: 11, color: subtextColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      latest.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      latest.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: subtextColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // INVITE CODES: COLLAPSED INTO A SINGLE ROW
  // ===========================================================================
  Widget _buildInviteCodesCollapsedRow({
    required BuildContext context,
    required bool isDark,
    required Color cardBg,
    required Color textColor,
    required Color subtextColor,
    required Color subtleBorder,
  }) {
    return InkWell(
      onTap: () => InviteCodesBottomSheet.show(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: subtleBorder, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.vpn_key_outlined, size: 18, color: textColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite codes',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Generate teacher & parent registration links',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: subtextColor),
          ],
        ),
      ),
    );
  }

  // Teacher Overview Card
  Widget _buildTeacherOverviewCard({
    required bool isDark,
    required Color cardBg,
    required Color textColor,
    required Color subtextColor,
    required Color subtleBorder,
  }) {
    final className = AuthSessionService.instance.assignedHalaqahName;
    final classStudents = StudentService.instance.getStudentsForHalaqah(className);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: subtleBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                className.isNotEmpty ? className : 'Assigned Circle',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _limeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${classStudents.length} Students',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _limeAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Mark daily attendance and log Quran memorization progress.',
            style: TextStyle(fontSize: 12, color: subtextColor, height: 1.3),
          ),
        ],
      ),
    );
  }

  // Parent Overview Card
  Widget _buildParentOverviewCard({
    required bool isDark,
    required Color cardBg,
    required Color textColor,
    required Color subtextColor,
    required Color subtleBorder,
  }) {
    final children = StudentService.instance.getStudentsForParent(
      AuthSessionService.instance.userId,
      parentEmail: AuthSessionService.instance.userEmail,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: subtleBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Enrolled Children',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _limeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${children.length} Active',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _limeAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'View daily attendance, recitation milestones, and monthly tuition.',
            style: TextStyle(fontSize: 12, color: subtextColor, height: 1.3),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return diff.inMinutes <= 1 ? 'Just now' : '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dt.month}/${dt.day}';
    }
  }
}
