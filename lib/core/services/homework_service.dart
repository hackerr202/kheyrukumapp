import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/homework.dart';
import 'auth_session_service.dart';
import 'halaqah_service.dart';
import 'push_notification_service.dart';
import 'student_service.dart';
import 'supabase_service.dart';

/// Reactive Homework & Tajweed Tasks Service for Kheyrukum Madrasah.
class HomeworkService {
  HomeworkService._();

  static final HomeworkService instance = HomeworkService._();

  final List<HomeworkAssignment> _assignments = [];
  final List<HomeworkSubmission> _submissions = [];
  RealtimeChannel? _assignmentsChannel;
  RealtimeChannel? _submissionsChannel;

  final StreamController<List<HomeworkAssignment>> _assignmentsController =
      StreamController<List<HomeworkAssignment>>.broadcast();

  final StreamController<List<HomeworkSubmission>> _submissionsController =
      StreamController<List<HomeworkSubmission>>.broadcast();

  Stream<List<HomeworkAssignment>> get assignmentsStream =>
      _assignmentsController.stream;
  Stream<List<HomeworkSubmission>> get submissionsStream =>
      _submissionsController.stream;

  List<HomeworkAssignment> get allAssignments => List.unmodifiable(_assignments);
  List<HomeworkSubmission> get allSubmissions => List.unmodifiable(_submissions);

  static bool _isValidUuid(String? str) {
    if (str == null) return false;
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(str.trim());
  }

  Future<void> refreshAll() async {
    await fetchFromCloud();
    await _subscribeRealtime();
  }

  Future<void> clearOnLogout() async {
    final client = SupabaseService.instance.client;
    final assignCh = _assignmentsChannel;
    final subCh = _submissionsChannel;
    _assignmentsChannel = null;
    _submissionsChannel = null;

    if (assignCh != null) {
      try {
        await client?.removeChannel(assignCh);
      } catch (e) {
        debugPrint('[HomeworkService] remove assignments channel note: $e');
      }
    }
    if (subCh != null) {
      try {
        await client?.removeChannel(subCh);
      } catch (e) {
        debugPrint('[HomeworkService] remove submissions channel note: $e');
      }
    }

    _assignments.clear();
    _submissions.clear();
    if (!_assignmentsController.isClosed) {
      _assignmentsController.add([]);
    }
    if (!_submissionsController.isClosed) {
      _submissionsController.add([]);
    }
  }

