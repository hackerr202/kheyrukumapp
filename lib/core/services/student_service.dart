import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../models/weekly_report.dart';
import 'notification_center_service.dart';
import 'supabase_service.dart';

/// Service managing:
/// - Student profiles & parent-student associations (one parent -> multiple children)
/// - Daily attendance logging with immediate daily parent notifications
/// - Weekly memorization & Tajweed reports with weekly parent notifications
class StudentService {
  StudentService._();

  static final StudentService instance = StudentService._();

  final List<Student> _students = [];
  final Map<String, List<AttendanceRecord>> _attendanceMap = {};
  final Map<String, List<WeeklyReport>> _weeklyReportsMap = {};

  final StreamController<List<Student>> _studentsController =
      StreamController<List<Student>>.broadcast();

  Stream<List<Student>> get studentsStream => _studentsController.stream;

  List<Student> get allStudents => List.unmodifiable(_students);

  /// Get students for a specific parent (enables one parent -> multiple children)
  List<Student> getStudentsForParent(String parentId, {String? parentEmail}) {
    return _students.where((s) {
      if (s.parentId == parentId) return true;
      if (parentEmail != null && s.parentPhone == parentEmail) return true;
      return false;
    }).toList();
  }

  /// Get attendance history for a student
  List<AttendanceRecord> getAttendanceForStudent(String studentId) {
    return _attendanceMap[studentId] ?? [];
  }

  /// Get weekly reports for a student
  List<WeeklyReport> getWeeklyReportsForStudent(String studentId) {
    return _weeklyReportsMap[studentId] ?? [];
  }

  /// Add new student and assign to parent (Admin action)
  Future<Student> addStudent({
    required String fullName,
    required String halaqahName,
    required String parentName,
    required String parentPhone,
    required int currentJuz,
    required int currentSurah,
    required int currentAyah,
    String? parentId,
  }) async {
    final newStudent = Student(
      id: 'stu-${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName,
      halaqahName: halaqahName,
      parentId: parentId ?? 'par-${DateTime.now().millisecondsSinceEpoch}',
      parentName: parentName,
      parentPhone: parentPhone,
      currentJuz: currentJuz,
      currentSurah: currentSurah,
      currentAyah: currentAyah,
      monthlyFeeStatus: 'pending',
      monthlyFeeAmount: 50.0,
      createdAt: DateTime.now(),
    );

    _students.insert(0, newStudent);
    _studentsController.add(List.from(_students));

    // Try cloud sync if Supabase is connected
    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        await client.from('students').insert({
          'full_name': fullName,
          'current_juz': currentJuz,
          'current_surah': currentSurah,
          'current_ayah': currentAyah,
        });
      } catch (e) {
        debugPrint('[StudentService] Cloud insert fallback: $e');
      }
    }

    return newStudent;
  }

  /// Record daily attendance for a student (Teacher/Admin action)
  /// Triggers daily notification for parent!
  Future<void> recordDailyAttendance({
    required String studentId,
    required String status, // 'present', 'absent', 'late', 'excused'
    String? remarks,
  }) async {
    final student = _students.firstWhere(
      (s) => s.id == studentId,
      orElse: () => _students.first,
    );

    final record = AttendanceRecord(
      id: 'att-${DateTime.now().millisecondsSinceEpoch}',
      studentId: student.id,
      studentName: student.fullName,
      date: DateTime.now(),
      status: status,
      teacherRemarks: remarks ?? (status == 'present' ? 'Attended on time' : 'Status: $status'),
      createdAt: DateTime.now(),
    );

    _attendanceMap.putIfAbsent(student.id, () => []).insert(0, record);

    // DAILY ATTENDANCE NOTIFICATION FOR PARENT
    String statusEmoji = '✅';
    if (status == 'absent') statusEmoji = '❌';
    if (status == 'late') statusEmoji = '⏰';
    if (status == 'excused') statusEmoji = '📝';

    NotificationCenterService.instance.addNotification(
      title: 'Daily Attendance: ${status.toUpperCase()} $statusEmoji',
      body: '${student.fullName} has been marked ${status.toUpperCase()} today in ${student.halaqahName}. Remarks: ${record.teacherRemarks}',
      type: 'attendance',
      data: {
        'student_id': student.id,
        'student_name': student.fullName,
        'status': status,
        'date': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Generate and post weekly progress report (Teacher/Admin action)
  /// Triggers weekly notification for parent!
  Future<void> submitWeeklyReport({
    required String studentId,
    required String sabaq,
    required String sabqi,
    required String manzil,
    required String tajweedRating,
    required String remarks,
    int mistakesCount = 0,
  }) async {
    final student = _students.firstWhere(
      (s) => s.id == studentId,
      orElse: () => _students.first,
    );

    final report = WeeklyReport(
      id: 'wr-${DateTime.now().millisecondsSinceEpoch}',
      studentId: student.id,
      studentName: student.fullName,
      weekStartDate: DateTime.now().subtract(const Duration(days: 7)),
      weekEndDate: DateTime.now(),
      sabaq: sabaq,
      sabqi: sabqi,
      manzil: manzil,
      daysPresent: 5,
      totalDays: 5,
      tajweedRating: tajweedRating,
      mistakesCount: mistakesCount,
      teacherRemarks: remarks,
      teacherName: 'Ustaz Muhammed Yakut',
      createdAt: DateTime.now(),
    );

    _weeklyReportsMap.putIfAbsent(student.id, () => []).insert(0, report);

    // WEEKLY REPORT NOTIFICATION FOR PARENT
    NotificationCenterService.instance.addNotification(
      title: 'Weekly Quran Progress Report 📜',
      body: 'Weekly review published for ${student.fullName}: Sabaq ($sabaq), Rating: $tajweedRating. Remarks: $remarks',
      type: 'weekly_report',
      data: {
        'student_id': student.id,
        'student_name': student.fullName,
        'sabaq': sabaq,
        'rating': tajweedRating,
      },
    );
  }
}
