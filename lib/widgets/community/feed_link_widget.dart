import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/community/post_model.dart';

class FeedLinkWidget extends StatelessWidget {
  final Post post;

  const FeedLinkWidget({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final url = post.mediaUrl.isNotEmpty ? post.mediaUrl : post.caption;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF142422) : const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.link_rounded, color: Color(0xFF14B8A6), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  url,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF14B8A6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap to visit external link',
                  style: GoogleFonts.poppins(color: context.caption, fontSize: 11),
                ),
              ],
            ),
          ),
          Icon(Icons.open_in_new_rounded, color: context.caption, size: 16),
        ],
      ),
    );
  }
}
