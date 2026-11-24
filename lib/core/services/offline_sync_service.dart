import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/json_parsers.dart';
import '../utils/uuid_v4.dart';
import 'connectivity_service.dart';
import 'local_storage_service.dart';
import 'storage_service.dart';
import 'supabase_service.dart';

/// Canonical entity keys supported by the durable offline outbox queue.
class OfflineEntityTypes {
  OfflineEntityTypes._();

  static const String attendance = 'attendance';
  static const String hifz = 'hifz';
  static const String weeklyReport = 'weekly_report';
  static const String homeworkAssignment = 'homework_assignment';
  static const String homeworkSubmission = 'homework_submission';
  static const String absenceRequest = 'absence_request';
  static const String chatMessage = 'chat_message';
  static const String paymentReceipt = 'payment_receipt';
  static const String announcement = 'announcement';
  static const String student = 'student';
}

/// A single idempotent write mutation queued for durable cloud replay.
class OfflineMutation {
  final String id;
  final String entityType;
  final String operation; // 'upsert', 'update', 'delete'
  final Map<String, dynamic> payload;
  final String? localMediaPath;
  final String? storageBucket;
  final String? storagePath;
  final String? mediaPayloadField;
  final String? mediaMimeType;
  final String? displayLabel;
  final DateTime createdAt;
  final int retryCount;
  final String status; // 'pending', 'syncing', 'failed'
  final String? lastError;

  const OfflineMutation({
    required this.id,
    required this.entityType,
    required this.operation,
    required this.payload,
    this.localMediaPath,
    this.storageBucket,
    this.storagePath,
    this.mediaPayloadField,
    this.mediaMimeType,
    this.displayLabel,
    required this.createdAt,
    this.retryCount = 0,
    this.status = 'pending',
    this.lastError,
  });

  String get targetRecordId => payload['id']?.toString() ?? id;

  bool get isFailed => status == 'failed';
  bool get isSyncing => status == 'syncing';
  bool get isPending => status == 'pending';

  OfflineMutation copyWith({
    String? operation,
    Map<String, dynamic>? payload,
    String? localMediaPath,
    String? storageBucket,
    String? storagePath,
    String? mediaPayloadField,
    String? mediaMimeType,
    String? displayLabel,
    int? retryCount,
    String? status,
    String? lastError,
    bool clearError = false,
  }) {
    return OfflineMutation(
      id: id,
      entityType: entityType,
      operation: operation ?? this.operation,
      payload: payload ?? Map<String, dynamic>.from(this.payload),
      localMediaPath: localMediaPath ?? this.localMediaPath,
      storageBucket: storageBucket ?? this.storageBucket,
      storagePath: storagePath ?? this.storagePath,
      mediaPayloadField: mediaPayloadField ?? this.mediaPayloadField,
      mediaMimeType: mediaMimeType ?? this.mediaMimeType,
      displayLabel: displayLabel ?? this.displayLabel,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entity_type': entityType,
      'operation': operation,
      'payload': payload,
      'local_media_path': localMediaPath,
      'storage_bucket': storageBucket,
      'storage_path': storagePath,
      'media_payload_field': mediaPayloadField,
      'media_mime_type': mediaMimeType,
      'display_label': displayLabel,
      'created_at': createdAt.toUtc().toIso8601String(),
      'retry_count': retryCount,
      'status': status,
      'last_error': lastError,
    };
  }

  factory OfflineMutation.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    final parsedPayload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    return OfflineMutation(
      id: (json['id'] ?? UuidV4.generate()).toString(),
      entityType: (json['entity_type'] ?? '').toString(),
      operation: (json['operation'] ?? 'upsert').toString(),
      payload: parsedPayload,
      localMediaPath: json['local_media_path']?.toString(),
      storageBucket: json['storage_bucket']?.toString(),
      storagePath: json['storage_path']?.toString(),
      mediaPayloadField: json['media_payload_field']?.toString(),
      mediaMimeType: json['media_mime_type']?.toString(),
      displayLabel: json['display_label']?.toString(),
      createdAt: JsonParsers.asDateTime(json['created_at']),
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'pending').toString(),
      lastError: json['last_error']?.toString(),
    );
  }
}

/// Snapshot of current offline sync state for banners & settings.
class OfflineSyncStatus {
  final bool isSyncing;
  final int pendingCount;
  final int failedCount;
  final DateTime? lastSyncedAt;
  final bool justSynced;

