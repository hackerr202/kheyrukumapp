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
  StudentService._() {
    _initSampleData();
  }

  static final StudentService instance = StudentService._();

  final List<Student> _students = [];
  final Map<String, List<AttendanceRecord>> _attendanceMap = {};
  final Map<String, List<WeeklyReport>> _weeklyReportsMap = {};

  final StreamController<List<Student>> _studentsController =
      StreamController<List<Student>>.broadcast();

  Stream<List<Student>> get studentsStream => _studentsController.stream;

  List<Student> get allStudents => List.unmodifiable(_students);

  void _initSampleData() {
    // Initial Students with parent linking
    final s1 = Student(
      id: 'stu-001',
      fullName: 'Abdur-Rahman Muhammed',
      halaqahId: 'hal-001',
      halaqahName: 'Halaqah Abu Bakr (حلقة أبي بكر)',
      parentId: 'par-001',
      parentName: 'Muhammed Yakut (Parent)',
      parentPhone: '+251 91 123 4567',
      currentJuz: 30,
      currentSurah: 67, // Al-Mulk
      currentAyah: 15,
      monthlyFeeStatus: 'paid',
      monthlyFeeAmount: 50.0,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    );

    final s2 = Student(
      id: 'stu-002',
      fullName: 'Fatima Muhammed',
      halaqahId: 'hal-002',
      halaqahName: 'Halaqah Aisha Bint Abi Bakr (حلقة عائشة)',
      parentId: 'par-001', // Same parent has 2 children!
      parentName: 'Muhammed Yakut (Parent)',
      parentPhone: '+251 91 123 4567',
      currentJuz: 29,
      currentSurah: 71, // Nuh
      currentAyah: 10,
      monthlyFeeStatus: 'pending',
      monthlyFeeAmount: 50.0,
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    );

    final s3 = Student(
      id: 'stu-003',
      fullName: 'Bilal Khalid',
      halaqahId: 'hal-001',
      halaqahName: 'Halaqah Abu Bakr (حلقة أبي بكر)',
      parentId: 'par-002',
      parentName: 'Khalid Al-Mansoor',
      parentPhone: '+251 92 888 7766',
      currentJuz: 30,
      currentSurah: 78, // An-Naba
      currentAyah: 20,
      monthlyFeeStatus: 'overdue',
      monthlyFeeAmount: 50.0,
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    );

    final s4 = Student(
      id: 'stu-004',
      fullName: 'Sumayyah Khalid',
      halaqahId: 'hal-002',
      halaqahName: 'Halaqah Aisha Bint Abi Bakr (حلقة عائشة)',
      parentId: 'par-002', // Khalid also has 2 children
      parentName: 'Khalid Al-Mansoor',
      parentPhone: '+251 92 888 7766',
      currentJuz: 28,
      currentSurah: 58,
      currentAyah: 1,
      monthlyFeeStatus: 'overdue',
      monthlyFeeAmount: 50.0,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );

    _students.addAll([s1, s2, s3, s4]);

    // Sample attendance for Abdur-Rahman
    _attendanceMap['stu-001'] = [
      AttendanceRecord(
        id: 'att-1',
        studentId: 'stu-001',
        studentName: 'Abdur-Rahman Muhammed',
        date: DateTime.now(),
        status: 'present',
        teacherRemarks: 'Arrived at 6:30 AM, memorized Surah Al-Mulk Ayahs 1-15 with no errors.',
        createdAt: DateTime.now(),
      ),
      AttendanceRecord(
        id: 'att-2',
        studentId: 'stu-001',
        studentName: 'Abdur-Rahman Muhammed',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: 'present',
        teacherRemarks: 'Excellent concentration during Tajweed pronunciation.',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      AttendanceRecord(
        id: 'att-3',
        studentId: 'stu-001',
        studentName: 'Abdur-Rahman Muhammed',
        date: DateTime.now().subtract(const Duration(days: 2)),
        status: 'late',
        teacherRemarks: 'Arrived 15 minutes late due to rain.',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    // Sample attendance for Fatima
    _attendanceMap['stu-002'] = [
      AttendanceRecord(
        id: 'att-4',
        studentId: 'stu-002',
        studentName: 'Fatima Muhammed',
        date: DateTime.now(),
        status: 'present',
        teacherRemarks: 'Masha\'Allah, recitation of Surah Nuh was fluent and clear.',
        createdAt: DateTime.now(),
      ),
    ];

    // Sample weekly report for Abdur-Rahman
    _weeklyReportsMap['stu-001'] = [
      WeeklyReport(
        id: 'wr-1',
        studentId: 'stu-001',
        studentName: 'Abdur-Rahman Muhammed',
        weekStartDate: DateTime.now().subtract(const Duration(days: 7)),
        weekEndDate: DateTime.now(),
        sabaq: 'Surah Al-Mulk (Ayahs 1 - 15)',
        sabqi: 'Surah Al-Qalam (Ayahs 1 - 30)',
        manzil: 'Juz 29 Complete Revision',
        daysPresent: 5,
        totalDays: 5,
        tajweedRating: 'Excellent',
        mistakesCount: 1,
        teacherRemarks: 'Remarkable memorization discipline this week. Pronunciation of Ghunnah and Madd is precise.',
        teacherName: 'Ustaz Muhammed Yakut',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    // Sample weekly report for Fatima
    _weeklyReportsMap['stu-002'] = [
      WeeklyReport(
        id: 'wr-2',
        studentId: 'stu-002',
        studentName: 'Fatima Muhammed',
        weekStartDate: DateTime.now().subtract(const Duration(days: 7)),
        weekEndDate: DateTime.now(),
        sabaq: 'Surah Nuh (Ayahs 1 - 15)',
        sabqi: 'Surah Al-Ma\'arij (Full)',
        manzil: 'Juz 29 Revision',
        daysPresent: 5,
        totalDays: 5,
        tajweedRating: 'Very Good',
        mistakesCount: 2,
        teacherRemarks: 'High retention and steady recitation pace.',
        teacherName: 'Ustadha Maryam',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    _studentsController.add(List.from(_students));
  }

  /// Get students for a specific parent (enables one parent -> multiple children)
  List<Student> getStudentsForParent(String parentId) {
    final list = _students.where((s) => s.parentId == parentId).toList();
    // Fallback: If demo parent, return all children of demo parent
    if (list.isEmpty) {
      return _students.where((s) => s.parentId == 'par-001').toList();
    }
    return list;
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
