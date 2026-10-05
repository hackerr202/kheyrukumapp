import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service class to manage Supabase Cloud initialization, authentication,
/// and the Admin Invitation Code registration workflow for Kheyrukum.
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

  /// 1. Validate Admin-Generated Invitation Code before signup
  Future<Map<String, dynamic>> checkInviteCode(String code) async {
    if (!_isInitialized) {
      // Mock validation for local development/preview testing
      final clean = code.trim().toUpperCase();
      if (clean.startsWith('PAR-') || clean.startsWith('KHY-P')) {
        return {'valid': true, 'role': 'parent', 'message': 'Valid Parent Invitation Code'};
      } else if (clean.startsWith('TEA-') || clean.startsWith('KHY-T')) {
        return {'valid': true, 'role': 'teacher', 'message': 'Valid Teacher Invitation Code'};
      }
      return {'valid': false, 'message': 'Invalid invitation code'};
    }

    try {
      final response = await client!
          .from('invitation_codes')
          .select('id, code, role, is_used, expires_at, target_email')
          .ilike('code', code.trim())
          .eq('is_used', false)
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      if (response == null) {
        return {'valid': false, 'message': 'Code is invalid, expired, or already used.'};
      }

      return {
        'valid': true,
        'role': response['role'],
        'target_email': response['target_email'],
        'message': 'Valid ${response['role']} invitation code.',
      };
    } catch (e) {
      return {'valid': false, 'message': 'Error validating code: $e'};
    }
  }

  /// 2. Register new Parent or Teacher using an Invitation Code + Email + Password
  Future<Map<String, dynamic>> registerWithInviteCode({
    required String code,
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    if (!_isInitialized) {
      // Offline / unconfigured mock response
      return {
        'success': true,
        'message': 'Account registered successfully (Demo Mode)',
      };
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
        'p_code': code.trim(),
        'p_user_id': user.id,
        'p_full_name': fullName.trim(),
        'p_email': email.trim(),
        'p_phone': phone?.trim(),
      });

      return {
        'success': result['success'] ?? true,
        'role': result['role'],
        'message': result['message'] ?? 'Registration complete.',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 3. Sign In with Email & Password
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    if (!_isInitialized) {
      return {'success': true, 'message': 'Logged in (Demo Mode)'};
    }

    try {
      final response = await client!.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user != null) {
        return {'success': true, 'user': response.user};
      }
      return {'success': false, 'message': 'Invalid credentials.'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 4. Sign Out
  Future<void> signOut() async {
    if (_isInitialized) {
      await client?.auth.signOut();
    }
  }
}
