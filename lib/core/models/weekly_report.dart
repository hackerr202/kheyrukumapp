class WeeklyReport {
  final String id;
  final String studentId;
  final String studentName;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final String sabaq; // New lesson (e.g. "Surah Al-Mulk Ayahs 1-15")
  final String sabqi; // Recent revision (e.g. "Surah Al-Mulk Ayahs 16-30")
  final String manzil; // Cumulative retention (e.g. "Juz 29")
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
    this.daysPresent = 5,
    this.totalDays = 5,
    this.tajweedRating = 'Excellent',
    this.mistakesCount = 2,
    this.teacherRemarks = 'Masha\'Allah, showing disciplined Tajweed articulation and smooth retention.',
    this.teacherName = 'Ustaz Muhammed Yakut',
    required this.createdAt,
  });

  factory WeeklyReport.fromJson(Map<String, dynamic> json) {
    return WeeklyReport(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Student',
      weekStartDate: json['week_start_date'] != null
          ? DateTime.tryParse(json['week_start_date'].toString()) ?? DateTime.now()
          : DateTime.now().subtract(const Duration(days: 7)),
      weekEndDate: json['week_end_date'] != null
          ? DateTime.tryParse(json['week_end_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sabaq: json['sabaq']?.toString() ?? 'Surah Al-Mulk (1-15)',
      sabqi: json['sabqi']?.toString() ?? 'Surah Al-Qalam (1-20)',
      manzil: json['manzil']?.toString() ?? 'Juz 29 Retention',
      daysPresent: (json['days_present'] as num?)?.toInt() ?? 5,
      totalDays: (json['total_days'] as num?)?.toInt() ?? 5,
      tajweedRating: json['tajweed_rating']?.toString() ?? 'Excellent',
      mistakesCount: (json['mistakes_count'] as num?)?.toInt() ?? 1,
      teacherRemarks: json['teacher_remarks']?.toString() ??
          'Consistent recitation with clear Makharij. Recommended for next Surah evaluation.',
      teacherName: json['teacher_name']?.toString() ?? 'Ustaz Muhammed Yakut',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
