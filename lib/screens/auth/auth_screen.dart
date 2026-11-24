import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/islamic_pattern_painter.dart';
import '../../widgets/pro_ui_kit.dart';

/// Flagship Login & Invite-Code Sign-Up Screen for Kheyrukum Islamic Center.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUpMode = false;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  final _inviteCodeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isInviteVerified = false;
  String? _verifiedRole;

  bool _isLoading = false;
  String? _errorMessage;

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
      final active = await AuthSessionService.instance.syncFromSupabaseProfile();
      if (!mounted) return;
      if (!active || !SupabaseService.instance.isAuthenticated) {
        _showToast(
          'Your account is suspended or inactive. Please contact center administration.',
        );
        return;
      }
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
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
      if (res['requiresEmailVerification'] == true) {
        if (mounted) {
          setState(() {
            _isSignUpMode = false;
            _isInviteVerified = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res['message'] ??
                    'Account created! Please verify your email before logging in.',
              ),
              backgroundColor: AppColors.pinePrimary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
            ),
          );
        }
        return;
      }

      await AuthSessionService.instance.syncFromSupabaseProfile();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
      }
    } else {
      _showToast(res['message'] ?? 'Registration failed.');
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.of(context).danger,
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
      } else if (mounted) {
        _showContactSheet();
      }
    } catch (_) {
      if (mounted) {
        _showContactSheet();
      }
    }
  }

  void _showContactSheet() {
    final p = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ProBottomSheetShell(
        title: 'Kheyrukum Support',
        subtitle: 'Addis Ababa, Bethel / Near Bethel Hospital',
        icon: Icons.support_agent_rounded,
        iconColor: p.gold,
        heightFactor: 0.48,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildContactTile(
              icon: Icons.send_rounded,
              color: const Color(0xFF0EA5E9),
              title: 'Telegram Official',
              subtitle: '+251 943 42 22 22',
              trailingIcon: Icons.open_in_new_rounded,
              onTap: () {
                Navigator.pop(ctx);
                _launchExternalUrl(telegramLink);
              },
            ),
            const SizedBox(height: 10),
            _buildContactTile(
              icon: Icons.chat_rounded,
              color: p.success,
              title: 'WhatsApp Official',
              subtitle: '+251 943 42 22 22',
              trailingIcon: Icons.open_in_new_rounded,
              onTap: () {
                Navigator.pop(ctx);
                _launchExternalUrl(whatsappLink);
              },
            ),
            const SizedBox(height: 10),
            _buildContactTile(
              icon: Icons.phone_rounded,
              color: p.gold,
              title: 'Direct Phone Support',
              subtitle: '+251 913 49 44 28',
              trailingIcon: Icons.call_rounded,
              onTap: () {
                Navigator.pop(ctx);
                _launchExternalUrl('tel:$phoneSecondary');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required IconData trailingIcon,
    required VoidCallback onTap,
  }) {
    final p = AppColors.of(context);
    return ProCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: p.inkSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(trailingIcon, color: p.inkMuted, size: 18),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);

    return Scaffold(
      backgroundColor: p.canvas,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Full-bleed curved Deep Pine Sanctuary Header
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    MediaQuery.of(context).padding.top + 22,
                    24,
                    58,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.pineRich, AppColors.pinePrimary, AppColors.pineDeep],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(36),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Circular Logo Seal
                      Container(
                        width: 96,
                        height: 96,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: AppColors.goldWarm,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.24),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.school_rounded,
                                color: AppColors.pinePrimary,
                                size: 42,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'ኸይሩኩም እስላማዊ ማዕከል',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Kheyrukum Islamic Center',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.goldWarm,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: GoogleFonts.amiri(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Parent & Teacher Quranic Collaborative Portal',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.78),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(36),
                      ),
                      child: IslamicGeometricPattern(
                        color: Colors.white,
                        opacity: 0.055,
                        cellSize: 52,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Elevated Overlapping Form Card
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ProCard(
                    borderRadius: 28,
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ProSegmentedControl(
                          labels: const ['Sign In', 'Join with Code'],
                          selectedIndex: _isSignUpMode ? 1 : 0,
                          onChanged: (idx) {
                            setState(() {
                              _isSignUpMode = idx == 1;
                              _errorMessage = null;
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: p.danger.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: p.danger.withOpacity(0.35),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 18,
                                  color: p.danger,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: p.danger,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          child: _isSignUpMode
                              ? _buildSignUpForm(p)
                              : _buildLoginForm(p),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Sleek Support Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    Text(
                      'Need assistance from center administration?',
                      style: TextStyle(
                        color: p.inkSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSocialLinksRow(p),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(AppPalette p) {
    return Column(
      key: const ValueKey('login_form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: p.ink,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Sign in to continue to your school portal.',
          style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
        ),
        const SizedBox(height: 18),
        _buildInputField(
          p: p,
          controller: _emailCtrl,
          label: 'Email or Username',
          hintText: 'parent@kheyrukum.com',
          prefixIcon: Icons.person_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _buildInputField(
          p: p,
          controller: _passwordCtrl,
          label: 'Password',
          hintText: 'Enter your password',
          prefixIcon: Icons.lock_outline_rounded,
          isPassword: true,
          obscureText: _obscurePassword,
          onToggleVisibility: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              _showToast(
                'Please contact your center administrator or Ustaz to reset your password.',
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: const Size(40, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                color: p.primary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildPrimaryCta(
          p: p,
          title: 'Sign In',
          isLoading: _isLoading,
          onTap: _handleSignIn,
        ),
      ],
    );
  }

  Widget _buildSignUpForm(AppPalette p) {
    return Column(
      key: const ValueKey('signup_form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isInviteVerified) ...[
          Text(
            'Activate your invitation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: p.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Enter the registration code provided by center administration.',
            style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
          ),
          const SizedBox(height: 18),
          _buildInputField(
            p: p,
            controller: _inviteCodeCtrl,
            label: 'School Invite Code',
            hintText: 'e.g. KHY-TEA-1234',
            prefixIcon: Icons.vpn_key_outlined,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 18),
          _buildPrimaryCta(
            p: p,
            title: 'Verify Invite Code',
            isLoading: _isLoading,
            onTap: _handleVerifyInvite,
          ),
        ] else ...[
          if (_verifiedRole != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: p.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.primary.withOpacity(0.32)),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded, color: p.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Verified as ${_verifiedRole!.toUpperCase()}',
                      style: TextStyle(
                        color: p.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isInviteVerified = false;
                        _verifiedRole = null;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Change Code',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildInputField(
            p: p,
            controller: _nameCtrl,
            label: 'Full Name',
            hintText: 'Enter your full name',
            prefixIcon: Icons.badge_outlined,
          ),
          const SizedBox(height: 12),
          _buildInputField(
            p: p,
            controller: _emailCtrl,
            label: 'Email Address',
            hintText: 'name@example.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _buildInputField(
            p: p,
            controller: _passwordCtrl,
            label: 'Create Password',
            hintText: 'Minimum 6 characters',
            prefixIcon: Icons.lock_outline_rounded,
            isPassword: true,
            obscureText: _obscurePassword,
            onToggleVisibility: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          const SizedBox(height: 18),
          _buildPrimaryCta(
            p: p,
            title: 'Create Account',
            isLoading: _isLoading,
            onTap: _handleCreateAccount,
          ),
        ],
      ],
    );
  }

  Widget _buildInputField({
    required AppPalette p,
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData prefixIcon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: p.inkSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword && obscureText,
          textCapitalization: textCapitalization,
          keyboardType: keyboardType,
          style: TextStyle(
            color: p.ink,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(prefixIcon, color: p.inkSecondary, size: 19),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: p.inkMuted,
                      size: 19,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryCta({
    required AppPalette p,
    required String title,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppColors.pineRich, AppColors.pinePrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.pinePrimary.withOpacity(0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
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
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.goldWarm),
                    ),
                  )
                : Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLinksRow(AppPalette p) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSocialChip(
          p: p,
          icon: Icons.send_rounded,
          label: 'Telegram',
          color: const Color(0xFF0EA5E9),
          onTap: () => _launchExternalUrl(telegramLink),
        ),
        const SizedBox(width: 10),
        _buildSocialChip(
          p: p,
          icon: Icons.chat_rounded,
          label: 'WhatsApp',
          color: p.success,
          onTap: () => _launchExternalUrl(whatsappLink),
        ),
        const SizedBox(width: 10),
        _buildSocialChip(
          p: p,
          icon: Icons.support_agent_rounded,
          label: 'Contact',
          color: p.gold,
          onTap: _showContactSheet,
        ),
      ],
    );
  }

  Widget _buildSocialChip({
    required AppPalette p,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: p.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
