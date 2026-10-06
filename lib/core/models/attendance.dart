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
    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Student',
      halaqahId: json['halaqah_id']?.toString(),
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: json['status']?.toString() ?? 'present',
      teacherRemarks: json['teacher_remarks']?.toString(),
      markedBy: json['marked_by']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'date': date.toIso8601String().substring(0, 10),
      'status': status,
      'teacher_remarks': teacherRemarks,
      'marked_by': markedBy,
    };
  }

  bool get isPresent => status.toLowerCase() == 'present';
  bool get isAbsent => status.toLowerCase() == 'absent';
  bool get isLate => status.toLowerCase() == 'late';
  bool get isExcused => status.toLowerCase() == 'excused';
}
