import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Storage helper service for uploading media, documents, and voice recordings
/// to Supabase Storage buckets with public URL retrieval.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  // Storage bucket constants matching Supabase schema
  static const String announcementAttachmentsBucket = 'announcement_attachments';
  static const String chatAttachmentsBucket = 'chat_attachments';
  static const String voiceMessagesBucket = 'voice_messages';

  /// Upload file bytes to specified bucket and return its public URL
  static Future<String?> uploadFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    String? mimeType,
  }) async {
    try {
      final client = SupabaseService.instance.client;
      if (client == null) {
        debugPrint('[StorageService] Supabase client is not initialized.');
        return null;
      }

      final resolvedMime = mimeType ?? lookupMimeType(path) ?? 'application/octet-stream';
      final byteData = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

      await client.storage.from(bucket).uploadBinary(
        path,
        byteData,
        fileOptions: FileOptions(
          contentType: resolvedMime,
          upsert: true,
        ),
      );

      final url = getPublicUrl(bucket: bucket, path: path);
      debugPrint('[StorageService] Successfully uploaded to $bucket/$path: $url');
      return url;
    } catch (e) {
      debugPrint('[StorageService] Upload failed for $bucket/$path: $e');
      return null;
    }
  }

  /// Upload a local file by path to the specified bucket and return its public URL
  static Future<String?> uploadFilePath({
    required String bucket,
    required String path,
    required String filePath,
    String? mimeType,
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
      );
    } catch (e) {
      debugPrint('[StorageService] uploadFilePath error: $e');
      return null;
    }
  }

  /// Retrieve the public URL for an asset in a bucket
  static String getPublicUrl({
    required String bucket,
    required String path,
  }) {
    final client = SupabaseService.instance.client;
    if (client == null) return '';
    return client.storage.from(bucket).getPublicUrl(path);
  }

  /// Convenience helper: upload circular/announcement attachment
  static Future<String?> uploadAnnouncementAttachment({
    required String fileName,
    required List<int> bytes,
  }) async {
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final uniquePath = 'announcements/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
    return await uploadFile(
      bucket: announcementAttachmentsBucket,
      path: uniquePath,
      bytes: bytes,
    );
  }

  /// Convenience helper: upload chat attachment
  static Future<String?> uploadChatAttachment({
    required String fileName,
    required List<int> bytes,
    String? conversationId,
  }) async {
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final prefix = conversationId != null ? 'chat/$conversationId' : 'chat';
    final uniquePath = '$prefix/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
    return await uploadFile(
      bucket: chatAttachmentsBucket,
      path: uniquePath,
      bytes: bytes,
    );
  }

  /// Convenience helper: upload voice recording
  static Future<String?> uploadVoiceNote({
    required String fileName,
    required List<int> bytes,
    String? conversationId,
  }) async {
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final prefix = conversationId != null ? 'voice/$conversationId' : 'voice';
    final uniquePath = '$prefix/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
    return await uploadFile(
      bucket: voiceMessagesBucket,
      path: uniquePath,
      bytes: bytes,
      mimeType: 'audio/m4a',
    );
  }
}
