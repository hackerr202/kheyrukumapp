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
    final halaqahObj = json['halaqahs'];
    final profileObj = json['profiles'];
    final resolvedHalaqahName = json['halaqah_name']?.toString() ??
        (halaqahObj is Map ? halaqahObj['name']?.toString() : null) ??
        'Halaqah Circle';
    final resolvedTeacherName = json['teacher_name']?.toString() ??
        (profileObj is Map ? profileObj['full_name']?.toString() : null) ??
        'Ustaz';

    return HomeworkAssignment(
      id: json['id']?.toString() ?? '',
      halaqahId: json['halaqah_id']?.toString() ?? '',
      halaqahName: resolvedHalaqahName,
      teacherId: json['teacher_id']?.toString() ?? '',
      teacherName: resolvedTeacherName,
      title: json['title']?.toString() ?? 'Quran Homework',
      surahName: json['surah_name']?.toString() ?? 'Surah #${json['surah_number'] ?? 1}',
      surahNumber: (json['surah_number'] as num?)?.toInt() ?? 1,
      fromAyah: ((json['from_ayah'] ?? json['ayah_start']) as num?)?.toInt() ?? 1,
      toAyah: ((json['to_ayah'] ?? json['ayah_end']) as num?)?.toInt() ?? 7,
      tajweedFocus: json['tajweed_focus']?.toString() ?? 'General Recitation',
      instructions: json['instructions']?.toString() ?? '',
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now().add(const Duration(days: 3))
          : DateTime.now().add(const Duration(days: 3)),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
  final String? teacherRating; // e.g. 'Mumtaz (ممتاز)', 'Jayyid Jiddan (جيد جداً)', 'Jayyid (جيد)'
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
    String? status,
    int? repetitionCount,
    String? parentNote,
    DateTime? practicedAt,
    String? teacherRating,
    String? teacherFeedback,
    DateTime? reviewedAt,
  }) {
    return HomeworkSubmission(
      id: id,
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
    final studentObj = json['students'];
    final resolvedStudentName = json['student_name']?.toString() ??
        (studentObj is Map ? studentObj['full_name']?.toString() : null) ??
        'Student';

    return HomeworkSubmission(
      id: json['id']?.toString() ?? '',
      assignmentId: json['assignment_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: resolvedStudentName,
      parentId: json['parent_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      repetitionCount: (json['repetition_count'] as num?)?.toInt() ?? 1,
      parentNote: json['parent_note']?.toString(),
      practicedAt: json['practiced_at'] != null
          ? DateTime.tryParse(json['practiced_at'].toString())
          : null,
      teacherRating: json['teacher_rating']?.toString(),
      teacherFeedback: json['teacher_feedback']?.toString(),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'].toString())
          : null,
    );
  }
}
