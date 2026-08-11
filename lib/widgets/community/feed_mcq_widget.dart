import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/community/post_model.dart';
import '../../services/post/post_repository.dart';

class FeedMcqWidget extends StatefulWidget {
  final Post post;

  const FeedMcqWidget({Key? key, required this.post}) : super(key: key);

  @override
  State<FeedMcqWidget> createState() => _FeedMcqWidgetState();
}

class _FeedMcqWidgetState extends State<FeedMcqWidget> {
  String? _selectedOptionId;
  bool _hasSubmitted = false;
  bool _isCorrect = false;
  String _explanation = '';

  @override
  void initState() {
    super.initState();
    if (widget.post.mcqData?.userSelectedOptionId != null) {
      _selectedOptionId = widget.post.mcqData!.userSelectedOptionId;
      _hasSubmitted = true;
    }
  }

  Future<void> _handleSelectOption(String optionId) async {
    if (_hasSubmitted) return;

    setState(() {
      _selectedOptionId = optionId;
      _hasSubmitted = true;
    });

    final res = await PostRepository.submitMcqVote(widget.post.id, optionId);
    if (res != null) {
      setState(() {
        _isCorrect = res['is_correct'] ?? false;
        _explanation = res['explanation'] ?? widget.post.mcqData?.explanation ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mcq = widget.post.mcqData;
    if (mcq == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111E25) : const Color(0xFFECFEFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.quiz_rounded, color: Color(0xFF06B6D4), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'QUIZ • ${mcq.difficulty.toUpperCase()}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF06B6D4),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 12),
                    const SizedBox(width: 2),
                    Text(
                      '+${mcq.xpReward} XP',
                      style: GoogleFonts.outfit(color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Question
          Text(
            mcq.question,
            style: GoogleFonts.poppins(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Options
          Column(
            children: mcq.options.map((option) {
              final isSelected = _selectedOptionId == option.id;
              final isCorrectOpt = option.isCorrect;

              Color optionBg = isDark ? const Color(0xFF1A2A33) : Colors.white;
              Color borderCol = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300;
              Color textColor = context.textPrimary;

              if (_hasSubmitted) {
                if (isCorrectOpt) {
                  optionBg = const Color(0xFF10B981).withOpacity(0.2);
                  borderCol = const Color(0xFF10B981);
                } else if (isSelected && !isCorrectOpt) {
                  optionBg = const Color(0xFFEF4444).withOpacity(0.2);
                  borderCol = const Color(0xFFEF4444);
                }
              } else if (isSelected) {
                borderCol = const Color(0xFF06B6D4);
              }

              return GestureDetector(
                onTap: () => _handleSelectOption(option.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: optionBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.text,
                          style: GoogleFonts.poppins(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_hasSubmitted && isCorrectOpt)
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18)
                      else if (_hasSubmitted && isSelected && !isCorrectOpt)
                        const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 18),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // Explanation Section after submission
          if (_hasSubmitted && (mcq.explanation.isNotEmpty || _explanation.isNotEmpty)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF172833) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Explanation:',
                    style: GoogleFonts.poppins(color: const Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _explanation.isNotEmpty ? _explanation : mcq.explanation,
                    style: GoogleFonts.poppins(color: context.caption, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
