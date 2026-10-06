import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/payment.dart';
import 'notification_center_service.dart';

/// Payment & Tuition Service managing:
/// - Monthly payment generation (salary/tuition)
/// - Parent receipt screenshot submission
/// - Admin receipt inspection, approval, and rejection with custom reason
/// - Admin overdue notifications
/// - Account suspension & removal for unpaid accounts
class PaymentService {
  PaymentService._();

  static final PaymentService instance = PaymentService._();

  final List<MonthlyPayment> _payments = [];
  final StreamController<List<MonthlyPayment>> _paymentsController =
      StreamController<List<MonthlyPayment>>.broadcast();

  Stream<List<MonthlyPayment>> get paymentsStream => _paymentsController.stream;
  List<MonthlyPayment> get allPayments => List.unmodifiable(_payments);

  // User account status tracking: 'active', 'suspended', 'removed'
  final Map<String, String> _userAccountStatus = {};
  final Map<String, String> _suspensionReasons = {};

  /// Admin issues a monthly tuition fee invoice for a student
  Future<MonthlyPayment> createPaymentInvoice({
    required String studentId,
    required String studentName,
    required String parentId,
    required String parentName,
    required String parentEmail,
    required String month,
    required double amount,
    required DateTime dueDate,
  }) async {
    final payment = MonthlyPayment(
      id: 'pay-${DateTime.now().millisecondsSinceEpoch}',
      parentId: parentId,
      parentName: parentName,
      parentEmail: parentEmail,
      studentId: studentId,
      studentName: studentName,
      month: month,
      amount: amount,
      dueDate: dueDate,
      status: 'pending',
    );

    _payments.insert(0, payment);
    _paymentsController.add(List.from(_payments));

    // Notify parent
    NotificationCenterService.instance.addNotification(
      title: 'Monthly Tuition Due 💳',
      body: 'Tuition for $studentName ($month - \$${amount.toStringAsFixed(0)}) is due on ${dueDate.toIso8601String().substring(0, 10)}.',
      type: 'payment_reminder',
      data: {'payment_id': payment.id, 'student_id': studentId},
    );

    return payment;
  }

  /// Get payments for a specific parent
  List<MonthlyPayment> getPaymentsForParent(String parentId, {String? parentEmail}) {
    return _payments.where((p) {
      if (p.parentId == parentId) return true;
      if (parentEmail != null && p.parentEmail.toLowerCase() == parentEmail.toLowerCase()) return true;
      return false;
    }).toList();
  }

  /// Parent uploads a receipt screenshot for verification
  Future<void> submitPaymentReceipt({
    required String paymentId,
    required String receiptMockId, // e.g. 'telebirr_proof' or local file reference
    String? customNote,
  }) async {
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index == -1) return;

    final existing = _payments[index];
    final updated = existing.copyWith(
      status: 'submitted',
      receiptLocalMock: receiptMockId,
      submittedAt: DateTime.now(),
      notes: customNote ?? 'Receipt uploaded by parent. Awaiting admin review.',
      rejectionReason: null, // Clear any previous rejection
    );

    _payments[index] = updated;
    _paymentsController.add(List.from(_payments));

