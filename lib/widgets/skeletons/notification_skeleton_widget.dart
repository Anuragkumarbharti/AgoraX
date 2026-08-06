import 'package:flutter/material.dart';
import '../common/app_skeleton.dart';

/// Skeleton loader for Notification History & Activity Feed.
class NotificationSkeletonWidget extends StatelessWidget {
  final int itemCount;

  const NotificationSkeletonWidget({
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
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton.circle(size: 44, context: context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton.line(width: 160, height: 13, context: context),
                    const SizedBox(height: 6),
                    AppSkeleton.line(width: double.infinity, height: 11, context: context),
                    const SizedBox(height: 6),
                    AppSkeleton.line(width: 60, height: 9, context: context),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
