import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment.dart';
import '../utils/json_parsers.dart';
import 'auth_session_service.dart';
import 'connectivity_service.dart';
import 'local_storage_service.dart';
import 'notification_center_service.dart';
import 'offline_sync_service.dart';
import 'push_notification_service.dart';
import 'storage_service.dart';
import 'supabase_service.dart';

/// Payment & Tuition Service backed by Supabase `monthly_payments`
/// with user-scoped offline caching, offline receipt staging/queuing,
/// and strict online-only guards on admin approvals & rejections.
class PaymentService {
  PaymentService._();

  static final PaymentService instance = PaymentService._();

  static const String receiptsBucket = StorageService.paymentReceiptsBucket;

  static const String _selectColumns =
      '*, student:students!student_id(full_name), parent:profiles!parent_id(full_name, email)';

  final List<MonthlyPayment> _payments = [];
  bool _cacheLoaded = false;
  final StreamController<List<MonthlyPayment>> _paymentsController =
      StreamController<List<MonthlyPayment>>.broadcast();
  RealtimeChannel? _channel;
  Timer? _realtimeDebounce;

  Stream<List<MonthlyPayment>> get paymentsStream => _paymentsController.stream;
  List<MonthlyPayment> get allPayments => List.unmodifiable(_payments);

  String get _uid => AuthSessionService.instance.userId.isNotEmpty
      ? AuthSessionService.instance.userId
      : (SupabaseService.instance.currentUser?.id ?? '');

  void _emit() {
    if (!_paymentsController.isClosed) {
      _paymentsController.add(List.from(_payments));
    }
  }

