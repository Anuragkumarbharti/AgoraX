import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../models/community/post_type.dart';
import '../../models/community/post_model.dart';
import '../../models/discovery/audio_track_model.dart';
import '../../widgets/post_creation/music_picker_sheet.dart';
import 'post_preview_screen.dart';

class CreatePostScreen extends StatefulWidget {
  final PostType initialType;
  final String? initialCommunityId;

  const CreatePostScreen({
    Key? key,
    this.initialType = PostType.photo,
    this.initialCommunityId,
  }) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  late PostType _selectedType;
  final TextEditingController _captionCtrl = TextEditingController();
  final TextEditingController _hashtagCtrl = TextEditingController();
  final List<String> _hashtags = [];
  AudioTrack? _selectedAudioTrack;
  File? _selectedMediaFile;
  String? _selectedMediaName;
  String _visibility = 'public';

  // MCQ Controllers
  final TextEditingController _mcqQuestionCtrl = TextEditingController();
  final List<TextEditingController> _mcqOptionCtrls = [
    TextEditingController(text: 'Option 1'),
    TextEditingController(text: 'Option 2'),
  ];
  int _mcqCorrectIndex = 0;
  int _mcqXpReward = 10;

  // Poll Controllers
  final TextEditingController _pollQuestionCtrl = TextEditingController();
  final List<TextEditingController> _pollOptionCtrls = [
    TextEditingController(text: 'Option A'),
    TextEditingController(text: 'Option B'),
  ];
  int _pollDurationHours = 24;

