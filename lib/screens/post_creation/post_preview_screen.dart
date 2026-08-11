import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/community/post_type.dart';
import '../../models/discovery/audio_track_model.dart';

class PostPreviewScreen extends StatelessWidget {
  final PostType postType;
  final String caption;
  final String title;
  final String contextText;
  final File? mediaFile;
  final AudioTrack? audioTrack;
  final List<String> mcqOptions;
  final int mcqCorrectIndex;
  final List<String> pollOptions;
  final VoidCallback onPublish;

  const PostPreviewScreen({
    Key? key,
    required this.postType,
    required this.caption,
    this.title = '',
    this.contextText = '',
    this.mediaFile,
    this.audioTrack,
    this.mcqOptions = const [],
    this.mcqCorrectIndex = 0,
    this.pollOptions = const [],
    required this.onPublish,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        title: Text(
          'Post Preview',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author Header preview
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.primaryColor,
                        child: Icon(Icons.person, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You (Preview)',
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Just now • ${postType.name.toUpperCase()}',
                            style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title if present
                  if (title.isNotEmpty) ...[
                    Text(
                      title,
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Caption with Tag Highlighting preview
                  if (caption.isNotEmpty)
                    RichText(
                      text: TextSpan(
                        children: _buildCaptionSpans(caption),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Media Preview
                  if (mediaFile != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        mediaFile!,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Audio Track Strip
                  if (audioTrack != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.music_note, color: AppTheme.primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${audioTrack!.title} - ${audioTrack!.artist}',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // MCQ Preview
                  if (postType == PostType.mcq && mcqOptions.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quiz Options', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...List.generate(mcqOptions.length, (idx) {
                            final isCorrect = idx == mcqCorrectIndex;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isCorrect ? AppTheme.primaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: isCorrect ? Border.all(color: AppTheme.primaryColor) : null,
                              ),
                              child: Row(
                                children: [
                                  Text('${String.fromCharCode(65 + idx)}.', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Text(mcqOptions[idx], style: GoogleFonts.inter(color: Colors.white)),
                                  if (isCorrect) const Spacer(),
                                  if (isCorrect) const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 16),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Confirm Publish Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onPublish();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.send, color: Colors.white),
                label: Text(
                  'Publish Now',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _buildCaptionSpans(String text) {
    final List<TextSpan> spans = [];
    final words = text.split(RegExp(r'(\s+)'));

    for (var word in words) {
      if (word.startsWith('#')) {
        spans.add(TextSpan(
          text: word,
          style: GoogleFonts.inter(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
        ));
      } else if (word.startsWith('@')) {
        spans.add(TextSpan(
          text: word,
          style: GoogleFonts.inter(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
        ));
      } else {
        spans.add(TextSpan(
          text: word,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        ));
      }
    }

    return spans;
  }
}
