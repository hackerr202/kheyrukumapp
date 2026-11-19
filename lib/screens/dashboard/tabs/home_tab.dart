import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/models/absence_request.dart';
import '../../../core/models/announcement.dart';
import '../../../core/models/student.dart';
import '../../../core/services/absence_service.dart';
import '../../../core/services/announcement_service.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/halaqah_service.dart';
import '../../../core/services/homework_service.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/student_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/add_student_dialog.dart';
import '../../../widgets/pro_ui_kit.dart';
import '../../admin/halaqah_management_sheet.dart';
import '../../admin/invite_codes_bottom_sheet.dart';
import '../../announcements/announcements_sheet.dart';
import '../../announcements/post_announcement_dialog.dart';
import '../../payments/payments_screen.dart';

/// Home Tab: Flagship role-tailored academy overview with Deep Pine hero card,
/// tactile action grid, and editorial announcement feed.
class HomeTab extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const HomeTab({super.key, this.onNavigateToTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Future<void> _handleRefresh() async {
    await Future.wait([
      HalaqahService.instance.fetchHalaqahs(),
      StudentService.instance.refreshAll(),
      HomeworkService.instance.refreshAll(),
      AbsenceService.instance.refreshAll(),
      PaymentService.instance.refresh(),
    ]);
    AnnouncementService.instance.refreshAndSubscribe();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: AuthSessionService.instance.roleNotifier,
      builder: (context, currentRole, _) {
        final isAdmin = currentRole == 'admin';
        final isTeacher = currentRole == 'teacher';

        return RefreshIndicator(
          color: p.primary,
          onRefresh: _handleRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 124),
            children: [
              if (isAdmin) ...[
                _buildAdminCenterStatusCard(context, p),
                const SizedBox(height: 24),
                _buildQuickActionsRow(context, p),
                const SizedBox(height: 24),
                _buildAnnouncementsSection(context, p, isAdmin: true),
                const SizedBox(height: 18),
                _buildInviteCodesCollapsedRow(context, p),
              ] else if (isTeacher) ...[
                _buildTeacherOverviewCard(p),
                const SizedBox(height: 24),
                _buildAnnouncementsSection(context, p, isAdmin: false),
              ] else ...[
                _buildParentOverviewCard(p),
                const SizedBox(height: 24),
                _buildAnnouncementsSection(context, p, isAdmin: false),
              ],
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // ADMIN HERO: CENTER OVERVIEW OR ONBOARDING CHECKLIST
  // ===========================================================================
  Widget _buildAdminCenterStatusCard(BuildContext context, AppPalette p) {
    return AnimatedBuilder(
      animation: HalaqahService.instance.halaqahsNotifier,
      builder: (context, _) {
        return StreamBuilder<List<Student>>(
          stream: StudentService.instance.studentsStream,
          initialData: StudentService.instance.allStudents,
          builder: (context, studentSnapshot) {
            final halaqahs = HalaqahService.instance.halaqahs;
            final students =
                studentSnapshot.data ?? StudentService.instance.allStudents;

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

                if (hasStudent && completedSteps >= 3) {
                  final teachersCount = halaqahs
                      .map((h) => h.teacherId)
                      .where((id) => id != null && id.isNotEmpty)
                      .toSet()
                      .length;

                  return ProHeroCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ACADEMY OVERVIEW',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                    color: AppColors.goldWarm,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Kheyrukum Islamic Center',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.22),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 7,
                                    color: Color(0xFF4ADE80),
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.14),
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildHeroStatItem(
                                label: 'Students',
                                value: '${students.length}',
                                onTap: () => widget.onNavigateToTab?.call(1),
                              ),
                              _buildHeroStatDivider(),
                              _buildHeroStatItem(
                                label: 'Circles',
                                value: '${halaqahs.length}',
                                onTap: () =>
                                    HalaqahManagementSheet.show(context),
                              ),
                              _buildHeroStatDivider(),
                              _buildHeroStatItem(
                                label: 'Ustazs',
                                value: '$teachersCount',
                                onTap: () =>
                                    InviteCodesBottomSheet.show(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Editorial Onboarding Setup Checklist Card
                String nextStepActionText;
                VoidCallback nextStepAction;

                if (!hasHalaqah) {
                  nextStepActionText = 'Create First Halaqah';
                  nextStepAction = () => HalaqahManagementSheet.show(context);
                } else if (!hasTeacherCode) {
                  nextStepActionText = 'Generate Teacher Invite Code';
                  nextStepAction = () => InviteCodesBottomSheet.show(context);
                } else {
                  nextStepActionText = 'Enroll First Student';
                  nextStepAction = () => AddStudentDialog.show(context);
                }

                return ProCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Center Setup',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: p.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Complete onboarding to launch all circles',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: p.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                          ProStatusPill(
                            label: '$completedSteps of 3',
                            color: p.gold,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: completedSteps / 3,
                          minHeight: 6,
                          backgroundColor: p.surfaceSubtle,
                          valueColor: AlwaysStoppedAnimation<Color>(p.gold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildChecklistStep(
                        p: p,
                        stepNum: 1,
                        title: 'Create a study circle (Halaqah)',
                        isDone: hasHalaqah,
                      ),
                      const SizedBox(height: 10),
                      _buildChecklistStep(
                        p: p,
                        stepNum: 2,
                        title: 'Generate a teacher invite code',
                        isDone: hasTeacherCode,
                      ),
                      const SizedBox(height: 10),
                      _buildChecklistStep(
                        p: p,
                        stepNum: 3,
                        title: 'Enroll your first student',
                        isDone: hasStudent,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: nextStepAction,
                          child: Text(nextStepActionText),
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
    required AppPalette p,
    required int stepNum,
    required String title,
    required bool isDone,
  }) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? p.success.withOpacity(0.15) : p.surfaceSubtle,
            border: Border.all(
              color: isDone ? p.success : p.border,
              width: 1.5,
            ),
          ),
          child: Center(
            child: isDone
                ? Icon(Icons.check_rounded, size: 13, color: p.success)
                : Text(
                    '$stepNum',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: p.inkSecondary,
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
              color: isDone ? p.inkMuted : p.ink,
              decoration: isDone ? TextDecoration.lineThrough : null,
              fontWeight: isDone ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroStatItem({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white.withOpacity(0.76),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStatDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withOpacity(0.18),
    );
  }

  // ===========================================================================
  // QUICK ACTIONS GRID (Admin)
  // ===========================================================================
  Widget _buildQuickActionsRow(BuildContext context, AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProSectionHeader(title: 'Quick Actions'),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildActionItem(
              p: p,
              icon: Icons.campaign_outlined,
              label: 'Post Notice',
              accent: p.primary,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => const PostAnnouncementDialog(),
                );
              },
            ),
            const SizedBox(width: 10),
            _buildActionItem(
              p: p,
              icon: Icons.vpn_key_outlined,
              label: 'Invite Codes',
              accent: p.gold,
              onTap: () => InviteCodesBottomSheet.show(context),
            ),
            const SizedBox(width: 10),
            _buildActionItem(
              p: p,
              icon: Icons.person_add_outlined,
              label: 'Add Student',
              accent: p.primary,
              onTap: () => AddStudentDialog.show(context),
            ),
            const SizedBox(width: 10),
            _buildActionItem(
              p: p,
              icon: Icons.menu_book_outlined,
              label: 'Circles',
              accent: p.gold,
              onTap: () => HalaqahManagementSheet.show(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem({
    required AppPalette p,
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: ProCard(
        onTap: onTap,
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TEACHER OVERVIEW HERO CARD
  // ===========================================================================
  Widget _buildTeacherOverviewCard(AppPalette p) {
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
          if (StudentService.instance.getTodayAttendanceForStudent(s.id) !=
              null) {
            markedToday++;
          }
        }
        final total = classStudents.length;
        final ratio = total > 0 ? (markedToday / total).clamp(0.0, 1.0) : 0.0;

        return StreamBuilder<List<AbsenceRequest>>(
          stream: AbsenceService.instance.requestsStream,
          initialData: AbsenceService.instance.allRequests,
          builder: (context, _) {
            final pendingExcuses = AbsenceService.instance
                .getPendingRequestsForHalaqah(className, halaqahId: classId)
                .length;

            return ProHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ASSIGNED STUDY CIRCLE',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                color: AppColors.goldWarm,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              className.isNotEmpty
                                  ? className
                                  : 'Assigned Circle',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$total Students',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Today\'s Attendance',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.82),
                        ),
                      ),
                      Text(
                        '$markedToday / $total marked',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: Colors.white.withOpacity(0.18),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.goldWarm,
                      ),
                    ),
                  ),
                  if (pendingExcuses > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.goldWarm.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.goldWarm.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.mark_email_unread_rounded,
                            size: 14,
                            color: AppColors.goldWarm,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$pendingExcuses pending absence excuse${pendingExcuses == 1 ? '' : 's'} to review',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => widget.onNavigateToTab?.call(1),
                          icon: const Icon(Icons.fact_check_rounded, size: 16),
                          label: const Text('Take Attendance'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.goldWarm,
                            foregroundColor: const Color(0xFF102322),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => widget.onNavigateToTab?.call(3),
                          icon: const Icon(
                            Icons.menu_book_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Homework',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.32),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
      },
    );
  }

  // ===========================================================================
  // PARENT OVERVIEW HERO CARD
  // ===========================================================================
  Widget _buildParentOverviewCard(AppPalette p) {
    return StreamBuilder<List<Student>>(
      stream: StudentService.instance.studentsStream,
      initialData: StudentService.instance.allStudents,
      builder: (context, _) {
        final children = StudentService.instance.getStudentsForParent(
          AuthSessionService.instance.userId,
          parentEmail: AuthSessionService.instance.userEmail,
        );
        final activeChild = children.isNotEmpty ? children.first : null;
        final todayAtt = activeChild != null
            ? StudentService.instance.getTodayAttendanceForStudent(activeChild.id)
            : null;
        final juzProgress = activeChild != null
            ? (activeChild.currentJuz / 30.0).clamp(0.03, 1.0)
            : 0.0;

        return ProHeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FAMILY LEARNING HUB',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: AppColors.goldWarm,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        activeChild != null
                            ? activeChild.fullName
                            : 'Welcome Parent',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${children.length} Enrolled',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (activeChild != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Juz ${activeChild.currentJuz} • Surah #${activeChild.currentSurah}, Ayah ${activeChild.currentAyah}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withOpacity(0.88),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (todayAtt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.goldWarm.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Today: ${todayAtt.status.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.goldWarm,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: juzProgress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.18),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.goldWarm,
                    ),
                  ),
                ),
              ] else
                Text(
                  'No children linked to your account yet. Please contact center administration.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withOpacity(0.82),
                    height: 1.4,
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onNavigateToTab?.call(1),
                      icon: const Icon(Icons.auto_stories_rounded, size: 16),
                      label: const Text('Learning Progress'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.goldWarm,
                        foregroundColor: const Color(0xFF102322),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaymentsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.receipt_long_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Tuition & Fees',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.32),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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

  // ===========================================================================
  // ANNOUNCEMENTS EDITORIAL FEED
  // ===========================================================================
  Widget _buildAnnouncementsSection(
    BuildContext context,
    AppPalette p, {
    required bool isAdmin,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProSectionHeader(
          title: 'School Announcements',
          subtitle: 'Official circulars and schedule notices',
          trailing: Row(
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
                  icon: Icon(Icons.add_circle_outline_rounded,
                      size: 20, color: p.primary),
                  padding: const EdgeInsets.all(6),
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Post notice',
                ),
              TextButton(
                onPressed: () => AnnouncementsSheet.show(context),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View all'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Announcement>>(
          stream: AnnouncementService.instance.streamAnnouncements(),
          builder: (context, snapshot) {
            final announcements = snapshot.data ?? [];

            if (announcements.isEmpty) {
              return ProEmptyState(
                icon: Icons.campaign_outlined,
                title: 'No announcements yet',
                message:
                    'Official circulars and center notices will appear here as soon as they are published.',
                accentColor: p.gold,
              );
            }

            return _VerticalAnnouncementsList(
              announcements: announcements,
              p: p,
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // ADMIN INVITE CODES QUICK ROW
  // ===========================================================================
  Widget _buildInviteCodesCollapsedRow(BuildContext context, AppPalette p) {
    return ProCard(
      onTap: () => InviteCodesBottomSheet.show(context),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: p.goldSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.vpn_key_outlined, size: 20, color: p.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invitation Codes',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Generate teacher & parent onboarding codes',
                  style: TextStyle(
                    fontSize: 12,
                    color: p.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: p.inkMuted),
        ],
      ),
    );
  }
}

class _VerticalAnnouncementsList extends StatelessWidget {
  final List<Announcement> announcements;
  final AppPalette p;

  const _VerticalAnnouncementsList({
    required this.announcements,
    required this.p,
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
    final items = announcements.take(4).toList();

    return Column(
      children: items.map((item) {
        final isPinned = item.isPinned;
        final hasImage = item.attachmentUrl != null &&
            item.attachmentUrl!.isNotEmpty &&
            _isImage(item.attachmentUrl!, item.attachmentName);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ProCard(
            onTap: () => AnnouncementsSheet.show(context),
            accentStripeColor: isPinned ? p.gold : null,
            borderColor: isPinned ? p.gold.withOpacity(0.45) : p.border,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ProStatusPill(
                      label: isPinned ? 'Pinned Notice' : 'Center Notice',
                      icon: isPinned
                          ? Icons.push_pin_rounded
                          : Icons.campaign_rounded,
                      color: isPinned ? p.gold : p.primary,
                    ),
                    Text(
                      _formatAnnouncementDate(item.createdAt),
                      style: TextStyle(fontSize: 11, color: p.inkMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                    letterSpacing: -0.15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.content,
                  maxLines: hasImage ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: p.inkSecondary,
                    height: 1.45,
                  ),
                ),
                if (hasImage) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 190),
                      width: double.infinity,
                      color: p.surfaceSubtle,
                      child: Image.network(
                        item.attachmentUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return SizedBox(
                            height: 120,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: p.primary,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ] else if (item.attachmentUrl != null &&
                    item.attachmentUrl!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: p.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.attach_file_rounded,
                          size: 14,
                          color: p.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.attachmentName ?? 'Attachment',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: p.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (item.authorName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 13,
                        color: p.inkMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        item.authorName,
                        style: TextStyle(
                          fontSize: 11,
                          color: p.inkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
