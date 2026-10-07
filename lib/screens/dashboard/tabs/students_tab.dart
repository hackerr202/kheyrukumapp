import 'package:flutter/material.dart';
import '../../../core/models/attendance.dart';
import '../../../core/models/student.dart';
import '../../../core/models/weekly_report.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/services/student_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../messages/chat_screen.dart';
import '../../payments/payments_screen.dart';

/// Students Tab with 3 completely distinct role interfaces:
/// 1. Admin: Comprehensive center roster across halaqahs, student enrollment with parent linking.
/// 2. Teacher: Assigned class roster, daily attendance marking with 1-tap status selector & remarks,
///             direct parent messaging for class students, and weekly Quran reports.
/// 3. Parent: Enrolled children multi-child switcher, attendance history, weekly reports, and Ustaz messaging.
class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  int _selectedChildIndex = 0;
  String _searchQuery = '';
  String _selectedHalaqahFilter = 'All';
  DateTime _teacherSelectedDate = DateTime.now();

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
        return StreamBuilder<List<Student>>(
          stream: StudentService.instance.studentsStream,
          initialData: StudentService.instance.allStudents,
          builder: (context, snapshot) {
            final students = snapshot.data ?? [];

            if (currentRole == 'teacher') {
              return _buildTeacherView(
                context: context,
                allStudents: students,
                isDark: isDark,
                textColor: textColor,
                subtextColor: subtextColor,
                cardBg: cardBg,
                borderColor: borderColor,
              );
            } else if (currentRole == 'parent') {
              final children = StudentService.instance.getStudentsForParent(
                AuthSessionService.instance.userId,
                parentEmail: AuthSessionService.instance.userEmail,
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

            // ADMIN VIEW
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
      },
    );
  }

  // ===========================================================================
  // 1. TEACHER VIEW: Assigned Class Roster, Daily Attendance, & Parent Chat
  // ===========================================================================
  Widget _buildTeacherView({
    required BuildContext context,
    required List<Student> allStudents,
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required Color cardBg,
    required Color borderColor,
  }) {
    final assignedHalaqah = AuthSessionService.instance.assignedHalaqahName;
    final classStudents = StudentService.instance.getStudentsForHalaqah(assignedHalaqah);

    // Calculate attendance metrics for selected date
    int presentCount = 0;
    int lateCount = 0;
    int absentCount = 0;
    int excusedCount = 0;
    int unmarkedCount = 0;

    for (final s in classStudents) {
      final att = StudentService.instance.getTodayAttendanceForStudent(s.id, date: _teacherSelectedDate);
      if (att == null) {
        unmarkedCount++;
      } else if (att.status == 'present') {
        presentCount++;
      } else if (att.status == 'late') {
        lateCount++;
      } else if (att.status == 'absent') {
        absentCount++;
      } else if (att.status == 'excused') {
        excusedCount++;
      }
    }

    final isToday = _teacherSelectedDate.toIso8601String().substring(0, 10) ==
        DateTime.now().toIso8601String().substring(0, 10);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          // Class Header Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accentTeal.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.accentTeal.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.school_rounded, color: AppColors.accentTeal, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assigned Class',
                              style: TextStyle(fontSize: 11, color: subtextColor, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              assignedHalaqah,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${classStudents.length} Students',
                        style: const TextStyle(
                          color: AppColors.accentTeal,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Date Switcher Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _teacherSelectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 90)),
                          lastDate: DateTime.now().add(const Duration(days: 7)),
                        );
                        if (picked != null) {
                          setState(() => _teacherSelectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.accentTeal),
                            const SizedBox(width: 6),
                            Text(
                              isToday
                                  ? 'Today (${_teacherSelectedDate.month}/${_teacherSelectedDate.day})'
                                  : '${_teacherSelectedDate.year}-${_teacherSelectedDate.month.toString().padLeft(2, '0')}-${_teacherSelectedDate.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down_rounded, size: 18, color: subtextColor),
                          ],
                        ),
                      ),
                    ),
                    // "Mark All Present" Action
                    ElevatedButton.icon(
                      onPressed: () async {
                        await StudentService.instance.markHalaqahAllPresent(
                          halaqahName: assignedHalaqah,
                          markedBy: AuthSessionService.instance.userName,
                          date: _teacherSelectedDate,
                        );
                        setState(() {});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('All class students marked Present ✅. Parents notified!'),
                              backgroundColor: AppColors.accentEmerald,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.done_all_rounded, size: 15),
                      label: const Text('Mark All Present', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentEmerald,
                        foregroundColor: Colors.black,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Attendance Summary Counter Bar
                Row(
                  children: [
                    _buildAttCounterChip('Present', '$presentCount', AppColors.accentEmerald, isDark),
                    const SizedBox(width: 6),
                    _buildAttCounterChip('Late', '$lateCount', const Color(0xFFFFA000), isDark),
                    const SizedBox(width: 6),
                    _buildAttCounterChip('Absent', '$absentCount', const Color(0xFFEF4444), isDark),
                    const SizedBox(width: 6),
                    _buildAttCounterChip('Excused', '$excusedCount', const Color(0xFF8B5CF6), isDark),
                    const SizedBox(width: 6),
                    _buildAttCounterChip('Unmarked', '$unmarkedCount', Colors.grey, isDark),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'Class Student Attendance Sheet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Select status for each student. Linked parents receive an automated notification immediately.',
            style: TextStyle(fontSize: 11.5, color: subtextColor),
          ),

          const SizedBox(height: 12),

          if (classStudents.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.people_outline_rounded, size: 40, color: subtextColor),
                    const SizedBox(height: 8),
                    Text(
                      'No students enrolled in your class yet.',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Students assigned to $assignedHalaqah by administration will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: subtextColor, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            )
          else
            ...classStudents.map((s) => _buildTeacherStudentCard(
                  student: s,
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textColor: textColor,
                  subtextColor: subtextColor,
                )),
        ],
      ),
    );
  }

  Widget _buildAttCounterChip(String label, String count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // Teacher Card for a single class student with 1-tap Attendance Selector and Chat button
  Widget _buildTeacherStudentCard({
    required Student student,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    final todayAtt = StudentService.instance.getTodayAttendanceForStudent(
      student.id,
      date: _teacherSelectedDate,
    );
    final currentStatus = todayAtt?.status;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: currentStatus != null
              ? _statusColor(currentStatus).withOpacity(0.4)
              : borderColor,
          width: currentStatus != null ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.accentTeal.withOpacity(0.2),
                    child: Text(
                      student.fullName.isNotEmpty ? student.fullName[0] : 'S',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentTeal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      Text(
                        'Juz ${student.currentJuz} • Surah #${student.currentSurah}, Ayah ${student.currentAyah}',
                        style: TextStyle(fontSize: 11, color: subtextColor),
                      ),
                    ],
                  ),
                ],
              ),
              // Linked Parent pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentAmber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_pin_rounded, size: 12, color: AppColors.accentAmber),
                    const SizedBox(width: 4),
                    Text(
                      student.parentName,
                      style: const TextStyle(
                        color: AppColors.accentAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Daily Attendance 1-Tap Selector Buttons
          Text(
            'Mark Attendance for ${_teacherSelectedDate.month}/${_teacherSelectedDate.day}:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subtextColor),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              _buildAttendanceButton(
                student: student,
                status: 'present',
                label: 'Present',
                icon: Icons.check_circle_rounded,
                color: AppColors.accentEmerald,
                isSelected: currentStatus == 'present',
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _buildAttendanceButton(
                student: student,
                status: 'late',
                label: 'Late',
                icon: Icons.access_time_rounded,
                color: const Color(0xFFFFA000),
                isSelected: currentStatus == 'late',
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _buildAttendanceButton(
                student: student,
                status: 'absent',
                label: 'Absent',
                icon: Icons.cancel_rounded,
                color: const Color(0xFFEF4444),
                isSelected: currentStatus == 'absent',
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _buildAttendanceButton(
                student: student,
                status: 'excused',
                label: 'Excused',
                icon: Icons.note_alt_rounded,
                color: const Color(0xFF8B5CF6),
                isSelected: currentStatus == 'excused',
                isDark: isDark,
              ),
            ],
          ),

          // Teacher Remarks for this student
          if (todayAtt?.teacherRemarks != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.comment_outlined, size: 12, color: AppColors.accentTeal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Note: "${todayAtt!.teacherRemarks}"',
                      style: TextStyle(fontSize: 11, color: textColor, fontStyle: FontStyle.italic),
                    ),
                  ),
                  InkWell(
                    onTap: () => _showEditRemarksDialog(context, student, todayAtt),
                    child: const Icon(Icons.edit_rounded, size: 13, color: AppColors.accentTeal),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 18),

          // Action Buttons: Chat with Parent, Weekly Report, Attendance History
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // CHAT WITH PARENT (CORE REQUIREMENT)
              ElevatedButton.icon(
                onPressed: () async {
                  final convo = await MessagingService.instance.startTeacherChatWithParent(
                    teacherId: AuthSessionService.instance.userId,
                    teacherName: AuthSessionService.instance.userName,
                    parentId: student.parentId ?? 'par-001',
                    parentName: student.parentName,
                    studentName: student.fullName,
                    halaqahId: student.halaqahId,
                  );

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: convo.id,
                          conversationTitle: convo.title,
                          targetRole: 'parent',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.chat_bubble_rounded, size: 14),
                label: const Text(
                  'Chat with Parent',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentAmber,
                  foregroundColor: Colors.black,
                  elevation: 1,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              Row(
                children: [
                  // Weekly Report
                  OutlinedButton.icon(
                    onPressed: () => _showWeeklyReportDialog(context, student),
                    icon: const Icon(Icons.menu_book_rounded, size: 13),
                    label: const Text('Weekly Report', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentTeal,
                      side: const BorderSide(color: AppColors.accentTeal),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // History
                  IconButton(
                    onPressed: () => _showStudentHistoryDialog(context, student),
                    icon: const Icon(Icons.history_rounded, size: 18),
                    color: subtextColor,
                    tooltip: 'Attendance History',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 1-Tap Attendance Button
  Widget _buildAttendanceButton({
    required Student student,
    required String status,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () async {
          await StudentService.instance.recordDailyAttendance(
            studentId: student.id,
            status: status,
            markedBy: AuthSessionService.instance.userName,
            sessionDate: _teacherSelectedDate,
          );
          setState(() {});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${student.fullName} marked ${status.toUpperCase()} ✅. Parent notified!'),
                duration: const Duration(seconds: 2),
                backgroundColor: color,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? color
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.3),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.black : color,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    if (status == 'present') return AppColors.accentEmerald;
    if (status == 'late') return const Color(0xFFFFA000);
    if (status == 'absent') return const Color(0xFFEF4444);
    if (status == 'excused') return const Color(0xFF8B5CF6);
    return Colors.grey;
  }

  // ===========================================================================
  // 2. PARENT VIEW: Multi-child Switcher, Attendance Records & Ustaz Chat
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
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.family_restroom_rounded, size: 48, color: subtextColor),
              const SizedBox(height: 12),
              Text('No Children Linked', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 6),
              Text(
                'When school administration links your child with your parent invitation code or details, they will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: subtextColor, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final currentChild = children[_selectedChildIndex.clamp(0, children.length - 1)];
    final attendanceHistory = StudentService.instance.getAttendanceForStudent(currentChild.id);
    final weeklyReports = StudentService.instance.getWeeklyReportsForStudent(currentChild.id);
    final todayAtt = StudentService.instance.getTodayAttendanceForStudent(currentChild.id);

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

        // Child Details Hero Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
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
                        currentChild.fullName,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentChild.halaqahName,
                        style: TextStyle(fontSize: 12, color: AppColors.accentTeal, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  // Chat with child's Ustaz button
                  ElevatedButton.icon(
                    onPressed: () async {
                      final convo = await MessagingService.instance.startParentChat(
                        parentId: AuthSessionService.instance.userId,
                        parentName: AuthSessionService.instance.userName,
                        targetRole: 'teacher',
                        targetName: 'Ustaz Ibrahim Bilal',
                        halaqahName: currentChild.halaqahName,
                      );

                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              conversationId: convo.id,
                              conversationTitle: convo.title,
                              targetRole: 'teacher',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                    label: const Text('Message Ustaz', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentTeal,
                      foregroundColor: Colors.black,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Memorization Progress Track
              Row(
                children: [
                  _buildStatBadge(
                    label: 'Current Juz',
                    value: 'Juz ${currentChild.currentJuz}',
                    color: AppColors.accentTeal,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    label: 'Surah',
                    value: '#${currentChild.currentSurah}',
                    color: AppColors.accentAmber,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    label: 'Ayah',
                    value: 'Ayah ${currentChild.currentAyah}',
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Today's Attendance Notification Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (todayAtt?.status == 'present' ? AppColors.accentEmerald : const Color(0xFFFFA000)).withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (todayAtt?.status == 'present' ? AppColors.accentEmerald : const Color(0xFFFFA000)).withOpacity(0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                todayAtt?.status == 'present' ? Icons.check_circle_rounded : Icons.schedule_rounded,
                color: todayAtt?.status == 'present' ? AppColors.accentEmerald : const Color(0xFFFFA000),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Attendance: ${(todayAtt?.status ?? 'Unrecorded').toUpperCase()}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: todayAtt?.status == 'present' ? AppColors.accentEmerald : const Color(0xFFFFA000),
                      ),
                    ),
                    Text(
                      todayAtt?.teacherRemarks ?? 'Teacher will record attendance during circle time.',
                      style: TextStyle(fontSize: 11, color: textColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Attendance History Log
        Text('Daily Attendance History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 10),
        if (attendanceHistory.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Text('No attendance recorded yet.', style: TextStyle(color: subtextColor, fontSize: 12)),
          )
        else
          ...attendanceHistory.map((att) => _buildAttendanceCard(att, isDark, cardBg, borderColor, textColor, subtextColor)),

        const SizedBox(height: 20),

        // Weekly Progress Reports
        Text('Weekly Quran Progress Reports', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
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
  // 3. ADMIN VIEW: Full Roster & Student Enrollment with Parent Linking
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
                    'Linked to Specific Parents',
                    style: TextStyle(fontSize: 11, color: subtextColor),
                  ),
                ],
              ),
              // ADMIN ADD STUDENT BUTTON
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (allStudents.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
              child: Column(
                children: [
                  Icon(Icons.school_outlined, size: 48, color: AppColors.accentTeal.withOpacity(0.7)),
                  const SizedBox(height: 14),
                  Text('No Students Enrolled Yet', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(
                    'Add your students and link each one to a specific parent account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subtextColor, fontSize: 12),
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
          else
            ...filtered.map((s) => _buildAdminStudentCard(s, isDark, cardBg, borderColor, textColor, subtextColor)),
        ],
      ),
    );
  }

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
                    Text(student.fullName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 2),
                    Text('Linked Parent: ${student.parentName} (${student.parentPhone})', style: TextStyle(fontSize: 11.5, color: subtextColor)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: student.monthlyFeeStatus == 'paid' ? AppColors.accentEmerald.withOpacity(0.15) : const Color(0xFFFFA000).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  student.monthlyFeeStatus.toUpperCase(),
                  style: TextStyle(
                    color: student.monthlyFeeStatus == 'paid' ? AppColors.accentEmerald : const Color(0xFFFFA000),
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
            style: TextStyle(fontSize: 11, color: subtextColor),
          ),
          const Divider(height: 16),
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
                onPressed: () async {
                  final convo = await MessagingService.instance.startDirectChatWithParent(
                    parentId: student.parentId ?? 'par-001',
                    parentName: student.parentName,
                  );
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: convo.id,
                          conversationTitle: convo.title,
                          targetRole: 'parent',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DIALOG: ADD STUDENT & LINK SPECIFIC PARENT (CORE REQUIREMENT)
  // ===========================================================================
  void _showAddStudentDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String selectedHalaqah = 'Halaqah Abu Bakr (حلقة أبي بكر)';

    // Parent Linking State
    bool linkExistingParent = true;
    final registeredParents = StudentService.instance.getRegisteredParents();
    String selectedParentId = registeredParents.isNotEmpty ? registeredParents.first['id']! : 'par-001';

    final newParentNameCtrl = TextEditingController();
    final newParentPhoneCtrl = TextEditingController();
    final newParentEmailCtrl = TextEditingController();

    int juz = 30;
    int surah = 1;
    int ayah = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.person_add_rounded, color: AppColors.accentTeal),
                SizedBox(width: 8),
                Text('Add Student & Link Parent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Student Full Name *',
                      hintText: 'e.g. Abdur-Rahman Muhammed',
                      prefixIcon: Icon(Icons.face_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: selectedHalaqah,
                    items: const [
                      DropdownMenuItem(
                        value: 'Halaqah Abu Bakr (حلقة أبي بكر)',
                        child: Text('Halaqah Abu Bakr (Ustaz Ibrahim)'),
                      ),
                      DropdownMenuItem(
                        value: 'Halaqah Uthman Ibn Affan (حلقة عثمان)',
                        child: Text('Halaqah Uthman (Ustaz Tariq)'),
                      ),
                    ],
                    onChanged: (val) => setDialogState(() => selectedHalaqah = val!),
                    decoration: const InputDecoration(
                      labelText: 'Assigned Class (Halaqah) *',
                      prefixIcon: Icon(Icons.school_rounded, size: 20),
                    ),
                  ),

                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 6),

                  // SPECIFIC PARENT LINKING SECTION
                  Row(
                    children: [
                      const Icon(Icons.family_restroom_rounded, size: 16, color: AppColors.accentAmber),
                      const SizedBox(width: 6),
                      const Text(
                        'Link to Specific Parent *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accentAmber),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Existing Parent', style: TextStyle(fontSize: 11)),
                          selected: linkExistingParent,
                          onSelected: (val) => setDialogState(() => linkExistingParent = true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('New Parent', style: TextStyle(fontSize: 11)),
                          selected: !linkExistingParent,
                          onSelected: (val) => setDialogState(() => linkExistingParent = false),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  if (linkExistingParent) ...[
                    DropdownButtonFormField<String>(
                      value: selectedParentId,
                      items: registeredParents.map((p) {
                        return DropdownMenuItem<String>(
                          value: p['id'],
                          child: Text(
                            '${p['name']} (${p['phone']})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedParentId = val!),
                      decoration: const InputDecoration(
                        labelText: 'Select Registered Parent',
                        prefixIcon: Icon(Icons.people_rounded, size: 20),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: newParentNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Parent Full Name *',
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newParentPhoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Parent Phone Number *',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newParentEmailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Parent Email (Optional)',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 6),

                  const Text('Initial Quran Milestone:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: '$juz',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Juz (1-30)'),
                          onChanged: (v) => juz = int.tryParse(v) ?? 30,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: '$surah',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Surah (1-114)'),
                          onChanged: (v) => surah = int.tryParse(v) ?? 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter student name.')),
                    );
                    return;
                  }

                  String finalParentId;
                  String finalParentName;
                  String finalParentPhone;
                  String? finalParentEmail;

                  if (linkExistingParent) {
                    final found = registeredParents.firstWhere(
                      (p) => p['id'] == selectedParentId,
                      orElse: () => registeredParents.first,
                    );
                    finalParentId = found['id']!;
                    finalParentName = found['name']!;
                    finalParentPhone = found['phone']!;
                    finalParentEmail = found['email'];
                  } else {
                    if (newParentNameCtrl.text.trim().isEmpty || newParentPhoneCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please complete parent full name and phone number.')),
                      );
                      return;
                    }
                    finalParentId = 'par-${DateTime.now().millisecondsSinceEpoch}';
                    finalParentName = newParentNameCtrl.text.trim();
                    finalParentPhone = newParentPhoneCtrl.text.trim();
                    finalParentEmail = newParentEmailCtrl.text.trim();
                  }

                  await StudentService.instance.addStudent(
                    fullName: nameCtrl.text.trim(),
                    halaqahName: selectedHalaqah,
                    halaqahId: selectedHalaqah.contains('Abu Bakr') ? 'halaqah-001' : 'halaqah-002',
                    parentId: finalParentId,
                    parentName: finalParentName,
                    parentPhone: finalParentPhone,
                    parentEmail: finalParentEmail,
                    currentJuz: juz,
                    currentSurah: surah,
                    currentAyah: ayah,
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Student "${nameCtrl.text.trim()}" enrolled & linked to parent "$finalParentName"!'),
                        backgroundColor: AppColors.accentEmerald,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentTeal,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Enroll & Link', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // Dialog: Edit remarks
  void _showEditRemarksDialog(BuildContext context, Student student, AttendanceRecord att) {
    final remarksCtrl = TextEditingController(text: att.teacherRemarks);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Remarks: ${student.fullName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: remarksCtrl,
          decoration: const InputDecoration(labelText: 'Teacher Remarks / Notes'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await StudentService.instance.recordDailyAttendance(
                studentId: student.id,
                status: att.status,
                remarks: remarksCtrl.text.trim(),
                sessionDate: att.date,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  // Dialog: Student History
  void _showStudentHistoryDialog(BuildContext context, Student student) {
    final history = StudentService.instance.getAttendanceForStudent(student.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceCard : AppColors.surfaceCardLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Attendance Log: ${student.fullName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No attendance recorded yet.'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: history.length,
                  itemBuilder: (ctx, i) => _buildAttendanceCard(
                    history[i],
                    isDark,
                    cardBg,
                    borderColor,
                    textColor,
                    subtextColor,
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // Dialog: Admin single attendance record
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
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Attendance recorded! Parent ${student.parentName} notified.')),
                  );
                }
                setState(() {});
              },
              child: const Text('Post & Notify Parent'),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog: Weekly Report
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
                  teacherName: AuthSessionService.instance.userName,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Weekly report posted! Parent ${student.parentName} notified.')),
                  );
                }
                setState(() {});
              },
              child: const Text('Submit & Notify Parent'),
            ),
          ],
        ),
      ),
    );
  }

  // Attendance card widget
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
            decoration: BoxDecoration(color: pillColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
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
}
