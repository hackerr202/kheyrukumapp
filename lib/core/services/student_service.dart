import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../models/weekly_report.dart';
import '../utils/json_parsers.dart';
import 'auth_session_service.dart';
import 'local_storage_service.dart';
import 'push_notification_service.dart';
import 'supabase_service.dart';

/// Service managing student profiles, parent-student links, daily attendance,
/// and weekly Quran progress reports synced with Supabase.
class StudentService {
  StudentService._();

  static final StudentService instance = StudentService._();

  final List<Student> _students = [];
  final Map<String, List<AttendanceRecord>> _attendanceMap = {};
  final Map<String, List<WeeklyReport>> _weeklyReportsMap = {};
  final List<Map<String, String>> _cachedRegisteredParents = [];
  bool _cacheLoaded = false;

  RealtimeChannel? _attendanceRealtimeChannel;
  RealtimeChannel? _reportsRealtimeChannel;

  final StreamController<List<Student>> _studentsController =
      StreamController<List<Student>>.broadcast();

  final StreamController<Map<String, List<AttendanceRecord>>>
      _attendanceController =
      StreamController<Map<String, List<AttendanceRecord>>>.broadcast();

  Stream<List<Student>> get studentsStream => _studentsController.stream;
  Stream<Map<String, List<AttendanceRecord>>> get attendanceStream =>
      _attendanceController.stream;

  List<Student> get allStudents => List.unmodifiable(_students);

  Future<void> _loadFromCache() async {
    if (_cacheLoaded) return;
    _cacheLoaded = true;
    try {
      final cached =
          await LocalStorageService.instance.getJsonList('cached_students');
      if (cached.isNotEmpty && _students.isEmpty) {
        _students.clear();
        for (final item in cached) {
          _students.add(Student.fromJson(item));
        }
        if (!_studentsController.isClosed) {
          _studentsController.add(List.from(_students));
        }
        debugPrint(
            '[StudentService] Loaded ${_students.length} students from offline cache.');
      }
    } catch (e) {
      debugPrint('[StudentService] Cache load error: $e');
    }
  }

  /// Load offline cache first, then refresh authoritative cloud tables & Realtime.
  Future<void> refreshAll() async {
    await _loadFromCache();
    await fetchStudentsFromCloud();
    await fetchAttendanceFromCloud();
    await fetchWeeklyReportsFromCloud();
    await _subscribeRealtime();
  }

  /// Purge in-memory, cached, and Realtime state on sign-out.
  Future<void> clearOnLogout() async {
    final client = SupabaseService.instance.client;
    final attCh = _attendanceRealtimeChannel;
    final repCh = _reportsRealtimeChannel;
    _attendanceRealtimeChannel = null;
    _reportsRealtimeChannel = null;

    if (attCh != null) {
      try {
        await client?.removeChannel(attCh);
      } catch (e) {
        debugPrint('[StudentService] remove attendance channel note: $e');
      }
    }
    if (repCh != null) {
      try {
        await client?.removeChannel(repCh);
      } catch (e) {
        debugPrint('[StudentService] remove reports channel note: $e');
      }
    }

    _students.clear();
    _attendanceMap.clear();
    _weeklyReportsMap.clear();
    _cachedRegisteredParents.clear();
    _cacheLoaded = false;

    if (!_studentsController.isClosed) {
      _studentsController.add([]);
    }
    if (!_attendanceController.isClosed) {
      _attendanceController.add({});
    }
    await LocalStorageService.instance.remove('cached_students');
  }

  Future<void> _subscribeRealtime() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;

