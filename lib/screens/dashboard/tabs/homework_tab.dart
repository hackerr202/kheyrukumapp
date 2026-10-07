import 'package:flutter/material.dart';
import '../../../core/models/homework.dart';
import '../../../core/models/student.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/homework_service.dart';
import '../../../core/services/student_service.dart';
import '../../../core/theme/app_colors.dart';

/// Full Interactive Quran & Tajweed Homework Tab:
/// - Teacher: Create assignments for assigned halaqah, review student practice completions and endorse with Mumtaz.
/// - Parent: Multi-child practice checklist, mark homework completed at home with repetition count and notes.
/// - Admin: Full oversight of assignments across all circles.
class HomeworkTab extends StatefulWidget {
  const HomeworkTab({super.key});

  @override
  State<HomeworkTab> createState() => _HomeworkTabState();
}

class _HomeworkTabState extends State<HomeworkTab> {
  int _selectedChildIndex = 0;
  String _teacherFilter = 'all'; // 'all', 'active', 'overdue'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.surfaceCard : AppColors.surfaceCardLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    return ValueListenableBuilder<String>(
      valueListenable: AuthSessionService.instance.roleNotifier,
      builder: (context, currentRole, _) {
        if (currentRole == 'teacher') {
          return _buildTeacherView(
            context: context,
            isDark: isDark,
            textColor: textColor,
            subtextColor: subtextColor,
            cardBg: cardBg,
            borderColor: borderColor,
          );
        } else if (currentRole == 'parent') {
          return _buildParentView(
            context: context,
            isDark: isDark,
            textColor: textColor,
            subtextColor: subtextColor,
            cardBg: cardBg,
            borderColor: borderColor,
          );
        }

        // Admin View
        return _buildAdminView(
          context: context,
          isDark: isDark,
          textColor: textColor,
          subtextColor: subtextColor,
          cardBg: cardBg,
          borderColor: borderColor,
        );
      },
    );
  }

  // ===========================================================================
  // 1. TEACHER VIEW: Assigned Halaqah Tasks, Creation Modal, & Practice Review
  // ===========================================================================
  Widget _buildTeacherView({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color cardBg,
    required Color borderColor,
  }) {
    final assignedHalaqah = AuthSessionService.instance.assignedHalaqahName;

    return StreamBuilder<List<HomeworkAssignment>>(
      stream: HomeworkService.instance.assignmentsStream,
      initialData: HomeworkService.instance.allAssignments,
      builder: (context, snapshot) {
        final assignments = HomeworkService.instance.getAssignmentsForHalaqah(assignedHalaqah);

        final filtered = assignments.where((a) {
          if (_teacherFilter == 'active') return !a.isOverdue;
          if (_teacherFilter == 'overdue') return a.isOverdue;
          return true;
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            // Top Header: Assigned Circle & "+ Assign Homework" Button
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentTeal.withOpacity(isDark ? 0.2 : 0.12),
                    AppColors.accentTeal.withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accentTeal.withOpacity(0.35)),
              ),
              child: Column(
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
                              color: AppColors.accentTeal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.school_rounded, size: 20, color: AppColors.accentTeal),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Teacher Homework Hub',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                              ),
                              Text(
                                assignedHalaqah,
                                style: TextStyle(fontSize: 11.5, color: subtextColor, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showCreateAssignmentDialog(context, assignedHalaqah),
                        icon: const Icon(Icons.add_rounded, size: 16, color: Colors.black),
                        label: const Text(
                          '+ Assign',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentTeal,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Assign Surah recitation goals and Tajweed rules to your circle. Review when parents mark completion.',
                    style: TextStyle(fontSize: 12, color: subtextColor, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Filter Chips
            Row(
              children: [
                _buildFilterChip('all', 'All (${assignments.length})', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('active', 'Active (${assignments.where((a) => !a.isOverdue).length})', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('overdue', 'Due/Past (${assignments.where((a) => a.isOverdue).length})', isDark),
              ],
            ),

            const SizedBox(height: 16),

            // Assignments List
            if (filtered.isEmpty)
              _buildEmptyState(
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textColor: textColor,
                subtextColor: subtextColor,
                title: 'No Homework Tasks Found',
                message: 'No homework has been assigned for $assignedHalaqah yet. Tap "+ Assign" to give your students their first task.',
                actionText: '+ Assign First Task',
                onAction: () => _showCreateAssignmentDialog(context, assignedHalaqah),
              )
            else
              ...filtered.map((assignment) => _buildTeacherAssignmentCard(
                    context: context,
                    assignment: assignment,
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  )),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String value, String label, bool isDark) {
    final isSelected = _teacherFilter == value;
    return InkWell(
      onTap: () => setState(() => _teacherFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentTeal
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherAssignmentCard({
    required BuildContext context,
    required HomeworkAssignment assignment,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    final submissions = HomeworkService.instance.getSubmissionsForAssignment(assignment.id);
    final completedCount = submissions.where((s) => s.isCompleted).length;
    final totalCount = submissions.isNotEmpty
        ? submissions.length
        : StudentService.instance.getStudentsForHalaqah(assignment.halaqahName).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showTeacherInspectionSheet(context, assignment),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      assignment.title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: assignment.isOverdue
                          ? const Color(0xFFEF4444).withOpacity(0.15)
                          : const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      assignment.isOverdue ? 'Due Date Passed' : 'Active Task',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: assignment.isOverdue ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Surah & Ayah span badge + Tajweed Rule Focus
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '📖 ${assignment.surahName} (Ayahs ${assignment.fromAyah}–${assignment.toAyah})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentTeal),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA000).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '✨ ${assignment.tajweedFocus}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFFFA000)),
                    ),
                  ),
                ],
              ),

              if (assignment.instructions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  assignment.instructions,
                  style: TextStyle(fontSize: 12, color: subtextColor, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),
              Divider(height: 1, color: borderColor),
              const SizedBox(height: 10),

              // Submission Progress + Due Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 14, color: subtextColor),
                      const SizedBox(width: 4),
                      Text(
                        '$completedCount of $totalCount Practiced at Home',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Review Submissions',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.accentTeal),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.accentTeal),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Teacher Inspection Bottom Sheet: Lists student practice completions & rating action
  void _showTeacherInspectionSheet(BuildContext context, HomeworkAssignment assignment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    final classStudents = StudentService.instance.getStudentsForHalaqah(assignment.halaqahName);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final submissions = HomeworkService.instance.getSubmissionsForAssignment(assignment.id);

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.78,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              assignment.title,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            Text(
                              '${assignment.surahName} (Ayahs ${assignment.fromAyah}–${assignment.toAyah})',
                              style: const TextStyle(fontSize: 12, color: AppColors.accentTeal, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 20, color: subtextColor),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: borderColor),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(18),
                      itemCount: classStudents.length,
                      itemBuilder: (context, index) {
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

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: sub.isCompleted
                                            ? const Color(0xFF10B981).withOpacity(0.2)
                                            : Colors.grey.withOpacity(0.2),
                                        child: Text(
                                          student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : 'S',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: sub.isCompleted ? const Color(0xFF10B981) : subtextColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        student.fullName,
                                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textColor),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: sub.isReviewed
                                          ? const Color(0xFF8B5CF6).withOpacity(0.15)
                                          : (sub.isCompleted
                                              ? const Color(0xFF10B981).withOpacity(0.15)
                                              : Colors.grey.withOpacity(0.15)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      sub.isReviewed
                                          ? 'Reviewed 🌟'
                                          : (sub.isCompleted ? 'Practiced at Home ✅' : 'Pending Practice ⏳'),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: sub.isReviewed
                                            ? const Color(0xFF8B5CF6)
                                            : (sub.isCompleted ? const Color(0xFF10B981) : subtextColor),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (sub.isCompleted) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Home Repetitions: ${sub.repetitionCount}x recited with parent',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor),
                                      ),
                                      if (sub.parentNote?.isNotEmpty == true) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Parent Note: "${sub.parentNote}"',
                                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: subtextColor),
                                        ),
                                      ],
                                      if (sub.isReviewed) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Rating: ${sub.teacherRating} • Feedback: "${sub.teacherFeedback ?? "Excellent"}"',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (!sub.isReviewed) ...[
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        _showReviewDialog(context, sub, () {
                                          setModalState(() {});
                                          setState(() {});
                                        });
                                      },
                                      icon: const Icon(Icons.star_rounded, size: 15, color: Color(0xFF8B5CF6)),
                                      label: const Text(
                                        'Endorse & Grade (Mumtaz / Feedback)',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFF8B5CF6)),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Teacher Review & Endorse Dialog
  void _showReviewDialog(BuildContext context, HomeworkSubmission submission, VoidCallback onReviewed) {
    String selectedRating = 'Mumtaz (ممتاز)';
    final feedbackCtrl = TextEditingController(text: 'Masha\'Allah excellent recitation with clear Tajweed.');

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDialogState) {
            return AlertDialog(
              title: Text('Grade ${submission.studentName}\'s Practice', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Recitation Rating:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedRating,
                    items: const [
                      DropdownMenuItem(value: 'Mumtaz (ممتاز)', child: Text('Mumtaz (ممتاز) - Excellent 🌟')),
                      DropdownMenuItem(value: 'Jayyid Jiddan (جيد جداً)', child: Text('Jayyid Jiddan (جيد جداً) - Very Good 👍')),
                      DropdownMenuItem(value: 'Jayyid (جيد)', child: Text('Jayyid (جيد) - Good')),
                      DropdownMenuItem(value: 'Needs Revision (يحتاج مراجعة)', child: Text('Needs Revision (يحتاج مراجعة)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedRating = val);
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Ustaz Feedback / Advice:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: feedbackCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Enter guidance for parent and student...',
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                    Navigator.of(ctx).pop();
                    onReviewed();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Submission endorsed for ${submission.studentName}!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
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

  // Teacher Create Homework Assignment Dialog
  void _showCreateAssignmentDialog(BuildContext context, String assignedHalaqah) {
    final titleCtrl = TextEditingController(text: 'Surah Memorization & Tajweed');
    final surahNameCtrl = TextEditingController(text: 'Al-Mulk (الملك)');
    final surahNumCtrl = TextEditingController(text: '67');
    final fromAyahCtrl = TextEditingController(text: '1');
    final toAyahCtrl = TextEditingController(text: '10');
    final tajweedCtrl = TextEditingController(text: 'Ghunnah & Ikhfa Rules');
    final instructionsCtrl = TextEditingController(
      text: 'Recite each verse at least 3 times focusing on correct elongation and nasalization.',
    );
    DateTime dueDate = DateTime.now().add(const Duration(days: 3));

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.assignment_add, color: AppColors.accentTeal, size: 22),
                  const SizedBox(width: 8),
                  const Text('Assign Quran Homework', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assigned Halaqah: $assignedHalaqah', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentTeal)),
                      const SizedBox(height: 12),
                      const Text('Assignment Title:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. Surah Al-Mulk Practice',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Surah Name:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: surahNameCtrl,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Surah #:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: surahNumCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('From Ayah:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: fromAyahCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('To Ayah:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: toAyahCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text('Tajweed Rule Focus:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: tajweedCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. Qalqalah, Ghunnah, Madd',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text('Instructions for Parents & Students:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: instructionsCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.all(10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Due Date: ${dueDate.toIso8601String().substring(0, 10)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dueDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 60)),
                              );
                              if (picked != null) {
                                setDialogState(() => dueDate = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_today_rounded, size: 14),
                            label: const Text('Change Date', style: TextStyle(fontSize: 11.5)),
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
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Homework assigned successfully!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: Colors.black,
                  ),
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
  // 2. PARENT VIEW: Multi-child Homework Checklist & "Mark Completed" Action
  // ===========================================================================
  Widget _buildParentView({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color cardBg,
    required Color borderColor,
  }) {
    final children = StudentService.instance.getStudentsForParent(
      AuthSessionService.instance.userId,
      parentEmail: AuthSessionService.instance.userEmail,
    );

    if (children.isEmpty) {
      return _buildEmptyState(
        isDark: isDark,
        cardBg: cardBg,
        borderColor: borderColor,
        textColor: textColor,
        subtextColor: subtextColor,
        title: 'No Linked Children',
        message: 'No children are currently linked to your parent account. Please contact the center administrator to enroll your children.',
      );
    }

    final safeIndex = _selectedChildIndex.clamp(0, children.length - 1);
    final activeChild = children[safeIndex];

    return StreamBuilder<List<HomeworkAssignment>>(
      stream: HomeworkService.instance.assignmentsStream,
      initialData: HomeworkService.instance.allAssignments,
      builder: (context, snapshot) {
        final assignments = HomeworkService.instance.getAssignmentsForStudent(
          activeChild.id,
          activeChild.halaqahName,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            // Multi-Child Switcher Banner (if parent has multiple children)
            if (children.length > 1) ...[
              Container(
                height: 44,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: children.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final child = children[index];
                    final isSelected = index == safeIndex;
                    return InkWell(
                      onTap: () => setState(() => _selectedChildIndex = index),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentTeal
                              : (isDark ? const Color(0xFF1E293B) : Colors.white),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppColors.accentTeal : borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 15,
                              color: isSelected ? Colors.black : subtextColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              child.fullName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.black : textColor,
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

            // Active Child Info Header
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.accentTeal.withOpacity(0.15),
                    child: Text(
                      activeChild.fullName.isNotEmpty ? activeChild.fullName[0].toUpperCase() : 'C',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentTeal),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeChild.fullName,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        Text(
                          activeChild.halaqahName,
                          style: TextStyle(fontSize: 11.5, color: subtextColor),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${assignments.length} Tasks',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentTeal),
                    ),
                  ),
                ],
              ),
            ),

            if (assignments.isEmpty)
              _buildEmptyState(
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textColor: textColor,
                subtextColor: subtextColor,
                title: 'No Homework Tasks Assigned',
                message: 'Ustaz has not posted any homework tasks for ${activeChild.fullName}\'s circle yet. Check back after the next Quran session.',
              )
            else
              ...assignments.map((assignment) => _buildParentAssignmentCard(
                    context: context,
                    assignment: assignment,
                    student: activeChild,
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  )),
          ],
        );
      },
    );
  }

  Widget _buildParentAssignmentCard({
    required BuildContext context,
    required HomeworkAssignment assignment,
    required Student student,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    final sub = HomeworkService.instance.getSubmission(assignment.id, student.id);
    final isDone = sub != null && sub.isCompleted;
    final isReviewed = sub != null && sub.isReviewed;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isReviewed
              ? const Color(0xFF8B5CF6).withOpacity(0.6)
              : (isDone ? const Color(0xFF10B981).withOpacity(0.6) : borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  assignment.title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isReviewed
                      ? const Color(0xFF8B5CF6).withOpacity(0.15)
                      : (isDone ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFFFA000).withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isReviewed
                      ? 'Reviewed 🌟'
                      : (isDone ? 'Practiced at Home ✅' : 'Needs Practice ⏳'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isReviewed
                        ? const Color(0xFF8B5CF6)
                        : (isDone ? const Color(0xFF10B981) : const Color(0xFFFFA000)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '📖 ${assignment.surahName} (Ayahs ${assignment.fromAyah}–${assignment.toAyah})',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentTeal),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA000).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '✨ ${assignment.tajweedFocus}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFFFA000)),
                ),
              ),
            ],
          ),

          if (assignment.instructions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              assignment.instructions,
              style: TextStyle(fontSize: 12, color: subtextColor, height: 1.3),
            ),
          ],

          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 14, color: subtextColor),
              const SizedBox(width: 4),
              Text(
                'Due Date: ${assignment.dueDate.toIso8601String().substring(0, 10)}',
                style: TextStyle(fontSize: 11.5, color: subtextColor),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Action: Mark Practiced at Home or show review result
          if (!isDone) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showMarkPracticedDialog(context, assignment, student),
                icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.black),
                label: const Text(
                  'Mark Practiced at Home',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentTeal,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        'Completed: ${sub.repetitionCount}x recited with parent',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor),
                      ),
                    ],
                  ),
                  if (sub.parentNote?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Your Note: "${sub.parentNote}"',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: subtextColor),
                    ),
                  ],
                  if (isReviewed) ...[
                    const SizedBox(height: 6),
                    Divider(height: 1, color: borderColor),
                    const SizedBox(height: 6),
                    Text(
                      'Ustaz Grade: ${sub.teacherRating} 🌟',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                    ),
                    if (sub.teacherFeedback?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Feedback: "${sub.teacherFeedback}"',
                        style: TextStyle(fontSize: 11, color: textColor),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Parent "Mark Practiced at Home" modal
  void _showMarkPracticedDialog(BuildContext context, HomeworkAssignment assignment, Student student) {
    int repetitionCount = 3;
    final notesCtrl = TextEditingController(text: 'Recited smoothly with parent.');

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Practice for ${student.fullName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${assignment.surahName} (Ayahs ${assignment.fromAyah}–${assignment.toAyah})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentTeal)),
                  const SizedBox(height: 12),
                  const Text('How many times did your child recite at home?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accentTeal.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$repetitionCount Repetitions',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.accentTeal),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setDialogState(() => repetitionCount++),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Parent Notes / Difficulties (Optional):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'e.g. Read smoothly, struggled on Ayah 7...',
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                    Navigator.of(ctx).pop();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Marked practiced for ${student.fullName}! Ustaz notified.')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: Colors.black,
                  ),
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
  // 3. ADMIN VIEW: Center-wide Homework Oversight
  // ===========================================================================
  Widget _buildAdminView({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color cardBg,
    required Color borderColor,
  }) {
    return StreamBuilder<List<HomeworkAssignment>>(
      stream: HomeworkService.instance.assignmentsStream,
      initialData: HomeworkService.instance.allAssignments,
      builder: (context, snapshot) {
        final assignments = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4B72).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_rounded, size: 20, color: Color(0xFFFF4B72)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Center Homework Oversight', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                        Text('${assignments.length} Total Assignments across circles', style: TextStyle(fontSize: 11.5, color: subtextColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (assignments.isEmpty)
              _buildEmptyState(
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                textColor: textColor,
                subtextColor: subtextColor,
                title: 'No Homework Tasks Recorded',
                message: 'Teachers have not created any homework tasks across any halaqah circles yet.',
              )
            else
              ...assignments.map((a) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(a.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                            Text(a.halaqahName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentTeal)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('📖 ${a.surahName} (Ayahs ${a.fromAyah}–${a.toAyah}) • Ustaz: ${a.teacherName}', style: TextStyle(fontSize: 11.5, color: subtextColor)),
                      ],
                    ),
                  )),
          ],
        );
      },
    );
  }

  // Clean Production Empty State
  Widget _buildEmptyState({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: AppColors.accentAmber.withOpacity(0.7)),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: subtextColor, fontSize: 12.5, height: 1.5)),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentTeal,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(actionText, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}
