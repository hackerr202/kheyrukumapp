import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/absence_request.dart';
import 'auth_session_service.dart';
import 'halaqah_service.dart';
import 'push_notification_service.dart';
import 'student_service.dart';
import 'supabase_service.dart';

/// Reactive Absence Service managing:
/// - Parents submitting excused absence requests in advance
/// - Teachers reviewing pending requests with 1-tap "Approve & Excuse" or "Decline"
/// - Automatic synchronization with StudentService daily attendance & Supabase Realtime
class AbsenceService {
  AbsenceService._() {
    refreshAll();
  }

  static final AbsenceService instance = AbsenceService._();

  final List<AbsenceRequest> _requests = [];
  RealtimeChannel? _realtimeChannel;
  final StreamController<List<AbsenceRequest>> _requestsController =
      StreamController<List<AbsenceRequest>>.broadcast();

  Stream<List<AbsenceRequest>> get requestsStream => _requestsController.stream;
  List<AbsenceRequest> get allRequests => List.unmodifiable(_requests);

  static bool _isValidUuid(String? str) {
    if (str == null) return false;
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(str.trim());
  }

  Future<void> refreshAll() async {
    await fetchFromCloud();
    _subscribeRealtime();
  }

  Future<void> clearOnLogout() async {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _requests.clear();
    _requestsController.add([]);
  }

