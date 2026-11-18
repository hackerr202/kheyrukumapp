import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../models/weekly_report.dart';
import 'auth_session_service.dart';
import 'local_storage_service.dart';
import 'notification_center_service.dart';
import 'push_notification_service.dart';
import 'supabase_service.dart';

/// Service managing:
/// - Student profiles & parent-student associations (one parent -> multiple children)
/// - Teacher's assigned class student roster and daily attendance logging
/// - Weekly memorization & Tajweed reports with automated parent alerts
/// - Cloud sync with Supabase tables: public.students, public.parent_students, public.student_attendance, public.weekly_reports
class StudentService {
  StudentService._() {
    _loadFromCache();
    refreshAll();
  }

  Future<void> _loadFromCache() async {
    try {
      final cached = await LocalStorageService.instance.getJsonList('cached_students');
      if (cached.isNotEmpty) {
        _students.clear();
        for (final item in cached) {
          _students.add(Student.fromJson(item));
        }
        _studentsController.add(List.from(_students));
        debugPrint('[StudentService] Loaded ${_students.length} students from offline cache.');
      }
    } catch (e) {
      debugPrint('[StudentService] Cache load error: $e');
    }
  }

  static final StudentService instance = StudentService._();

  final List<Student> _students = [];
  final Map<String, List<AttendanceRecord>> _attendanceMap = {};
  final Map<String, List<WeeklyReport>> _weeklyReportsMap = {};
  RealtimeChannel? _attendanceRealtimeChannel;
  RealtimeChannel? _reportsRealtimeChannel;

  final StreamController<List<Student>> _studentsController =
      StreamController<List<Student>>.broadcast();

  final StreamController<Map<String, List<AttendanceRecord>>> _attendanceController =
      StreamController<Map<String, List<AttendanceRecord>>>.broadcast();

  Stream<List<Student>> get studentsStream => _studentsController.stream;
  Stream<Map<String, List<AttendanceRecord>>> get attendanceStream => _attendanceController.stream;

  List<Student> get allStudents => List.unmodifiable(_students);

  /// Refresh students, attendance, and weekly reports from Supabase and subscribe to realtime updates
  Future<void> refreshAll() async {
    await fetchStudentsFromCloud();
    await fetchAttendanceFromCloud();
    await fetchWeeklyReportsFromCloud();
    _subscribeRealtime();
  }

  /// Purge in-memory and cached state on sign-out so switching accounts is clean
  Future<void> clearOnLogout() async {
    _attendanceRealtimeChannel?.unsubscribe();
    _attendanceRealtimeChannel = null;
    _reportsRealtimeChannel?.unsubscribe();
    _reportsRealtimeChannel = null;
    _students.clear();
    _attendanceMap.clear();
    _weeklyReportsMap.clear();
    _cachedRegisteredParents.clear();
    _studentsController.add([]);
    _attendanceController.add({});
    await LocalStorageService.instance.remove('cached_students');
  }

