import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/community/post_model.dart';
import '../common/optimized_image.dart';

class FeedPhotoWidget extends StatelessWidget {
  final Post post;

  const FeedPhotoWidget({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imageUrl = post.thumbnailUrl.isNotEmpty ? post.thumbnailUrl : (post.images != null && post.images!.isNotEmpty ? post.images!.first : post.mediaUrl);
    if (imageUrl.isEmpty) return const SizedBox.shrink();

    // Use precalculated aspect ratio to reserve exact space & eliminate layout shift
    final double ratio = post.aspectRatio > 0 ? post.aspectRatio.clamp(0.6, 2.0) : 1.33;

    return AspectRatio(
      aspectRatio: ratio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: OptimizedImage(
          imageUrl: imageUrl,
          quality: ImageQuality.medium,
          fit: BoxFit.cover,
          placeholder: Container(
            color: context.secondaryBackgroundColor,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: context.primaryColor),
              ),
            ),
          ),
          errorWidget: Container(
            color: context.secondaryBackgroundColor,
            child: Icon(Icons.broken_image_rounded, color: context.caption),
          ),
        ),
      ),
    );
  }
}
