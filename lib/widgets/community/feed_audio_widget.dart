import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/community/post_model.dart';
import '../common/optimized_image.dart';

class FeedAudioWidget extends StatefulWidget {
  final Post post;

  const FeedAudioWidget({Key? key, required this.post}) : super(key: key);

  @override
  State<FeedAudioWidget> createState() => _FeedAudioWidgetState();
}

class _FeedAudioWidgetState extends State<FeedAudioWidget> {
  bool _isPlaying = false;
  double _playbackPosition = 0.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coverUrl = widget.post.thumbnailUrl;
    final title = widget.post.caption.isNotEmpty ? widget.post.caption : 'Audio Post';
    final metadata = widget.post.mediaMetadata;
    final durationSec = metadata['duration_seconds'] ?? 45;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191926) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.primaryColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Cover Image or Default Music Icon
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: coverUrl.isNotEmpty
                      ? OptimizedImage(imageUrl: coverUrl, quality: ImageQuality.thumbnail, fit: BoxFit.cover)
                      : Container(
                          color: const Color(0xFF8B5CF6).withOpacity(0.2),
                          child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFF8B5CF6), size: 24),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: context.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(durationSec ~/ 60)}:${(durationSec % 60).toString().padLeft(2, '0')} • Voice Clip',
                      style: GoogleFonts.poppins(
                        color: context.caption,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Play / Pause Button
              IconButton(
                onPressed: () {
                  setState(() => _isPlaying = !_isPlaying);
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF8B5CF6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Waveform bar visualizer
          Row(
            children: List.generate(24, (index) {
              final heights = [8.0, 14.0, 22.0, 10.0, 18.0, 26.0, 12.0, 20.0, 16.0, 24.0, 10.0, 18.0, 28.0, 14.0, 20.0, 8.0, 16.0, 22.0, 12.0, 18.0, 24.0, 10.0, 16.0, 8.0];
              final isPlayed = index < (_playbackPosition * 24);
              return Expanded(
                child: Container(
                  height: heights[index % heights.length],
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: isPlayed ? const Color(0xFF8B5CF6) : context.caption.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
