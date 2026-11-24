import '../utils/json_parsers.dart';

class CenterPaymentChannel {
  final String id;
  final String labelKey;
  final String accountName;
  final String accountNumber;
  final int displayOrder;

  const CenterPaymentChannel({
    required this.id,
    required this.labelKey,
    this.accountName = '',
    required this.accountNumber,
    this.displayOrder = 0,
  });

  factory CenterPaymentChannel.fromJson(Map<String, dynamic> json) {
    return CenterPaymentChannel(
      id: JsonParsers.asString(json['id']),
      labelKey: JsonParsers.asNullableString(json['label_key']) ?? 'cbeBankName',
      accountName: JsonParsers.asString(json['account_name']),
      accountNumber: JsonParsers.asString(json['account_number']),
      displayOrder: JsonParsers.asInt(json['display_order'], 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label_key': labelKey,
      'account_name': accountName,
      'account_number': accountNumber,
      'display_order': displayOrder,
    };
  }
}

class MonthlyPayment {
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool looksLikeUuid(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isNotEmpty && _uuidPattern.hasMatch(trimmed);
  }

  final String id;
  final String parentId;
  final String parentName;
  final String parentEmail;
  final String studentId;
  final String studentName;
  final String month;
  final double amount;
  final DateTime dueDate;
  final DateTime feeStartDate;
  final String status; // 'pending', 'submitted', 'approved', 'rejected', 'overdue'
  final String? receiptUrl;
  final String? receiptLocalMock;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? verifiedByName;
  final String? notes;

  const MonthlyPayment({
    required this.id,
    required this.parentId,
    required this.parentName,
    required this.parentEmail,
    required this.studentId,
    required this.studentName,
    required this.month,
    required this.amount,
    required this.dueDate,
    required this.feeStartDate,
    this.status = 'pending',
    this.receiptUrl,
    this.receiptLocalMock,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.verifiedByName,
    this.notes,
  });

  factory MonthlyPayment.fromJson(Map<String, dynamic> json) {
    final due = JsonParsers.asDateTime(json['due_date']);
    return MonthlyPayment(
      id: JsonParsers.asString(json['id']),
      parentId: JsonParsers.asString(json['parent_id']),
      parentName: JsonParsers.asNullableString(json['parent_name']) ?? 'Parent',
      parentEmail: JsonParsers.asString(json['parent_email']),
      studentId: JsonParsers.asString(json['student_id']),
      studentName: JsonParsers.asNullableString(json['student_name']) ?? 'Student',
      month: JsonParsers.asNullableString(json['month'] ?? json['month_year']) ??
          'Current Month',
      amount: JsonParsers.asDouble(json['amount'], 0.0),
      dueDate: due,
      feeStartDate: JsonParsers.asDateTime(json['fee_start_date'], due),
      status: JsonParsers.asNullableString(json['status']) ?? 'pending',
      receiptUrl: JsonParsers.asNullableString(json['receipt_url']),
      receiptLocalMock: JsonParsers.asNullableString(json['receipt_local_mock']),
      rejectionReason: JsonParsers.asNullableString(json['rejection_reason']),
      submittedAt: JsonParsers.asNullableDateTime(json['submitted_at']),
      reviewedAt: JsonParsers.asNullableDateTime(json['reviewed_at']),
      reviewedBy: JsonParsers.asNullableString(json['reviewed_by']),
      verifiedByName: JsonParsers.asNullableString(json['verified_by_name']),
      notes: JsonParsers.asNullableString(json['notes']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parent_id': parentId,
      'parent_name': parentName,
      'parent_email': parentEmail,
      'student_id': studentId,
      'student_name': studentName,
      'month': month,
      'amount': amount,
      'due_date': dueDate.toIso8601String(),
      'fee_start_date': feeStartDate.toIso8601String().substring(0, 10),
      'status': status,
      'receipt_url': receiptUrl,
      'receipt_local_mock': receiptLocalMock,
      'rejection_reason': rejectionReason,
      'submitted_at': submittedAt?.toUtc().toIso8601String(),
      'reviewed_at': reviewedAt?.toUtc().toIso8601String(),
      'reviewed_by': reviewedBy,
      'verified_by_name': verifiedByName,
      'notes': notes,
    };
  }

  /// Safe human-readable reviewer name; never returns a raw Postgres UUID.
  String? get displayReviewerName {
    final named = verifiedByName?.trim();
    if (named != null && named.isNotEmpty && !looksLikeUuid(named)) {
      return named;
    }
    final fallback = reviewedBy?.trim();
    if (fallback != null && fallback.isNotEmpty && !looksLikeUuid(fallback)) {
      return fallback;
    }
    return null;
  }

  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';
  bool get isSubmitted => status.toLowerCase() == 'submitted';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isOverdue => status.toLowerCase() == 'overdue';
  bool get hasReceipt =>
      (receiptUrl != null && receiptUrl!.isNotEmpty) ||
      (receiptLocalMock != null && receiptLocalMock!.isNotEmpty);

  MonthlyPayment copyWith({
    DateTime? feeStartDate,
    String? status,
    String? receiptUrl,
    String? receiptLocalMock,
    String? rejectionReason,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? verifiedByName,
    String? notes,
  }) {
    return MonthlyPayment(
      id: id,
      parentId: parentId,
      parentName: parentName,
      parentEmail: parentEmail,
      studentId: studentId,
      studentName: studentName,
      month: month,
      amount: amount,
      dueDate: dueDate,
      feeStartDate: feeStartDate ?? this.feeStartDate,
      status: status ?? this.status,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      receiptLocalMock: receiptLocalMock ?? this.receiptLocalMock,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      verifiedByName: verifiedByName ?? this.verifiedByName,
      notes: notes ?? this.notes,
    );
  }
}
