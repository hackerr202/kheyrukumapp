import '../utils/json_parsers.dart';

/// Model representing an Excused Absence Request submitted by a parent for their child.
class AbsenceRequest {
  final String id;
  final String studentId;
  final String studentName;
  final String halaqahId;
  final String halaqahName;
  final String parentId;
  final String parentName;
  final String parentPhone;
  final DateTime date;
  final String reason; // 'illness', 'family_emergency', 'school_exam', 'travel', 'other'
  final String notes;
  final String status; // 'pending', 'approved', 'declined'
  final String? reviewedBy;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const AbsenceRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.halaqahId,
    required this.halaqahName,
    required this.parentId,
    required this.parentName,
    required this.parentPhone,
    required this.date,
    required this.reason,
    required this.notes,
    required this.status,
    this.reviewedBy,
    required this.createdAt,
    this.reviewedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDeclined => status == 'declined';

  String get reasonLabel {
    switch (reason.toLowerCase()) {
      case 'illness':
        return 'Medical / Illness 🤒';
      case 'family_emergency':
        return 'Family Emergency 🚨';
      case 'school_exam':
        return 'School Academic Exam 📚';
      case 'travel':
        return 'Travel / Out of Town ✈️';
      default:
        return 'Personal Reason 📝';
    }
  }

  AbsenceRequest copyWith({
    String? status,
    String? reviewedBy,
    DateTime? reviewedAt,
  }) {
    return AbsenceRequest(
      id: id,
      studentId: studentId,
      studentName: studentName,
      halaqahId: halaqahId,
      halaqahName: halaqahName,
      parentId: parentId,
      parentName: parentName,
      parentPhone: parentPhone,
      date: date,
      reason: reason,
      notes: notes,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      createdAt: createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'halaqah_id': halaqahId,
      'halaqah_name': halaqahName,
      'parent_id': parentId,
      'parent_name': parentName,
      'parent_phone': parentPhone,
      'date': date.toIso8601String(),
      'reason': reason,
      'notes': notes,
      'status': status,
      'reviewed_by': reviewedBy,
      'created_at': createdAt.toUtc().toIso8601String(),
      'reviewed_at': reviewedAt?.toUtc().toIso8601String(),
    };
  }

  factory AbsenceRequest.fromJson(Map<String, dynamic> json) {
    return AbsenceRequest(
      id: JsonParsers.asString(json['id']),
      studentId: JsonParsers.asString(json['student_id']),
      studentName: JsonParsers.asNullableString(json['student_name']) ?? 'Student',
      halaqahId: JsonParsers.asString(json['halaqah_id']),
      halaqahName:
          JsonParsers.asNullableString(json['halaqah_name']) ?? 'Halaqah Circle',
      parentId: JsonParsers.asString(json['parent_id']),
      parentName: JsonParsers.asNullableString(json['parent_name']) ?? 'Parent',
      parentPhone: JsonParsers.asString(json['parent_phone']),
      date: JsonParsers.asDateTime(json['date']),
      reason: JsonParsers.asNullableString(json['reason']) ?? 'illness',
      notes: JsonParsers.asString(json['notes']),
      status: JsonParsers.asNullableString(json['status']) ?? 'pending',
      reviewedBy: JsonParsers.asNullableString(json['reviewed_by']),
      createdAt: JsonParsers.asDateTime(json['created_at']),
      reviewedAt: JsonParsers.asNullableDateTime(json['reviewed_at']),
    );
  }
}
