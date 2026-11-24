import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/absence_request.dart';
import '../../../core/models/attendance.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/student.dart';
import '../../../core/models/weekly_report.dart';
import '../../../core/services/absence_service.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/halaqah_service.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/student_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/add_student_dialog.dart';
import '../../../widgets/pro_ui_kit.dart';
import '../../messages/chat_screen.dart';

/// Students Tab with 3 role-specific interfaces:
/// 1. Admin: Center roster across circles, Halaqah filters, enrollment with parent linking, removal.
/// 2. Teacher: Assigned circle roster, 1-tap attendance marking, excuse approvals, parent chat, weekly reports.
/// 3. Parent: Multi-child switcher, Juz progress tracker, attendance history, excuse submission, weekly reports.
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

  Future<void> _handleRefresh() async {
    await Future.wait([
      HalaqahService.instance.fetchHalaqahs(),
      StudentService.instance.refreshAll(),
      AbsenceService.instance.refreshAll(),
      PaymentService.instance.refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: AuthSessionService.instance.roleNotifier,
      builder: (context, currentRole, _) {
        return StreamBuilder<List<Student>>(
          stream: StudentService.instance.studentsStream,
          initialData: StudentService.instance.allStudents,
          builder: (context, snapshot) {
            final students = snapshot.data ?? [];

            if (currentRole == 'teacher') {
              return _buildTeacherView(context, p);
            } else if (currentRole == 'parent') {
              final children = StudentService.instance.getStudentsForParent(
                AuthSessionService.instance.userId,
                parentEmail: AuthSessionService.instance.userEmail,
              );
              return _buildParentView(context, children, p);
            } else if (currentRole == 'admin' || currentRole == 'superadmin') {
              return _buildAdminView(context, students, p);
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
      },
    );
  }

  // ===========================================================================
  // 1. TEACHER VIEW: Assigned Class Roster, Daily Attendance & Parent Chat
  // ===========================================================================
  Widget _buildTeacherView(BuildContext context, AppPalette p) {
    final assignedHalaqah = AuthSessionService.instance.assignedHalaqahName;
    final assignedHalaqahId = AuthSessionService.instance.assignedHalaqahId;
    final classStudents = StudentService.instance.getStudentsForHalaqah(
      assignedHalaqah,
      halaqahId: assignedHalaqahId,
    );

    int presentCount = 0;
    int lateCount = 0;
    int absentCount = 0;
    int excusedCount = 0;
    int unmarkedCount = 0;

    for (final s in classStudents) {
      final att = StudentService.instance.getTodayAttendanceForStudent(
        s.id,
        date: _teacherSelectedDate,
      );
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

    return RefreshIndicator(
      color: p.primary,
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 124),
        children: [
          // Hero Class Header
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
                          Text(
                            'ASSIGNED CLASS',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: AppColors.goldWarm,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            assignedHalaqah,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
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
                        '${classStudents.length} Students',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Date Picker + Mark All Present
                Row(
                  children: [
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _teacherSelectedDate,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 90)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 7)),
                        );
                        if (picked != null && mounted) {
                          setState(() => _teacherSelectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: AppColors.goldWarm,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isToday
                                  ? 'Today (${_teacherSelectedDate.month}/${_teacherSelectedDate.day})'
                                  : '${_teacherSelectedDate.year}-${_teacherSelectedDate.month.toString().padLeft(2, '0')}-${_teacherSelectedDate.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 18,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: classStudents.isEmpty
                          ? null
                          : () async {
                              try {
                                await StudentService.instance
                                    .markHalaqahAllPresent(
                                  halaqahName: assignedHalaqah,
                                  halaqahId: assignedHalaqahId,
                                  markedBy: AuthSessionService.instance.userName,
                                  date: _teacherSelectedDate,
                                );
                                if (!mounted) return;
                                setState(() {});
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'All class students marked Present. Parents notified.',
                                      ),
                                      backgroundColor: p.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (!mounted) return;
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to mark attendance: ${SupabaseService.cleanErrorMessage(e)}',
                                      ),
                                      backgroundColor: p.danger,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.done_all_rounded, size: 15),
                      label: const Text(
                        'All Present',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.goldWarm,
                        foregroundColor: const Color(0xFF102322),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 5-Column Glass Attendance Summary
                Row(
                  children: [
                    _buildAttCounterChip('Present', '$presentCount',
                        const Color(0xFF4ADE80)),
                    const SizedBox(width: 6),
                    _buildAttCounterChip(
                        'Late', '$lateCount', AppColors.goldWarm),
                    const SizedBox(width: 6),
                    _buildAttCounterChip(
                        'Absent', '$absentCount', const Color(0xFFFCA5A5)),
                    const SizedBox(width: 6),
                    _buildAttCounterChip(
                        'Excused', '$excusedCount', const Color(0xFFC4B5FD)),
                    const SizedBox(width: 6),
                    _buildAttCounterChip(
                        'Open', '$unmarkedCount', Colors.white70),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Pending Absence Requests
          StreamBuilder<List<AbsenceRequest>>(
            stream: AbsenceService.instance.requestsStream,
            initialData: AbsenceService.instance.allRequests,
            builder: (context, reqSnapshot) {
              final pendingRequests = AbsenceService.instance
                  .getPendingRequestsForHalaqah(
                assignedHalaqah,
                halaqahId: assignedHalaqahId,
              );
              if (pendingRequests.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProSectionHeader(
                    title:
                        'Pending Absence Excuses (${pendingRequests.length})',
                    subtitle: 'Submitted by parents for review',
                  ),
                  const SizedBox(height: 10),
                  ...pendingRequests.map(
                    (req) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ProCard(
                        accentStripeColor: p.excused,
                        borderColor: p.excused.withOpacity(0.35),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  req.studentName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                    color: p.ink,
                                  ),
                                ),
                                ProStatusPill(
                                  label: req.date
                                      .toIso8601String()
                                      .substring(0, 10),
                                  color: p.excused,
                                  icon: Icons.event_rounded,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Reason: ${_cleanReasonLabel(req.reason)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: p.excused,
                              ),
                            ),
                            if (req.notes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '"${req.notes}"',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: p.inkSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      try {
                                        await AbsenceService.instance
                                            .approveRequest(
                                          req.id,
                                          reviewedBy: AuthSessionService
                                              .instance.userName,
                                        );
                                        if (!mounted) return;
                                        setState(() {});
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Absence excuse approved for ${req.studentName}.',
                                              ),
                                              backgroundColor: p.excused,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (!mounted) return;
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Failed to approve request: ${SupabaseService.cleanErrorMessage(e)}',
                                              ),
                                              backgroundColor: p.danger,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.check_rounded,
                                        size: 15),
                                    label: const Text('Approve & Excuse',
                                        style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: p.excused,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      try {
                                        await AbsenceService.instance
                                            .declineRequest(
                                          req.id,
                                          reviewedBy: AuthSessionService
                                              .instance.userName,
                                        );
                                        if (!mounted) return;
                                        setState(() {});
                                      } catch (e) {
                                        if (!mounted) return;
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Failed to decline request: ${SupabaseService.cleanErrorMessage(e)}',
                                              ),
                                              backgroundColor: p.danger,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: Icon(Icons.close_rounded,
                                        size: 15, color: p.danger),
                                    label: Text('Decline',
                                        style: TextStyle(
                                            fontSize: 12, color: p.danger)),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: p.danger.withOpacity(0.5)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),

          const ProSectionHeader(
            title: 'Class Attendance Sheet',
            subtitle:
                'Tap a status to record attendance; parents are notified automatically.',
          ),
          const SizedBox(height: 12),

          if (classStudents.isEmpty)
            ProEmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No students enrolled in this circle',
              message:
                  'Students assigned to $assignedHalaqah by administration will appear here.',
            )
          else
            ...classStudents
                .map((s) => _buildTeacherStudentCard(context, s, p)),
        ],
      ),
    );
  }

  Widget _buildAttCounterChip(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.82),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherStudentCard(
      BuildContext context, Student student, AppPalette p) {
    final todayAtt = StudentService.instance.getTodayAttendanceForStudent(
      student.id,
      date: _teacherSelectedDate,
    );
    final currentStatus = todayAtt?.status;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ProCard(
        borderColor: currentStatus != null
            ? _statusColor(currentStatus, p).withOpacity(0.45)
            : p.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProAvatar(
                  name: student.fullName,
                  radius: 20,
                  color: p.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Juz ${student.currentJuz} • Surah #${student.currentSurah}, Ayah ${student.currentAyah}',
                        style: TextStyle(fontSize: 11.5, color: p.inkSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                ProStatusPill(
                  label: student.parentName,
                  icon: Icons.family_restroom_rounded,
                  color: p.gold,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Attendance for ${_teacherSelectedDate.month}/${_teacherSelectedDate.day}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: p.inkSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildAttendanceButton(
                  p: p,
                  student: student,
                  status: 'present',
                  label: 'Present',
                  icon: Icons.check_circle_rounded,
                  color: p.success,
                  isSelected: currentStatus == 'present',
                ),
                const SizedBox(width: 6),
                _buildAttendanceButton(
                  p: p,
                  student: student,
                  status: 'late',
                  label: 'Late',
                  icon: Icons.schedule_rounded,
                  color: p.warning,
                  isSelected: currentStatus == 'late',
                ),
                const SizedBox(width: 6),
                _buildAttendanceButton(
                  p: p,
                  student: student,
                  status: 'absent',
                  label: 'Absent',
                  icon: Icons.cancel_rounded,
                  color: p.danger,
                  isSelected: currentStatus == 'absent',
                ),
                const SizedBox(width: 6),
                _buildAttendanceButton(
                  p: p,
                  student: student,
                  status: 'excused',
                  label: 'Excused',
                  icon: Icons.note_alt_rounded,
                  color: p.excused,
                  isSelected: currentStatus == 'excused',
                ),
              ],
            ),
            if (todayAtt?.teacherRemarks != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: p.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.comment_outlined, size: 14, color: p.primary),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '"${todayAtt!.teacherRemarks}"',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: p.ink,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () =>
                          _showEditRemarksDialog(context, student, todayAtt),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.edit_rounded,
                            size: 14, color: p.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Divider(height: 1, color: p.border),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildCompactCardAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Message Parent',
                    color: p.gold,
                    onTap: () => _openTeacherParentChat(context, student),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactCardAction(
                    icon: Icons.menu_book_rounded,
                    label: 'Weekly Report',
                    color: p.primary,
                    onTap: () => _showWeeklyReportDialog(context, student),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showStudentHistoryDialog(context, student),
                  icon: Icon(Icons.history_rounded,
                      size: 20, color: p.inkSecondary),
                  style: IconButton.styleFrom(
                    backgroundColor: p.surfaceSubtle,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  tooltip: 'Attendance History',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTeacherParentChat(
      BuildContext context, Student student) async {
    if (student.parentId == null || student.parentId!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${student.fullName} does not have a linked parent account yet.',
            ),
          ),
        );
      }
      return;
    }
    try {
      final convo = await MessagingService.instance.startTeacherChatWithParent(
        teacherId: AuthSessionService.instance.userId,
        teacherName: AuthSessionService.instance.userName,
        parentId: student.parentId!,
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open chat: ${SupabaseService.cleanErrorMessage(e)}',
            ),
            backgroundColor: AppColors.of(context).danger,
          ),
        );
      }
    }
  }

  Widget _buildAttendanceButton({
    required AppPalette p,
    required Student student,
    required String status,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () async {
          try {
            await StudentService.instance.recordDailyAttendance(
              studentId: student.id,
              status: status,
              markedBy: AuthSessionService.instance.userName,
              sessionDate: _teacherSelectedDate,
            );
            if (!mounted) return;
            setState(() {});
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${student.fullName} marked ${status.toUpperCase()}. Parent notified.',
                  ),
                  duration: const Duration(seconds: 2),
                  backgroundColor: color,
                ),
              );
            }
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to save attendance: ${SupabaseService.cleanErrorMessage(e)}',
                ),
                backgroundColor: p.danger,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? color : p.surfaceSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.28),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status, AppPalette p) {
    if (status == 'present') return p.success;
    if (status == 'late') return p.warning;
    if (status == 'absent') return p.danger;
    if (status == 'excused') return p.excused;
    return p.inkMuted;
  }

  // ===========================================================================
  // 2. PARENT VIEW: Multi-child Switcher, Progress & Attendance Records
  // ===========================================================================
  Widget _buildParentView(
      BuildContext context, List<Student> children, AppPalette p) {
    if (children.isEmpty) {
      return RefreshIndicator(
        color: p.primary,
        onRefresh: _handleRefresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 40),
            ProEmptyState(
              icon: Icons.family_restroom_rounded,
              title: 'No Children Linked',
              message:
                  'When center administration enrolls your child and links them to your account, their Quran progress and attendance will appear here.',
            ),
          ],
        ),
      );
    }

    final currentChild =
        children[_selectedChildIndex.clamp(0, children.length - 1)];
    final attendanceHistory =
        StudentService.instance.getAttendanceForStudent(currentChild.id);
    final weeklyReports =
        StudentService.instance.getWeeklyReportsForStudent(currentChild.id);
    final todayAtt =
        StudentService.instance.getTodayAttendanceForStudent(currentChild.id);
    final juzProgress = (currentChild.currentJuz / 30.0).clamp(0.03, 1.0);

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
            Text(
              'My Enrolled Children (${children.length})',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: p.inkSecondary,
              ),
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
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
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
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: isSelected
                                  ? Colors.white.withOpacity(0.22)
                                  : p.primarySoft,
                              child: Text(
                                child.fullName.isNotEmpty
                                    ? child.fullName[0].toUpperCase()
                                    : 'S',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : p.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              child.fullName,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : p.ink,
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

          // Hero Child Learning Card
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
                          Text(
                            currentChild.halaqahName.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                              color: AppColors.goldWarm,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            currentChild.fullName,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final halaqahs = HalaqahService.instance.halaqahs;
                        final hMatch = halaqahs.where((h) =>
                            h.name.toLowerCase() ==
                            currentChild.halaqahName.toLowerCase());
                        final teacherName = (hMatch.isNotEmpty &&
                                hMatch.first.teacherName != 'Unassigned')
                            ? hMatch.first.teacherName
                            : 'Assigned Ustaz';

                        try {
                          final convo =
                              await MessagingService.instance.startParentChat(
                            parentId: AuthSessionService.instance.userId,
                            parentName: AuthSessionService.instance.userName,
                            targetRole: 'teacher',
                            targetName: teacherName,
                            targetId:
                                hMatch.isNotEmpty ? hMatch.first.teacherId : null,
                            halaqahName: currentChild.halaqahName,
                            halaqahId: currentChild.halaqahId,
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
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not open chat: ${SupabaseService.cleanErrorMessage(e)}',
                                ),
                                backgroundColor: p.danger,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          size: 14),
                      label: const Text('Message Ustaz',
                          style: TextStyle(fontSize: 11.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.goldWarm,
                        foregroundColor: const Color(0xFF102322),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quran Memorization Progress',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    Text(
                      'Juz ${currentChild.currentJuz} of 30',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldWarm,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildHeroMetricTile(
                        'Current Juz', 'Juz ${currentChild.currentJuz}'),
                    const SizedBox(width: 8),
                    _buildHeroMetricTile(
                        'Surah', '#${currentChild.currentSurah}'),
                    const SizedBox(width: 8),
                    _buildHeroMetricTile(
                        'Ayah', 'Ayah ${currentChild.currentAyah}'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Today's Attendance Banner
          ProCard(
            borderColor: (todayAtt?.status == 'present'
                    ? p.success
                    : p.warning)
                .withOpacity(0.4),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (todayAtt?.status == 'present'
                            ? p.success
                            : p.warning)
                        .withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    todayAtt?.status == 'present'
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    color:
                        todayAtt?.status == 'present' ? p.success : p.warning,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today: ${(todayAtt?.status ?? 'Unrecorded').toUpperCase()}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: todayAtt?.status == 'present'
                              ? p.success
                              : p.warning,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        todayAtt?.teacherRemarks ??
                            'Ustaz will mark attendance during circle time.',
                        style: TextStyle(fontSize: 12, color: p.inkSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          ProSectionHeader(
            title: 'Attendance History',
            trailing: ElevatedButton.icon(
              onPressed: () =>
                  _showRequestAbsenceDialog(context, currentChild),
              icon: const Icon(Icons.edit_calendar_rounded, size: 14),
              label: const Text('Request Excuse',
                  style: TextStyle(fontSize: 11.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: p.excused,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),

          // Live Absence Excuse Requests
          StreamBuilder<List<AbsenceRequest>>(
            stream: AbsenceService.instance.requestsStream,
            initialData: AbsenceService.instance.allRequests,
            builder: (context, snapshot) {
              final childRequests = (snapshot.data ?? [])
                  .where((r) => r.studentId == currentChild.id)
                  .toList();
              if (childRequests.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  ...childRequests.map((req) {
                    final reqColor = req.isApproved
                        ? p.success
                        : (req.isDeclined ? p.danger : p.warning);
                    final reqLabel = req.isApproved
                        ? 'Approved'
                        : (req.isDeclined ? 'Declined' : 'Pending');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ProCard(
                        padding: const EdgeInsets.all(13),
                        borderColor: reqColor.withOpacity(0.4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Excuse: ${_cleanReasonLabel(req.reason)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: p.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Date: ${req.date.toIso8601String().substring(0, 10)}${req.notes.isNotEmpty ? " • \"${req.notes}\"" : ""}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: p.inkSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ProStatusPill(label: reqLabel, color: reqColor),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),

          const SizedBox(height: 12),
          if (attendanceHistory.isEmpty)
            const ProEmptyState(
              icon: Icons.fact_check_outlined,
              title: 'No attendance logged yet',
              message:
                  'Daily attendance entries recorded by Ustaz will appear here.',
            )
          else
            ...attendanceHistory.map((att) => _buildAttendanceCard(att, p)),

          const SizedBox(height: 22),

          const ProSectionHeader(
            title: 'Weekly Quran Progress Reports',
            subtitle: 'Sabaq, Sabqi, Manzil & Tajweed evaluations',
          ),
          const SizedBox(height: 12),
          if (weeklyReports.isEmpty)
            const ProEmptyState(
              icon: Icons.auto_stories_outlined,
              title: 'No weekly reports yet',
              message:
                  'Weekly memorization and Tajweed evaluations will appear here once published.',
            )
          else
            ...weeklyReports
                .map((report) => _buildWeeklyReportCard(report, p)),
        ],
      ),
    );
  }

  Widget _buildHeroMetricTile(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.11),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.white.withOpacity(0.75),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. ADMIN VIEW: Full Roster, Circle Filter Chips & Student Enrollment
  // ===========================================================================
  Widget _buildAdminView(
      BuildContext context, List<Student> allStudents, AppPalette p) {
    final filtered = allStudents.where((s) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = s.fullName.toLowerCase().contains(q) ||
          s.parentName.toLowerCase().contains(q);
      final matchesHalaqah = _selectedHalaqahFilter == 'All' ||
          s.halaqahName.contains(_selectedHalaqahFilter);
      return matchesSearch && matchesHalaqah;
    }).toList();

    final loc = AppLocalizations.of(context);
    final paymentsByStudent = <String, List<MonthlyPayment>>{};
    for (final pay in PaymentService.instance.allPayments) {
      paymentsByStudent.putIfAbsent(pay.studentId, () => []).add(pay);
    }

    return RefreshIndicator(
      color: p.primary,
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 124),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${allStudents.length} ${loc.studentsCount}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loc.parentLinkage,
                      style: TextStyle(fontSize: 12, color: p.inkSecondary),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => AddStudentDialog.show(context),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: Text(loc.addStudent,
                    style: const TextStyle(fontSize: 12.5)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (allStudents.isNotEmpty) ...[
            ProSearchField(
              hintText: loc.search,
              query: _searchQuery,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder(
              valueListenable: HalaqahService.instance.halaqahsNotifier,
              builder: (context, halaqahs, _) {
                final circleNames = <String>[
                  'All',
                  ...halaqahs.map((h) => h.name),
                ];
                if (circleNames.length <= 1) return const SizedBox.shrink();
                return SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: circleNames.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final name = circleNames[i];
                      final isSelected = _selectedHalaqahFilter == name;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedHalaqahFilter = name),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? p.primary : p.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? p.primary : p.border,
                            ),
                          ),
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected ? p.onPrimary : p.inkSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          if (allStudents.isEmpty)
            ProEmptyState(
              icon: Icons.school_outlined,
              title: loc.studentRoster,
              message: loc.parentLinkage,
              actionLabel: loc.enrollStudent,
              onAction: () => AddStudentDialog.show(context),
            )
          else if (filtered.isEmpty)
            ProEmptyState(
              icon: Icons.search_off_rounded,
              title: loc.none,
              message: loc.search,
            )
          else
            ...filtered.map(
              (s) => _buildAdminStudentCard(
                s,
                p,
                paymentsByStudent[s.id] ?? const [],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminStudentCard(
    Student student,
    AppPalette p,
    List<MonthlyPayment> studentPayments,
  ) {
    final parentContact = student.parentPhone.isNotEmpty
        ? ' • ${student.parentPhone}'
        : (student.parentEmail != null && student.parentEmail!.isNotEmpty
            ? ' • ${student.parentEmail}'
            : '');

    final String badgeText;
    final Color badgeColor;
    if (studentPayments.isNotEmpty) {
      final latest = studentPayments.first.status;
      badgeText = latest.toUpperCase();
      badgeColor = latest == 'approved'
          ? p.success
          : (latest == 'rejected' || latest == 'overdue'
              ? p.danger
              : p.gold);
    } else {
      badgeText = student.halaqahName;
      badgeColor = p.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ProCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProAvatar(
                  name: student.fullName,
                  radius: 21,
                  color: p.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Parent: ${student.parentName}$parentContact',
                        style: TextStyle(fontSize: 12, color: p.inkSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                ProStatusPill(label: badgeText, color: badgeColor),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.more_vert_rounded,
                      size: 19, color: p.inkMuted),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  color: p.surface,
                  onSelected: (val) async {
                    if (val == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text('Remove ${student.fullName}?'),
                          content: const Text(
                            'This will permanently remove this student and their linked records from the roster.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: p.danger,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          final ok = await StudentService.instance
                              .deleteStudent(student.id);
                          if (!mounted) return;
                          setState(() {});
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Removed ${student.fullName} from roster.'
                                      : 'Failed to remove student. Please check permissions.',
                                ),
                                backgroundColor: ok ? p.success : p.danger,
                              ),
                            );
                          }
                        } catch (e) {
                          if (!mounted) return;
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to remove student: ${SupabaseService.cleanErrorMessage(e)}',
                                ),
                                backgroundColor: p.danger,
                              ),
                            );
                          }
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 18, color: p.danger),
                          const SizedBox(width: 8),
                          Text(
                            'Remove Student',
                            style: TextStyle(
                              color: p.danger,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: p.surfaceSubtle,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_stories_outlined,
                      size: 14, color: p.primary),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${student.halaqahName} • Juz ${student.currentJuz}, Surah #${student.currentSurah}, Ayah ${student.currentAyah}',
                      style: TextStyle(
                        fontSize: 12,
                        color: p.inkSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildCompactCardAction(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Attendance',
                    color: p.success,
                    onTap: () => _showMarkAttendanceDialog(context, student),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactCardAction(
                    icon: Icons.menu_book_rounded,
                    label: 'Report',
                    color: p.primary,
                    onTap: () => _showWeeklyReportDialog(context, student),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactCardAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Message',
                    color: p.gold,
                    onTap: () async {
                      if (student.parentId == null ||
                          student.parentId!.isEmpty) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${student.fullName} does not have a linked parent account yet.',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      try {
                        final convo = await MessagingService.instance
                            .startDirectChatWithParent(
                          parentId: student.parentId!,
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
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not open chat: ${SupabaseService.cleanErrorMessage(e)}',
                              ),
                              backgroundColor: p.danger,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCardAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withOpacity(0.28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DIALOGS
  // ===========================================================================
  Future<void> _showEditRemarksDialog(
      BuildContext context, Student student, AttendanceRecord att) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditRemarksDialog(
        student: student,
        attendance: att,
        palette: AppColors.of(context),
      ),
    );
    if (saved == true && mounted) {
      setState(() {});
    }
  }

  void _showStudentHistoryDialog(BuildContext context, Student student) {
    final p = AppColors.of(context);
    final history = StudentService.instance.getAttendanceForStudent(student.id);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Attendance Log: ${student.fullName}'),
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
                  itemBuilder: (ctx, i) => _buildAttendanceCard(history[i], p),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMarkAttendanceDialog(
      BuildContext context, Student student) async {
    final p = AppColors.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _MarkAttendanceDialog(student: student, palette: p),
    );
    if (saved != true || !mounted) return;
    setState(() {});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Attendance recorded. Parent ${student.parentName} notified.',
          ),
        ),
      );
    }
  }

  Future<void> _showWeeklyReportDialog(
      BuildContext context, Student student) async {
    final p = AppColors.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _WeeklyReportDialog(student: student, palette: p),
    );
    if (saved != true || !mounted) return;
    setState(() {});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Weekly report posted. Parent ${student.parentName} notified.',
          ),
        ),
      );
    }
  }

  Widget _buildAttendanceCard(AttendanceRecord att, AppPalette p) {
    final pillColor = _statusColor(att.status, p);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ProCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        borderRadius: 16,
        child: Row(
          children: [
            ProStatusPill(
              label: att.status.toUpperCase(),
              color: pillColor,
              showDot: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    att.teacherRemarks ?? 'Attended circle on time',
                    style: TextStyle(
                      color: p.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    att.date.toIso8601String().substring(0, 10),
                    style: TextStyle(color: p.inkMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyReportCard(WeeklyReport report, AppPalette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ProCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Week of ${report.weekStartDate.toIso8601String().substring(0, 10)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: p.ink,
                  ),
                ),
                ProStatusPill(
                  label: report.tajweedRating,
                  color: p.success,
                  icon: Icons.verified_rounded,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildReportLine(p, 'Sabaq (New)', report.sabaq),
                  const SizedBox(height: 6),
                  _buildReportLine(p, 'Sabqi (Revision)', report.sabqi),
                  const SizedBox(height: 6),
                  _buildReportLine(p, 'Manzil (Retention)', report.manzil),
                ],
              ),
            ),
            if (report.teacherRemarks.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Ustaz Notes: "${report.teacherRemarks}"',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: p.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportLine(AppPalette p, String label, String val) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 115,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: p.inkSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            val,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showRequestAbsenceDialog(
      BuildContext context, Student student) async {
    final p = AppColors.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RequestAbsenceDialog(student: student, palette: p),
    );
    if (saved != true || !mounted) return;
    setState(() {});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Absence excuse submitted for ${student.fullName}. Ustaz notified.',
          ),
          backgroundColor: p.excused,
        ),
      );
    }
  }

  String _cleanReasonLabel(String reason) {
    switch (reason.toLowerCase()) {
      case 'illness':
        return 'Medical / Illness';
      case 'family_emergency':
        return 'Family Emergency';
      case 'school_exam':
        return 'School Academic Exam';
      case 'travel':
        return 'Travel / Out of Town';
      default:
        return 'Personal Reason';
    }
  }
}

class _EditRemarksDialog extends StatefulWidget {
  final Student student;
  final AttendanceRecord attendance;
  final AppPalette palette;

  const _EditRemarksDialog({
    required this.student,
    required this.attendance,
    required this.palette,
  });

  @override
  State<_EditRemarksDialog> createState() => _EditRemarksDialogState();
}

class _EditRemarksDialogState extends State<_EditRemarksDialog> {
  late final TextEditingController _remarksCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _remarksCtrl =
        TextEditingController(text: widget.attendance.teacherRemarks);
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Remarks: ${widget.student.fullName}'),
      content: TextField(
        controller: _remarksCtrl,
        enabled: !_isSaving,
        decoration:
            const InputDecoration(labelText: 'Teacher Remarks / Notes'),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : () async {
                  setState(() => _isSaving = true);
                  try {
                    await StudentService.instance.recordDailyAttendance(
                      studentId: widget.student.id,
                      status: widget.attendance.status,
                      remarks: _remarksCtrl.text.trim(),
                      sessionDate: widget.attendance.date,
                    );
                    if (!mounted) return;
                    Navigator.pop(context, true);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to save note: ${SupabaseService.cleanErrorMessage(e)}',
                        ),
                        backgroundColor: widget.palette.danger,
                      ),
                    );
                  }
                },
          child: Text(_isSaving ? 'Saving...' : 'Save Note'),
        ),
      ],
    );
  }
}

class _MarkAttendanceDialog extends StatefulWidget {
  final Student student;
  final AppPalette palette;

  const _MarkAttendanceDialog({
    required this.student,
    required this.palette,
  });

  @override
  State<_MarkAttendanceDialog> createState() => _MarkAttendanceDialogState();
}

class _MarkAttendanceDialogState extends State<_MarkAttendanceDialog> {
  String _selectedStatus = 'present';
  final _remarksCtrl = TextEditingController(text: 'Attended circle on time.');
  bool _isSaving = false;

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Daily Attendance: ${widget.student.fullName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            items: const [
              DropdownMenuItem(value: 'present', child: Text('Present')),
              DropdownMenuItem(value: 'late', child: Text('Late')),
              DropdownMenuItem(value: 'absent', child: Text('Absent')),
              DropdownMenuItem(value: 'excused', child: Text('Excused')),
            ],
            onChanged: _isSaving
                ? null
                : (val) {
                    if (val != null) {
                      setState(() => _selectedStatus = val);
                    }
                  },
            decoration: const InputDecoration(labelText: 'Status'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _remarksCtrl,
            enabled: !_isSaving,
            decoration: const InputDecoration(labelText: 'Teacher Remarks'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : () async {
                  setState(() => _isSaving = true);
                  try {
                    await StudentService.instance.recordDailyAttendance(
                      studentId: widget.student.id,
                      status: _selectedStatus,
                      remarks: _remarksCtrl.text.trim(),
                    );
                    if (!mounted) return;
                    Navigator.pop(context, true);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to save attendance: ${SupabaseService.cleanErrorMessage(e)}',
                        ),
                        backgroundColor: widget.palette.danger,
                      ),
                    );
                  }
                },
          child: Text(_isSaving ? 'Saving...' : 'Save & Notify'),
        ),
      ],
    );
  }
}