    try {
      final oldAttCh = _attendanceRealtimeChannel;
      _attendanceRealtimeChannel = null;
      if (oldAttCh != null) {
        await client.removeChannel(oldAttCh);
      }
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
              if (AuthSessionService.instance.isParent &&
                  childMatches.isNotEmpty) {
                final child = childMatches.first;
                PushNotificationService.instance.showNotification(
                  title: 'Daily Attendance: ${status.toUpperCase()}',
                  body:
                      '${child.fullName} was marked ${status.toUpperCase()} in ${child.halaqahName}. ${remarks.isNotEmpty ? "Note: $remarks" : ""}',
                  payload: 'attendance',
                  type: 'attendance',
                );
              }
            },
          )
          .subscribe();

      final oldRepCh = _reportsRealtimeChannel;
      _reportsRealtimeChannel = null;
      if (oldRepCh != null) {
        await client.removeChannel(oldRepCh);
      }
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
              if (AuthSessionService.instance.isParent &&
                  childMatches.isNotEmpty) {
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
    if (client == null || SupabaseService.instance.currentUser == null) return;
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
          final studentObj = JsonParsers.asMap(map['students']);
          if (studentObj != null) {
            map['student_name'] = studentObj['full_name'];
            map['halaqah_id'] = studentObj['halaqah_id'];
          }
          final rec = AttendanceRecord.fromJson(map);
          _attendanceMap.putIfAbsent(rec.studentId, () => []).add(rec);
        }
        if (!_attendanceController.isClosed) {
          _attendanceController.add(Map.from(_attendanceMap));
        }
      }
    } catch (e) {
      debugPrint('[StudentService] fetchAttendanceFromCloud notice: $e');
    }
  }

  /// Fetch weekly Quran progress reports from Supabase
  Future<void> fetchWeeklyReportsFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;
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
          final studentObj = JsonParsers.asMap(map['students']);
          final profObj = JsonParsers.asMap(map['profiles']);
          if (studentObj != null) {
            map['student_name'] = studentObj['full_name'];
          }
          if (profObj != null) {
            map['teacher_name'] = profObj['full_name'];
          }
          final report = WeeklyReport.fromJson(map);
          _weeklyReportsMap.putIfAbsent(report.studentId, () => []).add(report);
        }
        if (!_studentsController.isClosed) {
          _studentsController.add(List.from(_students));
        }
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

  /// Fetch enrolled students from Supabase Cloud (authoritative source — never resurrects deleted rows).
  Future<void> fetchStudentsFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;

    try {
      final res = await client
          .from('students')
          .select(
            'id, full_name, age, avatar_url, halaqah_id, current_juz, current_surah, current_ayah, date_of_birth, created_at, '
            'halaqahs:halaqah_id(name), '
            'parent_students(parent_id, profiles:parent_id(full_name, phone, email))',
          )
          .order('created_at', ascending: false)
          .limit(500);

      if (res is List) {
        final List<Student> cloudStudents = [];
        for (final item in res) {
          final map = Map<String, dynamic>.from(item as Map);
          final halaqahMap = JsonParsers.asMap(map['halaqahs']);
          if (halaqahMap != null) {
            map['halaqah_name'] = halaqahMap['name'];
          }
          final psList = map['parent_students'];
          if (psList is List && psList.isNotEmpty) {
            final firstPs = JsonParsers.asMap(psList.first);
            if (firstPs != null) {
              map['parent_id'] = firstPs['parent_id']?.toString();
              final prof = JsonParsers.asMap(firstPs['profiles']);
              if (prof != null) {
                map['parent_name'] = prof['full_name']?.toString() ?? 'Parent';
                map['parent_phone'] = prof['phone']?.toString() ?? '';
                map['parent_email'] = prof['email']?.toString();
              }
            }
          }
          cloudStudents.add(Student.fromJson(map));
        }

        _students
          ..clear()
          ..addAll(cloudStudents);
        if (!_studentsController.isClosed) {
          _studentsController.add(List.from(_students));
        }

        final jsonList = _students.map((s) => s.toJson()).toList();
        await LocalStorageService.instance
            .saveJsonList('cached_students', jsonList);
      }
    } catch (e) {
      debugPrint('[StudentService] Cloud fetch students error: $e');
    }
    await fetchRegisteredParentsFromCloud();
  }

  /// Fetch registered parents from Supabase profiles
  Future<void> fetchRegisteredParentsFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;
    try {
      final res = await client
          .from('profiles')
          .select('id, full_name, phone, email')
          .eq('role', 'parent')
          .limit(500);
      if (res is List) {
        _cachedRegisteredParents.clear();
        for (final item in res) {
          final row = Map<String, dynamic>.from(item as Map);
          _cachedRegisteredParents.add({
            'id': JsonParsers.asString(row['id']),
            'name': JsonParsers.asNullableString(row['full_name']) ?? 'Parent',
            'phone': JsonParsers.asString(row['phone']),
            'email': JsonParsers.asString(row['email']),
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

    for (final p in _cachedRegisteredParents) {
      final pid = p['id'] ?? '';
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
    if ((halaqahName.trim().isEmpty ||
            halaqahName.toLowerCase() == 'assigned halaqah') &&
        (halaqahId == null || halaqahId.isEmpty)) {
      return [];
    }
    return _students.where((s) {
      if (halaqahId != null && halaqahId.isNotEmpty && s.halaqahId == halaqahId) {
        return true;
      }
      if (halaqahName.trim().isNotEmpty &&
          halaqahName.toLowerCase() != 'assigned halaqah') {
        return s.halaqahName.toLowerCase().contains(halaqahName.toLowerCase()) ||
            halaqahName.toLowerCase().contains(s.halaqahName.toLowerCase());
      }
      return false;
    }).toList();
  }

  /// Get students for a specific parent
  List<Student> getStudentsForParent(String parentId, {String? parentEmail}) {
    return _students.where((s) {
      if (parentId.isNotEmpty && s.parentId == parentId) return true;
      if (parentEmail != null &&
          parentEmail.isNotEmpty &&
          s.parentEmail != null &&
          s.parentEmail!.toLowerCase() == parentEmail.toLowerCase()) {
        return true;
      }
      if (parentEmail != null &&
          parentEmail.isNotEmpty &&
          s.parentPhone.isNotEmpty &&
          s.parentPhone == parentEmail) {
        return true;
      }
      return false;
    }).toList();
  }

  /// Get attendance history for a student
  List<AttendanceRecord> getAttendanceForStudent(String studentId) {
    return _attendanceMap[studentId] ?? [];
  }

  /// Get attendance record for a student on a specific date
  AttendanceRecord? getTodayAttendanceForStudent(String studentId,
      {DateTime? date}) {
    final targetDate = (date ?? DateTime.now()).toIso8601String().substring(0, 10);
    final history = _attendanceMap[studentId] ?? [];
    for (final att in history) {
      if (att.date.toIso8601String().substring(0, 10) == targetDate) {
        return att;
      }
    }
    return null;
  }

  /// Get weekly reports for a student
  List<WeeklyReport> getWeeklyReportsForStudent(String studentId) {
    return _weeklyReportsMap[studentId] ?? [];
  }

  /// Admin Action: Add new student in Supabase and notify linked parent
  Future<Student> addStudent({
    required String fullName,
    required int age,
    String? avatarUrl,
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
    final client = SupabaseService.instance.client;
    if (client == null) {
      throw Exception('Unable to connect to server. Please check your connection.');
    }

    final Map<String, dynamic> insertPayload = {
      'full_name': fullName.trim(),
      'age': age,
      'current_juz': currentJuz,
      'current_surah': currentSurah,
      'current_ayah': currentAyah,
    };
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      insertPayload['avatar_url'] = avatarUrl;
    }
    if (_isValidUuid(halaqahId)) {
      insertPayload['halaqah_id'] = halaqahId;
    }

    final inserted = await client
        .from('students')
        .insert(insertPayload)
        .select('id, created_at')
        .single();

    final finalStudentId = inserted['id']?.toString() ?? '';
    if (finalStudentId.isEmpty) {
      throw Exception('Failed to save student record.');
    }

    if (_isValidUuid(parentId)) {
      try {
        await client.from('parent_students').insert({
          'parent_id': parentId,
          'student_id': finalStudentId,
        });
      } catch (linkError) {
        // Roll back unlinked student insert on parent link failure
        try {
          await client.from('students').delete().eq('id', finalStudentId);
        } catch (_) {}
        throw Exception(
            'Could not link parent account: ${SupabaseService.cleanErrorMessage(linkError)}');
      }
    }

    final newStudent = Student(
      id: finalStudentId,
      fullName: fullName.trim(),
      age: age,
      avatarUrl: avatarUrl,
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
      createdAt: JsonParsers.asDateTime(inserted['created_at']),
    );

    _students.removeWhere((s) => s.id == newStudent.id);
    _students.insert(0, newStudent);
    if (!_studentsController.isClosed) {
      _studentsController.add(List.from(_students));
    }

    final jsonList = _students.map((s) => s.toJson()).toList();
    await LocalStorageService.instance.saveJsonList('cached_students', jsonList);

    if (_isValidUuid(parentId)) {
      PushNotificationService.instance.dispatchPushToUsers(
        userIds: [parentId],
        title: 'New Student Enrolled 🎓',
        body:
            '${newStudent.fullName} has been enrolled in $halaqahName and linked to your account.',
        type: 'general',
        data: {
          'student_id': newStudent.id,
          if (halaqahId != null) 'halaqah_id': halaqahId,
        },
      );
    }

    return newStudent;
  }

  /// Admin Action: Permanently remove a student record (cloud first; consistent cache)
  Future<bool> deleteStudent(String studentId) async {
    final client = SupabaseService.instance.client;
    if (client == null || !_isValidUuid(studentId)) {
      throw Exception('Cannot delete student: invalid server connection or ID.');
    }

    await client.from('students').delete().eq('id', studentId);

    _students.removeWhere((s) => s.id == studentId);
    _attendanceMap.remove(studentId);
    _weeklyReportsMap.remove(studentId);
    if (!_studentsController.isClosed) {
      _studentsController.add(List.from(_students));
    }
    if (!_attendanceController.isClosed) {
      _attendanceController.add(Map.from(_attendanceMap));
    }

    final jsonList = _students.map((s) => s.toJson()).toList();
    await LocalStorageService.instance.saveJsonList('cached_students', jsonList);
    return true;
  }

  /// Teacher Action: Record or update daily attendance for a class student (cloud first).
  Future<AttendanceRecord> recordDailyAttendance({
    required String studentId,
    required String status,
    String? remarks,
    String? markedBy,
    DateTime? sessionDate,
  }) async {
    final client = SupabaseService.instance.client;
    if (client == null || !_isValidUuid(studentId)) {
      throw Exception('Cannot record attendance: invalid server connection or student ID.');
    }

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

    final upserted = await client
        .from('student_attendance')
        .upsert(payload, onConflict: 'student_id,session_date')
        .select('id, created_at')
        .single();

    final record = AttendanceRecord(
      id: upserted['id']?.toString() ?? '',
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
      createdAt: JsonParsers.asDateTime(upserted['created_at']),
    );

    final studentHistory = _attendanceMap.putIfAbsent(student.id, () => []);
    final existingIndex = studentHistory.indexWhere(
      (att) => att.date.toIso8601String().substring(0, 10) == dateStr,
    );
    if (existingIndex != -1) {
      studentHistory[existingIndex] = record;
    } else {
      studentHistory.insert(0, record);
    }

    if (!_attendanceController.isClosed) {
      _attendanceController.add(Map.from(_attendanceMap));
    }

    if (student.parentId != null && _isValidUuid(student.parentId)) {
      PushNotificationService.instance.dispatchPushToUsers(
        userIds: [student.parentId!],
        title: 'Daily Attendance Update',
        body: '${student.fullName} was marked ${status.toUpperCase()} ($dateStr).',
        type: 'attendance',
        data: {
          'student_id': student.id,
          'status': status,
          'date': dateStr,
        },
      );
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
    final classStudents =
        getStudentsForHalaqah(halaqahName, halaqahId: halaqahId);
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

  int _computeWeeklyAttendanceDays(String studentId, DateTime weekStart) {
    final startDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final history = _attendanceMap[studentId] ?? [];
    final attendedDates = <String>{};
    for (final att in history) {
      final attDay = DateTime(att.date.year, att.date.month, att.date.day);
      if (!attDay.isBefore(startDay) && (att.isPresent || att.isLate)) {
        attendedDates.add(attDay.toIso8601String().substring(0, 10));
      }
    }
    return attendedDates.length.clamp(0, 7);
  }

  /// Teacher/Admin Action: Generate and post weekly progress report (cloud first, real attendance count)
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
    final client = SupabaseService.instance.client;
    if (client == null || !_isValidUuid(studentId)) {
      throw Exception('Cannot save weekly report: invalid server connection or student ID.');
    }

    final studentMatches = _students.where((s) => s.id == studentId);
    final student = studentMatches.isNotEmpty
        ? studentMatches.first
        : Student(
            id: studentId,
            fullName: 'Student',
            createdAt: DateTime.now(),
          );

    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7));
    final realAttendanceDays =
        _computeWeeklyAttendanceDays(student.id, weekStart);

    final teacherId = AuthSessionService.instance.userId;
    final payload = <String, dynamic>{
      'student_id': student.id,
      'week_start_date': weekStart.toIso8601String().substring(0, 10),
      'sabaq': sabaq,
      'sabqi': sabqi,
      'manzil': manzil,
      'tajweed_rating': tajweedRating,
      'teacher_remarks': remarks,
      'attendance_days': realAttendanceDays,
      'mistakes_count': mistakesCount,
    };
    if (_isValidUuid(teacherId)) {
      payload['teacher_id'] = teacherId;
    }

    final inserted = await client
        .from('weekly_reports')
        .insert(payload)
        .select('id, created_at')
        .single();
    final reportId = inserted['id']?.toString() ?? '';

    final report = WeeklyReport(
      id: reportId,
      studentId: student.id,
      studentName: student.fullName,
      weekStartDate: weekStart,
      weekEndDate: now,
      sabaq: sabaq,
      sabqi: sabqi,
      manzil: manzil,
      daysPresent: realAttendanceDays,
      totalDays: 5,
      tajweedRating: tajweedRating,
      mistakesCount: mistakesCount,
      teacherRemarks: remarks,
      teacherName: teacherName ??
          (AuthSessionService.instance.userName.isNotEmpty
              ? AuthSessionService.instance.userName
              : 'Assigned Ustaz'),
      createdAt: JsonParsers.asDateTime(inserted['created_at']),
    );

    _weeklyReportsMap.putIfAbsent(student.id, () => []).insert(0, report);
    if (!_studentsController.isClosed) {
      _studentsController.add(List.from(_students));
    }

    if (student.parentId != null && _isValidUuid(student.parentId)) {
      PushNotificationService.instance.dispatchPushToUsers(
        userIds: [student.parentId!],
        title: 'Weekly Quran Progress Report',
        body: 'Weekly report for ${student.fullName}: $sabaq ($tajweedRating).',
        type: 'weekly_report',
        data: {
          'student_id': student.id,
          if (reportId.isNotEmpty) 'report_id': reportId,
        },
      );
    }
  }
}
