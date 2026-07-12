import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import '../core/theme.dart';
import '../models/post_model.dart';
import 'post_attachments_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    Key? key,
    required this.post,
    this.onTap,
  }) : super(key: key);
  final Post post;
  final VoidCallback? onTap;

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

  void _handleLike() {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likes++;
      } else {
        _likes--;
      }
    });
  }

  void _handleBookmark() {
    setState(() {
      _isBookmarked = !_isBookmarked;
    });
    Get.snackbar(
      _isBookmarked ? 'Bookmarked 📚' : 'Bookmark Removed 🗑️',
      _isBookmarked ? 'Post added to your bookmarks.' : 'Post removed from your bookmarks.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
    );
  }

  void _handleComment(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF13131A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADD COMMENT',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Write your comment...',
                  hintStyle: GoogleFonts.poppins(color: Colors.white30, fontSize: 13),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white38)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isEmpty) return;
                      setState(() {
                        _comments++;
                      });
                      Get.back();
                      Get.snackbar(
                        'Comment Posted 💬',
                        'Your comment was posted successfully!',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: const Color(0xFF10B981),
                        colorText: Colors.white,
                        duration: const Duration(seconds: 1),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                    child: Text('Post', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _handleShare() {
    Share.share(widget.post.content);
    setState(() {
      _shares++;
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor, width: 0.5),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: widget.post.authorAvatarUrl != null && widget.post.authorAvatarUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.post.authorAvatarUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: AppTheme.bgLight),
                            errorWidget: (context, url, error) => _buildInitialsAvatar(),
                          )
                        : _buildInitialsAvatar(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.authorUsername != null && widget.post.authorUsername!.isNotEmpty
                              ? '@${widget.post.authorUsername}'
                              : 'Creania Student',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                        ),
                        Text(
                          _timeAgo(widget.post.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textTertiary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Content
              Text(
                widget.post.content,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              PostAttachmentsWidget(post: widget.post),
              const SizedBox(height: 12),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAction(
                    context,
                    _isLiked ? Icons.favorite : Icons.favorite_outline,
                    '$_likes',
                    color: _isLiked ? AppTheme.errorColor : AppTheme.textTertiary,
                    onTap: _handleLike,
                  ),
                  _buildAction(
                    context,
                    Icons.chat_bubble_outline,
                    '$_comments',
                    onTap: () => _handleComment(context),
                  ),
                  _buildAction(
                    context,
                    Icons.share_outlined,
                    '$_shares',
                    onTap: _handleShare,
                  ),
                  _buildAction(
                    context,
                    _isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                    '',
                    color: _isBookmarked ? AppTheme.primaryColor : AppTheme.textTertiary,
                    onTap: _handleBookmark,
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildAction(
    BuildContext context,
    IconData icon,
    String count, {
    Color? color,
    VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color ?? AppTheme.textTertiary),
              if (count.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(count, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
              ],
            ],
          ),
        ),
      );

  Widget _buildInitialsAvatar() {
    final name = widget.post.authorUsername ?? 'User';
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';
    return Container(
      width: 40,
      height: 40,
      color: AppTheme.primaryColor.withOpacity(0.2),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 8) {
      return DateFormat('dd MMM yyyy').format(dateTime);
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}
