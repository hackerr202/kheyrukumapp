import '../utils/json_parsers.dart';

class Student {
  final String id;
  final String fullName;
  final int age;
  final String? avatarUrl;
  final String? halaqahId;
  final String halaqahName;
  final String? parentId;
  final String parentName;
  final String parentPhone;
  final String? parentEmail;
  final DateTime? dateOfBirth;
  final String? gender; // 'male', 'female', or null
  final int currentJuz;
  final int currentSurah;
  final int currentAyah;
  final String monthlyFeeStatus; // 'paid', 'pending', 'overdue'
  final double monthlyFeeAmount;
  final DateTime createdAt;

  const Student({
    required this.id,
    required this.fullName,
    this.age = 8,
    this.avatarUrl,
    this.halaqahId,
    this.halaqahName = 'Study Circle',
    this.parentId,
    this.parentName = 'Parent',
    this.parentPhone = '',
    this.parentEmail,
    this.dateOfBirth,
    this.gender,
    this.currentJuz = 30,
    this.currentSurah = 67,
    this.currentAyah = 1,
    this.monthlyFeeStatus = 'pending',
    this.monthlyFeeAmount = 50.0,
    required this.createdAt,
  });

  static String? normalizeGender(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    if (normalized == 'male' || normalized == 'female') {
      return normalized;
    }
    return null;
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    final halaqahMap = JsonParsers.asMap(json['halaqahs']);
    return Student(
      id: JsonParsers.asString(json['id']),
      fullName: JsonParsers.asNullableString(json['full_name']) ?? 'Student',
      age: JsonParsers.asInt(json['age'], 8),
      avatarUrl: JsonParsers.asNullableString(json['avatar_url']),
      halaqahId: JsonParsers.asNullableString(json['halaqah_id']),
      halaqahName: JsonParsers.asNullableString(json['halaqah_name']) ??
          JsonParsers.asNullableString(halaqahMap?['name']) ??
          'Study Circle',
      parentId: JsonParsers.asNullableString(json['parent_id']),
      parentName: JsonParsers.asNullableString(json['parent_name']) ?? 'Parent',
      parentPhone: JsonParsers.asString(json['parent_phone']),
      parentEmail: JsonParsers.asNullableString(json['parent_email']),
      dateOfBirth: JsonParsers.asNullableDateTime(json['date_of_birth']),
      gender: normalizeGender(JsonParsers.asNullableString(json['gender'])),
      currentJuz: JsonParsers.asInt(json['current_juz'], 30),
      currentSurah: JsonParsers.asInt(json['current_surah'], 67),
      currentAyah: JsonParsers.asInt(json['current_ayah'], 1),
      monthlyFeeStatus:
          JsonParsers.asNullableString(json['monthly_fee_status']) ?? 'pending',
      monthlyFeeAmount: JsonParsers.asDouble(json['monthly_fee_amount'], 50.0),
      createdAt: JsonParsers.asDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'age': age,
      'avatar_url': avatarUrl,
      'halaqah_id': halaqahId,
      'halaqah_name': halaqahName,
      'parent_id': parentId,
      'parent_name': parentName,
      'parent_phone': parentPhone,
      'parent_email': parentEmail,
      'current_juz': currentJuz,
      'current_surah': currentSurah,
      'current_ayah': currentAyah,
      'monthly_fee_status': monthlyFeeStatus,
      'monthly_fee_amount': monthlyFeeAmount,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  Student copyWith({
    String? fullName,
    int? age,
    String? avatarUrl,
    String? halaqahId,
    String? halaqahName,
    String? parentId,
    String? parentName,
    String? parentPhone,
    String? parentEmail,
    String? gender,
    int? currentJuz,
    int? currentSurah,
    int? currentAyah,
    String? monthlyFeeStatus,
    double? monthlyFeeAmount,
  }) {
    return Student(
      id: id,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      halaqahId: halaqahId ?? this.halaqahId,
      halaqahName: halaqahName ?? this.halaqahName,
      parentId: parentId ?? this.parentId,
      parentName: parentName ?? this.parentName,
      parentPhone: parentPhone ?? this.parentPhone,
      parentEmail: parentEmail ?? this.parentEmail,
      dateOfBirth: dateOfBirth,
      gender: gender ?? this.gender,
      currentJuz: currentJuz ?? this.currentJuz,
      currentSurah: currentSurah ?? this.currentSurah,
      currentAyah: currentAyah ?? this.currentAyah,
      monthlyFeeStatus: monthlyFeeStatus ?? this.monthlyFeeStatus,
      monthlyFeeAmount: monthlyFeeAmount ?? this.monthlyFeeAmount,
      createdAt: createdAt,
    );
  }
}
