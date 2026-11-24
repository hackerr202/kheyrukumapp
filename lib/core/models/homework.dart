import '../utils/json_parsers.dart';

/// Homework Assignment model for Quran Madrasah Halaqah classes.
class HomeworkAssignment {
  final String id;
  final String halaqahId;
  final String halaqahName;
  final String teacherId;
  final String teacherName;
  final String title;
  final String surahName;
  final int surahNumber;
  final int fromAyah;
  final int toAyah;
  final String tajweedFocus;
  final String instructions;
  final DateTime dueDate;
  final DateTime createdAt;

  const HomeworkAssignment({
    required this.id,
    required this.halaqahId,
    required this.halaqahName,
    required this.teacherId,
    required this.teacherName,
    required this.title,
    required this.surahName,
    required this.surahNumber,
    required this.fromAyah,
    required this.toAyah,
    required this.tajweedFocus,
    required this.instructions,
    required this.dueDate,
    required this.createdAt,
  });

  bool get isOverdue => DateTime.now().isAfter(dueDate);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'halaqah_id': halaqahId,
      'halaqah_name': halaqahName,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'title': title,
      'surah_name': surahName,
      'surah_number': surahNumber,
      'from_ayah': fromAyah,
      'to_ayah': toAyah,
      'tajweed_focus': tajweedFocus,
      'instructions': instructions,
      'due_date': dueDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory HomeworkAssignment.fromJson(Map<String, dynamic> json) {
    final halaqahObj = JsonParsers.asMap(json['halaqahs']);
    final profileObj = JsonParsers.asMap(json['profiles']);
    final resolvedHalaqahName =
        JsonParsers.asNullableString(json['halaqah_name']) ??
            JsonParsers.asNullableString(halaqahObj?['name']) ??
            'Halaqah Circle';
    final resolvedTeacherName =
        JsonParsers.asNullableString(json['teacher_name']) ??
            JsonParsers.asNullableString(profileObj?['full_name']) ??
            'Ustaz';
    final surahNum = JsonParsers.asInt(json['surah_number'], 1);

    return HomeworkAssignment(
      id: JsonParsers.asString(json['id']),
      halaqahId: JsonParsers.asString(json['halaqah_id']),
      halaqahName: resolvedHalaqahName,
      teacherId: JsonParsers.asString(json['teacher_id']),
      teacherName: resolvedTeacherName,
      title: JsonParsers.asNullableString(json['title']) ?? 'Quran Homework',
      surahName:
          JsonParsers.asNullableString(json['surah_name']) ?? 'Surah #$surahNum',
      surahNumber: surahNum,
      fromAyah: JsonParsers.asInt(json['from_ayah'] ?? json['ayah_start'], 1),
      toAyah: JsonParsers.asInt(json['to_ayah'] ?? json['ayah_end'], 7),
      tajweedFocus: JsonParsers.asNullableString(json['tajweed_focus']) ??
          'General Recitation',
      instructions: JsonParsers.asString(json['instructions']),
      dueDate: JsonParsers.asDateTime(
        json['due_date'],
        DateTime.now().add(const Duration(days: 3)),
      ),
      createdAt: JsonParsers.asDateTime(json['created_at']),
    );
  }
}

/// Homework Submission model representing a student's home practice completion and teacher review.
class HomeworkSubmission {
  final String id;
  final String assignmentId;
  final String studentId;
  final String studentName;
  final String parentId;
  final String status; // 'pending', 'completed_at_home', 'reviewed'
  final int repetitionCount;
  final String? parentNote;
  final DateTime? practicedAt;
  final String? teacherRating;
  final String? teacherFeedback;
  final DateTime? reviewedAt;

  const HomeworkSubmission({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.studentName,
    required this.parentId,
    required this.status,
    this.repetitionCount = 1,
    this.parentNote,
    this.practicedAt,
    this.teacherRating,
    this.teacherFeedback,
    this.reviewedAt,
  });

  bool get isCompleted => status == 'completed_at_home' || status == 'reviewed';
  bool get isReviewed => status == 'reviewed';

  HomeworkSubmission copyWith({
    String? id,
    String? status,
    int? repetitionCount,
    String? parentNote,
    DateTime? practicedAt,
    String? teacherRating,
    String? teacherFeedback,
    DateTime? reviewedAt,
  }) {
    return HomeworkSubmission(
      id: id ?? this.id,
      assignmentId: assignmentId,
      studentId: studentId,
      studentName: studentName,
      parentId: parentId,
      status: status ?? this.status,
      repetitionCount: repetitionCount ?? this.repetitionCount,
      parentNote: parentNote ?? this.parentNote,
      practicedAt: practicedAt ?? this.practicedAt,
      teacherRating: teacherRating ?? this.teacherRating,
      teacherFeedback: teacherFeedback ?? this.teacherFeedback,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignment_id': assignmentId,
      'student_id': studentId,
      'student_name': studentName,
      'parent_id': parentId,
      'status': status,
      'repetition_count': repetitionCount,
      'parent_note': parentNote,
      'practiced_at': practicedAt?.toIso8601String(),
      'teacher_rating': teacherRating,
      'teacher_feedback': teacherFeedback,
      'reviewed_at': reviewedAt?.toIso8601String(),
    };
  }

  factory HomeworkSubmission.fromJson(Map<String, dynamic> json) {
    final studentObj = JsonParsers.asMap(json['students']);
    final resolvedStudentName =
        JsonParsers.asNullableString(json['student_name']) ??
            JsonParsers.asNullableString(studentObj?['full_name']) ??
            'Student';

    return HomeworkSubmission(
      id: JsonParsers.asString(json['id']),
      assignmentId: JsonParsers.asString(json['assignment_id']),
      studentId: JsonParsers.asString(json['student_id']),
      studentName: resolvedStudentName,
      parentId: JsonParsers.asString(json['parent_id']),
      status: JsonParsers.asNullableString(json['status']) ?? 'pending',
      repetitionCount: JsonParsers.asInt(json['repetition_count'], 1),
      parentNote: JsonParsers.asNullableString(json['parent_note']),
      practicedAt: JsonParsers.asNullableDateTime(
        json['practiced_at'] ?? json['submitted_at'],
      ),
      teacherRating: JsonParsers.asNullableString(json['teacher_rating']),
      teacherFeedback: JsonParsers.asNullableString(
        json['teacher_feedback'] ?? json['teacher_feedback_text'],
      ),
      reviewedAt: JsonParsers.asNullableDateTime(json['reviewed_at']),
    );
  }
}
