import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme.dart';
import '../../models/chat/chat_model.dart';

class ChatMediaAttachmentWidget extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;

  const ChatMediaAttachmentWidget({
    Key? key,
    required this.message,
    required this.isMe,
  }) : super(key: key);

  @override
  State<ChatMediaAttachmentWidget> createState() => _ChatMediaAttachmentWidgetState();
}

class _ChatMediaAttachmentWidgetState extends State<ChatMediaAttachmentWidget> {
  VideoPlayerController? _videoCtrl;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.message.type == MessageType.video && widget.message.mediaUrl != null) {
      _initVideoPlayer();
    }
  }

  Future<void> _initVideoPlayer() async {
    final url = widget.message.mediaUrl;
    if (url == null || url.isEmpty) return;
    try {
      if (url.startsWith('http')) {
        _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        _videoCtrl = VideoPlayerController.file(File(url));
      }
      await _videoCtrl!.initialize();
      if (mounted) {
        setState(() => _isVideoInitialized = true);
      }
    } catch (e) {
      debugPrint('Video Player Init Error: $e');
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getFileIcon(String? fileName) {
    if (fileName == null) return Icons.insert_drive_file_rounded;
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_rounded;
      case 'apk':
        return Icons.android_rounded;
      case 'txt':
        return Icons.article_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(String? fileName) {
    if (fileName == null) return Colors.blueAccent;
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Colors.redAccent;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'ppt':
      case 'pptx':
        return Colors.orangeAccent;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'zip':
      case 'rar':
        return Colors.amber;
      case 'apk':
        return Colors.lightGreen;
      default:
        return AppTheme.primaryColor;
    }
  }

  void _openFullScreenImage(String imageUrl) {
    Get.to(
      () => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(widget.message.fileName ?? 'Photo Preview', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
          actions: [
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.white),
              onPressed: () {
                Get.snackbar('Download', 'Saved to Gallery', backgroundColor: AppTheme.bgLight);
              },
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              onPressed: () {
                Get.snackbar('Share', 'Preparing image for sharing...', backgroundColor: AppTheme.bgLight);
              },
            ),
          ],
        ),
        body: Center(
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4.0,
            child: imageUrl.startsWith('http')
                ? Image.network(imageUrl, fit: BoxFit.contain)
                : Image.file(File(imageUrl), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  void _openFullScreenVideo() {
    if (_videoCtrl == null || !_isVideoInitialized) return;
    _videoCtrl!.play();

    Get.to(
      () => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(widget.message.fileName ?? 'Video Playback', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
        ),
        body: Center(
          child: AspectRatio(
            aspectRatio: _videoCtrl!.value.aspectRatio,
            child: VideoPlayer(_videoCtrl!),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppTheme.primaryColor,
          onPressed: () {
            setState(() {
              if (_videoCtrl!.value.isPlaying) {
                _videoCtrl!.pause();
              } else {
                _videoCtrl!.play();
              }
            });
          },
          child: Icon(_videoCtrl!.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final isMe = widget.isMe;

    switch (msg.type) {
      case MessageType.image:
        return _buildImageWidget(msg, isMe);
      case MessageType.video:
        return _buildVideoWidget(msg, isMe);
      case MessageType.file:
      case MessageType.document:
        return _buildDocumentWidget(msg, isMe);
      case MessageType.location:
        return _buildLocationWidget(msg, isMe);
      case MessageType.contact:
        return _buildContactWidget(msg, isMe);
      default:
        return Text(msg.content, style: TextStyle(color: isMe ? Colors.white : AppTheme.textPrimary));
    }
  }

  Widget _buildImageWidget(ChatMessage msg, bool isMe) {
    final imgUrl = msg.mediaUrl ?? msg.content;

    return GestureDetector(
      onTap: () => _openFullScreenImage(imgUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 260),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              imgUrl.startsWith('http')
                  ? Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)),
                    )
                  : Image.file(
                      File(imgUrl),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)),
                    ),
              Positioned(
                bottom: 6,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('h:mm a').format(msg.timestamp),
                        style: const TextStyle(color: Colors.white, fontSize: 9),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.done_all_rounded, size: 11, color: Color(0xFF60A5FA)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoWidget(ChatMessage msg, bool isMe) {
    return GestureDetector(
      onTap: _openFullScreenVideo,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 240,
          height: 160,
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isVideoInitialized && _videoCtrl != null)
                AspectRatio(
                  aspectRatio: _videoCtrl!.value.aspectRatio,
                  child: VideoPlayer(_videoCtrl!),
                )
              else
                const Center(child: Icon(Icons.video_library_rounded, color: Colors.white54, size: 40)),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.85),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentWidget(ChatMessage msg, bool isMe) {
    final fileName = msg.fileName ?? 'Document_${msg.id.substring(0, 6)}';
    final fileSize = msg.fileSize ?? 1024 * 500;
    final fileColor = _getFileColor(fileName);
    final fileIcon = _getFileIcon(fileName);

    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 260),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.15) : AppTheme.bgDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fileColor.withOpacity(0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: fileColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(fileIcon, color: fileColor, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: GoogleFonts.outfit(
                        color: isMe ? Colors.white : AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatFileSize(fileSize),
                      style: GoogleFonts.outfit(
                        color: isMe ? Colors.white70 : AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 1.0,
                    backgroundColor: isMe ? Colors.white24 : AppTheme.borderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(fileColor),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Get.snackbar('Open Document', 'Opening $fileName...', backgroundColor: AppTheme.bgLight);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: fileColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Open',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationWidget(ChatMessage msg, bool isMe) {
    final lat = msg.locationLat ?? 28.6139;
    final lng = msg.locationLng ?? 77.2090;
    final locName = msg.locationName ?? 'Shared Location ($lat, $lng)';

    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 260),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.15) : AppTheme.bgDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_rounded, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locName,
                      style: GoogleFonts.outfit(
                        color: isMe ? Colors.white : AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                      style: GoogleFonts.outfit(
                        color: isMe ? Colors.white70 : AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Get.snackbar('Location', 'Opening in Maps...', backgroundColor: AppTheme.bgLight);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'View on Map',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactWidget(ChatMessage msg, bool isMe) {
    final contactName = msg.contactName ?? 'Student Contact';
    final contactPhone = msg.contactPhone ?? '+91 98765 43210';

    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 260),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.15) : AppTheme.bgDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.teal.withOpacity(0.2),
                child: const Icon(Icons.person_rounded, color: Colors.teal, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contactName,
                      style: GoogleFonts.outfit(
                        color: isMe ? Colors.white : AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contactPhone,
                      style: GoogleFonts.outfit(
                        color: isMe ? Colors.white70 : AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Get.snackbar('Contact', 'Calling $contactName...', backgroundColor: AppTheme.bgLight);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Call',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Get.snackbar('Contact', 'Starting chat with $contactName...', backgroundColor: AppTheme.bgLight);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal, width: 0.5),
                    ),
                    child: Text(
                      'Message',
                      style: GoogleFonts.outfit(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
