import '../utils/json_parsers.dart';

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
    final profileMap = JsonParsers.asMap(json['profiles']);
    return Halaqah(
      id: JsonParsers.asString(json['id']),
      name: JsonParsers.asNullableString(json['name']) ?? 'Study Circle',
      teacherId: JsonParsers.asNullableString(json['teacher_id']),
      teacherName: JsonParsers.asNullableString(json['teacher_name']) ??
          JsonParsers.asNullableString(profileMap?['full_name']) ??
          'Unassigned',
      schedule: JsonParsers.asNullableString(json['schedule']) ??
          'Daily Recitation Session',
      description: JsonParsers.asString(json['description']),
      studentCount: JsonParsers.asInt(json['student_count'], 0),
      createdAt: JsonParsers.asDateTime(json['created_at']),
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
