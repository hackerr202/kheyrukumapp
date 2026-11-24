import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'push_notification_service.dart';
import 'storage_service.dart';
import 'supabase_service.dart';

/// Centralized session service managing user identity, role, and assigned class/halaqah.
class AuthSessionService {
  AuthSessionService._();

  static final AuthSessionService instance = AuthSessionService._();

  final ValueNotifier<String> roleNotifier = ValueNotifier<String>('parent');

  String _userId = '';
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';
  String? _avatarUrl;
  String _assignedHalaqahId = '';
  String _assignedHalaqahName = '';

  String get currentRole => roleNotifier.value;
  String get userId => _userId;
  String get userName =>
      _userName.isNotEmpty ? _userName : (_userEmail.isNotEmpty ? _userEmail : 'User');
  String get userEmail => _userEmail;
  String get userPhone => _userPhone;
  String? get avatarUrl => _avatarUrl;
  String get assignedHalaqahId => _assignedHalaqahId;
  String get assignedHalaqahName =>
      _assignedHalaqahName.isNotEmpty ? _assignedHalaqahName : 'Assigned Halaqah';

  bool get isSuperAdmin => currentRole == 'superadmin';
  bool get isAdmin => currentRole == 'admin' || currentRole == 'superadmin';
  bool get isTeacher => currentRole == 'teacher';
  bool get isParent => currentRole == 'parent';
  bool get canAccessPayments => isSuperAdmin || isParent;
  bool get isAuthenticated =>
      _userId.isNotEmpty || SupabaseService.instance.isAuthenticated;

