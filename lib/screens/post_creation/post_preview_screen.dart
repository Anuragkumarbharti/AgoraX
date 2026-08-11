import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../models/community/post_type.dart';
import '../../models/community/post_model.dart';
import '../../models/discovery/audio_track_model.dart';
import '../../services/post/post_upload_service.dart';
import '../../services/post/post_event_service.dart';
import '../../widgets/post_creation/music_picker_sheet.dart';

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
  late PostType _postType;
  late TextEditingController _captionCtrl;
  late List<String> _hashtags;
  File? _mediaFile;
  AudioTrack? _audioTrack;
  final TextEditingController _hashtagInputCtrl = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isPublishing = false;
  double _publishProgress = 0.0;
  String _statusText = 'Publishing your post...';
  String? _clientRequestId;

  @override
  void initState() {
    super.initState();
    _postType = widget.postType;
    _captionCtrl = TextEditingController(text: widget.caption);
    _hashtags = List.from(widget.hashtags);
    _mediaFile = widget.mediaFile;
    _audioTrack = widget.audioTrack;
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _hashtagInputCtrl.dispose();
    super.dispose();
  }

  String get _currentUserName {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.userMetadata?['username'] ?? user?.userMetadata?['full_name'] ?? 'Anurag Kumar';
  }

  String get _currentUserAvatar {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.userMetadata?['avatar_url'] ?? user?.userMetadata?['profile_photo'] ?? '';
  }

  Future<void> _pickOrChangeMedia() async {
    try {
      if (_postType == PostType.video || _postType == PostType.reel) {
        final picked = await _imagePicker.pickVideo(source: ImageSource.gallery);
        if (picked != null) {
          setState(() {
            _mediaFile = File(picked.path);
          });
        }
      } else {
        final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
        if (picked != null) {
          setState(() {
            _mediaFile = File(picked.path);
            if (_postType == PostType.text) {
              _postType = PostType.photo;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error changing media: $e');
    }
  }

  void _openMusicPicker() async {
    final track = await MusicPickerSheet.show(context, initialTrack: _audioTrack);
    if (track != null) {
      setState(() {
        _audioTrack = track;
      });
    }
  }

  void _addHashtagPrompt() {
    Get.dialog(
      AlertDialog(
        backgroundColor: context.dialogBackgroundColor,
        title: Text('Add Hashtag', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: _hashtagInputCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. #flutter, #ai, #creania',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              var text = _hashtagInputCtrl.text.trim();
              if (text.isNotEmpty) {
                if (!text.startsWith('#')) text = '#$text';
                text = text.replaceAll(' ', '_');
                if (!_hashtags.contains(text) && _hashtags.length < 10) {
                  setState(() {
                    _hashtags.add(text);
                  });
                }
              }
              _hashtagInputCtrl.clear();
              Get.back();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _insertMention() {
    final currentText = _captionCtrl.text;
    final newText = currentText.isEmpty ? '@' : '$currentText @';
    _captionCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    setState(() {});
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
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _publishProgress = 0.45;
        _statusText = 'Uploading media asset...';
      });

      final createdPost = await PostUploadService.instance.createAndReturnPost(
        postType: _postType,
        caption: _captionCtrl.text.trim(),
        hashtags: _hashtags,
        communityId: widget.communityId,
        visibility: widget.visibility,
        mediaFile: _mediaFile,
        audioTrackId: _audioTrack?.id,
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

        await Future.delayed(const Duration(milliseconds: 250));

        // 1. Broadcast PostCreated event to insert at TOP (index 0) of caller feed & show Instagram mini confirmation toast
        PostEventService.to.notifyPostCreated(createdPost);

        // 2. Auto-Back to original caller context (pops Preview screen AND CreatePost screen safely)
        if (mounted) {
          final nav = Navigator.of(context);
          if (nav.canPop()) nav.pop();
          if (nav.canPop()) nav.pop();
        }
      } else {
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
      backgroundColor: isDark ? const Color(0xFF0F0F17) : Colors.white,
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
          // Main Preview Screen matching Image 2 Layout
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Media Preview Card with Rounded Corners (Matching Image 2)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 220, maxHeight: 380),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A28) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_mediaFile != null && _mediaFile!.existsSync())
                          Image.file(
                            _mediaFile!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          )
                        else
                          _buildTypeFallbackGraphic(context, isDark),

                        // Overlay action bar (Change Photo & Add Photo buttons)
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _pickOrChangeMedia,
                                icon: Icon(_mediaFile != null ? Icons.photo_library_rounded : Icons.add_a_photo_rounded, size: 16),
                                label: Text(_mediaFile != null ? 'Change Photo' : 'Add Photo'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black.withOpacity(0.7),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  textStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (_mediaFile != null) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => setState(() => _mediaFile = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Caption Input Area ("Write a caption...")
                TextField(
                  controller: _captionCtrl,
                  maxLines: 3,
                  minLines: 1,
                  style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Write a caption...',
                    hintStyle: GoogleFonts.poppins(color: context.caption, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                // 3. Quick Action Buttons Row (# Hashtags, @ Mention) matching Image 2
                Row(
                  children: [
                    InkWell(
                      onTap: _addHashtagPrompt,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          children: [
                            const Text('#', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              'Hashtags',
                              style: GoogleFonts.poppins(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: _insertMention,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          children: [
                            const Text('@', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              'Mention',
                              style: GoogleFonts.poppins(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 4. Music Selector Row ("♫ Add Music" / Selected Track) matching Image 2
                InkWell(
                  onTap: _openMusicPicker,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.music_note_rounded,
                          color: _audioTrack != null ? AppTheme.primaryColor : AppTheme.primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _audioTrack != null ? '${_audioTrack!.title} • ${_audioTrack!.artist}' : 'Add Music',
                          style: GoogleFonts.poppins(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        if (_audioTrack != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _audioTrack = null),
                            child: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Display Active Hashtags Pills if added
                if (_hashtags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _hashtags.map((h) {
                      return Chip(
                        label: Text(h, style: GoogleFonts.inter(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                        deleteIcon: const Icon(Icons.close, size: 12, color: AppTheme.primaryColor),
                        onDeleted: () => setState(() => _hashtags.remove(h)),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Section Title: Live Instagram Feed Preview
                Text(
                  'FEED PREVIEW',
                  style: GoogleFonts.outfit(
                    color: context.caption,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),

                // Live Feed Card Mockup Preview
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
                      // Author Header
                      Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                              backgroundImage: _currentUserAvatar.isNotEmpty ? NetworkImage(_currentUserAvatar) : null,
                              child: _currentUserAvatar.isEmpty
                                  ? const Icon(Icons.person, color: AppTheme.primaryColor, size: 18)
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

                      // Feed Media
                      if (_mediaFile != null && _mediaFile!.existsSync())
                        Image.file(_mediaFile!, width: double.infinity, fit: BoxFit.cover),

                      // Feed Actions Row
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

                      // Feed Caption & Tags
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
                                    text: _captionCtrl.text,
                                    style: GoogleFonts.poppins(
                                      color: context.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_hashtags.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _hashtags.join(' '),
                                style: GoogleFonts.inter(color: const Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                            if (_audioTrack != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.music_note, size: 14, color: AppTheme.primaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_audioTrack!.title} • ${_audioTrack!.artist}',
                                    style: GoogleFonts.inter(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11),
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
                const SizedBox(height: 100),
              ],
            ),
          ),

          // Bottom Sticky "Post Now" Button
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

  Widget _buildTypeFallbackGraphic(BuildContext context, bool isDark) {
    if (_postType == PostType.mcq && widget.mcqData != null) {
      final mcq = widget.mcqData!;
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('☑', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mcq.question,
                    style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...mcq.options.map((opt) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF222234) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(opt.text, style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 12)),
              );
            }).toList(),
          ],
        ),
      );
    }

    if (_postType == PostType.poll && widget.pollData != null) {
      final poll = widget.pollData!;
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📊', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    poll.question,
                    style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...poll.options.map((opt) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF222234) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(opt.text, style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 12)),
              );
            }).toList(),
          ],
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(_postType.icon, size: 48, color: AppTheme.primaryColor),
        const SizedBox(height: 8),
        Text(
          'Select or Add Media for ${_postType.displayName}',
          style: GoogleFonts.poppins(color: context.caption, fontSize: 13),
        ),
      ],
    );
  }
}
