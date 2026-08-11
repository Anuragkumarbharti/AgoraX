import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/community/post_model.dart';
import '../common/optimized_image.dart';

class FeedPdfWidget extends StatelessWidget {
  final Post post;

  const FeedPdfWidget({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final metadata = post.mediaMetadata;
    final fileName = metadata['file_name'] ?? (post.caption.isNotEmpty ? post.caption : 'Document.pdf');
    final pageCount = metadata['page_count'] ?? 1;
    final fileSizeMb = ((metadata['file_size'] ?? 1840000) / (1024 * 1024)).toStringAsFixed(1);
    final thumbUrl = post.thumbnailUrl;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A26) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main PDF Preview Box
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 1st Page Thumbnail Preview
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 50,
                    height: 60,
                    child: thumbUrl.isNotEmpty
                        ? OptimizedImage(imageUrl: thumbUrl, quality: ImageQuality.thumbnail, fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFFF59E0B).withOpacity(0.15),
                            child: const Center(
                              child: Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFF59E0B), size: 28),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // File Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: GoogleFonts.poppins(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$pageCount Pages • $fileSizeMb MB • PDF Document',
                        style: GoogleFonts.poppins(
                          color: context.caption,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // Action Buttons: Open PDF & Download / Save
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Opening PDF: $fileName'),
                        backgroundColor: const Color(0xFFF59E0B),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_rounded, size: 16, color: Color(0xFFF59E0B)),
                  label: Text(
                    'Open PDF',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFF59E0B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Container(width: 0.5, height: 28, color: context.caption.withOpacity(0.2)),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Downloading $fileName...'),
                        backgroundColor: context.primaryColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: Icon(Icons.download_rounded, size: 16, color: context.primaryColor),
                  label: Text(
                    'Download / Save',
                    style: GoogleFonts.poppins(
                      color: context.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
