import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment.dart';
import 'auth_session_service.dart';
import 'notification_center_service.dart';
import 'push_notification_service.dart';
import 'storage_service.dart';
import 'supabase_service.dart';

/// Payment & Tuition Service backed by the Supabase `monthly_payments` table.
///
/// - Admin issues invoices (rows in `monthly_payments`)
/// - Parent uploads a real receipt image to Supabase Storage and submits it
/// - Admin approves / rejects with reason
/// - Changes are streamed to every device through Supabase Realtime, and the
///   affected parent / admin gets a system notification while the app is running.
class PaymentService {
  PaymentService._() {
    _init();
  }

  static final PaymentService instance = PaymentService._();

  /// Storage bucket used for receipt screenshots (public bucket, already
  /// covered by authenticated upload/read policies in supabase_schema.sql).
  static const String receiptsBucket = StorageService.chatAttachmentsBucket;

  static const String _selectColumns =
      '*, student:students!student_id(full_name), parent:profiles!parent_id(full_name, email)';

  final List<MonthlyPayment> _payments = [];
  final StreamController<List<MonthlyPayment>> _paymentsController =
      StreamController<List<MonthlyPayment>>.broadcast();
  RealtimeChannel? _channel;

  Stream<List<MonthlyPayment>> get paymentsStream => _paymentsController.stream;
  List<MonthlyPayment> get allPayments => List.unmodifiable(_payments);

  void _emit() => _paymentsController.add(List.from(_payments));

