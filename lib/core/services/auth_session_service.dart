import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Centralized session service managing user identity, role, and assigned class/halaqah.
/// Supports 3 distinct roles:
/// - 'admin': Center Director with full administrative controls
/// - 'teacher': Assigned to a specific Halaqah/class, responsible for attendance and parent communication
/// - 'parent': Linked to specific enrolled children, views attendance & communicates with Ustaz/Admin
class AuthSessionService {
  AuthSessionService._() {
    _initSession();
  }

  static final AuthSessionService instance = AuthSessionService._();

  final ValueNotifier<String> roleNotifier = ValueNotifier<String>('admin');

  String _userId = 'admin-001';
  String _userName = 'Ustaz Muhammed Yakut';
  String _userEmail = 'admin@kheyrukum.com';
  String _userPhone = '+251 91 000 0001';
  String _assignedHalaqahId = 'halaqah-001';
  String _assignedHalaqahName = 'Halaqah Abu Bakr (حلقة أبي بكر)';

  String get currentRole => roleNotifier.value;
  String get userId => _userId;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get userPhone => _userPhone;
  String get assignedHalaqahId => _assignedHalaqahId;
  String get assignedHalaqahName => _assignedHalaqahName;

  bool get isAdmin => currentRole == 'admin';
  bool get isTeacher => currentRole == 'teacher';
  bool get isParent => currentRole == 'parent';

  void _initSession() {
    final user = SupabaseService.instance.currentUser;
    if (user != null) {
      _userId = user.id;
      _userEmail = user.email ?? _userEmail;
      _syncFromSupabaseProfile();
    }
  }

  Future<void> _syncFromSupabaseProfile() async {
    try {
      final profile = await SupabaseService.instance.getUserProfile();
      if (profile != null) {
        _userId = profile['id'] ?? _userId;
        _userName = profile['full_name'] ?? _userName;
        _userEmail = profile['email'] ?? _userEmail;
        _userPhone = profile['phone'] ?? _userPhone;
        final role = (profile['role'] ?? 'parent').toString().toLowerCase();
        if (['admin', 'teacher', 'parent'].contains(role)) {
          roleNotifier.value = role;
        }
      }
    } catch (e) {
      debugPrint('[AuthSessionService] Error loading profile: $e');
    }
  }

  /// Switch active session role (for testing and demo environments)
  void setRole(
    String role, {
    String? name,
    String? email,
    String? phone,
    String? halaqahId,
    String? halaqahName,
  }) {
    final cleanRole = role.toLowerCase().trim();
    if (!['admin', 'teacher', 'parent'].contains(cleanRole)) return;

    if (cleanRole == 'admin') {
      _userId = 'admin-001';
      _userName = name ?? 'Ustaz Muhammed Yakut';
      _userEmail = email ?? 'admin@kheyrukum.com';
      _userPhone = phone ?? '+251 91 000 0001';
    } else if (cleanRole == 'teacher') {
      _userId = 'teach-001';
      _userName = name ?? 'Ustaz Ibrahim Bilal';
      _userEmail = email ?? 'teacher.ibrahim@kheyrukum.com';
      _userPhone = phone ?? '+251 91 222 3344';
      _assignedHalaqahId = halaqahId ?? 'halaqah-001';
      _assignedHalaqahName = halaqahName ?? 'Halaqah Abu Bakr (حلقة أبي بكر)';
    } else if (cleanRole == 'parent') {
      _userId = 'par-001';
      _userName = name ?? 'Brother Ahmed Muhammed';
      _userEmail = email ?? 'ahmed.parent@gmail.com';
      _userPhone = phone ?? '+251 91 123 4567';
    }

    roleNotifier.value = cleanRole;
  }

  /// Update user details
  void updateDetails({
    String? name,
    String? email,
    String? phone,
    String? halaqahId,
    String? halaqahName,
  }) {
    if (name != null) _userName = name;
    if (email != null) _userEmail = email;
    if (phone != null) _userPhone = phone;
    if (halaqahId != null) _assignedHalaqahId = halaqahId;
    if (halaqahName != null) _assignedHalaqahName = halaqahName;
    roleNotifier.notifyListeners();
  }
}
