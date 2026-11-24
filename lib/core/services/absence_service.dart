import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/absence_request.dart';
import '../utils/json_parsers.dart';
import '../utils/uuid_v4.dart';
import 'auth_session_service.dart';
import 'connectivity_service.dart';
import 'halaqah_service.dart';
import 'local_storage_service.dart';
import 'offline_sync_service.dart';
import 'push_notification_service.dart';
import 'student_service.dart';
import 'supabase_service.dart';

/// Reactive Absence Service managing excused absence requests and teacher review
/// with user-scoped offline caching and durable outbox replay.
class AbsenceService {
  AbsenceService._();

  static final AbsenceService instance = AbsenceService._();

  final List<AbsenceRequest> _requests = [];
  bool _cacheLoaded = false;
  RealtimeChannel? _realtimeChannel;
  Timer? _realtimeDebounce;
  final StreamController<List<AbsenceRequest>> _requestsController =
      StreamController<List<AbsenceRequest>>.broadcast();

  Stream<List<AbsenceRequest>> get requestsStream => _requestsController.stream;
  List<AbsenceRequest> get allRequests => List.unmodifiable(_requests);

  String get _uid => AuthSessionService.instance.userId.isNotEmpty
      ? AuthSessionService.instance.userId
      : (SupabaseService.instance.currentUser?.id ?? '');

  static bool _isValidUuid(String? str) => UuidV4.isValid(str);

