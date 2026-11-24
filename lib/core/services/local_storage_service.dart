import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingCacheWrite {
  final String userId;
  final String entity;
  final String encodedJson;

  const _PendingCacheWrite(this.userId, this.entity, this.encodedJson);
}

/// Centralized local persistent storage for offline caching across Kheyrukum:
/// - App-wide UI preferences (theme, locale, cached role topic)
/// - Strictly user-scoped offline JSON caches stored atomically in `<appDocs>/offline_cache/`
///   with clean web fallback and full wipe on sign-out.
class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  SharedPreferences? _prefs;
  Directory? _cacheDir;
  final Map<String, _PendingCacheWrite> _pendingWrites = {};
  final Map<String, Timer> _writeTimers = {};

  String _cacheKey(String userId, String entity) =>
      '${_sanitizeSegment(userId)}/${_sanitizeSegment(entity)}';

  Future<void> initialize() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (!kIsWeb) {
        await _ensureCacheDir();
      }
      debugPrint('[LocalStorageService] Offline cache initialized.');
    } catch (e) {
      debugPrint('[LocalStorageService] Error initializing storage: $e');
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<Directory?> _ensureCacheDir() async {
    if (kIsWeb) return null;
    if (_cacheDir != null && await _cacheDir!.exists()) {
      return _cacheDir;
    }
    final appDocs = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDocs.path}/offline_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  static String _sanitizeSegment(String raw) {
    final clean = raw.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return clean.isEmpty ? 'invalid' : clean;
  }

  static String _userFilePrefix(String userId) =>
      'user_${_sanitizeSegment(userId)}_';

  Future<File?> _resolveUserCacheFile(String userId, String entity) async {
    if (kIsWeb || userId.trim().isEmpty) return null;
    final dir = await _ensureCacheDir();
    if (dir == null) return null;
    final cleanEntity = _sanitizeSegment(entity);
    return File('${dir.path}/${_userFilePrefix(userId)}$cleanEntity.json');
  }

  // --- Generic JSON list caching (legacy & global helpers) ---
  Future<void> saveJsonList(String key, List<Map<String, dynamic>> items) async {
    try {
      final prefs = await _getPrefs();
      final str = jsonEncode(items);
      await prefs.setString(key, str);
    } catch (e) {
      debugPrint('[LocalStorageService] Cache save error for $key: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getJsonList(String key) async {
    try {
      final prefs = await _getPrefs();
      final str = prefs.getString(key);
      if (str == null || str.isEmpty) return [];
      final decoded = jsonDecode(str);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[LocalStorageService] Cache read error for $key: $e');
    }
    return [];
  }

  // --- User-scoped atomic JSON cache (debounced per key) ---
  Future<void> _writeEntryNow(_PendingCacheWrite entry) async {
    if (kIsWeb) {
      await saveString(
        'u_${_sanitizeSegment(entry.userId)}_${_sanitizeSegment(entry.entity)}',
        entry.encodedJson,
      );
      return;
    }
    try {
      final file = await _resolveUserCacheFile(entry.userId, entry.entity);
      if (file == null) return;
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(entry.encodedJson, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint(
        '[LocalStorageService] Atomic save error for ${entry.userId}/${entry.entity}: $e',
      );
    }
  }

  Future<void> _scheduleUserJsonSave(
    String userId,
    String entity,
    String encoded,
  ) async {
    if (userId.trim().isEmpty) return;
    final key = _cacheKey(userId, entity);
    _writeTimers.remove(key)?.cancel();
    _pendingWrites[key] = _PendingCacheWrite(userId, entity, encoded);
    _writeTimers[key] = Timer(const Duration(milliseconds: 300), () {
      _writeTimers.remove(key);
      final pending = _pendingWrites.remove(key);
      if (pending != null) {
        unawaited(_writeEntryNow(pending));
      }
    });
  }

  /// Flushes any debounced disk cache writes immediately (e.g. before sign-out wipe).
  Future<void> flushPendingWrites() async {
    for (final timer in _writeTimers.values) {
      timer.cancel();
    }
    _writeTimers.clear();
    if (_pendingWrites.isEmpty) return;
    final entries = _pendingWrites.values.toList();
    _pendingWrites.clear();
    for (final entry in entries) {
      await _writeEntryNow(entry);
    }
  }

  Future<void> saveUserJsonList(
    String userId,
    String entity,
    List<Map<String, dynamic>> items,
  ) async {
    if (userId.trim().isEmpty) return;
    await _scheduleUserJsonSave(userId, entity, jsonEncode(items));
  }

  Future<List<Map<String, dynamic>>> getUserJsonList(
    String userId,
    String entity,
  ) async {
    if (userId.trim().isEmpty) return [];
    try {
      final pending = _pendingWrites[_cacheKey(userId, entity)];
      String? raw = pending?.encodedJson;
      if (raw == null) {
        if (kIsWeb) {
          raw = await getString(
            'u_${_sanitizeSegment(userId)}_${_sanitizeSegment(entity)}',
          );
        } else {
          final file = await _resolveUserCacheFile(userId, entity);
          if (file == null || !await file.exists()) return [];
          raw = await file.readAsString();
        }
      }
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint(
        '[LocalStorageService] Read error for $userId/$entity: $e',
      );
    }
    return [];
  }

  Future<void> saveUserJsonMap(
    String userId,
    String entity,
    Map<String, dynamic> data,
  ) async {
    if (userId.trim().isEmpty) return;
    await _scheduleUserJsonSave(userId, entity, jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getUserJsonMap(
    String userId,
    String entity,
  ) async {
    if (userId.trim().isEmpty) return null;
    try {
      final pending = _pendingWrites[_cacheKey(userId, entity)];
      String? raw = pending?.encodedJson;
      if (raw == null) {
        if (kIsWeb) {
          raw = await getString(
            'u_${_sanitizeSegment(userId)}_${_sanitizeSegment(entity)}',
          );
        } else {
          final file = await _resolveUserCacheFile(userId, entity);
          if (file == null || !await file.exists()) return null;
          raw = await file.readAsString();
        }
      }
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      debugPrint(
        '[LocalStorageService] Map read error for $userId/$entity: $e',
      );
    }
    return null;
  }

  Future<void> removeUserCache(String userId, String entity) async {
    if (userId.trim().isEmpty) return;
    final key = _cacheKey(userId, entity);
    _writeTimers.remove(key)?.cancel();
    _pendingWrites.remove(key);
    if (kIsWeb) {
      await remove(
        'u_${_sanitizeSegment(userId)}_${_sanitizeSegment(entity)}',
      );
      return;
    }
    try {
      final file = await _resolveUserCacheFile(userId, entity);
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint(
        '[LocalStorageService] Remove error for $userId/$entity: $e',
      );
    }
  }

  /// Deletes all user-scoped cache files + web keys for [userId] and cleans
  /// any legacy unscoped keys so signing out leaves zero cross-account residue.
  Future<void> clearUserCaches(String userId) async {
    await flushPendingWrites();
    final cleanUid = userId.trim();
    if (cleanUid.isNotEmpty) {
      if (!kIsWeb) {
        try {
          final dir = await _ensureCacheDir();
          if (dir != null && await dir.exists()) {
            final prefix = _userFilePrefix(cleanUid);
            await for (final entry in dir.list()) {
              if (entry is File) {
                final name = entry.uri.pathSegments.isNotEmpty
                    ? entry.uri.pathSegments.last
                    : '';
                if (name.startsWith(prefix)) {
                  await entry.delete();
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[LocalStorageService] User cache file wipe note: $e');
        }
      }
      await removeByPrefix('u_${_sanitizeSegment(cleanUid)}_');
    }

    // Legacy unscoped keys cleanup
    await remove('cached_students');
    await remove('cached_halaqahs');
    await remove('cached_conversations');
    await remove('cached_payments');
    await remove('read_announcement_ids');
    await removeByPrefix('cache_msgs_');
  }

  // --- Generic String / Map caching ---
  Future<void> saveString(String key, String value) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('[LocalStorageService] Error saving string $key: $e');
    }
  }

  Future<String?> getString(String key) async {
    try {
      final prefs = await _getPrefs();
      return prefs.getString(key);
    } catch (e) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(key);
    } catch (e) {
      debugPrint('[LocalStorageService] Error removing $key: $e');
    }
  }

  Future<void> removeByPrefix(String prefix) async {
    try {
      final prefs = await _getPrefs();
      final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('[LocalStorageService] Error removing prefix $prefix: $e');
    }
  }
}