    // ADMIN NOTIFICATION: Payment submitted
    NotificationCenterService.instance.addNotification(
      title: 'Payment Verification Received 📥',
      body: '${updated.parentName} submitted a receipt screenshot for ${updated.studentName} (${updated.month} - \$${updated.amount.toStringAsFixed(0)}). Review required.',
      type: 'payment_approval',
      data: {'payment_id': updated.id, 'parent_id': updated.parentId},
    );
  }

  /// Admin approves the payment
  Future<void> approvePayment({
    required String paymentId,
    String? adminName = 'Ustaz Muhammed Yakut',
  }) async {
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index == -1) return;

    final existing = _payments[index];
    final updated = existing.copyWith(
      status: 'approved',
      reviewedAt: DateTime.now(),
      reviewedBy: adminName,
      rejectionReason: null,
    );

    _payments[index] = updated;
    _paymentsController.add(List.from(_payments));

    // PARENT NOTIFICATION: Payment approved!
    NotificationCenterService.instance.addNotification(
      title: 'Payment Approved ✅',
      body: 'Your payment of \$${updated.amount.toStringAsFixed(0)} for ${updated.studentName} (${updated.month}) has been verified and approved.',
      type: 'payment_approval',
      data: {'payment_id': updated.id, 'status': 'approved'},
    );
  }

  /// Admin rejects the payment with a mandatory reason (displayed on parent side)
  Future<void> rejectPayment({
    required String paymentId,
    required String reason,
    String? adminName = 'Ustaz Muhammed Yakut',
  }) async {
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index == -1) return;

    final existing = _payments[index];
    final updated = existing.copyWith(
      status: 'rejected',
      rejectionReason: reason,
      reviewedAt: DateTime.now(),
      reviewedBy: adminName,
    );

    _payments[index] = updated;
    _paymentsController.add(List.from(_payments));

    // PARENT NOTIFICATION: Payment rejected with specific reason
    NotificationCenterService.instance.addNotification(
      title: 'Payment Verification Rejected ❌',
      body: 'Payment for ${updated.studentName} (${updated.month}) could not be verified. Reason: "$reason". Please upload a clear receipt.',
      type: 'payment_rejection',
      data: {'payment_id': updated.id, 'reason': reason},
    );
  }

  /// Trigger monthly payment reminder to parents
  void sendMonthlyTuitionReminder(String month) {
    NotificationCenterService.instance.addNotification(
      title: 'Monthly Halaqah Tuition Reminder 💳',
      body: 'Monthly Quran memorization fee for $month is now due. Please submit your payment and upload receipt proof.',
      type: 'payment_reminder',
      data: {'month': month},
    );
  }

  /// Trigger overdue tuition alert to Admin
  void sendOverdueAlertToAdmin(MonthlyPayment payment) {
    NotificationCenterService.instance.addNotification(
      title: 'Overdue Tuition Alert ⚠️',
      body: 'Payment for student ${payment.studentName} (Parent: ${payment.parentName}) is past due date for ${payment.month}.',
      type: 'payment_overdue',
      data: {'payment_id': payment.id, 'parent_id': payment.parentId},
    );
  }

  // ---------------------------------------------------------------------------
  // USER SUSPENSION & REMOVAL CONTROLS (ADMIN)
  // ---------------------------------------------------------------------------

  String getUserStatus(String userId) {
    return _userAccountStatus[userId] ?? 'active';
  }

  String? getSuspensionReason(String userId) {
    return _suspensionReasons[userId];
  }

  bool isUserSuspended(String userId) {
    return getUserStatus(userId) == 'suspended';
  }

  bool isUserRemoved(String userId) {
    return getUserStatus(userId) == 'removed';
  }

  /// Admin suspends user due to unpaid fees or disciplinary issues
  Future<void> suspendUser({
    required String userId,
    required String userName,
    required String reason,
  }) async {
    _userAccountStatus[userId] = 'suspended';
    _suspensionReasons[userId] = reason;

    NotificationCenterService.instance.addNotification(
      title: 'Account Temporarily Suspended 🚫',
      body: 'Account for $userName has been suspended. Reason: $reason',
      type: 'payment_overdue',
      data: {'user_id': userId, 'status': 'suspended'},
    );
  }

  /// Admin restores suspended user
  Future<void> restoreUser(String userId) async {
    _userAccountStatus[userId] = 'active';
    _suspensionReasons.remove(userId);
  }

  /// Admin removes user permanently
  Future<void> removeUser(String userId) async {
    _userAccountStatus[userId] = 'removed';
    _suspensionReasons[userId] = 'Account has been removed from the portal by administrator.';
  }
}