  Future<void> fetchFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null) return;
    try {
      final res = await client
          .from('absence_requests')
          .select()
          .order('created_at', ascending: false);
      if (res is List) {
        _requests.clear();
        for (final item in res) {
          _requests.add(AbsenceRequest.fromJson(Map<String, dynamic>.from(item as Map)));
        }
        _requestsController.add(List.from(_requests));
      }
    } catch (e) {
      debugPrint('[AbsenceService] fetchFromCloud notice: $e');
    }
  }

  void _subscribeRealtime() {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;

    try {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = client
          .channel('public:absence_requests')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'absence_requests',
            callback: (payload) async {
              await fetchFromCloud();
              final newRow = payload.newRecord;
              if (newRow.isEmpty) return;

              final status = newRow['status']?.toString() ?? '';
              final studentName = newRow['student_name']?.toString() ?? 'Student';
              final parentId = newRow['parent_id']?.toString() ?? '';
              final halaqahName = newRow['halaqah_name']?.toString() ?? '';
              final halaqahId = newRow['halaqah_id']?.toString() ?? '';

              if (payload.eventType == PostgresChangeEvent.insert &&
                  AuthSessionService.instance.isTeacher) {
                final isMyClass = halaqahId == AuthSessionService.instance.assignedHalaqahId ||
                    halaqahName.toLowerCase() ==
                        AuthSessionService.instance.assignedHalaqahName.toLowerCase();
                if (isMyClass) {
                  PushNotificationService.instance.showNotification(
                    title: 'Absence Excuse Request',
                    body: 'Parent submitted an excuse for $studentName.',
                    payload: 'absence_request',
                    type: 'absence_request',
                  );
                }
              } else if (payload.eventType == PostgresChangeEvent.update &&
                  AuthSessionService.instance.isParent &&
                  parentId == AuthSessionService.instance.userId) {
                PushNotificationService.instance.showNotification(
                  title: status == 'approved'
                      ? 'Absence Excuse Approved'
                      : 'Absence Request Update',
                  body: 'Absence request for $studentName was $status.',
                  payload: 'absence_$status',
                  type: 'absence_$status',
                );
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[AbsenceService] Realtime subscription note: $e');
    }
  }

  /// Get pending requests for teacher's halaqah
  List<AbsenceRequest> getPendingRequestsForHalaqah(String halaqahName, {String? halaqahId}) {
    return _requests.where((r) {
      if (!r.isPending) return false;
      if (halaqahId != null && halaqahId.isNotEmpty && r.halaqahId == halaqahId) return true;
      return r.halaqahName.toLowerCase().contains(halaqahName.toLowerCase()) ||
          halaqahName.toLowerCase().contains(r.halaqahName.toLowerCase());
    }).toList();
  }

  /// Get all requests for a specific parent
  List<AbsenceRequest> getRequestsForParent(String parentId, {String? parentEmail}) {
    return _requests.where((r) {
      if (r.parentId == parentId) return true;
      return false;
    }).toList();
  }

  /// Parent Action: Submit an excused absence request for a student
  Future<AbsenceRequest> submitAbsenceRequest({
    required String studentId,
    required DateTime date,
    required String reason,
    required String notes,
  }) async {
    final studentMatches = StudentService.instance.allStudents.where((s) => s.id == studentId);
    final student = studentMatches.isNotEmpty ? studentMatches.first : null;
    final parentId = student?.parentId ?? AuthSessionService.instance.userId;

    String requestId = 'abs-${DateTime.now().millisecondsSinceEpoch}';
    final client = SupabaseService.instance.client;
    if (client != null && _isValidUuid(studentId)) {
      try {
        final payload = <String, dynamic>{
          'student_id': studentId,
          'student_name': student?.fullName ?? 'Student',
          if (_isValidUuid(student?.halaqahId)) 'halaqah_id': student!.halaqahId,
          'halaqah_name': student?.halaqahName ?? 'Halaqah Circle',
          if (_isValidUuid(parentId)) 'parent_id': parentId,
          'parent_name': student?.parentName ?? AuthSessionService.instance.userName,
          'parent_phone': student?.parentPhone ?? AuthSessionService.instance.userPhone,
          'date': date.toIso8601String().substring(0, 10),
          'reason': reason,
          'notes': notes.trim(),
          'status': 'pending',
        };
        final inserted = await client.from('absence_requests').insert(payload).select('id').single();
        if (inserted['id'] != null) {
          requestId = inserted['id'].toString();
        }
      } catch (e) {
        debugPrint('[AbsenceService] Cloud insert notice: $e');
      }
    }

    final request = AbsenceRequest(
      id: requestId,
      studentId: studentId,
      studentName: student?.fullName ?? 'Student',
      halaqahId: student?.halaqahId ?? '',
      halaqahName: student?.halaqahName ?? 'Halaqah Circle',
      parentId: parentId,
      parentName: student?.parentName ?? AuthSessionService.instance.userName,
      parentPhone: student?.parentPhone ?? AuthSessionService.instance.userPhone,
      date: date,
      reason: reason,
      notes: notes.trim(),
      status: 'pending',
      createdAt: DateTime.now(),
    );

    _requests.insert(0, request);
    _requestsController.add(List.from(_requests));

    final halaqahMatches = HalaqahService.instance.halaqahs.where((h) =>
        (request.halaqahId.isNotEmpty && h.id == request.halaqahId) ||
        h.name.toLowerCase() == request.halaqahName.toLowerCase());
    final teacherIds = halaqahMatches
        .map((h) => h.teacherId)
        .whereType<String>()
        .where((id) => _isValidUuid(id))
        .toList();
    PushNotificationService.instance.dispatchPushToUsers(
      userIds: teacherIds,
      fallbackAudience: teacherIds.isEmpty ? 'teachers' : null,
      title: 'Absence Excuse Request',
      body:
          '${request.parentName} submitted an excuse for ${request.studentName}.',
      type: 'absence_request',
      data: {'student_id': studentId, 'request_id': requestId},
    );

    return request;
  }

  /// Teacher Action: 1-tap Approve & Excuse
  /// Automatically synchronizes with StudentService to mark daily attendance as 'excused'!
  Future<void> approveRequest(
    String requestId, {
    String? reviewedBy,
  }) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;

    final reviewer = reviewedBy ??
        (AuthSessionService.instance.userName.isNotEmpty
            ? AuthSessionService.instance.userName
            : 'Assigned Ustaz');

    final existing = _requests[index];
    final reviewedAt = DateTime.now();
    final updated = existing.copyWith(
      status: 'approved',
      reviewedBy: reviewer,
      reviewedAt: reviewedAt,
    );

    _requests[index] = updated;
    _requestsController.add(List.from(_requests));

    final client = SupabaseService.instance.client;
    if (client != null && _isValidUuid(requestId)) {
      try {
        await client.from('absence_requests').update({
          'status': 'approved',
          'reviewed_by': reviewer,
          'reviewed_at': reviewedAt.toUtc().toIso8601String(),
        }).eq('id', requestId);
      } catch (e) {
        debugPrint('[AbsenceService] Cloud approve notice: $e');
      }
    }

    // ATOMICALLY MARK DAILY ATTENDANCE AS 'EXCUSED' IN STUDENT SERVICE!
    await StudentService.instance.recordDailyAttendance(
      studentId: updated.studentId,
      status: 'excused',
      remarks: 'Parent excuse approved: ${updated.reasonLabel} - ${updated.notes}',
      sessionDate: updated.date,
      markedBy: reviewer,
    );

    if (_isValidUuid(existing.parentId)) {
      PushNotificationService.instance.dispatchPushToUsers(
        userIds: [existing.parentId],
        title: 'Absence Excuse Approved',
        body: 'Absence excuse for ${updated.studentName} has been approved.',
        type: 'absence_approved',
        data: {'request_id': requestId, 'student_id': updated.studentId},
      );
    }
  }

  /// Teacher Action: Decline absence request
  Future<void> declineRequest(
    String requestId, {
    String? reviewedBy,
    String? declineReason,
  }) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;

    final reviewer = reviewedBy ??
        (AuthSessionService.instance.userName.isNotEmpty
            ? AuthSessionService.instance.userName
            : 'Assigned Ustaz');

    final existing = _requests[index];
    final reviewedAt = DateTime.now();
    final updated = existing.copyWith(
      status: 'declined',
      reviewedBy: reviewer,
      reviewedAt: reviewedAt,
    );

    _requests[index] = updated;
    _requestsController.add(List.from(_requests));

    final client = SupabaseService.instance.client;
    if (client != null && _isValidUuid(requestId)) {
      try {
        await client.from('absence_requests').update({
          'status': 'declined',
          'reviewed_by': reviewer,
          'reviewed_at': reviewedAt.toUtc().toIso8601String(),
        }).eq('id', requestId);
      } catch (e) {
        debugPrint('[AbsenceService] Cloud decline notice: $e');
      }
    }

    if (_isValidUuid(existing.parentId)) {
      PushNotificationService.instance.dispatchPushToUsers(
        userIds: [existing.parentId],
        title: 'Absence Request Update',
        body: 'Absence excuse for ${updated.studentName} was declined.',
        type: 'absence_declined',
        data: {'request_id': requestId, 'student_id': updated.studentId},
      );
    }
  }
}
