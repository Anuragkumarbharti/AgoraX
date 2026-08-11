import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../models/community/post_model.dart';
import '../../models/community/post_type.dart';
import '../../services/post/post_repository.dart';
import '../common/optimized_image.dart';

// Specialized Type Feed Cards
import 'feed_photo_widget.dart';
import 'feed_video_widget.dart';
import 'feed_audio_widget.dart';
import 'feed_pdf_widget.dart';
import 'feed_question_widget.dart';
import 'feed_mcq_widget.dart';
import 'feed_poll_widget.dart';
import 'feed_link_widget.dart';
import 'post_attachments_widget.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onTap;

  const PostCard({
    Key? key,
    required this.post,
    this.onTap,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _isLiked;
  late int _likes;
  late bool _isBookmarked;
  late int _comments;
  late int _shares;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likes = widget.post.likes;
    _isBookmarked = widget.post.isBookmarked;
    _comments = widget.post.comments;
    _shares = widget.post.shares;
  }

  Future<void> _handleLike() async {
    final prevLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likes = _isLiked ? _likes + 1 : _likes - 1;
    });

    await PostRepository.toggleLike(widget.post.id, prevLiked);
  }

  Future<void> _handleBookmark() async {
    final prevBookmarked = _isBookmarked;
    setState(() {
      _isBookmarked = !_isBookmarked;
    });

    Get.snackbar(
      _isBookmarked ? 'Bookmarked 📚' : 'Bookmark Removed 🗑️',
      _isBookmarked ? 'Post added to your saved posts.' : 'Post removed from saved posts.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
    );

    await PostRepository.toggleBookmark(widget.post.id, prevBookmarked);
  }

  void _handleComment() {
    final TextEditingController controller = TextEditingController();
    Get.dialog(
      Dialog(
        backgroundColor: context.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ADD COMMENT',
                    style: GoogleFonts.outfit(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: context.caption, size: 18),
                    onPressed: () => Get.back(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Write your comment...',
                  hintStyle: GoogleFonts.poppins(color: context.caption, fontSize: 13),
                  filled: true,
                  fillColor: context.secondaryBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      setState(() {
                        _comments++;
                      });
                      Get.back();
                      Get.snackbar(
                        'Comment Added',
                        'Your response was posted.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: const Color(0xFF10B981),
                        colorText: Colors.white,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Post Comment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleShare() {
    Share.share('Check out this post on Creania!\n${widget.post.caption}');
  }

  void _handleReport() {
    Get.dialog(
      AlertDialog(
        backgroundColor: context.dialogBackgroundColor,
        title: Text('Report Post', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Report this post for inappropriate content or spam?', style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Get.back();
              await PostRepository.reportPost(widget.post.id, 'Inappropriate content');
              Get.snackbar(
                'Report Submitted',
                'Thank you for keeping Creania safe.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: context.primaryColor,
                colorText: Colors.white,
              );
            },
            child: const Text('Report', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final post = widget.post;
    final formattedTime = DateFormat.yMMMd().add_jm().format(post.createdAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161622) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header Bar
          Row(
            children: [
              // Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: (post.authorAvatarUrl != null && post.authorAvatarUrl!.isNotEmpty)
                      ? OptimizedImage(
                          imageUrl: post.authorAvatarUrl!,
                          quality: ImageQuality.thumbnail,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: context.primaryColor.withOpacity(0.2),
                          child: Icon(Icons.person, color: context.primaryColor, size: 22),
                        ),
                ),
              ),
              const SizedBox(width: 10),

              // Username & Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post.authorUsername ?? 'Creania User',
                          style: GoogleFonts.poppins(
                            color: context.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Post Type Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: post.postType.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${post.postType.emoji} ${post.postType.displayName}',
                            style: TextStyle(
                              color: post.postType.color,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedTime,
                      style: GoogleFonts.poppins(
                        color: context.caption,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              // Options Menu Popup
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'bookmark') _handleBookmark();
                  if (val == 'share') _handleShare();
                  if (val == 'report') _handleReport();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'bookmark',
                    child: Text(_isBookmarked ? '🔖 Remove Bookmark' : '🔖 Save Post'),
                  ),
                  const PopupMenuItem(value: 'share', child: Text('🔗 Share Post')),
                  const PopupMenuItem(value: 'report', child: Text('🚩 Report Post', style: TextStyle(color: Colors.red))),
                ],
                child: Icon(Icons.more_horiz_rounded, color: context.caption, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Caption Text (if present and not duplicated in special card)
          if (post.caption.isNotEmpty && post.postType != PostType.mcq && post.postType != PostType.poll && post.postType != PostType.question) ...[
            Text(
              post.caption,
              style: GoogleFonts.poppins(
                color: context.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Type-Specific Optimized Feed Widget
          _buildSpecializedFeedContent(context, post),

          const SizedBox(height: 12),

          // Action Buttons Bar (Like, Comment, Share, Bookmark)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Like
              InkWell(
                onTap: _handleLike,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: _isLiked ? Colors.redAccent : context.caption,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_likes',
                        style: GoogleFonts.poppins(
                          color: _isLiked ? Colors.redAccent : context.caption,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Comment
              InkWell(
                onTap: _handleComment,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, color: context.caption, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '$_comments',
                        style: GoogleFonts.poppins(
                          color: context.caption,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Share
              InkWell(
                onTap: _handleShare,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, color: context.caption, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '$_shares',
                        style: GoogleFonts.poppins(
                          color: context.caption,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bookmark
              IconButton(
                icon: Icon(
                  _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: _isBookmarked ? const Color(0xFF8B5CF6) : context.caption,
                  size: 20,
                ),
                onPressed: _handleBookmark,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecializedFeedContent(BuildContext context, Post post) {
    switch (post.postType) {
      case PostType.photo:
        return FeedPhotoWidget(post: post);
      case PostType.video:
        return FeedVideoWidget(post: post);
      case PostType.audio:
        return FeedAudioWidget(post: post);
      case PostType.pdf:
        return FeedPdfWidget(post: post);
      case PostType.question:
        return FeedQuestionWidget(post: post, onAnswerTap: _handleComment);
      case PostType.mcq:
        return FeedMcqWidget(post: post);
      case PostType.poll:
        return FeedPollWidget(post: post);
      case PostType.link:
        return FeedLinkWidget(post: post);
      case PostType.text:
      default:
        // Legacy multi-attachment fallback if images/videos/pdfs arrays exist
        if ((post.images != null && post.images!.isNotEmpty) ||
            (post.videos != null && post.videos!.isNotEmpty) ||
            (post.pdfs != null && post.pdfs!.isNotEmpty)) {
          return PostAttachmentsWidget(post: post);
        }
        return const SizedBox.shrink();
    }
  }
}
