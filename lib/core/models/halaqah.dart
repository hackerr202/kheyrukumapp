/// Halaqah (Study Circle) model representing a memorization and Tajweed class.
class Halaqah {
  final String id;
  final String name;
  final String? teacherId;
  final String teacherName;
  final String schedule;
  final String description;
  final int studentCount;
  final DateTime createdAt;

  const Halaqah({
    required this.id,
    required this.name,
    this.teacherId,
    this.teacherName = 'Unassigned',
    this.schedule = 'Daily Recitation Session',
    this.description = '',
    this.studentCount = 0,
    required this.createdAt,
  });

  factory Halaqah.fromJson(Map<String, dynamic> json) {
    return Halaqah(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Study Circle',
      teacherId: json['teacher_id']?.toString(),
      teacherName: json['teacher_name']?.toString() ??
          (json['profiles'] != null ? json['profiles']['full_name'] : 'Unassigned'),
      schedule: json['schedule']?.toString() ?? 'Daily Recitation Session',
      description: json['description']?.toString() ?? '',
      studentCount: (json['student_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (teacherId != null) 'teacher_id': teacherId,
      'teacher_name': teacherName,
      'schedule': schedule,
      'description': description,
      'student_count': studentCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Halaqah copyWith({
    String? id,
    String? name,
    String? teacherId,
    String? teacherName,
    String? schedule,
    String? description,
    int? studentCount,
    DateTime? createdAt,
  }) {
    return Halaqah(
      id: id ?? this.id,
      name: name ?? this.name,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      schedule: schedule ?? this.schedule,
      description: description ?? this.description,
      studentCount: studentCount ?? this.studentCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
