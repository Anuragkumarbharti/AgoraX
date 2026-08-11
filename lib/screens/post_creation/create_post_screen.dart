import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../models/community/post_type.dart';
import '../../models/discovery/audio_track_model.dart';
import '../../models/discovery/hashtag_model.dart';
import '../../services/post/post_upload_service.dart';
import '../../services/discovery/discovery_service.dart';
import '../../services/discovery/caption_parser_service.dart';
import '../../services/discovery/draft_post_service.dart';
import '../../widgets/post_creation/music_picker_sheet.dart';
import 'post_preview_screen.dart';

class CreatePostScreen extends StatefulWidget {
  final PostType initialType;
  final String? initialCommunityId;
  final AudioTrack? initialAudioTrack;

  const CreatePostScreen({
    Key? key,
    this.initialType = PostType.text,
    this.initialCommunityId,
    this.initialAudioTrack,
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

  // Media & Music
  File? _pickedMediaFile;
  File? _pickedCoverFile;
  List<File> _pickedImages = [];
  AudioTrack? _attachedAudioTrack;
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

  // Discovery & Parsing Services
  final PostUploadService _uploadService = Get.put(PostUploadService());
  final DiscoveryService _discoveryService = Get.put(DiscoveryService());

  // Hashtag & Mention Autocomplete state
  bool _showTagPopup = false;
  bool _showMentionPopup = false;
  String _autocompleteQuery = '';
  List<String> _smartSuggestedTags = [];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _selectedCommunityId = widget.initialCommunityId;
    _attachedAudioTrack = widget.initialAudioTrack;

    _captionCtrl.addListener(_onCaptionChanged);
    _checkDraft();
  }

  @override
  void dispose() {
    _captionCtrl.removeListener(_onCaptionChanged);
    _captionCtrl.dispose();
    _titleCtrl.dispose();
    _contextCtrl.dispose();
    _explanationCtrl.dispose();
    _linkCtrl.dispose();
    _mcqQuestionCtrl.dispose();
    for (var c in _mcqOptionCtrls) { c.dispose(); }
    _pollQuestionCtrl.dispose();
    for (var c in _pollOptionCtrls) { c.dispose(); }
    super.dispose();
  }

  Future<void> _checkDraft() async {
    final draft = await DraftPostService.getDraft();
    if (draft != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unfinished post draft found.'),
          backgroundColor: AppTheme.primaryColor,
          action: SnackBarAction(
            label: 'Restore',
            textColor: Colors.white,
            onPressed: () {
              setState(() {
                _captionCtrl.text = draft['caption'] ?? '';
                _titleCtrl.text = draft['title'] ?? '';
              });
            },
          ),
        ),
      );
    }
  }

  void _onCaptionChanged() {
    final text = _captionCtrl.text;
    final parseResult = CaptionParserService.parseCaption(text);

    // Save local draft
    DraftPostService.saveDraft({
      'caption': text,
      'title': _titleCtrl.text,
      'post_type': _selectedType.name,
    });

    setState(() {
      _smartSuggestedTags = parseResult.suggestedTags;
    });

    // Detect # or @ trigger at cursor
    final selection = _captionCtrl.selection;
    if (selection.baseOffset >= 0 && selection.isCollapsed) {
      final cursor = selection.baseOffset;
      final textBefore = text.substring(0, cursor);
      final words = textBefore.split(RegExp(r'\s+'));
      final lastWord = words.isNotEmpty ? words.last : '';

      if (lastWord.startsWith('#') && lastWord.length > 1) {
        final query = lastWord.substring(1);
        _discoveryService.fetchHashtagSuggestions(query);
        setState(() {
          _showTagPopup = true;
          _showMentionPopup = false;
          _autocompleteQuery = query;
        });
      } else if (lastWord.startsWith('@') && lastWord.length > 1) {
        final query = lastWord.substring(1);
        _discoveryService.fetchMentionSuggestions(query);
        setState(() {
          _showMentionPopup = true;
          _showTagPopup = false;
          _autocompleteQuery = query;
        });
      } else {
        setState(() {
          _showTagPopup = false;
          _showMentionPopup = false;
        });
      }
    }
  }

  void _insertHashtag(String tag) {
    final clean = tag.startsWith('#') ? tag : '#$tag';
    final text = _captionCtrl.text;
    final parseResult = CaptionParserService.parseCaption(text);

    if (parseResult.hashtags.length >= CaptionParserService.maxHashtags) {
      Get.snackbar('Limit Reached', 'Maximum 10 hashtags allowed per post.',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    _captionCtrl.text = '$text $clean ';
    _captionCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _captionCtrl.text.length));
    setState(() {
      _showTagPopup = false;
    });
  }

  void _insertMention(String username) {
    final text = _captionCtrl.text;
    _captionCtrl.text = '$text @$username ';
    _captionCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _captionCtrl.text.length));
    setState(() {
      _showMentionPopup = false;
    });
  }

  Future<void> _openMusicPicker() async {
    final track = await showModalBottomSheet<AudioTrack>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MusicPickerSheet(selectedTrack: _attachedAudioTrack),
    );

    if (track != null) {
      setState(() {
        _attachedAudioTrack = track;
      });
    }
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

  Future<void> _pickPdf() async {
    final picker = ImagePicker();
    final file = await picker.pickMedia();
    if (file != null) {
      setState(() {
        _pickedMediaFile = File(file.path);
        _pdfName = file.name;
        _pdfSize = 1024;
      });
    }
  }

  Future<void> _handlePublishSubmit() async {
    final text = _captionCtrl.text.trim();
    final parseResult = CaptionParserService.parseCaption(text);

    if (_selectedType == PostType.question) {
      final questionText = _titleCtrl.text.isNotEmpty ? _titleCtrl.text : text;
      final dupCheck = await _discoveryService.checkDuplicateQuestion(questionText);
      if (dupCheck['is_duplicate_suspected'] == true) {
        final bool proceed = await _showDuplicateQuestionWarning(dupCheck['similar_questions']);
        if (!proceed) return;
      }
    }

    // Process upload
    final success = await _uploadService.uploadPost(
      postType: _selectedType,
      caption: text,
      title: _titleCtrl.text,
      contextText: _contextCtrl.text,
      explanation: _explanationCtrl.text,
      linkUrl: _linkCtrl.text,
      visibility: _visibility,
      commentsEnabled: _commentsEnabled,
      sharesEnabled: _sharesEnabled,
      communityId: _selectedCommunityId,
      mediaFile: _pickedMediaFile,
      coverFile: _pickedCoverFile,
      audioTrackId: _attachedAudioTrack?.id,
      hashtags: parseResult.hashtags,
      mentions: parseResult.mentions,
      mcqQuestion: _mcqQuestionCtrl.text,
      mcqOptions: _mcqOptionCtrls.map((c) => c.text).toList(),
      mcqCorrectIndex: _mcqCorrectIndex,
      mcqXpReward: _mcqXpReward,
      pollQuestion: _pollQuestionCtrl.text,
      pollOptions: _pollOptionCtrls.map((c) => c.text).toList(),
      pollDurationHours: _pollDurationHours,
    );

    if (success) {
      await DraftPostService.clearDraft();
      Get.back(result: true);
    }
  }

  Future<bool> _showDuplicateQuestionWarning(List<dynamic> similarQuestions) async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.cardBg,
            title: Text('Similar Questions Found', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Other students have asked similar questions:', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 10),
                ...similarQuestions.take(3).map((q) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(8)),
                      child: Text('• ${q['question']}', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                    )),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Edit Question')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                child: const Text('Post Anyway'),
              ),
            ],
          ),
        )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final parseResult = CaptionParserService.parseCaption(_captionCtrl.text);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Create Post', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostPreviewScreen(
                    postType: _selectedType,
                    caption: _captionCtrl.text,
                    title: _titleCtrl.text,
                    mediaFile: _pickedMediaFile,
                    audioTrack: _attachedAudioTrack,
                    mcqOptions: _mcqOptionCtrls.map((c) => c.text).toList(),
                    mcqCorrectIndex: _mcqCorrectIndex,
                    pollOptions: _pollOptionCtrls.map((c) => c.text).toList(),
                    onPublish: _handlePublishSubmit,
                  ),
                ),
              );
            },
            child: Text('Preview', style: GoogleFonts.inter(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Obx(() => ElevatedButton(
                onPressed: _uploadService.isUploading.value ? null : _handlePublishSubmit,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: _uploadService.isUploading.value
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Post', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              )),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Post Type Selector Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      PostType.text,
                      PostType.photo,
                      PostType.video,
                      PostType.reel,
                      PostType.audio,
                      PostType.question,
                      PostType.mcq,
                      PostType.poll,
                      PostType.pdf,
                    ].map((type) {
                      final isSelected = _selectedType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(type.name.toUpperCase()),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => _selectedType = type);
                          },
                          selectedColor: AppTheme.primaryColor,
                          backgroundColor: AppTheme.surfaceColor,
                          labelStyle: GoogleFonts.inter(
                            color: isSelected ? Colors.white : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Main Caption Editor
                TextField(
                  controller: _captionCtrl,
                  maxLines: 5,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'What is on your mind? Use #hashtags or @mentions',
                    hintStyle: GoogleFonts.inter(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                ),

                // Hashtag counter & Smart Suggestions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hashtags: ${parseResult.hashtags.length} / 10',
                      style: GoogleFonts.inter(
                        color: parseResult.exceedsHashtagLimit ? Colors.redAccent : Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openMusicPicker,
                      icon: const Icon(Icons.music_note, color: AppTheme.primaryColor, size: 18),
                      label: Text(_attachedAudioTrack != null ? 'Music Attached' : 'Add Music', style: GoogleFonts.inter(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),

                // Attached Audio Strip if selected
                if (_attachedAudioTrack != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.audiotrack, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_attachedAudioTrack!.title} - ${_attachedAudioTrack!.artist}',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                          onPressed: () => setState(() => _attachedAudioTrack = null),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Smart Recommended Tags Chips
                if (_smartSuggestedTags.isNotEmpty) ...[
                  Text('Suggested Hashtags:', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: _smartSuggestedTags.map((tag) {
                      return ActionChip(
                        label: Text(tag, style: GoogleFonts.inter(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        backgroundColor: AppTheme.surfaceColor,
                        onPressed: () => _insertHashtag(tag),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // Dynamic Media Pickers
                if (_selectedType == PostType.photo)
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: Text(_pickedMediaFile != null ? 'Image Selected' : 'Select Photo'),
                  ),

                if (_selectedType == PostType.video || _selectedType == PostType.reel)
                  ElevatedButton.icon(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.videocam),
                    label: Text(_pickedMediaFile != null ? 'Video Selected' : 'Select Video / Reel'),
                  ),

                if (_selectedType == PostType.pdf)
                  ElevatedButton.icon(
                    onPressed: _pickPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(_pdfName.isNotEmpty ? _pdfName : 'Select PDF Document'),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // Autocomplete Tag Popup Overlay
          if (_showTagPopup)
            Positioned(
              left: 16,
              right: 16,
              top: 180,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.cardBg,
                child: Obx(() {
                  final tags = _discoveryService.hashtagSuggestions;
                  return Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: tags.length,
                      itemBuilder: (context, index) {
                        final t = tags[index];
                        return ListTile(
                          title: Text(t.name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('${t.usageCount} posts', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                          onTap: () => _insertHashtag(t.name),
                        );
                      },
                    ),
                  );
                }),
              ),
            ),

          // Autocomplete Mention Popup Overlay
          if (_showMentionPopup)
            Positioned(
              left: 16,
              right: 16,
              top: 180,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.cardBg,
                child: Obx(() {
                  final users = _discoveryService.mentionSuggestions;
                  return Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final u = users[index];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundImage: u['avatar_url'].isNotEmpty ? NetworkImage(u['avatar_url']) : null,
                            child: u['avatar_url'].isEmpty ? const Icon(Icons.person, size: 14) : null,
                          ),
                          title: Text('@${u['username']}', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(u['display_name'] ?? '', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                          onTap: () => _insertMention(u['username']),
                        );
                      },
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
