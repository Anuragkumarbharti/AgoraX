import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../models/community/post_model.dart';
import '../../models/community/post_type.dart';
import '../../models/discovery/unified_content_model.dart';
import '../../models/discovery/audio_track_model.dart';
import '../../services/post/post_repository.dart';
import '../../services/discovery/discovery_service.dart';
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
  final dynamic post; // Post or UnifiedContentItem
  final VoidCallback? onTap;
  final Function(String tag)? onHashtagTap;
  final Function(AudioTrack? audioTrack)? onAudioTap;

  const PostCard({
    Key? key,
    required this.post,
    this.onTap,
    this.onHashtagTap,
    this.onAudioTap,
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

  final DiscoveryService _discoveryService = Get.put(DiscoveryService());

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    if (p is UnifiedContentItem) {
      _isLiked = p.isLiked;
      _likes = p.likes;
      _isBookmarked = p.isSaved;
      _comments = p.comments;
      _shares = p.shares;
    } else if (p is Post) {
      _isLiked = p.isLiked;
      _likes = p.likes;
      _isBookmarked = p.isBookmarked;
      _comments = p.comments;
      _shares = p.shares;
    } else {
      _isLiked = false;
      _likes = 0;
      _isBookmarked = false;
      _comments = 0;
      _shares = 0;
    }
  }

  String get _postId => widget.post.id?.toString() ?? '';
  String get _creatorId => widget.post.userId?.toString() ?? '';
  String get _caption => widget.post.caption?.toString() ?? '';
  String get _authorUsername => (widget.post is UnifiedContentItem) ? widget.post.authorName : (widget.post.authorUsername ?? 'Creania User');
  String get _authorAvatarUrl => (widget.post is UnifiedContentItem) ? widget.post.authorAvatarUrl : (widget.post.authorAvatarUrl ?? '');
  PostType get _postType => (widget.post is UnifiedContentItem) ? widget.post.postType : (widget.post is Post ? widget.post.postType : PostType.text);
  DateTime get _createdAt => widget.post.createdAt ?? DateTime.now();
  AudioTrack? get _audioTrack => (widget.post is UnifiedContentItem) ? widget.post.audioTrack : null;

  Future<void> _handleLike() async {
    final prevLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likes = _isLiked ? _likes + 1 : _likes - 1;
    });
    await PostRepository.toggleLike(_postId, prevLiked);
  }

  Future<void> _handleBookmark() async {
    final prevBookmarked = _isBookmarked;
    setState(() {
      _isBookmarked = !_isBookmarked;
    });

    _discoveryService.toggleSavePost(_postId, prevBookmarked);
    Get.snackbar(
      _isBookmarked ? 'Bookmarked 📚' : 'Bookmark Removed 🗑️',
      _isBookmarked ? 'Post added to your saved posts.' : 'Post removed from saved posts.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
    );
  }

  void _handleShare() {
    Share.share('Check out this post on Creania!\n$_caption');
  }

  void _handleNotInterested() {
    _discoveryService.submitFeedFeedback(postId: _postId, creatorId: _creatorId, feedbackType: 'not_interested');
    Get.snackbar('Not Interested', 'We will show fewer posts like this.', snackPosition: SnackPosition.BOTTOM);
  }

  void _handleMuteCreator() {
    _discoveryService.submitFeedFeedback(postId: _postId, creatorId: _creatorId, feedbackType: 'mute_creator');
    Get.snackbar('Creator Muted', 'Posts from $_authorUsername will be hidden.', snackPosition: SnackPosition.BOTTOM);
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
              await _discoveryService.submitFeedFeedback(postId: _postId, creatorId: _creatorId, feedbackType: 'report', reason: 'Spam/Inappropriate');
              Get.snackbar('Report Submitted', 'Thank you for keeping Creania safe.', snackPosition: SnackPosition.BOTTOM);
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
    final formattedTime = DateFormat.yMMMd().add_jm().format(_createdAt);

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
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: _authorAvatarUrl.isNotEmpty
                      ? OptimizedImage(
                          imageUrl: _authorAvatarUrl,
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

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _authorUsername,
                          style: GoogleFonts.poppins(
                            color: context.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _postType.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_postType.emoji} ${_postType.displayName}',
                            style: TextStyle(
                              color: _postType.color,
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

              // Options Menu
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'bookmark') _handleBookmark();
                  if (val == 'share') _handleShare();
                  if (val == 'not_interested') _handleNotInterested();
                  if (val == 'mute') _handleMuteCreator();
                  if (val == 'report') _handleReport();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'bookmark', child: Text(_isBookmarked ? '🔖 Remove Bookmark' : '🔖 Save Post')),
                  const PopupMenuItem(value: 'share', child: Text('🔗 Share Post')),
                  const PopupMenuItem(value: 'not_interested', child: Text('👎 Not Interested')),
                  PopupMenuItem(value: 'mute', child: Text('🔇 Mute @$_authorUsername')),
                  const PopupMenuItem(value: 'report', child: Text('🚩 Report Post', style: TextStyle(color: Colors.red))),
                ],
                child: Icon(Icons.more_horiz_rounded, color: context.caption, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Caption Text with Clickable Tags
          if (_caption.isNotEmpty && _postType != PostType.mcq && _postType != PostType.poll && _postType != PostType.question) ...[
            RichText(
              text: TextSpan(
                children: _buildInteractiveCaptionSpans(_caption),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Attached Audio Pill if present
          if (_audioTrack != null) ...[
            GestureDetector(
              onTap: () => widget.onAudioTap?.call(_audioTrack),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.music_note, color: AppTheme.primaryColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${_audioTrack!.title} • ${_audioTrack!.artist}',
                      style: GoogleFonts.inter(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Type-Specific Content
          if (widget.post is Post)
            _buildSpecializedFeedContent(context, widget.post as Post),

          const SizedBox(height: 12),

          // Action Buttons Bar (Like, Comment, Share, Bookmark)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
                      Text('$_likes', style: GoogleFonts.poppins(color: _isLiked ? Colors.redAccent : context.caption, fontSize: 12)),
                    ],
                  ),
                ),
              ),

              InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, color: context.caption, size: 18),
                      const SizedBox(width: 4),
                      Text('$_comments', style: GoogleFonts.poppins(color: context.caption, fontSize: 12)),
                    ],
                  ),
                ),
              ),

              InkWell(
                onTap: _handleShare,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, color: context.caption, size: 18),
                      const SizedBox(width: 4),
                      Text('$_shares', style: GoogleFonts.poppins(color: context.caption, fontSize: 12)),
                    ],
                  ),
                ),
              ),

              IconButton(
                icon: Icon(_isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: _isBookmarked ? context.primaryColor : context.caption, size: 20),
                onPressed: _handleBookmark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<TextSpan> _buildInteractiveCaptionSpans(String text) {
    final List<TextSpan> spans = [];
    final words = text.split(RegExp(r'(\s+)'));

    for (var word in words) {
      if (word.startsWith('#')) {
        spans.add(
          TextSpan(
            text: word,
            style: GoogleFonts.inter(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        );
      } else if (word.startsWith('@')) {
        spans.add(
          TextSpan(
            text: word,
            style: GoogleFonts.inter(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: word,
            style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
          ),
        );
      }
    }
    return spans;
  }

  Widget _buildSpecializedFeedContent(BuildContext context, Post post) {
    switch (post.postType) {
      case PostType.photo: return FeedPhotoWidget(post: post);
      case PostType.video:
      case PostType.reel: return FeedVideoWidget(post: post);
      case PostType.audio: return FeedAudioWidget(post: post);
      case PostType.pdf: return FeedPdfWidget(post: post);
      case PostType.question: return FeedQuestionWidget(post: post);
      case PostType.mcq: return FeedMcqWidget(post: post);
      case PostType.poll: return FeedPollWidget(post: post);
      case PostType.link: return FeedLinkWidget(post: post);
      default:
        return PostAttachmentsWidget(post: post);
    }
  }
}