  const OfflineSyncStatus({
    this.isSyncing = false,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastSyncedAt,
    this.justSynced = false,
  });

  int get totalActionableCount => pendingCount + failedCount;
}

/// Durable user-scoped FIFO Outbox & Persistent Media Staging Engine.
/// - Atomic queue persistence in `<appDocs>/offline_sync/queue_<userId>.json`
/// - Persistent media staging in `<appDocs>/offline_sync/media_<userId>/`
/// - Exponential backoff on transient network failures; clean failed state on 4xx/RLS
/// - Zero cross-account leakage (all files & staged media wiped on Sign Out)
class OfflineSyncService {
  OfflineSyncService._();

  static final OfflineSyncService instance = OfflineSyncService._();

  static const List<int> _backoffSeconds = [5, 15, 45, 120];

  final ValueNotifier<OfflineSyncStatus> statusNotifier =
      ValueNotifier<OfflineSyncStatus>(const OfflineSyncStatus());

  final ValueNotifier<List<OfflineMutation>> mutationsNotifier =
      ValueNotifier<List<OfflineMutation>>(const []);

  /// Optional callback invoked after one or more queued mutations succeed in a batch.
  void Function(Set<String> syncedEntityTypes)? onBatchSynced;

  String? _activeUserId;
  final List<OfflineMutation> _queue = [];
  bool _isSyncing = false;
  DateTime? _lastSyncedAt;
  bool _justSynced = false;
  Timer? _backoffTimer;
  Timer? _justSyncedTimer;
  StreamSubscription<void>? _reconnectedSub;

  List<OfflineMutation> get mutations => List.unmodifiable(_queue);
  String? get activeUserId => _activeUserId;

  static String _sanitizeSegment(String raw) {
    final clean = raw.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return clean.isEmpty ? 'invalid' : clean;
  }