  void _init() {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;
    refresh();
    try {
      _channel?.unsubscribe();
      _channel = client
          .channel('public:monthly_payments')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'monthly_payments',
            callback: (payload) => _handleRealtimeChange(payload),
          )
          .subscribe();
    } catch (e) {
      debugPrint('[PaymentService] Realtime subscription error: $e');
    }
  }

  Future<void> refreshAndSubscribe() async {
    _init();
  }

  /// Reload all payments visible to the current user (RLS restricts parents to their own rows).
  Future<void> refresh() async {
    final client = SupabaseService.instance.client;
    if (client == null) return;
    try {
      final res = await client
          .from('monthly_payments')
          .select(_selectColumns)
          .order('created_at', ascending: false);
      _payments
        ..clear()
        ..addAll((res as List)
            .map((e) => _fromRow(Map<String, dynamic>.from(e as Map))));
      _emit();
    } catch (e) {
      debugPrint('[PaymentService] Failed to load payments: $e');
    }
  }

  MonthlyPayment _fromRow(Map<String, dynamic> row) {
    final student = row['student'];
    final parent = row['parent'];
    final json = Map<String, dynamic>.from(row);
    json['month'] = row['month_year'] ?? row['month'];
    if (student is Map && student['full_name'] != null) {
      json['student_name'] = student['full_name'];
    }
    if (parent is Map) {
      if (parent['full_name'] != null) json['parent_name'] = parent['full_name'];
      if (parent['email'] != null) json['parent_email'] = parent['email'];
    }
    if (json['amount'] is String) {
      json['amount'] = double.tryParse(json['amount'] as String);
    }
    return MonthlyPayment.fromJson(json);
  }

  Future<void> _handleRealtimeChange(PostgresChangePayload payload) async {
    final userId = AuthSessionService.instance.userId;
    final isAdmin = AuthSessionService.instance.isAdmin;
    final newRow = payload.newRecord;
    final oldRow = payload.oldRecord;

    if (payload.eventType == PostgresChangeEvent.delete) {
      final id = oldRow['id']?.toString();
      _payments.removeWhere((p) => p.id == id);
      _emit();
      return;
    }

    final oldStatus = oldRow['status']?.toString();
    final newStatus = newRow['status']?.toString();
    final parentId = newRow['parent_id']?.toString();

    await refresh();

    if (oldStatus == newStatus && payload.eventType == PostgresChangeEvent.update) {
      return;
    }
    final month = newRow['month_year']?.toString() ?? '';
    final amount = newRow['amount']?.toString() ?? '';

    if (!isAdmin && parentId == userId) {
      if (payload.eventType == PostgresChangeEvent.insert) {
        _notify('Monthly Tuition Due 💳', 'A tuition invoice for $month ($amount) has been issued.', 'payment_reminder');
      } else if (newStatus == 'approved') {
        _notify('Payment Approved ✅', 'Your payment for $month has been verified and approved.', 'payment_approval');
      } else if (newStatus == 'rejected') {
        final reason = newRow['rejection_reason']?.toString() ?? '';
        _notify('Payment Rejected ❌', 'Payment for $month could not be verified. Reason: "$reason".', 'payment_overdue');
      }
    } else if (isAdmin && newStatus == 'submitted') {
      _notify('Payment Receipt Received 📥', 'A parent submitted a receipt for $month. Review required.', 'payment_approval');
    }
  }

  void _notify(String title, String body, String type) {
    PushNotificationService.instance.showNotification(title: title, body: body, payload: type, type: type);
  }

  /// Admin issues a monthly tuition fee invoice for a student
  Future<MonthlyPayment?> createPaymentInvoice({
    required String studentId,
    required String studentName,
    required String parentId,
    required String parentName,
    required String parentEmail,
    required String month,
    required double amount,
    required DateTime dueDate,
    required DateTime feeStartDate,
  }) async {
    final client = SupabaseService.instance.client;
    if (client == null) throw Exception('Not connected to the server.');
    if (!AuthSessionService.instance.isSuperAdmin) {
      throw Exception(
        'Access Denied: Only Super Administrators can issue fees or manage payments.',
      );
    }
    if (parentId.isEmpty) {
      throw Exception('$studentName has no linked parent account yet.');
    }
    final res = await client
        .from('monthly_payments')
        .insert({
          'parent_id': parentId,
          'student_id': studentId,
          'month_year': month,
          'amount': amount,
          'due_date': dueDate.toIso8601String().substring(0, 10),
          'fee_start_date': feeStartDate.toIso8601String().substring(0, 10),
          'status': 'pending',
        })
        .select(_selectColumns)
        .single();
    final payment = _fromRow(Map<String, dynamic>.from(res));
    _payments.removeWhere((p) => p.id == payment.id);
    _payments.insert(0, payment);
    _emit();

    // 1. Persist notification in public.notifications for closed-app retrieval
    try {
      await client.from('notifications').insert({
        'user_id': parentId,
        'title': 'Monthly Tuition Fee Due 💳',
        'body':
            'Tuition for $month (${amount.toStringAsFixed(0)}) starting on ${feeStartDate.toLocal().toString().substring(0, 10)} has been issued for $studentName.',
        'type': 'payment_reminder',
        'data': {
          'payment_id': payment.id,
          'student_id': studentId,
          'month': month,
          'fee_start_date': feeStartDate.toIso8601String().substring(0, 10),
        },
      });
    } catch (e) {
      debugPrint('[PaymentService] Notification log error: $e');
    }

    // 2. Dispatch push notification to parent
    PushNotificationService.instance.dispatchPushToUsers(
      userIds: [parentId],
      title: 'Monthly Tuition Due 💳',
      body:
          'A tuition invoice for $month (${amount.toStringAsFixed(0)}) starting on ${feeStartDate.toLocal().toString().substring(0, 10)} has been issued for $studentName.',
      type: 'payment_reminder',
      data: {
        'payment_id': payment.id,
        'student_id': studentId,
        'fee_start_date': feeStartDate.toIso8601String().substring(0, 10),
      },
    );

    return payment;
  }

  /// Get payments for a specific parent
  List<MonthlyPayment> getPaymentsForParent(String parentId, {String? parentEmail}) {
    return _payments.where((p) {
      if (p.parentId == parentId) return true;
      if (parentEmail != null &&
          parentEmail.isNotEmpty &&
          p.parentEmail.toLowerCase() == parentEmail.toLowerCase()) {
        return true;
      }
      return false;
    }).toList();
  }

  /// Upload a receipt image and return its public URL (null on failure).
  Future<String?> uploadReceipt({
    required String paymentId,
    required String fileName,
    required List<int> bytes,
  }) async {
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return StorageService.uploadFile(
      bucket: receiptsBucket,
      path: 'receipts/$paymentId/${DateTime.now().millisecondsSinceEpoch}_$cleanName',
      bytes: bytes,
    );
  }

  /// Parent submits an uploaded receipt for verification
  Future<void> submitPaymentReceipt({
    required String paymentId,
    required String receiptUrl,
    String? customNote,
  }) async {
    final client = SupabaseService.instance.client;
    if (client == null) throw Exception('Not connected to the server.');
    final matching = _payments.where((p) => p.id == paymentId);
    final existing = matching.isNotEmpty ? matching.first : null;
    await client.from('monthly_payments').update({
      'status': 'submitted',
      'receipt_url': receiptUrl,
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
      'notes': (customNote == null || customNote.isEmpty)
          ? 'Receipt uploaded by parent. Awaiting admin review.'
          : customNote,
      'rejection_reason': null,
    }).eq('id', paymentId);
    await refresh();

    PushNotificationService.instance.dispatchPushNotificationToAll(
      title: 'Payment Receipt Submitted',
      body: existing != null
          ? '${existing.parentName} uploaded a tuition receipt for ${existing.month}.'
          : 'A parent uploaded a tuition receipt for verification.',
      targetAudience: 'admins',
      type: 'payment_approval',
      showLocally: false,
      data: {'payment_id': paymentId},
    );
  }

  /// Admin approves the payment
  Future<void> approvePayment({required String paymentId, String? adminName}) async {
    final client = SupabaseService.instance.client;
    if (client == null) throw Exception('Not connected to the server.');
    final matching = _payments.where((p) => p.id == paymentId);
    final existing = matching.isNotEmpty ? matching.first : null;
    final reviewerId = AuthSessionService.instance.userId;
    await client.from('monthly_payments').update({
      'status': 'approved',
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'reviewed_by': reviewerId.isEmpty ? null : reviewerId,
      'rejection_reason': null,
    }).eq('id', paymentId);
    await refresh();

    if (existing != null && existing.parentId.isNotEmpty) {
      PushNotificationService.instance.dispatchPushToUsers(
        userIds: [existing.parentId],
        title: 'Payment Approved',
        body:
            'Your tuition payment for ${existing.month} (${existing.studentName}) has been approved.',
        type: 'payment_approval',
        data: {'payment_id': paymentId},
      );
    }
  }

  /// Admin rejects the payment with a mandatory reason (displayed on parent side)
  Future<void> rejectPayment({
    required String paymentId,
    required String reason,
    String? adminName,
  }) async {
    final client = SupabaseService.instance.client;
    if (client == null) throw Exception('Not connected to the server.');
    final matching = _payments.where((p) => p.id == paymentId);
    final existing = matching.isNotEmpty ? matching.first : null;
    final reviewerId = AuthSessionService.instance.userId;
    await client.from('monthly_payments').update({
      'status': 'rejected',
      'rejection_reason': reason,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'reviewed_by': reviewerId.isEmpty ? null : reviewerId,
    }).eq('id', paymentId);
    await refresh();

    if (existing != null && existing.parentId.isNotEmpty) {
      PushNotificationService.instance.dispatchPushToUsers(
        userIds: [existing.parentId],
        title: 'Payment Rejected',
        body:
            'Your tuition receipt for ${existing.month} was rejected: $reason',
        type: 'payment_overdue',
        data: {'payment_id': paymentId},
      );
    }
  }

  /// Admin sends a tuition reminder to all parents (as an announcement so it
  /// reaches every parent's device through Realtime).
  Future<void> sendMonthlyTuitionReminder(String month) async {
    final client = SupabaseService.instance.client;
    if (client == null) return;
    try {
      await client.from('announcements').insert({
        'title': 'Monthly Tuition Fee Reminder 💳',
        'content':
            'Monthly Quran memorization fee for $month is now due. Please submit your payment and upload the receipt in the Payments section.',
        'target_audience': 'parents',
        'author_name': AuthSessionService.instance.userName,
        'is_pinned': false,
      });
    } catch (e) {
      debugPrint('[PaymentService] Reminder broadcast failed: $e');
      rethrow;
    }
  }

  /// Mark an overdue payment and record it locally for the admin
  Future<void> sendOverdueAlertToAdmin(MonthlyPayment payment) async {
    final client = SupabaseService.instance.client;
    if (client != null && payment.isPending) {
      try {
        await client.from('monthly_payments').update({'status': 'overdue'}).eq('id', payment.id);
        await refresh();
      } catch (e) {
        debugPrint('[PaymentService] Mark overdue failed: $e');
      }
    }
    NotificationCenterService.instance.addNotification(
      title: 'Overdue Tuition Alert ⚠️',
      body:
          'Payment for student ${payment.studentName} (Parent: ${payment.parentName}) is past due date for ${payment.month}.',
      type: 'payment_overdue',
      data: {'payment_id': payment.id, 'parent_id': payment.parentId},
    );
  }

  /// Automatically check all active fees and remind parents monthly
  Future<void> checkAndSendMonthlyFeeReminders() async {
    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      final now = DateTime.now();
      // Find pending payments
      final pendingRows = await client
          .from('monthly_payments')
          .select(_selectColumns)
          .eq('status', 'pending');

      if (pendingRows is List) {
        for (final row in pendingRows) {
          final payment = _fromRow(Map<String, dynamic>.from(row as Map));
          // If fee started on or before today, remind parent
          if (payment.feeStartDate.isBefore(now) ||
              payment.feeStartDate.day == now.day) {
            PushNotificationService.instance.dispatchPushToUsers(
              userIds: [payment.parentId],
              title: 'Monthly Tuition Reminder 💳',
              body:
                  'Tuition for ${payment.studentName} (${payment.month}) is due. Please submit your payment and receipt.',
              type: 'payment_reminder',
              data: {'payment_id': payment.id},
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[PaymentService] Error running monthly fee reminders: $e');
    }
  }
}