  void _subscribeRealtime() {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;

    try {
      _attendanceRealtimeChannel?.unsubscribe();
      _attendanceRealtimeChannel = client
          .channel('public:student_attendance')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'student_attendance',
            callback: (payload) async {
              await fetchAttendanceFromCloud();
              final newRow = payload.newRecord;
              if (newRow.isEmpty) return;
              final studentId = newRow['student_id']?.toString() ?? '';
              final status = newRow['status']?.toString() ?? '';
              final remarks = newRow['remarks']?.toString() ?? '';
              final myChildren = getStudentsForParent(
                AuthSessionService.instance.userId,
                parentEmail: AuthSessionService.instance.userEmail,
              );
              final childMatches = myChildren.where((c) => c.id == studentId);
              if (AuthSessionService.instance.isParent && childMatches.isNotEmpty) {
                final child = childMatches.first;
                PushNotificationService.instance.showNotification(
                  title: 'Daily Attendance: ${status.toUpperCase()}',
                  body: '${child.fullName} was marked ${status.toUpperCase()} in ${child.halaqahName}. ${remarks.isNotEmpty ? "Note: $remarks" : ""}',
                  payload: 'attendance',
                  type: 'attendance',
                );
              }
            },
          )
          .subscribe();

      _reportsRealtimeChannel?.unsubscribe();
      _reportsRealtimeChannel = client
          .channel('public:weekly_reports')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'weekly_reports',
            callback: (payload) async {
              await fetchWeeklyReportsFromCloud();
              final newRow = payload.newRecord;
              if (newRow.isEmpty) return;
              final studentId = newRow['student_id']?.toString() ?? '';
              final sabaq = newRow['sabaq']?.toString() ?? '';
              final rating = newRow['tajweed_rating']?.toString() ?? '';
              final myChildren = getStudentsForParent(
                AuthSessionService.instance.userId,
                parentEmail: AuthSessionService.instance.userEmail,
              );
              final childMatches = myChildren.where((c) => c.id == studentId);
              if (AuthSessionService.instance.isParent && childMatches.isNotEmpty) {
                final child = childMatches.first;
                PushNotificationService.instance.showNotification(
                  title: 'Weekly Quran Progress Report',
                  body: 'Report for ${child.fullName}: $sabaq ($rating)',
                  payload: 'weekly_report',
                  type: 'weekly_report',
                );
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[StudentService] Realtime subscription note: $e');
    }
  }

  /// Fetch daily attendance records from Supabase
  Future<void> fetchAttendanceFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null) return;
    try {
      final res = await client
          .from('student_attendance')
          .select('*, students(full_name, halaqah_id)')
          .order('session_date', ascending: false)
          .limit(300);
      if (res is List) {
        _attendanceMap.clear();
        for (final item in res) {
          final map = Map<String, dynamic>.from(item as Map);
          if (map['students'] is Map) {
            map['student_name'] = map['students']['full_name'];
            map['halaqah_id'] = map['students']['halaqah_id'];
          }
          final rec = AttendanceRecord.fromJson(map);
          _attendanceMap.putIfAbsent(rec.studentId, () => []).add(rec);
        }
        _attendanceController.add(Map.from(_attendanceMap));
      }
    } catch (e) {
      debugPrint('[StudentService] fetchAttendanceFromCloud notice: $e');
    }
  }

  /// Fetch weekly Quran progress reports from Supabase
  Future<void> fetchWeeklyReportsFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null) return;
    try {
      final res = await client
          .from('weekly_reports')
          .select('*, students(full_name), profiles:teacher_id(full_name)')
          .order('created_at', ascending: false)
          .limit(200);
      if (res is List) {
        _weeklyReportsMap.clear();
        for (final item in res) {
          final map = Map<String, dynamic>.from(item as Map);
          if (map['students'] is Map) {
            map['student_name'] = map['students']['full_name'];
          }
          if (map['profiles'] is Map) {
            map['teacher_name'] = map['profiles']['full_name'];
          }
          final report = WeeklyReport.fromJson(map);
          _weeklyReportsMap.putIfAbsent(report.studentId, () => []).add(report);
        }
        _studentsController.add(List.from(_students));
      }
    } catch (e) {
      debugPrint('[StudentService] fetchWeeklyReportsFromCloud notice: $e');
    }
  }

  static bool _isValidUuid(String? str) {
    if (str == null) return false;
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(str.trim());
  }

  /// Fetch enrolled students from Supabase Cloud
  Future<void> fetchStudentsFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      final res = await client
          .from('students')
          .select(
            'id, full_name, halaqah_id, current_juz, current_surah, current_ayah, date_of_birth, created_at, '
            'halaqahs:halaqah_id(name), '
            'parent_students(parent_id, profiles:parent_id(full_name, phone, email))',
          )
          .order('created_at', ascending: false);

      if (res is List) {
        final List<Student> cloudStudents = [];
        for (final item in res) {
          final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
          if (map['halaqahs'] != null && map['halaqahs'] is Map) {
            map['halaqah_name'] = map['halaqahs']['name'];
          }
          if (map['parent_students'] is List && (map['parent_students'] as List).isNotEmpty) {
            final firstPs = (map['parent_students'] as List).first;
            if (firstPs is Map) {
              map['parent_id'] = firstPs['parent_id']?.toString();
              if (firstPs['profiles'] is Map) {
                final prof = firstPs['profiles'] as Map<String, dynamic>;
                map['parent_name'] = prof['full_name']?.toString() ?? 'Parent';
                map['parent_phone'] = prof['phone']?.toString() ?? '';
                map['parent_email'] = prof['email']?.toString();
              }
            }
          }
          cloudStudents.add(Student.fromJson(map));
        }

        // Merge cloud students with locally created students that may not be in cloud yet
        for (final local in _students) {
          if (!cloudStudents.any((c) =>
              c.id == local.id ||
              (c.fullName.toLowerCase() == local.fullName.toLowerCase() &&
                  c.halaqahName == local.halaqahName))) {
            cloudStudents.add(local);
          }
        }
        _students.clear();
        _students.addAll(cloudStudents);
        _studentsController.add(List.from(_students));

        // Save to offline cache
        final jsonList = _students.map((s) => s.toJson()).toList();
        await LocalStorageService.instance.saveJsonList('cached_students', jsonList);
      }
    } catch (e) {
      debugPrint('[StudentService] Cloud fetch notice: $e');
    }
    await fetchRegisteredParentsFromCloud();
  }

  final List<Map<String, String>> _cachedRegisteredParents = [];

  /// Fetch registered parents from Supabase profiles
  Future<void> fetchRegisteredParentsFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null) return;
    try {
      final res = await client
          .from('profiles')
          .select('id, full_name, phone, email')
          .eq('role', 'parent');
      if (res is List) {
        _cachedRegisteredParents.clear();
        for (final item in res) {
          _cachedRegisteredParents.add({
            'id': item['id']?.toString() ?? '',
            'name': item['full_name']?.toString() ?? 'Parent',
            'phone': item['phone']?.toString() ?? '',
            'email': item['email']?.toString() ?? '',
          });
        }
      }
    } catch (e) {
      debugPrint('[StudentService] Cloud fetch parents notice: $e');
    }
  }

  /// Get list of all distinct registered parents for easy admin selection when enrolling students
  List<Map<String, String>> getRegisteredParents() {
    final Map<String, Map<String, String>> parentMap = {};

    // 1. Include cloud registered parents
    for (final p in _cachedRegisteredParents) {
      final pid = p['id']!;
      if (pid.isNotEmpty) {
        parentMap[pid] = {
          'id': pid,
          'name': p['name'] ?? 'Parent',
          'phone': p['phone'] ?? '',
          'email': p['email'] ?? '',
          'children': '',
        };
      }
    }

    // 2. Merge with existing enrolled students' parents
    for (final s in _students) {
      if (s.parentId != null && s.parentId!.isNotEmpty) {
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
  List<Student> getStudentsForHalaqah(String halaqahName, {String? halaqahId}) {
    if ((halaqahName.trim().isEmpty || halaqahName.toLowerCase() == 'assigned halaqah') &&
        (halaqahId == null || halaqahId.isEmpty)) {
      return [];
    }
    return _students.where((s) {
      if (halaqahId != null && halaqahId.isNotEmpty && s.halaqahId == halaqahId) {
        return true;
      }
      if (halaqahName.trim().isNotEmpty && halaqahName.toLowerCase() != 'assigned halaqah') {
        return s.halaqahName.toLowerCase().contains(halaqahName.toLowerCase()) ||
            halaqahName.toLowerCase().contains(s.halaqahName.toLowerCase());
      }
      return false;
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
    String finalStudentId = 'stu-${DateTime.now().millisecondsSinceEpoch}';
    final client = SupabaseService.instance.client;

    if (client != null) {
      try {
        final Map<String, dynamic> insertPayload = {
          'full_name': fullName.trim(),
          'current_juz': currentJuz,
          'current_surah': currentSurah,
          'current_ayah': currentAyah,
        };
        if (_isValidUuid(halaqahId)) {
          insertPayload['halaqah_id'] = halaqahId;
        }

        final inserted = await client
            .from('students')
            .insert(insertPayload)
            .select('id, created_at')
            .single();

        if (inserted['id'] != null) {
          finalStudentId = inserted['id'].toString();
          debugPrint('[StudentService] Persisted student to Supabase cloud: $finalStudentId');

          // Link parent in public.parent_students if valid UUID
          if (_isValidUuid(parentId)) {
            try {
              await client.from('parent_students').insert({
                'parent_id': parentId,
                'student_id': finalStudentId,
              });
              debugPrint('[StudentService] Linked parent $parentId to student $finalStudentId');
            } catch (linkError) {
              debugPrint('[StudentService] parent_students link notice: $linkError');
            }
          }
        }
      } catch (e) {
        debugPrint('[StudentService] Cloud insert fallback: $e');
      }
    }

    final newStudent = Student(
      id: finalStudentId,
      fullName: fullName,
      halaqahId: _isValidUuid(halaqahId) ? halaqahId : null,
      halaqahName: halaqahName,
      parentId: _isValidUuid(parentId) ? parentId : null,
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

    _students.removeWhere((s) => s.id == newStudent.id);
    _students.insert(0, newStudent);
    _studentsController.add(List.from(_students));

    // Persist immediately to local cache as offline fallback
    final jsonList = _students.map((s) => s.toJson()).toList();
    await LocalStorageService.instance.saveJsonList('cached_students', jsonList);

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
      markedBy: markedBy ??
          (AuthSessionService.instance.userName.isNotEmpty
              ? AuthSessionService.instance.userName
              : 'Assigned Ustaz'),
      createdAt: DateTime.now(),
    );

    if (existingIndex != -1) {
      studentHistory[existingIndex] = record;
    } else {
      studentHistory.insert(0, record);
    }

    _attendanceController.add(Map.from(_attendanceMap));

    // Supabase cloud sync (with teacher_id so RLS passes for teachers & admins)
    final client = SupabaseService.instance.client;
    if (client != null && _isValidUuid(student.id)) {
      try {
        final teacherId = AuthSessionService.instance.userId;
        final payload = <String, dynamic>{
          'student_id': student.id,
          'session_date': dateStr,
          'status': status,
          'remarks': defaultRemark,
        };
        if (_isValidUuid(teacherId)) {
          payload['teacher_id'] = teacherId;
        }
        await client
            .from('student_attendance')
            .upsert(payload, onConflict: 'student_id,session_date');
      } catch (e) {
        debugPrint('[StudentService] Cloud attendance sync notice: $e');
      }
    }

    return record;
  }

  /// Teacher Action: Mark all students in teacher's assigned class as 'present' for the day
  Future<void> markHalaqahAllPresent({
    required String halaqahName,
    String? halaqahId,
    String? markedBy,
    DateTime? date,
  }) async {
    final classStudents = getStudentsForHalaqah(halaqahName, halaqahId: halaqahId);
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

    final weekStart = DateTime.now().subtract(const Duration(days: 7));
    String reportId = 'wr-${DateTime.now().millisecondsSinceEpoch}';

    final client = SupabaseService.instance.client;
    if (client != null && _isValidUuid(student.id)) {
      try {
        final teacherId = AuthSessionService.instance.userId;
        final payload = <String, dynamic>{
          'student_id': student.id,
          'week_start_date': weekStart.toIso8601String().substring(0, 10),
          'sabaq': sabaq,
          'sabqi': sabqi,
          'manzil': manzil,
          'tajweed_rating': tajweedRating,
          'teacher_remarks': remarks,
          'attendance_days': 5,
          'mistakes_count': mistakesCount,
        };
        if (_isValidUuid(teacherId)) {
          payload['teacher_id'] = teacherId;
        }
        final inserted = await client.from('weekly_reports').insert(payload).select('id').single();
        if (inserted['id'] != null) {
          reportId = inserted['id'].toString();
        }
      } catch (e) {
        debugPrint('[StudentService] Cloud weekly report sync notice: $e');
      }
    }

    final report = WeeklyReport(
      id: reportId,
      studentId: student.id,
      studentName: student.fullName,
      weekStartDate: weekStart,
      weekEndDate: DateTime.now(),
      sabaq: sabaq,
      sabqi: sabqi,
      manzil: manzil,
      daysPresent: 5,
      totalDays: 5,
      tajweedRating: tajweedRating,
      mistakesCount: mistakesCount,
      teacherRemarks: remarks,
      teacherName: teacherName ??
          (AuthSessionService.instance.userName.isNotEmpty
              ? AuthSessionService.instance.userName
              : 'Assigned Ustaz'),
      createdAt: DateTime.now(),
    );

    _weeklyReportsMap.putIfAbsent(student.id, () => []).insert(0, report);
    _studentsController.add(List.from(_students));
  }
}
