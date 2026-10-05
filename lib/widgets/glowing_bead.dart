import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// The glowing circular bead that indicates the active tab and rests inside
/// the curved meniscus socket of the navigation bar.
class GlowingBead extends StatelessWidget {
  final double size;
  final IconData icon;
  final bool isDragging;
  final Color primaryColor;
  final Color glowColor;

  const GlowingBead({
    super.key,
    this.size = 50.0,
    required this.icon,
    this.isDragging = false,
    this.primaryColor = AppColors.accentAmber,
    this.glowColor = AppColors.accentAmber,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 150),
      scale: isDragging ? 1.12 : 1.0,
      curve: Curves.easeOutBack,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Diffuse Ambient Glow
            Container(
              width: size * 0.9,
              height: size * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withOpacity(isDragging ? 0.75 : 0.5),
                    blurRadius: isDragging ? 22 : 14,
                    spreadRadius: isDragging ? 4 : 2,
                  ),
                ],
              ),
            ),

            // 2. Bead Spherical Gradient Body
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.4),
                  radius: 0.9,
                  colors: [
                    Colors.white,
                    primaryColor,
                    Color.lerp(primaryColor, Colors.black, 0.35)!,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),

            // 3. Specular Arc Highlight (Glass jewel reflection)
            Positioned(
              top: 5,
              left: 9,
              child: Container(
                width: size * 0.42,
                height: size * 0.22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.85),
                      Colors.white.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // 4. Active Tab Icon inside Bead
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Icon(
                icon,
                key: ValueKey<IconData>(icon),
                size: size * 0.48,
                color: const Color(0xFF0F172A), // Dark slate icon for ultra-high contrast
              ),
            ),
          ],
        ),
      ),
    );
  }
}
