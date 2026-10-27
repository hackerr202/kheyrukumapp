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

  /// Admin creates a brand new Halaqah
  Future<Halaqah> createHalaqah({
    required String name,
    String? teacherId,
    String? teacherName,
    String? schedule,
    String? description,
  }) async {
    final newId = 'hal-${DateTime.now().millisecondsSinceEpoch}';
    final halaqah = Halaqah(
      id: newId,
      name: name.trim(),
      teacherId: teacherId,
      teacherName: (teacherName != null && teacherName.isNotEmpty) ? teacherName : 'Unassigned',
      schedule: (schedule != null && schedule.isNotEmpty) ? schedule.trim() : 'Daily Recitation Session',
      description: description?.trim() ?? '',
      studentCount: 0,
      createdAt: DateTime.now(),
    );

    _halaqahs.add(halaqah);
    halaqahsNotifier.value = List.from(_halaqahs);

    // Cloud sync to Supabase
    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        final res = await client.from('halaqahs').insert({
          'name': halaqah.name,
          'teacher_id': halaqah.teacherId,
          'description': halaqah.description,
        }).select().maybeSingle();

        if (res != null && res['id'] != null) {
          final cloudId = res['id'].toString();
          final idx = _halaqahs.indexWhere((h) => h.id == newId);
          if (idx != -1) {
            _halaqahs[idx] = halaqah.copyWith(id: cloudId);
            halaqahsNotifier.value = List.from(_halaqahs);

        // Save to offline cache
        final jsonList = _halaqahs.map((h) => h.toJson()).toList();
        await LocalStorageService.instance.saveJsonList('cached_halaqahs', jsonList);
            return _halaqahs[idx];
          }
        }
      } catch (e) {
        debugPrint('[HalaqahService] Cloud insert halaqah: $e');
      }
    }

    return halaqah;
  }

  /// Admin updates an existing Halaqah
  Future<void> updateHalaqah(Halaqah updated) async {
    final index = _halaqahs.indexWhere((h) => h.id == updated.id);
    if (index != -1) {
      _halaqahs[index] = updated;
      halaqahsNotifier.value = List.from(_halaqahs);
    }

    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        await client.from('halaqahs').update({
          'name': updated.name,
          'teacher_id': updated.teacherId,
          'description': updated.description,
        }).eq('id', updated.id);
      } catch (e) {
        debugPrint('[HalaqahService] Cloud update halaqah: $e');
      }
    }
  }

  /// Admin deletes a Halaqah
  Future<void> deleteHalaqah(String halaqahId) async {
    _halaqahs.removeWhere((h) => h.id == halaqahId);
    halaqahsNotifier.value = List.from(_halaqahs);

    final client = SupabaseService.instance.client;
    if (client != null) {
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
