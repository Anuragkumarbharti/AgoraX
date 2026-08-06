import 'package:flutter/material.dart';
import '../common/app_skeleton.dart';

/// Skeleton loader for Communities & Channels.
class CommunitySkeletonWidget extends StatelessWidget {
  final int itemCount;

  const CommunitySkeletonWidget({
    Key? key,
    this.itemCount = 6,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppSkeleton.shimmer(
      context: context,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                AppSkeleton.box(width: 56, height: 56, borderRadius: 14, context: context),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeleton.line(width: 130, height: 14, context: context),
                      const SizedBox(height: 6),
                      AppSkeleton.line(width: 180, height: 11, context: context),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          AppSkeleton.line(width: 70, height: 10, context: context),
                          const SizedBox(width: 12),
                          AppSkeleton.line(width: 50, height: 10, context: context),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AppSkeleton.box(width: 68, height: 32, borderRadius: 20, context: context),
              ],
            ),
          );
        },
      ),
    );
  }
}
