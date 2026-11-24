import '../utils/json_parsers.dart';

class WeeklyReport {
  final String id;
  final String studentId;
  final String studentName;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final String sabaq;
  final String sabqi;
  final String manzil;
  final int daysPresent;
  final int totalDays;
  final String tajweedRating; // 'Excellent', 'Very Good', 'Good', 'Needs Revision'
  final int mistakesCount;
  final String teacherRemarks;
  final String teacherName;
  final DateTime createdAt;

  const WeeklyReport({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.sabaq,
    required this.sabqi,
    required this.manzil,
    this.daysPresent = 0,
    this.totalDays = 5,
    this.tajweedRating = 'Good',
    this.mistakesCount = 0,
    this.teacherRemarks = '',
    this.teacherName = 'Assigned Teacher',
    required this.createdAt,
  });

  factory WeeklyReport.fromJson(Map<String, dynamic> json) {
    final daysPresent = JsonParsers.asNullableInt(json['attendance_days']) ??
        JsonParsers.asInt(json['days_present'], 0);
    return WeeklyReport(
      id: JsonParsers.asString(json['id']),
      studentId: JsonParsers.asString(json['student_id']),
      studentName: JsonParsers.asNullableString(json['student_name']) ?? 'Student',
      weekStartDate: JsonParsers.asDateTime(
        json['week_start_date'],
        DateTime.now().subtract(const Duration(days: 7)),
      ),
      weekEndDate: JsonParsers.asDateTime(json['week_end_date']),
      sabaq: JsonParsers.asString(json['sabaq']),
      sabqi: JsonParsers.asString(json['sabqi']),
      manzil: JsonParsers.asString(json['manzil']),
      daysPresent: daysPresent,
      totalDays: JsonParsers.asInt(json['total_days'], 5),
      tajweedRating:
          JsonParsers.asNullableString(json['tajweed_rating']) ?? 'Good',
      mistakesCount: JsonParsers.asInt(json['mistakes_count'], 0),
      teacherRemarks: JsonParsers.asString(json['teacher_remarks']),
      teacherName: JsonParsers.asNullableString(json['teacher_name']) ??
          'Assigned Teacher',
      createdAt: JsonParsers.asDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'week_start_date': weekStartDate.toIso8601String().substring(0, 10),
      'week_end_date': weekEndDate.toIso8601String().substring(0, 10),
      'sabaq': sabaq,
      'sabqi': sabqi,
      'manzil': manzil,
      'days_present': daysPresent,
      'total_days': totalDays,
      'tajweed_rating': tajweedRating,
      'mistakes_count': mistakesCount,
      'teacher_remarks': teacherRemarks,
      'teacher_name': teacherName,
    };
  }
}
