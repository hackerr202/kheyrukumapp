import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/models/homework.dart';
import '../../../core/models/student.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/homework_service.dart';
import '../../../core/services/student_service.dart';
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
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: ProEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Access Restricted',
              message: 'Your session permissions could not be verified.',
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
    final assignedHalaqah = AuthSessionService.instance.assignedHalaqahName;

    return StreamBuilder<List<HomeworkAssignment>>(
      stream: HomeworkService.instance.assignmentsStream,
      initialData: HomeworkService.instance.allAssignments,
      builder: (context, _) {
        final assignments =
            HomeworkService.instance.getAssignmentsForHalaqah(assignedHalaqah);

        final filtered = assignments.where((a) {
          if (_teacherFilter == 'active') return !a.isOverdue;
          if (_teacherFilter == 'overdue') return a.isOverdue;
          return true;
        }).toList();

        return RefreshIndicator(
          color: p.primary,
          onRefresh: _handleRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 124),
            children: [
              ProHeroCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TAJWEED & RECITATION',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: AppColors.goldWarm,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Teacher Homework Hub',
                                style: TextStyle(
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
                                  color: Colors.white.withOpacity(0.78),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showCreateAssignmentDialog(
                              context, assignedHalaqah),
                          icon: const Icon(Icons.add_rounded, size: 17),
                          label: const Text('Assign'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.goldWarm,
                            foregroundColor: const Color(0xFF102322),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Assign Surah goals and Tajweed rules to your circle. Review submissions when parents log home practice.',
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
                    _buildFilterChip(
                        p, 'all', 'All (${assignments.length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                        p,
                        'active',
                        'Active (${assignments.where((a) => !a.isOverdue).length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                        p,
                        'overdue',
                        'Past Due (${assignments.where((a) => a.isOverdue).length})'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (filtered.isEmpty)
                ProEmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No Homework Tasks Found',
                  message:
                      'No homework has been assigned for $assignedHalaqah yet. Tap "Assign" to give your students their first recitation goal.',
                  actionLabel: 'Assign First Task',
                  onAction: () =>
                      _showCreateAssignmentDialog(context, assignedHalaqah),
                )
              else
                ...filtered.map(
                    (a) => _buildTeacherAssignmentCard(context, a, p)),
            ],
          ),
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
    AppPalette p,
  ) {
    final submissions =
        HomeworkService.instance.getSubmissionsForAssignment(assignment.id);
    final completedCount = submissions.where((s) => s.isCompleted).length;
    final totalCount = submissions.isNotEmpty
        ? submissions.length
        : StudentService.instance
            .getStudentsForHalaqah(assignment.halaqahName)
            .length;
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
                ProStatusPill(
                  label: assignment.isOverdue ? 'Past Due' : 'Active',
                  color: assignment.isOverdue ? p.danger : p.success,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$completedCount of $totalCount Practiced at Home',
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
                      'Review',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.primary,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 16, color: p.primary),
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
    final classStudents = StudentService.instance
        .getStudentsForHalaqah(assignment.halaqahName);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final submissions = HomeworkService.instance
                .getSubmissionsForAssignment(assignment.id);

            return ProBottomSheetShell(
              title: assignment.title,
              subtitle:
                  '${assignment.surahName} (Ayahs ${assignment.fromAyah}–${assignment.toAyah})',
              icon: Icons.fact_check_rounded,
              iconColor: p.primary,
              heightFactor: 0.78,
              child: classStudents.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: ProEmptyState(
                        icon: Icons.people_outline_rounded,
                        title: 'No students in circle',
                        message:
                            'No enrolled students found for this halaqah.',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(18),
                      itemCount: classStudents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final student = classStudents[index];
                        final sub = submissions.firstWhere(
                          (s) => s.studentId == student.id,
                          orElse: () => HomeworkSubmission(
                            id: '',
                            assignmentId: assignment.id,
                            studentId: student.id,
                            studentName: student.fullName,
                            parentId: student.parentId ?? '',
                            status: 'pending',
                          ),
                        );

                        final statusColor = sub.isReviewed
                            ? p.excused
                            : (sub.isCompleted ? p.success : p.inkMuted);
                        final statusLabel = sub.isReviewed
                            ? 'Reviewed'
                            : (sub.isCompleted ? 'Practiced' : 'Pending');

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
                                        'Home Repetitions: ${sub.repetitionCount}x recited with parent',
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
                                          'Parent Note: "${sub.parentNote}"',
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
                                          'Rating: ${sub.teacherRating} • "${sub.teacherFeedback ?? "Excellent"}"',
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
                                        'Endorse & Grade',
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

  void _showReviewDialog(BuildContext context, HomeworkSubmission submission,
      VoidCallback onReviewed) {
    final p = AppColors.of(context);
    String selectedRating = 'Mumtaz (ممتاز)';
    final feedbackCtrl = TextEditingController(
        text: 'Masha\'Allah excellent recitation with clear Tajweed.');

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDialogState) {
            return AlertDialog(
              title: Text('Grade ${submission.studentName}\'s Practice'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedRating,
                    items: const [
                      DropdownMenuItem(
                        value: 'Mumtaz (ممتاز)',
                        child: Text('Mumtaz (ممتاز) — Excellent'),
                      ),
                      DropdownMenuItem(
                        value: 'Jayyid Jiddan (جيد جداً)',
                        child: Text('Jayyid Jiddan (جيد جداً) — Very Good'),
                      ),
                      DropdownMenuItem(
                        value: 'Jayyid (جيد)',
                        child: Text('Jayyid (جيد) — Good'),
                      ),
                      DropdownMenuItem(
                        value: 'Needs Revision (يحتاج مراجعة)',
                        child: Text('Needs Revision (يحتاج مراجعة)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedRating = val);
                      }
                    },
                    decoration:
                        const InputDecoration(labelText: 'Recitation Rating'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: feedbackCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Ustaz Feedback / Advice',
                      hintText: 'Enter guidance for parent and student...',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await HomeworkService.instance.reviewSubmissionByTeacher(
                      submissionId: submission.id,
                      teacherRating: selectedRating,
                      teacherFeedback: feedbackCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    onReviewed();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Submission endorsed for ${submission.studentName}.'),
                          backgroundColor: p.excused,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.excused,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit Endorsement'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateAssignmentDialog(
      BuildContext context, String assignedHalaqah) {
    final p = AppColors.of(context);
    final titleCtrl =
        TextEditingController(text: 'Surah Memorization & Tajweed');
    final surahNameCtrl = TextEditingController(text: 'Al-Mulk (الملك)');
    final surahNumCtrl = TextEditingController(text: '67');
    final fromAyahCtrl = TextEditingController(text: '1');
    final toAyahCtrl = TextEditingController(text: '10');
    final tajweedCtrl = TextEditingController(text: 'Ghunnah & Ikhfa Rules');
    final instructionsCtrl = TextEditingController(
      text:
          'Recite each verse at least 3 times focusing on correct elongation and nasalization.',
    );
    DateTime dueDate = DateTime.now().add(const Duration(days: 3));

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.assignment_add, color: p.primary, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Assign Quran Homework')),
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
                        label: 'Circle: $assignedHalaqah',
                        color: p.primary,
                        icon: Icons.school_rounded,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Assignment Title',
                          hintText: 'e.g. Surah Al-Mulk Practice',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: surahNameCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Surah Name'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: surahNumCtrl,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: '#'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: fromAyahCtrl,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: 'From Ayah'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: toAyahCtrl,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: 'To Ayah'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: tajweedCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tajweed Rule Focus',
                          hintText: 'e.g. Qalqalah, Ghunnah, Madd',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: instructionsCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Instructions for Parents & Students',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Due: ${dueDate.toIso8601String().substring(0, 10)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dueDate,
                                firstDate: DateTime.now(),
                                lastDate:
                                    DateTime.now().add(const Duration(days: 60)),
                              );
                              if (picked != null) {
                                setDialogState(() => dueDate = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_today_rounded,
                                size: 14),
                            label: const Text('Change Date'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    await HomeworkService.instance.createAssignment(
                      halaqahId: AuthSessionService.instance.assignedHalaqahId,
                      halaqahName: assignedHalaqah,
                      teacherId: AuthSessionService.instance.userId,
                      teacherName: AuthSessionService.instance.userName,
                      title: titleCtrl.text.trim(),
                      surahName: surahNameCtrl.text.trim(),
                      surahNumber: int.tryParse(surahNumCtrl.text.trim()) ?? 1,
                      fromAyah: int.tryParse(fromAyahCtrl.text.trim()) ?? 1,
                      toAyah: int.tryParse(toAyahCtrl.text.trim()) ?? 7,
                      tajweedFocus: tajweedCtrl.text.trim(),
                      instructions: instructionsCtrl.text.trim(),
                      dueDate: dueDate,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Homework assigned successfully.'),
                        ),
                      );
                    }
                  },
                  child: const Text('Assign Task'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // 2. PARENT VIEW
  // ===========================================================================
  Widget _buildParentView(BuildContext context, AppPalette p) {
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
          children: const [
            SizedBox(height: 40),
            ProEmptyState(
              icon: Icons.assignment_outlined,
              title: 'No Linked Children',
              message:
                  'No children are currently linked to your parent account. Contact center administration to enroll your children.',
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
        final assignments = HomeworkService.instance.getAssignmentsForStudent(
          activeChild.id,
          activeChild.halaqahName,
        );

        return RefreshIndicator(
          color: p.primary,
          onRefresh: _handleRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 124),
            children: [
              if (children.length > 1) ...[
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: children.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final child = children[index];
                      final isSelected = index == safeIndex;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedChildIndex = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? p.primary : p.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? p.primary : p.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 15,
                                color: isSelected ? p.onPrimary : p.inkMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                child.fullName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? p.onPrimary : p.ink,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              color: Colors.white.withOpacity(0.78),
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
                        '${assignments.length} Tasks',
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

              if (assignments.isEmpty)
                ProEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No Homework Tasks Assigned',
                  message:
                      'Ustaz has not posted any homework tasks for ${activeChild.fullName}\'s circle yet.',
                )
              else
                ...assignments.map(
                    (a) => _buildParentAssignmentCard(context, a, activeChild, p)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParentAssignmentCard(
    BuildContext context,
    HomeworkAssignment assignment,
    Student student,
    AppPalette p,
  ) {
    final sub = HomeworkService.instance.getSubmission(assignment.id, student.id);
    final isDone = sub != null && sub.isCompleted;
    final isReviewed = sub != null && sub.isReviewed;

    final statusColor =
        isReviewed ? p.excused : (isDone ? p.success : p.warning);
    final statusLabel =
        isReviewed ? 'Reviewed' : (isDone ? 'Practiced' : 'Needs Practice');

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
                  'Due: ${assignment.dueDate.toIso8601String().substring(0, 10)}',
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
                  label: const Text('Mark Practiced at Home'),
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
                          'Completed: ${sub.repetitionCount}x recited at home',
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
                        'Your Note: "${sub.parentNote}"',
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
                        'Ustaz Grade: ${sub.teacherRating}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: p.excused,
                        ),
                      ),
                      if (sub.teacherFeedback?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Feedback: "${sub.teacherFeedback}"',
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

  void _showMarkPracticedDialog(
      BuildContext context, HomeworkAssignment assignment, Student student) {
    final p = AppColors.of(context);
    int repetitionCount = 3;
    final notesCtrl =
        TextEditingController(text: 'Recited smoothly with parent.');

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDialogState) {
            return AlertDialog(
              title: Text('Practice for ${student.fullName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${assignment.surahName} (Ayahs ${assignment.fromAyah}–${assignment.toAyah})',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: p.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'How many times did your child recite at home?',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: repetitionCount > 1
                            ? () => setDialogState(() => repetitionCount--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: p.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$repetitionCount Repetitions',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: p.primary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setDialogState(() => repetitionCount++),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Parent Notes (Optional)',
                      hintText: 'e.g. Read smoothly, struggled on Ayah 7...',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await HomeworkService.instance.markCompletedByParent(
                      assignmentId: assignment.id,
                      studentId: student.id,
                      repetitionCount: repetitionCount,
                      notes: notesCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (!mounted) return;
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Marked practiced for ${student.fullName}. Ustaz notified.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Confirm Practice'),
                ),
              ],
            );
          },
        );
      },
    );
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
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 124),
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
                          const Text(
                            'Center Homework Oversight',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${assignments.length} total assignments across study circles',
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
              if (assignments.isEmpty)
                const ProEmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No Homework Tasks Recorded',
                  message:
                      'Teachers have not created any homework tasks across any study circles yet.',
                )
              else
                ...assignments.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ProCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            '${a.surahName} (Ayahs ${a.fromAyah}–${a.toAyah}) • Ustaz: ${a.teacherName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: p.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
