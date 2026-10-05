import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// CustomPainter that renders:
/// 1. The Journey (0.0s - 1.5s): Glowing sweeping path with looping trajectory and leading orb.
/// 2. The Connection (1.5s - 2.0s): Two interlocking glowing rings (Parent & Teacher).
/// 3. The Core (2.0s - 2.5s): Smooth morphing into an illuminated Quran / open book with pulse.
class SplashPainter extends CustomPainter {
  final double journeyProgress; // 0.0 -> 1.0 (Phase 1)
  final double connectionProgress; // 0.0 -> 1.0 (Phase 2)
  final double coreProgress; // 0.0 -> 1.0 (Phase 3)
  final double pulseScale; // 1.0 -> 1.12 -> 1.0 (Phase 3 pulse)

  SplashPainter({
    required this.journeyProgress,
    required this.connectionProgress,
    required this.coreProgress,
    required this.pulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Phase 1: Sweeping flight path
    if (journeyProgress > 0.0) {
      _drawJourney(canvas, center, size);
    }

    // Phase 2: Interlocking glowing rings (Parent & Teacher)
    if (connectionProgress > 0.0) {
      _drawConnectionRings(canvas, center);
    }

    // Phase 3: The Core (Illuminated Quran / Open Book)
    if (coreProgress > 0.0) {
      _drawCoreIcon(canvas, center);
    }
  }

  /// Phase 1: The Journey
  void _drawJourney(Canvas canvas, Offset center, Size size) {
    // Fade out slightly when transitioning into Phase 2
    final fadeOut = (1.0 - connectionProgress * 0.7).clamp(0.0, 1.0);
    if (fadeOut <= 0.0) return;

    final path = Path();
    // Sweeping upward looping flight path
    final start = Offset(center.dx - 140, center.dy + 80);
    path.moveTo(start.dx, start.dy);

    // First swoop down & right
    path.cubicTo(
      center.dx - 70, center.dy + 120,
      center.dx - 10, center.dy + 50,
      center.dx + 25, center.dy - 10,
    );
    // Loop upwards like a paper airplane or pen flourish
    path.cubicTo(
      center.dx + 75, center.dy - 95,
      center.dx + 20, center.dy - 130,
      center.dx - 35, center.dy - 75,
    );
    // Loop around and swoop through center
    path.cubicTo(
      center.dx - 65, center.dy - 35,
      center.dx - 20, center.dy + 10,
      center.dx + 60, center.dy - 15,
    );
    // Final convergence to center
    path.cubicTo(
      center.dx + 90, center.dy - 25,
      center.dx + 30, center.dy + 15,
      center.dx, center.dy,
    );

    // Extract animated portion based on journeyProgress
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final currentLength = metric.length * journeyProgress.clamp(0.0, 1.0);
    final animatedPath = metric.extractPath(0.0, currentLength);

    final rect = Rect.fromCenter(center: center, width: 280, height: 260);
    final glowShader = const LinearGradient(
      colors: [AppColors.accentAmber, AppColors.accentTeal],
      stops: [0.1, 0.9],
    ).createShader(rect);

    // 1. Wide outer blur glow
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..shader = glowShader
      ..color = Colors.white.withOpacity(0.6 * fadeOut);

    canvas.drawPath(animatedPath, glowPaint);

    // 2. Medium crisp neon core
    final coreLinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = glowShader;

    canvas.drawPath(animatedPath, coreLinePaint);

    // 3. Leading glowing orb & flight spark at head of path
    if (journeyProgress > 0.02 && journeyProgress < 1.0) {
      final tangent = metric.getTangentForOffset(currentLength);
      if (tangent != null) {
        final headPos = tangent.position;

        // Outer pulse circle
        final orbGlowPaint = Paint()
          ..color = AppColors.accentTeal.withOpacity(0.5 * fadeOut)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(headPos, 9, orbGlowPaint);

        // Solid bright inner core
        final orbPaint = Paint()..color = Colors.white;
        canvas.drawCircle(headPos, 4.0, orbPaint);

        // Leading pointer / spark
        final angle = tangent.angle;
        final sparkPath = Path();
        sparkPath.moveTo(
          headPos.dx + math.cos(angle) * 10,
          headPos.dy + math.sin(angle) * 10,
        );
        sparkPath.lineTo(
          headPos.dx + math.cos(angle + 2.5) * 5,
          headPos.dy + math.sin(angle + 2.5) * 5,
        );
        sparkPath.lineTo(
          headPos.dx + math.cos(angle - 2.5) * 5,
          headPos.dy + math.sin(angle - 2.5) * 5,
        );
        sparkPath.close();

        final sparkPaint = Paint()..color = AppColors.accentAmber;
        canvas.drawPath(sparkPath, sparkPaint);
      }
    }
  }

  /// Phase 2: The Connection (Interlocking rings)
  void _drawConnectionRings(Canvas canvas, Offset center) {
    // Rings fade out as core morphs in
    final ringAlpha = (1.0 - coreProgress * 0.9).clamp(0.0, 1.0);
    if (ringAlpha <= 0.0) return;

    // Rings scale down slightly into center when core appears
    final ringScale = 1.0 - (coreProgress * 0.4);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(ringScale);

    const ringRadius = 38.0;
    const ringOffset = 24.0; // Distance of each ring center from origin
    final sweepAngle = 2 * math.pi * connectionProgress.clamp(0.0, 1.0);

    // Left Ring (Parent - Teal)
    final leftCenter = const Offset(-ringOffset, 0);
    final leftRect = Rect.fromCircle(center: leftCenter, radius: ringRadius);

    final tealGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..color = AppColors.accentTeal.withOpacity(0.55 * ringAlpha);

    final tealPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accentTeal.withOpacity(ringAlpha);

    canvas.drawArc(leftRect, -math.pi / 2, sweepAngle, false, tealGlowPaint);
    canvas.drawArc(leftRect, -math.pi / 2, sweepAngle, false, tealPaint);

    // Right Ring (Teacher - Warm Amber)
    final rightCenter = const Offset(ringOffset, 0);
    final rightRect = Rect.fromCircle(center: rightCenter, radius: ringRadius);

    final amberGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..color = AppColors.accentAmber.withOpacity(0.55 * ringAlpha);

    final amberPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accentAmber.withOpacity(ringAlpha);

    canvas.drawArc(rightRect, math.pi / 2, -sweepAngle, false, amberGlowPaint);
    canvas.drawArc(rightRect, math.pi / 2, -sweepAngle, false, amberPaint);

    // Interlocking intersection highlight spark
    if (connectionProgress > 0.6) {
      final intersectionOpacity = ((connectionProgress - 0.6) / 0.4 * ringAlpha).clamp(0.0, 1.0);
      final sparkPaint = Paint()
        ..color = Colors.white.withOpacity(0.85 * intersectionOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      // Top overlap point
      canvas.drawCircle(Offset(0, -math.sqrt(ringRadius * ringRadius - ringOffset * ringOffset)), 4, sparkPaint);
      // Bottom overlap point
      canvas.drawCircle(Offset(0, math.sqrt(ringRadius * ringRadius - ringOffset * ringOffset)), 4, sparkPaint);
    }

    canvas.restore();
  }

  /// Phase 3: The Core (Solid Glowing Quran / Open Book)
  void _drawCoreIcon(Canvas canvas, Offset center) {
    final opacity = coreProgress.clamp(0.0, 1.0);
    if (opacity <= 0.0) return;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Combine enter scale with 1.1x pulse
    final totalScale = (0.5 + 0.5 * coreProgress) * pulseScale;
    canvas.scale(totalScale);

    // 1. Radial ambient backlight aura
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.accentAmber.withOpacity(0.4 * opacity),
          AppColors.accentTeal.withOpacity(0.2 * opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 80));

    canvas.drawCircle(Offset.zero, 75, auraPaint);

    // 2. Radiating golden subtle rays behind Quran
    final rayPaint = Paint()
      ..color = AppColors.accentAmber.withOpacity(0.25 * opacity)
      ..strokeWidth = 1.5;

    for (int i = 0; i < 8; i++) {
      final rayAngle = (i * math.pi / 4) + (math.pi / 8);
      final p1 = Offset(math.cos(rayAngle) * 38, math.sin(rayAngle) * 38);
      final p2 = Offset(math.cos(rayAngle) * 52, math.sin(rayAngle) * 52);
      canvas.drawLine(p1, p2, rayPaint);
    }

    // 3. Open Book / Quran geometry
    // Left Page
    final leftPage = Path();
    leftPage.moveTo(0, 10);
    leftPage.cubicTo(-10, 12, -26, 16, -34, 10);
    leftPage.lineTo(-34, -20);
    leftPage.cubicTo(-26, -14, -10, -18, 0, -20);
    leftPage.close();

    // Right Page
    final rightPage = Path();
    rightPage.moveTo(0, 10);
    rightPage.cubicTo(10, 12, 26, 16, 34, 10);
    rightPage.lineTo(34, -20);
    rightPage.cubicTo(26, -14, 10, -18, 0, -20);
    rightPage.close();

    // Fill Page - Radiant White / Warm Cream
    final pageFillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.white, Color(0xFFFFF8E1)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(const Rect.fromLTWH(-40, -30, 80, 50))
      ..color = Colors.white.withOpacity(opacity);

    canvas.drawPath(leftPage, pageFillPaint);
    canvas.drawPath(rightPage, pageFillPaint);

    // Page border glowing stroke
    final bookBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = const LinearGradient(
        colors: [AppColors.accentAmber, AppColors.accentTeal],
      ).createShader(const Rect.fromLTWH(-40, -30, 80, 50));

    canvas.drawPath(leftPage, bookBorderPaint);
    canvas.drawPath(rightPage, bookBorderPaint);

    // Book spine / Stand (Rihal base)
    final rihalPath = Path();
    rihalPath.moveTo(-28, 14);
    rihalPath.lineTo(0, 30);
    rihalPath.lineTo(28, 14);
    rihalPath.moveTo(-20, 26);
    rihalPath.lineTo(0, 36);
    rihalPath.lineTo(20, 26);

    final rihalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accentTeal.withOpacity(0.9 * opacity);

    canvas.drawPath(rihalPath, rihalPaint);

    // Golden Bookmark Ribbon dangling down center
    final ribbonPath = Path();
    ribbonPath.moveTo(0, -18);
    ribbonPath.lineTo(0, 18);
    ribbonPath.lineTo(3, 24);
    ribbonPath.lineTo(0, 22);
    ribbonPath.lineTo(-3, 24);
    ribbonPath.lineTo(0, 18);

    final ribbonPaint = Paint()
      ..color = AppColors.accentAmber
      ..style = PaintingStyle.fill;
    canvas.drawPath(ribbonPath, ribbonPaint);

    // Subtle Quranic script line suggestions on pages
    final linePaint = Paint()
      ..color = AppColors.background.withOpacity(0.25 * opacity)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // Left page lines
    canvas.drawLine(const Offset(-28, -10), const Offset(-8, -12), linePaint);
    canvas.drawLine(const Offset(-30, -3), const Offset(-8, -5), linePaint);
    canvas.drawLine(const Offset(-26, 4), const Offset(-8, 2), linePaint);

    // Right page lines
    canvas.drawLine(const Offset(8, -12), const Offset(28, -10), linePaint);
    canvas.drawLine(const Offset(8, -5), const Offset(30, -3), linePaint);
    canvas.drawLine(const Offset(8, 2), const Offset(26, 4), linePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SplashPainter oldDelegate) {
    return oldDelegate.journeyProgress != journeyProgress ||
        oldDelegate.connectionProgress != connectionProgress ||
        oldDelegate.coreProgress != coreProgress ||
        oldDelegate.pulseScale != pulseScale;
  }
}
