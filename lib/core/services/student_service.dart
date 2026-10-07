import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../models/weekly_report.dart';
import 'notification_center_service.dart';
import 'supabase_service.dart';

/// Service managing:
/// - Student profiles & parent-student associations (one parent -> multiple children)
/// - Teacher's assigned class student roster and daily attendance logging
/// - Weekly memorization & Tajweed reports with automated parent alerts
/// - Cloud sync with Supabase tables: public.students, public.parent_students, public.student_attendance
class StudentService {
  StudentService._() {
    fetchStudentsFromCloud();
  }

  static final StudentService instance = StudentService._();

  final List<Student> _students = [];
  final Map<String, List<AttendanceRecord>> _attendanceMap = {};
  final Map<String, List<WeeklyReport>> _weeklyReportsMap = {};

  final StreamController<List<Student>> _studentsController =
      StreamController<List<Student>>.broadcast();

  final StreamController<Map<String, List<AttendanceRecord>>> _attendanceController =
      StreamController<Map<String, List<AttendanceRecord>>>.broadcast();

  Stream<List<Student>> get studentsStream => _studentsController.stream;
  Stream<Map<String, List<AttendanceRecord>>> get attendanceStream => _attendanceController.stream;

  List<Student> get allStudents => List.unmodifiable(_students);

  /// Fetch enrolled students from Supabase Cloud
  Future<void> fetchStudentsFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      final res = await client
          .from('students')
          .select('id, full_name, halaqah_id, halaqah_name, current_juz, current_surah, current_ayah, monthly_fee_status, monthly_fee_amount, created_at')
          .order('created_at', ascending: false);

