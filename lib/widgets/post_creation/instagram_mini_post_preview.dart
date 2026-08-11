import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/community/post_model.dart';
import '../../models/community/post_type.dart';
import '../common/optimized_image.dart';

class InstagramMiniPostPreview extends StatefulWidget {
  final Post post;
  final VoidCallback onDismiss;

  const InstagramMiniPostPreview({
    Key? key,
    required this.post,
    required this.onDismiss,
  }) : super(key: key);

  static OverlayEntry? _activeOverlay;

  static void show({BuildContext? context, required Post post}) {
    final targetContext = context ?? Get.overlayContext ?? Get.context;
    if (targetContext == null) return;
    
    // Remove existing overlay if present
    try {
      _activeOverlay?.remove();
    } catch (_) {}
    _activeOverlay = null;

    OverlayState? overlayState;
    try {
      overlayState = Overlay.maybeOf(targetContext, rootOverlay: true) ?? Overlay.maybeOf(targetContext);
    } catch (_) {}

    if (overlayState == null) {
      // Fallback display if Overlay context not in tree
      Get.snackbar(
        '✓ Post shared successfully!',
        post.caption.isNotEmpty ? post.caption : 'Your post is live.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1F2937),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(12),
        borderRadius: 16,
      );
      return;
    }

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        bottom: MediaQuery.of(ctx).padding.bottom + 70,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: InstagramMiniPostPreview(
            post: post,
            onDismiss: () {
              try {
                overlayEntry.remove();
              } catch (_) {}
              _activeOverlay = null;
            },
          ),
        ),
      ),
    );

    _activeOverlay = overlayEntry;
    overlayState.insert(overlayEntry);
  }

  @override
  State<InstagramMiniPostPreview> createState() => _InstagramMiniPostPreviewState();
}

class _InstagramMiniPostPreviewState extends State<InstagramMiniPostPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));

    _animController.forward();

    // Auto dismiss after 2.8 seconds
    _dismissTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) {
        _animController.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  String _getHumanSuccessText(PostType type) {
    switch (type) {
      case PostType.reel:
        return '✓ Reel shared successfully!';
      case PostType.video:
        return '✓ Video published!';
      case PostType.question:
        return '✓ Question posted!';
      case PostType.mcq:
        return '✓ Quiz published!';
      case PostType.poll:
        return '✓ Poll published!';
      case PostType.pdf:
        return '✓ Document posted!';
      case PostType.audio:
        return '✓ Audio published!';
      default:
        return '✓ Post shared successfully!';
    }
  }

  Widget _buildMediaThumbnail(BuildContext context) {
    final post = widget.post;
    final thumb = post.thumbnailUrl.isNotEmpty ? post.thumbnailUrl : post.mediaUrl;

    if (thumb.isNotEmpty && (post.postType == PostType.photo || post.postType == PostType.video || post.postType == PostType.reel)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 44,
          height: 44,
          child: OptimizedImage(
            imageUrl: thumb,
            quality: ImageQuality.thumbnail,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Icon fallback for types without image thumbnails
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: post.postType.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: post.postType.color.withOpacity(0.4)),
      ),
      child: Center(
        child: Text(
          post.postType.emoji,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final post = widget.post;
    final successLabel = _getHumanSuccessText(post.postType);

    // Extract hashtags from caption or post
    final hashtags = RegExp(r'#\w+')
        .allMatches(post.caption)
        .map((m) => m.group(0)!)
        .take(3)
        .join(' ');

    final cleanCaption = post.caption.replaceAll(RegExp(r'#\w+'), '').trim();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dismissible(
          key: UniqueKey(),
          direction: DismissDirection.horizontal,
          onDismissed: (_) => widget.onDismiss(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Green Success Badge / Checkmark
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),

                // Main Info Column
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Human status message
                      Text(
                        successLabel,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Caption preview (1-2 lines)
                      if (cleanCaption.isNotEmpty)
                        Text(
                          cleanCaption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                      // Hashtags
                      if (hashtags.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          hashtags,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF60A5FA),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Media Thumbnail Preview
                _buildMediaThumbnail(context),

                const SizedBox(width: 4),
                // Close button
                GestureDetector(
                  onTap: () {
                    _animController.reverse().then((_) {
                      widget.onDismiss();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withOpacity(0.6),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
