import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../models/community/post_type.dart';
import '../../models/community/post_model.dart';
import '../../models/discovery/audio_track_model.dart';
import '../../services/post/post_upload_service.dart';
import '../../services/post/post_event_service.dart';

class PostPreviewScreen extends StatefulWidget {
  final PostType postType;
  final String caption;
  final List<String> hashtags;
  final File? mediaFile;
  final AudioTrack? audioTrack;
  final String? communityId;
  final String visibility;
  final McqData? mcqData;
  final PollData? pollData;
  final QuestionData? questionData;

  const PostPreviewScreen({
    Key? key,
    required this.postType,
    required this.caption,
    this.hashtags = const [],
    this.mediaFile,
    this.audioTrack,
    this.communityId,
    this.visibility = 'public',
    this.mcqData,
    this.pollData,
    this.questionData,
  }) : super(key: key);

  @override
  State<PostPreviewScreen> createState() => _PostPreviewScreenState();
}

class _PostPreviewScreenState extends State<PostPreviewScreen> {
  bool _isPublishing = false;
  double _publishProgress = 0.0;
  String _statusText = 'Publishing your post...';
  String? _clientRequestId;

  String get _currentUserName {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.userMetadata?['username'] ?? user?.userMetadata?['full_name'] ?? 'Anurag Kumar';
  }

  String get _currentUserAvatar {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.userMetadata?['avatar_url'] ?? user?.userMetadata?['profile_photo'] ?? '';
  }

  Future<void> _publishPost() async {
    if (_isPublishing) return; // Prevent duplicate taps

    setState(() {
      _isPublishing = true;
      _publishProgress = 0.15;
      _statusText = 'Processing media & attachments...';
      _clientRequestId = 'req_${DateTime.now().millisecondsSinceEpoch}';
    });

    try {
      // 1. Progress simulation updates
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _publishProgress = 0.45;
        _statusText = 'Uploading media asset...';
      });

      // 2. Call upload service
      final createdPost = await PostUploadService.instance.createAndReturnPost(
        postType: widget.postType,
        caption: widget.caption,
        hashtags: widget.hashtags,
        communityId: widget.communityId,
        visibility: widget.visibility,
        mediaFile: widget.mediaFile,
        audioTrackId: widget.audioTrack?.id,
        mcqData: widget.mcqData,
        pollData: widget.pollData,
        questionData: widget.questionData,
        clientRequestId: _clientRequestId,
      );

      if (!mounted) return;

      if (createdPost != null) {
        setState(() {
          _publishProgress = 1.0;
          _statusText = 'Post published successfully!';
        });

        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;

        // Auto-Back to original caller context (pops Preview screen AND CreatePost screen)
        // First pop Preview, then pop Composer
        final navigator = Navigator.of(context);
        navigator.pop(); // Pop preview
        navigator.pop(); // Pop composer back to caller screen (Home/Community/Profile)

        // Broadcast PostCreated event to insert at TOP (index 0) of caller feed & show Instagram mini confirmation toast
        PostEventService.to.notifyPostCreated(createdPost, context: Get.context);
      } else {
        // Failed on backend
        setState(() {
          _isPublishing = false;
          _publishProgress = 0.0;
        });

        Get.snackbar(
          'Upload Error',
          "Couldn't publish your post. Please try again.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      debugPrint('Error publishing post: $e');
      if (!mounted) return;
      setState(() {
        _isPublishing = false;
        _publishProgress = 0.0;
      });

      Get.snackbar(
        'Upload Error',
        "Couldn't publish your post. Please try again.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F17) : Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF161622) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 18),
          onPressed: _isPublishing ? null : () => Navigator.pop(context),
        ),
        title: Text(
          _isPublishing ? 'Creating Post...' : 'Preview',
          style: GoogleFonts.outfit(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (!_isPublishing)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Edit',
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Main Instagram-Style Preview Feed Card
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161622) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Author Header Bar
                      Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                              backgroundImage: _currentUserAvatar.isNotEmpty ? NetworkImage(_currentUserAvatar) : null,
                              child: _currentUserAvatar.isEmpty
                                  ? const Icon(Icons.person, color: AppTheme.primaryColor, size: 20)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentUserName,
                                    style: GoogleFonts.poppins(
                                      color: context.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Just now',
                                    style: GoogleFonts.poppins(
                                      color: context.caption,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.more_horiz_rounded, color: context.caption),
                          ],
                        ),
                      ),

                      // 2. Media Preview Display
                      _buildMediaPreviewArea(context, isDark),

                      // 3. Action Row (Like, Comment, Share, Bookmark)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.favorite_border_rounded, size: 22),
                            const SizedBox(width: 16),
                            const Icon(Icons.chat_bubble_outline_rounded, size: 22),
                            const SizedBox(width: 16),
                            const Icon(Icons.share_outlined, size: 22),
                            const Spacer(),
                            const Icon(Icons.bookmark_border_rounded, size: 22),
                          ],
                        ),
                      ),

                      // 4. Creator Caption & Hashtags Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '$_currentUserName ',
                                    style: GoogleFonts.poppins(
                                      color: context.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  TextSpan(
                                    text: widget.caption,
                                    style: GoogleFonts.poppins(
                                      color: context.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.hashtags.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: widget.hashtags.map((h) {
                                  return Text(
                                    h,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF3B82F6),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            if (widget.audioTrack != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.music_note, size: 14, color: AppTheme.primaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.audioTrack!.title} • ${widget.audioTrack!.artist}',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
                const SizedBox(height: 100), // Space for sticky button
              ],
            ),
          ),

          // Bottom Sticky "Post Now" Action Bar
          if (!_isPublishing)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).padding.bottom + 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161622) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _publishPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Post Now',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // Full-screen Publishing Progress Overlay ("Creating Post...")
          if (_isPublishing)
            Container(
              color: (isDark ? const Color(0xFF0F0F17) : Colors.white).withOpacity(0.95),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Flying Paper Airplane Animation Icon
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: AppTheme.primaryColor,
                          size: 54,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Publishing your post...',
                        style: GoogleFonts.outfit(
                          color: context.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please don\'t close the app.',
                        style: GoogleFonts.poppins(
                          color: context.caption,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Linear Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _publishProgress,
                          minHeight: 8,
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        '${(_publishProgress * 100).toInt()}% • $_statusText',
                        style: GoogleFonts.poppins(
                          color: context.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaPreviewArea(BuildContext context, bool isDark) {
    if (widget.mediaFile != null && widget.mediaFile!.existsSync()) {
      if (widget.postType == PostType.photo) {
        return Image.file(
          widget.mediaFile!,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      }
      return Container(
        height: 240,
        width: double.infinity,
        color: Colors.black87,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(widget.postType.icon, color: Colors.white70, size: 48),
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.64),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.postType.emoji} ${widget.postType.displayName}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.postType == PostType.mcq && widget.mcqData != null) {
      final mcq = widget.mcqData!;
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('☑', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mcq.question,
                    style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...mcq.options.map((opt) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF222234) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      opt.isCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: opt.isCorrect ? const Color(0xFF10B981) : context.caption,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      opt.text,
                      style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      );
    }

    if (widget.postType == PostType.poll && widget.pollData != null) {
      final poll = widget.pollData!;
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📊', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    poll.question,
                    style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...poll.options.map((opt) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF222234) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  opt.text,
                  style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
                ),
              );
            }).toList(),
          ],
        ),
      );
    }

    if (widget.postType == PostType.question && widget.questionData != null) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Text('❓', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.questionData!.question,
                style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
