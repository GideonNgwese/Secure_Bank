import 'package:flutter/material.dart';

/// A sliding-gradient shimmer used for loading skeletons.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final dx = (_c.value * 2 - 1) * 1.5;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(dx - 0.5, 0),
            end: Alignment(dx + 0.5, 0),
            colors: const [
              Color(0xFFE9EDF3),
              Color(0xFFF7F9FC),
              Color(0xFFE9EDF3),
            ],
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A grey placeholder block.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, this.height = 16, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF3),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Full dashboard loading skeleton.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: const [
              SkeletonBox(width: 44, height: 44, radius: 22),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 120, height: 12),
                    SizedBox(height: 8),
                    SkeletonBox(width: 80, height: 10),
                  ],
                ),
              ),
              SkeletonBox(width: 40, height: 40, radius: 12),
            ],
          ),
          const SizedBox(height: 20),
          const SkeletonBox(height: 170, radius: 22),
          const SizedBox(height: 20),
          Row(
            children: List.generate(
              4,
              (i) => const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: SkeletonBox(height: 76, radius: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SkeletonBox(width: 160, height: 14),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                SkeletonBox(width: 200, height: 120, radius: 18),
                SizedBox(width: 12),
                SkeletonBox(width: 200, height: 120, radius: 18),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < 4; i++) ...[
            Row(
              children: const [
                SkeletonBox(width: 44, height: 44, radius: 14),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 14)),
                SizedBox(width: 12),
                SkeletonBox(width: 60, height: 14),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