  Future<void> fetchFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;
    try {
      final assignRes = await client
          .from('homework_assignments')
          .select('*, halaqahs:halaqah_id(name), profiles:teacher_id(full_name)')
          .order('created_at', ascending: false);

      if (assignRes is List) {
        _assignments.clear();
        for (final item in assignRes) {
          _assignments.add(
              HomeworkAssignment.fromJson(Map<String, dynamic>.from(item as Map)));
        }
        if (!_assignmentsController.isClosed) {
          _assignmentsController.add(List.from(_assignments));
        }
      }

      final subRes = await client
          .from('homework_submissions')
          .select('*, students(full_name)')
          .order('submitted_at', ascending: false);

      if (subRes is List) {
        _submissions.clear();
        for (final item in subRes) {
          _submissions.add(
              HomeworkSubmission.fromJson(Map<String, dynamic>.from(item as Map)));
        }
        if (!_submissionsController.isClosed) {
          _submissionsController.add(List.from(_submissions));
        }
      }
    } catch (e) {
      debugPrint('[HomeworkService] fetchFromCloud notice: $e');
    }
  }

  Future<void> _subscribeRealtime() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;

    try {
      final oldAssign = _assignmentsChannel;
      _assignmentsChannel = null;
      if (oldAssign != null) {
        await client.removeChannel(oldAssign);
      }
      _assignmentsChannel = client
          .channel('public:homework_assignments')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'homework_assignments',
            callback: (payload) async {
              await fetchFromCloud();
              final newRow = payload.newRecord;
              if (newRow.isEmpty) return;
              final halaqahId = newRow['halaqah_id']?.toString() ?? '';
              final title = newRow['title']?.toString() ?? 'Quran Homework';
              if (AuthSessionService.instance.isParent) {
                final children = StudentService.instance.getStudentsForParent(
                  AuthSessionService.instance.userId,
                  parentEmail: AuthSessionService.instance.userEmail,
                );
                if (children.any((c) => c.halaqahId == halaqahId)) {
                  PushNotificationService.instance.showNotification(
                    title: 'New Quran Homework Assigned',
                    body: title,
                    payload: 'homework',
                    type: 'homework',
                  );
                }
              }
            },
          )
          .subscribe();

      final oldSub = _submissionsChannel;
      _submissionsChannel = null;
      if (oldSub != null) {
        await client.removeChannel(oldSub);
      }
      _submissionsChannel = client
          .channel('public:homework_submissions')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'homework_submissions',
            callback: (payload) async {
              await fetchFromCloud();
              final newRow = payload.newRecord;
              if (newRow.isEmpty) return;
              final status = newRow['status']?.toString() ?? '';
              final studentName = newRow['student_name']?.toString() ?? 'Student';
              final studentId = newRow['student_id']?.toString() ?? '';
              final assignmentId = newRow['assignment_id']?.toString() ?? '';

              if (status == 'completed_at_home' &&
                  AuthSessionService.instance.isTeacher) {
                final assignMatches =
                    _assignments.where((a) => a.id == assignmentId);
                final isMyAssignment = assignMatches.isNotEmpty &&
                    (assignMatches.first.teacherId ==
                            AuthSessionService.instance.userId ||
                        assignMatches.first.halaqahId ==
                            AuthSessionService.instance.assignedHalaqahId);
                if (isMyAssignment) {
                  PushNotificationService.instance.showNotification(
                    title: 'Homework Practiced at Home',
                    body: '$studentName completed home recitation practice.',
                    payload: 'homework',
                    type: 'homework',
                  );
                }
              } else if (status == 'reviewed' &&
                  AuthSessionService.instance.isParent) {
                final children = StudentService.instance.getStudentsForParent(
                  AuthSessionService.instance.userId,
                  parentEmail: AuthSessionService.instance.userEmail,
                );
                if (children.any((c) => c.id == studentId)) {
                  final rating =
                      newRow['teacher_rating']?.toString() ?? 'Reviewed';
                  PushNotificationService.instance.showNotification(
                    title: 'Homework Reviewed by Ustaz',
                    body: '$studentName: $rating',
                    payload: 'homework_review',
                    type: 'homework_review',
                  );
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[HomeworkService] Realtime subscription note: $e');
    }
  }

  /// Get assignments assigned to a specific Halaqah (or all if empty/admin)
  List<HomeworkAssignment> getAssignmentsForHalaqah(String halaqahName) {
    if (halaqahName.trim().isEmpty || halaqahName.toLowerCase() == 'all') {
      return List.unmodifiable(_assignments);
    }
    return _assignments.where((a) {
      return a.halaqahName.toLowerCase().contains(halaqahName.toLowerCase()) ||
          halaqahName.toLowerCase().contains(a.halaqahName.toLowerCase()) ||
          (AuthSessionService.instance.assignedHalaqahId.isNotEmpty &&
              a.halaqahId == AuthSessionService.instance.assignedHalaqahId);
    }).toList();
  }

  /// Get all assignments for a student's halaqah
  List<HomeworkAssignment> getAssignmentsForStudent(
      String studentId, String halaqahName) {
    return getAssignmentsForHalaqah(halaqahName);
  }

  /// Get the submission state of a specific student for a given assignment
  HomeworkSubmission? getSubmission(String assignmentId, String studentId) {
    for (final sub in _submissions) {
      if (sub.assignmentId == assignmentId && sub.studentId == studentId) {
        return sub;
      }
    }
    return null;
  }

  /// Get all submissions for an assignment
  List<HomeworkSubmission> getSubmissionsForAssignment(String assignmentId) {
    return _submissions.where((sub) => sub.assignmentId == assignmentId).toList();
  }

  /// Teacher Action: Create new homework task for their halaqah (cloud first, no silent wrong-circle fallback)
  Future<HomeworkAssignment> createAssignment({
    required String halaqahId,
    required String halaqahName,
    required String teacherId,
    required String teacherName,
    required String title,
    required String surahName,
    required int surahNumber,
    required int fromAyah,
    required int toAyah,
    required String tajweedFocus,
    required String instructions,
    required DateTime dueDate,
  }) async {
    String resolvedHalaqahId = halaqahId;
    if (!_isValidUuid(resolvedHalaqahId)) {
      final matching = HalaqahService.instance.halaqahs.where(
        (h) => h.name.toLowerCase() == halaqahName.toLowerCase(),
      );
      if (matching.isNotEmpty && _isValidUuid(matching.first.id)) {
        resolvedHalaqahId = matching.first.id;
      }
    }

    if (!_isValidUuid(resolvedHalaqahId)) {
      throw Exception(
          'Could not resolve a valid Study Circle ID for "$halaqahName".');
    }

    String resolvedTeacherId = teacherId;
    if (!_isValidUuid(resolvedTeacherId)) {
      final currentId = AuthSessionService.instance.userId;
      if (_isValidUuid(currentId)) resolvedTeacherId = currentId;
    }

    if (!_isValidUuid(resolvedTeacherId)) {
      throw Exception('Teacher account ID is required to assign homework.');
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      throw Exception('Unable to connect to server. Please check your connection.');
    }

    final inserted = await client.from('homework_assignments').insert({
      'halaqah_id': resolvedHalaqahId,
      'halaqah_name': halaqahName,
      'teacher_id': resolvedTeacherId,
      'teacher_name': teacherName,
      'title': title.trim(),
      'surah_name': surahName.trim(),
      'surah_number': surahNumber,
      'ayah_start': fromAyah,
      'ayah_end': toAyah,
      'tajweed_focus': tajweedFocus.trim(),
      'instructions': instructions.trim(),
      'due_date': dueDate.toUtc().toIso8601String(),
    }).select('id, created_at').single();

    final finalId = inserted['id']?.toString() ?? '';
    if (finalId.isEmpty) {
      throw Exception('Failed to save homework assignment in cloud.');
    }

    final assignment = HomeworkAssignment(
      id: finalId,
      halaqahId: resolvedHalaqahId,
      halaqahName: halaqahName,
      teacherId: resolvedTeacherId,
      teacherName: teacherName,
      title: title.trim(),
      surahName: surahName.trim(),
      surahNumber: surahNumber,
      fromAyah: fromAyah,
      toAyah: toAyah,
      tajweedFocus: tajweedFocus.trim(),
      instructions: instructions.trim(),
      dueDate: dueDate,
      createdAt: DateTime.now(),
    );

    _assignments.insert(0, assignment);
    if (!_assignmentsController.isClosed) {
      _assignmentsController.add(List.from(_assignments));
    }

    final classStudents = StudentService.instance.getStudentsForHalaqah(
      halaqahName,
      halaqahId: resolvedHalaqahId,
    );
    for (final s in classStudents) {
      final sub = HomeworkSubmission(
        id: 'sub-${assignment.id}-${s.id}',
        assignmentId: assignment.id,
        studentId: s.id,
        studentName: s.fullName,
        parentId: s.parentId ?? '',
        status: 'pending',
      );
      _submissions.add(sub);
    }
    if (!_submissionsController.isClosed) {
      _submissionsController.add(List.from(_submissions));
    }

    final parentIds = classStudents
        .map((s) => s.parentId)
        .whereType<String>()
        .where((id) => _isValidUuid(id))
        .toSet()
        .toList();
    if (parentIds.isNotEmpty) {
      PushNotificationService.instance.dispatchPushToUsers(
        userIds: parentIds,
        title: 'New Homework Assigned',
        body:
            '${assignment.title} (${assignment.surahName}, Ayah ${assignment.fromAyah}-${assignment.toAyah})',
        type: 'homework',
        data: {
          'assignment_id': assignment.id,
          'halaqah_id': resolvedHalaqahId,
        },
      );
    }

    return assignment;
  }

  /// Parent Action: Mark homework practiced at home (cloud first, preserves real UUID `id`, notifies assigned teacher)
  Future<void> markCompletedByParent({
    required String assignmentId,
    required String studentId,
    required int repetitionCount,
    String? notes,
  }) async {
    final client = SupabaseService.instance.client;
    if (client == null ||
        !_isValidUuid(assignmentId) ||
        !_isValidUuid(studentId)) {
      throw Exception('Cannot submit homework: invalid connection or identifier.');
    }

    final index = _submissions.indexWhere(
      (s) => s.assignmentId == assignmentId && s.studentId == studentId,
    );

    final practicedAt = DateTime.now();
    final isoTimestamp = practicedAt.toUtc().toIso8601String();
    final studentMatches =
        StudentService.instance.allStudents.where((s) => s.id == studentId);
    final student = studentMatches.isNotEmpty ? studentMatches.first : null;
    final parentId = AuthSessionService.instance.userId;

    String subId = index != -1 ? _submissions[index].id : '';

    if (index != -1 && _isValidUuid(subId)) {
      await client.from('homework_submissions').update({
        'status': 'completed_at_home',
        'repetition_count': repetitionCount,
        'parent_note': notes,
        'practiced_at': isoTimestamp,
        'submitted_at': isoTimestamp,
      }).eq('id', subId);
    } else {
      final inserted = await client.from('homework_submissions').insert({
        'assignment_id': assignmentId,
        'student_id': studentId,
        'student_name': student?.fullName ?? 'Student',
        if (_isValidUuid(parentId)) 'parent_id': parentId,
        'audio_url': 'completed_at_home',
        'duration_seconds': 0,
        'status': 'completed_at_home',
        'repetition_count': repetitionCount,
        'parent_note': notes,
        'practiced_at': isoTimestamp,
        'submitted_at': isoTimestamp,
      }).select('id').single();
      subId = inserted['id']?.toString() ?? '';
    }

    if (subId.isEmpty) {
      throw Exception('Failed to save practice submission in cloud.');
    }

    if (index != -1) {
      final existing = _submissions[index];
      _submissions[index] = existing.copyWith(
        id: subId,
        status: 'completed_at_home',
        repetitionCount: repetitionCount,
        parentNote: notes,
        practicedAt: practicedAt,
      );
    } else {
      _submissions.add(HomeworkSubmission(
        id: subId,
        assignmentId: assignmentId,
        studentId: studentId,
        studentName: student?.fullName ?? 'Student',
        parentId: parentId,
        status: 'completed_at_home',
        repetitionCount: repetitionCount,
        parentNote: notes,
        practicedAt: practicedAt,
      ));
    }

    if (!_submissionsController.isClosed) {
      _submissionsController.add(List.from(_submissions));
    }

    // Notify only the assigned circle's teacher
    final assignMatches = _assignments.where((a) => a.id == assignmentId);
    final teacherIds = <String>{};
    if (assignMatches.isNotEmpty) {
      final assign = assignMatches.first;
      if (_isValidUuid(assign.teacherId)) {
        teacherIds.add(assign.teacherId);
      }
      final circleTeacher = HalaqahService.instance.halaqahs
          .where((h) => h.id == assign.halaqahId)
          .map((h) => h.teacherId)
          .whereType<String>()
          .where((id) => _isValidUuid(id));
      teacherIds.addAll(circleTeacher);
    }
    if (teacherIds.isNotEmpty) {
      PushNotificationService.instance.dispatchPushToUsers(
        userIds: teacherIds.toList(),
        title: 'Homework Practiced at Home',
        body:
            '${student?.fullName ?? "A student"} completed $repetitionCount repetition(s) at home.',
        type: 'homework',
        data: {'assignment_id': assignmentId, 'student_id': studentId},
      );
    }
  }

  /// Teacher Action: Review and endorse student's home practice (cloud first)
  Future<void> reviewSubmissionByTeacher({
    required String submissionId,
    required String teacherRating,
    String? teacherFeedback,
  }) async {
    final index = _submissions.indexWhere((s) => s.id == submissionId);
    if (index == -1) return;

    final client = SupabaseService.instance.client;
    if (client == null || !_isValidUuid(submissionId)) {
      throw Exception('Cannot review submission: invalid server connection or submission ID.');
    }

    final reviewedAt = DateTime.now();
    await client.from('homework_submissions').update({
      'status': 'reviewed',
      'teacher_rating': teacherRating,
      'teacher_feedback': teacherFeedback,
      'teacher_feedback_text': teacherFeedback,
      'reviewed_at': reviewedAt.toUtc().toIso8601String(),
    }).eq('id', submissionId);

    final existing = _submissions[index];
    _submissions[index] = existing.copyWith(
      status: 'reviewed',
      teacherRating: teacherRating,
      teacherFeedback: teacherFeedback,
      reviewedAt: reviewedAt,
    );

    if (!_submissionsController.isClosed) {
      _submissionsController.add(List.from(_submissions));
    }

    if (_isValidUuid(existing.parentId)) {
      PushNotificationService.instance.dispatchPushToUsers(
        userIds: [existing.parentId],
        title: 'Homework Reviewed by Ustaz',
        body: '${existing.studentName}: $teacherRating',
        type: 'homework_review',
        data: {
          'assignment_id': existing.assignmentId,
          'student_id': existing.studentId,
        },
      );
    }
  }
}
