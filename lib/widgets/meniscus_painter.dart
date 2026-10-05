import 'dart:math' as math;
import 'package:flutter/material.dart';

/// CustomPainter that renders the floating dock with a parametric Meniscus socket
/// matching the exact reference visual geometry:
///
/// - Flat horizontal dock top edge
/// - Smooth convex shoulders transitioning into a concave circular cradle/bowl
/// - Luminous rim highlight contouring ONLY the socket bowl directly under the bead
/// - Subtle dark plate gradient with clean border
class MeniscusPainter extends CustomPainter {
  final double beadX;
  final double beadY;          // Vertical center offset of bead relative to dock top edge
  final double bowlRadius;     // Radius of the concave socket bowl
  final double shoulderRadius; // Radius of the convex shoulders
  final double velocityX;      // Velocity for dynamic surface leaning
  final Color dockFillColor;
  final Color accentColor;
  final double cornerRadius;

  MeniscusPainter({
    required this.beadX,
    this.beadY = 2.0,
    this.bowlRadius = 23.0,
    this.shoulderRadius = 11.0,
    this.velocityX = 0.0,
    this.dockFillColor = const Color(0xFF161927),
    required this.accentColor,
    this.cornerRadius = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = cornerRadius;

    // Velocity lean factors
    const maxV = 500.0;
    final q = (velocityX / maxV).clamp(-1.0, 1.0);
    final mag = (velocityX.abs() / maxV).clamp(0.0, 1.0);

    final sL = (shoulderRadius * (1.0 + 0.06 * mag + 0.35 * q)).clamp(7.0, 24.0);
    final sR = (shoulderRadius * (1.0 + 0.06 * mag - 0.35 * q)).clamp(7.0, 24.0);
    final rb = bowlRadius;
    final by = beadY;

    // Exact geometric reach: distance from beadX to where shoulder meets top edge y=0
    final reachL = math.sqrt(math.max(1.0, math.pow(sL + rb, 2) - math.pow(sL - by, 2)));
    final reachR = math.sqrt(math.max(1.0, math.pow(sR + rb, 2) - math.pow(sR - by, 2)));

    // Clamp beadX strictly within valid track so socket never penetrates rounded corners
    final minX = r + reachL;
    final maxX = w - r - reachR;
    final clampedX = beadX.clamp(minX, maxX);

    // Tangency calculations

    final alphaL = math.atan2(sL - by, reachL);
    final alphaR = math.atan2(sR - by, reachR);

    // Shoulder 1 center: (clampedX - reachL, sL)
    final c1x = clampedX - reachL;
    final c1y = sL;

    // Bowl center: (clampedX, by)
    final c2x = clampedX;
    final c2y = by;

    // Shoulder 2 center: (clampedX + reachR, sR)
    final c3x = clampedX + reachR;
    final c3y = sR;

    // 1. Build the continuous Dock Path
    final dockPath = Path();
    dockPath.moveTo(r, 0);
    dockPath.lineTo(c1x, 0);

    // Left shoulder arc: from -pi/2 clockwise to -alphaL (in screen coords where y is down)
    const int shoulderSteps = 14;
    for (int i = 1; i <= shoulderSteps; i++) {
      final a = -math.pi / 2 + alphaL * (i / shoulderSteps);
      dockPath.lineTo(c1x + sL * math.cos(a), c1y + sL * math.sin(a));
    }

    // Bowl arc: from (pi - alphaL) clockwise through pi/2 to alphaR
    const int bowlSteps = 24;
    final startBowlAngle = math.pi - alphaL;
    final endBowlAngle = alphaR;
    final bowlPath = Path();

    for (int i = 0; i <= bowlSteps; i++) {
      final a = startBowlAngle - (startBowlAngle - endBowlAngle) * (i / bowlSteps);
      final px = c2x + rb * math.cos(a);
      final py = c2y + rb * math.sin(a);
      dockPath.lineTo(px, py);

      if (i == 0) {
        bowlPath.moveTo(px, py);
      } else {
        bowlPath.lineTo(px, py);
      }
    }

    // Right shoulder arc: from (-pi + alphaR) to -pi/2
    for (int i = 1; i <= shoulderSteps; i++) {
      final a = (-math.pi + alphaR) + (math.pi / 2 - alphaR) * (i / shoulderSteps);
      dockPath.lineTo(c3x + sR * math.cos(a), c3y + sR * math.sin(a));
    }

    // Flat line to top right
    dockPath.lineTo(w - r, 0);

    // Top-right corner
    dockPath.arcToPoint(Offset(w, r), radius: Radius.circular(r), clockwise: true);
    // Right side
    dockPath.lineTo(w, h - r);
    // Bottom-right corner
    dockPath.arcToPoint(Offset(w - r, h), radius: Radius.circular(r), clockwise: true);
    // Bottom edge
    dockPath.lineTo(r, h);
    // Bottom-left corner
    dockPath.arcToPoint(Offset(0, h - r), radius: Radius.circular(r), clockwise: true);
    // Left side
    dockPath.lineTo(0, r);
    // Top-left corner
    dockPath.arcToPoint(Offset(r, 0), radius: Radius.circular(r), clockwise: true);
    dockPath.close();

    // 2. Ambient Drop Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.save();
    canvas.translate(0, 8);
    canvas.drawPath(dockPath, shadowPaint);
    canvas.restore();

    // 3. Plate Gradient Fill (#161927 to #0C0E17)
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          dockFillColor,
          const Color(0xFF0C0E17),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(dockPath, fillPaint);

    // 4. Subtle Outer Border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF2E334D).withOpacity(0.8);
    canvas.drawPath(dockPath, borderPaint);

    // 5. Luminous Rim Highlight strictly on the socket bowl arc
    final rimGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = accentColor.withOpacity(0.65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(bowlPath, rimGlowPaint);

    final rimCrispPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = accentColor;
    canvas.drawPath(bowlPath, rimCrispPaint);
  }

  @override
  bool shouldRepaint(covariant MeniscusPainter oldDelegate) {
    return oldDelegate.beadX != beadX ||
        oldDelegate.beadY != beadY ||
        oldDelegate.bowlRadius != bowlRadius ||
        oldDelegate.shoulderRadius != shoulderRadius ||
        oldDelegate.velocityX != velocityX ||
        oldDelegate.dockFillColor != dockFillColor ||
        oldDelegate.accentColor != accentColor;
  }
}
