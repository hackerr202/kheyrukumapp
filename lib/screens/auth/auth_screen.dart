import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/supabase_service.dart';

/// Islamic Emerald/Teal & Gold Luxury Login & Sign-Up Screen
/// Faithfully matching Kheyrukum Islamic Center branding:
/// - Amharic: ኸይሩኩም እስላማዊ ማዕከል
/// - English: Kheyrukum Islamic Center
/// - Arabic Hadith: خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ
/// - Subtitle: Parent & Teacher Quranic Collaborative Portal
/// - Gold framed input fields and glowing Gold "LOGIN" button
/// - Direct Telegram & WhatsApp social contact links from kheyrukum.com (+251 943 42 22 22 / +251 913 49 44 28)
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Toggle between Login and Sign-Up modes
  bool _isSignUpMode = false;

  // Controllers
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  // Sign-up specific controllers
  final _inviteCodeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isInviteVerified = false;
  String? _verifiedRole;

  bool _isLoading = false;
  String? _errorMessage;

  // Website official contact details
  static const String phonePrimary = '+251943422222';
  static const String phoneSecondary = '+251913494428';
  static const String telegramLink = 'https://t.me/+251943422222';
  static const String whatsappLink = 'https://wa.me/251943422222';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _inviteCodeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _showToast('Please enter your username/email and password.');
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

    if (!mounted) return;
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
      final msg = res['message'] ?? 'Sign in failed.';
      _showToast(msg);
    }
  }

  Future<void> _handleVerifyInvite() async {
    final code = _inviteCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showToast('Please enter your school invite code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await SupabaseService.instance.checkInviteCode(code);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['valid'] == true) {
      setState(() {
        _isInviteVerified = true;
        _verifiedRole = res['role'];
        if (res['target_email'] != null && _emailCtrl.text.isEmpty) {
          _emailCtrl.text = res['target_email'];
        }
      });
    } else {
      _showToast(res['message'] ?? 'Invalid invite code.');
    }
  }

  Future<void> _handleCreateAccount() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showToast('Please complete all fields.');
      return;
    }

    if (password.length < 6) {
      _showToast('Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await SupabaseService.instance.registerWithInviteCode(
      code: _inviteCodeCtrl.text.trim(),
      fullName: name,
      email: email,
      password: password,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      AuthSessionService.instance.setRole(
        res['role'] ?? 'parent',
        name: name,
        email: email,
      );
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
      }
    } else {
      _showToast(res['message'] ?? 'Registration failed.');
    }
  }

  void _showToast(String message) {
    setState(() => _errorMessage = message);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _launchExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showContactSheet();
      }
    } catch (_) {
      _showContactSheet();
    }
  }

  void _showContactSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C2431),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.support_agent_rounded, color: Color(0xFFF7B928), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Kheyrukum Islamic Center Contact',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Addis Ababa, Bethel / Near Bethel Hospital\nContact our support team directly via Telegram or WhatsApp:',
                style: TextStyle(color: Color(0xFF88A0B2), fontSize: 12),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF229ED9).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.send_rounded, color: Color(0xFF229ED9), size: 20),
                ),
                title: const Text('Telegram Official', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('+251 943 42 22 22', style: TextStyle(color: Color(0xFF88A0B2), fontSize: 12)),
                trailing: const Icon(Icons.open_in_new_rounded, color: Color(0xFF88A0B2), size: 18),
                onTap: () {
                  Navigator.pop(ctx);
                  _launchExternalUrl(telegramLink);
                },
              ),
              const Divider(color: Color(0xFF1E3A4B), height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 20),
                ),
                title: const Text('WhatsApp Official', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('+251 943 42 22 22', style: TextStyle(color: Color(0xFF88A0B2), fontSize: 12)),
                trailing: const Icon(Icons.open_in_new_rounded, color: Color(0xFF88A0B2), size: 18),
                onTap: () {
                  Navigator.pop(ctx);
                  _launchExternalUrl(whatsappLink);
                },
              ),
              const Divider(color: Color(0xFF1E3A4B), height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7B928).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.phone_rounded, color: Color(0xFFF7B928), size: 20),
                ),
                title: const Text('Direct Phone Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('+251 913 49 44 28', style: TextStyle(color: Color(0xFF88A0B2), fontSize: 12)),
                trailing: const Icon(Icons.call_rounded, color: Color(0xFF88A0B2), size: 18),
                onTap: () {
                  Navigator.pop(ctx);
                  _launchExternalUrl('tel:$phoneSecondary');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF071B26),
      body: Stack(
        children: [
          // 1. Rich Background Gradient (Deep Navy to Dark Teal)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.4),
                radius: 1.25,
                colors: [
                  Color(0xFF0F3B4C), // Radiant center teal
                  Color(0xFF08222F), // Deep emerald-navy
                  Color(0xFF05151E), // Midnight base
                ],
              ),
            ),
          ),

          // 2. Islamic Arabesque Arch & Mandala Corner Ornaments
          Positioned.fill(
            child: CustomPaint(
              painter: _IslamicOrnamentPainter(),
            ),
          ),

          // 3. Foreground Interactive Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),

                      // Circular Centerpiece Logo with Arch Frame
                      _buildCenterpieceLogo(),
                      const SizedBox(height: 14),

                      // Amharic Title: ኸይሩኩም እስላማዊ ማዕከል
                      const Text(
                        'ኸይሩኩም እስላማዊ ማዕከል',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF38B2AC), // Bright Tiffany/Teal
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // English Title: Kheyrukum Islamic Center
                      const Text(
                        'Kheyrukum Islamic Center',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFF3C06B), // Golden Tan
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Arabic Hadith: خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ
                      const Text(
                        'خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Portal Tagline
                      const Text(
                        'Parent & Teacher Quranic Collaborative Portal',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFD4A373),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Form Body (Login or Sign-Up)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isSignUpMode ? _buildSignUpForm() : _buildLoginForm(),
                      ),

                      const SizedBox(height: 24),

                      // Social Connect Options: Telegram & WhatsApp from kheyrukum.com
                      _buildSocialLinksRow(),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterpieceLogo() {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38B2AC).withOpacity(0.35),
            blurRadius: 26,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFFF7B928).withOpacity(0.2),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: const Color(0xFF38B2AC).withOpacity(0.8),
          width: 2.5,
        ),
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.school_rounded, color: Color(0xFF0F3B4C), size: 48),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // LOGIN FORM
  // ===========================================================================
  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login_form'),
      children: [
        // Username / Email Input Box
        _buildInputField(
          controller: _emailCtrl,
          hintText: 'Username / Email',
          prefixIcon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 16),

        // Password Input Box with Visibility Toggle
        _buildInputField(
          controller: _passwordCtrl,
          hintText: 'Password',
          prefixIcon: Icons.lock_outline_rounded,
          isPassword: true,
          obscureText: _obscurePassword,
          onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 10),

        // Forgot Password Link
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              _showToast('Please contact your center administrator or Ustaz to reset your password.');
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(50, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Forgot Password?',
              style: TextStyle(
                color: Color(0xFFD4A373),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),

        // Glowing Golden LOGIN Button
        _buildGoldButton(
          title: 'LOGIN',
          isLoading: _isLoading,
          onTap: _handleSignIn,
        ),
        const SizedBox(height: 20),

        // Don't have an account? Sign Up
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Don't have an account? ",
              style: TextStyle(color: Color(0xFF88A0B2), fontSize: 13),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isSignUpMode = true;
                  _errorMessage = null;
                });
              },
              child: const Text(
                'Sign Up',
                style: TextStyle(
                  color: Color(0xFFF3C06B),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // SIGN UP FORM
  // ===========================================================================
  Widget _buildSignUpForm() {
    return Column(
      key: const ValueKey('signup_form'),
      children: [
        if (!_isInviteVerified) ...[
          // Step 1: Invite Code Verification
          _buildInputField(
            controller: _inviteCodeCtrl,
            hintText: 'School Invite Code (e.g. KHY-TEA-1234)',
            prefixIcon: Icons.card_membership_rounded,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 20),
          _buildGoldButton(
            title: 'VERIFY CODE',
            isLoading: _isLoading,
            onTap: _handleVerifyInvite,
          ),
        ] else ...[
          // Step 2: Account details
          if (_verifiedRole != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF38B2AC).withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF38B2AC)),
              ),
              child: Text(
                'Verified as ${_verifiedRole!.toUpperCase()}',
                style: const TextStyle(
                  color: Color(0xFF38B2AC),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          _buildInputField(
            controller: _nameCtrl,
            hintText: 'Full Name',
            prefixIcon: Icons.badge_outlined,
          ),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _emailCtrl,
            hintText: 'Email Address',
            prefixIcon: Icons.email_outlined,
          ),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _passwordCtrl,
            hintText: 'Create Password (min. 6 characters)',
            prefixIcon: Icons.lock_outline_rounded,
            isPassword: true,
            obscureText: _obscurePassword,
            onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          const SizedBox(height: 20),
          _buildGoldButton(
            title: 'CREATE ACCOUNT',
            isLoading: _isLoading,
            onTap: _handleCreateAccount,
          ),
        ],
        const SizedBox(height: 20),

        // Already have an account? Login
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Already have an account? ',
              style: TextStyle(color: Color(0xFF88A0B2), fontSize: 13),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isSignUpMode = false;
                  _isInviteVerified = false;
                  _errorMessage = null;
                });
              },
              child: const Text(
                'Login',
                style: TextStyle(
                  color: Color(0xFFF3C06B),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Styled Gold-Trimmed Glass Input Box
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B2836).withOpacity(0.72), // Dark Slate Glass
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3A697F).withOpacity(0.85), // Soft Blue-Gold border
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && obscureText,
        textCapitalization: textCapitalization,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: TextStyle(
            color: const Color(0xFF7A97A6).withOpacity(0.8),
            fontSize: 13.5,
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: const Color(0xFF8DB6C7),
            size: 20,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFF7A97A6),
                    size: 19,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
        ),
      ),
    );
  }

  // Golden Amber Gradient Button with Smooth Corners
  Widget _buildGoldButton({
    required String title,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF7BD38), // Golden Yellow
            Color(0xFFE5A118), // Rich Gold
            Color(0xFFCA8200), // Deep Amber Gold
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF7BD38).withOpacity(0.4),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isLoading ? null : onTap,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F3B4C)),
                    ),
                  )
                : Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF162A35), // Dark Midnight Green font for high contrast
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // Telegram and WhatsApp Quick Connect Row from kheyrukum.com
  Widget _buildSocialLinksRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Telegram Button
        _buildSocialIconBox(
          icon: Icons.send_rounded,
          color: const Color(0xFFF3C06B),
          tooltip: 'Telegram: +251 943 42 22 22',
          onTap: () => _launchExternalUrl(telegramLink),
        ),
        const SizedBox(width: 14),
        const Text(
          'or',
          style: TextStyle(
            color: Color(0xFF6A8696),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 14),
        // WhatsApp Button
        _buildSocialIconBox(
          icon: Icons.chat_bubble_outline_rounded,
          color: const Color(0xFF38B2AC),
          tooltip: 'WhatsApp: +251 943 42 22 22',
          onTap: () => _launchExternalUrl(whatsappLink),
        ),
      ],
    );
  }

  Widget _buildSocialIconBox({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF0A222F).withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.55),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 19),
        ),
      ),
    );
  }
}

