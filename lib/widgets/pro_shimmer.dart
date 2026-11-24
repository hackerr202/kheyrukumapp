import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class _ShimmerAnimationScope extends InheritedNotifier<Animation<double>> {
  const _ShimmerAnimationScope({
    required Animation<double> animation,
    required super.child,
  }) : super(notifier: animation);

  static double progressOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ShimmerAnimationScope>();
    return scope?.notifier?.value ?? 0.0;
  }
}

/// Pure-Flutter lightweight shimmer scope wrapped in [RepaintBoundary].
/// Uses Warm Sanctuary Ivory in Light mode and Deep Pine tones in Dark mode.
class ProShimmer extends StatefulWidget {
  final Widget child;

  const ProShimmer({super.key, required this.child});

  @override
  State<ProShimmer> createState() => _ProShimmerState();
}

class _ProShimmerState extends State<ProShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _ShimmerAnimationScope(
        animation: _controller,
        child: widget.child,
      ),
    );
  }
}

/// Single shimmer placeholder rectangle or circle.
class ProShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final bool isCircle;

  const ProShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 10,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final t = _ShimmerAnimationScope.progressOf(context);
    final baseColor =
        p.isDark ? const Color(0xFF0A2B22) : const Color(0xFFECE8DF);
    final highlightColor =
        p.isDark ? const Color(0xFF134235) : const Color(0xFFF7F5EF);
    final slide = -1.6 + (3.2 * t);

    return Container(
      width: isCircle ? height : width,
      height: height,
      decoration: BoxDecoration(
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(slide - 0.6, -0.2),
          end: Alignment(slide + 0.6, 0.2),
          colors: [baseColor, highlightColor, baseColor],
          stops: const [0.1, 0.5, 0.9],
        ),
      ),
    );
  }
}

/// Warm Ivory/Emerald Night skeleton matching the Home Dashboard layout.
class ProDashboardSkeleton extends StatelessWidget {
  const ProDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return ProShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 124),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: p.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProShimmerBox(width: 120, height: 12, borderRadius: 6),
                SizedBox(height: 10),
                ProShimmerBox(width: 210, height: 22, borderRadius: 8),
                SizedBox(height: 18),
                ProShimmerBox(height: 10, borderRadius: 6),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ProShimmerBox(height: 36, isCircle: true),
                    ProShimmerBox(height: 36, isCircle: true),
                    ProShimmerBox(height: 36, isCircle: true),
                    ProShimmerBox(height: 36, isCircle: true),
                    ProShimmerBox(height: 36, isCircle: true),
                    ProShimmerBox(height: 36, isCircle: true),
                    ProShimmerBox(height: 36, isCircle: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(child: ProShimmerBox(height: 92, borderRadius: 20)),
              SizedBox(width: 12),
              Expanded(child: ProShimmerBox(height: 92, borderRadius: 20)),
            ],
          ),
          const SizedBox(height: 22),
          const ProShimmerBox(width: 160, height: 16, borderRadius: 8),
          const SizedBox(height: 12),
          const ProShimmerBox(height: 82, borderRadius: 20),
          const SizedBox(height: 12),
          const ProShimmerBox(height: 82, borderRadius: 20),
        ],
      ),
    );
  }
}

/// Skeleton list resembling conversation tiles in MessagesTab.
class ProChatListSkeleton extends StatelessWidget {
  final int itemCount;

  const ProChatListSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return ProShimmer(
      child: Column(
        children: List.generate(itemCount, (i) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: const Row(
              children: [
                ProShimmerBox(height: 46, isCircle: true),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProShimmerBox(width: 148, height: 14, borderRadius: 6),
                      SizedBox(height: 8),
                      ProShimmerBox(width: 210, height: 11, borderRadius: 6),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                ProShimmerBox(width: 36, height: 10, borderRadius: 5),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Skeleton loader for card-based screens (Students, Homework, Payments).
class ProCardListSkeleton extends StatelessWidget {
  final int itemCount;

  const ProCardListSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return ProShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 124),
        children: [
          const ProShimmerBox(height: 124, borderRadius: 24),
          const SizedBox(height: 18),
          ...List.generate(itemCount, (i) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ProShimmerBox(height: 40, isCircle: true),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProShimmerBox(
                                width: 155, height: 14, borderRadius: 6),
                            SizedBox(height: 7),
                            ProShimmerBox(
                                width: 110, height: 11, borderRadius: 6),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  ProShimmerBox(height: 34, borderRadius: 12),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
