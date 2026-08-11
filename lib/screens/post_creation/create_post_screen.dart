import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../models/community/post_model.dart';
import '../../models/community/post_type.dart';
import '../../services/post/post_upload_service.dart';

class CreatePostScreen extends StatefulWidget {
  final PostType initialType;
  final String? initialCommunityId;

  const CreatePostScreen({
    Key? key,
    this.initialType = PostType.text,
    this.initialCommunityId,
  }) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  late PostType _selectedType;
  final TextEditingController _captionCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _contextCtrl = TextEditingController();
  final TextEditingController _explanationCtrl = TextEditingController();
  final TextEditingController _linkCtrl = TextEditingController();

  // Settings
  String _visibility = 'public';
  bool _commentsEnabled = true;
  bool _sharesEnabled = true;
  String? _selectedCommunityId;

  // Media state
  File? _pickedMediaFile;
  File? _pickedCoverFile;
  List<File> _pickedImages = [];
  String _pdfName = '';
  int _pdfSize = 0;

  // MCQ state
  final TextEditingController _mcqQuestionCtrl = TextEditingController();
  final List<TextEditingController> _mcqOptionCtrls = [
    TextEditingController(text: 'Option A'),
    TextEditingController(text: 'Option B'),
    TextEditingController(text: 'Option C'),
    TextEditingController(text: 'Option D'),
  ];
  int _mcqCorrectIndex = 0;
  int _mcqXpReward = 10;

