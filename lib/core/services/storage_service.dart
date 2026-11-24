import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class _CachedSignedUrl {
  final String signedUrl;
  final DateTime expiresAt;

  const _CachedSignedUrl({
    required this.signedUrl,
    required this.expiresAt,
  });

  bool get isValid => DateTime.now().isBefore(expiresAt);
}

class _StorageObjectRef {
  final String bucket;
  final String path;

  const _StorageObjectRef(this.bucket, this.path);
}

/// Storage helper service for uploading media, documents, avatars, receipts, and
/// voice recordings to private Supabase Storage buckets and resolving short-lived
/// signed URLs with an in-memory TTL cache.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  // Storage bucket constants matching Supabase schema
  static const String announcementAttachmentsBucket = 'announcement_attachments';
  static const String chatAttachmentsBucket = 'chat_attachments';
  static const String voiceMessagesBucket = 'voice_messages';
  static const String avatarsBucket = 'avatars';
  static const String paymentReceiptsBucket = 'payment_receipts';

  static const Set<String> _allowedImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  static final Map<String, _CachedSignedUrl> _signedUrlCache = {};
  static final Map<String, Future<String?>> _inFlightSignedRequests = {};

  /// Canonical storage ref scheme stored in Postgres rows for private buckets.
  static String buildStorageRef({
    required String bucket,
    required String path,
  }) =>
      'storage://$bucket/$path';

  /// Returns true if [raw] is either an HTTP(S) URL or a `storage://bucket/path` ref.
  static bool isValidMediaRef(String? raw) {
    if (raw == null) return false;
    final trimmed = raw.trim();
    return trimmed.startsWith('http') || trimmed.startsWith('storage://');
  }

  /// Clears cached signed URLs (should be called when signing out).
  static void clearSignedUrlCache() {
    _signedUrlCache.clear();
    _inFlightSignedRequests.clear();
  }

  /// Evicts a single cached signed URL (e.g. when a user replaces or removes their avatar).
  static void invalidateSignedUrl(String? rawUrlOrRef) {
    if (rawUrlOrRef == null) return;
    final parsed = _parseStorageRef(rawUrlOrRef);
    if (parsed == null) return;
    final cacheKey = '${parsed.bucket}/${parsed.path}';
    _signedUrlCache.remove(cacheKey);
    _inFlightSignedRequests.remove(cacheKey);
  }

  /// Parses `storage://<bucket>/<path>` or Supabase Storage URLs
  /// (`/storage/v1/object/(public|sign|authenticated)/<bucket>/<path>`).
  static _StorageObjectRef? _parseStorageRef(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('storage://')) {
      final remainder = trimmed.substring('storage://'.length);
      final slashIdx = remainder.indexOf('/');
      if (slashIdx <= 0 || slashIdx >= remainder.length - 1) return null;
      return _StorageObjectRef(
        remainder.substring(0, slashIdx),
        remainder.substring(slashIdx + 1),
      );
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return null;
    }

    final segs = uri.pathSegments;
    // Expected: storage / v1 / object / (public|sign|authenticated) / <bucket> / <path...>
    final objectIdx = segs.indexOf('object');
    if (objectIdx != -1 && segs.length > objectIdx + 3) {
      final visibility = segs[objectIdx + 1];
      if (visibility == 'public' ||
          visibility == 'sign' ||
          visibility == 'authenticated') {
        final bucket = segs[objectIdx + 2];
        final objectPath = segs.sublist(objectIdx + 3).join('/');
        if (bucket.isNotEmpty && objectPath.isNotEmpty) {
          return _StorageObjectRef(bucket, Uri.decodeComponent(objectPath));
        }
      }
    }

    return null;
  }

  /// Synchronous cache lookup so rebuilds do not flash a loading spinner when
  /// a valid signed URL is already cached.
  static String? getCachedSignedUrl(String? rawUrlOrRef) {
    if (rawUrlOrRef == null) return null;
    final trimmed = rawUrlOrRef.trim();
    if (trimmed.isEmpty) return null;

    final parsed = _parseStorageRef(trimmed);
    if (parsed == null) {
      return trimmed.startsWith('http') ? trimmed : null;
    }

    final cacheKey = '${parsed.bucket}/${parsed.path}';
    final cached = _signedUrlCache[cacheKey];
    if (cached != null && cached.isValid) {
      return cached.signedUrl;
    }
    return null;
  }

  /// Resolves a `storage://bucket/path` reference (or legacy Supabase storage URL)
  /// into a short-lived signed URL using an in-memory TTL cache.
  static Future<String?> resolveSignedUrl(
    String? rawUrlOrRef, {
    int expiresInSeconds = 3600,
  }) async {
    if (rawUrlOrRef == null) return null;
    final trimmed = rawUrlOrRef.trim();
    if (trimmed.isEmpty) return null;

    final parsed = _parseStorageRef(trimmed);
    if (parsed == null) {
      return trimmed.startsWith('http') ? trimmed : null;
    }

    final cacheKey = '${parsed.bucket}/${parsed.path}';
    final cached = _signedUrlCache[cacheKey];
    if (cached != null && cached.isValid) {
      return cached.signedUrl;
    }

    final existingFuture = _inFlightSignedRequests[cacheKey];
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = () async {
      try {
        final client = SupabaseService.instance.client;
        if (client == null) return null;

        final signed = await client.storage
            .from(parsed.bucket)
            .createSignedUrl(parsed.path, expiresInSeconds);

        // Refresh 2 minutes early to avoid race conditions near expiration
        final ttlSeconds =
            expiresInSeconds > 180 ? expiresInSeconds - 120 : expiresInSeconds;
        _signedUrlCache[cacheKey] = _CachedSignedUrl(
          signedUrl: signed,
          expiresAt: DateTime.now().add(Duration(seconds: ttlSeconds)),
        );
        return signed;
      } catch (e) {
        debugPrint(
            '[StorageService] Failed to sign $cacheKey: ${SupabaseService.cleanErrorMessage(e)}');
        return null;
      } finally {
        _inFlightSignedRequests.remove(cacheKey);
      }
    }();

    _inFlightSignedRequests[cacheKey] = future;
    return future;
  }

  /// Upload file bytes to specified private bucket and return its canonical
  /// `storage://<bucket>/<path>` reference.
  static Future<String?> uploadFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    String? mimeType,
    bool upsert = false,
  }) async {
    try {
      final client = SupabaseService.instance.client;
      if (client == null) {
        debugPrint('[StorageService] Supabase client is not initialized.');
        return null;
      }

      final resolvedMime =
          mimeType ?? lookupMimeType(path) ?? 'application/octet-stream';
      final byteData = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

      await client.storage.from(bucket).uploadBinary(
            path,
            byteData,
            fileOptions: FileOptions(
              contentType: resolvedMime,
              upsert: upsert,
            ),
          );

      // Warm the signed URL cache immediately so the uploader sees instant UI preview
      final ref = buildStorageRef(bucket: bucket, path: path);
      await resolveSignedUrl(ref);
      debugPrint('[StorageService] Successfully uploaded to $bucket/$path');
      return ref;
    } catch (e) {
      debugPrint('[StorageService] Upload failed for $bucket/$path: $e');
      return null;
    }
  }

  /// Upload a local file by path to the specified bucket and return its ref.
  static Future<String?> uploadFilePath({
    required String bucket,
    required String path,
    required String filePath,
    String? mimeType,
    bool upsert = false,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[StorageService] Local file does not exist: $filePath');
        return null;
      }
      final bytes = await file.readAsBytes();
      final resolvedMime = mimeType ?? lookupMimeType(filePath);
      return await uploadFile(
        bucket: bucket,
        path: path,
        bytes: bytes,
        mimeType: resolvedMime,
        upsert: upsert,
      );
    } catch (e) {
      debugPrint('[StorageService] uploadFilePath error: $e');
      return null;
    }
  }

  /// Convenience helper: upload avatar / profile picture under `<uid>/...`
  static Future<String?> uploadAvatar({
    required String userIdOrName,
    required List<int> bytes,
    String extension = 'jpg',
  }) async {
    final lowerExt = extension.toLowerCase().trim();
    final safeExt =
        _allowedImageExtensions.contains(lowerExt) ? lowerExt : 'jpg';
    final cleanName = userIdOrName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final ownerFolder =
        SupabaseService.instance.currentUser?.id ?? cleanName;
    final uniquePath =
        '$ownerFolder/avatar_${cleanName}_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    return await uploadFile(
      bucket: avatarsBucket,
      path: uniquePath,
      bytes: bytes,
      mimeType: safeExt == 'jpg' ? 'image/jpeg' : 'image/$safeExt',
    );
  }

  /// Convenience helper: upload circular/announcement attachment
  static Future<String?> uploadAnnouncementAttachment({
    required String fileName,
    required List<int> bytes,
  }) async {
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final uniquePath =
        'announcements/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
    return await uploadFile(
      bucket: announcementAttachmentsBucket,
      path: uniquePath,
      bytes: bytes,
    );
  }

  /// Convenience helper: upload chat attachment under `chat/<conversationId>/...`
  static Future<String?> uploadChatAttachment({
    required String fileName,
    required List<int> bytes,
    String? conversationId,
  }) async {
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final prefix = conversationId != null ? 'chat/$conversationId' : 'chat';
    final uniquePath =
        '$prefix/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
    return await uploadFile(
      bucket: chatAttachmentsBucket,
      path: uniquePath,
      bytes: bytes,
    );
  }

  /// Convenience helper: upload voice recording under `voice/<conversationId>/...`
  static Future<String?> uploadVoiceNote({
    required String fileName,
    required List<int> bytes,
    String? conversationId,
  }) async {
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final prefix = conversationId != null ? 'voice/$conversationId' : 'voice';
    final uniquePath =
        '$prefix/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
    return await uploadFile(
      bucket: voiceMessagesBucket,
      path: uniquePath,
      bytes: bytes,
      mimeType: 'audio/m4a',
    );
  }
}
