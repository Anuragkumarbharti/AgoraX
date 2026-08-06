import 'package:flutter/material.dart';
import '../common/app_skeleton.dart';

/// Skeleton loader for Followers, Following, and Friends list views.
class FollowersSkeletonWidget extends StatelessWidget {
  final int itemCount;

  const FollowersSkeletonWidget({
    Key? key,
    this.itemCount = 8,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppSkeleton.shimmer(
      context: context,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Row(
            children: [
              AppSkeleton.circle(size: 48, context: context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton.line(width: 120, height: 13, context: context),
                    const SizedBox(height: 6),
                    AppSkeleton.line(width: 80, height: 10, context: context),
                  ],
                ),
              ),
              AppSkeleton.box(width: 72, height: 30, borderRadius: 18, context: context),
            ],
          );
        },
      ),
    );
  }
}
