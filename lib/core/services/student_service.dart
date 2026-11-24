import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../models/weekly_report.dart';
import '../utils/json_parsers.dart';
import '../utils/uuid_v4.dart';
import 'auth_session_service.dart';
import 'connectivity_service.dart';
import 'local_storage_service.dart';
import 'offline_sync_service.dart';
import 'push_notification_service.dart';
import 'supabase_service.dart';

/// Service managing student profiles, parent-student links, daily attendance,
/// and weekly Quran progress reports synced with Supabase and user-scoped offline caches.
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

  String get _uid => AuthSessionService.instance.userId.isNotEmpty
      ? AuthSessionService.instance.userId
      : (SupabaseService.instance.currentUser?.id ?? '');

  Future<void> _saveStudentsCache() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    await LocalStorageService.instance.saveUserJsonList(
      uid,
      'students',
      _students.map((s) => s.toJson()).toList(),
    );
  }

  Future<void> _saveAttendanceCache() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    final flat = <Map<String, dynamic>>[];
    for (final list in _attendanceMap.values) {
      for (final rec in list) {
        flat.add(rec.toJson());
      }
    }
    await LocalStorageService.instance.saveUserJsonList(
      uid,
      'attendance',
      flat,
    );
  }

  Future<void> _saveReportsCache() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    final flat = <Map<String, dynamic>>[];
    for (final list in _weeklyReportsMap.values) {
      for (final rep in list) {
        flat.add(rep.toJson());
      }
    }
    await LocalStorageService.instance.saveUserJsonList(
      uid,
      'weekly_reports',
      flat,
    );
  }

  Future<void> _saveRegisteredParentsCache() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    await LocalStorageService.instance.saveUserJsonList(
      uid,
      'registered_parents',
      _cachedRegisteredParents
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }

  void _applyPendingStudentOverlays() {
    final pending = OfflineSyncService.instance
        .pendingMutationsForEntity(OfflineEntityTypes.student);
    for (final mut in pending) {
      final p = mut.payload;
      final id = p['id']?.toString() ?? mut.id;
      if (id.isEmpty) continue;
      final student = Student(
        id: id,
        fullName: p['full_name']?.toString() ?? 'Student',
        age: JsonParsers.asInt(p['age'], 8),
        avatarUrl: p['avatar_url']?.toString(),
        halaqahId: p['halaqah_id']?.toString(),
        halaqahName: p['_halaqah_name']?.toString() ?? 'Assigned Halaqah',
        parentId: p['_parent_id']?.toString(),
        parentName: p['_parent_name']?.toString() ?? 'Parent',
        parentPhone: p['_parent_phone']?.toString() ?? '',
        parentEmail: p['_parent_email']?.toString(),
        currentJuz: JsonParsers.asInt(p['current_juz'], 1),
        currentSurah: JsonParsers.asInt(p['current_surah'], 1),
        currentAyah: JsonParsers.asInt(p['current_ayah'], 1),
        monthlyFeeStatus: 'pending',
        monthlyFeeAmount: 50.0,
        createdAt: JsonParsers.asDateTime(p['created_at'], mut.createdAt),
      );
      _students.removeWhere((s) => s.id == id);
      _students.insert(0, student);
    }
  }

  void _applyPendingAttendanceOverlays() {
    final pending = OfflineSyncService.instance
        .pendingMutationsForEntity(OfflineEntityTypes.attendance);
    for (final mut in pending) {
      final p = mut.payload;
      final studentId = p['student_id']?.toString() ?? '';
      final dateStr = p['session_date']?.toString() ?? '';
      if (studentId.isEmpty || dateStr.isEmpty) continue;
      final studentMatches = _students.where((s) => s.id == studentId);
      final student = studentMatches.isNotEmpty ? studentMatches.first : null;
      final rec = AttendanceRecord(
        id: p['id']?.toString() ?? mut.id,
        studentId: studentId,
        studentName: student?.fullName ??
            p['_student_name']?.toString() ??
            'Student',
        halaqahId: student?.halaqahId,
        date: JsonParsers.asDateTime(dateStr, mut.createdAt),
        status: p['status']?.toString() ?? 'present',
        teacherRemarks: p['remarks']?.toString(),
        markedBy: p['_marked_by']?.toString(),
        createdAt: mut.createdAt.toLocal(),
      );
      final list = _attendanceMap.putIfAbsent(studentId, () => []);
      final existingIdx = list.indexWhere(
        (att) => att.date.toIso8601String().substring(0, 10) == dateStr,
      );
      if (existingIdx != -1) {
        list[existingIdx] = rec;
      } else {
        list.insert(0, rec);
      }
    }
  }

  void _applyPendingReportOverlays() {
    final pending = OfflineSyncService.instance
        .pendingMutationsForEntity(OfflineEntityTypes.weeklyReport);
    for (final mut in pending) {
      final p = mut.payload;
      final studentId = p['student_id']?.toString() ?? '';
      final reportId = p['id']?.toString() ?? mut.id;
      if (studentId.isEmpty || reportId.isEmpty) continue;
      final studentMatches = _students.where((s) => s.id == studentId);
      final student = studentMatches.isNotEmpty ? studentMatches.first : null;
      final report = WeeklyReport(
        id: reportId,
        studentId: studentId,
        studentName: student?.fullName ??
            p['_student_name']?.toString() ??
            'Student',
        weekStartDate: JsonParsers.asDateTime(
          p['week_start_date'],
          mut.createdAt.subtract(const Duration(days: 7)),
        ),
        weekEndDate: JsonParsers.asDateTime(
          p['_week_end_date'],
          mut.createdAt,
        ),
        sabaq: p['sabaq']?.toString() ?? '',
        sabqi: p['sabqi']?.toString() ?? '',
        manzil: p['manzil']?.toString() ?? '',
        daysPresent: JsonParsers.asInt(p['attendance_days'], 0),
        totalDays: 5,
        tajweedRating: p['tajweed_rating']?.toString() ?? 'Good',
        mistakesCount: JsonParsers.asInt(p['mistakes_count'], 0),
        teacherRemarks: p['teacher_remarks']?.toString() ?? '',
        teacherName: p['_teacher_name']?.toString() ?? 'Assigned Ustaz',
        createdAt: mut.createdAt.toLocal(),
      );
      final list = _weeklyReportsMap.putIfAbsent(studentId, () => []);
      list.removeWhere((r) => r.id == reportId);
      list.insert(0, report);
    }
  }

  Future<void> _loadFromCache() async {
    if (_cacheLoaded) return;
    final uid = _uid;
    if (uid.isEmpty) return;
    _cacheLoaded = true;
    try {
      final cachedStudents =
          await LocalStorageService.instance.getUserJsonList(uid, 'students');
      if (cachedStudents.isNotEmpty && _students.isEmpty) {
        _students.clear();
        for (final item in cachedStudents) {
          _students.add(Student.fromJson(item));
        }
      }
      _applyPendingStudentOverlays();
      if (_students.isNotEmpty && !_studentsController.isClosed) {
        _studentsController.add(List.from(_students));
      }

      final cachedAtt =
          await LocalStorageService.instance.getUserJsonList(uid, 'attendance');
      if (cachedAtt.isNotEmpty && _attendanceMap.isEmpty) {
        for (final item in cachedAtt) {
          final rec = AttendanceRecord.fromJson(item);
          _attendanceMap.putIfAbsent(rec.studentId, () => []).add(rec);
        }
      }
      _applyPendingAttendanceOverlays();
      if (_attendanceMap.isNotEmpty && !_attendanceController.isClosed) {
        _attendanceController.add(Map.from(_attendanceMap));
      }

      final cachedReps = await LocalStorageService.instance
          .getUserJsonList(uid, 'weekly_reports');
      if (cachedReps.isNotEmpty && _weeklyReportsMap.isEmpty) {
        for (final item in cachedReps) {
          final rep = WeeklyReport.fromJson(item);
          _weeklyReportsMap.putIfAbsent(rep.studentId, () => []).add(rep);
        }
      }
      _applyPendingReportOverlays();
      if (_weeklyReportsMap.isNotEmpty && !_studentsController.isClosed) {
        _studentsController.add(List.from(_students));
      }

      final cachedParents = await LocalStorageService.instance
          .getUserJsonList(uid, 'registered_parents');
      if (cachedParents.isNotEmpty && _cachedRegisteredParents.isEmpty) {
        for (final item in cachedParents) {
          _cachedRegisteredParents.add({
            'id': JsonParsers.asString(item['id']),
            'name': JsonParsers.asNullableString(item['name']) ?? 'Parent',
            'phone': JsonParsers.asString(item['phone']),
            'email': JsonParsers.asString(item['email']),
          });
        }
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
    final uid = _uid;
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
    if (uid.isNotEmpty) {
      await LocalStorageService.instance.removeUserCache(uid, 'students');
      await LocalStorageService.instance.removeUserCache(uid, 'attendance');
      await LocalStorageService.instance.removeUserCache(uid, 'weekly_reports');
      await LocalStorageService.instance
          .removeUserCache(uid, 'registered_parents');
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

  /// Fetch daily attendance records from Supabase (preserving pending offline marks).
  Future<void> fetchAttendanceFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;
    if (!ConnectivityService.instance.isOnline) return;
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
        _applyPendingAttendanceOverlays();
        if (!_attendanceController.isClosed) {
          _attendanceController.add(Map.from(_attendanceMap));
        }
        await _saveAttendanceCache();
      }
    } catch (e) {
      debugPrint('[StudentService] fetchAttendanceFromCloud notice: $e');
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
      }
    }
  }

  /// Fetch weekly Quran progress reports from Supabase (preserving pending offline reports).
  Future<void> fetchWeeklyReportsFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;
    if (!ConnectivityService.instance.isOnline) return;
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
        _applyPendingReportOverlays();
        if (!_studentsController.isClosed) {
          _studentsController.add(List.from(_students));
        }
        await _saveReportsCache();
      }
    } catch (e) {
      debugPrint('[StudentService] fetchWeeklyReportsFromCloud notice: $e');
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
      }
    }
  }

  static bool _isValidUuid(String? str) => UuidV4.isValid(str);

  /// Fetch enrolled students from Supabase Cloud (preserving pending offline additions).
  Future<void> fetchStudentsFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;
    if (!ConnectivityService.instance.isOnline) return;

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
        _applyPendingStudentOverlays();
        if (!_studentsController.isClosed) {
          _studentsController.add(List.from(_students));
        }
        await _saveStudentsCache();
      }
    } catch (e) {
      debugPrint('[StudentService] Cloud fetch students error: $e');
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
      }
    }
    await fetchRegisteredParentsFromCloud();
  }

  /// Fetch registered parents from Supabase profiles.
  Future<void> fetchRegisteredParentsFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;
    if (!ConnectivityService.instance.isOnline) return;
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
        await _saveRegisteredParentsCache();
      }
    } catch (e) {
      debugPrint('[StudentService] Cloud fetch parents notice: $e');
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
      }
    }
  }

  /// Get list of all distinct registered parents for easy admin selection when enrolling students.
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

  /// Get students belonging to a specific Halaqah (Class).
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

  /// Get students for a specific parent.
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

  /// Get attendance history for a student.
  List<AttendanceRecord> getAttendanceForStudent(String studentId) {
    return _attendanceMap[studentId] ?? [];
  }

  /// Get attendance record for a student on a specific date.
  AttendanceRecord? getTodayAttendanceForStudent(
    String studentId, {
    DateTime? date,
  }) {
    final targetDate = (date ?? DateTime.now()).toIso8601String().substring(0, 10);
    final history = _attendanceMap[studentId] ?? [];
    for (final att in history) {
      if (att.date.toIso8601String().substring(0, 10) == targetDate) {
        return att;
      }
    }
    return null;
  }

  /// Get weekly reports for a student.
  List<WeeklyReport> getWeeklyReportsForStudent(String studentId) {
    return _weeklyReportsMap[studentId] ?? [];
  }

  /// Admin Action: Add new student (online-first, automatically queues offline with genuine UUID v4).
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
    final studentId = UuidV4.generate();
    final createdAt = DateTime.now();
    final createdAtIso = createdAt.toUtc().toIso8601String();

    final Map<String, dynamic> insertPayload = {
      'id': studentId,
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

    Future<Student> applyLocally({required bool queueOffline}) async {
      final newStudent = Student(
        id: studentId,
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
        createdAt: createdAt,
      );

      _students.removeWhere((s) => s.id == newStudent.id);
      _students.insert(0, newStudent);
      if (!_studentsController.isClosed) {
        _studentsController.add(List.from(_students));
      }
      await _saveStudentsCache();

      if (queueOffline) {
        await OfflineSyncService.instance.enqueue(
          entityType: OfflineEntityTypes.student,
          operation: 'upsert',
          id: studentId,
          payload: {
            ...insertPayload,
            'created_at': createdAtIso,
            '_halaqah_name': halaqahName,
            if (_isValidUuid(parentId)) '_parent_id': parentId,
            '_parent_name': parentName,
            '_parent_phone': parentPhone,
            if (parentEmail != null) '_parent_email': parentEmail,
          },
          displayLabel: 'Enroll: ${fullName.trim()}',
          triggerImmediateSync: false,
        );
      }
      return newStudent;
    }

    final client = SupabaseService.instance.client;
    if (!ConnectivityService.instance.isOnline || client == null) {
      return await applyLocally(queueOffline: true);
    }

    try {
      final inserted = await client
          .from('students')
          .upsert(insertPayload, onConflict: 'id')
          .select('id, created_at')
          .single();

      final finalStudentId = inserted['id']?.toString() ?? studentId;
      if (_isValidUuid(parentId)) {
        try {
          await client.from('parent_students').insert({
            'parent_id': parentId,
            'student_id': finalStudentId,
          });
        } catch (linkError) {
          try {
            await client.from('students').delete().eq('id', finalStudentId);
          } catch (_) {}
          throw Exception(
            'Could not link parent account: ${SupabaseService.cleanErrorMessage(linkError)}',
          );
        }
      }

      final syncedStudent = await applyLocally(queueOffline: false);
      if (_isValidUuid(parentId)) {
        PushNotificationService.instance.dispatchPushToUsers(
          userIds: [parentId],
          title: 'New Student Enrolled 🎓',
          body:
              '${syncedStudent.fullName} has been enrolled in $halaqahName and linked to your account.',
          type: 'general',
          data: {
            'student_id': syncedStudent.id,
            if (halaqahId != null) 'halaqah_id': halaqahId,
          },
        );
      }
      return syncedStudent;
    } catch (e) {
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
        return await applyLocally(queueOffline: true);
      }
      rethrow;
    }
  }

  /// Admin Action: Permanently remove a student record (online required).
  Future<bool> deleteStudent(String studentId) async {
    if (!ConnectivityService.instance.isOnline &&
        !await ConnectivityService.instance.checkNow()) {
      throw const OfflineActionException();
    }

    final client = SupabaseService.instance.client;
    if (client == null || !_isValidUuid(studentId)) {
      throw Exception(
          'Cannot delete student: invalid server connection or ID.');
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

    await _saveStudentsCache();
    await _saveAttendanceCache();
    await _saveReportsCache();
    return true;
  }

  /// Teacher Action: Record or update daily attendance (works seamlessly offline & online).
  Future<AttendanceRecord> recordDailyAttendance({
    required String studentId,
    required String status,
    String? remarks,
    String? markedBy,
    DateTime? sessionDate,
  }) async {
    if (!_isValidUuid(studentId)) {
      throw Exception('Cannot record attendance: invalid student ID.');
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
                : (status == 'absent'
                    ? 'Absent from halaqah'
                    : 'Excused absence')));

    final teacherId = AuthSessionService.instance.userId;
    final resolvedMarkedBy = markedBy ??
        (AuthSessionService.instance.userName.isNotEmpty
            ? AuthSessionService.instance.userName
            : 'Assigned Ustaz');

    final existingAtt = getTodayAttendanceForStudent(student.id, date: date);
    final localId =
        (existingAtt != null && _isValidUuid(existingAtt.id))
            ? existingAtt.id
            : UuidV4.generate();

    final payload = <String, dynamic>{
      'student_id': student.id,
      'session_date': dateStr,
      'status': status,
      'remarks': defaultRemark,
    };
    if (_isValidUuid(teacherId)) {
      payload['teacher_id'] = teacherId;
    }

    Future<AttendanceRecord> applyLocally({
      required String resolvedId,
      required DateTime createdAt,
      required bool queueOffline,
    }) async {
      final record = AttendanceRecord(
        id: resolvedId,
        studentId: student.id,
        studentName: student.fullName,
        halaqahId: student.halaqahId,
        date: date,
        status: status,
        teacherRemarks: defaultRemark,
        markedBy: resolvedMarkedBy,
        createdAt: createdAt,
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
      await _saveAttendanceCache();

      if (queueOffline) {
        await OfflineSyncService.instance.enqueue(
          entityType: OfflineEntityTypes.attendance,
          operation: 'upsert',
          id: resolvedId,
          payload: {
            ...payload,
            'id': resolvedId,
            '_student_name': student.fullName,
            '_marked_by': resolvedMarkedBy,
          },
          displayLabel: 'Attendance: ${student.fullName} ($status)',
          triggerImmediateSync: false,
        );
      }
      return record;
    }

    final client = SupabaseService.instance.client;
    if (!ConnectivityService.instance.isOnline || client == null) {
      return await applyLocally(
        resolvedId: localId,
        createdAt: DateTime.now(),
        queueOffline: true,
      );
    }

    try {
      final upserted = await client
          .from('student_attendance')
          .upsert(payload, onConflict: 'student_id,session_date')
          .select('id, created_at')
          .single();

      final record = await applyLocally(
        resolvedId: upserted['id']?.toString() ?? localId,
        createdAt: JsonParsers.asDateTime(upserted['created_at']),
        queueOffline: false,
      );

      if (student.parentId != null && _isValidUuid(student.parentId)) {
        PushNotificationService.instance.dispatchPushToUsers(
          userIds: [student.parentId!],
          title: 'Daily Attendance Update',
          body:
              '${student.fullName} was marked ${status.toUpperCase()} ($dateStr).',
          type: 'attendance',
          data: {
            'student_id': student.id,
            'status': status,
            'date': dateStr,
          },
        );
      }
      return record;
    } catch (e) {
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
        return await applyLocally(
          resolvedId: localId,
          createdAt: DateTime.now(),
          queueOffline: true,
        );
      }
      rethrow;
    }
  }

  /// Teacher Action: Mark all students in teacher's assigned class as 'present' for the day.
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

  /// Teacher/Admin Action: Post weekly progress report (works offline & online cleanly).
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
    if (!_isValidUuid(studentId)) {
      throw Exception('Cannot save weekly report: invalid student ID.');
    }

    final studentMatches = _students.where((s) => s.id == studentId);
    final student = studentMatches.isNotEmpty
        ? studentMatches.first
        : Student(
            id: studentId,
            fullName: 'Student',
            createdAt: DateTime.now(),
          );

    final reportId = UuidV4.generate();
    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7));
    final realAttendanceDays =
        _computeWeeklyAttendanceDays(student.id, weekStart);

    final teacherId = AuthSessionService.instance.userId;
    final resolvedTeacherName = teacherName ??
        (AuthSessionService.instance.userName.isNotEmpty
            ? AuthSessionService.instance.userName
            : 'Assigned Ustaz');

    final payload = <String, dynamic>{
      'id': reportId,
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

    Future<void> applyLocally({
      required String resolvedId,
      required DateTime createdAt,
      required bool queueOffline,
    }) async {
      final report = WeeklyReport(
        id: resolvedId,
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
        teacherName: resolvedTeacherName,
        createdAt: createdAt,
      );

      final list = _weeklyReportsMap.putIfAbsent(student.id, () => []);
      list.removeWhere((r) => r.id == resolvedId);
      list.insert(0, report);
      if (!_studentsController.isClosed) {
        _studentsController.add(List.from(_students));
      }
      await _saveReportsCache();

      if (queueOffline) {
        await OfflineSyncService.instance.enqueue(
          entityType: OfflineEntityTypes.weeklyReport,
          operation: 'upsert',
          id: resolvedId,
          payload: {
            ...payload,
            '_student_name': student.fullName,
            '_teacher_name': resolvedTeacherName,
            '_week_end_date': now.toUtc().toIso8601String(),
          },
          displayLabel: 'Weekly Report: ${student.fullName}',
          triggerImmediateSync: false,
        );
      }
    }

    final client = SupabaseService.instance.client;
    if (!ConnectivityService.instance.isOnline || client == null) {
      await applyLocally(
        resolvedId: reportId,
        createdAt: now,
        queueOffline: true,
      );
      return;
    }

    try {
      final inserted = await client
          .from('weekly_reports')
          .upsert(payload, onConflict: 'id')
          .select('id, created_at')
          .single();
      final finalId = inserted['id']?.toString() ?? reportId;

      await applyLocally(
        resolvedId: finalId,
        createdAt: JsonParsers.asDateTime(inserted['created_at']),
        queueOffline: false,
      );

      if (student.parentId != null && _isValidUuid(student.parentId)) {
        PushNotificationService.instance.dispatchPushToUsers(
          userIds: [student.parentId!],
          title: 'Weekly Quran Progress Report',
          body:
              'Weekly report for ${student.fullName}: $sabaq ($tajweedRating).',
          type: 'weekly_report',
          data: {
            'student_id': student.id,
            if (finalId.isNotEmpty) 'report_id': finalId,
          },
        );
      }
    } catch (e) {
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
        await applyLocally(
          resolvedId: reportId,
          createdAt: now,
          queueOffline: true,
        );
        return;
      }
      rethrow;
    }
  }
}
