import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/absence_request.dart';
import '../../../core/models/announcement.dart';
import '../../../core/models/homework.dart';
import '../../../core/models/invitation_code.dart';
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
import '../../../core/utils/json_parsers.dart';
import '../../../widgets/add_student_dialog.dart';
import '../../../widgets/pro_shimmer.dart';
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
  late final Stream<List<Student>> _studentsStream;
  late final Stream<List<InvitationCode>> _inviteCodesStream;
  late final Stream<List<Announcement>> _announcementsStream;

  @override
  void initState() {
    super.initState();
    _studentsStream = StudentService.instance.studentsStream;
    _inviteCodesStream = SupabaseService.instance.streamInviteCodes();
    _announcementsStream = AnnouncementService.instance.streamAnnouncements();
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      HalaqahService.instance.fetchHalaqahs(),
      StudentService.instance.refreshAll(),
      HomeworkService.instance.refreshAll(),
      AbsenceService.instance.refreshAll(),
      PaymentService.instance.refresh(),
      AnnouncementService.instance.refreshAndSubscribe(),
    ]);
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
                _buildAnnouncementsSection(context, p),
              ] else if (isTeacher) ...[
                _buildTeacherOverviewCard(p),
                const SizedBox(height: 24),
                _buildAnnouncementsSection(context, p),
              ] else ...[
                _buildParentOverviewCard(p),
                const SizedBox(height: 24),
                _buildAnnouncementsSection(context, p),
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
    final loc = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: HalaqahService.instance.halaqahsNotifier,
      builder: (context, _) {
        return StreamBuilder<List<Student>>(
          stream: _studentsStream,
          initialData: StudentService.instance.allStudents,
          builder: (context, studentSnapshot) {
            final halaqahs = HalaqahService.instance.halaqahs;
            final students =
                studentSnapshot.data ?? StudentService.instance.allStudents;
            if (studentSnapshot.connectionState == ConnectionState.waiting &&
                students.isEmpty &&
                halaqahs.isEmpty) {
              return const ProShimmer(
                child: ProShimmerBox(height: 196, borderRadius: 24),
              );
            }

            final hasHalaqah = halaqahs.isNotEmpty;
            final hasStudent = students.isNotEmpty;

            return StreamBuilder<List<InvitationCode>>(
              stream: _inviteCodesStream,
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
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.academyOverview,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                      color: Color(0xFFF6CE6B),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    loc.appName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 11,
                                    color: Color(0xFFF6CE6B),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    loc.formatTodayDateBanner(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              _buildHeroStatItem(
                                label: loc.studentsCount,
                                value: '${students.length}',
                                onTap: () => widget.onNavigateToTab?.call(1),
                              ),
                              _buildHeroStatDivider(),
                              _buildHeroStatItem(
                                label: loc.circlesCount,
                                value: '${halaqahs.length}',
                                onTap: () =>
                                    HalaqahManagementSheet.show(context),
                              ),
                              _buildHeroStatDivider(),
                              _buildHeroStatItem(
                                label: loc.ustazsCount,
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
                  nextStepActionText =
                      loc.translate('createFirstHalaqahAction');
                  nextStepAction = () => HalaqahManagementSheet.show(context);
                } else if (!hasTeacherCode) {
                  nextStepActionText =
                      loc.translate('generateTeacherCodeAction');
                  nextStepAction = () => InviteCodesBottomSheet.show(context);
                } else {
                  nextStepActionText =
                      loc.translate('enrollFirstStudentAction');
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
                                loc.translate('centerSetupTitle'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: p.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                loc.translate('completeOnboardingSubtitle'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: p.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                          ProStatusPill(
                            label: loc.tr('stepsOf3', {'count': '$completedSteps'}),
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
                        title: loc.translate('checklistStep1'),
                        isDone: hasHalaqah,
                      ),
                      const SizedBox(height: 10),
                      _buildChecklistStep(
                        p: p,
                        stepNum: 2,
                        title: loc.translate('checklistStep2'),
                        isDone: hasTeacherCode,
                      ),
                      const SizedBox(height: 10),
                      _buildChecklistStep(
                        p: p,
                        stepNum: 3,
                        title: loc.translate('checklistStep3'),
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
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.6,
                  height: 1.05,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white.withOpacity(0.80),
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
      height: 32,
      color: Colors.white.withOpacity(0.18),
    );
  }

  // ===========================================================================
  // QUICK ACTIONS 2x2 HORIZONTAL GRID (Admin)
  // ===========================================================================
  Widget _buildQuickActionsRow(BuildContext context, AppPalette p) {
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProSectionHeader(title: loc.quickActions),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildActionItem(
              p: p,
              icon: Icons.campaign_outlined,
              label: loc.postNotice,
              subtitle: loc.schoolAnnouncements,
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
              label: loc.inviteCodes,
              subtitle: loc.generateInviteCode,
              accent: p.gold,
              onTap: () => InviteCodesBottomSheet.show(context),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildActionItem(
              p: p,
              icon: Icons.person_add_outlined,
              label: loc.addStudent,
              subtitle: loc.enrollStudent,
              accent: p.primary,
              onTap: () => AddStudentDialog.show(context),
            ),
            const SizedBox(width: 10),
            _buildActionItem(
              p: p,
              icon: Icons.auto_stories_outlined,
              label: loc.studyCircles,
              subtitle: loc.manageCircles,
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
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: ProCard(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: p.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          ),
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

        final openAssignments = HomeworkService.instance
            .getAssignmentsForHalaqah(className)
            .where((a) => !a.isOverdue)
            .length;

        return StreamBuilder<List<AbsenceRequest>>(
          stream: AbsenceService.instance.requestsStream,
          initialData: AbsenceService.instance.allRequests,
          builder: (context, _) {
            final loc = AppLocalizations.of(context);
            final pendingExcuses = AbsenceService.instance
                .getPendingRequestsForHalaqah(className, halaqahId: classId)
                .length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProHeroCard(
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
                                  loc.translate('assignedStudyCircleHeader'),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                    color: Color(0xFFF6CE6B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  className.isNotEmpty
                                      ? className
                                      : loc.assignedCircle,
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
                              total == 1
                                  ? loc.translate('studentBadgeOne')
                                  : loc.tr('studentsBadgeLabel',
                                      {'count': '$total'}),
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
                            loc.translate('todaysAttendanceLabel'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.82),
                            ),
                          ),
                          Text(
                            loc.tr('markedProgressLabel', {
                              'marked': '$markedToday',
                              'total': '$total',
                            }),
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
                                pendingExcuses == 1
                                    ? loc.translate('pendingExcusesNoticeOne')
                                    : loc.tr('pendingExcusesNoticeMany',
                                        {'count': '$pendingExcuses'}),
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
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                widget.onNavigateToTab?.call(1);
                              },
                              icon:
                                  const Icon(Icons.fact_check_rounded, size: 16),
                              label: Text(loc.translate('takeAttendanceAction')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.goldWarm,
                                foregroundColor: const Color(0xFF102322),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                widget.onNavigateToTab?.call(3);
                              },
                              icon: const Icon(
                                Icons.assignment_turned_in_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: Text(
                                loc.navHomework,
                                style: const TextStyle(color: Colors.white),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.32),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildExecutiveKpiCard(
                      p: p,
                      icon: Icons.people_alt_rounded,
                      accent: p.primary,
                      value: '$total',
                      label: loc.studentsCount,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onNavigateToTab?.call(1);
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildExecutiveKpiCard(
                      p: p,
                      icon: Icons.assignment_turned_in_rounded,
                      accent: p.gold,
                      value: '$openAssignments',
                      label: loc.navHomework,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onNavigateToTab?.call(3);
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildExecutiveKpiCard({
    required AppPalette p,
    required IconData icon,
    required Color accent,
    required String value,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: ProCard(
        onTap: onTap,
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withOpacity(p.isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: p.ink,
                        height: 1.05,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _latestQualitativeRatingForStudent(String studentId) {
    HomeworkSubmission? latestSub;
    for (final s in HomeworkService.instance.allSubmissions) {
      if (s.studentId == studentId &&
          s.isReviewed &&
          s.teacherRating != null &&
          s.teacherRating!.isNotEmpty) {
        if (latestSub == null ||
            (s.reviewedAt ?? DateTime(2000))
                .isAfter(latestSub.reviewedAt ?? DateTime(2000))) {
          latestSub = s;
        }
      }
    }
    if (latestSub != null) return latestSub.teacherRating;

    final reports = StudentService.instance.getWeeklyReportsForStudent(studentId);
    if (reports.isNotEmpty) {
      return reports.first.tajweedRating;
    }
    return null;
  }

  List<({DateTime day, bool isActive})> _computeSevenDayStreak(
    String studentId,
  ) {
    final activeDateKeys = <String>{};
    for (final att in StudentService.instance.getAttendanceForStudent(studentId)) {
      if (att.status == 'present' || att.status == 'late') {
        final d = att.date.toLocal();
        activeDateKeys.add('${d.year}-${d.month}-${d.day}');
      }
    }
    for (final sub in HomeworkService.instance.allSubmissions) {
      if (sub.studentId == studentId && sub.practicedAt != null) {
        final d = sub.practicedAt!.toLocal();
        activeDateKeys.add('${d.year}-${d.month}-${d.day}');
      }
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      final key = '${day.year}-${day.month}-${day.day}';
      return (day: day, isActive: activeDateKeys.contains(key));
    });
  }

  String _weekdayInitial(DateTime day, AppLocalizations loc) {
    const keys = [
      'dayLetterMon',
      'dayLetterTue',
      'dayLetterWed',
      'dayLetterThu',
      'dayLetterFri',
      'dayLetterSat',
      'dayLetterSun',
    ];
    return loc.translate(keys[(day.weekday - 1).clamp(0, 6)]);
  }

  // ===========================================================================
  // PARENT OVERVIEW HERO CARD ("QURAN JOURNEY")
  // ===========================================================================
  Widget _buildParentOverviewCard(AppPalette p) {
    return StreamBuilder<List<Student>>(
      stream: StudentService.instance.studentsStream,
      initialData: StudentService.instance.allStudents,
      builder: (context, snapshot) {
        final loc = AppLocalizations.of(context);
        final children = StudentService.instance.getStudentsForParent(
          AuthSessionService.instance.userId,
          parentEmail: AuthSessionService.instance.userEmail,
        );
        if (snapshot.connectionState == ConnectionState.waiting &&
            children.isEmpty &&
            StudentService.instance.allStudents.isEmpty) {
          return const ProShimmer(
            child: ProShimmerBox(height: 256, borderRadius: 24),
          );
        }

        final activeChild = children.isNotEmpty ? children.first : null;
        final juzProgress = activeChild != null
            ? (activeChild.currentJuz / 30.0).clamp(0.03, 1.0)
            : 0.0;
        final latestRawRating = activeChild != null
            ? _latestQualitativeRatingForStudent(activeChild.id)
            : null;
        final isMumtaz = latestRawRating != null &&
            (latestRawRating.contains('Mumtaz') ||
                latestRawRating == 'Excellent');
        final streakDays = activeChild != null
            ? _computeSevenDayStreak(activeChild.id)
            : const <({DateTime day, bool isActive})>[];
        final activeStreakCount = streakDays.where((d) => d.isActive).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProHeroCard(
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
                              loc.translate('quranJourneyHeader'),
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                color: Color(0xFFF6CE6B),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              activeChild != null
                                  ? activeChild.fullName
                                  : loc.translate('welcomeParentFallback'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (activeChild != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                activeChild.halaqahName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.76),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (latestRawRating != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isMumtaz
                                ? AppColors.goldWarm.withOpacity(0.22)
                                : AppColors.statusSuccessDark.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: (isMumtaz
                                      ? AppColors.goldWarm
                                      : AppColors.statusSuccessDark)
                                  .withOpacity(0.55),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isMumtaz) ...[
                                const Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: AppColors.goldWarm,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                loc.localizedTajweedRating(latestRawRating),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isMumtaz
                                      ? AppColors.goldWarm
                                      : const Color(0xFF6EE7B7),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
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
                            loc.tr('enrolledCountBadge',
                                {'count': '${children.length}'}),
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
                  if (activeChild != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            loc.tr('juzSurahAyahSummary', {
                              'juz': '${activeChild.currentJuz}',
                              'surah': '${activeChild.currentSurah}',
                              'ayah': '${activeChild.currentAyah}',
                            }),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withOpacity(0.90),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${activeChild.currentJuz}/30',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.goldWarm,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: juzProgress,
                        minHeight: 7,
                        backgroundColor: Colors.white.withOpacity(0.18),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.goldWarm,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                loc.translate('sevenDayStreakLabel'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.84),
                                ),
                              ),
                              Text(
                                loc.tr('streakDaysCount', {
                                  'count': '$activeStreakCount',
                                }),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.goldWarm,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (final entry in streakDays)
                                Container(
                                  width: 34,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: entry.isActive
                                        ? AppColors.statusSuccessDark
                                            .withOpacity(0.24)
                                        : Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: entry.isActive
                                          ? AppColors.goldWarm.withOpacity(0.75)
                                          : Colors.white.withOpacity(0.16),
                                      width: entry.isActive ? 1.3 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _weekdayInitial(entry.day, loc),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: entry.isActive
                                              ? Colors.white
                                              : Colors.white.withOpacity(0.62),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Icon(
                                        entry.isActive
                                            ? Icons.check_circle_rounded
                                            : Icons.circle_outlined,
                                        size: 13,
                                        color: entry.isActive
                                            ? AppColors.goldWarm
                                            : Colors.white.withOpacity(0.32),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else
                    Text(
                      loc.translate('noChildrenLinkedBanner'),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withOpacity(0.82),
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PaymentsScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.receipt_long_rounded,
                            size: 16,
                            color: AppColors.goldWarm,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              loc.tuitionAndFees,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Directionality.of(context) == TextDirection.rtl
                                ? Icons.chevron_left_rounded
                                : Icons.chevron_right_rounded,
                            size: 18,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildParentQuickActionButton(
                  p: p,
                  icon: Icons.assignment_turned_in_rounded,
                  label: loc.translate('homeworkActionShort'),
                  accent: p.primary,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onNavigateToTab?.call(3);
                  },
                ),
                const SizedBox(width: 8),
                _buildParentQuickActionButton(
                  p: p,
                  icon: Icons.chat_bubble_rounded,
                  label: loc.translate('messageUstazAction'),
                  accent: p.gold,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onNavigateToTab?.call(2);
                  },
                ),
                const SizedBox(width: 8),
                _buildParentQuickActionButton(
                  p: p,
                  icon: Icons.event_note_rounded,
                  label: loc.translate('absenceActionShort'),
                  accent: p.excused,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onNavigateToTab?.call(1);
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildParentQuickActionButton({
    required AppPalette p,
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: ProCard(
        onTap: onTap,
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withOpacity(p.isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ANNOUNCEMENTS EDITORIAL FEED
  // ===========================================================================
  Widget _buildAnnouncementsSection(BuildContext context, AppPalette p) {
    final loc = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProSectionHeader(
          title: loc.schoolAnnouncements,
          subtitle: loc.officialCirculars,
          trailing: TextButton(
            onPressed: () => AnnouncementsSheet.show(context, initialTab: 1),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc.viewAll,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 2),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: 17,
                  color: p.primary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Announcement>>(
          stream: _announcementsStream,
          builder: (context, snapshot) {
            final loc = AppLocalizations.of(context);
            final announcements = snapshot.data ?? [];

            if (snapshot.connectionState == ConnectionState.waiting &&
                announcements.isEmpty) {
              return const ProShimmer(
                child: Column(
                  children: [
                    ProShimmerBox(height: 112, borderRadius: 20),
                    SizedBox(height: 12),
                    ProShimmerBox(height: 112, borderRadius: 20),
                  ],
                ),
              );
            }

            if (announcements.isEmpty) {
              return ProEmptyState(
                icon: Icons.campaign_outlined,
                title: loc.translate('noAnnouncementsTitle'),
                message: loc.translate('noAnnouncementsDesc'),
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
}

class _VerticalAnnouncementsList extends StatelessWidget {
  final List<Announcement> announcements;
  final AppPalette p;

  const _VerticalAnnouncementsList({
    required this.announcements,
    required this.p,
  });

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
    final loc = AppLocalizations.of(context);
    final items = announcements.take(4).toList();

    return Column(
      children: items.map((item) {
        final isPinned = item.isPinned;
        final hasAudienceTag = item.targetAudience == 'parents' ||
            item.targetAudience == 'teachers';
        final audienceLabel = item.targetAudience == 'parents'
            ? loc.parentsTab
            : loc.teachersTab;
        final hasImage = item.attachmentUrl != null &&
            item.attachmentUrl!.isNotEmpty &&
            _isImage(item.attachmentUrl!, item.attachmentName);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ProCard(
            onTap: () => AnnouncementsSheet.show(context, initialTab: 1),
            accentStripeColor: isPinned ? p.gold : null,
            borderColor: isPinned ? p.gold.withOpacity(0.45) : p.border,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isPinned || hasAudienceTag)
                      Wrap(
                        spacing: 6,
                        children: [
                          if (isPinned)
                            ProStatusPill(
                              label: loc.translate('pinnedTag'),
                              icon: Icons.push_pin_rounded,
                              color: p.gold,
                            ),
                          if (hasAudienceTag)
                            ProStatusPill(
                              label: audienceLabel,
                              color: p.primary,
                            ),
                        ],
                      )
                    else
                      Text(
                        loc.translate('centerNoticeTag'),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: p.primary,
                          letterSpacing: 0.6,
                        ),
                      ),
                    Text(
                      loc.formatRelativeDate(item.createdAt),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: p.inkSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                    letterSpacing: -0.25,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.content,
                  maxLines: hasImage ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: p.inkSecondary,
                    height: 1.48,
                  ),
                ),
                if (hasImage) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 240),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: p.surfaceSubtle,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.border),
                      ),
                      child: ProSignedImage(
                        mediaRef: item.attachmentUrl!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        placeholder: const ProShimmer(
                          child: ProShimmerBox(
                            height: 130,
                            borderRadius: 14,
                          ),
                        ),
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
                            item.attachmentName ??
                                loc.translate('attachmentFallback'),
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
                if (item.authorName.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.primary.withOpacity(0.12),
                        ),
                        child: Center(
                          child: Text(
                            JsonParsers.safeInitial(item.authorName),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: p.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          item.authorName
                              .replaceAll(' (Director)', ' · ${loc.roleAdmin}')
                              .replaceAll(
                                  'Center Administration',
                                  loc.centerAdministrationTitle),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: p.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
