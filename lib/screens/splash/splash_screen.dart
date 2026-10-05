import 'package:flutter/material.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/kheyrukum_logo_painter.dart';


/// Animated Splash Screen matching the official Kheyrukum Islamic Center Logo.
///
/// Timeline:
/// - 0.0s - 0.8s: Foundation Crescent arch sweep
/// - 0.8s - 1.6s: Three Golden Pillars / Pedestals rising
/// - 1.6s - 2.3s: Three Teal Lightbulbs of Knowledge & Sacred Open Quran
/// - 2.3s - 2.9s: Royal Golden Crown (Taj Al-Waqar) descending & gentle pulse
/// - 2.9s - 3.4s: Seamless brand reveal with official emblem, Amharic & English title, and Hadith
/// - 3.5s: Automatic transition to Dashboard
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Staggered Animation Intervals
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
      duration: const Duration(milliseconds: 3500),
    );

    // 1. Crescent Foundation (0.0s - 0.8s) -> [0.0 / 3.5 to 0.8 / 3.5 = 0.0 to 0.228]
    _crescentAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.228, curve: Curves.easeInOutCubic),
    );

    // 2. Three Golden Pillars (0.8s - 1.6s) -> [0.228 to 0.457]
    _pillarsAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.228, 0.457, curve: Curves.easeOutBack),
    );

    // 3. Three Lightbulbs & Quran (1.6s - 2.3s) -> [0.457 to 0.657]
    _bulbsAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.457, 0.657, curve: Curves.easeOut),
    );

    // 4. Royal Golden Crown (2.3s - 2.9s) -> [0.657 to 0.828]
    _crownAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.657, 0.828, curve: Curves.bounceOut),
    );

    // Pulse: 2.7s - 3.1s
    _pulseAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.771, 0.885, curve: Curves.linear),
      ),
    );

    // Official Image Crossfade
    _assetFadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.800, 0.942, curve: Curves.easeIn),
    );

    // 5. Typography Reveal (2.8s - 3.3s) -> [0.800 to 0.942]
    _textFadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.800, 0.942, curve: Curves.easeOut),
    );

    _textSlideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.800, 0.942, curve: Curves.easeOutCubic),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToDashboard();
      }
    });

    _controller.forward();
  }

  void _navigateToDashboard() {
    if (!mounted) return;
    final targetRoute = SupabaseService.instance.isAuthenticated
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
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient Radial Glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 0.9,
                  colors: [
                    const Color(0xFF007A78).withOpacity(0.18),
                    AppColors.backgroundDark,
                    AppColors.background,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo Animation Container
                      SizedBox(
                        width: 280,
                        height: 250,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 1. Procedural Custom Painting Animation
                            CustomPaint(
                              size: const Size(280, 250),
                              painter: KheyrukumLogoPainter(
                                crescentProgress: _crescentAnim.value,
                                pillarsProgress: _pillarsAnim.value,
                                bulbsProgress: _bulbsAnim.value,
                                crownProgress: _crownAnim.value,
                                pulseScale: _pulseAnim.value,
                              ),
                            ),

                            // 2. High-Res Logo Overlay Fade-In
                            FadeTransition(
                              opacity: _assetFadeAnim,
                              child: Transform.scale(
                                scale: _pulseAnim.value,
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 240,
                                  height: 240,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Smooth fallback to procedural painter if image is still caching
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Text Reveal: Amharic, English Brand, and Hadith
                      FadeTransition(
                        opacity: _textFadeAnim,
                        child: SlideTransition(
                          position: _textSlideAnim,
                          child: Column(
                            children: [
                              // Amharic Title
                              const Text(
                                'ኸይሩኩም ኢስላማዊ ማዕከል',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00B4B0), // Vivid Teal
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // English Brand Title
                              const Text(
                                'Kheyrukum Islamic Center',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF5A623), // Golden Amber
                                  letterSpacing: 0.2,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Quranic Hadith Tagline
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  'خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ',
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.85),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Subtitle
                              Text(
                                'Parent & Teacher Quranic Collaborative Portal',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textSecondary.withOpacity(0.7),
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

          // Skip Button
          Positioned(
            top: 48,
            right: 20,
            child: TextButton.icon(
              onPressed: _navigateToDashboard,
              icon: const Icon(Icons.arrow_forward, size: 16, color: AppColors.textSecondary),
              label: const Text(
                'Skip',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
