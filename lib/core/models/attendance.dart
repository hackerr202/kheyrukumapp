import '../utils/json_parsers.dart';

class AttendanceRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String? halaqahId;
  final DateTime date;
  final String status; // 'present', 'absent', 'late', 'excused'
  final String? teacherRemarks;
  final String? markedBy;
  final DateTime createdAt;

  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.halaqahId,
    required this.date,
    required this.status,
    this.teacherRemarks,
    this.markedBy,
    required this.createdAt,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final rawDate = json['session_date'] ?? json['date'];
    return AttendanceRecord(
      id: JsonParsers.asString(json['id']),
      studentId: JsonParsers.asString(json['student_id']),
      studentName: JsonParsers.asNullableString(json['student_name']) ?? 'Student',
      halaqahId: JsonParsers.asNullableString(json['halaqah_id']),
      date: JsonParsers.asDateTime(rawDate),
      status: JsonParsers.asNullableString(json['status']) ?? 'present',
      teacherRemarks: JsonParsers.asNullableString(
        json['remarks'] ?? json['teacher_remarks'],
      ),
      markedBy: JsonParsers.asNullableString(json['marked_by']),
      createdAt: JsonParsers.asDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'halaqah_id': halaqahId,
      'date': date.toIso8601String().substring(0, 10),
      'status': status,
      'teacher_remarks': teacherRemarks,
      'marked_by': markedBy,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  bool get isPresent => status.toLowerCase() == 'present';
  bool get isAbsent => status.toLowerCase() == 'absent';
  bool get isLate => status.toLowerCase() == 'late';
  bool get isExcused => status.toLowerCase() == 'excused';
}
