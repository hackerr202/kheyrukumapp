import 'package:flutter/foundation.dart';
import '../models/halaqah.dart';
import 'local_storage_service.dart';
import 'student_service.dart';
import 'supabase_service.dart';

/// Singleton Service managing dynamic Halaqahs (Study Circles).
///
/// Completely replaces hardcoded halaqahs and allows Admin to:
/// - Create new halaqahs with custom names, assigned teachers, and schedules
/// - Assign or reassign teachers
/// - Delete or edit circles
/// - Stream live halaqahs to all dashboard tabs
class HalaqahService {
  HalaqahService._() {
    _loadFromCache();
  }
  static final HalaqahService instance = HalaqahService._();

  final List<Halaqah> _halaqahs = [];
  final ValueNotifier<List<Halaqah>> halaqahsNotifier = ValueNotifier<List<Halaqah>>([]);

  List<Halaqah> get halaqahs => List.unmodifiable(_halaqahs);

  Future<void> _loadFromCache() async {
    try {
      final cached = await LocalStorageService.instance.getJsonList('cached_halaqahs');
      if (cached.isNotEmpty) {
        _halaqahs.clear();
        for (final item in cached) {
          _halaqahs.add(Halaqah.fromJson(item));
        }
        halaqahsNotifier.value = List.from(_halaqahs);

        // Save to offline cache
        final jsonList = _halaqahs.map((h) => h.toJson()).toList();
        await LocalStorageService.instance.saveJsonList('cached_halaqahs', jsonList);
        debugPrint('[HalaqahService] Loaded ${_halaqahs.length} halaqahs from offline cache.');
      }
    } catch (e) {
      debugPrint('[HalaqahService] Cache load error: $e');
    }
  }