class _WeeklyReportDialog extends StatefulWidget {
  final Student student;
  final AppPalette palette;

  const _WeeklyReportDialog({
    required this.student,
    required this.palette,
  });

  @override
  State<_WeeklyReportDialog> createState() => _WeeklyReportDialogState();
}

class _WeeklyReportDialogState extends State<_WeeklyReportDialog> {
  final _sabaqCtrl = TextEditingController(text: 'Surah Al-Mulk (1-15)');
  final _sabqiCtrl = TextEditingController(text: 'Surah Al-Qalam (1-20)');
  final _manzilCtrl = TextEditingController(text: 'Juz 29 Retention');
  final _remarksCtrl =
      TextEditingController(text: 'Consistent Tajweed articulation.');
  String _rating = 'Excellent';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _sabaqCtrl.dispose();
    _sabqiCtrl.dispose();
    _manzilCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Weekly Report: ${widget.student.fullName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _sabaqCtrl,
              enabled: !_isSubmitting,
              decoration:
                  const InputDecoration(labelText: 'Sabaq (New Lesson)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sabqiCtrl,
              enabled: !_isSubmitting,
              decoration:
                  const InputDecoration(labelText: 'Sabqi (Recent Revision)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _manzilCtrl,
              enabled: !_isSubmitting,
              decoration:
                  const InputDecoration(labelText: 'Manzil (Retention)'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _rating,
              items: const [
                DropdownMenuItem(value: 'Excellent', child: Text('Excellent')),
                DropdownMenuItem(value: 'Very Good', child: Text('Very Good')),
                DropdownMenuItem(value: 'Good', child: Text('Good')),
                DropdownMenuItem(
                    value: 'Needs Revision', child: Text('Needs Revision')),
              ],
              onChanged: _isSubmitting
                  ? null
                  : (val) {
                      if (val != null) {
                        setState(() => _rating = val);
                      }
                    },
              decoration:
                  const InputDecoration(labelText: 'Tajweed Evaluation'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _remarksCtrl,
              enabled: !_isSubmitting,
              decoration:
                  const InputDecoration(labelText: 'Ustaz Evaluation Notes'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  try {
                    await StudentService.instance.submitWeeklyReport(
                      studentId: widget.student.id,
                      sabaq: _sabaqCtrl.text.trim(),
                      sabqi: _sabqiCtrl.text.trim(),
                      manzil: _manzilCtrl.text.trim(),
                      tajweedRating: _rating,
                      remarks: _remarksCtrl.text.trim(),
                      teacherName: AuthSessionService.instance.userName,
                    );
                    if (!mounted) return;
                    Navigator.pop(context, true);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to submit report: ${SupabaseService.cleanErrorMessage(e)}',
                        ),
                        backgroundColor: widget.palette.danger,
                      ),
                    );
                  }
                },
          child: Text(_isSubmitting ? 'Submitting...' : 'Submit & Notify'),
        ),
      ],
    );
  }
}