      if (res is List && res.isNotEmpty) {
        _students.clear();
        for (final item in res) {
          _students.add(Student.fromJson(item as Map<String, dynamic>));
        }
        _studentsController.add(List.from(_students));
      }
    } catch (e) {
      debugPrint('[StudentService] Cloud fetch notice: $e');
    }
  }

  /// Get list of all distinct registered parents for easy admin selection when enrolling students
  List<Map<String, String>> getRegisteredParents() {
    final Map<String, Map<String, String>> parentMap = {};

    for (final s in _students) {
      if (s.parentId != null && !parentMap.containsKey(s.parentId)) {
        final children = _students
            .where((other) => other.parentId == s.parentId)
            .map((other) => other.fullName)
            .join(', ');

        parentMap[s.parentId!] = {
          'id': s.parentId!,
          'name': s.parentName,
          'phone': s.parentPhone,
          'email': s.parentEmail ?? '',
          'children': children,
        };
      }
    }

    return parentMap.values.toList();
  }

  /// Get students belonging to a specific Halaqah (Class)
  List<Student> getStudentsForHalaqah(String halaqahName) {
    return _students.where((s) {
      return s.halaqahName.toLowerCase().contains(halaqahName.toLowerCase()) ||
          halaqahName.toLowerCase().contains(s.halaqahName.toLowerCase());
    }).toList();
  }

  /// Get students for a specific parent (enables one parent -> multiple children)
  List<Student> getStudentsForParent(String parentId, {String? parentEmail}) {
    return _students.where((s) {
      if (s.parentId == parentId) return true;
      if (parentEmail != null && s.parentEmail?.toLowerCase() == parentEmail.toLowerCase()) return true;
      if (parentEmail != null && s.parentPhone == parentEmail) return true;
      return false;
    }).toList();
  }

  /// Get attendance history for a student
  List<AttendanceRecord> getAttendanceForStudent(String studentId) {
    return _attendanceMap[studentId] ?? [];
  }

  /// Get attendance record for a student on a specific date (defaults to today)
  AttendanceRecord? getTodayAttendanceForStudent(String studentId, {DateTime? date}) {
    final targetDate = (date ?? DateTime.now()).toIso8601String().substring(0, 10);
    final history = _attendanceMap[studentId] ?? [];
    try {
      return history.firstWhere(
        (att) => att.date.toIso8601String().substring(0, 10) == targetDate,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get weekly reports for a student
  List<WeeklyReport> getWeeklyReportsForStudent(String studentId) {
    return _weeklyReportsMap[studentId] ?? [];
  }

  /// Admin Action: Add new student and link to a specific parent
  Future<Student> addStudent({
    required String fullName,
    required String halaqahName,
    required String parentId,
    required String parentName,
    required String parentPhone,
    String? parentEmail,
    required int currentJuz,
    required int currentSurah,
    required int currentAyah,
    String? halaqahId,
  }) async {
    final newStudent = Student(
      id: 'stu-${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName,
      halaqahId: halaqahId ?? 'halaqah-001',
      halaqahName: halaqahName,
      parentId: parentId,
      parentName: parentName,
      parentPhone: parentPhone,
      parentEmail: parentEmail,
      currentJuz: currentJuz,
      currentSurah: currentSurah,
      currentAyah: currentAyah,
      monthlyFeeStatus: 'pending',
      monthlyFeeAmount: 50.0,
      createdAt: DateTime.now(),
    );

    _students.insert(0, newStudent);
    _studentsController.add(List.from(_students));

    // Notify Parent of Enrollment
    NotificationCenterService.instance.addNotification(
      title: 'New Student Enrolled 🎓',
      body: '$fullName has been registered and linked to your parent account in $halaqahName.',
      type: 'general',
      data: {
        'student_id': newStudent.id,
        'parent_id': parentId,
      },
    );

    // Cloud sync to Supabase if connected
    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        final insertedStudent = await client.from('students').insert({
          'full_name': fullName,
          'current_juz': currentJuz,
          'current_surah': currentSurah,
          'current_ayah': currentAyah,
        }).select('id').maybeSingle();

        if (insertedStudent != null && insertedStudent['id'] != null) {
          final cloudStudentId = insertedStudent['id'];
          // Link parent to student in public.parent_students table
          await client.from('parent_students').insert({
            'parent_id': parentId,
            'student_id': cloudStudentId,
          });
        }
      } catch (e) {
        debugPrint('[StudentService] Cloud insert fallback: $e');
      }
    }

    return newStudent;
  }

  /// Teacher Action: Record or update daily attendance for a class student
  /// Emits immediate daily notification to the linked parent!
  Future<AttendanceRecord> recordDailyAttendance({
    required String studentId,
    required String status, // 'present', 'absent', 'late', 'excused'
    String? remarks,
    String? markedBy,
    DateTime? sessionDate,
  }) async {
    final studentMatches = _students.where((s) => s.id == studentId);
    final student = studentMatches.isNotEmpty
        ? studentMatches.first
        : Student(
            id: studentId,
            fullName: 'Student',
            createdAt: DateTime.now(),
          );

    final date = sessionDate ?? DateTime.now();
    final dateStr = date.toIso8601String().substring(0, 10);

    final defaultRemark = remarks?.trim().isNotEmpty == true
        ? remarks!.trim()
        : (status == 'present'
            ? 'Attended on time'
            : (status == 'late'
                ? 'Arrived late'
                : (status == 'absent' ? 'Absent from halaqah' : 'Excused absence')));

    // Check if attendance already exists for today; if so, update in-place
    final studentHistory = _attendanceMap.putIfAbsent(student.id, () => []);
    final existingIndex = studentHistory.indexWhere(
      (att) => att.date.toIso8601String().substring(0, 10) == dateStr,
    );

    final record = AttendanceRecord(
      id: existingIndex != -1
          ? studentHistory[existingIndex].id
          : 'att-${DateTime.now().millisecondsSinceEpoch}',
      studentId: student.id,
      studentName: student.fullName,
      halaqahId: student.halaqahId,
      date: date,
      status: status,
      teacherRemarks: defaultRemark,
      markedBy: markedBy ?? 'Ustaz Ibrahim Bilal',
      createdAt: DateTime.now(),
    );

    if (existingIndex != -1) {
      studentHistory[existingIndex] = record;
    } else {
      studentHistory.insert(0, record);
    }

    _attendanceController.add(Map.from(_attendanceMap));

    // DAILY ATTENDANCE NOTIFICATION FOR PARENT
    String statusEmoji = '✅';
    if (status == 'absent') statusEmoji = '❌';
    if (status == 'late') statusEmoji = '⏰';
    if (status == 'excused') statusEmoji = '📝';

    NotificationCenterService.instance.addNotification(
      title: 'Daily Attendance: ${status.toUpperCase()} $statusEmoji',
      body: '${student.fullName} was marked ${status.toUpperCase()} today in ${student.halaqahName}. Remarks: $defaultRemark',
      type: 'attendance',
      data: {
        'student_id': student.id,
        'student_name': student.fullName,
        'status': status,
        'date': date.toIso8601String(),
      },
    );

    // Supabase cloud sync
    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        await client.from('student_attendance').upsert({
          'student_id': student.id,
          'session_date': dateStr,
          'status': status,
          'remarks': defaultRemark,
        });
      } catch (e) {
        debugPrint('[StudentService] Cloud attendance sync: $e');
      }
    }

    return record;
  }

  /// Teacher Action: Mark all students in teacher's assigned class as 'present' for the day
  Future<void> markHalaqahAllPresent({
    required String halaqahName,
    String? markedBy,
    DateTime? date,
  }) async {
    final classStudents = getStudentsForHalaqah(halaqahName);
    for (final s in classStudents) {
      await recordDailyAttendance(
        studentId: s.id,
        status: 'present',
        remarks: 'Attended circle on time',
        markedBy: markedBy,
        sessionDate: date,
      );
    }
  }

  /// Teacher/Admin Action: Generate and post weekly progress report
  Future<void> submitWeeklyReport({
    required String studentId,
    required String sabaq,
    required String sabqi,
    required String manzil,
    required String tajweedRating,
    required String remarks,
    int mistakesCount = 0,
    String? teacherName,
  }) async {
    final studentMatches = _students.where((s) => s.id == studentId);
    final student = studentMatches.isNotEmpty
        ? studentMatches.first
        : Student(
            id: studentId,
            fullName: 'Student',
            createdAt: DateTime.now(),
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
      teacherName: teacherName ?? 'Ustaz Ibrahim Bilal',
      createdAt: DateTime.now(),
    );

    _weeklyReportsMap.putIfAbsent(student.id, () => []).insert(0, report);

    // WEEKLY REPORT NOTIFICATION FOR PARENT
    NotificationCenterService.instance.addNotification(
      title: 'Weekly Quran Progress Report 📜',
      body: 'Weekly evaluation for ${student.fullName}: Sabaq ($sabaq), Tajweed: $tajweedRating. Remarks: $remarks',
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
