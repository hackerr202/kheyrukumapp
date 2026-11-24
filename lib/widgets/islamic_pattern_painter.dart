import 'package:flutter/material.dart';

/// Subtle geometric 8-point Khatam / Rub-el-Hizb lattice ornament
/// rendered efficiently as a cached path backdrop for hero cards and headers.
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

  static final Map<String, Path> _latticePathCache = {};

  _IslamicPatternPainter({
    required this.color,
    required this.cellSize,
    required this.showCornerArcs,
  });

  static Path _getOrBuildLatticePath(Size size, double cellSize) {
    final key =
        '${size.width.round()}x${size.height.round()}_${cellSize.round()}';
    final cached = _latticePathCache[key];
    if (cached != null) return cached;

    if (_latticePathCache.length >= 24) {
      _latticePathCache.clear();
    }

    final combined = Path();
    final cols = (size.width / cellSize).ceil() + 1;
    final rows = (size.height / cellSize).ceil() + 1;
    final r = cellSize * 0.34;
    final rotatedRadius = r * 1.414;
    final dotRadius = r * 0.70710678 * 0.25;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final cx = col * cellSize;
        final cy = row * cellSize;

        // Axis-aligned square of the 8-point Khatam star
        combined.addRect(
          Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2),
        );

        // 45-degree rotated diamond (Rub-el-Hizb)
        combined
          ..moveTo(cx, cy - rotatedRadius)
          ..lineTo(cx + rotatedRadius, cy)
          ..lineTo(cx, cy + rotatedRadius)
          ..lineTo(cx - rotatedRadius, cy)
          ..close();

        // Subtle inner octagon dot accent
        combined.addOval(
          Rect.fromCircle(center: Offset(cx, cy), radius: dotRadius),
        );
      }
    }

    _latticePathCache[key] = combined;
    return combined;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    canvas.drawPath(_getOrBuildLatticePath(size, cellSize), paint);

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
