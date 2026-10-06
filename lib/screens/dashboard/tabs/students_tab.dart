import 'package:flutter/material.dart';
import '../../../core/models/attendance.dart';
import '../../../core/models/student.dart';
import '../../../core/models/weekly_report.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/student_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../messages/chat_screen.dart';
import '../../payments/payments_screen.dart';

/// Students Tab:
/// - Parents: View multiple children with attendance logs, weekly reports, & direct Ustaz messaging.
/// - Admins: Manage students, assign to parents, record daily attendance, post weekly reports, & suspend/remove unpaid accounts.
class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  int _selectedChildIndex = 0;
  String _searchQuery = '';
  String _selectedHalaqahFilter = 'All';

  bool get _isAdmin {
    final user = SupabaseService.instance.currentUser;
    // Default to admin for center administrative director
    if (user == null || user.email?.toLowerCase() == 'admin@kheyrukum.com') return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.surfaceCard : AppColors.surfaceCardLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    return StreamBuilder<List<Student>>(
      stream: StudentService.instance.studentsStream,
      initialData: StudentService.instance.allStudents,
      builder: (context, snapshot) {
        final students = snapshot.data ?? [];

        if (!_isAdmin) {
          // PARENT VIEW: Shows multiple children assigned to this parent
          final user = SupabaseService.instance.currentUser;
          final children = StudentService.instance.getStudentsForParent(
            user?.id ?? '',
            parentEmail: user?.email,
          );
          return _buildParentView(
            context: context,
            children: children,
            isDark: isDark,
            textColor: textColor,
            subtextColor: subtextColor,
            cardBg: cardBg,
            borderColor: borderColor,
          );
        }

        // ADMIN VIEW: Comprehensive student roster & administrative controls
        return _buildAdminView(
          context: context,
          allStudents: students,
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
  // PARENT VIEW: Multiple Children, Daily Attendance, & Weekly Reports
  // ===========================================================================
  Widget _buildParentView({
    required BuildContext context,
    required List<Student> children,
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color cardBg,
    required Color borderColor,
  }) {
    if (children.isEmpty) {
      return Center(
        child: Text('No children linked yet.', style: TextStyle(color: textColor)),
      );
    }

    final currentChild = children[_selectedChildIndex.clamp(0, children.length - 1)];
    final attendanceHistory = StudentService.instance.getAttendanceForStudent(currentChild.id);
    final weeklyReports = StudentService.instance.getWeeklyReportsForStudent(currentChild.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        // Multi-child switcher if parent has more than 1 student
        if (children.length > 1) ...[
          Text(
            'My Enrolled Children (${children.length})',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: subtextColor),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(children.length, (index) {
                final child = children[index];
                final isSelected = _selectedChildIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => setState(() => _selectedChildIndex = index),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accentTeal.withOpacity(isDark ? 0.25 : 0.15)
                            : cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.accentTeal : borderColor,
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: isSelected ? AppColors.accentTeal : Colors.grey.withOpacity(0.3),
                            child: Text(
                              child.fullName.substring(0, 1),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.black : textColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            child.fullName,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppColors.accentTeal : textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Child Profile Hero Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentChild.fullName,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          currentChild.halaqahName,
                          style: const TextStyle(fontSize: 12, color: AppColors.accentTeal, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: currentChild.monthlyFeeStatus == 'paid'
                          ? AppColors.accentEmerald.withOpacity(0.15)
                          : const Color(0xFFFFA000).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Tuition: ${currentChild.monthlyFeeStatus.toUpperCase()}',
                      style: TextStyle(
                        color: currentChild.monthlyFeeStatus == 'paid'
                            ? AppColors.accentEmerald
                            : const Color(0xFFFFA000),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Memorization Position Progress Bar
              Row(
                children: [
                  _buildStatBadge(
                    label: 'Juz',
                    value: '${currentChild.currentJuz} / 30',
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    label: 'Surah',
                    value: '#${currentChild.currentSurah}',
                    color: const Color(0xFF00BCD4),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    label: 'Ayah',
                    value: '${currentChild.currentAyah}',
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              conversationId: 'convo-teacher-01',
                              conversationTitle: 'Ustaz (${currentChild.halaqahName})',
                              targetRole: 'teacher',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                      label: const Text('Message Ustaz', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accentTeal,
                        side: const BorderSide(color: AppColors.accentTeal),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PaymentsScreen()),
                        );
                      },
                      icon: const Icon(Icons.receipt_long_rounded, size: 15, color: Colors.white),
                      label: const Text('Fee Receipts', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 1. DAILY ATTENDANCE NOTIFICATION HISTORY
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daily Attendance Logs',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentEmerald.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Daily Alerts Active', style: TextStyle(fontSize: 10, color: AppColors.accentEmerald, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (attendanceHistory.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Text('No attendance records logged yet today.', style: TextStyle(color: subtextColor, fontSize: 12)),
          )
        else
          ...attendanceHistory.map((att) => _buildAttendanceCard(att, isDark, cardBg, borderColor, textColor, subtextColor)),

        const SizedBox(height: 20),

        // 2. WEEKLY PROGRESS REPORTS
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Weekly Progress Reports',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Weekly Digest', style: TextStyle(fontSize: 10, color: Color(0xFF00BCD4), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (weeklyReports.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Text('No weekly reports published yet.', style: TextStyle(color: subtextColor, fontSize: 12)),
          )
        else
          ...weeklyReports.map((report) => _buildWeeklyReportCard(report, isDark, cardBg, borderColor, textColor, subtextColor)),
      ],
    );
  }

  // ===========================================================================
  // ADMIN VIEW: Comprehensive Student Roster & Actions
  // ===========================================================================
  Widget _buildAdminView({
    required BuildContext context,
    required List<Student> allStudents,
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color cardBg,
    required Color borderColor,
  }) {
    final filtered = allStudents.where((s) {
      final matchesSearch = s.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.parentName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesHalaqah = _selectedHalaqahFilter == 'All' || s.halaqahName.contains(_selectedHalaqahFilter);
      return matchesSearch && matchesHalaqah;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          // Header & Add Button (placed in header row away from floating nav bar)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student Roster (${allStudents.length})',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Assigned to Parents',
                    style: TextStyle(fontSize: 11, color: subtextColor),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddStudentDialog(context),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Add Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentTeal,
                  foregroundColor: Colors.black,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search Bar
          if (allStudents.isNotEmpty) ...[
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(color: textColor, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search student or parent name...',
                hintStyle: TextStyle(color: subtextColor, fontSize: 12),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: subtextColor),
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: borderColor),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Student Cards List or Empty State
          if (allStudents.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Icon(Icons.school_outlined, size: 48, color: AppColors.accentTeal.withOpacity(0.7)),
                  const SizedBox(height: 14),
                  Text(
                    'No Students Enrolled Yet',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add your students to begin logging daily attendance, recording weekly memorization progress, and managing halaqahs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subtextColor, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () => _showAddStudentDialog(context),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Add First Student', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentTeal,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            )
          else if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('No students matched your search.', style: TextStyle(color: subtextColor)),
              ),
            )
          else
            ...filtered.map((s) => _buildAdminStudentCard(s, isDark, cardBg, borderColor, textColor, subtextColor)),
        ],
      ),
    );
  }

  // Admin Card for a student with 1-click attendance, weekly reports, & messaging
  Widget _buildAdminStudentCard(
    Student student,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtextColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
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
                      student.fullName,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Parent: ${student.parentName} (${student.parentPhone})',
                      style: TextStyle(fontSize: 11.5, color: subtextColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: student.monthlyFeeStatus == 'paid'
                      ? AppColors.accentEmerald.withOpacity(0.15)
                      : (student.monthlyFeeStatus == 'overdue'
                          ? const Color(0xFFEF4444).withOpacity(0.15)
                          : const Color(0xFFFFA000).withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  student.monthlyFeeStatus.toUpperCase(),
                  style: TextStyle(
                    color: student.monthlyFeeStatus == 'paid'
                        ? AppColors.accentEmerald
                        : (student.monthlyFeeStatus == 'overdue'
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFFFA000)),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${student.halaqahName} • Juz ${student.currentJuz}, Surah #${student.currentSurah}, Ayah ${student.currentAyah}',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
          ),
          const Divider(height: 16),
          // Action Buttons: Mark Attendance, Weekly Report, Message Parent (Suspend button removed)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                avatar: const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.accentEmerald),
                label: const Text('Mark Attendance', style: TextStyle(fontSize: 11)),
                onPressed: () => _showMarkAttendanceDialog(context, student),
              ),
              ActionChip(
                avatar: const Icon(Icons.menu_book_rounded, size: 14, color: Color(0xFF00BCD4)),
                label: const Text('Weekly Report', style: TextStyle(fontSize: 11)),
                onPressed: () => _showWeeklyReportDialog(context, student),
              ),
              ActionChip(
                avatar: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFFFFA000)),
                label: const Text('Message Parent', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        conversationId: 'convo-direct-01',
                        conversationTitle: 'Parent: ${student.parentName}',
                        targetRole: 'parent',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Attendance item
  Widget _buildAttendanceCard(
    AttendanceRecord att,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtextColor,
  ) {
    Color pillColor = AppColors.accentEmerald;
    if (att.isAbsent) pillColor = const Color(0xFFEF4444);
    if (att.isLate) pillColor = const Color(0xFFFFA000);
    if (att.isExcused) pillColor = const Color(0xFF8B5CF6);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: pillColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              att.status.toUpperCase(),
              style: TextStyle(color: pillColor, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  att.teacherRemarks ?? 'Attended circle on time',
                  style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  att.date.toIso8601String().substring(0, 10),
                  style: TextStyle(color: subtextColor, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Weekly report item
  Widget _buildWeeklyReportCard(
    WeeklyReport report,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtextColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Week of ${report.weekStartDate.toIso8601String().substring(0, 10)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  report.tajweedRating,
                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 10.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('• Sabaq (New): ${report.sabaq}', style: TextStyle(fontSize: 11.5, color: textColor)),
          Text('• Sabqi (Revision): ${report.sabqi}', style: TextStyle(fontSize: 11.5, color: subtextColor)),
          Text('• Manzil: ${report.manzil}', style: TextStyle(fontSize: 11.5, color: subtextColor)),
          const SizedBox(height: 6),
          Text(
            'Ustaz Remarks: "${report.teacherRemarks}"',
            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.accentTeal),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DIALOGS: Add Student, Mark Attendance, Weekly Report, Suspension
  // ===========================================================================

  void _showAddStudentDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final halaqahCtrl = TextEditingController(text: 'Halaqah Abu Bakr (حلقة أبي بكر)');
    final parentNameCtrl = TextEditingController();
    final parentPhoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Student & Assign Parent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Student Full Name'),
              ),
              TextField(
                controller: halaqahCtrl,
                decoration: const InputDecoration(labelText: 'Halaqah Circle'),
              ),
              TextField(
                controller: parentNameCtrl,
                decoration: const InputDecoration(labelText: 'Parent Full Name'),
              ),
              TextField(
                controller: parentPhoneCtrl,
                decoration: const InputDecoration(labelText: 'Parent Phone Number'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty && parentNameCtrl.text.isNotEmpty) {
                await StudentService.instance.addStudent(
                  fullName: nameCtrl.text.trim(),
                  halaqahName: halaqahCtrl.text.trim(),
                  parentName: parentNameCtrl.text.trim(),
                  parentPhone: parentPhoneCtrl.text.trim(),
                  currentJuz: 30,
                  currentSurah: 1,
                  currentAyah: 1,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Student added and assigned to parent!')),
                );
              }
            },
            child: const Text('Save Student'),
          ),
        ],
      ),
    );
  }

  void _showMarkAttendanceDialog(BuildContext context, Student student) {
    String selectedStatus = 'present';
    final remarksCtrl = TextEditingController(text: 'Attended circle on time.');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Daily Attendance: ${student.fullName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedStatus,
                items: const [
                  DropdownMenuItem(value: 'present', child: Text('Present ✅')),
                  DropdownMenuItem(value: 'late', child: Text('Late ⏰')),
                  DropdownMenuItem(value: 'absent', child: Text('Absent ❌')),
                  DropdownMenuItem(value: 'excused', child: Text('Excused 📝')),
                ],
                onChanged: (val) => setDialogState(() => selectedStatus = val!),
                decoration: const InputDecoration(labelText: 'Attendance Status'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: remarksCtrl,
                decoration: const InputDecoration(labelText: 'Teacher Remarks'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await StudentService.instance.recordDailyAttendance(
                  studentId: student.id,
                  status: selectedStatus,
                  remarks: remarksCtrl.text.trim(),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Attendance recorded! Parent ${student.parentName} notified.')),
                );
              },
              child: const Text('Post & Notify Parent'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWeeklyReportDialog(BuildContext context, Student student) {
    final sabaqCtrl = TextEditingController(text: 'Surah Al-Mulk (1-15)');
    final sabqiCtrl = TextEditingController(text: 'Surah Al-Qalam (1-20)');
    final manzilCtrl = TextEditingController(text: 'Juz 29 Retention');
    final remarksCtrl = TextEditingController(text: 'Consistent Tajweed articulation.');
    String rating = 'Excellent';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Weekly Report: ${student.fullName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: sabaqCtrl, decoration: const InputDecoration(labelText: 'Sabaq (New Lesson)')),
                TextField(controller: sabqiCtrl, decoration: const InputDecoration(labelText: 'Sabqi (Recent Revision)')),
                TextField(controller: manzilCtrl, decoration: const InputDecoration(labelText: 'Manzil (Retention)')),
                DropdownButtonFormField<String>(
                  value: rating,
                  items: const [
                    DropdownMenuItem(value: 'Excellent', child: Text('Excellent 🌟')),
                    DropdownMenuItem(value: 'Very Good', child: Text('Very Good 👍')),
                    DropdownMenuItem(value: 'Good', child: Text('Good 👌')),
                    DropdownMenuItem(value: 'Needs Revision', child: Text('Needs Revision ⚠️')),
                  ],
                  onChanged: (val) => setDialogState(() => rating = val!),
                  decoration: const InputDecoration(labelText: 'Tajweed Evaluation'),
                ),
                TextField(controller: remarksCtrl, decoration: const InputDecoration(labelText: 'Ustaz Evaluation Notes')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await StudentService.instance.submitWeeklyReport(
                  studentId: student.id,
                  sabaq: sabaqCtrl.text.trim(),
                  sabqi: sabqiCtrl.text.trim(),
                  manzil: manzilCtrl.text.trim(),
                  tajweedRating: rating,
                  remarks: remarksCtrl.text.trim(),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Weekly report posted! Parent ${student.parentName} notified.')),
                );
              },
              child: const Text('Submit & Notify Parent'),
            ),
          ],
        ),
      ),
    );
  }
}
