import 'package:flutter/material.dart';
import 'app_skeleton.dart';

/// Skeleton loader for Arena Cards (Grid or List views).
/// Preserves exact layout dimensions of Voice Room / Arena cards.
class ArenaSkeletonWidget extends StatelessWidget {
  final bool isGrid;
  final int itemCount;

  const ArenaSkeletonWidget({
    Key? key,
    this.isGrid = true,
    this.itemCount = 6,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppSkeleton.shimmer(
      context: context,
      child: isGrid ? _buildGrid(context) : _buildList(context),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image Placeholder
              Expanded(
                flex: 5,
                child: AppSkeleton.box(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 14,
                  context: context,
                ),
              ),
              const SizedBox(height: 8),
              // Title Line
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AppSkeleton.line(
                  width: 110,
                  height: 14,
                  context: context,
                ),
              ),
              const SizedBox(height: 6),
              // Subtitle/Tag Line
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    AppSkeleton.circle(size: 16, context: context),
                    const SizedBox(width: 6),
                    AppSkeleton.line(width: 65, height: 10, context: context),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              AppSkeleton.box(width: 76, height: 76, borderRadius: 12, context: context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppSkeleton.line(width: 140, height: 14, context: context),
                    const SizedBox(height: 8),
                    AppSkeleton.line(width: 90, height: 10, context: context),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        AppSkeleton.circle(size: 14, context: context),
                        const SizedBox(width: 4),
                        AppSkeleton.line(width: 50, height: 10, context: context),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
