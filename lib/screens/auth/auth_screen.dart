import 'package:flutter/material.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';

/// Authentication Screen supporting Admin-Generated Invitation Codes
/// for new Parents and Teachers, plus Email/Password Sign-In.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Invite Registration controllers
  final _inviteCodeController = TextEditingController();
  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();

  // Sign In controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  bool _isCheckingCode = false;
  String? _verifiedRole;
  String? _codeValidationMessage;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inviteCodeController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _inviteCodeController.text.trim();
    if (code.length < 4) return;

    setState(() {
      _isCheckingCode = true;
      _codeValidationMessage = null;
      _errorMessage = null;
    });

    final res = await SupabaseService.instance.checkInviteCode(code);

    setState(() {
      _isCheckingCode = false;
      if (res['valid'] == true) {
        _verifiedRole = res['role'];
        _codeValidationMessage = res['message'] ?? 'Valid Invitation Code';
        if (res['target_email'] != null && _regEmailController.text.isEmpty) {
          _regEmailController.text = res['target_email'];
        }
      } else {
        _verifiedRole = null;
        _codeValidationMessage = res['message'] ?? 'Invalid code';
      }
    });
  }

  Future<void> _handleRegister() async {
    if (_inviteCodeController.text.isEmpty ||
        _regNameController.text.isEmpty ||
        _regEmailController.text.isEmpty ||
        _regPasswordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await SupabaseService.instance.registerWithInviteCode(
      code: _inviteCodeController.text,
      fullName: _regNameController.text,
      email: _regEmailController.text,
      password: _regPasswordController.text,
    );

    setState(() => _isLoading = false);

    if (res['success'] == true) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
      }
    } else {
      setState(() => _errorMessage = res['message'] ?? 'Registration failed.');
    }
  }

  Future<void> _handleSignIn() async {
    if (_loginEmailController.text.isEmpty || _loginPasswordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await SupabaseService.instance.signIn(
      email: _loginEmailController.text,
      password: _loginPasswordController.text,
    );

    setState(() => _isLoading = false);

    if (res['success'] == true) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
      }
    } else {
      setState(() => _errorMessage = res['message'] ?? 'Invalid email or password.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // Official Logo & Emblem
              Image.asset(
                'assets/images/logo.png',
                height: 84,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.menu_book_rounded,
                  size: 64,
                  color: Color(0xFF00BCD4),
                ),
              ),

              const SizedBox(height: 12),
              const Text(
                'ኸይሩኩም ኢስላማዊ ማዕከል',
                style: TextStyle(
                  color: Color(0xFF00BCD4),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Kheyrukum Portal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 24),

              // Tab Selector
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFF00BCD4).withOpacity(0.2),
                    border: Border.all(color: const Color(0xFF00BCD4), width: 1.2),
                  ),
                  labelColor: const Color(0xFF00BCD4),
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Invite Signup'),
                    Tab(text: 'Sign In'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Error Alert
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Tab Content Area
              SizedBox(
                height: 480,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInviteSignupTab(),
                    _buildSignInTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInviteSignupTab() {
    final roleColor = _verifiedRole == 'teacher'
        ? const Color(0xFFFFA000)
        : const Color(0xFF00BCD4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Invitation Code Field with Verify button
        const Text(
          'Admin Invitation Code',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inviteCodeController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: Colors.white, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'e.g. KHY-7842-PAR',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), letterSpacing: 0),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) {
                  if (_verifiedRole != null) {
                    setState(() {
                      _verifiedRole = null;
                      _codeValidationMessage = null;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isCheckingCode ? null : _verifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF334155),
                foregroundColor: const Color(0xFF00BCD4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              child: _isCheckingCode
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Verify'),
            ),
          ],
        ),

        // Verified Status Badge
        if (_codeValidationMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Row(
              children: [
                Icon(
                  _verifiedRole != null ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: _verifiedRole != null ? roleColor : Colors.redAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  _codeValidationMessage!,
                  style: TextStyle(
                    color: _verifiedRole != null ? roleColor : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // 2. Full Name
        _buildTextField('Full Name', _regNameController, Icons.person_outline, 'e.g. Fatima Ahmed'),

        const SizedBox(height: 12),

        // 3. Email
        _buildTextField('Email Address', _regEmailController, Icons.email_outlined, 'parent@example.com',
            keyboardType: TextInputType.emailAddress),

        const SizedBox(height: 12),

        // 4. Password
        _buildTextField('Create Password', _regPasswordController, Icons.lock_outline, '••••••••',
            isPassword: true),

        const SizedBox(height: 20),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BCD4),
              foregroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)))
                : const Text('Register & Activate Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _buildTextField('Email Address', _loginEmailController, Icons.email_outlined, 'yourname@example.com',
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _buildTextField('Password', _loginPasswordController, Icons.lock_outline, '••••••••',
            isPassword: true),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BCD4),
              foregroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)))
                : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
    String hint, {
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
