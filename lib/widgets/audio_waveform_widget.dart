import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 60fps real-time recording waveform driven by a [ValueNotifier] of normalized
/// amplitude samples (`0.0..1.0`) from `AudioRecorder.onAmplitudeChanged`.
class LiveRecordingWaveform extends StatefulWidget {
  final ValueNotifier<List<double>> amplitudesNotifier;
  final Color activeColor;
  final Color? inactiveColor;
  final int barCount;
  final double height;
  final bool isActive;

  const LiveRecordingWaveform({
    super.key,
    required this.amplitudesNotifier,
    required this.activeColor,
    this.inactiveColor,
    this.barCount = 28,
    this.height = 32,
    this.isActive = true,
  });

  @override
  State<LiveRecordingWaveform> createState() => _LiveRecordingWaveformState();
}

class _LiveRecordingWaveformState extends State<LiveRecordingWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isActive) {
      _pulseCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant LiveRecordingWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat();
    } else if (!widget.isActive && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final muted =
        widget.inactiveColor ?? widget.activeColor.withValues(alpha: 0.28);

    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: ValueListenableBuilder<List<double>>(
          valueListenable: widget.amplitudesNotifier,
          builder: (context, samples, _) {
            return AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) {
                final bars = _buildBars(samples, _pulseCtrl.value);
                return CustomPaint(
                  painter: _WaveformBarsPainter(
                    bars: bars,
                    progress: widget.isActive ? 1.0 : 0.0,
                    activeColor: widget.activeColor,
                    inactiveColor: muted,
                    isRtl: isRtl,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<double> _buildBars(List<double> samples, double phase) {
    final count = widget.barCount;
    final result = List<double>.filled(count, 0.18);
    if (samples.isEmpty) {
      for (var i = 0; i < count; i++) {
        final wave = math.sin((i / count) * math.pi * 3 + phase * math.pi * 2);
        result[i] = widget.isActive
            ? (0.24 + 0.34 * ((wave + 1) * 0.5)).clamp(0.16, 0.92)
            : 0.18;
      }
      return result;
    }

    final startOffset = math.max(0, samples.length - count);
    final available = samples.length - startOffset;
    final leftPad = count - available;
    for (var i = 0; i < count; i++) {
      if (i < leftPad) {
        final wave = math.sin((i / count) * math.pi * 2 + phase * math.pi * 2);
        result[i] = widget.isActive
            ? (0.16 + 0.14 * ((wave + 1) * 0.5)).clamp(0.14, 0.40)
            : 0.16;
      } else {
        final raw = samples[startOffset + (i - leftPad)];
        result[i] = raw.clamp(0.14, 1.0);
      }
    }
    return result;
  }
}

/// Interactive audio waveform bar for voice bubbles and studio playback cards.
/// Supports RTL direction, tap-to-seek scrubbing, and tabular duration labels.
class PlaybackWaveformBar extends StatelessWidget {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final String durationLabel;
  final Color? labelColor;
  final ValueChanged<double>? onSeek;
  final int seed;
  final int barCount;
  final double height;

  const PlaybackWaveformBar({
    super.key,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.durationLabel,
    this.labelColor,
    this.onSeek,
    this.seed = 0,
    this.barCount = 28,
    this.height = 24,
  });

  List<double> _generateBars() {
    var s = seed == 0 ? 1337 : seed.abs();
    return List<double>.generate(barCount, (i) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      final n = ((s >> 16) & 0xff) / 255.0;
      final contour = 0.55 + 0.45 * math.sin((i / barCount) * math.pi);
      return (0.22 + 0.72 * n * contour).clamp(0.20, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final clamped = progress.clamp(0.0, 1.0);
    final bars = _generateBars();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth > 0 ? constraints.maxWidth : 120.0;

            void handleOffset(Offset localPosition) {
              if (onSeek == null || maxWidth <= 0) return;
              var ratio = (localPosition.dx / maxWidth).clamp(0.0, 1.0);
              if (isRtl) ratio = 1.0 - ratio;
              onSeek!(ratio.clamp(0.0, 1.0));
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: onSeek == null
                  ? null
                  : (details) => handleOffset(details.localPosition),
              onHorizontalDragUpdate: onSeek == null
                  ? null
                  : (details) => handleOffset(details.localPosition),
              child: RepaintBoundary(
                child: SizedBox(
                  height: height,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _WaveformBarsPainter(
                      bars: bars,
                      progress: clamped,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      isRtl: isRtl,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 5),
        Text(
          durationLabel,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: labelColor ?? activeColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _WaveformBarsPainter extends CustomPainter {
  final List<double> bars;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final bool isRtl;

  const _WaveformBarsPainter({
    required this.bars,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.isRtl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || size.width <= 0 || size.height <= 0) return;

    final activePaint = Paint()..color = activeColor;
    final inactivePaint = Paint()..color = inactiveColor;
    final count = bars.length;
    final slotWidth = size.width / count;
    final barWidth = (slotWidth * 0.56).clamp(2.2, 4.0);
    final activeBars = (progress * count).round();

    for (var i = 0; i < count; i++) {
      final logicalIndex = isRtl ? (count - 1 - i) : i;
      final normalized = bars[logicalIndex].clamp(0.14, 1.0);
      final barHeight = math.max(4.0, size.height * normalized);
      final dx = i * slotWidth + (slotWidth - barWidth) / 2;
      final dy = (size.height - barHeight) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(dx, dy, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );
      final isFilled = logicalIndex < activeBars;
      canvas.drawRRect(rect, isFilled ? activePaint : inactivePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformBarsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.isRtl != isRtl ||
        !listEquals(oldDelegate.bars, bars);
  }
}