  Future<void> _saveCache() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    await LocalStorageService.instance.saveUserJsonList(
      uid,
      'absence_requests',
      _requests.map((r) => r.toJson()).toList(),
    );
  }

  void _applyPendingAbsenceOverlays() {
    final pending = OfflineSyncService.instance
        .pendingMutationsForEntity(OfflineEntityTypes.absenceRequest);
    for (final mut in pending) {
      final p = mut.payload;
      final id = p['id']?.toString() ?? mut.id;
      if (id.isEmpty) continue;
      final existingIdx = _requests.indexWhere((r) => r.id == id);
      if (existingIdx != -1) {
        final existing = _requests[existingIdx];
        _requests[existingIdx] = existing.copyWith(
          status: p['status']?.toString() ?? existing.status,
          reviewedBy: p['reviewed_by']?.toString() ?? existing.reviewedBy,
          reviewedAt: JsonParsers.asNullableDateTime(p['reviewed_at']) ??
              existing.reviewedAt,
        );
      } else {
        _requests.insert(
          0,
          AbsenceRequest.fromJson({
            ...p,
            'id': id,
            'created_at': mut.createdAt.toUtc().toIso8601String(),
          }),
        );
      }
    }
  }

  Future<void> _loadFromCache() async {
    if (_cacheLoaded) return;
    final uid = _uid;
    if (uid.isEmpty) return;
    _cacheLoaded = true;
    try {
      final cached = await LocalStorageService.instance
          .getUserJsonList(uid, 'absence_requests');
      if (cached.isNotEmpty && _requests.isEmpty) {
        for (final item in cached) {
          _requests.add(AbsenceRequest.fromJson(item));
        }
      }
      _applyPendingAbsenceOverlays();
      if (_requests.isNotEmpty && !_requestsController.isClosed) {
        _requestsController.add(List.from(_requests));
      }
    } catch (e) {
      debugPrint('[AbsenceService] Cache load note: $e');
    }
  }

  Future<void> refreshAll() async {
    await _loadFromCache();
    await fetchFromCloud();
    await _subscribeRealtime();
  }

  Future<void> clearOnLogout() async {
    final uid = _uid;
    final client = SupabaseService.instance.client;
    _realtimeDebounce?.cancel();
    _realtimeDebounce = null;
    final ch = _realtimeChannel;
    _realtimeChannel = null;
    if (ch != null) {
      try {
        await client?.removeChannel(ch);
      } catch (e) {
        debugPrint('[AbsenceService] removeChannel note: $e');
      }
    }
    _requests.clear();
    _cacheLoaded = false;
    if (!_requestsController.isClosed) {
      _requestsController.add([]);
    }
    if (uid.isNotEmpty) {
      await LocalStorageService.instance
          .removeUserCache(uid, 'absence_requests');
    }
  }

  Future<void> fetchFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;
    if (!ConnectivityService.instance.isOnline) return;
    try {
      final res = await client
          .from('absence_requests')
          .select()
          .order('created_at', ascending: false)
          .limit(200);
      if (res is List) {
        _requests.clear();
        for (final item in res) {
          _requests.add(
              AbsenceRequest.fromJson(Map<String, dynamic>.from(item as Map)));
        }
        _applyPendingAbsenceOverlays();
        if (!_requestsController.isClosed) {
          _requestsController.add(List.from(_requests));
        }
        await _saveCache();
      }
    } catch (e) {
      debugPrint('[AbsenceService] fetchFromCloud notice: $e');
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
      }
    }
  }

  void _scheduleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (SupabaseService.instance.currentUser != null) {
        fetchFromCloud();
      }
    });
  }

  Future<void> _subscribeRealtime() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;

    try {
      final oldCh = _realtimeChannel;
      _realtimeChannel = null;
      if (oldCh != null) {
        await client.removeChannel(oldCh);
      }
      _realtimeChannel = client
          .channel('public:absence_requests')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'absence_requests',
            callback: (payload) async {
              _scheduleRealtimeRefresh();
              final newRow = payload.newRecord;
              if (newRow.isEmpty) return;

              final status = newRow['status']?.toString() ?? '';
              final studentName =
                  newRow['student_name']?.toString() ?? 'Student';
              final parentId = newRow['parent_id']?.toString() ?? '';
              final halaqahName = newRow['halaqah_name']?.toString() ?? '';
              final halaqahId = newRow['halaqah_id']?.toString() ?? '';

              if (payload.eventType == PostgresChangeEvent.insert &&
                  AuthSessionService.instance.isTeacher) {
                final isMyClass =
                    halaqahId == AuthSessionService.instance.assignedHalaqahId ||
                        halaqahName.toLowerCase() ==
                            AuthSessionService.instance.assignedHalaqahName
                                .toLowerCase();
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

  /// Get pending requests for teacher's halaqah.
  List<AbsenceRequest> getPendingRequestsForHalaqah(
    String halaqahName, {
    String? halaqahId,
  }) {
    return _requests.where((r) {
      if (!r.isPending) return false;
      if (halaqahId != null &&
          halaqahId.isNotEmpty &&
          r.halaqahId == halaqahId) {
        return true;
      }
      return r.halaqahName.toLowerCase().contains(halaqahName.toLowerCase()) ||
          halaqahName.toLowerCase().contains(r.halaqahName.toLowerCase());
    }).toList();
  }

  /// Get all requests for a specific parent.
  List<AbsenceRequest> getRequestsForParent(
    String parentId, {
    String? parentEmail,
  }) {
    return _requests.where((r) => r.parentId == parentId).toList();
  }

  /// Parent Action: Submit an excused absence request (works offline & online cleanly).
  Future<AbsenceRequest> submitAbsenceRequest({
    required String studentId,
    required DateTime date,
    required String reason,
    required String notes,
  }) async {
    if (!_isValidUuid(studentId)) {
      throw Exception('Unable to submit absence request: invalid student ID.');
    }

    final studentMatches =
        StudentService.instance.allStudents.where((s) => s.id == studentId);
    final student = studentMatches.isNotEmpty ? studentMatches.first : null;
    final parentId = student?.parentId ?? AuthSessionService.instance.userId;

    final requestId = UuidV4.generate();
    final now = DateTime.now();

    final payload = <String, dynamic>{
      'id': requestId,
      'student_id': studentId,
      'student_name': student?.fullName ?? 'Student',
      if (_isValidUuid(student?.halaqahId)) 'halaqah_id': student!.halaqahId,
      'halaqah_name': student?.halaqahName ?? 'Halaqah Circle',
      if (_isValidUuid(parentId)) 'parent_id': parentId,
      'parent_name':
          student?.parentName ?? AuthSessionService.instance.userName,
      'parent_phone':
          student?.parentPhone ?? AuthSessionService.instance.userPhone,
      'date': date.toIso8601String().substring(0, 10),
      'reason': reason,
      'notes': notes.trim(),
      'status': 'pending',
    };

    Future<AbsenceRequest> applyLocally({
      required String resolvedId,
      required DateTime createdAt,
      required bool queueOffline,
    }) async {
      final request = AbsenceRequest(
        id: resolvedId,
        studentId: studentId,
        studentName: student?.fullName ?? 'Student',
        halaqahId: student?.halaqahId ?? '',
        halaqahName: student?.halaqahName ?? 'Halaqah Circle',
        parentId: parentId,
        parentName:
            student?.parentName ?? AuthSessionService.instance.userName,
        parentPhone:
            student?.parentPhone ?? AuthSessionService.instance.userPhone,
        date: date,
        reason: reason,
        notes: notes.trim(),
        status: 'pending',
        createdAt: createdAt,
      );

      _requests.removeWhere((r) => r.id == resolvedId);
      _requests.insert(0, request);
      if (!_requestsController.isClosed) {
        _requestsController.add(List.from(_requests));
      }
      await _saveCache();

      if (queueOffline) {
        await OfflineSyncService.instance.enqueue(
          entityType: OfflineEntityTypes.absenceRequest,
          operation: 'upsert',
          id: resolvedId,
          payload: {
            ...payload,
            'id': resolvedId,
          },
          displayLabel: 'Absence excuse: ${request.studentName}',
          triggerImmediateSync: false,
        );
      }

      return request;
    }

    final client = SupabaseService.instance.client;
    if (!ConnectivityService.instance.isOnline || client == null) {
      return await applyLocally(
        resolvedId: requestId,
        createdAt: now,
        queueOffline: true,
      );
    }

    try {
      final inserted = await client
          .from('absence_requests')
          .upsert(payload, onConflict: 'id')
          .select('id, created_at')
          .single();
      final finalId = inserted['id']?.toString() ?? requestId;

      final request = await applyLocally(
        resolvedId: finalId,
        createdAt: JsonParsers.asDateTime(inserted['created_at'], now),
        queueOffline: false,
      );

      final halaqahMatches = HalaqahService.instance.halaqahs.where((h) =>
          (request.halaqahId.isNotEmpty && h.id == request.halaqahId) ||
          h.name.toLowerCase() == request.halaqahName.toLowerCase());
      final teacherIds = halaqahMatches
          .map((h) => h.teacherId)
          .whereType<String>()
          .where((id) => _isValidUuid(id))
          .toList();
      if (teacherIds.isNotEmpty) {
        PushNotificationService.instance.dispatchPushToUsers(
          userIds: teacherIds,
          title: 'Absence Excuse Request',
          body:
              '${request.parentName} submitted an excuse for ${request.studentName}.',
          type: 'absence_request',
          data: {
            'student_id': studentId,
            'request_id': finalId,
            'template_key': 'absence_submitted',
            'params': {
              'parent_name': request.parentName,
              'student_name': request.studentName,
            },
          },
        );
      }
      return request;
    } catch (e) {
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
        return await applyLocally(
          resolvedId: requestId,
          createdAt: now,
          queueOffline: true,
        );
      }
      rethrow;
    }
  }

  /// Teacher Action: Approve & record excused attendance (works offline & online cleanly).
  Future<void> approveRequest(
    String requestId, {
    String? reviewedBy,
  }) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index == -1 || !_isValidUuid(requestId)) return;

    final reviewer = reviewedBy ??
        (AuthSessionService.instance.userName.isNotEmpty
            ? AuthSessionService.instance.userName
            : 'Assigned Ustaz');

    final existing = _requests[index];
    final reviewedAt = DateTime.now();
    final updateFields = <String, dynamic>{
      'status': 'approved',
      'reviewed_by': reviewer,
      'reviewed_at': reviewedAt.toUtc().toIso8601String(),
    };

    Future<void> applyLocally({required bool queueOffline}) async {
      final updated = existing.copyWith(
        status: 'approved',
        reviewedBy: reviewer,
        reviewedAt: reviewedAt,
      );
      _requests[index] = updated;
      if (!_requestsController.isClosed) {
        _requestsController.add(List.from(_requests));
      }
      await _saveCache();

      if (queueOffline) {
        await OfflineSyncService.instance.enqueue(
          entityType: OfflineEntityTypes.absenceRequest,
          operation: 'update',
          id: requestId,
          payload: {
            'id': requestId,
            ...updateFields,
          },
          displayLabel: 'Approve excuse: ${updated.studentName}',
          triggerImmediateSync: false,
        );
      }

      try {
        await StudentService.instance.recordDailyAttendance(
          studentId: updated.studentId,
          status: 'excused',
          remarks:
              'Parent excuse approved: ${updated.reasonLabel} - ${updated.notes}',
          sessionDate: updated.date,
          markedBy: reviewer,
        );
      } catch (e) {
        debugPrint('[AbsenceService] Attendance sync after approval note: $e');
      }
    }

    final client = SupabaseService.instance.client;
    if (!ConnectivityService.instance.isOnline || client == null) {
      await applyLocally(queueOffline: true);
      return;
    }

    try {
      await client
          .from('absence_requests')
          .update(updateFields)
          .eq('id', requestId);
      await applyLocally(queueOffline: false);

      if (_isValidUuid(existing.parentId)) {
        PushNotificationService.instance.dispatchPushToUsers(
          userIds: [existing.parentId],
          title: 'Absence Excuse Approved',
          body: 'Absence excuse for ${existing.studentName} has been approved.',
          type: 'absence_approved',
          data: {
            'request_id': requestId,
            'student_id': existing.studentId,
            'template_key': 'absence_approved',
            'params': {
              'student_name': existing.studentName,
            },
          },
        );
      }
    } catch (e) {
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
        await applyLocally(queueOffline: true);
        return;
      }
      rethrow;
    }
  }

  /// Teacher Action: Decline absence request (works offline & online cleanly).
  Future<void> declineRequest(
    String requestId, {
    String? reviewedBy,
    String? declineReason,
  }) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index == -1 || !_isValidUuid(requestId)) return;

    final reviewer = reviewedBy ??
        (AuthSessionService.instance.userName.isNotEmpty
            ? AuthSessionService.instance.userName
            : 'Assigned Ustaz');

    final existing = _requests[index];
    final reviewedAt = DateTime.now();
    final updateFields = <String, dynamic>{
      'status': 'declined',
      'reviewed_by': reviewer,
      'reviewed_at': reviewedAt.toUtc().toIso8601String(),
    };

    Future<void> applyLocally({required bool queueOffline}) async {
      final updated = existing.copyWith(
        status: 'declined',
        reviewedBy: reviewer,
        reviewedAt: reviewedAt,
      );
      _requests[index] = updated;
      if (!_requestsController.isClosed) {
        _requestsController.add(List.from(_requests));
      }
      await _saveCache();

      if (queueOffline) {
        await OfflineSyncService.instance.enqueue(
          entityType: OfflineEntityTypes.absenceRequest,
          operation: 'update',
          id: requestId,
          payload: {
            'id': requestId,
            ...updateFields,
          },
          displayLabel: 'Decline excuse: ${updated.studentName}',
          triggerImmediateSync: false,
        );
      }
    }

    final client = SupabaseService.instance.client;
    if (!ConnectivityService.instance.isOnline || client == null) {
      await applyLocally(queueOffline: true);
      return;
    }

    try {
      await client
          .from('absence_requests')
          .update(updateFields)
          .eq('id', requestId);
      await applyLocally(queueOffline: false);

      if (_isValidUuid(existing.parentId)) {
        PushNotificationService.instance.dispatchPushToUsers(
          userIds: [existing.parentId],
          title: 'Absence Request Update',
          body: 'Absence excuse for ${existing.studentName} was declined.',
          type: 'absence_declined',
          data: {
            'request_id': requestId,
            'student_id': existing.studentId,
            'template_key': 'absence_declined',
            'params': {
              'student_name': existing.studentName,
            },
          },
        );
      }
    } catch (e) {
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
        await applyLocally(queueOffline: true);
        return;
      }
      rethrow;
    }
  }
}
