import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service class to manage Supabase Cloud initialization, authentication,
/// email verification, and the Admin Invitation Code registration workflow for Kheyrukum.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  // Project credentials: Supabase Cloud
  static const String supabaseUrl = 'https://tjhqpzvjzmpyrridtpsj.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_zTV0p7ofXzpZ_sWbUwcCgg_2NpvA_3g';

  static bool _isInitialized = false;

  /// Initialize Supabase
  static Future<void> initialize() async {
    if (supabaseUrl == 'YOUR_SUPABASE_URL') {
      debugPrint('[SupabaseService] Credentials not yet configured.');
      return;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _isInitialized = true;
      debugPrint('[SupabaseService] Initialized successfully.');
    } catch (e) {
      debugPrint('[SupabaseService] Initialization error: $e');
    }
  }

  SupabaseClient? get client => _isInitialized ? Supabase.instance.client : null;

  User? get currentUser => client?.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  /// Fetch user profile from public.profiles
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (!_isInitialized || currentUser == null) return null;
    try {
      final res = await client!
          .from('profiles')
          .select('id, role, full_name, email, phone, avatar_url')
          .eq('id', currentUser!.id)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('[SupabaseService] Failed to load profile: $e');
      return null;
    }
  }

  /// 1. Validate Admin-Generated Invitation Code before signup
  Future<Map<String, dynamic>> checkInviteCode(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) {
      return {'valid': false, 'message': 'Please enter an invitation code.'};
    }

    if (!_isInitialized) {
      return {'valid': false, 'message': 'Supabase service is not initialized.'};
    }

    try {
      final response = await client!
          .from('invitation_codes')
          .select('id, code, role, is_used, expires_at, target_email')
          .ilike('code', clean)
          .eq('is_used', false)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .maybeSingle();

      if (response == null) {
        return {'valid': false, 'message': 'Invite code is invalid, expired, or already used.'};
      }

      return {
        'valid': true,
        'role': response['role'],
        'target_email': response['target_email'],
        'message': 'Code verified for ${response['role']} role.',
      };
    } catch (e) {
      return {'valid': false, 'message': 'Error validating code: $e'};
    }
  }

  /// 2. Register new Parent or Teacher using an Invitation Code + Email + Password
  /// Enforces Email Verification requirement
  Future<Map<String, dynamic>> registerWithInviteCode({
    required String code,
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    if (!_isInitialized) {
      return {'success': false, 'message': 'Supabase is not initialized.'};
    }

    try {
      // Step A: Create user in Supabase Auth
      final authResponse = await client!.auth.signUp(
        email: email.trim(),
        password: password,
      );

      final user = authResponse.user;
      if (user == null) {
        return {'success': false, 'message': 'Failed to create auth account.'};
      }

      // Step B: Atomically consume invitation code and link profile
      final result = await client!.rpc('consume_invitation_code', params: {
        'p_code': code.trim().toUpperCase(),
        'p_user_id': user.id,
        'p_full_name': fullName.trim(),
        'p_email': email.trim(),
        'p_phone': phone?.trim(),
      });

      final bool isConfirmed = user.emailConfirmedAt != null;

      return {
        'success': result['success'] ?? true,
        'requiresEmailVerification': !isConfirmed,
        'role': result['role'],
        'email': email.trim(),
        'message': !isConfirmed
            ? 'Account created! Please check your email inbox to verify your account before logging in.'
            : 'Registration complete. You can now log in.',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 3. Sign In with Email & Password (with Email Verification check)
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    if (!_isInitialized) {
      return {'success': false, 'message': 'Supabase service is offline.'};
    }

    try {
      final response = await client!.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user != null) {
        // Enforce email verification check for non-admin accounts
        final isConfirmed = user.emailConfirmedAt != null;
        if (!isConfirmed && email.trim().toLowerCase() != 'admin@kheyrukum.com') {
          await client?.auth.signOut();
          return {
            'success': false,
            'requiresEmailVerification': true,
            'email': email.trim(),
            'message': 'Please verify your email before signing in. Check your inbox for the confirmation link.',
          };
        }
        return {'success': true, 'user': user};
      }
      return {'success': false, 'message': 'Invalid email or password.'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Resend verification email
  Future<Map<String, dynamic>> resendVerificationEmail(String email) async {
    if (!_isInitialized) return {'success': false, 'message': 'Service unavailable.'};
    try {
      await client?.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
      return {'success': true, 'message': 'Verification email sent! Please check your inbox.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to resend email: $e'};
    }
  }

  /// 4. Sign Out
  Future<void> signOut() async {
    if (_isInitialized) {
      await client?.auth.signOut();
    }
  }
}