  // Poll state
  final TextEditingController _pollQuestionCtrl = TextEditingController();
  final List<TextEditingController> _pollOptionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];
  int _pollDurationHours = 24;

  final PostUploadService _uploadService = Get.put(PostUploadService());

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _selectedCommunityId = widget.initialCommunityId;
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _titleCtrl.dispose();
    _contextCtrl.dispose();
    _explanationCtrl.dispose();
    _linkCtrl.dispose();
    _mcqQuestionCtrl.dispose();
    for (var c in _mcqOptionCtrls) {
      c.dispose();
    }
    _pollQuestionCtrl.dispose();
    for (var c in _pollOptionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedMediaFile = File(image.path);
        _pickedImages = [_pickedMediaFile!];
      });
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _pickedMediaFile = File(video.path);
      });
    }
  }

  Future<void> _handlePublish() async {
    final captionText = _captionCtrl.text.trim();

    if (_selectedType == PostType.text && captionText.isEmpty) {
      Get.snackbar('Empty Post', 'Please enter some text for your post.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    McqData? mcqData;
    if (_selectedType == PostType.mcq) {
      if (_mcqQuestionCtrl.text.trim().isEmpty) {
        Get.snackbar('Missing Question', 'Please enter your quiz question.',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      final options = _mcqOptionCtrls.asMap().entries.map((e) {
        return McqOption(
          id: 'opt_${e.key}',
          text: e.value.text.trim().isEmpty ? 'Option ${e.key + 1}' : e.value.text.trim(),
          isCorrect: e.key == _mcqCorrectIndex,
        );
      }).toList();

      mcqData = McqData(
        question: _mcqQuestionCtrl.text.trim(),
        options: options,
        explanation: _explanationCtrl.text.trim(),
        xpReward: _mcqXpReward,
      );
    }

    PollData? pollData;
    if (_selectedType == PostType.poll) {
      if (_pollQuestionCtrl.text.trim().isEmpty) {
        Get.snackbar('Missing Question', 'Please enter your poll question.',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      final options = _pollOptionCtrls.asMap().entries.map((e) {
        return PollOption(
          id: 'opt_${e.key}',
          text: e.value.text.trim().isEmpty ? 'Option ${e.key + 1}' : e.value.text.trim(),
        );
      }).toList();

      pollData = PollData(
        question: _pollQuestionCtrl.text.trim(),
        options: options,
        durationHours: _pollDurationHours,
      );
    }

    QuestionData? questionData;
    if (_selectedType == PostType.question) {
      if (_captionCtrl.text.trim().isEmpty) {
        Get.snackbar('Missing Question', 'Please enter your question.',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      questionData = QuestionData(
        question: _captionCtrl.text.trim(),
        context: _contextCtrl.text.trim(),
      );
    }

    final success = await _uploadService.createPost(
      postType: _selectedType,
      caption: captionText.isNotEmpty ? captionText : (_titleCtrl.text.isNotEmpty ? _titleCtrl.text : 'New ${_selectedType.displayName} Post'),
      communityId: _selectedCommunityId,
      visibility: _visibility,
      commentsEnabled: _commentsEnabled,
      sharesEnabled: _sharesEnabled,
      mediaFile: _pickedMediaFile,
      coverFile: _pickedCoverFile,
      mcqData: mcqData,
      pollData: pollData,
      questionData: questionData,
    );

    if (success) {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.scaffoldBackgroundColor.withOpacity(0.85),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: context.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Post',
          style: GoogleFonts.outfit(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          // Visibility Selector Pill
          _buildVisibilityPill(context),
          const SizedBox(width: 8),

          // Settings Cog Button
          IconButton(
            icon: Icon(Icons.settings_outlined, color: context.textPrimary, size: 20),
            onPressed: () => _showSettingsDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Upload Progress Bar if active
            Obx(() {
              final state = _uploadService.uploadState.value;
              if (!state.isUploading) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: context.primaryColor.withOpacity(0.15),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(context.primaryColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.statusText,
                        style: GoogleFonts.poppins(
                          color: context.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${(state.progress * 100).round()}%',
                      style: GoogleFonts.outfit(
                        color: context.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Horizontal Post Type Selector Tabs
            _buildTypeSelectorTabs(context),
            const Divider(height: 1, thickness: 0.5),

            // Active Type Editor Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Caption / Description Field (Common to all)
                    if (_selectedType != PostType.mcq && _selectedType != PostType.poll) ...[
                      TextField(
                        controller: _captionCtrl,
                        maxLines: _selectedType == PostType.text ? 6 : 3,
                        style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _getHintForType(_selectedType),
                          hintStyle: GoogleFonts.poppins(color: context.caption, fontSize: 14),
                          border: InputBorder.none,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Contextual Editor View
                    _buildTypeSpecificEditor(context),
                  ],
                ),
              ),
            ),

            // Bottom Publish Action Bar
            _buildBottomActionBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityPill(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (val) => setState(() => _visibility = val),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'public', child: Text('🌐 Public')),
        const PopupMenuItem(value: 'followers', child: Text('👥 Followers')),
        const PopupMenuItem(value: 'private', child: Text('🔒 Only Me')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: context.primaryColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.primaryColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Text(
              _visibility == 'public'
                  ? '🌐 Public'
                  : (_visibility == 'followers' ? '👥 Followers' : '🔒 Private'),
              style: GoogleFonts.poppins(
                color: context.primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: context.primaryColor, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelectorTabs(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: PostType.values.length,
        itemBuilder: (context, idx) {
          final type = PostType.values[idx];
          final isSelected = type == _selectedType;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedType = type),
              avatar: Text(type.emoji, style: const TextStyle(fontSize: 12)),
              label: Text(
                type.displayName,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : context.textPrimary,
                ),
              ),
              selectedColor: type.color,
              backgroundColor: isDark ? const Color(0xFF1F1F2E) : Colors.grey.shade200,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeSpecificEditor(BuildContext context) {
    switch (_selectedType) {
      case PostType.photo:
        return _buildPhotoEditor(context);
      case PostType.video:
        return _buildVideoEditor(context);
      case PostType.audio:
        return _buildAudioEditor(context);
      case PostType.pdf:
        return _buildPdfEditor(context);
      case PostType.question:
        return _buildQuestionEditor(context);
      case PostType.mcq:
        return _buildMcqEditor(context);
      case PostType.poll:
        return _buildPollEditor(context);
      case PostType.link:
        return _buildLinkEditor(context);
      case PostType.text:
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPhotoEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pickedMediaFile != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Image.file(_pickedMediaFile!, height: 220, width: double.infinity, fit: BoxFit.cover),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: () => setState(() => _pickedMediaFile = null),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: Icon(Icons.add_photo_alternate_rounded, color: context.primaryColor),
          label: Text(
            _pickedMediaFile == null ? 'Select Photo(s)' : 'Change Photo',
            style: GoogleFonts.poppins(color: context.primaryColor, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: context.primaryColor.withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pickedMediaFile != null) ...[
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.video_collection_rounded, color: context.primaryColor, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    _pickedMediaFile!.path.split('/').last,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _pickVideo,
          icon: Icon(Icons.video_library_rounded, color: PostType.video.color),
          label: Text(
            _pickedMediaFile == null ? 'Select Video' : 'Change Video',
            style: GoogleFonts.poppins(color: PostType.video.color, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: PostType.video.color.withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleCtrl,
          style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Audio Title / Episode Name...',
            hintStyle: GoogleFonts.poppins(color: context.caption, fontSize: 14),
            filled: true,
            fillColor: context.secondaryBackgroundColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: Icon(Icons.audiotrack_rounded, color: PostType.audio.color),
          label: Text(
            _pickedMediaFile == null ? 'Upload Audio File' : 'Audio File Selected ✓',
            style: GoogleFonts.poppins(color: PostType.audio.color, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: PostType.audio.color.withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildPdfEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PostType.pdf.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PostType.pdf.color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: PostType.pdf.color, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pdfName.isNotEmpty ? _pdfName : 'Academic_Notes_2026.pdf',
                      style: GoogleFonts.poppins(color: context.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      '1st Page Preview Auto-Generated',
                      style: GoogleFonts.poppins(color: context.caption, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PostType.pdf.color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Browse', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _contextCtrl,
          maxLines: 3,
          style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Additional context or code snippet (optional)...',
            hintStyle: GoogleFonts.poppins(color: context.caption, fontSize: 13),
            filled: true,
            fillColor: context.secondaryBackgroundColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildMcqEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUESTION',
          style: GoogleFonts.outfit(color: PostType.mcq.color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _mcqQuestionCtrl,
          maxLines: 2,
          style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Enter quiz question...',
            hintStyle: GoogleFonts.poppins(color: context.caption, fontSize: 14),
            filled: true,
            fillColor: context.secondaryBackgroundColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'OPTIONS (Select the correct answer)',
          style: GoogleFonts.outfit(color: context.caption, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.1),
        ),
        const SizedBox(height: 8),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _mcqOptionCtrls.length,
          itemBuilder: (context, idx) {
            final isCorrect = idx == _mcqCorrectIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Radio<int>(
                    value: idx,
                    groupValue: _mcqCorrectIndex,
                    activeColor: PostType.mcq.color,
                    onChanged: (val) => setState(() => _mcqCorrectIndex = val!),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _mcqOptionCtrls[idx],
                      style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Option ${String.fromCharCode(65 + idx)}',
                        filled: true,
                        fillColor: isCorrect ? PostType.mcq.color.withOpacity(0.12) : context.secondaryBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 12),
        TextField(
          controller: _explanationCtrl,
          maxLines: 2,
          style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Explanation (revealed after user answers)...',
            hintStyle: GoogleFonts.poppins(color: context.caption, fontSize: 12),
            filled: true,
            fillColor: context.secondaryBackgroundColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildPollEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'POLL QUESTION',
          style: GoogleFonts.outfit(color: PostType.poll.color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _pollQuestionCtrl,
          maxLines: 2,
          style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Ask your question...',
            hintStyle: GoogleFonts.poppins(color: context.caption, fontSize: 14),
            filled: true,
            fillColor: context.secondaryBackgroundColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 14),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _pollOptionCtrls.length,
          itemBuilder: (context, idx) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _pollOptionCtrls[idx],
                style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Choice ${idx + 1}',
                  filled: true,
                  fillColor: context.secondaryBackgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            );
          },
        ),

        if (_pollOptionCtrls.length < 6)
          TextButton.icon(
            onPressed: () => setState(() => _pollOptionCtrls.add(TextEditingController())),
            icon: Icon(Icons.add_rounded, color: PostType.poll.color, size: 18),
            label: Text('Add Option', style: GoogleFonts.poppins(color: PostType.poll.color, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildLinkEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _linkCtrl,
          style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Paste web URL (https://...)',
            hintStyle: GoogleFonts.poppins(color: context.caption, fontSize: 13),
            prefixIcon: Icon(Icons.link_rounded, color: PostType.link.color),
            filled: true,
            fillColor: context.secondaryBackgroundColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13131A) : Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.local_offer_outlined, color: context.caption, size: 20),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.alternate_email_rounded, color: context.caption, size: 20),
            onPressed: () {},
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _handlePublish,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Publish',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _getHintForType(PostType type) {
    switch (type) {
      case PostType.photo:
        return 'Write a caption for your photo...';
      case PostType.video:
        return 'Write a caption for your video...';
      case PostType.audio:
        return 'Write audio description...';
      case PostType.pdf:
        return 'Describe this document...';
      case PostType.question:
        return 'Ask your question here...';
      case PostType.link:
        return 'Say something about this link...';
      case PostType.text:
      default:
        return "What's on your mind?";
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.dialogBackgroundColor,
          title: Text('Post Settings', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text('Allow Comments', style: GoogleFonts.poppins(fontSize: 13)),
                value: _commentsEnabled,
                activeColor: context.primaryColor,
                onChanged: (val) {
                  setDialogState(() => _commentsEnabled = val);
                  setState(() => _commentsEnabled = val);
                },
              ),
              SwitchListTile(
                title: Text('Allow Shares', style: GoogleFonts.poppins(fontSize: 13)),
                value: _sharesEnabled,
                activeColor: context.primaryColor,
                onChanged: (val) {
                  setDialogState(() => _sharesEnabled = val);
                  setState(() => _sharesEnabled = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
