import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/homework.dart';
import 'notification_center_service.dart';
import 'student_service.dart';
import 'supabase_service.dart';

/// Reactive Homework & Tajweed Tasks Service for Kheyrukum Madrasah:
/// - Teachers create assignments for their assigned Halaqah.
/// - Pending submissions are tracked per student.
/// - Parents mark home practice as completed with repetitions and notes.
/// - Teachers inspect practice completions and submit ratings & feedback.
class HomeworkService {
  HomeworkService._();

  static final HomeworkService instance = HomeworkService._();

  final List<HomeworkAssignment> _assignments = [];
  final List<HomeworkSubmission> _submissions = [];

  final StreamController<List<HomeworkAssignment>> _assignmentsController =
      StreamController<List<HomeworkAssignment>>.broadcast();

  final StreamController<List<HomeworkSubmission>> _submissionsController =
      StreamController<List<HomeworkSubmission>>.broadcast();

  Stream<List<HomeworkAssignment>> get assignmentsStream => _assignmentsController.stream;
  Stream<List<HomeworkSubmission>> get submissionsStream => _submissionsController.stream;

  List<HomeworkAssignment> get allAssignments => List.unmodifiable(_assignments);
  List<HomeworkSubmission> get allSubmissions => List.unmodifiable(_submissions);

  /// Get assignments assigned to a specific Halaqah (or all if empty/admin)
  List<HomeworkAssignment> getAssignmentsForHalaqah(String halaqahName) {
    if (halaqahName.trim().isEmpty || halaqahName.toLowerCase() == 'all') {
      return List.unmodifiable(_assignments);
    }
    return _assignments.where((a) {
      return a.halaqahName.toLowerCase().contains(halaqahName.toLowerCase()) ||
          halaqahName.toLowerCase().contains(a.halaqahName.toLowerCase());
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
    final assignment = HomeworkAssignment(
      id: 'hw-${DateTime.now().millisecondsSinceEpoch}',
      halaqahId: halaqahId,
      halaqahName: halaqahName,
      teacherId: teacherId,
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
    final classStudents = StudentService.instance.getStudentsForHalaqah(halaqahName);
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

    // DISPATCH NOTIFICATION TO PARENTS
    NotificationCenterService.instance.addNotification(
      title: 'New Quran Homework Assigned 📖',
      body: '$teacherName assigned $title ($surahName: $fromAyah–$toAyah) for $halaqahName. Due: ${dueDate.toIso8601String().substring(0, 10)}.',
      type: 'homework',
      data: {
        'assignment_id': assignment.id,
        'halaqah_name': halaqahName,
      },
    );

    // Cloud sync to Supabase if connected
    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        await client.from('homework_assignments').insert(assignment.toJson());
      } catch (e) {
        debugPrint('[HomeworkService] Cloud insert fallback: $e');
      }
    }

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

    if (index != -1) {
      final existing = _submissions[index];
      _submissions[index] = existing.copyWith(
        status: 'completed_at_home',
        repetitionCount: repetitionCount,
        parentNote: notes,
        practicedAt: practicedAt,
      );
    } else {
      // Find student and assignment details to construct submission
      final assignment = _assignments.firstWhere(
        (a) => a.id == assignmentId,
        orElse: () => _assignments.first,
      );
      final student = StudentService.instance.allStudents.firstWhere(
        (s) => s.id == studentId,
        orElse: () => StudentService.instance.allStudents.first,
      );

      _submissions.add(HomeworkSubmission(
        id: 'sub-$assignmentId-$studentId',
        assignmentId: assignment.id,
        studentId: student.id,
        studentName: student.fullName,
        parentId: student.parentId ?? '',
        status: 'completed_at_home',
        repetitionCount: repetitionCount,
        parentNote: notes,
        practicedAt: practicedAt,
      ));
    }

    _submissionsController.add(List.from(_submissions));

    // DISPATCH NOTIFICATION TO TEACHER
    final assignment = _assignments.firstWhere((a) => a.id == assignmentId, orElse: () => _assignments.first);
    final student = StudentService.instance.allStudents.firstWhere((s) => s.id == studentId, orElse: () => StudentService.instance.allStudents.first);

    NotificationCenterService.instance.addNotification(
      title: 'Homework Practiced at Home ✅',
      body: '${student.fullName} has completed recitation practice for ${assignment.title} ($repetitionCount repetitions). Parent note: ${notes ?? "Done"}',
      type: 'homework',
      data: {
        'assignment_id': assignmentId,
        'student_id': studentId,
      },
    );
  }

  /// Teacher Action: Review and endorse student's home practice
  Future<void> reviewSubmissionByTeacher({
    required String submissionId,
    required String teacherRating,
    String? teacherFeedback,
  }) async {
    final index = _submissions.indexWhere((s) => s.id == submissionId);
    if (index == -1) return;

    final existing = _submissions[index];
    _submissions[index] = existing.copyWith(
      status: 'reviewed',
      teacherRating: teacherRating,
      teacherFeedback: teacherFeedback,
      reviewedAt: DateTime.now(),
    );

    _submissionsController.add(List.from(_submissions));

    // DISPATCH NOTIFICATION TO PARENT
    NotificationCenterService.instance.addNotification(
      title: 'Homework Reviewed by Ustaz 🌟',
      body: 'Recitation for ${existing.studentName} was reviewed: $teacherRating. Feedback: ${teacherFeedback ?? "Masha\'Allah excellent effort."}',
      type: 'homework',
      data: {
        'submission_id': submissionId,
        'student_id': existing.studentId,
        'rating': teacherRating,
      },
    );
  }
}
