import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/homework.dart';
import 'auth_session_service.dart';
import 'halaqah_service.dart';
import 'push_notification_service.dart';
import 'student_service.dart';
import 'supabase_service.dart';

/// Reactive Homework & Tajweed Tasks Service for Kheyrukum Madrasah:
/// - Teachers create assignments for their assigned Halaqah (persisted in Supabase).
/// - Pending submissions are tracked per student.
/// - Parents mark home practice as completed with repetitions and notes.
/// - Teachers inspect practice completions and submit ratings & feedback.
class HomeworkService {
  HomeworkService._() {
    refreshAll();
  }

  static final HomeworkService instance = HomeworkService._();

  final List<HomeworkAssignment> _assignments = [];
  final List<HomeworkSubmission> _submissions = [];
  RealtimeChannel? _assignmentsChannel;
  RealtimeChannel? _submissionsChannel;

  final StreamController<List<HomeworkAssignment>> _assignmentsController =
      StreamController<List<HomeworkAssignment>>.broadcast();

  final StreamController<List<HomeworkSubmission>> _submissionsController =
      StreamController<List<HomeworkSubmission>>.broadcast();

  Stream<List<HomeworkAssignment>> get assignmentsStream => _assignmentsController.stream;
  Stream<List<HomeworkSubmission>> get submissionsStream => _submissionsController.stream;

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
    _subscribeRealtime();
  }

  Future<void> clearOnLogout() async {
    _assignmentsChannel?.unsubscribe();
    _assignmentsChannel = null;
    _submissionsChannel?.unsubscribe();
    _submissionsChannel = null;
    _assignments.clear();
    _submissions.clear();
    _assignmentsController.add([]);
    _submissionsController.add([]);
  }

  Future<void> fetchFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null) return;
    try {
      final assignRes = await client
          .from('homework_assignments')
          .select('*, halaqahs:halaqah_id(name), profiles:teacher_id(full_name)')
          .order('created_at', ascending: false);

      if (assignRes is List) {
        _assignments.clear();
        for (final item in assignRes) {
          _assignments.add(HomeworkAssignment.fromJson(Map<String, dynamic>.from(item as Map)));
        }
        _assignmentsController.add(List.from(_assignments));
      }

      final subRes = await client
          .from('homework_submissions')
          .select('*, students(full_name)')
          .order('submitted_at', ascending: false);

      if (subRes is List) {
        _submissions.clear();
        for (final item in subRes) {
          _submissions.add(HomeworkSubmission.fromJson(Map<String, dynamic>.from(item as Map)));
        }
        _submissionsController.add(List.from(_submissions));
      }
    } catch (e) {
      debugPrint('[HomeworkService] fetchFromCloud notice: $e');
    }
  }

  void _subscribeRealtime() {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;

    try {
      _assignmentsChannel?.unsubscribe();
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

      _submissionsChannel?.unsubscribe();
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

              if (status == 'completed_at_home' && AuthSessionService.instance.isTeacher) {
                PushNotificationService.instance.showNotification(
                  title: 'Homework Practiced at Home',
                  body: '$studentName completed home recitation practice.',
                  payload: 'homework',
                  type: 'homework',
                );
              } else if (status == 'reviewed' && AuthSessionService.instance.isParent) {
                final children = StudentService.instance.getStudentsForParent(
                  AuthSessionService.instance.userId,
                  parentEmail: AuthSessionService.instance.userEmail,
                );
                if (children.any((c) => c.id == studentId)) {
                  final rating = newRow['teacher_rating']?.toString() ?? 'Reviewed';
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
  List<HomeworkAssignment> getAssignmentsForStudent(String studentId, String halaqahName) {
    return getAssignmentsForHalaqah(halaqahName);
  }

  /// Get the submission state of a specific student for a given assignment
  HomeworkSubmission? getSubmission(String assignmentId, String studentId) {
    try {
      return _submissions.firstWhere(
        (sub) => sub.assignmentId == assignmentId && sub.studentId == studentId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get all submissions for an assignment
  List<HomeworkSubmission> getSubmissionsForAssignment(String assignmentId) {
    return _submissions.where((sub) => sub.assignmentId == assignmentId).toList();
  }

  /// Teacher Action: Create new homework task for their halaqah
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
      } else if (HalaqahService.instance.halaqahs.isNotEmpty &&
          _isValidUuid(HalaqahService.instance.halaqahs.first.id)) {
        resolvedHalaqahId = HalaqahService.instance.halaqahs.first.id;
      }
    }

    String resolvedTeacherId = teacherId;
    if (!_isValidUuid(resolvedTeacherId)) {
      final currentId = AuthSessionService.instance.userId;
      if (_isValidUuid(currentId)) resolvedTeacherId = currentId;
    }

    String finalId = 'hw-${DateTime.now().millisecondsSinceEpoch}';
    final client = SupabaseService.instance.client;
    if (client != null && _isValidUuid(resolvedHalaqahId) && _isValidUuid(resolvedTeacherId)) {
      try {
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
        }).select('id').single();

        if (inserted['id'] != null) {
          finalId = inserted['id'].toString();
        }
      } catch (e) {
        debugPrint('[HomeworkService] Cloud insert notice: $e');
      }
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
    _assignmentsController.add(List.from(_assignments));

    // Automatically create pending submission records for students in this halaqah
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
    _submissionsController.add(List.from(_submissions));

    return assignment;
  }

  /// Parent Action: Mark homework practiced at home
  Future<void> markCompletedByParent({
    required String assignmentId,
    required String studentId,
    required int repetitionCount,
    String? notes,
  }) async {
    final index = _submissions.indexWhere(
      (s) => s.assignmentId == assignmentId && s.studentId == studentId,
    );

    final practicedAt = DateTime.now();
    final studentMatches = StudentService.instance.allStudents.where((s) => s.id == studentId);
    final student = studentMatches.isNotEmpty ? studentMatches.first : null;
    final parentId = AuthSessionService.instance.userId;

    String subId = index != -1 ? _submissions[index].id : 'sub-$assignmentId-$studentId';

    final client = SupabaseService.instance.client;
    if (client != null && _isValidUuid(assignmentId) && _isValidUuid(studentId)) {
      try {
        if (index != -1 && _isValidUuid(subId)) {
          await client.from('homework_submissions').update({
            'status': 'completed_at_home',
            'repetition_count': repetitionCount,
            'parent_note': notes,
            'practiced_at': practicedAt.toUtc().toIso8601String(),
          }).eq('id', subId);
        } else {
          final inserted = await client.from('homework_submissions').insert({
            'assignment_id': assignmentId,
            'student_id': studentId,
            'student_name': student?.fullName ?? 'Student',
            if (_isValidUuid(parentId)) 'parent_id': parentId,
            'status': 'completed_at_home',
            'repetition_count': repetitionCount,
            'parent_note': notes,
            'practiced_at': practicedAt.toUtc().toIso8601String(),
          }).select('id').single();
          if (inserted['id'] != null) {
            subId = inserted['id'].toString();
          }
        }
      } catch (e) {
        debugPrint('[HomeworkService] Cloud submission sync notice: $e');
      }
    }

    if (index != -1) {
      final existing = _submissions[index];
      _submissions[index] = existing.copyWith(
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

    _submissionsController.add(List.from(_submissions));
  }

  /// Teacher Action: Review and endorse student's home practice
  Future<void> reviewSubmissionByTeacher({
    required String submissionId,
    required String teacherRating,
    String? teacherFeedback,
  }) async {
    final index = _submissions.indexWhere((s) => s.id == submissionId);
    if (index == -1) return;

    final reviewedAt = DateTime.now();
    final existing = _submissions[index];
    _submissions[index] = existing.copyWith(
      status: 'reviewed',
      teacherRating: teacherRating,
      teacherFeedback: teacherFeedback,
      reviewedAt: reviewedAt,
    );

    _submissionsController.add(List.from(_submissions));

    final client = SupabaseService.instance.client;
    if (client != null && _isValidUuid(submissionId)) {
      try {
        await client.from('homework_submissions').update({
          'status': 'reviewed',
          'teacher_rating': teacherRating,
          'teacher_feedback': teacherFeedback,
          'reviewed_at': reviewedAt.toUtc().toIso8601String(),
        }).eq('id', submissionId);
      } catch (e) {
        debugPrint('[HomeworkService] Cloud review sync notice: $e');
      }
    }
  }
}
