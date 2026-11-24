import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/homework.dart';
import '../utils/json_parsers.dart';
import '../utils/uuid_v4.dart';
import 'auth_session_service.dart';
import 'connectivity_service.dart';
import 'halaqah_service.dart';
import 'local_storage_service.dart';
import 'offline_sync_service.dart';
import 'push_notification_service.dart';
import 'storage_service.dart';
import 'student_service.dart';
import 'supabase_service.dart';

/// Reactive Homework & Tajweed Tasks Service with user-scoped offline cache
/// and durable outbox replay (including optional home recitation audio files).
class HomeworkService {
  HomeworkService._();

  static final HomeworkService instance = HomeworkService._();

  final List<HomeworkAssignment> _assignments = [];
  final List<HomeworkSubmission> _submissions = [];
  bool _cacheLoaded = false;
  RealtimeChannel? _assignmentsChannel;
  RealtimeChannel? _submissionsChannel;
  Timer? _realtimeDebounce;

  final StreamController<List<HomeworkAssignment>> _assignmentsController =
      StreamController<List<HomeworkAssignment>>.broadcast();

  final StreamController<List<HomeworkSubmission>> _submissionsController =
      StreamController<List<HomeworkSubmission>>.broadcast();

  Stream<List<HomeworkAssignment>> get assignmentsStream =>
      _assignmentsController.stream;
  Stream<List<HomeworkSubmission>> get submissionsStream =>
      _submissionsController.stream;

  List<HomeworkAssignment> get allAssignments => List.unmodifiable(_assignments);
  List<HomeworkSubmission> get allSubmissions => List.unmodifiable(_submissions);

  String get _uid => AuthSessionService.instance.userId.isNotEmpty
      ? AuthSessionService.instance.userId
      : (SupabaseService.instance.currentUser?.id ?? '');

  static bool _isValidUuid(String? str) => UuidV4.isValid(str);

