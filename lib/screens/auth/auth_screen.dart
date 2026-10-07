import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/supabase_service.dart';

/// Neumorphic (Soft UI) Login & Sign-Up Screen with a true 3D perspective flip
/// and a two-step school invitation verification workflow.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  // 3D Flip animation controller
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  // Sign-in controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _rememberMe = true;
  bool _isSignInPressed = false;

  // Sign-up controllers
  final _inviteCodeController = TextEditingController();
  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  bool _isVerifyPressed = false;
  bool _isCreatePressed = false;

  // State Management
  bool _isInviteVerified = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _verifiedRole;

  // Neumorphic Soft UI Palette
  static const Color bgColor = Color(0xFFE0E5EC);
  static const Color darkShadow = Color(0xFFA3B1C6);
  static const Color lightShadow = Colors.white;
  static const Color primaryNavy = Color(0xFF1E293B);
  static const Color accentCoral = Color(0xFFFF4B72);
  static const Color subtitleGray = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: math.pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );

    _flipController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        // Automatically reset two-step invite state when card flips back to Login
        setState(() {
          _isInviteVerified = false;
          _errorMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _inviteCodeController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  void _flipToSignUp() {
    setState(() => _errorMessage = null);
    _flipController.forward();
  }

  void _flipToLogin() {
    setState(() => _errorMessage = null);
    _flipController.reverse();
  }

  Future<void> _handleSignIn() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      const msg = 'Please enter your username/email and password.';
      setState(() => _errorMessage = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(msg),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await SupabaseService.instance.signIn(
      email: email,
      password: password,
    );

    setState(() => _isLoading = false);

    if (res['success'] == true) {
      final profile = await SupabaseService.instance.getUserProfile();
      if (profile != null) {
        AuthSessionService.instance.setRole(
          profile['role'] ?? 'parent',
          name: profile['full_name'],
          email: profile['email'],
          phone: profile['phone'],
        );
      } else if (email.trim().toLowerCase() == 'admin@kheyrukum.com') {
        AuthSessionService.instance.setRole('admin');
      }
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
      }
    } else {
      if (res['requiresEmailVerification'] == true) {
        _showEmailVerificationDialog(email);
      } else {
        final msg = res['message'] ?? 'Sign in failed.';
        setState(() => _errorMessage = msg);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleVerifyCode() async {
    final code = _inviteCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      const msg = 'Please enter your school invite code.';
      setState(() => _errorMessage = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(msg),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await SupabaseService.instance.checkInviteCode(code);

    setState(() => _isLoading = false);

    if (res['valid'] == true) {
      setState(() {
        _isInviteVerified = true;
        _verifiedRole = res['role'];
        if (res['target_email'] != null && _regEmailController.text.isEmpty) {
          _regEmailController.text = res['target_email'];
        }
      });
    } else {
      final msg = res['message'] ?? 'Invalid code.';
      setState(() => _errorMessage = msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handleCreateAccount() async {
    final name = _regNameController.text.trim();
    final email = _regEmailController.text.trim();
    final password = _regPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      const msg = 'Please complete all fields.';
      setState(() => _errorMessage = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(msg),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (password.length < 6) {
      const msg = 'Password must be at least 6 characters.';
      setState(() => _errorMessage = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(msg),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await SupabaseService.instance.registerWithInviteCode(
      code: _inviteCodeController.text.trim(),
      fullName: name,
      email: email,
      password: password,
    );

    setState(() => _isLoading = false);

    if (res['success'] == true) {
      if (res['requiresEmailVerification'] == true) {
        _showEmailVerificationDialog(email, onConfirmed: () {
          _flipToLogin();
        });
      } else {
        AuthSessionService.instance.setRole(
          res['role'] ?? 'parent',
          name: name,
          email: email,
        );
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
        }
      }
    } else {
      final msg = res['message'] ?? 'Account creation failed.';
      setState(() => _errorMessage = msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showEmailVerificationDialog(String email, {VoidCallback? onConfirmed}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read_rounded, color: accentCoral),
            SizedBox(width: 8),
            Text(
              'Verify Your Email',
              style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A verification email has been sent to:\n$email',
              style: const TextStyle(color: primaryNavy, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please check your inbox and verify your email before logging in.',
              style: TextStyle(color: subtitleGray, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await SupabaseService.instance.resendVerificationEmail(email);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Verification email resent.')),
                );
              }
            },
            child: const Text('Resend Email', style: TextStyle(color: subtitleGray)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (onConfirmed != null) {
                onConfirmed();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Proceed to Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cardDiameter = (math.min(screenSize.width * 0.94, 430.0)).clamp(340.0, 440.0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Centerpiece Round Logo Placed Just Above Card
                _buildRoundLogo(size: 64),
                const SizedBox(height: 14),

                // 2. 3D Flipping Circular Card
                AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, child) {
                    final angle = _flipAnimation.value;
                    final isFront = angle < (math.pi / 2);

                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // 3D Perspective Depth
                        ..rotateY(angle),
                      child: Container(
                        width: cardDiameter,
                        height: cardDiameter,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: bgColor,
                          boxShadow: [
                            BoxShadow(
                              color: lightShadow,
                              offset: Offset(-9, -9),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: darkShadow,
                              offset: Offset(9, 9),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
                            child: isFront
                                ? _buildFrontLogin()
                                : Transform(
                                    // Mirror back side so text reads correctly
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()..rotateY(math.pi),
                                    child: _buildBackSignUp(),
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoundLogo({double size = 64}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: lightShadow,
            offset: Offset(-5, -5),
            blurRadius: 10,
          ),
          BoxShadow(
            color: darkShadow,
            offset: Offset(5, 5),
            blurRadius: 10,
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFF007A78).withOpacity(0.35),
            width: 1.5,
          ),
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/logo.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(
              Icons.menu_book_rounded,
              color: const Color(0xFF007A78),
              size: size * 0.5,
            ),
          ),
        ),
      ),
    );
  }

  /// Fixed-height error banner: reserves layout space so errors never push the signup link downward
  Widget _buildErrorBanner() {
    return SizedBox(
      height: 22,
      child: _errorMessage != null
          ? AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: 1.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: accentCoral.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentCoral.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 12, color: accentCoral),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: accentCoral,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  // ===========================================================================
  // FRONT SIDE (LOGIN)
  // ===========================================================================
  Widget _buildFrontLogin() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Header
        const Text(
          'Login',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: primaryNavy,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Sign in to your account',
          style: TextStyle(
            fontSize: 12,
            color: subtitleGray,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),

        // Fixed-height Error Banner (does not shift layout)
        _buildErrorBanner(),
        const SizedBox(height: 4),

        // Recessed Field: Username
        _buildRecessedTextField(
          controller: _loginEmailController,
          hintText: 'Username or Email',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 10),

        // Recessed Field: Password
        _buildRecessedTextField(
          controller: _loginPasswordController,
          hintText: 'Password',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
        ),
        const SizedBox(height: 8),

        // Tactile Toggle Switch: Remember Me
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Remember me',
              style: TextStyle(
                fontSize: 11.5,
                color: primaryNavy,
                fontWeight: FontWeight.w600,
              ),
            ),
            _buildTactileSwitch(
              value: _rememberMe,
              onChanged: (val) => setState(() => _rememberMe = val),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Raised Neumorphic Button: SIGN IN
        _buildRaisedButton(
          text: 'SIGN IN',
          isPressed: _isSignInPressed,
          isLoading: _isLoading,
          onTapDown: () => setState(() => _isSignInPressed = true),
          onTapUp: () => setState(() => _isSignInPressed = false),
          onTap: _handleSignIn,
        ),
        const SizedBox(height: 10),

        // Footer Text (positioned comfortably away from circle's bottom edge)
        GestureDetector(
          onTap: _flipToSignUp,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
            child: Text.rich(
              TextSpan(
                text: "Don't have an account? ",
                style: TextStyle(fontSize: 11.5, color: subtitleGray),
                children: [
                  TextSpan(
                    text: 'Sign up',
                    style: TextStyle(
                      color: accentCoral,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // BACK SIDE (SIGN UP - TWO STEP FLOW)
  // ===========================================================================
  Widget _buildBackSignUp() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _isInviteVerified ? _buildSignUpStep2() : _buildSignUpStep1(),
    );
  }

  // Step 1: Invite Code Verification
  Widget _buildSignUpStep1() {
    return Column(
      key: const ValueKey('step1_invite'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Sign Up',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: primaryNavy,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Enter your school invite code',
          style: TextStyle(
            fontSize: 12,
            color: subtitleGray,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        _buildErrorBanner(),
        const SizedBox(height: 6),

        // Recessed Field: Invite Code
        _buildRecessedTextField(
          controller: _inviteCodeController,
          hintText: 'Invite Code (e.g. KHY-TEA-1234)',
          icon: Icons.confirmation_number_outlined,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 16),

        // Raised Neumorphic Button: VERIFY CODE
        _buildRaisedButton(
          text: 'VERIFY CODE',
          isPressed: _isVerifyPressed,
          isLoading: _isLoading,
          onTapDown: () => setState(() => _isVerifyPressed = true),
          onTapUp: () => setState(() => _isVerifyPressed = false),
          onTap: _handleVerifyCode,
        ),
        const SizedBox(height: 14),

        // Footer: Flip back to login
        GestureDetector(
          onTap: _flipToLogin,
          child: const Padding(
            padding: EdgeInsets.all(4.0),
            child: Text.rich(
              TextSpan(
                text: 'Already have an account? ',
                style: TextStyle(fontSize: 11, color: subtitleGray),
                children: [
                  TextSpan(
                    text: 'Login',
                    style: TextStyle(
                      color: accentCoral,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  // Step 2: User Information
  Widget _buildSignUpStep2() {
    return Column(
      key: const ValueKey('step2_profile'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: primaryNavy,
                letterSpacing: -0.5,
              ),
            ),
            if (_verifiedRole != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentCoral.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _verifiedRole!.toUpperCase(),
                  style: const TextStyle(
                    color: accentCoral,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          'Complete your profile',
          style: TextStyle(
            fontSize: 11.5,
            color: subtitleGray,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),

        _buildErrorBanner(),

        // Recessed Field: Full name
        _buildRecessedTextField(
          controller: _regNameController,
          hintText: 'Full name',
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 8),

        // Recessed Field: Email
        _buildRecessedTextField(
          controller: _regEmailController,
          hintText: 'Email',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 8),

        // Recessed Field: Password
        _buildRecessedTextField(
          controller: _regPasswordController,
          hintText: 'Password',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
        ),
        const SizedBox(height: 12),

        // Raised Neumorphic Button: CREATE ACCOUNT
        _buildRaisedButton(
          text: 'CREATE ACCOUNT',
          isPressed: _isCreatePressed,
          isLoading: _isLoading,
          onTapDown: () => setState(() => _isCreatePressed = true),
          onTapUp: () => setState(() => _isCreatePressed = false),
          onTap: _handleCreateAccount,
        ),
        const SizedBox(height: 8),

        // Footer: Cancel Sign Up
        GestureDetector(
          onTap: () {
            setState(() => _isInviteVerified = false);
            _flipToLogin();
          },
          child: const Padding(
            padding: EdgeInsets.all(4.0),
            child: Text(
              'Cancel Sign Up',
              style: TextStyle(
                fontSize: 11,
                color: subtitleGray,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  // ===========================================================================
  // NEUMORPHIC RECESSED TEXT FIELD (INSET SHADOW EFFECT)
  // ===========================================================================
  Widget _buildRecessedTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        // Inset/Recessed shadow simulation
        boxShadow: const [
          BoxShadow(
            color: darkShadow,
            offset: Offset(2, 2),
            blurRadius: 4,
            spreadRadius: 0.5,
          ),
          BoxShadow(
            color: lightShadow,
            offset: Offset(-2, -2),
            blurRadius: 4,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              darkShadow.withOpacity(0.18),
              lightShadow.withOpacity(0.35),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: primaryNavy.withOpacity(0.7)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: isPassword,
                keyboardType: keyboardType,
                textCapitalization: textCapitalization,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: primaryNavy,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: subtitleGray.withOpacity(0.75),
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // RAISED NEUMORPHIC BUTTON
  // ===========================================================================
  Widget _buildRaisedButton({
    required String text,
    required bool isPressed,
    required bool isLoading,
    required VoidCallback onTapDown,
    required VoidCallback onTapUp,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: () => onTapUp(),
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity,
        height: 42,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isPressed
              ? [
                  const BoxShadow(
                    color: darkShadow,
                    offset: Offset(2, 2),
                    blurRadius: 3,
                  ),
                  const BoxShadow(
                    color: lightShadow,
                    offset: Offset(-2, -2),
                    blurRadius: 3,
                  ),
                ]
              : const [
                  BoxShadow(
                    color: darkShadow,
                    offset: Offset(4, 4),
                    blurRadius: 8,
                  ),
                  BoxShadow(
                    color: lightShadow,
                    offset: Offset(-4, -4),
                    blurRadius: 8,
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(accentCoral),
                  ),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: primaryNavy,
                  ),
                ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TACTILE TOGGLE SWITCH
  // ===========================================================================
  Widget _buildTactileSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: bgColor,
          boxShadow: const [
            BoxShadow(
              color: darkShadow,
              offset: Offset(1.5, 1.5),
              blurRadius: 3,
            ),
            BoxShadow(
              color: lightShadow,
              offset: Offset(-1.5, -1.5),
              blurRadius: 3,
            ),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 19,
            height: 19,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? accentCoral : darkShadow,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
