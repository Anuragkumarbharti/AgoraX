import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/community/post_model.dart';
import '../common/optimized_image.dart';

class FeedPhotoWidget extends StatelessWidget {
  final Post post;

  const FeedPhotoWidget({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imageUrl = post.thumbnailUrl.isNotEmpty
        ? post.thumbnailUrl
        : (post.images != null && post.images!.isNotEmpty ? post.images!.first : post.mediaUrl);
    if (imageUrl.isEmpty) return const SizedBox.shrink();

    final double ratio = post.aspectRatio > 0 ? post.aspectRatio.clamp(0.6, 2.0) : 1.33;
    final isLocalFile = !imageUrl.startsWith('http://') && !imageUrl.startsWith('https://');

    return AspectRatio(
      aspectRatio: ratio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: isLocalFile && File(imageUrl).existsSync()
            ? Image.file(
                File(imageUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: context.secondaryBackgroundColor,
                  child: Icon(Icons.broken_image_rounded, color: context.caption),
                ),
              )
            : OptimizedImage(
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