  /// Resolves the root offline_sync directory safely on mobile/desktop.
  Future<Directory?> _ensureSyncRootDir() async {
    if (kIsWeb) return null;
    final appDocs = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDocs.path}/offline_sync');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File?> _queueFileForUser(String userId) async {
    if (kIsWeb || userId.trim().isEmpty) return null;
    final root = await _ensureSyncRootDir();
    if (root == null) return null;
    return File('${root.path}/queue_${_sanitizeSegment(userId)}.json');
  }

  Future<Directory?> _mediaDirForUser(String userId) async {
    if (kIsWeb || userId.trim().isEmpty) return null;
    final root = await _ensureSyncRootDir();
    if (root == null) return null;
    final dir = Directory('${root.path}/media_${_sanitizeSegment(userId)}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copies a temporary file (e.g. from OS temp / recorder cache) into
  /// persistent user-scoped offline media storage so the OS never evicts it.
  Future<String> stageMediaFile({
    required String sourcePath,
    required String fileName,
    String? userIdOverride,
  }) async {
    final uid = (userIdOverride ??
            _activeUserId ??
            SupabaseService.instance.currentUser?.id ??
            '')
        .trim();
    if (uid.isEmpty) {
      throw StateError('Cannot stage media without an authenticated user.');
    }
    if (kIsWeb) {
      throw UnsupportedError('Local file staging is not supported on Web.');
    }
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('Source media file does not exist: $sourcePath');
    }
    final dir = await _mediaDirForUser(uid);
    if (dir == null) {
      throw StateError('Unable to resolve persistent offline media folder.');
    }
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final destPath =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${UuidV4.generate().substring(0, 8)}_$cleanName';
    await source.copy(destPath);
    return destPath;
  }

  /// Writes in-memory media bytes directly into persistent user-scoped
  /// offline media storage (e.g. receipt images picked from ImagePicker).
  Future<String> stageMediaBytes({
    required Uint8List bytes,
    required String fileName,
    String? userIdOverride,
  }) async {
    final uid = (userIdOverride ??
            _activeUserId ??
            SupabaseService.instance.currentUser?.id ??
            '')
        .trim();
    if (uid.isEmpty) {
      throw StateError('Cannot stage media without an authenticated user.');
    }
    if (kIsWeb) {
      throw UnsupportedError('Local byte staging is not supported on Web.');
    }
    final dir = await _mediaDirForUser(uid);
    if (dir == null) {
      throw StateError('Unable to resolve persistent offline media folder.');
    }
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final destPath =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${UuidV4.generate().substring(0, 8)}_$cleanName';
    final file = File(destPath);
    final tmp = File('$destPath.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
    return file.path;
  }

  /// Returns true if a non-failed mutation for `(entityType, recordId)` is pending or syncing.
  bool isRecordPending(String entityType, String recordId) {
    if (recordId.trim().isEmpty) return false;
    return _queue.any(
      (m) =>
          m.entityType == entityType &&
          !m.isFailed &&
          (m.id == recordId || m.targetRecordId == recordId),
    );
  }

  /// Returns all queued (non-failed or pending) mutations matching [entityType].
  List<OfflineMutation> pendingMutationsForEntity(String entityType) {
    return _queue
        .where((m) => m.entityType == entityType && !m.isFailed)
        .toList();
  }

  /// Initializes the durable outbox for [userId], resets crashed `syncing` items
  /// back to `pending`, and hooks automatic sync on connectivity return.
  Future<void> initializeForUser(String userId) async {
    final cleanUid = userId.trim();
    if (cleanUid.isEmpty) return;

    if (_activeUserId != cleanUid) {
      _backoffTimer?.cancel();
      _justSyncedTimer?.cancel();
      _activeUserId = cleanUid;
      _queue.clear();
      _lastSyncedAt = null;
      _justSynced = false;
      await _loadQueueFromDisk(cleanUid);
    }

    await _reconnectedSub?.cancel();
    _reconnectedSub = ConnectivityService.instance.onReconnected.listen((_) {
      unawaited(syncPendingMutations());
    });

    _publishStatus();
    if (ConnectivityService.instance.isOnline &&
        _queue.any((m) => m.isPending)) {
      unawaited(syncPendingMutations());
    }
  }

  Future<void> _loadQueueFromDisk(String userId) async {
    try {
      String? raw;
      if (kIsWeb) {
        raw = await LocalStorageService.instance.getString(
          'offline_queue_${_sanitizeSegment(userId)}',
        );
      } else {
        final file = await _queueFileForUser(userId);
        if (file != null && await file.exists()) {
          raw = await file.readAsString();
        }
      }
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        var needsResave = false;
        for (final entry in decoded) {
          if (entry is Map) {
            var mut =
                OfflineMutation.fromJson(Map<String, dynamic>.from(entry));
            if (mut.isSyncing) {
              // Recover gracefully if the app crashed mid-upload.
              mut = mut.copyWith(status: 'pending');
              needsResave = true;
            }
            _queue.add(mut);
          }
        }
        if (needsResave) {
          await _persistQueue();
        }
      }
    } catch (e) {
      debugPrint('[OfflineSyncService] Load queue note: $e');
    }
  }

  Future<void> _persistQueue() async {
    final uid = _activeUserId;
    if (uid == null || uid.isEmpty) return;
    final encoded = jsonEncode(_queue.map((m) => m.toJson()).toList());

    if (kIsWeb) {
      await LocalStorageService.instance.saveString(
        'offline_queue_${_sanitizeSegment(uid)}',
        encoded,
      );
      return;
    }

    try {
      final file = await _queueFileForUser(uid);
      if (file == null) return;
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(encoded, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('[OfflineSyncService] Persist queue error: $e');
    }
  }

  void _publishStatus() {
    final pendingCount = _queue.where((m) => !m.isFailed).length;
    final failedCount = _queue.where((m) => m.isFailed).length;
    mutationsNotifier.value = List<OfflineMutation>.unmodifiable(_queue);
    statusNotifier.value = OfflineSyncStatus(
      isSyncing: _isSyncing,
      pendingCount: pendingCount,
      failedCount: failedCount,
      lastSyncedAt: _lastSyncedAt,
      justSynced: _justSynced,
    );
  }

  /// Adds a durable write mutation into the FIFO queue and triggers immediate
  /// replay if connectivity is currently online.
  Future<OfflineMutation> enqueue({
    required String entityType,
    required String operation,
    required Map<String, dynamic> payload,
    String? id,
    String? localMediaPath,
    String? storageBucket,
    String? storagePath,
    String? mediaPayloadField,
    String? mediaMimeType,
    String? displayLabel,
    bool triggerImmediateSync = true,
  }) async {
    final uid = (_activeUserId ??
            SupabaseService.instance.currentUser?.id ??
            '')
        .trim();
    if (uid.isEmpty) {
      throw StateError('No active user session to queue offline mutation.');
    }
    if (_activeUserId != uid) {
      await initializeForUser(uid);
    }

    final payloadCopy = Map<String, dynamic>.from(payload);
    final mutationId =
        (id != null && UuidV4.isValid(id)) ? id : UuidV4.generate();
    if ((operation == 'upsert' || operation == 'insert') &&
        payloadCopy['id'] == null) {
      payloadCopy['id'] = mutationId;
    }

    // Coalesce idempotent attendance updates for the same student + date.
    if (entityType == OfflineEntityTypes.attendance) {
      _queue.removeWhere(
        (existing) =>
            existing.entityType == OfflineEntityTypes.attendance &&
            !existing.isSyncing &&
            existing.payload['student_id']?.toString() ==
                payloadCopy['student_id']?.toString() &&
            existing.payload['session_date']?.toString() ==
                payloadCopy['session_date']?.toString(),
      );
    }

    final mutation = OfflineMutation(
      id: mutationId,
      entityType: entityType,
      operation: operation,
      payload: payloadCopy,
      localMediaPath: localMediaPath,
      storageBucket: storageBucket,
      storagePath: storagePath,
      mediaPayloadField: mediaPayloadField,
      mediaMimeType: mediaMimeType,
      displayLabel: displayLabel,
      createdAt: DateTime.now().toUtc(),
      retryCount: 0,
      status: 'pending',
    );

    _queue.add(mutation);
    await _persistQueue();
    _publishStatus();

    if (triggerImmediateSync && ConnectivityService.instance.isOnline) {
      unawaited(syncPendingMutations());
    }

    return mutation;
  }

  /// Replays all `pending` mutations in strict FIFO order using a mutex.
  Future<void> syncPendingMutations() async {
    final uid = _activeUserId;
    if (uid == null || uid.isEmpty || _isSyncing) return;
    if (!ConnectivityService.instance.isOnline) return;

    final client = SupabaseService.instance.client;
    final authUser = SupabaseService.instance.currentUser;
    if (client == null || authUser == null || authUser.id != uid) return;

    if (!_queue.any((m) => m.isPending)) {
      _publishStatus();
      return;
    }

    _backoffTimer?.cancel();
    _isSyncing = true;
    _justSynced = false;
    _publishStatus();

    final syncedEntityTypes = <String>{};
    var stoppedForNetworkError = false;

    try {
      final targetIds =
          _queue.where((m) => m.isPending).map((m) => m.id).toList();

      for (final id in targetIds) {
        if (_activeUserId != uid || SupabaseService.instance.currentUser?.id != uid) {
          break;
        }
        final idx = _queue.indexWhere((m) => m.id == id);
        if (idx < 0) continue;
        final current = _queue[idx];
        if (!current.isPending) continue;

        _queue[idx] = current.copyWith(status: 'syncing', clearError: true);
        await _persistQueue();
        _publishStatus();

        try {
          await _executeMutation(client, current);

          final removeIdx = _queue.indexWhere((m) => m.id == id);
          if (removeIdx >= 0) {
            _queue.removeAt(removeIdx);
          }
          await _persistQueue();
          await _deleteStagedMediaQuietly(current.localMediaPath);
          syncedEntityTypes.add(current.entityType);
        } catch (e) {
          final isNetwork = ConnectivityService.isNetworkError(e);
          final nextRetry = current.retryCount + 1;
          final cleanMsg = SupabaseService.cleanErrorMessage(e);

          final errIdx = _queue.indexWhere((m) => m.id == id);
          if (errIdx >= 0) {
            if (isNetwork || !_isPermanentError(e)) {
              _queue[errIdx] = current.copyWith(
                status: 'pending',
                retryCount: nextRetry,
                lastError: cleanMsg,
              );
              await _persistQueue();
              ConnectivityService.instance.reportNetworkFailure();
              _scheduleBackoff(nextRetry);
              stoppedForNetworkError = true;
              break;
            } else {
              _queue[errIdx] = current.copyWith(
                status: 'failed',
                retryCount: nextRetry,
                lastError: cleanMsg,
              );
              await _persistQueue();
            }
          }
        }
      }
    } finally {
      _isSyncing = false;
      if (syncedEntityTypes.isNotEmpty) {
        _lastSyncedAt = DateTime.now();
        _justSynced = _queue.isEmpty && !stoppedForNetworkError;
        if (_justSynced) {
          _justSyncedTimer?.cancel();
          _justSyncedTimer = Timer(const Duration(milliseconds: 2500), () {
            _justSynced = false;
            _publishStatus();
          });
        }
      }
      _publishStatus();

      if (syncedEntityTypes.isNotEmpty) {
        try {
          onBatchSynced?.call(syncedEntityTypes);
        } catch (e) {
          debugPrint('[OfflineSyncService] onBatchSynced callback note: $e');
        }
      }
    }
  }

  bool _isPermanentError(Object e) {
    if (ConnectivityService.isNetworkError(e)) return false;
    if (e is PostgrestException || e is AuthException || e is FormatException || e is StateError) {
      return true;
    }
    if (e is StorageException) {
      final code = (e.statusCode ?? '').trim();
      return code.startsWith('4');
    }
    return false;
  }

  void _scheduleBackoff(int retryCount) {
    _backoffTimer?.cancel();
    final idx = (retryCount - 1).clamp(0, _backoffSeconds.length - 1);
    final delaySeconds = _backoffSeconds[idx];
    _backoffTimer = Timer(Duration(seconds: delaySeconds), () {
      unawaited(() async {
        final online = await ConnectivityService.instance.checkNow();
        if (online) {
          await syncPendingMutations();
        }
      }());
    });
  }

  Future<void> _executeMutation(
    SupabaseClient client,
    OfflineMutation m,
  ) async {
    final rawPayload = Map<String, dynamic>.from(m.payload);
    final previewText = rawPayload['_preview_text']?.toString();
    final parentIdMeta = rawPayload['_parent_id']?.toString();

    final dbPayload = <String, dynamic>{};
    for (final entry in rawPayload.entries) {
      if (!entry.key.startsWith('_')) {
        dbPayload[entry.key] = entry.value;
      }
    }

    if (m.localMediaPath != null && m.localMediaPath!.isNotEmpty) {
      final bucket = m.storageBucket ?? '';
      final path = m.storagePath ?? '';
      if (bucket.isEmpty || path.isEmpty) {
        throw StateError('Missing target storage path for offline media.');
      }
      final file = File(m.localMediaPath!);
      if (!await file.exists()) {
        throw StateError('Offline media file missing for ${m.entityType}.');
      }
      final bytes = await file.readAsBytes();
      final ref = await StorageService.uploadFile(
        bucket: bucket,
        path: path,
        bytes: bytes,
        mimeType: m.mediaMimeType,
        upsert: true,
        throwOnError: true,
      );
      if (ref == null || ref.isEmpty) {
        throw StateError('Storage upload returned empty reference.');
      }
      dbPayload[m.mediaPayloadField ?? 'attachment_url'] = ref;
    }

    switch (m.entityType) {
      case OfflineEntityTypes.attendance:
        dbPayload.remove('id');
        await client
            .from('student_attendance')
            .upsert(dbPayload, onConflict: 'student_id,session_date');
        break;

      case OfflineEntityTypes.hifz:
        await client.from('hifz_records').upsert(dbPayload, onConflict: 'id');
        break;

      case OfflineEntityTypes.weeklyReport:
        await client
            .from('weekly_reports')
            .upsert(dbPayload, onConflict: 'id');
        break;

      case OfflineEntityTypes.student:
        await client.from('students').upsert(dbPayload, onConflict: 'id');
        final studentId = dbPayload['id']?.toString() ?? '';
        if (parentIdMeta != null &&
            UuidV4.isValid(parentIdMeta) &&
            UuidV4.isValid(studentId)) {
          try {
            await client.from('parent_students').upsert(
              {
                'parent_id': parentIdMeta,
                'student_id': studentId,
              },
              onConflict: 'parent_id,student_id',
            );
          } catch (_) {
            try {
              await client.from('parent_students').insert({
                'parent_id': parentIdMeta,
                'student_id': studentId,
              });
            } catch (linkErr) {
              if (!linkErr.toString().contains('23505')) rethrow;
            }
          }
        }
        break;

      case OfflineEntityTypes.homeworkAssignment:
        await client
            .from('homework_assignments')
            .upsert(dbPayload, onConflict: 'id');
        break;

      case OfflineEntityTypes.homeworkSubmission:
        if (m.operation == 'update') {
          final targetId = dbPayload.remove('id')?.toString() ?? m.id;
          await client
              .from('homework_submissions')
              .update(dbPayload)
              .eq('id', targetId);
        } else {
          await client
              .from('homework_submissions')
              .upsert(dbPayload, onConflict: 'id');
        }
        break;

      case OfflineEntityTypes.absenceRequest:
        if (m.operation == 'update') {
          final targetId = dbPayload.remove('id')?.toString() ?? m.id;
          await client
              .from('absence_requests')
              .update(dbPayload)
              .eq('id', targetId);
        } else {
          await client
              .from('absence_requests')
              .upsert(dbPayload, onConflict: 'id');
        }
        break;

      case OfflineEntityTypes.chatMessage:
        await client.from('messages').upsert(dbPayload, onConflict: 'id');
        final conversationId = dbPayload['conversation_id']?.toString() ?? '';
        if (conversationId.isNotEmpty) {
          try {
            await client.from('conversations').update({
              'last_message': previewText ??
                  dbPayload['content']?.toString() ??
                  'New message',
              'last_message_time': dbPayload['created_at']?.toString() ??
                  DateTime.now().toUtc().toIso8601String(),
            }).eq('id', conversationId);
          } catch (e) {
            debugPrint('[OfflineSyncService] Conversation timestamp update note: $e');
          }
        }
        break;

      case OfflineEntityTypes.paymentReceipt:
        final paymentId = dbPayload.remove('id')?.toString() ?? m.id;
        await client
            .from('monthly_payments')
            .update(dbPayload)
            .eq('id', paymentId);
        break;

      case OfflineEntityTypes.announcement:
        await client.from('announcements').upsert(dbPayload, onConflict: 'id');
        break;

      default:
        throw StateError('Unknown offline entityType: ${m.entityType}');
    }
  }

  Future<void> _deleteStagedMediaQuietly(String? path) async {
    if (kIsWeb || path == null || path.trim().isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (e) {
      debugPrint('[OfflineSyncService] Cleanup staged file note: $e');
    }
  }

  /// Marks a failed mutation back to `pending` and replays immediately if online.
  Future<void> retryFailed(String id) async {
    final idx = _queue.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    _queue[idx] = _queue[idx].copyWith(
      status: 'pending',
      clearError: true,
    );
    await _persistQueue();
    _publishStatus();
    if (await ConnectivityService.instance.checkNow()) {
      await syncPendingMutations();
    }
  }

  /// Retries all failed mutations at once.
  Future<void> retryAllFailed() async {
    var changed = false;
    for (int i = 0; i < _queue.length; i++) {
      if (_queue[i].isFailed) {
        _queue[i] = _queue[i].copyWith(status: 'pending', clearError: true);
        changed = true;
      }
    }
    if (!changed) return;
    await _persistQueue();
    _publishStatus();
    if (await ConnectivityService.instance.checkNow()) {
      await syncPendingMutations();
    }
  }

  /// Permanently removes a mutation and deletes any staged offline media for it.
  Future<void> discardMutation(String id) async {
    final idx = _queue.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    final removed = _queue.removeAt(idx);
    await _persistQueue();
    await _deleteStagedMediaQuietly(removed.localMediaPath);
    _publishStatus();
  }

  /// Completely wipes outbox queue + staged offline media files for [userId].
  Future<void> clearForUser(String userId) async {
    final cleanUid = userId.trim();
    _backoffTimer?.cancel();
    _justSyncedTimer?.cancel();
    await _reconnectedSub?.cancel();
    _reconnectedSub = null;
    _isSyncing = false;
    _justSynced = false;
    _lastSyncedAt = null;

    if (cleanUid.isNotEmpty) {
      if (kIsWeb) {
        await LocalStorageService.instance.remove(
          'offline_queue_${_sanitizeSegment(cleanUid)}',
        );
      } else {
        try {
          final qFile = await _queueFileForUser(cleanUid);
          if (qFile != null && await qFile.exists()) {
            await qFile.delete();
          }
          final tmpFile = qFile != null ? File('${qFile.path}.tmp') : null;
          if (tmpFile != null && await tmpFile.exists()) {
            await tmpFile.delete();
          }
          final mDir = await _mediaDirForUser(cleanUid);
          if (mDir != null && await mDir.exists()) {
            await mDir.delete(recursive: true);
          }
        } catch (e) {
          debugPrint('[OfflineSyncService] Clear user sync storage note: $e');
        }
      }
    }

    if (_activeUserId == cleanUid || cleanUid.isEmpty) {
      _activeUserId = null;
      _queue.clear();
      onBatchSynced = null;
      _publishStatus();
    }
  }

  /// Wipes outbox queue and staged media for the currently active user.
  Future<void> clearForCurrentUser() async {
    final uid = _activeUserId ?? SupabaseService.instance.currentUser?.id ?? '';
    await clearForUser(uid);
  }
}
