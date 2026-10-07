class Student {
  final String id;
  final String fullName;
  final String? halaqahId;
  final String halaqahName;
  final String? parentId;
  final String parentName;
  final String parentPhone;
  final String? parentEmail;
  final DateTime? dateOfBirth;
  final int currentJuz;
  final int currentSurah;
  final int currentAyah;
  final String monthlyFeeStatus; // 'paid', 'pending', 'overdue'
  final double monthlyFeeAmount;
  final DateTime createdAt;

  const Student({
    required this.id,
    required this.fullName,
    this.halaqahId,
    this.halaqahName = 'Halaqah Abu Bakr (حلقة أبي بكر)',
    this.parentId,
    this.parentName = 'Parent Account',
    this.parentPhone = '+251 91 123 4567',
    this.parentEmail,
    this.dateOfBirth,
    this.currentJuz = 30,
    this.currentSurah = 67,
    this.currentAyah = 1,
    this.monthlyFeeStatus = 'pending',
    this.monthlyFeeAmount = 50.0,
    required this.createdAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Student',
      halaqahId: json['halaqah_id']?.toString(),
      halaqahName: json['halaqah_name']?.toString() ??
          (json['halaqahs'] != null ? json['halaqahs']['name'] : 'Halaqah Abu Bakr (حلقة أبي بكر)'),
      parentId: json['parent_id']?.toString(),
      parentName: json['parent_name']?.toString() ?? 'Parent',
      parentPhone: json['parent_phone']?.toString() ?? '+251 91 123 4567',
      parentEmail: json['parent_email']?.toString(),
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'].toString())
          : null,
      currentJuz: (json['current_juz'] as num?)?.toInt() ?? 30,
      currentSurah: (json['current_surah'] as num?)?.toInt() ?? 67,
      currentAyah: (json['current_ayah'] as num?)?.toInt() ?? 1,
      monthlyFeeStatus: json['monthly_fee_status']?.toString() ?? 'pending',
      monthlyFeeAmount: (json['monthly_fee_amount'] as num?)?.toDouble() ?? 50.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'halaqah_id': halaqahId,
      'current_juz': currentJuz,
      'current_surah': currentSurah,
      'current_ayah': currentAyah,
      'date_of_birth': dateOfBirth?.toIso8601String(),
    };
  }

  Student copyWith({
    String? fullName,
    String? halaqahId,
    String? halaqahName,
    String? parentId,
    String? parentName,
    String? parentPhone,
    String? parentEmail,
    int? currentJuz,
    int? currentSurah,
    int? currentAyah,
    String? monthlyFeeStatus,
    double? monthlyFeeAmount,
  }) {
    return Student(
      id: id,
      fullName: fullName ?? this.fullName,
      halaqahId: halaqahId ?? this.halaqahId,
      halaqahName: halaqahName ?? this.halaqahName,
      parentId: parentId ?? this.parentId,
      parentName: parentName ?? this.parentName,
      parentPhone: parentPhone ?? this.parentPhone,
      parentEmail: parentEmail ?? this.parentEmail,
      dateOfBirth: dateOfBirth,
      currentJuz: currentJuz ?? this.currentJuz,
      currentSurah: currentSurah ?? this.currentSurah,
      currentAyah: currentAyah ?? this.currentAyah,
      monthlyFeeStatus: monthlyFeeStatus ?? this.monthlyFeeStatus,
      monthlyFeeAmount: monthlyFeeAmount ?? this.monthlyFeeAmount,
      createdAt: createdAt,
    );
  }
}
