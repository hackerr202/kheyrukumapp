import '../utils/json_parsers.dart';

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
      id: JsonParsers.asString(json['id']),
      code: JsonParsers.asString(json['code']),
      role: (JsonParsers.asNullableString(json['role']) ?? 'parent')
          .toLowerCase(),
      targetEmail: JsonParsers.asNullableString(json['target_email']),
      linkedStudentId: JsonParsers.asNullableString(json['linked_student_id']),
      targetHalaqahId: JsonParsers.asNullableString(json['target_halaqah_id']),
      isUsed: JsonParsers.asBool(json['is_used']),
      usedBy: JsonParsers.asNullableString(json['used_by']),
      usedAt: JsonParsers.asNullableDateTime(json['used_at']),
      expiresAt: JsonParsers.asDateTime(
        json['expires_at'],
        DateTime.now().add(const Duration(days: 30)),
      ),
      createdAt: JsonParsers.asDateTime(json['created_at']),
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
      'expires_at': expiresAt.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isUsed && !isExpired;
}
