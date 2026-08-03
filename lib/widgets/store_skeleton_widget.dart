import 'package:flutter/material.dart';
import 'app_skeleton.dart';

/// Skeleton loader for Coin Store, Customizations, and Inventory.
class StoreSkeletonWidget extends StatelessWidget {
  const StoreSkeletonWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppSkeleton.shimmer(
      context: context,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Balance Banner Skeleton
            AppSkeleton.box(
              width: double.infinity,
              height: 120,
              borderRadius: 20,
              context: context,
            ),
            const SizedBox(height: 24),
            // Section Title
            AppSkeleton.line(width: 140, height: 16, context: context),
            const SizedBox(height: 16),
            // Grid of Packages / Items
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              itemBuilder: (context, index) {
                return AppSkeleton.box(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 16,
                  context: context,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
