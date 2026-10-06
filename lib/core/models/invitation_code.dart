/// Model representing an Admin-Generated Signup Invitation Code
class InvitationCode {
  final String id;
  final String code;
  final String role; // 'teacher' or 'parent'
  final String? targetEmail;
  final String? linkedStudentId;
  final String? targetHalaqahId;
  final bool isUsed;
  final String? usedBy;
  final DateTime? usedAt;
  final DateTime expiresAt;
  final DateTime createdAt;

  const InvitationCode({
    required this.id,
    required this.code,
    required this.role,
    this.targetEmail,
    this.linkedStudentId,
    this.targetHalaqahId,
    this.isUsed = false,
    this.usedBy,
    this.usedAt,
    required this.expiresAt,
    required this.createdAt,
  });

  factory InvitationCode.fromJson(Map<String, dynamic> json) {
    return InvitationCode(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      role: (json['role'] as String? ?? 'parent').toLowerCase(),
      targetEmail: json['target_email'] as String?,
      linkedStudentId: json['linked_student_id'] as String?,
      targetHalaqahId: json['target_halaqah_id'] as String?,
      isUsed: json['is_used'] as bool? ?? false,
      usedBy: json['used_by'] as String?,
      usedAt: json['used_at'] != null ? DateTime.tryParse(json['used_at'].toString()) : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString()) ?? DateTime.now().add(const Duration(days: 30))
          : DateTime.now().add(const Duration(days: 30)),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'role': role,
      'target_email': targetEmail,
      'linked_student_id': linkedStudentId,
      'target_halaqah_id': targetHalaqahId,
      'is_used': isUsed,
      'expires_at': expiresAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isUsed && !isExpired;
}
