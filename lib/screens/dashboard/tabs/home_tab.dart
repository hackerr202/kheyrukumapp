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
import '../../payments/payments_screen.dart';

/// Home Tab: Modern editorial Islamic center dashboard with role-tailored hero card,
/// quick actions grid, and vertical announcement feed with photo attachments.
class HomeTab extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const HomeTab({super.key, this.onNavigateToTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const Color _limeAccent = AppColors.accentEmerald;
  static const Color _alertRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.surfaceCard : Colors.white;
    final subtleBorder = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    return ValueListenableBuilder<String>(
      valueListenable: AuthSessionService.instance.roleNotifier,
      builder: (context, currentRole, _) {
        final isAdmin = currentRole == 'admin';
        final isTeacher = currentRole == 'teacher';

        // 20px side padding, 120px bottom padding to avoid overlapping floating bottom nav
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            if (isAdmin) ...[
              // Hero Center Status / Onboarding Card
              _buildAdminCenterStatusCard(
                context: context,
                isDark: isDark,
                cardBg: cardBg,
                textColor: textColor,
                subtextColor: subtextColor,
                subtleBorder: subtleBorder,
              ),

              const SizedBox(height: 22),

              // Quick Actions Grid
              _buildQuickActionsRow(
                context: context,
                isDark: isDark,
                cardBg: cardBg,
                textColor: textColor,
                subtleBorder: subtleBorder,
              ),

              const SizedBox(height: 22),

              // Announcements Vertical Feed
              _buildAnnouncementsSection(
                context: context,
                isDark: isDark,
                isAdmin: true,
                cardBg: cardBg,
                textColor: textColor,
                subtextColor: subtextColor,
                subtleBorder: subtleBorder,
              ),

              const SizedBox(height: 18),

              // Invite Codes quick row
              _buildInviteCodesCollapsedRow(
                context: context,
                isDark: isDark,
                cardBg: cardBg,
                textColor: textColor,
                subtextColor: subtextColor,
                subtleBorder: subtleBorder,
              ),
            ] else if (isTeacher) ...[
              _buildTeacherOverviewCard(
                isDark: isDark,
                cardBg: cardBg,
                textColor: textColor,
                subtextColor: subtextColor,
                subtleBorder: subtleBorder,
              ),
              const SizedBox(height: 22),
              _buildAnnouncementsSection(
                context: context,
                isDark: isDark,
                isAdmin: false,
                cardBg: cardBg,
                textColor: textColor,
                subtextColor: subtextColor,
                subtleBorder: subtleBorder,
              ),
            ] else ...[
              _buildParentOverviewCard(
                isDark: isDark,
                cardBg: cardBg,
                textColor: textColor,
                subtextColor: subtextColor,
                subtleBorder: subtleBorder,
              ),
              const SizedBox(height: 22),
              _buildAnnouncementsSection(
                context: context,
                isDark: isDark,
                isAdmin: false,
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

            // If setup is complete (or students exist), show elevated Center Overview Hero Card
            if (hasStudent && completedSteps >= 3) {
              final teachersCount = halaqahs.map((h) => h.teacherId).where((id) => id != null && id.isNotEmpty).toSet().length;

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF11262D), Color(0xFF131C31)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFECFDF5), Color(0xFFFFFFFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.accentEmerald.withOpacity(isDark ? 0.28 : 0.35),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Center Overview',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: subtextColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentEmerald.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 6, color: AppColors.accentEmerald),
                              SizedBox(width: 5),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentEmerald,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: subtleBorder, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.accentEmerald.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: AppColors.accentEmerald),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
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

            // Prominently display announcements in a vertical feed
            return _VerticalAnnouncementsList(
              announcements: announcements,
              isDark: isDark,
              cardBg: cardBg,
              textColor: textColor,
              subtextColor: subtextColor,
              subtleBorder: subtleBorder,
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

  // Teacher Overview Hero Card
  Widget _buildTeacherOverviewCard({
    required bool isDark,
    required Color cardBg,
    required Color textColor,
    required Color subtextColor,
    required Color subtleBorder,
  }) {
    final className = AuthSessionService.instance.assignedHalaqahName;
    final classId = AuthSessionService.instance.assignedHalaqahId;

    return StreamBuilder<List<Student>>(
      stream: StudentService.instance.studentsStream,
      initialData: StudentService.instance.allStudents,
      builder: (context, _) {
        final classStudents = StudentService.instance.getStudentsForHalaqah(
          className,
          halaqahId: classId,
        );
        int markedToday = 0;
        for (final s in classStudents) {
          if (StudentService.instance.getTodayAttendanceForStudent(s.id) != null) {
            markedToday++;
          }
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    colors: [Color(0xFF0E292E), Color(0xFF131C31)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFF0FDFA), Color(0xFFFFFFFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.accentTeal.withOpacity(isDark ? 0.35 : 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ASSIGNED STUDY CIRCLE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.accentTealLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          className.isNotEmpty ? className : 'Assigned Circle',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.accentEmerald.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${classStudents.length} Students',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentEmerald,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Today\'s attendance: $markedToday of ${classStudents.length} marked.',
                style: TextStyle(fontSize: 12.5, color: subtextColor),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onNavigateToTab?.call(1),
                      icon: const Icon(Icons.fact_check_rounded, size: 16),
                      label: const Text('Take Attendance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentEmerald,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onNavigateToTab?.call(3),
                      icon: const Icon(Icons.menu_book_rounded, size: 16),
                      label: const Text('Homework', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(color: subtleBorder),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Parent Overview Hero Card
  Widget _buildParentOverviewCard({
    required bool isDark,
    required Color cardBg,
    required Color textColor,
    required Color subtextColor,
    required Color subtleBorder,
  }) {
    return StreamBuilder<List<Student>>(
      stream: StudentService.instance.studentsStream,
      initialData: StudentService.instance.allStudents,
      builder: (context, _) {
        final children = StudentService.instance.getStudentsForParent(
          AuthSessionService.instance.userId,
          parentEmail: AuthSessionService.instance.userEmail,
        );
        final activeChild = children.isNotEmpty ? children.first : null;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    colors: [Color(0xFF231F16), Color(0xFF131C31)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFFFFBEB), Color(0xFFFFFFFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.accentAmber.withOpacity(isDark ? 0.35 : 0.4),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Family Learning Hub',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentAmber.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${children.length} Enrolled',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentAmber,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                activeChild != null
                    ? '${activeChild.fullName} — Juz ${activeChild.currentJuz}, Surah #${activeChild.currentSurah}, Ayah ${activeChild.currentAyah}'
                    : 'No children linked to your account yet. Contact center administration.',
                style: TextStyle(fontSize: 12.5, color: subtextColor, height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onNavigateToTab?.call(1),
                      icon: const Icon(Icons.auto_stories_rounded, size: 16),
                      label: const Text('Progress', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentAmber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PaymentsScreen()),
                        );
                      },
                      icon: const Icon(Icons.receipt_long_rounded, size: 16),
                      label: const Text('Tuition', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(color: subtleBorder),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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

class _VerticalAnnouncementsList extends StatelessWidget {
  final List<Announcement> announcements;
  final bool isDark;
  final Color cardBg;
  final Color textColor;
  final Color subtextColor;
  final Color subtleBorder;

  const _VerticalAnnouncementsList({
    required this.announcements,
    required this.isDark,
    required this.cardBg,
    required this.textColor,
    required this.subtextColor,
    required this.subtleBorder,
  });

  String _formatAnnouncementDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return diff.inMinutes <= 1 ? 'Just now' : '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dt.month}/${dt.day}';
    }
  }

  bool _isImage(String url, String? name) {
    final lowerUrl = url.toLowerCase();
    final lowerName = (name ?? '').toLowerCase();
    return lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.webp') ||
        lowerUrl.endsWith('.gif') ||
        lowerUrl.contains('images%2f') ||
        lowerUrl.contains('/images/') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp');
  }

  @override
  Widget build(BuildContext context) {
    // Show announcements vertically stacked (up to 4 prominent items)
    final items = announcements.take(4).toList();

    return Column(
      children: items.map((item) {
        final isPinned = item.isPinned;
        final hasImage = item.attachmentUrl != null &&
            item.attachmentUrl!.isNotEmpty &&
            _isImage(item.attachmentUrl!, item.attachmentName);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => AnnouncementsSheet.show(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPinned ? AppColors.accentAmber.withOpacity(0.4) : subtleBorder,
                  width: isPinned ? 1.5 : 1,
                ),
                boxShadow: [
                  if (isPinned)
                    BoxShadow(
                      color: AppColors.accentAmber.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPinned ? Icons.push_pin_rounded : Icons.campaign_rounded,
                            size: 16,
                            color: isPinned ? AppColors.accentAmber : AppColors.accentEmerald,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isPinned ? 'PINNED NOTICE' : 'CENTER NOTICE',
                            style: TextStyle(
                              color: isPinned ? AppColors.accentAmber : AppColors.accentEmerald,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatAnnouncementDate(item.createdAt),
                        style: TextStyle(fontSize: 11, color: subtextColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.content,
                    maxLines: hasImage ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: subtextColor,
                      height: 1.35,
                    ),
                  ),
                  if (hasImage) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        width: double.infinity,
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        child: Image.network(
                          item.attachmentUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const SizedBox(
                              height: 100,
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          },
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ] else if (item.attachmentUrl != null && item.attachmentUrl!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attach_file_rounded, size: 12, color: subtextColor),
                          const SizedBox(width: 4),
                          Text(
                            item.attachmentName ?? 'Attachment',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: subtextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (item.authorName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 12, color: subtextColor.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(
                          item.authorName,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontStyle: FontStyle.italic,
                            color: subtextColor.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
