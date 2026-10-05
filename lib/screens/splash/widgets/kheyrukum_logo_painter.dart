import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// CustomPainter that animates the Kheyrukum Islamic Center Logo elements:
/// 1. The Foundation Crescent Arch (Teal)
/// 2. Three Golden Pedestals / Pillars (Staggered growth)
/// 3. Three Lightbulbs of Knowledge (Left, Center with Quran, Right)
/// 4. Golden Royal Crown (Taj Al-Waqar / تاج الوقار) descending onto center
class KheyrukumLogoPainter extends CustomPainter {
  final double crescentProgress; // 0.0 -> 1.0 (Phase 1)
  final double pillarsProgress;  // 0.0 -> 1.0 (Phase 2)
  final double bulbsProgress;    // 0.0 -> 1.0 (Phase 3)
  final double crownProgress;    // 0.0 -> 1.0 (Phase 4)
  final double pulseScale;       // Pulse effect

  static const Color tealPrimary = Color(0xFF007A78);     // Brand Deep Teal
  static const Color tealGlow = Color(0xFF00BCD4);        // Glowing Teal
  static const Color goldPrimary = Color(0xFFF5A623);     // Brand Golden Amber
  static const Color goldLight = Color(0xFFFFD54F);

  KheyrukumLogoPainter({
    required this.crescentProgress,
    required this.pillarsProgress,
    required this.bulbsProgress,
    required this.crownProgress,
    required this.pulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 10;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(pulseScale, pulseScale);

    // 1. Draw Crescent Foundation (Bottom Arch)
    if (crescentProgress > 0) {
      _drawCrescentFoundation(canvas);
    }

    // 2. Draw 3 Golden Pedestals
    if (pillarsProgress > 0) {
      _drawPillars(canvas);
    }

    // 3. Draw 3 Lightbulbs & Open Quran
    if (bulbsProgress > 0) {
      _drawBulbsAndQuran(canvas);
    }

    // 4. Draw Golden Crown (Taj)
    if (crownProgress > 0) {
      _drawCrown(canvas);
    }

    canvas.restore();
  }

  /// Phase 1: Curved Foundation Crescent
  void _drawCrescentFoundation(Canvas canvas) {
    final p = crescentProgress.clamp(0.0, 1.0);
    final crescentPath = Path();

    // The curved boat/crescent shape
    const w = 120.0;
    const h = 24.0;
    const yBase = 46.0;

    crescentPath.moveTo(-w, yBase - 14);
    crescentPath.quadraticBezierTo(0, yBase + h, w, yBase - 14);
    crescentPath.quadraticBezierTo(0, yBase + (h - 10), -w, yBase - 14);
    crescentPath.close();

    // Clip to animated sweep
    canvas.save();
    final clipRect = Rect.fromLTWH(-w - 10, yBase - 20, (2 * w + 20) * p, 60);
    canvas.clipRect(clipRect);

    // Glow under crescent
    final glowPaint = Paint()
      ..color = tealGlow.withOpacity(0.5 * p)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(crescentPath, glowPaint);

    // Fill crescent
    final crescentPaint = Paint()
      ..shader = const LinearGradient(
        colors: [tealPrimary, Color(0xFF009688), tealPrimary],
      ).createShader(Rect.fromLTWH(-w, yBase - 20, 2 * w, 50));
    canvas.drawPath(crescentPath, crescentPaint);

    canvas.restore();
  }

  /// Phase 2: Three Golden Pedestals
  void _drawPillars(Canvas canvas) {
    const yBase = 42.0;

    // Center Pillar (Tallest)
    final pCenter = (pillarsProgress * 1.2).clamp(0.0, 1.0);
    const centerH = 68.0;
    const centerW = 34.0;
    final centerCurH = centerH * pCenter;
    final centerRect = Rect.fromLTWH(-centerW / 2, yBase - centerCurH, centerW, centerCurH);

    // Left Pillar (Medium)
    final pLeft = ((pillarsProgress - 0.15) * 1.3).clamp(0.0, 1.0);
    const leftH = 46.0;
    const leftW = 30.0;
    final leftCurH = leftH * pLeft;
    final leftRect = Rect.fromLTWH(-68, yBase - leftCurH, leftW, leftCurH);

    // Right Pillar (Lower)
    final pRight = ((pillarsProgress - 0.3) * 1.4).clamp(0.0, 1.0);
    const rightH = 34.0;
    const rightW = 30.0;
    final rightCurH = rightH * pRight;
    final rightRect = Rect.fromLTWH(38, yBase - rightCurH, rightW, rightCurH);

    final pillarShader = const LinearGradient(
      colors: [goldLight, goldPrimary, Color(0xFFD97706)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    // Draw Left
    if (pLeft > 0) {
      final paint = Paint()..shader = pillarShader.createShader(leftRect);
      canvas.drawRRect(RRect.fromRectAndRadius(leftRect, const Radius.circular(3)), paint);
    }
    // Draw Center
    if (pCenter > 0) {
      final paint = Paint()..shader = pillarShader.createShader(centerRect);
      canvas.drawRRect(RRect.fromRectAndRadius(centerRect, const Radius.circular(3)), paint);
    }
    // Draw Right
    if (pRight > 0) {
      final paint = Paint()..shader = pillarShader.createShader(rightRect);
      canvas.drawRRect(RRect.fromRectAndRadius(rightRect, const Radius.circular(3)), paint);
    }
  }

  /// Phase 3: Three Teal Lightbulbs & Open Quran
  void _drawBulbsAndQuran(Canvas canvas) {
    final p = bulbsProgress.clamp(0.0, 1.0);

    // 1. Left Lightbulb
    _drawBulb(
      canvas: canvas,
      center: const Offset(-53, -12),
      radius: 14,
      stemH: 7,
      progress: p,
      hasQuran: false,
    );

    // 2. Right Lightbulb
    _drawBulb(
      canvas: canvas,
      center: const Offset(53, 0),
      radius: 14,
      stemH: 7,
      progress: p,
      hasQuran: false,
    );

    // 3. Grand Center Lightbulb
    _drawBulb(
      canvas: canvas,
      center: const Offset(0, -44),
      radius: 24,
      stemH: 10,
      progress: p,
      hasQuran: true,
    );
  }

  void _drawBulb({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double stemH,
    required double progress,
    required bool hasQuran,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(progress, progress);

    // Glow Aura
    final glowPaint = Paint()
      ..color = tealGlow.withOpacity(0.45 * progress)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.7);
    canvas.drawCircle(Offset.zero, radius * 1.1, glowPaint);

    // Bulb Body Path
    final bulbPath = Path();
    bulbPath.addArc(Rect.fromCircle(center: Offset.zero, radius: radius), -math.pi * 0.8, math.pi * 1.6);
    // Neck
    bulbPath.lineTo(radius * 0.5, radius * 0.85);
    bulbPath.lineTo(radius * 0.45, radius + stemH);
    bulbPath.lineTo(-radius * 0.45, radius + stemH);
    bulbPath.lineTo(-radius * 0.5, radius * 0.85);
    bulbPath.close();

    final bulbPaint = Paint()
      ..shader = const LinearGradient(
        colors: [tealGlow, tealPrimary],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius + stemH));

    canvas.drawPath(bulbPath, bulbPaint);

    // Screw Base ridges (white lines on stem)
    final ridgePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final stemTop = radius * 0.85;
    canvas.drawLine(Offset(-radius * 0.35, stemTop + 3), Offset(radius * 0.35, stemTop + 3), ridgePaint);
    canvas.drawLine(Offset(-radius * 0.28, stemTop + 7), Offset(radius * 0.28, stemTop + 7), ridgePaint);

    // Inside Center Bulb: Sacred Open Quran
    if (hasQuran && progress > 0.4) {
      final quranP = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
      canvas.save();
      canvas.scale(quranP, quranP);

      // Open Book Path
      final bookPath = Path();
      // Left Page
      bookPath.moveTo(0, 3);
      bookPath.cubicTo(-4, 4, -10, 6, -13, 3);
      bookPath.lineTo(-13, -7);
      bookPath.cubicTo(-10, -5, -4, -6, 0, -8);
      // Right Page
      bookPath.cubicTo(4, -6, 10, -5, 13, -7);
      bookPath.lineTo(13, 3);
      bookPath.cubicTo(10, 6, 4, 4, 0, 3);
      bookPath.close();

      final bookPaint = Paint()..color = Colors.white;
      canvas.drawPath(bookPath, bookPaint);

      // Wooden Rihal Base
      final rihalPath = Path();
      rihalPath.moveTo(-10, 5);
      rihalPath.lineTo(0, 11);
      rihalPath.lineTo(10, 5);
      rihalPath.moveTo(-7, 9);
      rihalPath.lineTo(0, 14);
      rihalPath.lineTo(7, 9);

      final rihalPaint = Paint()
        ..color = goldPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(rihalPath, rihalPaint);
      canvas.restore();
    }

    canvas.restore();
  }

  /// Phase 4: Golden Crown (Taj Al-Waqar / تاج الوقار)
  void _drawCrown(Canvas canvas) {
    final p = crownProgress.clamp(0.0, 1.0);

    canvas.save();
    // Drop down from top
    final dropY = -92.0 + (1.0 - p) * -30.0;
    canvas.translate(0, dropY);
    canvas.scale(p, p);

    // Ambient gold glow
    final glowPaint = Paint()
      ..color = goldPrimary.withOpacity(0.6 * p)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    // Crown Path (5-point royal crown)
    final crownPath = Path();
    crownPath.moveTo(-22, 10);
    crownPath.lineTo(-24, -12);
    crownPath.lineTo(-12, -2);
    crownPath.lineTo(0, -18);
    crownPath.lineTo(12, -2);
    crownPath.lineTo(24, -12);
    crownPath.lineTo(22, 10);
    crownPath.close();

    canvas.drawPath(crownPath, glowPaint);

    final crownPaint = Paint()
      ..shader = const LinearGradient(
        colors: [goldLight, goldPrimary, Color(0xFFD97706)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(const Rect.fromLTWH(-25, -20, 50, 32));

    canvas.drawPath(crownPath, crownPaint);

    // 5 Jewels on top of crown peaks
    final jewelPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(-24, -12), 2.2, jewelPaint);
    canvas.drawCircle(const Offset(-12, -2), 2.0, jewelPaint);
    canvas.drawCircle(const Offset(0, -18), 3.0, jewelPaint); // Center main jewel
    canvas.drawCircle(const Offset(12, -2), 2.0, jewelPaint);
    canvas.drawCircle(const Offset(24, -12), 2.2, jewelPaint);

    // Crown base band
    final bandPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(-20, 8), const Offset(20, 8), bandPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant KheyrukumLogoPainter oldDelegate) {
    return oldDelegate.crescentProgress != crescentProgress ||
        oldDelegate.pillarsProgress != pillarsProgress ||
        oldDelegate.bulbsProgress != bulbsProgress ||
        oldDelegate.crownProgress != crownProgress ||
        oldDelegate.pulseScale != pulseScale;
  }
}
