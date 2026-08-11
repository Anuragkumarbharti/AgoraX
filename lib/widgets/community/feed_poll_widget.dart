import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/community/post_model.dart';
import '../../services/post/post_repository.dart';

class FeedPollWidget extends StatefulWidget {
  final Post post;

  const FeedPollWidget({Key? key, required this.post}) : super(key: key);

  @override
  State<FeedPollWidget> createState() => _FeedPollWidgetState();
}

class _FeedPollWidgetState extends State<FeedPollWidget> {
  String? _selectedOptionId;
  bool _hasVoted = false;
  Map<String, int> _optionCounts = {};
  int _totalVotes = 0;

  @override
  void initState() {
    super.initState();
    final poll = widget.post.pollData;
    if (poll != null) {
      _selectedOptionId = poll.userSelectedOptionId;
      _hasVoted = _selectedOptionId != null;
      _optionCounts = Map.from(poll.optionCounts);
      _totalVotes = poll.totalVotes;
    }
  }

  Future<void> _handleVote(String optionId) async {
    if (_hasVoted) return;

    setState(() {
      _selectedOptionId = optionId;
      _hasVoted = true;
      _optionCounts[optionId] = (_optionCounts[optionId] ?? 0) + 1;
      _totalVotes++;
    });

    final res = await PostRepository.submitPollVote(widget.post.id, optionId);
    if (res != null && res['option_counts'] != null) {
      setState(() {
        _totalVotes = res['total_votes'] ?? _totalVotes;
        if (res['option_counts'] is Map) {
          (res['option_counts'] as Map).forEach((k, v) {
            _optionCounts[k.toString()] = (v as num).toInt();
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final poll = widget.post.pollData;
    if (poll == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A29) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.poll_rounded, color: Color(0xFF3B82F6), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'POLL',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF3B82F6),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '$_totalVotes Votes',
                style: GoogleFonts.poppins(color: context.caption, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Poll Question
          Text(
            poll.question,
            style: GoogleFonts.poppins(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Dynamic Options list
          Column(
            children: poll.options.map((option) {
              final isSelected = _selectedOptionId == option.id;
              final count = _optionCounts[option.id] ?? 0;
              final percentage = _totalVotes > 0 ? (count / _totalVotes) * 100 : 0.0;

              return GestureDetector(
                onTap: () => _handleVote(option.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  height: 40,
                  child: Stack(
                    children: [
                      // Progress Bar Background
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF3B82F6) : (isDark ? Colors.white12 : Colors.grey.shade300),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                      ),

                      // Animated Percentage Fill
                      if (_hasVoted)
                        AnimatedFractionallySizedBox(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          widthFactor: (percentage / 100).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF3B82F6).withOpacity(0.3)
                                  : const Color(0xFF3B82F6).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                      // Option Text & Percentage Text
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                option.text,
                                style: GoogleFonts.poppins(
                                  color: context.textPrimary,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              if (_hasVoted)
                                Text(
                                  '${percentage.toStringAsFixed(0)}%',
                                  style: GoogleFonts.outfit(
                                    color: isSelected ? const Color(0xFF3B82F6) : context.caption,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
