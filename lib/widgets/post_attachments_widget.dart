import 'package:creania/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme.dart';
import '../models/post_model.dart';
import 'video_player_dialog.dart';
import 'optimized_image.dart';
import '../services/asset_cache_manager.dart';

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

    if (children.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children.map((w) => Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: w,
        )).toList(),
      ),
    );
  }

  Widget _buildImages(BuildContext context, List<String> images) {
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _renderImageItem(context, images[0], height: 200, width: double.infinity),
      );
    }

    // Multiple images -> Grid
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => SizedBox(width: 8),
        itemBuilder: (context, idx) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _renderImageItem(context, images[idx], height: 180, width: 140),
        ),
      ),
    );
  }

  Widget _renderImageItem(BuildContext context, String path, {required double height, required double width}) {
    final isNetwork = path.startsWith('http') || path.startsWith('https');
    if (isNetwork) {
      return OptimizedImage(
        imageUrl: path,
        quality: ImageQuality.medium,
        height: height,
        width: width,
        placeholder: Container(
          height: height,
          width: width,
          color: context.borderColor.withOpacity(0.3),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: context.primaryColor),
            ),
          ),
        ),
        errorWidget: Container(
          height: height,
          width: width,
          color: context.borderColor.withOpacity(0.3),
          child: Icon(Icons.broken_image_rounded, color: context.caption),
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
          color: context.borderColor.withOpacity(0.3),
          child: Icon(Icons.broken_image_rounded, color: context.caption),
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
        separatorBuilder: (_, __) => SizedBox(width: 8),
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
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
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
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            margin: EdgeInsets.only(bottom: 6),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.secondaryBackgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderColor.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.errorColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: context.errorColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        '1.8 MB · PDF Document',
                        style: TextStyle(
                          color: context.caption,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: context.caption,
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
            margin: EdgeInsets.only(bottom: 6),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.secondaryBackgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderColor.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isWord ? Color(0xFF2563EB) : Color(0xFF059669)).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isWord ? Icons.description_rounded : Icons.table_chart_rounded,
                    color: isWord ? Color(0xFF2563EB) : Color(0xFF059669),
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        isWord ? '840 KB · Word Document' : '1.2 MB · Excel Spreadsheet',
                        style: TextStyle(
                          color: context.caption,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: context.caption,
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
        backgroundColor: context.accentOrange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
