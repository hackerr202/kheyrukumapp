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
      'created_at': createdAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
    };
  }

  factory AbsenceRequest.fromJson(Map<String, dynamic> json) {
    return AbsenceRequest(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      studentName: json['student_name'] as String? ?? 'Student',
      halaqahId: json['halaqah_id'] as String? ?? 'halaqah-001',
      halaqahName: json['halaqah_name'] as String? ?? 'Halaqah Circle',
      parentId: json['parent_id'] as String? ?? '',
      parentName: json['parent_name'] as String? ?? 'Parent',
      parentPhone: json['parent_phone'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      reason: json['reason'] as String? ?? 'illness',
      notes: json['notes'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      reviewedBy: json['reviewed_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
    );
  }
}