  Future<void> _saveToCache() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    await LocalStorageService.instance.saveUserJsonList(
      uid,
      'payments',
      _payments.map((p) => p.toJson()).toList(),
    );
  }

  void _applyPendingPaymentOverlays() {
    final pending = OfflineSyncService.instance
        .pendingMutationsForEntity(OfflineEntityTypes.paymentReceipt);
    for (final mut in pending) {
      final p = mut.payload;
      final paymentId = p['id']?.toString() ?? mut.id;
      final idx = _payments.indexWhere((row) => row.id == paymentId);
      if (idx == -1) continue;
      final existing = _payments[idx];
      final localReceipt = (mut.localMediaPath != null &&
              mut.localMediaPath!.trim().isNotEmpty)
          ? 'local://${mut.localMediaPath}'
          : (p['receipt_url']?.toString() ?? existing.receiptUrl);
      _payments[idx] = MonthlyPayment(
        id: existing.id,
        parentId: existing.parentId,
        parentName: existing.parentName,
        parentEmail: existing.parentEmail,
        studentId: existing.studentId,
        studentName: existing.studentName,
        month: existing.month,
        amount: existing.amount,
        dueDate: existing.dueDate,
        feeStartDate: existing.feeStartDate,
        status: p['status']?.toString() ?? 'submitted',
        receiptUrl: localReceipt,
        receiptLocalMock: existing.receiptLocalMock,
        rejectionReason: null,
        submittedAt:
            JsonParsers.asNullableDateTime(p['submitted_at']) ?? mut.createdAt,
        reviewedAt: existing.reviewedAt,
        reviewedBy: existing.reviewedBy,
        notes: p['notes']?.toString() ?? existing.notes,
      );
    }
  }

  Future<void> _loadFromCache() async {
    if (_cacheLoaded) return;
    if (!AuthSessionService.instance.canAccessPayments) return;
    final uid = _uid;
    if (uid.isEmpty) return;
    _cacheLoaded = true;
    try {
      final cached =
          await LocalStorageService.instance.getUserJsonList(uid, 'payments');
      if (cached.isNotEmpty && _payments.isEmpty) {
        for (final item in cached) {
          _payments.add(MonthlyPayment.fromJson(item));
        }
      }
      _applyPendingPaymentOverlays();
      _emit();
    } catch (e) {
      debugPrint('[PaymentService] Cache load note: $e');
    }
  }

  Future<void> refreshAndSubscribe() async {
    await _loadFromCache();
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;
    await refresh();
    try {
      final oldCh = _channel;
      _channel = null;
      if (oldCh != null) {
        await client.removeChannel(oldCh);
      }
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

  Future<void> clearOnLogout() async {
    final uid = _uid;
    final client = SupabaseService.instance.client;
    _realtimeDebounce?.cancel();
    _realtimeDebounce = null;
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      try {
        await client?.removeChannel(ch);
      } catch (e) {
        debugPrint('[PaymentService] removeChannel note: $e');
      }
    }
    _payments.clear();
    _cacheLoaded = false;
    _emit();
    if (uid.isNotEmpty) {
      await LocalStorageService.instance.removeUserCache(uid, 'payments');
    }
    await LocalStorageService.instance.remove('cached_payments');
  }

  /// Reload all payments visible to the current user (preserving pending offline receipts).
  Future<void> refresh() async {
    await _loadFromCache();
    if (!AuthSessionService.instance.canAccessPayments) {
      _payments.clear();
      _emit();
      return;
    }
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;
    if (!ConnectivityService.instance.isOnline) return;
    try {
      final res = await client
          .from('monthly_payments')
          .select(_selectColumns)
          .order('created_at', ascending: false)
          .limit(500);
      if (res is List) {
        _payments
          ..clear()
          ..addAll(
            res.map((e) => _fromRow(Map<String, dynamic>.from(e as Map))),
          );
        _applyPendingPaymentOverlays();
        _emit();
        await _saveToCache();
      }
    } catch (e) {
      debugPrint('[PaymentService] Failed to load payments: $e');
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
      }
    }
  }

  MonthlyPayment _fromRow(Map<String, dynamic> row) {
    final student = JsonParsers.asMap(row['student']);
    final parent = JsonParsers.asMap(row['parent']);
    final json = Map<String, dynamic>.from(row);
    json['month'] = row['month_year'] ?? row['month'];
    if (student != null && student['full_name'] != null) {
      json['student_name'] = student['full_name'];
    }
    if (parent != null) {
      if (parent['full_name'] != null) json['parent_name'] = parent['full_name'];
      if (parent['email'] != null) json['parent_email'] = parent['email'];
    }
    return MonthlyPayment.fromJson(json);
  }

  void _scheduleRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (SupabaseService.instance.currentUser != null) {
        refresh();
      }
    });
  }

  Future<void> _handleRealtimeChange(PostgresChangePayload payload) async {
    final userId = AuthSessionService.instance.userId;
    final isSuperAdmin = AuthSessionService.instance.isSuperAdmin;
    final newRow = payload.newRecord;
    final oldRow = payload.oldRecord;

    if (payload.eventType == PostgresChangeEvent.delete) {
      final id = oldRow['id']?.toString();
      _payments.removeWhere((p) => p.id == id);
      _emit();
      await _saveToCache();
      return;
    }

    final oldStatus = oldRow['status']?.toString();
    final newStatus = newRow['status']?.toString();
    final parentId = newRow['parent_id']?.toString();

    _scheduleRefresh();

    if (oldStatus == newStatus &&
        payload.eventType == PostgresChangeEvent.update) {
      return;
    }
    final month = newRow['month_year']?.toString() ?? '';
    final amount = newRow['amount']?.toString() ?? '';

    if (!isSuperAdmin &&
        AuthSessionService.instance.isParent &&
        parentId == userId) {
      if (payload.eventType == PostgresChangeEvent.insert) {
        _notify(
          'Monthly Tuition Due 💳',
          'A tuition invoice for $month ($amount) has been issued.',
          'payment_reminder',
        );
      } else if (newStatus == 'approved') {
        _notify(
          'Payment Approved ✅',
          'Your payment for $month has been verified and approved.',
          'payment_approval',
        );
      } else if (newStatus == 'rejected') {
        final reason = newRow['rejection_reason']?.toString() ?? '';
        _notify(
          'Payment Rejected ❌',
          'Payment for $month could not be verified. Reason: "$reason".',
          'payment_overdue',
        );
      }
    } else if (isSuperAdmin && newStatus == 'submitted') {
      _notify(
        'Payment Receipt Received 📥',
        'A parent submitted a receipt for $month. Review required.',
        'payment_approval',
      );
    }
  }

  void _notify(String title, String body, String type) {
    PushNotificationService.instance.showNotification(
      title: title,
      body: body,
      payload: type,
      type: type,
    );
  }

  void _requireSuperAdmin() {
    if (!AuthSessionService.instance.isSuperAdmin) {
      throw Exception(
        'Access Denied: Only Super Administrators can manage tuition payments.',
      );
    }
  }

  /// Superadmin issues a monthly tuition fee invoice for a student (online required).
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
    _requireSuperAdmin();
    if (!ConnectivityService.instance.isOnline &&
        !await ConnectivityService.instance.checkNow()) {
      throw const OfflineActionException();
    }
    final client = SupabaseService.instance.client;
    if (client == null) throw Exception('Not connected to the server.');
    if (parentId.isEmpty) {
      throw Exception('$studentName has no linked parent account yet.');
    }
    if (amount <= 0) {
      throw Exception('Fee amount must be greater than zero.');
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
    await _saveToCache();

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

  /// Get payments for a specific parent.
  List<MonthlyPayment> getPaymentsForParent(
    String parentId, {
    String? parentEmail,
  }) {
    return _payments.where((p) {
      if (p.parentId == parentId) return true;
      if (parentEmail != null &&
          parentEmail.isNotEmpty &&
          p.parentEmail.isNotEmpty &&
          p.parentEmail.toLowerCase() == parentEmail.toLowerCase()) {
        return true;
      }
      return false;
    }).toList();
  }

  /// Upload a receipt image to private `payment_receipts` under `<parentId>/<paymentId>/...`.
  Future<String?> uploadReceipt({
    required String paymentId,
    required String fileName,
    required List<int> bytes,
  }) async {
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final ownerId = SupabaseService.instance.currentUser?.id ??
        AuthSessionService.instance.userId;
    final cleanOwner = ownerId.isNotEmpty ? ownerId : 'unknown';
    return StorageService.uploadFile(
      bucket: receiptsBucket,
      path:
          '$cleanOwner/$paymentId/${DateTime.now().millisecondsSinceEpoch}_$cleanName',
      bytes: bytes,
    );
  }

  /// Offline-aware receipt upload & submission:
  /// Returns `true` if uploaded and committed online immediately, or `false` if staged
  /// locally and queued for durable auto-sync when connectivity returns.
  Future<bool> submitPaymentReceiptOfflineAware({
    required String paymentId,
    required Uint8List receiptBytes,
    required String fileName,
    String? customNote,
  }) async {
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final ownerId = SupabaseService.instance.currentUser?.id ??
        AuthSessionService.instance.userId;
    final cleanOwner = ownerId.isNotEmpty ? ownerId : 'unknown';
    final ms = DateTime.now().millisecondsSinceEpoch;
    final targetStoragePath = '$cleanOwner/$paymentId/${ms}_$cleanName';
    final cleanNote = (customNote == null || customNote.trim().isEmpty)
        ? 'Receipt uploaded by parent. Awaiting superadmin verification.'
        : customNote.trim();
    final now = DateTime.now();
    final nowIso = now.toUtc().toIso8601String();

    final idx = _payments.indexWhere((p) => p.id == paymentId);
    final existing = idx != -1 ? _payments[idx] : null;

    Future<void> applyLocally({
      required String resolvedReceiptUrl,
      required bool queueOffline,
      String? stagedPath,
    }) async {
      if (idx != -1 && existing != null) {
        _payments[idx] = MonthlyPayment(
          id: existing.id,
          parentId: existing.parentId,
          parentName: existing.parentName,
          parentEmail: existing.parentEmail,
          studentId: existing.studentId,
          studentName: existing.studentName,
          month: existing.month,
          amount: existing.amount,
          dueDate: existing.dueDate,
          feeStartDate: existing.feeStartDate,
          status: 'submitted',
          receiptUrl: resolvedReceiptUrl,
          receiptLocalMock: existing.receiptLocalMock,
          rejectionReason: null,
          submittedAt: now,
          reviewedAt: existing.reviewedAt,
          reviewedBy: existing.reviewedBy,
          notes: cleanNote,
        );
        _emit();
        await _saveToCache();
      }

      if (queueOffline) {
        await OfflineSyncService.instance.enqueue(
          entityType: OfflineEntityTypes.paymentReceipt,
          operation: 'update',
          id: paymentId,
          payload: {
            'id': paymentId,
            'status': 'submitted',
            'submitted_at': nowIso,
            'notes': cleanNote,
            'rejection_reason': null,
          },
          localMediaPath: stagedPath,
          storageBucket: receiptsBucket,
          storagePath: targetStoragePath,
          mediaPayloadField: 'receipt_url',
          displayLabel: 'Receipt: ${existing?.month ?? "Tuition"}',
          triggerImmediateSync: false,
        );
      }
    }

    Future<bool> stageAndQueue() async {
      final stagedPath = await OfflineSyncService.instance.stageMediaBytes(
        bytes: receiptBytes,
        fileName: cleanName,
      );
      await applyLocally(
        resolvedReceiptUrl: 'local://$stagedPath',
        queueOffline: true,
        stagedPath: stagedPath,
      );
      return false;
    }

    final client = SupabaseService.instance.client;
    if (!ConnectivityService.instance.isOnline || client == null) {
      return await stageAndQueue();
    }

    try {
      final uploadedUrl = await StorageService.uploadFile(
        bucket: receiptsBucket,
        path: targetStoragePath,
        bytes: receiptBytes,
        upsert: true,
        throwOnError: true,
      );
      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        throw Exception('Receipt upload failed.');
      }

      await submitPaymentReceipt(
        paymentId: paymentId,
        receiptUrl: uploadedUrl,
        customNote: cleanNote,
      );
      return true;
    } catch (e) {
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
        return await stageAndQueue();
      }
      rethrow;
    }
  }

  /// Parent submits an uploaded receipt URL for verification (routes push strictly to superadmins).
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
          ? 'Receipt uploaded by parent. Awaiting superadmin verification.'
          : customNote,
      'rejection_reason': null,
    }).eq('id', paymentId);
    await refresh();

    try {
      final superRows = await client
          .from('profiles')
          .select('id')
          .eq('role', 'superadmin')
          .or('is_suspended.is.null,is_suspended.eq.false');
      if (superRows is List && superRows.isNotEmpty) {
        final superIds = superRows
            .map((r) => r['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
        if (superIds.isNotEmpty) {
          await PushNotificationService.instance.dispatchPushToUsers(
            userIds: superIds,
            title: 'Payment Receipt Submitted',
            body: existing != null
                ? '${existing.parentName} uploaded a tuition receipt for ${existing.month}.'
                : 'A parent uploaded a tuition receipt for verification.',
            type: 'payment_approval',
            data: {'payment_id': paymentId},
          );
        }
      }
    } catch (e) {
      debugPrint('[PaymentService] Superadmin receipt notification note: $e');
    }
  }

  /// Superadmin approves the payment (strictly online-only).
  Future<void> approvePayment({
    required String paymentId,
    String? adminName,
  }) async {
    _requireSuperAdmin();
    if (!ConnectivityService.instance.isOnline &&
        !await ConnectivityService.instance.checkNow()) {
      throw const OfflineActionException();
    }
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

  /// Superadmin rejects the payment with a mandatory reason (strictly online-only).
  Future<void> rejectPayment({
    required String paymentId,
    required String reason,
    String? adminName,
  }) async {
    _requireSuperAdmin();
    if (!ConnectivityService.instance.isOnline &&
        !await ConnectivityService.instance.checkNow()) {
      throw const OfflineActionException();
    }
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

  /// Superadmin sends a tuition reminder announcement to parents (online-only).
  Future<void> sendMonthlyTuitionReminder(String month) async {
    _requireSuperAdmin();
    if (!ConnectivityService.instance.isOnline &&
        !await ConnectivityService.instance.checkNow()) {
      throw const OfflineActionException();
    }
    final client = SupabaseService.instance.client;
    if (client == null) {
      throw Exception('Unable to connect to server.');
    }
    await client.from('announcements').insert({
      'title': 'Monthly Tuition Fee Reminder 💳',
      'content':
          'Monthly Quran memorization fee for $month is now due. Please submit your payment and upload the receipt in the Payments section.',
      'target_audience': 'parents',
      'author_name': AuthSessionService.instance.userName,
      'is_pinned': false,
    });
  }

  /// Superadmin marks an overdue payment and records an in-app alert (online-only).
  Future<void> sendOverdueAlertToAdmin(MonthlyPayment payment) async {
    _requireSuperAdmin();
    if (!ConnectivityService.instance.isOnline &&
        !await ConnectivityService.instance.checkNow()) {
      throw const OfflineActionException();
    }
    final client = SupabaseService.instance.client;
    if (client != null && payment.isPending) {
      await client
          .from('monthly_payments')
          .update({'status': 'overdue'})
          .eq('id', payment.id);
      await refresh();
    }
    NotificationCenterService.instance.addNotification(
      title: 'Overdue Tuition Alert ⚠️',
      body:
          'Payment for student ${payment.studentName} (Parent: ${payment.parentName}) is past due date for ${payment.month}.',
      type: 'payment_overdue',
      data: {'payment_id': payment.id, 'parent_id': payment.parentId},
    );
  }

  /// Invoke the idempotent PostgreSQL monthly reminder dispatcher (Superadmin only).
  Future<int> checkAndSendMonthlyFeeReminders() async {
    if (!AuthSessionService.instance.isSuperAdmin) return 0;
    if (!ConnectivityService.instance.isOnline) return 0;
    final client = SupabaseService.instance.client;
    if (client == null) return 0;

    try {
      final res = await client.rpc('dispatch_due_monthly_fee_reminders');
      return JsonParsers.asInt(res, 0);
    } catch (e) {
      debugPrint(
          '[PaymentService] Idempotent monthly fee reminder RPC note: $e');
      return 0;
    }
  }
}
