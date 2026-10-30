import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invitation_code.dart';

/// Service class to manage Supabase Cloud initialization, authentication,
/// email verification, and the Admin Invitation Code registration workflow for Kheyrukum.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  // Project credentials: Support --dart-define with safe fallbacks
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://tjhqpzvjzmpyrridtpsj.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_zTV0p7ofXzpZ_sWbUwcCgg_2NpvA_3g',
  );

  static bool _isInitialized = false;
  static String? _initializationError;

  /// Check if Supabase is initialized, and attempt on-demand retry if needed
  static Future<bool> ensureInitialized() async {
    if (_isInitialized && Supabase.instance.client != null) return true;
    await initialize();
    return _isInitialized;
  }

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
      _initializationError = null;
      debugPrint('[SupabaseService] Initialized successfully.');
    } catch (e) {
      _initializationError = e.toString();
      debugPrint('[SupabaseService] Initialization error: $e');
      // If already initialized (e.g. hot reload or re-init), mark as initialized
      try {
        if (Supabase.instance.client != null) {
          _isInitialized = true;
          _initializationError = null;
        }
      } catch (_) {}
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

    if (!await ensureInitialized()) {
      return {'valid': false, 'message': 'Unable to connect to Supabase: ${_initializationError ?? "offline"}'};
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
      return {'valid': false, 'message': 'Invalid code or server error: ${cleanErrorMessage(e)}'};
    }
  }

  /// Converts any raw backend/auth/database exception into a human-friendly message
  static String cleanErrorMessage(dynamic e) {
    if (e == null) return 'An unexpected error occurred. Please try again.';

    // 1. Direct typed inspection if PostgrestException
    if (e is PostgrestException) {
      final code = e.code?.trim().toUpperCase();
      final msg = e.message.trim();
      final lowerMsg = msg.toLowerCase();

      if (code == '42501' ||
          lowerMsg.contains('row-level security') ||
          lowerMsg.contains('violates row-level') ||
          lowerMsg.contains('permission denied')) {
        return 'Access denied: You do not have permission to perform this action.';
      }
      if (code == '23505' || lowerMsg.contains('unique constraint') || lowerMsg.contains('already exists')) {
        return 'A record with this information already exists.';
      }
      if (code == '23503' || lowerMsg.contains('foreign key')) {
        return 'The referenced item (study circle, parent, or teacher) was not found.';
      }
      if (code == '23502' || lowerMsg.contains('not-null constraint') || lowerMsg.contains('null value in column')) {
        return 'Please fill in all required fields.';
      }
      if (code == 'PGRST204' || lowerMsg.contains('schema cache')) {
        return 'Database schema is currently updating. Please try again in a few moments.';
      }
      if (code == 'PGRST116') {
        return 'The requested record could not be found.';
      }
      if (code == '22P02') {
        return 'Invalid format or identifier provided.';
      }
      if (code == '42P01') {
        return 'Service is temporarily unavailable. Please try again later.';
      }

      // Check if message contains Postgres internals
      if (lowerMsg.contains('violates') ||
          lowerMsg.contains('relation ') ||
          lowerMsg.contains('column ') ||
          lowerMsg.contains('syntax error')) {
        return 'Database operation failed. Please check your details and try again.';
      }

      if (msg.isNotEmpty) {
        return msg;
      }
    }

    final str = e.toString();
    final lower = str.toLowerCase();

    // 2. PostgreSQL & PostgREST codes and phrases in String form
    if (lower.contains('42501') ||
        lower.contains('violates row-level security policy') ||
        lower.contains('row-level security') ||
        lower.contains('permission denied')) {
      return 'Access denied: You do not have permission to perform this action.';
    }
    if (lower.contains('23505') || lower.contains('unique constraint') || lower.contains('already exists')) {
      return 'A record with this information already exists.';
    }
    if (lower.contains('23503') || lower.contains('foreign key constraint')) {
      return 'The referenced item (study circle, parent, or teacher) was not found.';
    }
    if (lower.contains('23502') || lower.contains('not-null constraint') || lower.contains('null value in column')) {
      return 'Please fill in all required fields.';
    }
    if (lower.contains('pgrst204') || lower.contains('schema cache')) {
      return 'Database schema is currently updating. Please try again in a few moments.';
    }
    if (lower.contains('pgrst116')) {
      return 'The requested record could not be found.';
    }
    if (lower.contains('22p02')) {
      return 'Invalid format or identifier provided.';
    }
    if (lower.contains('42p01')) {
      return 'Service is temporarily unavailable. Please try again later.';
    }

    // 3. Auth error patterns
    if (lower.contains('invalid login credentials') || lower.contains('invalid credentials')) {
      return 'Incorrect email or password. Please check your details and try again.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Your email is not verified yet. Please check your inbox for the confirmation link.';
    }
    if (lower.contains('user already registered') || lower.contains('already in use')) {
      return 'An account with this email already exists. Please log in instead.';
    }
    if (lower.contains('password should be at least') || lower.contains('password')) {
      if (lower.contains('least 6') || lower.contains('short')) {
        return 'Password must be at least 6 characters long.';
      }
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment before trying again.';
    }
    if (lower.contains('jwt expired') || lower.contains('token expired') || lower.contains('session expired')) {
      return 'Your session has expired. Please sign in again.';
    }

    // 4. Network / Socket errors
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('clientexception') ||
        lower.contains('network') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('timeoutexception') ||
        lower.contains('timed out')) {
      return 'Unable to reach the server. Please verify your internet connection.';
    }

    // 5. Storage errors
    if (lower.contains('bucket not found')) {
      return 'Storage service bucket was not found. Please contact administration.';
    }
    if (lower.contains('payload too large') || lower.contains('entity too large')) {
      return 'The selected file exceeds the maximum allowed upload size.';
    }
    if (lower.contains('storage') && (lower.contains('not found') || lower.contains('404'))) {
      return 'Requested file was not found on cloud storage.';
    }

    // 6. Platform / Permission errors
    if (lower.contains('permission_denied') || lower.contains('permission denied')) {
      return 'Device permission was denied. Please grant permission in settings.';
    }

    // 7. Strip exception type names and PostgrestException wrappers
    final cleaned = str
        .replaceAll(RegExp(r'^(AuthApiException|AuthException|PostgrestException|StorageException|Exception|PlatformException):\s*'), '')
        .replaceAll(RegExp(r'^PostgrestException\s*\(\s*message:\s*([^,]+).*?\)$', dotAll: true), r'$1')
        .trim();

    final lowerCleaned = cleaned.toLowerCase();
    if (lowerCleaned.contains('violates') ||
        lowerCleaned.contains('relation ') ||
        lowerCleaned.contains('syntax error') ||
        lowerCleaned.contains('fkey') ||
        lowerCleaned.contains('pkey')) {
      return 'An unexpected database error occurred. Please try again.';
    }

    return cleaned.isNotEmpty ? cleaned : 'An unexpected error occurred. Please try again.';
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
    if (!await ensureInitialized()) {
      return {'success': false, 'message': 'Unable to connect to Supabase: ${_initializationError ?? "offline"}'};
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
      return {'success': false, 'message': cleanErrorMessage(e)};
    }
  }

  /// 3. Sign In with Email & Password (with Email Verification check)
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    if (!await ensureInitialized()) {
      return {'success': false, 'message': 'Supabase service is offline: ${_initializationError ?? "Please check connection"}'};
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
      return {'success': false, 'message': cleanErrorMessage(e)};
    }
  }

  /// Resend verification email
  Future<Map<String, dynamic>> resendVerificationEmail(String email) async {
    if (!await ensureInitialized()) return {'success': false, 'message': 'Service unavailable.'};
    try {
      await client?.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
      return {'success': true, 'message': 'Verification email sent! Please check your inbox.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to resend email: ${cleanErrorMessage(e)}'};
    }
  }

  /// 4. Sign Out
  Future<void> signOut() async {
    if (_isInitialized) {
      await client?.auth.signOut();
    }
  }

  /// 5. Generate Realtime Invitation Code for Teacher or Parent (Admin)
  Future<Map<String, dynamic>> generateInviteCode({
    required String role,
    String? targetEmail,
    String? linkedStudentId,
    String? targetHalaqahId,
    int daysValid = 30,
  }) async {
    final cleanRole = role.toLowerCase().trim();
    if (cleanRole != 'teacher' && cleanRole != 'parent') {
      return {'success': false, 'message': 'Role must be teacher or parent.'};
    }

    if (!await ensureInitialized() || client == null) {
      return {'success': false, 'message': 'Supabase service is offline. Please check your internet connection.'};
    }

    try {
      // Step A: Call the atomic stored function with security definer
      final rpcRes = await client!.rpc('generate_invitation_code', params: {
        'p_role': cleanRole,
        'p_target_email': targetEmail?.trim(),
        'p_linked_student_id': linkedStudentId,
        'p_target_halaqah_id': targetHalaqahId,
        'p_days_valid': daysValid,
      });

      if (rpcRes != null && rpcRes['success'] == true) {
        return {
          'success': true,
          'code': rpcRes['code'],
          'role': rpcRes['role'],
          'data': rpcRes,
          'message': 'Invitation code created successfully: ${rpcRes['code']}',
        };
      }

      // Step B: Direct table insert fallback
      final prefix = cleanRole == 'teacher' ? 'KHY-TEA' : 'KHY-PAR';
      final randomNum = (1000 + (DateTime.now().microsecondsSinceEpoch % 9000));
      final generatedCode = '$prefix-$randomNum';

      final res = await client!.from('invitation_codes').insert({
        'code': generatedCode,
        'role': cleanRole,
        'target_email': targetEmail?.trim().isEmpty == true ? null : targetEmail?.trim(),
        'linked_student_id': linkedStudentId,
        'target_halaqah_id': targetHalaqahId,
        'expires_at': DateTime.now().toUtc().add(Duration(days: daysValid)).toIso8601String(),
        'is_used': false,
      }).select().single();

      return {
        'success': true,
        'code': res['code'],
        'role': res['role'],
        'data': res,
        'message': 'Invitation code created successfully: ${res['code']}',
      };
    } catch (e) {
      debugPrint('[SupabaseService] generateInviteCode error: $e');
      return {'success': false, 'message': cleanErrorMessage(e)};
    }
  }

  /// 6. Stream Invitation Codes in Real-Time
  Stream<List<InvitationCode>> streamInviteCodes() {
    if (client == null) {
      return Stream.value(<InvitationCode>[]);
    }

    return client!
        .from('invitation_codes')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => InvitationCode.fromJson(json)).toList());
  }

  /// 7. Delete an Invitation Code
  Future<bool> deleteInviteCode(String id) async {
    if (client == null) return true;
    try {
      await client!.from('invitation_codes').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] deleteInviteCode error: $e');
      return false;
    }
  }
}
