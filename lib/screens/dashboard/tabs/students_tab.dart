import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../core/services/offline_sync_service.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/student_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/surah_names.dart';
import '../../../widgets/add_student_dialog.dart';
import '../../../widgets/pro_shimmer.dart';
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
            if (snapshot.connectionState == ConnectionState.waiting &&
                students.isEmpty) {
              return const ProCardListSkeleton();
            }

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

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ProEmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: AppLocalizations.of(context).accessRestrictedTitle,
                  message: AppLocalizations.of(context)
                      .sessionPermissionsUnverified,
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
    final loc = AppLocalizations.of(context);
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
                            loc.translate('assignedClassHeader'),
                            style: const TextStyle(
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
                        classStudents.length == 1
                            ? loc.translate('studentBadgeOne')
                            : loc.tr('studentsBadgeLabel', {
                                'count': '${classStudents.length}',
                              }),
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
                                  ? loc.tr('todayDateParens', {
                                      'date':
                                          '${_teacherSelectedDate.month}/${_teacherSelectedDate.day}',
                                    })
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
                                      content: Text(
                                        loc.translate('allPresentSuccessMsg'),
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
                                        loc.tr('failedMarkAttendanceMsg', {
                                          'error':
                                              SupabaseService.cleanErrorMessage(
                                                  e),
                                        }),
                                      ),
                                      backgroundColor: p.danger,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.done_all_rounded, size: 15),
                      label: Text(
                        loc.translate('allPresentAction'),
                        style: const TextStyle(
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
                    _buildAttCounterChip(
                        loc.present, '$presentCount', const Color(0xFF4ADE80)),
                    const SizedBox(width: 6),
                    _buildAttCounterChip(
                        loc.lateStatus, '$lateCount', AppColors.goldWarm),
                    const SizedBox(width: 6),
                    _buildAttCounterChip(
                        loc.absent, '$absentCount', const Color(0xFFFCA5A5)),
                    const SizedBox(width: 6),
                    _buildAttCounterChip(
                        loc.excused, '$excusedCount', const Color(0xFFC4B5FD)),
                    const SizedBox(width: 6),
                    _buildAttCounterChip(
                        loc.openStatus, '$unmarkedCount', Colors.white70),
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
                    title: loc.tr('pendingAbsenceExcusesTitle', {
                      'count': '${pendingRequests.length}',
                    }),
                    subtitle: loc.translate('submittedByParentsSubtitle'),
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
                              loc.tr('reasonLabelValue', {
                                'reason': loc.localizedAbsenceReason(req.reason),
                              }),
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
                                                loc.tr(
                                                    'absenceExcuseApprovedMsg',
                                                    {'name': req.studentName}),
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
                                                loc.tr(
                                                    'failedApproveRequestMsg', {
                                                  'error': SupabaseService
                                                      .cleanErrorMessage(e),
                                                }),
                                              ),
                                              backgroundColor: p.danger,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.check_rounded,
                                        size: 15),
                                    label: Text(loc.approveAndExcuse,
                                        style: const TextStyle(fontSize: 12)),
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
                                                loc.tr(
                                                    'failedDeclineRequestMsg', {
                                                  'error': SupabaseService
                                                      .cleanErrorMessage(e),
                                                }),
                                              ),
                                              backgroundColor: p.danger,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: Icon(Icons.close_rounded,
                                        size: 15, color: p.danger),
                                    label: Text(loc.decline,
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

          ProSectionHeader(
            title: loc.translate('classAttendanceSheetTitle'),
            subtitle: loc.translate('classAttendanceSheetSubtitle'),
          ),
          const SizedBox(height: 12),

          if (classStudents.isEmpty)
            ProEmptyState(
              icon: Icons.people_outline_rounded,
              title: loc.translate('noStudentsInThisCircleTitle'),
              message: loc.tr('studentsAssignedByAdminMsg', {
                'circle': assignedHalaqah,
              }),
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
    final loc = AppLocalizations.of(context);
    final genderLabel = loc.localizedGender(student.gender);
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
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            student.fullName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                          ),
                          if (genderLabel != null)
                            ProStatusPill(
                              label: genderLabel,
                              color: student.gender == 'male'
                                  ? p.primary
                                  : p.gold,
                              icon: student.gender == 'male'
                                  ? Icons.male_rounded
                                  : Icons.female_rounded,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loc.tr('juzSurahAyahSummary', {
                          'juz': '${student.currentJuz}',
                          'surah': SurahNames.formatted(
                            student.currentSurah,
                            languageCode: loc.locale.languageCode,
                          ),
                          'ayah': '${student.currentAyah}',
                        }),
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
            Row(
              children: [
                Text(
                  loc.tr('attendanceForDateLabel', {
                    'date':
                        '${_teacherSelectedDate.month}/${_teacherSelectedDate.day}',
                  }),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: p.inkSecondary,
                  ),
                ),
                if (todayAtt != null)
                  ValueListenableBuilder<List<OfflineMutation>>(
                    valueListenable:
                        OfflineSyncService.instance.mutationsNotifier,
                    builder: (context, _, __) {
                      final isPending = OfflineSyncService.instance
                          .isRecordPending(
                        OfflineEntityTypes.attendance,
                        todayAtt.id,
                      );
                      if (!isPending) return const SizedBox.shrink();
                      return Padding(
                        padding:
                            const EdgeInsetsDirectional.only(start: 6),
                        child: Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: p.warning,
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildAttendanceButton(
                  p: p,
                  student: student,
                  status: 'present',
                  label: loc.present,
                  icon: Icons.check_circle_rounded,
                  color: p.success,
                  isSelected: currentStatus == 'present',
                ),
                const SizedBox(width: 6),
                _buildAttendanceButton(
                  p: p,
                  student: student,
                  status: 'late',
                  label: loc.lateStatus,
                  icon: Icons.schedule_rounded,
                  color: p.warning,
                  isSelected: currentStatus == 'late',
                ),
                const SizedBox(width: 6),
                _buildAttendanceButton(
                  p: p,
                  student: student,
                  status: 'absent',
                  label: loc.absent,
                  icon: Icons.cancel_rounded,
                  color: p.danger,
                  isSelected: currentStatus == 'absent',
                ),
                const SizedBox(width: 6),
                _buildAttendanceButton(
                  p: p,
                  student: student,
                  status: 'excused',
                  label: loc.excused,
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
                    label: AppLocalizations.of(context)
                        .translate('messageParentAction'),
                    color: p.gold,
                    onTap: () => _openTeacherParentChat(context, student),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactCardAction(
                    icon: Icons.menu_book_rounded,
                    label: AppLocalizations.of(context).weeklyReport,
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
                  tooltip: AppLocalizations.of(context)
                      .translate('attendanceHistoryTitle'),
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
    final loc = AppLocalizations.of(context);
    if (student.parentId == null || student.parentId!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.tr('noLinkedParentMsg', {'name': student.fullName}),
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
              loc.tr('couldNotOpenChatMsg', {
                'error': SupabaseService.cleanErrorMessage(e),
              }),
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
          HapticFeedback.lightImpact();
          final loc = AppLocalizations.of(context);
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
                    loc.tr('studentMarkedStatusMsg', {
                      'name': student.fullName,
                      'status': loc.localizedAttendanceStatus(status),
                    }),
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
                  loc.tr('failedSaveAttendanceMsg', {
                    'error': SupabaseService.cleanErrorMessage(e),
                  }),
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
    final loc = AppLocalizations.of(context);
    if (children.isEmpty) {
      return RefreshIndicator(
        color: p.primary,
        onRefresh: _handleRefresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            ProEmptyState(
              icon: Icons.family_restroom_rounded,
              title: loc.noLinkedChildrenTitle,
              message: loc.noLinkedChildrenDesc,
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
              loc.tr('myEnrolledChildrenHeader', {
                'count': '${children.length}',
              }),
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
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  currentChild.fullName,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (AppLocalizations.of(context)
                                      .localizedGender(currentChild.gender) !=
                                  null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        currentChild.gender == 'male'
                                            ? Icons.male_rounded
                                            : Icons.female_rounded,
                                        size: 12,
                                        color: AppColors.goldWarm,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        AppLocalizations.of(context)
                                            .localizedGender(
                                                currentChild.gender)!,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final loc = AppLocalizations.of(context);
                        final halaqahs = HalaqahService.instance.halaqahs;
                        final hMatch = halaqahs.where((h) =>
                            h.name.toLowerCase() ==
                            currentChild.halaqahName.toLowerCase());
                        final teacherName = (hMatch.isNotEmpty &&
                                hMatch.first.teacherName != 'Unassigned')
                            ? hMatch.first.teacherName
                            : loc.assignedUstazTitle;

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
                                  loc.tr('couldNotOpenChatMsg', {
                                    'error':
                                        SupabaseService.cleanErrorMessage(e),
                                  }),
                                ),
                                backgroundColor: p.danger,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          size: 14),
                      label: Text(
                          AppLocalizations.of(context)
                              .translate('messageUstazAction'),
                          style: const TextStyle(fontSize: 11.5)),
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
                      AppLocalizations.of(context)
                          .translate('quranMemorizationProgressTitle'),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context).tr('juzOf30', {
                        'juz': '${currentChild.currentJuz}',
                      }),
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
                      AppLocalizations.of(context)
                          .translate('currentJuzMetric'),
                      AppLocalizations.of(context)
                          .tr('juzShort', {'juz': '${currentChild.currentJuz}'}),
                    ),
                    const SizedBox(width: 8),
                    _buildHeroMetricTile(
                      AppLocalizations.of(context).surahLabel,
                      SurahNames.nameFor(
                        currentChild.currentSurah,
                        languageCode:
                            AppLocalizations.of(context).locale.languageCode,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildHeroMetricTile(
                      AppLocalizations.of(context).translate('ayahMetric'),
                      AppLocalizations.of(context).tr('ayahValueLabel', {
                        'ayah': '${currentChild.currentAyah}',
                      }),
                    ),
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
                        loc.tr('todayAttBadge', {
                          'status': todayAtt != null
                              ? loc.localizedAttendanceStatus(todayAtt.status)
                              : loc.unrecordedStatus,
                        }),
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
                            loc.translate('ustazWillMarkMsg'),
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
            title: loc.translate('attendanceHistoryTitle'),
            trailing: ElevatedButton.icon(
              onPressed: () =>
                  _showRequestAbsenceDialog(context, currentChild),
              icon: const Icon(Icons.edit_calendar_rounded, size: 14),
              label: Text(AppLocalizations.of(context).requestExcuse,
                  style: const TextStyle(fontSize: 11.5)),
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
              final loc = AppLocalizations.of(context);
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
                        ? loc.approved
                        : (req.isDeclined ? loc.declinedStatus : loc.pending);

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
                                    loc.tr('excuseReasonLine', {
                                      'reason': loc
                                          .localizedAbsenceReason(req.reason),
                                    }),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: p.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${loc.tr('dateLineLabel', {
                                      'date': req.date
                                          .toIso8601String()
                                          .substring(0, 10),
                                    })}${req.notes.isNotEmpty ? " • \"${req.notes}\"" : ""}',
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
            ProEmptyState(
              icon: Icons.fact_check_outlined,
              title: AppLocalizations.of(context)
                  .translate('noAttendanceLoggedTitle'),
              message: AppLocalizations.of(context)
                  .translate('dailyAttendanceAppearHereMsg'),
            )
          else
            ...attendanceHistory.map((att) => _buildAttendanceCard(att, p)),

          const SizedBox(height: 22),

          ProSectionHeader(
            title: AppLocalizations.of(context)
                .translate('weeklyQuranProgressReportsTitle'),
            subtitle: AppLocalizations.of(context)
                .translate('sabaqSabqiManzilSubtitle'),
          ),
          const SizedBox(height: 12),
          if (weeklyReports.isEmpty)
            ProEmptyState(
              icon: Icons.auto_stories_outlined,
              title:
                  AppLocalizations.of(context).translate('noWeeklyReportsTitle'),
              message: AppLocalizations.of(context)
                  .translate('weeklyReportsAppearHereMsg'),
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
  String _titleCaseName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return raw;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  bool _hasLoggedRecitation(Student student, List<WeeklyReport> reports) {
    if (reports.isNotEmpty) return true;
    if (student.currentSurah <= 0) return false;
    if (student.currentJuz == 30 &&
        student.currentSurah == 1 &&
        student.currentAyah == 1) {
      return false;
    }
    return true;
  }

  Color _ratingBadgeColor(String rating, AppPalette p) {
    final lower = rating.trim().toLowerCase();
    if (lower.contains('excellent') || lower.contains('mumtaz')) {
      return const Color(0xFFC89B3C);
    }
    if (lower.contains('needs') || lower.contains('revision')) {
      return p.warning;
    }
    return p.success;
  }

  Future<void> _openParentDirectChat(
      BuildContext context, Student student) async {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    if (student.parentId == null || student.parentId!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.tr('noLinkedParentMsg', {'name': student.fullName}),
            ),
          ),
        );
      }
      return;
    }
    try {
      final convo = await MessagingService.instance.startDirectChatWithParent(
        parentId: student.parentId!,
        parentName: student.parentName,
      );
      if (context.mounted) {
        final displayTitle = MessagingService.instance
            .displayTitleFor(convo, AuthSessionService.instance.userId);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: convo.id,
              conversationTitle: displayTitle,
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
              loc.tr('couldNotOpenChatMsg', {
                'error': SupabaseService.cleanErrorMessage(e),
              }),
            ),
            backgroundColor: p.danger,
          ),
        );
      }
    }
  }

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

    final halaqahs = HalaqahService.instance.halaqahs;
    final circleCount = halaqahs.isNotEmpty
        ? halaqahs.length
        : allStudents
            .map((s) => s.halaqahName.trim())
            .where((n) => n.isNotEmpty)
            .toSet()
            .length;
    final presentTodayCount = allStudents.where((s) {
      final status = StudentService.instance.getTodayAttendanceForStudent(s.id)?.status;
      return status == 'present' || status == 'late';
    }).length;

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
                      loc.studentRoster,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: p.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loc.tr('rosterSummaryMetrics', {
                        'students': '${allStudents.length}',
                        'circles': '$circleCount',
                        'present': '$presentTodayCount',
                      }),
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
              hintText: loc.translate('searchStudentsOrParentsHint'),
              query: _searchQuery,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder(
              valueListenable: HalaqahService.instance.halaqahsNotifier,
              builder: (context, halaqahsList, _) {
                final circleNames = <String>[
                  'All',
                  ...halaqahsList.map((h) => h.name),
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
                            name == 'All' ? loc.all : name,
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
              message: loc.translate('addOneStudentBeforeTuitionMsg'),
              actionLabel: loc.enrollStudent,
              onAction: () => AddStudentDialog.show(context),
            )
          else if (filtered.isEmpty)
            ProEmptyState(
              icon: Icons.search_off_rounded,
              title: loc.none,
              message: loc.translate('searchStudentsOrParentsHint'),
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
    final loc = AppLocalizations.of(context);
    final displayName = _titleCaseName(student.fullName);
    final genderLabel = loc.localizedGender(student.gender);
    final metaParts = <String>[
      if (student.age > 0)
        loc.tr('ageYearsShort', {'age': '${student.age}'}),
      if (genderLabel != null) genderLabel,
    ];
    final metaLine = metaParts.join(' • ');

    final parentLine = student.parentPhone.isNotEmpty
        ? '${student.parentName} • ${student.parentPhone}'
        : student.parentName;

    final reports = StudentService.instance.getWeeklyReportsForStudent(student.id);
    final latestReport = reports.isNotEmpty ? reports.first : null;
    final hasRecitation = _hasLoggedRecitation(student, reports);

    final todayAtt = StudentService.instance.getTodayAttendanceForStudent(student.id);
    final attStatus = todayAtt?.status;
    final attColor = attStatus != null ? _statusColor(attStatus, p) : p.primary;
    final attLabel = attStatus != null
        ? loc.localizedAttendanceStatus(attStatus)
        : loc.translate('attendanceShortTab');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ProCard(
        onTap: () {
          HapticFeedback.selectionClick();
          _showStudentDetailSheet(context, student, p, studentPayments);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Name (+ Age/Gender) + Single Circle Pill + Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ProAvatar(
                  name: displayName,
                  radius: 21,
                  color: p.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                      if (metaLine.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          metaLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: p.inkSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                ProStatusPill(label: student.halaqahName, color: p.primary),
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
                    if (val == 'edit') {
                      await AddStudentDialog.show(
                        context,
                        existingStudent: student,
                      );
                      if (mounted) setState(() {});
                    } else if (val == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text(
                            loc.tr('removeStudentConfirmTitle', {
                              'name': student.fullName,
                            }),
                          ),
                          content: Text(
                            loc.translate('removeStudentConfirmBody'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: Text(loc.cancel),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: p.danger,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(c, true),
                              child: Text(loc.translate('removeAction')),
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
                                      ? loc.tr('removedStudentMsg', {
                                          'name': student.fullName,
                                        })
                                      : loc.translate(
                                          'failedRemoveStudentPermsMsg'),
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
                                  loc.tr('failedRemoveStudentMsg', {
                                    'error':
                                        SupabaseService.cleanErrorMessage(e),
                                  }),
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
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: p.primary),
                          const SizedBox(width: 8),
                          Text(
                            loc.editStudent,
                            style: TextStyle(
                              color: p.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 18, color: p.danger),
                          const SizedBox(width: 8),
                          Text(
                            loc.translate('removeStudentMenuLabel'),
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
            const SizedBox(height: 8),
            // Second Row: Full-width Parent Row with Icon
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 15, color: p.inkMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    parentLine,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: p.inkSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Quran Progress Strip (no redundant circle name; real Surah names)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: p.surfaceSubtle,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 14,
                    color: hasRecitation ? p.primary : p.inkMuted,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      hasRecitation
                          ? loc.tr('juzSurahAyahSummary', {
                              'juz': '${student.currentJuz}',
                              'surah': SurahNames.formatted(
                                student.currentSurah,
                                languageCode: loc.locale.languageCode,
                              ),
                              'ayah': '${student.currentAyah}',
                            })
                          : loc.translate('noRecitationLoggedYet'),
                      style: TextStyle(
                        fontSize: 12,
                        color: hasRecitation ? p.ink : p.inkMuted,
                        fontWeight:
                            hasRecitation ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (latestReport != null &&
                      latestReport.tajweedRating.trim().isNotEmpty) ...[
                    const SizedBox(width: 6),
                    ProStatusPill(
                      label: loc.localizedTajweedRating(latestReport.tajweedRating),
                      color: _ratingBadgeColor(latestReport.tajweedRating, p),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Action Row: Primary Attendance Pill + Secondary Log Hifz + Compact Chat Icon
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showMarkAttendanceDialog(context, student);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: attStatus != null
                            ? attColor.withValues(alpha: 0.14)
                            : p.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: attColor.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            attStatus != null
                                ? Icons.check_circle_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 16,
                            color: attColor,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              attLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: attColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showWeeklyReportDialog(context, student);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: p.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            size: 16,
                            color: p.inkSecondary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              loc.translate('logHifzAction'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: p.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: loc.translate('messageParentTooltip'),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _openParentDirectChat(context, student);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 42,
                      decoration: BoxDecoration(
                        color: p.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.border),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 18,
                        color: p.primary,
                      ),
                    ),
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
    final loc = AppLocalizations.of(context);
    final history = StudentService.instance.getAttendanceForStudent(student.id);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          loc.tr('attendanceLogTitle', {'name': student.fullName}),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(loc.translate('noAttendanceRecordedYet')),
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
            child: Text(loc.close),
          ),
        ],
      ),
    );
  }

  Future<void> _showMarkAttendanceDialog(
      BuildContext context, Student student) async {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
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
            loc.tr('attendanceRecordedNotifyMsg', {
              'name': student.parentName,
            }),
          ),
        ),
      );
    }
  }

  Future<void> _showWeeklyReportDialog(
      BuildContext context, Student student) async {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
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
            loc.tr('weeklyReportPostedNotifyMsg', {
              'name': student.parentName,
            }),
          ),
        ),
      );
    }
  }

  Widget _buildAttendanceCard(AttendanceRecord att, AppPalette p) {
    final loc = AppLocalizations.of(context);
    final pillColor = _statusColor(att.status, p);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ProCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        borderRadius: 16,
        child: Row(
          children: [
            ProStatusPill(
              label: loc.localizedAttendanceStatus(att.status),
              color: pillColor,
              showDot: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    att.teacherRemarks ??
                        loc.translate('defaultAttendedOnTime'),
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
    final loc = AppLocalizations.of(context);
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
                  loc.tr('weekOfDateLabel', {
                    'date': report.weekStartDate.toIso8601String().substring(0, 10),
                  }),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: p.ink,
                  ),
                ),
                ProStatusPill(
                  label: loc.localizedTajweedRating(report.tajweedRating),
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
                  _buildReportLine(
                      p, loc.translate('sabaqNewLessonLabel'), report.sabaq),
                  const SizedBox(height: 6),
                  _buildReportLine(
                      p, loc.translate('sabqiRecentRevisionLabel'), report.sabqi),
                  const SizedBox(height: 6),
                  _buildReportLine(
                      p, loc.translate('manzilRetentionLabel'), report.manzil),
                ],
              ),
            ),
            if (report.teacherRemarks.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                loc.tr('ustazNotesQuote', {'notes': report.teacherRemarks}),
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
    final loc = AppLocalizations.of(context);
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
            loc.tr('absenceExcuseSubmittedMsg', {'name': student.fullName}),
          ),
          backgroundColor: p.excused,
        ),
      );
    }
  }

  void _showStudentDetailSheet(
    BuildContext context,
    Student student,
    AppPalette p,
    List<MonthlyPayment> studentPayments,
  ) {
    final loc = AppLocalizations.of(context);
    final displayName = _titleCaseName(student.fullName);
    final genderLabel = loc.localizedGender(student.gender);
    final todayAtt =
        StudentService.instance.getTodayAttendanceForStudent(student.id);
    final reports =
        StudentService.instance.getWeeklyReportsForStudent(student.id);
    final latestReport = reports.isNotEmpty ? reports.first : null;
    final hasRecitation = _hasLoggedRecitation(student, reports);
    final latestPay = studentPayments.isNotEmpty ? studentPayments.first : null;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ProAvatar(name: displayName, radius: 26, color: p.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: p.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ProStatusPill(
                                label: student.halaqahName,
                                color: p.primary,
                              ),
                              if (student.age > 0)
                                ProStatusPill(
                                  label: loc.tr(
                                    'ageYearsShort',
                                    {'age': '${student.age}'},
                                  ),
                                  color: p.inkSecondary,
                                ),
                              if (genderLabel != null)
                                ProStatusPill(
                                  label: genderLabel,
                                  color: student.gender == 'male'
                                      ? p.primary
                                      : p.gold,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ProCard(
                  backgroundColor: p.surfaceSubtle,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReportLine(
                        p,
                        loc.roleParent,
                        student.parentPhone.isNotEmpty
                            ? '${student.parentName} • ${student.parentPhone}'
                            : student.parentName,
                      ),
                      const SizedBox(height: 8),
                      _buildReportLine(
                        p,
                        loc.translate('todaysAttendanceLabel'),
                        todayAtt != null
                            ? loc.localizedAttendanceStatus(todayAtt.status)
                            : loc.translate('notMarkedYetLabel'),
                      ),
                      const SizedBox(height: 8),
                      _buildReportLine(
                        p,
                        loc.translate('latestRecitationLabel'),
                        hasRecitation
                            ? loc.tr('juzSurahAyahSummary', {
                                'juz': '${student.currentJuz}',
                                'surah': SurahNames.formatted(
                                  student.currentSurah,
                                  languageCode: loc.locale.languageCode,
                                ),
                                'ayah': '${student.currentAyah}',
                              })
                            : loc.translate('noRecitationLoggedYet'),
                      ),
                      if (latestReport != null &&
                          latestReport.tajweedRating.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildReportLine(
                          p,
                          loc.translate('recitationRatingLabel'),
                          loc.localizedTajweedRating(latestReport.tajweedRating),
                        ),
                      ],
                      if (latestPay != null) ...[
                        const SizedBox(height: 8),
                        _buildReportLine(
                          p,
                          loc.tuitionAndFees,
                          '${latestPay.month} • ${loc.localizedPaymentStatus(latestPay.status)}',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _showMarkAttendanceDialog(context, student);
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded,
                            size: 18),
                        label: Text(loc.translate('attendanceShortTab')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _showWeeklyReportDialog(context, student);
                        },
                        icon: const Icon(Icons.menu_book_rounded, size: 18),
                        label: Text(loc.translate('logHifzAction')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _openParentDirectChat(context, student);
                        },
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            size: 18),
                        label: Text(loc.translate('messageParentTooltip')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(sheetCtx);
                          await AddStudentDialog.show(
                            context,
                            existingStudent: student,
                          );
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(loc.editStudent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        loc.tr('editRemarksTitle', {'name': widget.student.fullName}),
      ),
      content: TextField(
        controller: _remarksCtrl,
        enabled: !_isSaving,
        decoration: InputDecoration(
          labelText: loc.translate('teacherRemarksLabel'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(loc.cancel),
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
                          loc.tr('failedSaveNoteMsg', {
                            'error': SupabaseService.cleanErrorMessage(e),
                          }),
                        ),
                        backgroundColor: widget.palette.danger,
                      ),
                    );
                  }
                },
          child: Text(
              _isSaving ? loc.savingProgress : loc.translate('saveNoteAction')),
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
  final _remarksCtrl = TextEditingController();
  bool _didInitLocalizedDefaults = false;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitLocalizedDefaults) {
      _didInitLocalizedDefaults = true;
      _remarksCtrl.text =
          AppLocalizations.of(context).translate('defaultAttendedOnTime');
    }
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        loc.tr('dailyAttendanceTitle', {'name': widget.student.fullName}),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            items: [
              DropdownMenuItem(value: 'present', child: Text(loc.present)),
              DropdownMenuItem(value: 'late', child: Text(loc.lateStatus)),
              DropdownMenuItem(value: 'absent', child: Text(loc.absent)),
              DropdownMenuItem(value: 'excused', child: Text(loc.excused)),
            ],
            onChanged: _isSaving
                ? null
                : (val) {
                    if (val != null) {
                      setState(() => _selectedStatus = val);
                    }
                  },
            decoration:
                InputDecoration(labelText: loc.translate('statusFieldLabel')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _remarksCtrl,
            enabled: !_isSaving,
            decoration: InputDecoration(
              labelText: loc.translate('teacherRemarksShortLabel'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(loc.cancel),
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
                          loc.tr('failedSaveAttendanceMsg', {
                            'error': SupabaseService.cleanErrorMessage(e),
                          }),
                        ),
                        backgroundColor: widget.palette.danger,
                      ),
                    );
                  }
                },
          child: Text(_isSaving
              ? loc.savingProgress
              : loc.translate('saveAndNotifyAction')),
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
  final _sabaqCtrl = TextEditingController();
  final _sabqiCtrl = TextEditingController();
  final _manzilCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  String _rating = 'Excellent';
  bool _didInitLocalizedDefaults = false;
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitLocalizedDefaults) {
      _didInitLocalizedDefaults = true;
      final loc = AppLocalizations.of(context);
      _sabaqCtrl.text = loc.translate('defaultSabaqSample');
      _sabqiCtrl.text = loc.translate('defaultSabqiSample');
      _manzilCtrl.text = loc.translate('defaultManzilSample');
      _remarksCtrl.text = loc.translate('defaultReportRemarks');
    }
  }

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
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        loc.tr('weeklyReportTitle', {'name': widget.student.fullName}),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _sabaqCtrl,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                labelText: loc.translate('sabaqNewLessonLabel'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sabqiCtrl,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                labelText: loc.translate('sabqiRecentRevisionLabel'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _manzilCtrl,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                labelText: loc.translate('manzilRetentionLabel'),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _rating,
              items: [
                DropdownMenuItem(
                    value: 'Excellent', child: Text(loc.ratingExcellent)),
                DropdownMenuItem(
                    value: 'Very Good', child: Text(loc.ratingVeryGood)),
                DropdownMenuItem(value: 'Good', child: Text(loc.ratingGood)),
                DropdownMenuItem(
                    value: 'Needs Revision',
                    child: Text(loc.ratingNeedsRevision)),
              ],
              onChanged: _isSubmitting
                  ? null
                  : (val) {
                      if (val != null) {
                        setState(() => _rating = val);
                      }
                    },
              decoration: InputDecoration(labelText: loc.tajweedEvaluation),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _remarksCtrl,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                labelText: loc.translate('ustazEvaluationNotesLabel'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text(loc.cancel),
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
                          loc.tr('failedSubmitReportMsg', {
                            'error': SupabaseService.cleanErrorMessage(e),
                          }),
                        ),
                        backgroundColor: widget.palette.danger,
                      ),
                    );
                  }
                },
          child: Text(_isSubmitting
              ? loc.submittingProgress
              : loc.translate('submitAndNotifyAction')),
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
  final _notesCtrl = TextEditingController();
  bool _didInitLocalizedDefaults = false;
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitLocalizedDefaults) {
      _didInitLocalizedDefaults = true;
      _notesCtrl.text =
          AppLocalizations.of(context).translate('defaultExcuseNote');
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
      title: Row(
        children: [
          Icon(Icons.edit_calendar_rounded, color: p.excused, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              loc.tr('requestExcuseTitle', {'name': widget.student.fullName}),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.tr('circlePrefixLabel', {
                'circle': widget.student.halaqahName,
              }),
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
                  loc.tr('dateLineLabel', {
                    'date': _selectedDate.toIso8601String().substring(0, 10),
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
                  label: Text(loc.changeAction),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedReason,
              items: [
                DropdownMenuItem(
                    value: 'illness', child: Text(loc.reasonMedical)),
                DropdownMenuItem(
                    value: 'family_emergency',
                    child: Text(loc.reasonFamilyEmergency)),
                DropdownMenuItem(
                    value: 'school_exam', child: Text(loc.reasonSchoolExam)),
                DropdownMenuItem(
                    value: 'travel', child: Text(loc.reasonTravel)),
                DropdownMenuItem(
                    value: 'other', child: Text(loc.reasonPersonal)),
              ],
              onChanged: _isSubmitting
                  ? null
                  : (val) {
                      if (val != null) {
                        setState(() => _selectedReason = val);
                      }
                    },
              decoration: InputDecoration(
                labelText: loc.translate('reasonForAbsenceLabel'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              enabled: !_isSubmitting,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: loc.translate('parentExplanationLabel'),
                hintText: loc.translate('parentExplanationHint'),
              ),
            ),
          ],
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
                          loc.tr('failedSubmitExcuseMsg', {
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
          child: Text(_isSubmitting ? loc.submittingProgress : loc.submitExcuse),
        ),
      ],
    );
  }
}
