import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/absence_request.dart';
import 'notification_center_service.dart';
import 'student_service.dart';
import 'supabase_service.dart';

/// Reactive Absence Service managing:
/// - Parents submitting excused absence requests in advance
/// - Teachers reviewing pending requests with 1-tap "Approve & Excuse" or "Decline"
/// - Automatic synchronization with StudentService daily attendance
class AbsenceService {
  AbsenceService._();

  static final AbsenceService instance = AbsenceService._();

  final List<AbsenceRequest> _requests = [];
  final StreamController<List<AbsenceRequest>> _requestsController =
      StreamController<List<AbsenceRequest>>.broadcast();

  Stream<List<AbsenceRequest>> get requestsStream => _requestsController.stream;
  List<AbsenceRequest> get allRequests => List.unmodifiable(_requests);

  /// Get pending requests for teacher's halaqah
  List<AbsenceRequest> getPendingRequestsForHalaqah(String halaqahName) {
    return _requests.where((r) {
      if (!r.isPending) return false;
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
    final student = StudentService.instance.allStudents.firstWhere(
      (s) => s.id == studentId,
      orElse: () => StudentService.instance.allStudents.first,
    );

    final request = AbsenceRequest(
      id: 'abs-${DateTime.now().millisecondsSinceEpoch}',
      studentId: student.id,
      studentName: student.fullName,
      halaqahId: student.halaqahId,
      halaqahName: student.halaqahName,
      parentId: student.parentId ?? '',
      parentName: student.parentName,
      parentPhone: student.parentPhone,
      date: date,
      reason: reason,
      notes: notes.trim(),
      status: 'pending',
      createdAt: DateTime.now(),
    );

    _requests.insert(0, request);
    _requestsController.add(List.from(_requests));

    // DISPATCH NOTIFICATION TO TEACHER
    NotificationCenterService.instance.addNotification(
      title: 'Absence Excuse Request Received 📝',
      body: '${student.parentName} submitted an absence excuse for ${student.fullName} on ${date.toIso8601String().substring(0, 10)} (${request.reasonLabel}). Review required.',
      type: 'attendance',
      data: {
        'request_id': request.id,
        'student_id': student.id,
        'halaqah_name': student.halaqahName,
      },
    );

    // Cloud sync to Supabase if connected
    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        await client.from('absence_requests').insert(request.toJson());
      } catch (e) {
        debugPrint('[AbsenceService] Cloud insert fallback: $e');
      }
    }

    return request;
  }

  /// Teacher Action: 1-tap Approve & Excuse
  /// Automatically synchronizes with StudentService to mark daily attendance as 'excused'!
  Future<void> approveRequest(
    String requestId, {
    String? reviewedBy = 'Ustaz Ibrahim Bilal',
  }) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;

    final existing = _requests[index];
    final updated = existing.copyWith(
      status: 'approved',
      reviewedBy: reviewedBy,
      reviewedAt: DateTime.now(),
    );

    _requests[index] = updated;
    _requestsController.add(List.from(_requests));

    // ATOMICALLY MARK DAILY ATTENDANCE AS 'EXCUSED' IN STUDENT SERVICE!
    await StudentService.instance.recordDailyAttendance(
      studentId: updated.studentId,
      status: 'excused',
      remarks: 'Parent excuse approved: ${updated.reasonLabel} - ${updated.notes}',
      sessionDate: updated.date,
      markedBy: reviewedBy,
    );

    // DISPATCH NOTIFICATION TO PARENT
    NotificationCenterService.instance.addNotification(
      title: 'Absence Excuse Approved ✅',
      body: 'Absence request for ${updated.studentName} on ${updated.date.toIso8601String().substring(0, 10)} has been approved by $reviewedBy.',
      type: 'attendance',
      data: {
        'request_id': updated.id,
        'student_id': updated.studentId,
        'status': 'approved',
      },
    );
  }

  /// Teacher Action: Decline absence request
  Future<void> declineRequest(
    String requestId, {
    String? reviewedBy = 'Ustaz Ibrahim Bilal',
    String? declineReason,
  }) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;

    final existing = _requests[index];
    final updated = existing.copyWith(
      status: 'declined',
      reviewedBy: reviewedBy,
      reviewedAt: DateTime.now(),
    );

    _requests[index] = updated;
    _requestsController.add(List.from(_requests));

    // DISPATCH NOTIFICATION TO PARENT
    NotificationCenterService.instance.addNotification(
      title: 'Absence Request Update ❌',
      body: 'Absence request for ${updated.studentName} on ${updated.date.toIso8601String().substring(0, 10)} was declined. Reason: ${declineReason ?? "Please contact the teacher."}',
      type: 'attendance',
      data: {
        'request_id': updated.id,
        'student_id': updated.studentId,
        'status': 'declined',
      },
    );
  }
}
