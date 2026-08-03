import 'package:flutter/material.dart';
import 'app_skeleton.dart';

/// Skeleton loader for Chat & Conversation Lists.
class ChatListSkeletonWidget extends StatelessWidget {
  final int itemCount;

  const ChatListSkeletonWidget({
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return Row(
            children: [
              AppSkeleton.circle(size: 52, context: context),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppSkeleton.line(width: 120, height: 14, context: context),
                        AppSkeleton.line(width: 40, height: 10, context: context),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AppSkeleton.line(width: 180, height: 12, context: context),
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
