import '../utils/json_parsers.dart';

class MonthlyPayment {
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
      notes: JsonParsers.asNullableString(json['notes']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parent_id': parentId,
      'student_id': studentId,
      'month': month,
      'amount': amount,
      'due_date': dueDate.toIso8601String(),
      'fee_start_date': feeStartDate.toIso8601String().substring(0, 10),
      'status': status,
      'receipt_url': receiptUrl,
      'receipt_local_mock': receiptLocalMock,
      'rejection_reason': rejectionReason,
      'submitted_at': submittedAt?.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewed_by': reviewedBy,
      'notes': notes,
    };
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
      notes: notes ?? this.notes,
    );
  }
}