  // Question Controllers
  final TextEditingController _questionTitleCtrl = TextEditingController();
  final TextEditingController _questionContextCtrl = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _hashtagCtrl.dispose();
    _mcqQuestionCtrl.dispose();
    for (var c in _mcqOptionCtrls) {
      c.dispose();
    }
    _pollQuestionCtrl.dispose();
    for (var c in _pollOptionCtrls) {
      c.dispose();
    }
    _questionTitleCtrl.dispose();
    _questionContextCtrl.dispose();
    super.dispose();
  }

  void _addHashtag(String text) {
    var tag = text.trim();
    if (!tag.startsWith('#')) tag = '#$tag';
    tag = tag.replaceAll(' ', '_');
    if (tag.length > 1 && !_hashtags.contains(tag) && _hashtags.length < 10) {
      setState(() {
        _hashtags.add(tag);
        _hashtagCtrl.clear();
      });
    }
  }

  Future<void> _pickMedia() async {
    try {
      if (_selectedType == PostType.photo) {
        final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
        if (picked != null) {
          setState(() {
            _selectedMediaFile = File(picked.path);
            _selectedMediaName = picked.name;
          });
        }
      } else if (_selectedType == PostType.video || _selectedType == PostType.reel) {
        final picked = await _imagePicker.pickVideo(source: ImageSource.gallery);
        if (picked != null) {
          setState(() {
            _selectedMediaFile = File(picked.path);
            _selectedMediaName = picked.name;
          });
        }
      } else {
        // Fallback image picker for other attachment types
        final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
        if (picked != null) {
          setState(() {
            _selectedMediaFile = File(picked.path);
            _selectedMediaName = picked.name;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking media: $e');
    }
  }

  void _openMusicPicker() async {
    final track = await MusicPickerSheet.show(context, initialTrack: _selectedAudioTrack);
    if (track != null) {
      setState(() {
        _selectedAudioTrack = track;
      });
    }
  }

  void _navigateToPreview() {
    final captionText = _captionCtrl.text.trim();
    if (_selectedType == PostType.text && captionText.isEmpty) {
      Get.snackbar('Input Required', 'Please enter some text for your post.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (_selectedType == PostType.photo && _selectedMediaFile == null) {
      Get.snackbar('Image Required', 'Please select an image file to post.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if ((_selectedType == PostType.video || _selectedType == PostType.reel) && _selectedMediaFile == null) {
      Get.snackbar('Video Required', 'Please select a video file.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    McqData? mcqData;
    if (_selectedType == PostType.mcq) {
      if (_mcqQuestionCtrl.text.trim().isEmpty) {
        Get.snackbar('Question Required', 'Please enter a quiz question.', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      final opts = _mcqOptionCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
      if (opts.length < 2) {
        Get.snackbar('Options Required', 'Please provide at least 2 options.', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      mcqData = McqData(
        question: _mcqQuestionCtrl.text.trim(),
        options: List.generate(
          opts.length,
          (i) => McqOption(id: 'opt_$i', text: opts[i], isCorrect: i == _mcqCorrectIndex),
        ),
        xpReward: _mcqXpReward,
      );
    }

    PollData? pollData;
    if (_selectedType == PostType.poll) {
      if (_pollQuestionCtrl.text.trim().isEmpty) {
        Get.snackbar('Question Required', 'Please enter a poll question.', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      final opts = _pollOptionCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
      if (opts.length < 2) {
        Get.snackbar('Options Required', 'Please provide at least 2 options.', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      pollData = PollData(
        question: _pollQuestionCtrl.text.trim(),
        options: List.generate(
          opts.length,
          (i) => PollOption(id: 'poll_opt_$i', text: opts[i]),
        ),
        durationHours: _pollDurationHours,
      );
    }

    QuestionData? questionData;
    if (_selectedType == PostType.question) {
      if (_questionTitleCtrl.text.trim().isEmpty) {
        Get.snackbar('Question Required', 'Please enter your question.', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      questionData = QuestionData(
        question: _questionTitleCtrl.text.trim(),
        context: _questionContextCtrl.text.trim(),
      );
    }

    final extractedTags = RegExp(r'#\w+')
        .allMatches(captionText)
        .map((m) => m.group(0)!)
        .toList();
    final allHashtags = {..._hashtags, ...extractedTags}.toList();

    Get.to(
      () => PostPreviewScreen(
        postType: _selectedType,
        caption: captionText,
        hashtags: allHashtags,
        mediaFile: _selectedMediaFile,
        audioTrack: _selectedAudioTrack,
        communityId: widget.initialCommunityId,
        visibility: _visibility,
        mcqData: mcqData,
        pollData: pollData,
        questionData: questionData,
      ),
      transition: Transition.rightToLeft,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F17) : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF161622) : Colors.white,
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
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: ElevatedButton(
              onPressed: _navigateToPreview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: Text(
                'Next',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Post Type Selector Tabs
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: PostType.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final type = PostType.values[index];
                  final isSelected = type == _selectedType;

                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(type.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(
                          type.displayName.toUpperCase(),
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.white : context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryColor,
                    backgroundColor: isDark ? const Color(0xFF1F1F2E) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primaryColor : (isDark ? Colors.white12 : Colors.black12),
                      ),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedType = type;
                          _selectedMediaFile = null;
                          _selectedMediaName = null;
                        });
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 2. Main Content / Caption Input Area
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181824) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                ),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _captionCtrl,
                    maxLines: 6,
                    minLines: 4,
                    style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _getHintForType(_selectedType),
                      hintStyle: GoogleFonts.poppins(color: context.caption, fontSize: 13),
                      contentPadding: const EdgeInsets.all(16),
                      border: InputBorder.none,
                    ),
                  ),

                  // Media Preview Box inside card if selected
                  if (_selectedMediaFile != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _selectedType == PostType.photo
                                ? Image.file(
                                    _selectedMediaFile!,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    height: 100,
                                    width: double.infinity,
                                    color: AppTheme.primaryColor.withOpacity(0.12),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(_selectedType.icon, color: AppTheme.primaryColor, size: 32),
                                          const SizedBox(height: 6),
                                          Text(
                                            _selectedMediaName ?? 'Selected File',
                                            style: GoogleFonts.poppins(
                                              color: context.textPrimary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedMediaFile = null;
                                  _selectedMediaName = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.64),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Divider(height: 1),

                  // Actions row (Hashtags counter & Add Music)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Hashtags: ${_hashtags.length} / 10',
                          style: GoogleFonts.poppins(color: context.caption, fontSize: 12),
                        ),
                        InkWell(
                          onTap: _openMusicPicker,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.music_note_rounded,
                                  color: _selectedAudioTrack != null ? AppTheme.primaryColor : context.caption,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _selectedAudioTrack != null ? _selectedAudioTrack!.title : 'Add Music',
                                  style: GoogleFonts.poppins(
                                    color: _selectedAudioTrack != null ? AppTheme.primaryColor : context.caption,
                                    fontSize: 12,
                                    fontWeight: _selectedAudioTrack != null ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Media Picker Action Button if relevant
            if (_selectedType == PostType.photo ||
                _selectedType == PostType.video ||
                _selectedType == PostType.reel ||
                _selectedType == PostType.pdf ||
                _selectedType == PostType.audio) ...[
              OutlinedButton.icon(
                onPressed: _pickMedia,
                icon: Icon(_selectedType.icon, color: AppTheme.primaryColor),
                label: Text(
                  _selectedMediaFile != null ? 'Change ${_selectedType.displayName}' : 'Select ${_selectedType.displayName}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 4. Type-Specific Input Sections
            if (_selectedType == PostType.mcq) _buildMcqInputSection(context, isDark),
            if (_selectedType == PostType.poll) _buildPollInputSection(context, isDark),
            if (_selectedType == PostType.question) _buildQuestionInputSection(context, isDark),

            // 5. Hashtags Chip Input Section
            Text(
              'Add Hashtags',
              style: GoogleFonts.outfit(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hashtagCtrl,
                    onSubmitted: (val) => _addHashtag(val),
                    style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '#flutter, #ai, #creania',
                      hintStyle: GoogleFonts.poppins(color: context.caption, fontSize: 12),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF181824) : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_rounded, color: AppTheme.primaryColor, size: 28),
                  onPressed: () => _addHashtag(_hashtagCtrl.text),
                ),
              ],
            ),
            if (_hashtags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _hashtags.map((tag) {
                  return Chip(
                    label: Text(
                      tag,
                      style: GoogleFonts.inter(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                    deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.primaryColor),
                    onDeleted: () {
                      setState(() => _hashtags.remove(tag));
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getHintForType(PostType type) {
    switch (type) {
      case PostType.photo:
        return 'Write a caption for your photo... Use #hashtags or @mentions';
      case PostType.video:
        return 'Write a caption for your video... Use #hashtags or @mentions';
      case PostType.reel:
        return 'Write a caption for your reel... Use #hashtags or @mentions';
      case PostType.audio:
        return 'Describe your audio clip... Use #hashtags or @mentions';
      case PostType.pdf:
        return 'Describe your PDF document... Use #hashtags or @mentions';
      case PostType.question:
        return 'Add context to your question...';
      case PostType.mcq:
        return 'Add explanation or notes for your quiz...';
      case PostType.poll:
        return 'Add additional info for your poll...';
      default:
        return 'What is on your mind? Use #hashtags or @mentions';
    }
  }

  Widget _buildMcqInputSection(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181824) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('☑', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                'Quiz / MCQ Details',
                style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mcqQuestionCtrl,
            style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Enter Quiz Question',
              hintStyle: GoogleFonts.poppins(color: context.caption, fontSize: 12),
              filled: true,
              fillColor: isDark ? const Color(0xFF222234) : Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Text('Options (Select correct answer radio):', style: GoogleFonts.poppins(color: context.caption, fontSize: 11)),
          const SizedBox(height: 6),
          ...List.generate(_mcqOptionCtrls.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Radio<int>(
                    value: i,
                    groupValue: _mcqCorrectIndex,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      if (val != null) setState(() => _mcqCorrectIndex = val);
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _mcqOptionCtrls[i],
                      style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Option ${i + 1}',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF222234) : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (_mcqOptionCtrls.length < 4)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _mcqOptionCtrls.add(TextEditingController(text: 'Option ${_mcqOptionCtrls.length + 1}'));
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Option'),
            ),
        ],
      ),
    );
  }

  Widget _buildPollInputSection(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181824) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                'Poll Details',
                style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pollQuestionCtrl,
            style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ask a question for your poll...',
              hintStyle: GoogleFonts.poppins(color: context.caption, fontSize: 12),
              filled: true,
              fillColor: isDark ? const Color(0xFF222234) : Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_pollOptionCtrls.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: TextField(
                controller: _pollOptionCtrls[i],
                style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Option ${i + 1}',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF222234) : Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            );
          }),
          if (_pollOptionCtrls.length < 4)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _pollOptionCtrls.add(TextEditingController(text: 'Option ${_pollOptionCtrls.length + 1}'));
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Option'),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionInputSection(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181824) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('❓', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                'Question Title',
                style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _questionTitleCtrl,
            style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'e.g. How can I improve Flutter app performance?',
              hintStyle: GoogleFonts.poppins(color: context.caption, fontSize: 12),
              filled: true,
              fillColor: isDark ? const Color(0xFF222234) : Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }
}