/// Custom Painter for the top Islamic Mihrab Arch and bottom arabesque flourishes
class _IslamicOrnamentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintStroke = Paint()
      ..color = const Color(0xFF38B2AC).withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Top Mihrab Arch Outline
    final archPath = Path();
    archPath.moveTo(0, size.height * 0.18);
    archPath.quadraticBezierTo(
      size.width * 0.15,
      size.height * 0.16,
      size.width * 0.28,
      size.height * 0.08,
    );
    archPath.quadraticBezierTo(
      size.width * 0.40,
      size.height * 0.02,
      size.width * 0.50,
      size.height * 0.005,
    );
    archPath.quadraticBezierTo(
      size.width * 0.60,
      size.height * 0.02,
      size.width * 0.72,
      size.height * 0.08,
    );
    archPath.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.16,
      size.width,
      size.height * 0.18,
    );
    canvas.drawPath(archPath, paintStroke);

    // Secondary Nested Arch
    final innerArch = Path();
    innerArch.moveTo(size.width * 0.08, size.height * 0.17);
    innerArch.quadraticBezierTo(
      size.width * 0.22,
      size.height * 0.14,
      size.width * 0.32,
      size.height * 0.09,
    );
    innerArch.quadraticBezierTo(
      size.width * 0.42,
      size.height * 0.04,
      size.width * 0.50,
      size.height * 0.025,
    );
    innerArch.quadraticBezierTo(
      size.width * 0.58,
      size.height * 0.04,
      size.width * 0.68,
      size.height * 0.09,
    );
    innerArch.quadraticBezierTo(
      size.width * 0.78,
      size.height * 0.14,
      size.width * 0.92,
      size.height * 0.17,
    );
    canvas.drawPath(
      innerArch,
      paintStroke..color = const Color(0xFFF7BD38).withOpacity(0.08),
    );

    // Bottom Decorative Corner Arabesque Mandalas
    _drawMandalaCorner(canvas, size.width, size.height, isBottomRight: true);
    _drawMandalaCorner(canvas, 0, 0, isBottomRight: false);
  }

  void _drawMandalaCorner(Canvas canvas, double cx, double cy, {required bool isBottomRight}) {
    final mandalaPaint = Paint()
      ..color = const Color(0xFF38B2AC).withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int r = 30; r <= 150; r += 28) {
      canvas.drawCircle(Offset(cx, cy), r.toDouble(), mandalaPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
