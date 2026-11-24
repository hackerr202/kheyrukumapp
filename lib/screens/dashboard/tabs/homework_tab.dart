import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/homework.dart';
import '../../../core/models/student.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/homework_service.dart';
import '../../../core/services/offline_sync_service.dart';
import '../../../core/services/student_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/pro_ui_kit.dart';

/// Flagship Quran & Tajweed Homework Tab:
/// - Teacher: Create assignments for assigned circle, track completion bar, review & grade submissions.
/// - Parent: Multi-child switcher, home practice checklist, repetition counter & Ustaz feedback.
/// - Admin: Center-wide homework oversight across all circles.
class HomeworkTab extends StatefulWidget {
  const HomeworkTab({super.key});

  @override
  State<HomeworkTab> createState() => _HomeworkTabState();
}

class _HomeworkTabState extends State<HomeworkTab> {
  int _selectedChildIndex = 0;
  String _teacherFilter = 'all';

  Future<void> _handleRefresh() async {
    await HomeworkService.instance.refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: AuthSessionService.instance.roleNotifier,
      builder: (context, currentRole, _) {
        if (currentRole == 'teacher') {
          return _buildTeacherView(context, p);
        } else if (currentRole == 'parent') {
          return _buildParentView(context, p);
        } else if (currentRole == 'admin' || currentRole == 'superadmin') {
          return _buildAdminView(context, p);
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ProEmptyState(
              icon: Icons.lock_outline_rounded,
              title: loc.accessRestrictedTitle,
              message: loc.sessionPermissionsUnverified,
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 1. TEACHER VIEW
  // ===========================================================================
  Widget _buildTeacherView(BuildContext context, AppPalette p) {
    final loc = AppLocalizations.of(context);
    final assignedHalaqah = AuthSessionService.instance.assignedHalaqahName;

    return StreamBuilder<List<HomeworkAssignment>>(
      stream: HomeworkService.instance.assignmentsStream,
      initialData: HomeworkService.instance.allAssignments,
      builder: (context, _) {
        return StreamBuilder<List<HomeworkSubmission>>(
          stream: HomeworkService.instance.submissionsStream,
          initialData: HomeworkService.instance.allSubmissions,
          builder: (context, subSnap) {
            final assignments = HomeworkService.instance
                .getAssignmentsForHalaqah(assignedHalaqah);
            final allSubmissions =
                subSnap.data ?? HomeworkService.instance.allSubmissions;
            final submissionsByAssignment = <String, List<HomeworkSubmission>>{};
            for (final sub in allSubmissions) {
              (submissionsByAssignment[sub.assignmentId] ??= []).add(sub);
            }
            final halaqahStudentCounts = <String, int>{};

            final filtered = assignments.where((a) {
              if (_teacherFilter == 'active') return !a.isOverdue;
              if (_teacherFilter == 'overdue') return a.isOverdue;
              return true;
            }).toList();

            return RefreshIndicator(
              color: p.primary,
              onRefresh: _handleRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ProHeroCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            loc.tajweedAndRecitationHeader,
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.0,
                                              color: AppColors.goldWarm,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            loc.assignedHomework,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            assignedHalaqah,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  Colors.white.withOpacity(0.78),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _showCreateAssignmentDialog(
                                              context, assignedHalaqah),
                                      icon: const Icon(Icons.add_rounded,
                                          size: 17),
                                      label: Text(loc.assignHomework),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.goldWarm,
                                        foregroundColor:
                                            const Color(0xFF102322),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  loc.assignSurahGoalsHint,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.80),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Filter Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip(p, 'all',
                                    '${loc.all} (${assignments.length})'),
                                const SizedBox(width: 8),
                                _buildFilterChip(p, 'active',
                                    '${loc.activeLabel} (${assignments.where((a) => !a.isOverdue).length})'),
                                const SizedBox(width: 8),
                                _buildFilterChip(p, 'overdue',
                                    '${loc.overdue} (${assignments.where((a) => a.isOverdue).length})'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 124),
                      sliver: SliverToBoxAdapter(
                        child: ProEmptyState(
                          icon: Icons.assignment_outlined,
                          title: loc.noHomeworkFoundTitle,
                          message: loc.tr('noHomeworkForCircleMsg', {
                            'circle': assignedHalaqah,
                            'action': loc.assignHomework,
                          }),
                          actionLabel: loc.assignHomework,
                          onAction: () => _showCreateAssignmentDialog(
                              context, assignedHalaqah),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 124),
                      sliver: SliverList.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final a = filtered[index];
                          final studentCount = halaqahStudentCounts.putIfAbsent(
                            a.halaqahName,
                            () => StudentService.instance
                                .getStudentsForHalaqah(a.halaqahName)
                                .length,
                          );
                          return _buildTeacherAssignmentCard(
                            context,
                            a,
                            p,
                            preindexedSubmissions:
                                submissionsByAssignment[a.id] ?? const [],
                            halaqahStudentCount: studentCount,
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(AppPalette p, String value, String label) {
    final isSelected = _teacherFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _teacherFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? p.primary : p.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? p.primary : p.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? p.onPrimary : p.inkSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherAssignmentCard(
    BuildContext context,
    HomeworkAssignment assignment,
    AppPalette p, {
    List<HomeworkSubmission>? preindexedSubmissions,
    int? halaqahStudentCount,
  }) {
    final loc = AppLocalizations.of(context);
    final submissions = preindexedSubmissions ??
        HomeworkService.instance.getSubmissionsForAssignment(assignment.id);
    final completedCount = submissions.where((s) => s.isCompleted).length;
    final totalCount = submissions.isNotEmpty
        ? submissions.length
        : (halaqahStudentCount ??
            StudentService.instance
                .getStudentsForHalaqah(assignment.halaqahName)
                .length);
    final progressRatio =
        totalCount > 0 ? (completedCount / totalCount).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ProCard(
        onTap: () => _showTeacherInspectionSheet(context, assignment),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    assignment.title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<List<OfflineMutation>>(
                  valueListenable:
                      OfflineSyncService.instance.mutationsNotifier,
                  builder: (context, _, __) {
                    final isPending =
                        OfflineSyncService.instance.isRecordPending(
                      OfflineEntityTypes.homeworkAssignment,
                      assignment.id,
                    );
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPending) ...[
                          Icon(
                            Icons.schedule_rounded,
                            size: 15,
                            color: p.warning,
                          ),
                          const SizedBox(width: 6),
                        ],
                        ProStatusPill(
                          label: assignment.isOverdue
                              ? loc.overdue
                              : loc.activeLabel,
                          color: assignment.isOverdue ? p.danger : p.success,
                          showDot: true,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ProStatusPill(
                  label:
                      '${assignment.surahName} (${assignment.fromAyah}–${assignment.toAyah})',
                  icon: Icons.menu_book_rounded,
                  color: p.primary,
                ),
                ProStatusPill(
                  label: assignment.tajweedFocus,
                  icon: Icons.auto_awesome_rounded,
                  color: p.gold,
                ),
              ],
            ),
            if (assignment.instructions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                assignment.instructions,
                style: TextStyle(
                  fontSize: 12.5,
                  color: p.inkSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loc.tr('practicedAtHomeCount', {
                    'completed': '$completedCount',
                    'total': '$totalCount',
                  }),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      loc.reviewAction,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.primary,
                      ),
                    ),
                    Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      size: 16,
                      color: p.primary,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: progressRatio,
                minHeight: 5,
                backgroundColor: p.surfaceSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(p.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTeacherInspectionSheet(
      BuildContext context, HomeworkAssignment assignment) {
    final p = AppColors.of(context);
    final sheetLoc = AppLocalizations.of(context);
    final classStudents = StudentService.instance
        .getStudentsForHalaqah(assignment.halaqahName);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final loc = AppLocalizations.of(modalCtx);
            final submissions = HomeworkService.instance
                .getSubmissionsForAssignment(assignment.id);
            final submissionsByStudent = <String, HomeworkSubmission>{
              for (final s in submissions) s.studentId: s,
            };

            return ProBottomSheetShell(
              title: assignment.title,
              subtitle: loc.tr('surahAyahRange', {
                'surah': assignment.surahName,
                'from': '${assignment.fromAyah}',
                'to': '${assignment.toAyah}',
              }),
              icon: Icons.fact_check_rounded,
              iconColor: p.primary,
              heightFactor: 0.78,
              child: classStudents.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: ProEmptyState(
                        icon: Icons.people_outline_rounded,
                        title: sheetLoc.noStudentsInHalaqahTitle,
                        message: sheetLoc.noEnrolledStudentsHalaqahMsg,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(18),
                      itemCount: classStudents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final student = classStudents[index];
                        final sub = submissionsByStudent[student.id] ??
                            HomeworkSubmission(
                              id: '',
                              assignmentId: assignment.id,
                              studentId: student.id,
                              studentName: student.fullName,
                              parentId: student.parentId ?? '',
                              status: 'pending',
                            );

                        final statusColor = sub.isReviewed
                            ? p.excused
                            : (sub.isCompleted ? p.success : p.inkMuted);
                        final statusLabel = sub.isReviewed
                            ? loc.reviewedStatus
                            : (sub.isCompleted
                                ? loc.practicedStatus
                                : loc.pending);

                        return ProCard(
                          padding: const EdgeInsets.all(14),
                          backgroundColor: p.canvas,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ProAvatar(
                                    name: student.fullName,
                                    radius: 16,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      student.fullName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: p.ink,
                                      ),
                                    ),
                                  ),
                                  ProStatusPill(
                                    label: statusLabel,
                                    color: statusColor,
                                    showDot: true,
                                  ),
                                ],
                              ),
                              if (sub.isCompleted) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: p.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: p.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        loc.tr('homeRepetitionsLine', {
                                          'count': '${sub.repetitionCount}',
                                        }),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: p.ink,
                                        ),
                                      ),
                                      if (sub.parentNote?.isNotEmpty ==
                                          true) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          loc.tr('parentNoteQuote', {
                                            'note': '${sub.parentNote}',
                                          }),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontStyle: FontStyle.italic,
                                            color: p.inkSecondary,
                                          ),
                                        ),
                                      ],
                                      if (sub.isReviewed) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          loc.tr('ratingFeedbackLine', {
                                            'rating': loc.localizedTajweedRating(
                                                sub.teacherRating ?? ''),
                                            'feedback': sub.teacherFeedback ??
                                                loc.ratingExcellent,
                                          }),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: p.excused,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (!sub.isReviewed) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        _showReviewDialog(context, sub, () {
                                          setModalState(() {});
                                          setState(() {});
                                        });
                                      },
                                      icon: Icon(Icons.star_rounded,
                                          size: 16, color: p.excused),
                                      label: Text(
                                        loc.endorseSubmission,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: p.excused,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: p.excused),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            );
          },
        );
      },
    );
  }

  Future<void> _showReviewDialog(BuildContext context,
      HomeworkSubmission submission, VoidCallback onReviewed) async {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ReviewSubmissionDialog(
        submission: submission,
        palette: p,
      ),
    );
    if (saved != true || !mounted) return;
    onReviewed();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc.tr('submissionEndorsedMsg', {'name': submission.studentName}),
          ),
          backgroundColor: p.excused,
        ),
      );
    }
  }

  Future<void> _showCreateAssignmentDialog(
      BuildContext context, String assignedHalaqah) async {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateAssignmentDialog(
        assignedHalaqah: assignedHalaqah,
        palette: p,
      ),
    );
    if (saved != true || !mounted) return;
    setState(() {});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('homeworkAssignedMsg')),
        ),
      );
    }
  }

  // ===========================================================================
  // 2. PARENT VIEW
  // ===========================================================================
  Widget _buildParentView(BuildContext context, AppPalette p) {
    final loc = AppLocalizations.of(context);
    final children = StudentService.instance.getStudentsForParent(
      AuthSessionService.instance.userId,
      parentEmail: AuthSessionService.instance.userEmail,
    );

    if (children.isEmpty) {
      return RefreshIndicator(
        color: p.primary,
        onRefresh: _handleRefresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            ProEmptyState(
              icon: Icons.assignment_outlined,
              title: loc.noLinkedChildrenTitle,
              message: loc.noLinkedChildrenDesc,
            ),
          ],
        ),
      );
    }

    final safeIndex = _selectedChildIndex.clamp(0, children.length - 1);
    final activeChild = children[safeIndex];

    return StreamBuilder<List<HomeworkAssignment>>(
      stream: HomeworkService.instance.assignmentsStream,
      initialData: HomeworkService.instance.allAssignments,
      builder: (context, _) {
        return StreamBuilder<List<HomeworkSubmission>>(
          stream: HomeworkService.instance.submissionsStream,
          initialData: HomeworkService.instance.allSubmissions,
          builder: (context, subSnap) {
            final loc = AppLocalizations.of(context);
            final assignments = HomeworkService.instance
                .getAssignmentsForStudent(
                  activeChild.id,
                  activeChild.halaqahName,
                );
            final allSubmissions =
                subSnap.data ?? HomeworkService.instance.allSubmissions;
            final childSubmissionsByAssignment =
                <String, HomeworkSubmission>{};
            for (final sub in allSubmissions) {
              if (sub.studentId == activeChild.id) {
                childSubmissionsByAssignment[sub.assignmentId] = sub;
              }
            }

            return RefreshIndicator(
              color: p.primary,
              onRefresh: _handleRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (children.length > 1) ...[
                            SizedBox(
                              height: 40,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: children.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final child = children[index];
                                  final isSelected = index == safeIndex;
                                  return GestureDetector(
                                    onTap: () => setState(
                                        () => _selectedChildIndex = index),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? p.primary
                                            : p.surface,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected
                                              ? p.primary
                                              : p.border,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person_rounded,
                                            size: 15,
                                            color: isSelected
                                                ? p.onPrimary
                                                : p.inkMuted,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            child.fullName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: isSelected
                                                  ? p.onPrimary
                                                  : p.ink,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          ProHeroCard(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                ProAvatar(
                                  name: activeChild.fullName,
                                  radius: 22,
                                  color: AppColors.goldWarm,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        activeChild.fullName,
                                        style: const TextStyle(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        activeChild.halaqahName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              Colors.white.withOpacity(0.78),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    loc.tr('tasksCountBadge',
                                        {'count': '${assignments.length}'}),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                  if (assignments.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 124),
                      sliver: SliverToBoxAdapter(
                        child: ProEmptyState(
                          icon: Icons.menu_book_outlined,
                          title: loc.noHomeworkAssignedTitle,
                          message: loc.tr('ustazNoHomeworkYetMsg', {
                            'name': activeChild.fullName,
                          }),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 124),
                      sliver: SliverList.builder(
                        itemCount: assignments.length,
                        itemBuilder: (context, index) {
                          final a = assignments[index];
                          return _buildParentAssignmentCard(
                            context,
                            a,
                            activeChild,
                            p,
                            preindexedSubmission:
                                childSubmissionsByAssignment[a.id],
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildParentAssignmentCard(
    BuildContext context,
    HomeworkAssignment assignment,
    Student student,
    AppPalette p, {
    HomeworkSubmission? preindexedSubmission,
  }) {
    final loc = AppLocalizations.of(context);
    final sub = preindexedSubmission ??
        HomeworkService.instance.getSubmission(assignment.id, student.id);
    final isDone = sub != null && sub.isCompleted;
    final isReviewed = sub != null && sub.isReviewed;

    final statusColor =
        isReviewed ? p.excused : (isDone ? p.success : p.warning);
    final statusLabel = isReviewed
        ? loc.reviewedStatus
        : (isDone ? loc.practicedStatus : loc.needsPracticeStatus);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ProCard(
        borderColor: isReviewed || isDone
            ? statusColor.withOpacity(0.45)
            : p.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    assignment.title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (sub != null)
                  ValueListenableBuilder<List<OfflineMutation>>(
                    valueListenable:
                        OfflineSyncService.instance.mutationsNotifier,
                    builder: (context, _, __) {
                      final isPending =
                          OfflineSyncService.instance.isRecordPending(
                        OfflineEntityTypes.homeworkSubmission,
                        sub.id,
                      );
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPending) ...[
                            Icon(
                              Icons.schedule_rounded,
                              size: 15,
                              color: p.warning,
                            ),
                            const SizedBox(width: 6),
                          ],
                          ProStatusPill(
                            label: statusLabel,
                            color: statusColor,
                            showDot: true,
                          ),
                        ],
                      );
                    },
                  )
                else
                  ProStatusPill(
                    label: statusLabel,
                    color: statusColor,
                    showDot: true,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ProStatusPill(
                  label:
                      '${assignment.surahName} (${assignment.fromAyah}–${assignment.toAyah})',
                  icon: Icons.menu_book_rounded,
                  color: p.primary,
                ),
                ProStatusPill(
                  label: assignment.tajweedFocus,
                  icon: Icons.auto_awesome_rounded,
                  color: p.gold,
                ),
              ],
            ),
            if (assignment.instructions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                assignment.instructions,
                style: TextStyle(
                  fontSize: 12.5,
                  color: p.inkSecondary,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.event_outlined, size: 14, color: p.inkMuted),
                const SizedBox(width: 5),
                Text(
                  loc.tr('dueDateLabel', {
                    'date': assignment.dueDate.toIso8601String().substring(0, 10),
                  }),
                  style: TextStyle(fontSize: 11.5, color: p.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!isDone)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _showMarkPracticedDialog(context, assignment, student),
                  icon: const Icon(Icons.check_circle_rounded, size: 17),
                  label: Text(loc.practiceAtHome),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 16, color: p.success),
                        const SizedBox(width: 6),
                        Text(
                          loc.tr('completedRepetitionsLine', {
                            'count': '${sub.repetitionCount}',
                          }),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: p.ink,
                          ),
                        ),
                      ],
                    ),
                    if (sub.parentNote?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        loc.tr('yourNoteQuote', {'note': '${sub.parentNote}'}),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: p.inkSecondary,
                        ),
                      ),
                    ],
                    if (isReviewed) ...[
                      const SizedBox(height: 8),
                      Divider(height: 1, color: p.border),
                      const SizedBox(height: 8),
                      Text(
                        loc.tr('ustazGradeLine', {
                          'rating': loc.localizedTajweedRating(
                              sub.teacherRating ?? ''),
                        }),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: p.excused,
                        ),
                      ),
                      if (sub.teacherFeedback?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          loc.tr('feedbackQuote', {
                            'feedback': '${sub.teacherFeedback}',
                          }),
                          style: TextStyle(fontSize: 11.5, color: p.ink),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMarkPracticedDialog(BuildContext context,
      HomeworkAssignment assignment, Student student) async {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _MarkPracticedDialog(
        assignment: assignment,
        student: student,
        palette: p,
      ),
    );
    if (saved != true || !mounted) return;
    setState(() {});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc.tr('markedPracticedMsg', {'name': student.fullName}),
          ),
        ),
      );
    }
  }

  // ===========================================================================
  // 3. ADMIN VIEW
  // ===========================================================================
  Widget _buildAdminView(BuildContext context, AppPalette p) {
    return StreamBuilder<List<HomeworkAssignment>>(
      stream: HomeworkService.instance.assignmentsStream,
      initialData: HomeworkService.instance.allAssignments,
      builder: (context, snapshot) {
        final assignments = snapshot.data ?? [];

        return RefreshIndicator(
          color: p.primary,
          onRefresh: _handleRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProHeroCard(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.menu_book_rounded,
                                  size: 22, color: AppColors.goldWarm),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)
                                        .assignedHomework,
                                    style: const TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppLocalizations.of(context).tr(
                                      'totalAssignmentsMeta',
                                      {'count': '${assignments.length}'},
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.78),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
              if (assignments.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 124),
                  sliver: SliverToBoxAdapter(
                    child: ProEmptyState(
                      icon: Icons.assignment_outlined,
                      title: AppLocalizations.of(context)
                          .noHomeworkRecordedTitle,
                      message: AppLocalizations.of(context)
                          .teachersNoHomeworkYetMsg,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 124),
                  sliver: SliverList.builder(
                    itemCount: assignments.length,
                    itemBuilder: (context, index) {
                      final a = assignments[index];
                      final loc = AppLocalizations.of(context);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ProCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      a.title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: p.ink,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ProStatusPill(
                                      label: a.halaqahName, color: p.primary),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                loc.tr('surahAyahWithTeacher', {
                                  'surah': a.surahName,
                                  'from': '${a.fromAyah}',
                                  'to': '${a.toAyah}',
                                  'teacher': a.teacherName,
                                }),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: p.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReviewSubmissionDialog extends StatefulWidget {
  final HomeworkSubmission submission;
  final AppPalette palette;

  const _ReviewSubmissionDialog({
    required this.submission,
    required this.palette,
  });

  @override
  State<_ReviewSubmissionDialog> createState() =>
      _ReviewSubmissionDialogState();
}

class _ReviewSubmissionDialogState extends State<_ReviewSubmissionDialog> {
  String _selectedRating = 'Mumtaz (ممتاز)';
  final _feedbackCtrl = TextEditingController();
  bool _didInitLocalizedDefaults = false;
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitLocalizedDefaults) {
      _didInitLocalizedDefaults = true;
      _feedbackCtrl.text =
          AppLocalizations.of(context).translate('defaultEndorseFeedback');
    }
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        loc.tr('gradePracticeTitle', {'name': widget.submission.studentName}),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedRating,
            items: [
              DropdownMenuItem(
                value: 'Mumtaz (ممتاز)',
                child: Text(loc.ratingExcellent),
              ),
              DropdownMenuItem(
                value: 'Jayyid Jiddan (جيد جداً)',
                child: Text(loc.ratingVeryGood),
              ),
              DropdownMenuItem(
                value: 'Jayyid (جيد)',
                child: Text(loc.ratingGood),
              ),
              DropdownMenuItem(
                value: 'Needs Revision (يحتاج مراجعة)',
                child: Text(loc.ratingNeedsRevision),
              ),
            ],
            onChanged: _isSubmitting
                ? null
                : (val) {
                    if (val != null) {
                      setState(() => _selectedRating = val);
                    }
                  },
            decoration: InputDecoration(
              labelText: loc.translate('recitationRatingLabel'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _feedbackCtrl,
            enabled: !_isSubmitting,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: loc.translate('ustazFeedbackLabel'),
              hintText: loc.translate('ustazFeedbackHint'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(loc.cancel),
        ),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  try {
                    await HomeworkService.instance.reviewSubmissionByTeacher(
                      submissionId: widget.submission.id,
                      teacherRating: _selectedRating,
                      teacherFeedback: _feedbackCtrl.text.trim(),
                    );
                    if (!mounted) return;
                    Navigator.of(context).pop(true);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          loc.tr('failedEndorseMsg', {
                            'error': SupabaseService.cleanErrorMessage(e),
                          }),
                        ),
                        backgroundColor: p.danger,
                      ),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: p.excused,
            foregroundColor: Colors.white,
          ),
          child: Text(_isSubmitting ? loc.submittingProgress : loc.submitEndorsement),
        ),
      ],
    );
  }
}

class _CreateAssignmentDialog extends StatefulWidget {
  final String assignedHalaqah;
  final AppPalette palette;

  const _CreateAssignmentDialog({
    required this.assignedHalaqah,
    required this.palette,
  });

  @override
  State<_CreateAssignmentDialog> createState() =>
      _CreateAssignmentDialogState();
}

class _CreateAssignmentDialogState extends State<_CreateAssignmentDialog> {
  final _titleCtrl = TextEditingController();
  final _surahNameCtrl = TextEditingController(text: 'Al-Mulk (الملك)');
  final _surahNumCtrl = TextEditingController(text: '67');
  final _fromAyahCtrl = TextEditingController(text: '1');
  final _toAyahCtrl = TextEditingController(text: '10');
  final _tajweedCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 3));
  bool _didInitLocalizedDefaults = false;
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitLocalizedDefaults) {
      _didInitLocalizedDefaults = true;
      final loc = AppLocalizations.of(context);
      _titleCtrl.text = loc.translate('defaultHomeworkTitle');
      _tajweedCtrl.text = loc.translate('defaultTajweedFocus');
      _instructionsCtrl.text = loc.translate('defaultHomeworkInstructions');
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _surahNameCtrl.dispose();
    _surahNumCtrl.dispose();
    _fromAyahCtrl.dispose();
    _toAyahCtrl.dispose();
    _tajweedCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.assignment_add, color: p.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(loc.assignHomework)),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProStatusPill(
                label: loc.tr('circlePrefixLabel', {
                  'circle': widget.assignedHalaqah,
                }),
                color: p.primary,
                icon: Icons.school_rounded,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleCtrl,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  labelText: loc.translate('assignmentTitleLabel'),
                  hintText: loc.translate('assignmentTitleHint'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _surahNameCtrl,
                      enabled: !_isSubmitting,
                      decoration: InputDecoration(
                        labelText: loc.translate('surahNameLabel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _surahNumCtrl,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '#'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fromAyahCtrl,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc.translate('fromAyahLabel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _toAyahCtrl,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc.translate('toAyahLabel'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _tajweedCtrl,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  labelText: loc.translate('tajweedFocusLabel'),
                  hintText: loc.translate('tajweedFocusHint'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _instructionsCtrl,
                enabled: !_isSubmitting,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: loc.translate('instructionsParentsStudentsLabel'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loc.tr('dueDateLabel', {
                      'date': _dueDate.toIso8601String().substring(0, 10),
                    }),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _dueDate,
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 60)),
                            );
                            if (picked != null && mounted) {
                              setState(() => _dueDate = picked);
                            }
                          },
                    icon: const Icon(Icons.calendar_today_rounded, size: 14),
                    label: Text(loc.translate('changeDateAction')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(loc.cancel),
        ),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  if (_titleCtrl.text.trim().isEmpty) return;
                  setState(() => _isSubmitting = true);
                  try {
                    await HomeworkService.instance.createAssignment(
                      halaqahId: AuthSessionService.instance.assignedHalaqahId,
                      halaqahName: widget.assignedHalaqah,
                      teacherId: AuthSessionService.instance.userId,
                      teacherName: AuthSessionService.instance.userName,
                      title: _titleCtrl.text.trim(),
                      surahName: _surahNameCtrl.text.trim(),
                      surahNumber:
                          int.tryParse(_surahNumCtrl.text.trim()) ?? 1,
                      fromAyah: int.tryParse(_fromAyahCtrl.text.trim()) ?? 1,
                      toAyah: int.tryParse(_toAyahCtrl.text.trim()) ?? 7,
                      tajweedFocus: _tajweedCtrl.text.trim(),
                      instructions: _instructionsCtrl.text.trim(),
                      dueDate: _dueDate,
                    );
                    if (!mounted) return;
                    Navigator.of(context).pop(true);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          loc.tr('failedAssignHomeworkMsg', {
                            'error': SupabaseService.cleanErrorMessage(e),
                          }),
                        ),
                        backgroundColor: p.danger,
                      ),
                    );
                  }
                },
          child: Text(
              _isSubmitting ? loc.assigningProgress : loc.assignHomework),
        ),
      ],
    );
  }
}