  /// Initialize and fetch halaqahs from Supabase
  Future<void> fetchHalaqahs() async {
    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      final res = await client
          .from('halaqahs')
          .select('*, profiles:teacher_id(full_name)')
          .order('name', ascending: true);

      if (res is List) {
        _halaqahs.clear();
        for (final item in res) {
          final teacherName = item['profiles'] != null ? item['profiles']['full_name'] : 'Unassigned';
          final halaqah = Halaqah.fromJson({
            ...item,
            'teacher_name': teacherName,
            'student_count': StudentService.instance.getStudentsForHalaqah(item['name'] ?? '').length,
          });
          _halaqahs.add(halaqah);
        }
        halaqahsNotifier.value = List.from(_halaqahs);

        // Save to offline cache
        final jsonList = _halaqahs.map((h) => h.toJson()).toList();
        await LocalStorageService.instance.saveJsonList('cached_halaqahs', jsonList);
      }
    } catch (e) {
      debugPrint('[HalaqahService] Notice: Supabase fetch halaqahs: $e');
    }
  }

  static bool _isValidUuid(String? str) {
    if (str == null) return false;
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(str.trim());
  }

  /// Admin creates a brand new Halaqah
  Future<Halaqah> createHalaqah({
    required String name,
    String? teacherId,
    String? teacherName,
    String? schedule,
    String? description,
  }) async {
    final cleanSchedule = (schedule != null && schedule.isNotEmpty)
        ? schedule.trim()
        : 'Daily Recitation Session';
    final cleanDescription = description?.trim() ?? '';
    final cleanTeacherName = (teacherName != null && teacherName.isNotEmpty)
        ? teacherName
        : 'Unassigned';

    final client = SupabaseService.instance.client;
    String finalId = 'hal-${DateTime.now().millisecondsSinceEpoch}';

    if (client != null) {
      try {
        final Map<String, dynamic> payload = {
          'name': name.trim(),
          'description': cleanDescription,
          'schedule': cleanSchedule,
        };
        if (teacherId != null && _isValidUuid(teacherId)) {
          payload['teacher_id'] = teacherId;
        }

        final res = await client.from('halaqahs').insert(payload).select().maybeSingle();
        if (res != null && res['id'] != null) {
          finalId = res['id'].toString();
          debugPrint('[HalaqahService] Persisted halaqah to Supabase: $finalId');
        }
      } catch (e) {
        debugPrint('[HalaqahService] Cloud insert halaqah notice: $e');
      }
    }

    final halaqah = Halaqah(
      id: finalId,
      name: name.trim(),
      teacherId: (teacherId != null && _isValidUuid(teacherId)) ? teacherId : null,
      teacherName: cleanTeacherName,
      schedule: cleanSchedule,
      description: cleanDescription,
      studentCount: 0,
      createdAt: DateTime.now(),
    );

    _halaqahs.removeWhere((h) => h.id == halaqah.id);
    _halaqahs.add(halaqah);
    halaqahsNotifier.value = List.from(_halaqahs);

    // Save to offline cache
    final jsonList = _halaqahs.map((h) => h.toJson()).toList();
    await LocalStorageService.instance.saveJsonList('cached_halaqahs', jsonList);

    return halaqah;
  }

  /// Admin updates an existing Halaqah
  Future<void> updateHalaqah(Halaqah updated) async {
    final index = _halaqahs.indexWhere((h) => h.id == updated.id);
    if (index != -1) {
      _halaqahs[index] = updated;
      halaqahsNotifier.value = List.from(_halaqahs);
    }

    final jsonList = _halaqahs.map((h) => h.toJson()).toList();
    await LocalStorageService.instance.saveJsonList('cached_halaqahs', jsonList);

    final client = SupabaseService.instance.client;
    if (client != null && _isValidUuid(updated.id)) {
      try {
        final Map<String, dynamic> updatePayload = {
          'name': updated.name.trim(),
          'description': updated.description.trim(),
          'schedule': updated.schedule.trim(),
        };
        if (updated.teacherId != null && _isValidUuid(updated.teacherId)) {
          updatePayload['teacher_id'] = updated.teacherId;
        } else {
          updatePayload['teacher_id'] = null;
        }
        await client.from('halaqahs').update(updatePayload).eq('id', updated.id);
      } catch (e) {
        debugPrint('[HalaqahService] Cloud update halaqah: $e');
      }
    }
  }

  /// Admin deletes a Halaqah
  Future<void> deleteHalaqah(String halaqahId) async {
    _halaqahs.removeWhere((h) => h.id == halaqahId);
    halaqahsNotifier.value = List.from(_halaqahs);

    final jsonList = _halaqahs.map((h) => h.toJson()).toList();
    await LocalStorageService.instance.saveJsonList('cached_halaqahs', jsonList);

    final client = SupabaseService.instance.client;
    if (client != null && _isValidUuid(halaqahId)) {
      try {
        await client.from('halaqahs').delete().eq('id', halaqahId);
      } catch (e) {
        debugPrint('[HalaqahService] Cloud delete halaqah: $e');
      }
    }
  }

  /// Assign teacher to a halaqah
  Future<void> assignTeacher({
    required String halaqahId,
    required String teacherId,
    required String teacherName,
  }) async {
    final index = _halaqahs.indexWhere((h) => h.id == halaqahId);
    if (index != -1) {
      final existing = _halaqahs[index];
      final updated = existing.copyWith(
        teacherId: teacherId,
        teacherName: teacherName,
      );
      _halaqahs[index] = updated;
      halaqahsNotifier.value = List.from(_halaqahs);

      final client = SupabaseService.instance.client;
      if (client != null) {
        try {
          await client.from('halaqahs').update({
            'teacher_id': teacherId,
          }).eq('id', halaqahId);
        } catch (e) {
          debugPrint('[HalaqahService] Assign teacher error: $e');
        }
      }
    }
  }

  /// Get halaqah name by id
  String getHalaqahName(String? halaqahId) {
    if (halaqahId == null) return 'Unassigned';
    final match = _halaqahs.where((h) => h.id == halaqahId);
    return match.isNotEmpty ? match.first.name : 'Study Circle';
  }
}