  Future<void> _saveAssignmentsCache() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    await LocalStorageService.instance.saveUserJsonList(
      uid,
      'homework_assignments',
      _assignments.map((a) => a.toJson()).toList(),
    );
  }

  Future<void> _saveSubmissionsCache() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    await LocalStorageService.instance.saveUserJsonList(
      uid,
      'homework_submissions',
      _submissions.map((s) => s.toJson()).toList(),
    );
  }

  void _applyPendingHomeworkOverlays() {
    final assignPending = OfflineSyncService.instance
        .pendingMutationsForEntity(OfflineEntityTypes.homeworkAssignment);
    for (final mut in assignPending) {
      final p = mut.payload;
      final id = p['id']?.toString() ?? mut.id;
      if (id.isEmpty) continue;
      final assignment = HomeworkAssignment.fromJson({
        ...p,
        'id': id,
        'created_at':
            p['created_at']?.toString() ?? mut.createdAt.toUtc().toIso8601String(),
      });
      _assignments.removeWhere((a) => a.id == id);
      _assignments.insert(0, assignment);
    }

    final subPending = OfflineSyncService.instance
        .pendingMutationsForEntity(OfflineEntityTypes.homeworkSubmission);
    for (final mut in subPending) {
      final p = mut.payload;
      final id = p['id']?.toString() ?? mut.id;
      if (id.isEmpty) continue;
      final assignmentId = p['assignment_id']?.toString() ?? '';
      final studentId = p['student_id']?.toString() ?? '';
      final existingIdx = _submissions.indexWhere(
        (s) =>
            s.id == id ||
            (assignmentId.isNotEmpty &&
                s.assignmentId == assignmentId &&
                s.studentId == studentId),
      );
      if (existingIdx != -1) {
        final existing = _submissions[existingIdx];
        _submissions[existingIdx] = existing.copyWith(
          id: id,
          status: p['status']?.toString() ?? existing.status,
          repetitionCount:
              JsonParsers.asNullableInt(p['repetition_count']) ??
                  existing.repetitionCount,
          parentNote: p['parent_note']?.toString() ?? existing.parentNote,
          practicedAt: JsonParsers.asNullableDateTime(p['practiced_at']) ??
              existing.practicedAt,
          teacherRating:
              p['teacher_rating']?.toString() ?? existing.teacherRating,
          teacherFeedback:
              p['teacher_feedback']?.toString() ?? existing.teacherFeedback,
          reviewedAt: JsonParsers.asNullableDateTime(p['reviewed_at']) ??
              existing.reviewedAt,
        );
      } else {
        _submissions.insert(
          0,
          HomeworkSubmission.fromJson({
            ...p,
            'id': id,
            'parent_id': p['parent_id']?.toString() ?? _uid,
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
      final cachedAssign = await LocalStorageService.instance
          .getUserJsonList(uid, 'homework_assignments');
      if (cachedAssign.isNotEmpty && _assignments.isEmpty) {
        for (final item in cachedAssign) {
          _assignments.add(HomeworkAssignment.fromJson(item));
        }
      }

      final cachedSubs = await LocalStorageService.instance
          .getUserJsonList(uid, 'homework_submissions');
      if (cachedSubs.isNotEmpty && _submissions.isEmpty) {
        for (final item in cachedSubs) {
          _submissions.add(HomeworkSubmission.fromJson(item));
        }
      }

      _applyPendingHomeworkOverlays();

      if (_assignments.isNotEmpty && !_assignmentsController.isClosed) {
        _assignmentsController.add(List.from(_assignments));
      }
      if (_submissions.isNotEmpty && !_submissionsController.isClosed) {
        _submissionsController.add(List.from(_submissions));
      }
    } catch (e) {
      debugPrint('[HomeworkService] Cache load note: $e');
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
    final assignCh = _assignmentsChannel;
    final subCh = _submissionsChannel;
    _assignmentsChannel = null;
    _submissionsChannel = null;

    if (assignCh != null) {
      try {
        await client?.removeChannel(assignCh);
      } catch (e) {
        debugPrint('[HomeworkService] remove assignments channel note: $e');
      }
    }
    if (subCh != null) {
      try {
        await client?.removeChannel(subCh);
      } catch (e) {
        debugPrint('[HomeworkService] remove submissions channel note: $e');
      }
    }

    _assignments.clear();
    _submissions.clear();
    _cacheLoaded = false;
    if (!_assignmentsController.isClosed) {
      _assignmentsController.add([]);
    }
    if (!_submissionsController.isClosed) {
      _submissionsController.add([]);
    }
    if (uid.isNotEmpty) {
      await LocalStorageService.instance
          .removeUserCache(uid, 'homework_assignments');
      await LocalStorageService.instance
          .removeUserCache(uid, 'homework_submissions');
    }
  }

  Future<void> fetchFromCloud() async {
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) return;
    if (!ConnectivityService.instance.isOnline) return;
    try {
      final assignRes = await client
          .from('homework_assignments')
          .select(
              '*, halaqahs:halaqah_id(name), profiles:teacher_id(full_name)')
          .order('created_at', ascending: false)
          .limit(200);

      if (assignRes is List) {
        _assignments.clear();
        for (final item in assignRes) {
          _assignments.add(HomeworkAssignment.fromJson(
              Map<String, dynamic>.from(item as Map)));
        }
      }

      final subRes = await client
          .from('homework_submissions')
          .select('*, students(full_name)')
          .order('submitted_at', ascending: false)
          .limit(500);

      if (subRes is List) {
        _submissions.clear();
        for (final item in subRes) {
          _submissions.add(HomeworkSubmission.fromJson(
              Map<String, dynamic>.from(item as Map)));
        }
      }

      _applyPendingHomeworkOverlays();

      if (!_assignmentsController.isClosed) {
        _assignmentsController.add(List.from(_assignments));
      }
      if (!_submissionsController.isClosed) {
        _submissionsController.add(List.from(_submissions));
      }

      await _saveAssignmentsCache();
      await _saveSubmissionsCache();
    } catch (e) {
      debugPrint('[HomeworkService] fetchFromCloud notice: $e');
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
      final oldAssign = _assignmentsChannel;
      _assignmentsChannel = null;
      if (oldAssign != null) {
        await client.removeChannel(oldAssign);
      }
      _assignmentsChannel = client
          .channel('public:homework_assignments')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'homework_assignments',
            callback: (payload) async {
              _scheduleRealtimeRefresh();
              final newRow = payload.newRecord;
              if (newRow.isEmpty) return;
              final halaqahId = newRow['halaqah_id']?.toString() ?? '';
              final title = newRow['title']?.toString() ?? 'Quran Homework';
              if (AuthSessionService.instance.isParent) {
                final children = StudentService.instance.getStudentsForParent(
                  AuthSessionService.instance.userId,
                  parentEmail: AuthSessionService.instance.userEmail,
                );
                if (children.any((c) => c.halaqahId == halaqahId)) {
                  PushNotificationService.instance.showNotification(
                    title: 'New Quran Homework Assigned',
                    body: title,
                    payload: 'homework',
                    type: 'homework',
                  );
                }
              }
            },
          )
          .subscribe();

      final oldSub = _submissionsChannel;
      _submissionsChannel = null;
      if (oldSub != null) {
        await client.removeChannel(oldSub);
      }
      _submissionsChannel = client
          .channel('public:homework_submissions')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'homework_submissions',
            callback: (payload) async {
              _scheduleRealtimeRefresh();
              final newRow = payload.newRecord;
              if (newRow.isEmpty) return;
              final status = newRow['status']?.toString() ?? '';
              final studentName =
                  newRow['student_name']?.toString() ?? 'Student';
              final studentId = newRow['student_id']?.toString() ?? '';
              final assignmentId = newRow['assignment_id']?.toString() ?? '';

              if (status == 'completed_at_home' &&
                  AuthSessionService.instance.isTeacher) {
                final assignMatches =
                    _assignments.where((a) => a.id == assignmentId);
                final isMyAssignment = assignMatches.isNotEmpty &&
                    (assignMatches.first.teacherId ==
                            AuthSessionService.instance.userId ||
                        assignMatches.first.halaqahId ==
                            AuthSessionService.instance.assignedHalaqahId);
                if (isMyAssignment) {
                  PushNotificationService.instance.showNotification(
                    title: 'Homework Practiced at Home',
                    body: '$studentName completed home recitation practice.',
                    payload: 'homework',
                    type: 'homework',
                  );
                }
              } else if (status == 'reviewed' &&
                  AuthSessionService.instance.isParent) {
                final children = StudentService.instance.getStudentsForParent(
                  AuthSessionService.instance.userId,
                  parentEmail: AuthSessionService.instance.userEmail,
                );
                if (children.any((c) => c.id == studentId)) {
                  final rating =
                      newRow['teacher_rating']?.toString() ?? 'Reviewed';
                  PushNotificationService.instance.showNotification(
                    title: 'Homework Reviewed by Ustaz',
                    body: '$studentName: $rating',
                    payload: 'homework_review',
                    type: 'homework_review',
                  );
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[HomeworkService] Realtime subscription note: $e');
    }
  }

  /// Get assignments assigned to a specific Halaqah (or all if empty/admin).
  List<HomeworkAssignment> getAssignmentsForHalaqah(String halaqahName) {
    if (halaqahName.trim().isEmpty || halaqahName.toLowerCase() == 'all') {
      return List.unmodifiable(_assignments);
    }
    return _assignments.where((a) {
      return a.halaqahName.toLowerCase().contains(halaqahName.toLowerCase()) ||
          halaqahName.toLowerCase().contains(a.halaqahName.toLowerCase()) ||
          (AuthSessionService.instance.assignedHalaqahId.isNotEmpty &&
              a.halaqahId == AuthSessionService.instance.assignedHalaqahId);
    }).toList();
  }

  /// Get all assignments for a student's halaqah.
  List<HomeworkAssignment> getAssignmentsForStudent(
    String studentId,
    String halaqahName,
  ) {
    return getAssignmentsForHalaqah(halaqahName);
  }

  /// Get the submission state of a specific student for a given assignment.
  HomeworkSubmission? getSubmission(String assignmentId, String studentId) {
    for (final sub in _submissions) {
      if (sub.assignmentId == assignmentId && sub.studentId == studentId) {
        return sub;
      }
    }
    return null;
  }

  /// Get all submissions for an assignment.
  List<HomeworkSubmission> getSubmissionsForAssignment(String assignmentId) {
    return _submissions
        .where((sub) => sub.assignmentId == assignmentId)
        .toList();
  }

  /// Teacher Action: Create new homework task for their halaqah (works offline & online).
  Future<HomeworkAssignment> createAssignment({
    required String halaqahId,
    required String halaqahName,
    required String teacherId,
    required String teacherName,
    required String title,
    required String surahName,
    required int surahNumber,
    required int fromAyah,
    required int toAyah,
    required String tajweedFocus,
    required String instructions,
    required DateTime dueDate,
  }) async {
    String resolvedHalaqahId = halaqahId;
    if (!_isValidUuid(resolvedHalaqahId)) {
      final matching = HalaqahService.instance.halaqahs.where(
        (h) => h.name.toLowerCase() == halaqahName.toLowerCase(),
      );
      if (matching.isNotEmpty && _isValidUuid(matching.first.id)) {
        resolvedHalaqahId = matching.first.id;
      }
    }

    if (!_isValidUuid(resolvedHalaqahId)) {
      throw Exception(
          'Could not resolve a valid Study Circle ID for "$halaqahName".');
    }

    String resolvedTeacherId = teacherId;
    if (!_isValidUuid(resolvedTeacherId)) {
      final currentId = AuthSessionService.instance.userId;
      if (_isValidUuid(currentId)) resolvedTeacherId = currentId;
    }

    if (!_isValidUuid(resolvedTeacherId)) {
      throw Exception('Teacher account ID is required to assign homework.');
    }

    final assignmentId = UuidV4.generate();
    final now = DateTime.now();
    final payload = <String, dynamic>{
      'id': assignmentId,
      'halaqah_id': resolvedHalaqahId,
      'halaqah_name': halaqahName,
      'teacher_id': resolvedTeacherId,
      'teacher_name': teacherName,
      'title': title.trim(),
      'surah_name': surahName.trim(),
      'surah_number': surahNumber,
      'ayah_start': fromAyah,
      'ayah_end': toAyah,
      'tajweed_focus': tajweedFocus.trim(),
      'instructions': instructions.trim(),
      'due_date': dueDate.toUtc().toIso8601String(),
    };

    Future<HomeworkAssignment> applyLocally({
      required String resolvedId,
      required DateTime createdAt,
      required bool queueOffline,
    }) async {
      final assignment = HomeworkAssignment(
        id: resolvedId,
        halaqahId: resolvedHalaqahId,
        halaqahName: halaqahName,
        teacherId: resolvedTeacherId,
        teacherName: teacherName,
        title: title.trim(),
        surahName: surahName.trim(),
        surahNumber: surahNumber,
        fromAyah: fromAyah,
        toAyah: toAyah,
        tajweedFocus: tajweedFocus.trim(),
        instructions: instructions.trim(),
        dueDate: dueDate,
        createdAt: createdAt,
      );

      _assignments.removeWhere((a) => a.id == resolvedId);
      _assignments.insert(0, assignment);
      if (!_assignmentsController.isClosed) {
        _assignmentsController.add(List.from(_assignments));
      }
      await _saveAssignmentsCache();

      if (queueOffline) {
        await OfflineSyncService.instance.enqueue(
          entityType: OfflineEntityTypes.homeworkAssignment,
          operation: 'upsert',
          id: resolvedId,
          payload: {
            ...payload,
            'id': resolvedId,
          },
          displayLabel: 'Homework: ${title.trim()}',
          triggerImmediateSync: false,
        );
      }

      return assignment;
    }

    final client = SupabaseService.instance.client;
    if (!ConnectivityService.instance.isOnline || client == null) {
      return await applyLocally(
        resolvedId: assignmentId,
        createdAt: now,
        queueOffline: true,
      );
    }

    try {
      final inserted = await client
          .from('homework_assignments')
          .upsert(payload, onConflict: 'id')
          .select('id, created_at')
          .single();

      final finalId = inserted['id']?.toString() ?? assignmentId;
      final assignment = await applyLocally(
        resolvedId: finalId,
        createdAt: JsonParsers.asDateTime(inserted['created_at'], now),
        queueOffline: false,
      );

      final classStudents = StudentService.instance.getStudentsForHalaqah(
        halaqahName,
        halaqahId: resolvedHalaqahId,
      );
      final parentIds = classStudents
          .map((s) => s.parentId)
          .whereType<String>()
          .where((id) => _isValidUuid(id))
          .toSet()
          .toList();
      if (parentIds.isNotEmpty) {
        PushNotificationService.instance.dispatchPushToUsers(
          userIds: parentIds,
          title: 'New Homework Assigned',
          body:
              '${assignment.title} (${assignment.surahName}, Ayah ${assignment.fromAyah}-${assignment.toAyah})',
          type: 'homework',
          data: {
            'assignment_id': assignment.id,
            'halaqah_id': resolvedHalaqahId,
            'template_key': 'homework_assigned',
            'params': {
              'title': assignment.title,
              'surah': assignment.surahName,
              'from_ayah': '${assignment.fromAyah}',
              'to_ayah': '${assignment.toAyah}',
            },
          },
        );
      }
      return assignment;
    } catch (e) {
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
        return await applyLocally(
          resolvedId: assignmentId,
          createdAt: now,
          queueOffline: true,
        );
      }
      rethrow;
    }
  }

  /// Parent Action: Mark homework practiced at home (supports offline queue & optional `.m4a` staging).
  Future<void> markCompletedByParent({
    required String assignmentId,
    required String studentId,
    required int repetitionCount,
    String? notes,
    String? localAudioPath,
    int audioDurationSeconds = 0,
  }) async {
    if (!_isValidUuid(assignmentId) || !_isValidUuid(studentId)) {
      throw Exception('Cannot submit homework: invalid identifier.');
    }

    final index = _submissions.indexWhere(
      (s) => s.assignmentId == assignmentId && s.studentId == studentId,
    );

    final practicedAt = DateTime.now();
    final isoTimestamp = practicedAt.toUtc().toIso8601String();
    final studentMatches =
        StudentService.instance.allStudents.where((s) => s.id == studentId);
    final student = studentMatches.isNotEmpty ? studentMatches.first : null;
    final parentId = AuthSessionService.instance.userId;

    final hasExistingValidId =
        index != -1 && _isValidUuid(_submissions[index].id);
    final String subId =
        hasExistingValidId ? _submissions[index].id : UuidV4.generate();

    final hasAudio = localAudioPath != null && localAudioPath.trim().isNotEmpty;
    final ms = DateTime.now().millisecondsSinceEpoch;
    final audioStoragePath = 'homework/$assignmentId/${studentId}_$ms.m4a';

    Future<void> applyLocally({
      required String resolvedId,
      required bool queueOffline,
      String? stagedPath,
    }) async {
      if (index != -1) {
        final existing = _submissions[index];
        _submissions[index] = existing.copyWith(
          id: resolvedId,
          status: 'completed_at_home',
          repetitionCount: repetitionCount,
          parentNote: notes,
          practicedAt: practicedAt,
        );
      } else {
        _submissions.insert(
          0,
          HomeworkSubmission(
            id: resolvedId,
            assignmentId: assignmentId,
            studentId: studentId,
            studentName: student?.fullName ?? 'Student',
            parentId: parentId,
            status: 'completed_at_home',
            repetitionCount: repetitionCount,
            parentNote: notes,
            practicedAt: practicedAt,
          ),
        );
      }

      if (!_submissionsController.isClosed) {
        _submissionsController.add(List.from(_submissions));
      }
      await _saveSubmissionsCache();

      if (queueOffline) {
        final Map<String, dynamic> mutPayload;
        if (hasExistingValidId) {
          mutPayload = {
            'id': resolvedId,
            'assignment_id': assignmentId,
            'student_id': studentId,
            'status': 'completed_at_home',
            'repetition_count': repetitionCount,
            'parent_note': notes,
            'practiced_at': isoTimestamp,
            'submitted_at': isoTimestamp,
            if (hasAudio) 'duration_seconds': audioDurationSeconds,
          };
        } else {
          mutPayload = {
            'id': resolvedId,
            'assignment_id': assignmentId,
            'student_id': studentId,
            'student_name': student?.fullName ?? 'Student',
            if (_isValidUuid(parentId)) 'parent_id': parentId,
            'audio_url':
                stagedPath != null ? 'local://$stagedPath' : 'completed_at_home',
            'duration_seconds': hasAudio ? audioDurationSeconds : 0,
            'status': 'completed_at_home',
            'repetition_count': repetitionCount,
            'parent_note': notes,
            'practiced_at': isoTimestamp,
            'submitted_at': isoTimestamp,
          };
        }

        await OfflineSyncService.instance.enqueue(
          entityType: OfflineEntityTypes.homeworkSubmission,
          operation: hasExistingValidId ? 'update' : 'upsert',
          id: resolvedId,
          payload: mutPayload,
          localMediaPath: stagedPath,
          storageBucket:
              stagedPath != null ? StorageService.voiceMessagesBucket : null,
          storagePath: stagedPath != null ? audioStoragePath : null,
          mediaPayloadField: stagedPath != null ? 'audio_url' : null,
          mediaMimeType: stagedPath != null ? 'audio/m4a' : null,
          displayLabel:
              'Homework practice: ${student?.fullName ?? "Student"}',
          triggerImmediateSync: false,
        );
      }
    }

    final client = SupabaseService.instance.client;
    if (!ConnectivityService.instance.isOnline || client == null) {
      String? stagedPath;
      if (hasAudio) {
        stagedPath = await OfflineSyncService.instance.stageMediaFile(
          sourcePath: localAudioPath,
          fileName: 'homework_${studentId}_$ms.m4a',
        );
      }
      await applyLocally(
        resolvedId: subId,
        queueOffline: true,
        stagedPath: stagedPath,
      );
      return;
    }

    try {
      String audioRef = 'completed_at_home';
      if (hasAudio) {
        final uploaded = await StorageService.uploadFilePath(
          bucket: StorageService.voiceMessagesBucket,
          path: audioStoragePath,
          filePath: localAudioPath,
          mimeType: 'audio/m4a',
          upsert: true,
        );
        if (uploaded == null) {
          throw Exception('Failed to upload homework audio recording.');
        }
        audioRef = uploaded;
      }

      String finalSubId = subId;
      if (hasExistingValidId) {
        await client.from('homework_submissions').update({
          'status': 'completed_at_home',
          'repetition_count': repetitionCount,
          'parent_note': notes,
          'practiced_at': isoTimestamp,
          'submitted_at': isoTimestamp,
          if (hasAudio) 'audio_url': audioRef,
          if (hasAudio) 'duration_seconds': audioDurationSeconds,
        }).eq('id', subId);
      } else {
        final inserted = await client.from('homework_submissions').upsert(
          {
            'id': subId,
            'assignment_id': assignmentId,
            'student_id': studentId,
            'student_name': student?.fullName ?? 'Student',
            if (_isValidUuid(parentId)) 'parent_id': parentId,
            'audio_url': audioRef,
            'duration_seconds': hasAudio ? audioDurationSeconds : 0,
            'status': 'completed_at_home',
            'repetition_count': repetitionCount,
            'parent_note': notes,
            'practiced_at': isoTimestamp,
            'submitted_at': isoTimestamp,
          },
          onConflict: 'id',
        ).select('id').single();
        finalSubId = inserted['id']?.toString() ?? subId;
      }

      await applyLocally(resolvedId: finalSubId, queueOffline: false);

      final assignMatches = _assignments.where((a) => a.id == assignmentId);
      final teacherIds = <String>{};
      if (assignMatches.isNotEmpty) {
        final assign = assignMatches.first;
        if (_isValidUuid(assign.teacherId)) {
          teacherIds.add(assign.teacherId);
        }
        final circleTeacher = HalaqahService.instance.halaqahs
            .where((h) => h.id == assign.halaqahId)
            .map((h) => h.teacherId)
            .whereType<String>()
            .where((id) => _isValidUuid(id));
        teacherIds.addAll(circleTeacher);
      }
      if (teacherIds.isNotEmpty) {
        PushNotificationService.instance.dispatchPushToUsers(
          userIds: teacherIds.toList(),
          title: 'Homework Practiced at Home',
          body:
              '${student?.fullName ?? "A student"} completed $repetitionCount repetition(s) at home.',
          type: 'homework',
          data: {
            'assignment_id': assignmentId,
            'student_id': studentId,
            'template_key': 'homework_submitted',
            'params': {
              'student_name': student?.fullName ?? '',
              'title': assignMatches.isNotEmpty ? assignMatches.first.title : '',
            },
          },
        );
      }
    } catch (e) {
      if (ConnectivityService.isNetworkError(e) || hasAudio) {
        if (ConnectivityService.isNetworkError(e)) {
          ConnectivityService.instance.reportNetworkFailure();
        }
        if (ConnectivityService.isNetworkError(e) ||
            !ConnectivityService.instance.isOnline) {
          String? stagedPath;
          if (hasAudio) {
            stagedPath = await OfflineSyncService.instance.stageMediaFile(
              sourcePath: localAudioPath,
              fileName: 'homework_${studentId}_$ms.m4a',
            );
          }
          await applyLocally(
            resolvedId: subId,
            queueOffline: true,
            stagedPath: stagedPath,
          );
          return;
        }
      }
      rethrow;
    }
  }

  /// Teacher Action: Review and endorse student's home practice (works offline & online).
  Future<void> reviewSubmissionByTeacher({
    required String submissionId,
    required String teacherRating,
    String? teacherFeedback,
  }) async {
    final index = _submissions.indexWhere((s) => s.id == submissionId);
    if (index == -1 || !_isValidUuid(submissionId)) return;

    final existing = _submissions[index];
    final reviewedAt = DateTime.now();
    final updateFields = <String, dynamic>{
      'status': 'reviewed',
      'teacher_rating': teacherRating,
      'teacher_feedback': teacherFeedback,
      'teacher_feedback_text': teacherFeedback,
      'reviewed_at': reviewedAt.toUtc().toIso8601String(),
    };

    Future<void> applyLocally({required bool queueOffline}) async {
      _submissions[index] = existing.copyWith(
        status: 'reviewed',
        teacherRating: teacherRating,
        teacherFeedback: teacherFeedback,
        reviewedAt: reviewedAt,
      );
      if (!_submissionsController.isClosed) {
        _submissionsController.add(List.from(_submissions));
      }
      await _saveSubmissionsCache();

      if (queueOffline) {
        await OfflineSyncService.instance.enqueue(
          entityType: OfflineEntityTypes.homeworkSubmission,
          operation: 'update',
          id: submissionId,
          payload: {
            'id': submissionId,
            ...updateFields,
          },
          displayLabel: 'Review homework: ${existing.studentName}',
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
          .from('homework_submissions')
          .update(updateFields)
          .eq('id', submissionId);
      await applyLocally(queueOffline: false);

      if (_isValidUuid(existing.parentId)) {
        PushNotificationService.instance.dispatchPushToUsers(
          userIds: [existing.parentId],
          title: 'Homework Reviewed by Ustaz',
          body: '${existing.studentName}: $teacherRating',
          type: 'homework_review',
          data: {
            'assignment_id': existing.assignmentId,
            'student_id': existing.studentId,
            'template_key': 'homework_reviewed',
            'params': {
              'student_name': existing.studentName,
              'rating': teacherRating,
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