  /// Synchronize identity and role strictly from Supabase `public.profiles`.
  /// Returns `true` when an active (non-suspended) user session is ready, or
  /// `false` if unauthenticated / suspended / profile missing.
  Future<bool> syncFromSupabaseProfile() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) {
      clearSession();
      return false;
    }

    _userId = user.id;
    _userEmail = user.email ?? _userEmail;

    try {
      final profile = await SupabaseService.instance.getUserProfile();
      if (profile == null) {
        debugPrint('[AuthSessionService] No Supabase profile row found for $_userId');
        return false;
      }

      if (profile['is_suspended'] == true) {
        clearSession();
        await SupabaseService.instance.signOut();
        return false;
      }

      _userId = profile['id']?.toString() ?? _userId;
      _userName = profile['full_name']?.toString() ?? _userName;
      _userEmail = profile['email']?.toString() ?? _userEmail;
      _userPhone = profile['phone']?.toString() ?? _userPhone;
      _avatarUrl = profile['avatar_url']?.toString();
      final role = (profile['role'] ?? 'parent').toString().toLowerCase().trim();
      roleNotifier.value =
          ['superadmin', 'admin', 'teacher', 'parent'].contains(role)
              ? role
              : 'parent';

      _assignedHalaqahId = profile['halaqah_id']?.toString() ?? '';
      _assignedHalaqahName = profile['halaqah_name']?.toString() ?? '';

      if (roleNotifier.value == 'teacher' &&
          (_assignedHalaqahId.isEmpty || _assignedHalaqahName.isEmpty)) {
        try {
          final client = SupabaseService.instance.client;
          final halaqah = _assignedHalaqahId.isNotEmpty
              ? await client
                  ?.from('halaqahs')
                  .select('id, name')
                  .eq('id', _assignedHalaqahId)
                  .maybeSingle()
              : await client
                  ?.from('halaqahs')
                  .select('id, name')
                  .eq('teacher_id', _userId)
                  .maybeSingle();
          if (halaqah != null) {
            _assignedHalaqahId = halaqah['id']?.toString() ?? '';
            _assignedHalaqahName = halaqah['name']?.toString() ?? '';
          }
        } catch (e) {
          debugPrint('[AuthSessionService] Error looking up teacher halaqah: $e');
        }
      }
      // Always notify listeners even if the role string remained identical (e.g. account switch).
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      roleNotifier.notifyListeners();

      try {
        await PushNotificationService.instance.registerDeviceToken();
        await PushNotificationService.instance
            .syncRoleSubscription(roleNotifier.value);
      } catch (e) {
        debugPrint('[AuthSessionService] Push registration note: $e');
      }
      return true;
    } catch (e) {
      debugPrint('[AuthSessionService] Error loading profile: $e');
      return false;
    }
  }

  /// Apply authenticated session credentials locally without duplicating cloud pushes.
  void setRole(
    String role, {
    String? userId,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? halaqahId,
    String? halaqahName,
  }) {
    final cleanRole = role.toLowerCase().trim();
    if (!['superadmin', 'admin', 'teacher', 'parent'].contains(cleanRole)) return;

    if (userId != null) _userId = userId;
    if (name != null) _userName = name;
    if (email != null) _userEmail = email;
    if (phone != null) _userPhone = phone;
    if (avatarUrl != null) _avatarUrl = avatarUrl;
    if (halaqahId != null) _assignedHalaqahId = halaqahId;
    if (halaqahName != null) _assignedHalaqahName = halaqahName;

    roleNotifier.value = cleanRole;
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    roleNotifier.notifyListeners();
  }

  /// Clear session completely upon user sign out and always notify UI listeners.
  void clearSession() {
    _userId = '';
    _userName = '';
    _userEmail = '';
    _userPhone = '';
    _avatarUrl = null;
    _assignedHalaqahId = '';
    _assignedHalaqahName = '';
    roleNotifier.value = 'parent';
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    roleNotifier.notifyListeners();
    StorageService.clearSignedUrlCache();
  }

  /// Update user details
  void updateDetails({
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? halaqahId,
    String? halaqahName,
  }) {
    if (name != null) _userName = name;
    if (email != null) _userEmail = email;
    if (phone != null) _userPhone = phone;
    if (avatarUrl != null) _avatarUrl = avatarUrl;
    if (halaqahId != null) _assignedHalaqahId = halaqahId;
    if (halaqahName != null) _assignedHalaqahName = halaqahName;
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    roleNotifier.notifyListeners();
  }

  /// Update the signed-in user's full name and phone number in `public.profiles`
  /// and broadcast immediately to all listeners.
  Future<void> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    final cleanName = fullName.trim();
    final cleanPhone = phone.trim();
    if (cleanName.isEmpty) {
      throw Exception('Full name cannot be empty.');
    }
    final client = SupabaseService.instance.client;
    final uid = SupabaseService.instance.currentUser?.id ?? _userId;
    if (client == null || uid.isEmpty) {
      throw Exception('Please sign in to update your profile.');
    }

    await client.from('profiles').update({
      'full_name': cleanName,
      'phone': cleanPhone,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);

    updateDetails(name: cleanName, phone: cleanPhone);
  }

  /// Update or remove the signed-in user's avatar URL in `public.profiles`
  /// and invalidate the stale signed URL cache entry.
  Future<void> updateAvatarUrl(String? avatarUrl) async {
    final client = SupabaseService.instance.client;
    final uid = SupabaseService.instance.currentUser?.id ?? _userId;
    if (client == null || uid.isEmpty) {
      throw Exception('Please sign in to update your profile photo.');
    }

    final previousUrl = _avatarUrl;
    await client.from('profiles').update({
      'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);

    StorageService.invalidateSignedUrl(previousUrl);
    _avatarUrl = avatarUrl;
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    roleNotifier.notifyListeners();
  }

  /// Update the signed-in user's Supabase Auth password.
  Future<void> changePassword(String newPassword) async {
    if (newPassword.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }
    final client = SupabaseService.instance.client;
    if (client == null || SupabaseService.instance.currentUser == null) {
      throw Exception('Please sign in to change your password.');
    }
    await client.auth.updateUser(UserAttributes(password: newPassword));
  }
}
