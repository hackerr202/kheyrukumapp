import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized local persistent storage for offline caching across Kheyrukum:
/// - Cached messages per conversation
/// - Cached conversations list
/// - Cached students roster & attendance
/// - Cached halaqahs & announcements
/// Ensures the app loads instantaneously without spinner lag, even offline or on poor connections.
class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      debugPrint('[LocalStorageService] Offline cache initialized.');
    } catch (e) {
      debugPrint('[LocalStorageService] Error initializing SharedPreferences: $e');
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs == null) {
      await initialize();
    }
    return _prefs ?? await SharedPreferences.getInstance();
  }

  // --- Generic JSON list caching ---
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
}
