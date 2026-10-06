class MonthlyPayment {
  final String id;
  final String parentId;
  final String parentName;
  final String parentEmail;
  final String studentId;
  final String studentName;
  final String month; // e.g. "October 2026"
  final double amount; // e.g. 50.0
  final DateTime dueDate;
  final String status; // 'pending', 'submitted', 'approved', 'rejected', 'overdue'
  final String? receiptUrl;
  final String? receiptLocalMock; // Base64 or sample receipt identifier
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
    return MonthlyPayment(
      id: json['id']?.toString() ?? '',
      parentId: json['parent_id']?.toString() ?? '',
      parentName: json['parent_name']?.toString() ?? 'Parent',
      parentEmail: json['parent_email']?.toString() ?? 'parent@kheyrukum.com',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Student',
      month: json['month']?.toString() ?? 'Current Month',
      amount: (json['amount'] as num?)?.toDouble() ?? 50.0,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: json['status']?.toString() ?? 'pending',
      receiptUrl: json['receipt_url']?.toString(),
      receiptLocalMock: json['receipt_local_mock']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString())
          : null,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'].toString())
          : null,
      reviewedBy: json['reviewed_by']?.toString(),
      notes: json['notes']?.toString(),
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
