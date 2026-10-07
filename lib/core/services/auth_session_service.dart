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

  final ValueNotifier<String> roleNotifier = ValueNotifier<String>('parent');

  String _userId = '';
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';
  String _assignedHalaqahId = '';
  String _assignedHalaqahName = '';

  String get currentRole => roleNotifier.value;
  String get userId => _userId;
  String get userName => _userName.isNotEmpty ? _userName : (_userEmail.isNotEmpty ? _userEmail : 'User');
  String get userEmail => _userEmail;
  String get userPhone => _userPhone;
  String get assignedHalaqahId => _assignedHalaqahId;
  String get assignedHalaqahName => _assignedHalaqahName.isNotEmpty ? _assignedHalaqahName : 'Assigned Halaqah';

  bool get isAdmin => currentRole == 'admin';
  bool get isTeacher => currentRole == 'teacher';
  bool get isParent => currentRole == 'parent';
  bool get isAuthenticated => _userId.isNotEmpty || SupabaseService.instance.isAuthenticated;

  void _initSession() {
    final user = SupabaseService.instance.currentUser;
    if (user != null) {
      _userId = user.id;
      _userEmail = user.email ?? '';
      if (_userEmail.toLowerCase() == 'admin@kheyrukum.com') {
        roleNotifier.value = 'admin';
        _userName = 'Center Administrator';
      }
      syncFromSupabaseProfile();
    }
  }

  /// Synchronize identity and role strictly from Supabase public.profiles
  Future<void> syncFromSupabaseProfile() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) {
      clearSession();
      return;
    }

    _userId = user.id;
    _userEmail = user.email ?? _userEmail;

    if (_userEmail.toLowerCase() == 'admin@kheyrukum.com') {
      roleNotifier.value = 'admin';
      _userName = 'Center Administrator';
      return;
    }

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
        if (profile['halaqah_id'] != null) {
          _assignedHalaqahId = profile['halaqah_id'] as String;
        }
        if (profile['halaqah_name'] != null) {
          _assignedHalaqahName = profile['halaqah_name'] as String;
        }
      }
    } catch (e) {
      debugPrint('[AuthSessionService] Error loading profile: $e');
    }
  }

  /// Apply authenticated session credentials upon successful login/registration
  void setRole(
    String role, {
    String? userId,
    String? name,
    String? email,
    String? phone,
    String? halaqahId,
    String? halaqahName,
  }) {
    final cleanRole = role.toLowerCase().trim();
    if (!['admin', 'teacher', 'parent'].contains(cleanRole)) return;

    if (userId != null) _userId = userId;
    if (name != null) _userName = name;
    if (email != null) _userEmail = email;
    if (phone != null) _userPhone = phone;
    if (halaqahId != null) _assignedHalaqahId = halaqahId;
    if (halaqahName != null) _assignedHalaqahName = halaqahName;

    roleNotifier.value = cleanRole;
  }

  /// Clear session completely upon user sign out
  void clearSession() {
    _userId = '';
    _userName = '';
    _userEmail = '';
    _userPhone = '';
    _assignedHalaqahId = '';
    _assignedHalaqahName = '';
    roleNotifier.value = 'parent';
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
