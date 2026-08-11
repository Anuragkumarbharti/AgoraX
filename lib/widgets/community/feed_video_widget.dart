import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/community/post_model.dart';
import '../room/video_player_dialog.dart';
import '../common/optimized_image.dart';

class FeedVideoWidget extends StatelessWidget {
  final Post post;

  const FeedVideoWidget({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final videoUrl = post.mediaUrl.isNotEmpty ? post.mediaUrl : (post.videos != null && post.videos!.isNotEmpty ? post.videos!.first : '');
    final thumbUrl = post.thumbnailUrl;
    final ratio = post.aspectRatio > 0 ? post.aspectRatio.clamp(0.6, 2.0) : (16 / 9);

    return GestureDetector(
      onTap: () {
        if (videoUrl.isNotEmpty) {
          showDialog(
            context: context,
            builder: (_) => VideoPlayerDialog(videoUrl: videoUrl),
          );
        }
      },
      child: AspectRatio(
        aspectRatio: ratio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Low-resolution thumbnail preview only (never load heavy video in feed)
              thumbUrl.isNotEmpty
                  ? OptimizedImage(
                      imageUrl: thumbUrl,
                      quality: ImageQuality.thumbnail,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: Container(color: Colors.black87),
                      errorWidget: Container(color: Colors.black87),
                    )
                  : Container(
                      color: Colors.black87,
                      child: Center(
                        child: Icon(
                          Icons.movie_rounded,
                          size: 48,
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                    ),

              // Play Button Overlay
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),

              // Video Badge
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'VIDEO',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