class _RequestAbsenceDialog extends StatefulWidget {
  final Student student;
  final AppPalette palette;

  const _RequestAbsenceDialog({
    required this.student,
    required this.palette,
  });

  @override
  State<_RequestAbsenceDialog> createState() => _RequestAbsenceDialogState();
}

class _RequestAbsenceDialogState extends State<_RequestAbsenceDialog> {
  DateTime _selectedDate = DateTime.now();
  String _selectedReason = 'illness';
  final _notesCtrl =
      TextEditingController(text: 'Feeling unwell and needs rest at home.');
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit_calendar_rounded, color: p.excused, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Request Excuse: ${widget.student.fullName}'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Circle: ${widget.student.halaqahName}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Date: ${_selectedDate.toIso8601String().substring(0, 10)}',
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
                            initialDate: _selectedDate,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 2)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null && mounted) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                  icon: const Icon(Icons.calendar_month_rounded, size: 15),
                  label: const Text('Change'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedReason,
              items: const [
                DropdownMenuItem(
                    value: 'illness', child: Text('Medical / Illness')),
                DropdownMenuItem(
                    value: 'family_emergency', child: Text('Family Emergency')),
                DropdownMenuItem(
                    value: 'school_exam', child: Text('School Academic Exam')),
                DropdownMenuItem(
                    value: 'travel', child: Text('Travel / Out of Town')),
                DropdownMenuItem(
                    value: 'other', child: Text('Other Personal Reason')),
              ],
              onChanged: _isSubmitting
                  ? null
                  : (val) {
                      if (val != null) {
                        setState(() => _selectedReason = val);
                      }
                    },
              decoration: const InputDecoration(
                labelText: 'Reason for Absence',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              enabled: !_isSubmitting,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Parent Explanation',
                hintText: 'Enter reason details for the teacher...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  try {
                    await AbsenceService.instance.submitAbsenceRequest(
                      studentId: widget.student.id,
                      date: _selectedDate,
                      reason: _selectedReason,
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
                          'Failed to submit excuse: ${SupabaseService.cleanErrorMessage(e)}',
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
          child: Text(_isSubmitting ? 'Submitting...' : 'Submit Excuse'),
        ),
      ],
    );
  }
}
