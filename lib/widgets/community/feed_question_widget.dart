import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/community/post_model.dart';

class FeedQuestionWidget extends StatelessWidget {
  final Post post;
  final VoidCallback? onAnswerTap;

  const FeedQuestionWidget({
    Key? key,
    required this.post,
    this.onAnswerTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final qData = post.questionData;
    final questionText = qData?.question.isNotEmpty == true ? qData!.question : post.caption;
    final contextText = qData?.context ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131F1C) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.help_outline_rounded, color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'QUESTION',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Question Prompt
          Text(
            questionText,
            style: GoogleFonts.poppins(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (contextText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              contextText,
              style: GoogleFonts.poppins(
                color: context.caption,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Answer Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAnswerTap,
              icon: const Icon(Icons.mode_comment_outlined, size: 16, color: Colors.white),
              label: Text(
                'Answer Question (${post.comments})',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
