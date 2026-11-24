import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/islamic_pattern_painter.dart';
import 'widgets/kheyrukum_logo_painter.dart';

/// Animated Flagship Splash Screen for Kheyrukum Islamic Center.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _crescentAnim;
  late final Animation<double> _pillarsAnim;
  late final Animation<double> _bulbsAnim;
  late final Animation<double> _crownAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _assetFadeAnim;
  late final Animation<double> _textFadeAnim;
  late final Animation<Offset> _textSlideAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _crescentAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.22, curve: Curves.easeInOutCubic),
    );

    _pillarsAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.20, 0.44, curve: Curves.easeOutBack),
    );

    _bulbsAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.64, curve: Curves.easeOut),
    );

    _crownAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.62, 0.80, curve: Curves.bounceOut),
    );

    _pulseAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.74, 0.88, curve: Curves.linear),
      ),
    );

    _assetFadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.76, 0.92, curve: Curves.easeIn),
    );

    _textFadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.74, 0.92, curve: Curves.easeOut),
    );

    _textSlideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.28),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.74, 0.92, curve: Curves.easeOutCubic),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateNext();
      }
    });

    _controller.forward();
  }

  Future<void> _navigateNext() async {
    if (!mounted) return;
    if (!SupabaseService.instance.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.auth);
      return;
    }

    final activeSession = await AuthSessionService.instance
        .syncFromSupabaseProfile()
        .timeout(const Duration(seconds: 6), onTimeout: () => false);

    if (!mounted) return;
    final targetRoute = (activeSession && SupabaseService.instance.isAuthenticated)
        ? AppRoutes.dashboard
        : AppRoutes.auth;
    Navigator.of(context).pushReplacementNamed(targetRoute);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pineDeep,
      body: Stack(
        children: [
          // Deep Pine Sanctuary radial gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.22),
                  radius: 1.05,
                  colors: [
                    AppColors.pineRich,
                    AppColors.pinePrimary,
                    AppColors.pineDeep,
                    const Color(0xFF032D2A),
                  ],
                  stops: const [0.0, 0.35, 0.72, 1.0],
                ),
              ),
            ),
          ),

          // Subtle geometric Khatam lattice
          const Positioned.fill(
            child: IslamicGeometricPattern(
              color: Colors.white,
              opacity: 0.055,
              cellSize: 58,
              showCornerArcs: true,
            ),
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Embossed Double-Ring Gold Halo + Circular Emblem Seal
                        Container(
                          width: 222,
                          height: 222,
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.goldWarm.withOpacity(0.45),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.goldWarm.withOpacity(0.22),
                                blurRadius: 36,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: AppColors.goldWarm,
                                width: 2.5,
                              ),
                            ),
                            child: ClipOval(
                              child: Stack(
                                fit: StackFit.expand,
                                alignment: Alignment.center,
                                children: [
                                  RepaintBoundary(
                                    child: CustomPaint(
                                      size: const Size(200, 200),
                                      painter: KheyrukumLogoPainter(
                                        crescentProgress: _crescentAnim.value,
                                        pillarsProgress: _pillarsAnim.value,
                                        bulbsProgress: _bulbsAnim.value,
                                        crownProgress: _crownAnim.value,
                                        pulseScale: _pulseAnim.value,
                                      ),
                                    ),
                                  ),
                                  FadeTransition(
                                    opacity: _assetFadeAnim,
                                    child: Transform.scale(
                                      scale: _pulseAnim.value,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Image.asset(
                                          'assets/images/logo.png',
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const SizedBox.shrink(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        FadeTransition(
                          opacity: _textFadeAnim,
                          child: SlideTransition(
                            position: _textSlideAnim,
                            child: Column(
                              children: [
                                const Text(
                                  'ኸይሩኩም ኢስላማዊ ማዕከል',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Kheyrukum Islamic Center',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.goldWarm,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.14),
                                    ),
                                  ),
                                  child: Text(
                                    'خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ',
                                    textAlign: TextAlign.center,
                                    textDirection: TextDirection.rtl,
                                    style: GoogleFonts.amiri(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withOpacity(0.95),
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Parent & Teacher Quranic Collaborative Portal',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.75),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