class _MarkPracticedDialog extends StatefulWidget {
  final HomeworkAssignment assignment;
  final Student student;
  final AppPalette palette;

  const _MarkPracticedDialog({
    required this.assignment,
    required this.student,
    required this.palette,
  });

  @override
  State<_MarkPracticedDialog> createState() => _MarkPracticedDialogState();
}

class _MarkPracticedDialogState extends State<_MarkPracticedDialog> {
  int _repetitionCount = 3;
  final _notesCtrl = TextEditingController();
  bool _didInitLocalizedDefaults = false;
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitLocalizedDefaults) {
      _didInitLocalizedDefaults = true;
      _notesCtrl.text =
          AppLocalizations.of(context).translate('defaultPracticeNote');
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        loc.tr('practiceForStudentTitle', {'name': widget.student.fullName}),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.tr('surahAyahRange', {
              'surah': widget.assignment.surahName,
              'from': '${widget.assignment.fromAyah}',
              'to': '${widget.assignment.toAyah}',
            }),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: p.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            loc.translate('repetitionsQuestion'),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: (!_isSubmitting && _repetitionCount > 1)
                    ? () => setState(() => _repetitionCount--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: p.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  loc.tr('repetitionsCountLabel', {
                    'count': '$_repetitionCount',
                  }),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.primary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() => _repetitionCount++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notesCtrl,
            enabled: !_isSubmitting,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: loc.translate('parentNotesOptionalLabel'),
              hintText: loc.translate('parentNotesHint'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(loc.cancel),
        ),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  try {
                    await HomeworkService.instance.markCompletedByParent(
                      assignmentId: widget.assignment.id,
                      studentId: widget.student.id,
                      repetitionCount: _repetitionCount,
                      notes: _notesCtrl.text.trim(),
                    );
                    if (!mounted) return;
                    Navigator.of(context).pop(true);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          loc.tr('failedSavePracticeMsg', {
                            'error': SupabaseService.cleanErrorMessage(e),
                          }),
                        ),
                        backgroundColor: p.danger,
                      ),
                    );
                  }
                },
          child:
              Text(_isSubmitting ? loc.savingProgress : loc.confirmPractice),
        ),
      ],
    );
  }
}
