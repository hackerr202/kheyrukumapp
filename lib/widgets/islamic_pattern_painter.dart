import 'package:flutter/material.dart';

/// Subtle geometric 8-point Khatam / Rub-el-Hizb lattice ornament
/// rendered efficiently as a quiet backdrop for hero cards and headers.
class IslamicGeometricPattern extends StatelessWidget {
  final Color color;
  final double opacity;
  final double cellSize;
  final bool showCornerArcs;

  const IslamicGeometricPattern({
    super.key,
    this.color = Colors.white,
    this.opacity = 0.06,
    this.cellSize = 54.0,
    this.showCornerArcs = false,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _IslamicPatternPainter(
          color: color.withOpacity(opacity),
          cellSize: cellSize,
          showCornerArcs: showCornerArcs,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _IslamicPatternPainter extends CustomPainter {
  final Color color;
  final double cellSize;
  final bool showCornerArcs;

  _IslamicPatternPainter({
    required this.color,
    required this.cellSize,
    required this.showCornerArcs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    final cols = (size.width / cellSize).ceil() + 1;
    final rows = (size.height / cellSize).ceil() + 1;
    final r = cellSize * 0.34;
    final rotatedHalf = r * 0.70710678;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final cx = col * cellSize;
        final cy = row * cellSize;

        // Axis-aligned square of the 8-point Khatam star
        canvas.drawRect(
          Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2),
          paint,
        );

        // 45-degree rotated diamond (Rub-el-Hizb)
        final diamond = Path()
          ..moveTo(cx, cy - r * 1.414)
          ..lineTo(cx + r * 1.414, cy)
          ..lineTo(cx, cy + r * 1.414)
          ..lineTo(cx - r * 1.414, cy)
          ..close();
        canvas.drawPath(diamond, paint);

        // Subtle inner octagon dot accent
        canvas.drawCircle(Offset(cx, cy), rotatedHalf * 0.25, paint);
      }
    }

    if (showCornerArcs) {
      final arcPaint = Paint()
        ..color = color.withOpacity((color.opacity * 1.6).clamp(0.0, 0.25))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1;

      for (final radius in [44.0, 74.0, 104.0]) {
        canvas.drawCircle(Offset(size.width, 0), radius, arcPaint);
        canvas.drawCircle(Offset(0, size.height), radius, arcPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IslamicPatternPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.showCornerArcs != showCornerArcs;
  }
}
