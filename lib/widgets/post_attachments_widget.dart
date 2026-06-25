import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme.dart';
import '../models/post_model.dart';
import 'video_player_dialog.dart';

class PostAttachmentsWidget extends StatelessWidget {
  final Post post;

  const PostAttachmentsWidget({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];

    // 1. Render Images
    if (post.images != null && post.images!.isNotEmpty) {
      children.add(_buildImages(context, post.images!));
    }

    // 2. Render Videos
    if (post.videos != null && post.videos!.isNotEmpty) {
      children.add(_buildVideos(context, post.videos!));
    }

    // 3. Render PDFs
    if (post.pdfs != null && post.pdfs!.isNotEmpty) {
      children.add(_buildPdfs(context, post.pdfs!));
    }

    // 4. Render Document URLs
    if (post.docUrls != null && post.docUrls!.isNotEmpty) {
      children.add(_buildDocs(context, post.docUrls!));
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children.map((w) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: w,
        )).toList(),
      ),
    );
  }

  Widget _buildImages(BuildContext context, List<String> images) {
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _renderImageItem(images[0], height: 200, width: double.infinity),
      );
    }

    // Multiple images -> Grid
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _renderImageItem(images[idx], height: 180, width: 140),
        ),
      ),
    );
  }

  Widget _renderImageItem(String path, {required double height, required double width}) {
    final isNetwork = path.startsWith('http') || path.startsWith('https');
    if (isNetwork) {
      return CachedNetworkImage(
        imageUrl: path,
        height: height,
        width: width,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: height,
          width: width,
          color: AppTheme.borderColor.withOpacity(0.3),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          height: height,
          width: width,
          color: AppTheme.borderColor.withOpacity(0.3),
          child: const Icon(Icons.broken_image_rounded, color: AppTheme.textTertiary),
        ),
      );
    } else {
      return Image.asset(
        path,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: height,
          width: width,
          color: AppTheme.borderColor.withOpacity(0.3),
          child: const Icon(Icons.broken_image_rounded, color: AppTheme.textTertiary),
        ),
      );
    }
  }

  Widget _buildVideos(BuildContext context, List<String> videos) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: videos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final videoUrl = videos[idx];
          return GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => VideoPlayerDialog(videoUrl: videoUrl),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 240,
                height: 180,
                color: Colors.black87,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Mock thumbnail placeholder
                    Icon(
                      Icons.video_library_rounded,
                      size: 48,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    // Semi-transparent play button
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    // Text label at bottom
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Video Playback',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPdfs(BuildContext context, List<String> pdfs) {
    return Column(
      children: pdfs.map((pdfPath) {
        final fileName = pdfPath.split('/').last;
        return GestureDetector(
          onTap: () => _openFileAction(context, fileName, 'PDF'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppTheme.errorColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '1.8 MB · PDF Document',
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppTheme.textTertiary,
                  size: 14,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDocs(BuildContext context, List<String> docUrls) {
    return Column(
      children: docUrls.map((docPath) {
        final fileName = docPath.split('/').last;
        final isWord = fileName.endsWith('.doc') || fileName.endsWith('.docx');
        return GestureDetector(
          onTap: () => _openFileAction(context, fileName, 'Document'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isWord ? const Color(0xFF2563EB) : const Color(0xFF059669)).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isWord ? Icons.description_rounded : Icons.table_chart_rounded,
                    color: isWord ? const Color(0xFF2563EB) : const Color(0xFF059669),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isWord ? '840 KB · Word Document' : '1.2 MB · Excel Spreadsheet',
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppTheme.textTertiary,
                  size: 14,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _openFileAction(BuildContext context, String name, String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $type: $name'),
        backgroundColor: AppTheme.accentColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
