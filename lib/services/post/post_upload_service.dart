import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/community/post_model.dart';
import '../../models/community/post_type.dart';
import 'media_processing_service.dart';

class UploadProgressState {
  final bool isUploading;
  final double progress; // 0.0 to 1.0
  final String statusText;
  final String? error;

  UploadProgressState({
    this.isUploading = false,
    this.progress = 0.0,
    this.statusText = '',
    this.error,
  });
}

class PostUploadService extends GetxController {
  static PostUploadService get instance => Get.find<PostUploadService>();

  final Rx<UploadProgressState> uploadState = UploadProgressState().obs;

  /// Main background upload method
  Future<bool> createPost({
    required PostType postType,
    required String caption,
    String? communityId,
    String visibility = 'public',
    bool commentsEnabled = true,
    bool sharesEnabled = true,
    File? mediaFile,
    File? coverFile,
    McqData? mcqData,
    PollData? pollData,
    QuestionData? questionData,
  }) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        uploadState.value = UploadProgressState(error: 'User not logged in');
        return false;
      }

      uploadState.value = UploadProgressState(
        isUploading: true,
        progress: 0.1,
        statusText: 'Processing media...',
      );

      final postId = 'post_${DateTime.now().millisecondsSinceEpoch}';
      String mediaUrl = '';
      String thumbnailUrl = '';
      double aspectRatio = 1.0;
      Map<String, dynamic> metadata = {};

      // 1. Process media if provided
      if (mediaFile != null && await mediaFile.exists()) {
        ProcessedMediaResult processed;
        if (postType == PostType.photo) {
          processed = await MediaProcessingService.processImage(mediaFile);
        } else if (postType == PostType.video) {
          processed = await MediaProcessingService.processVideo(mediaFile);
        } else if (postType == PostType.audio) {
          processed = await MediaProcessingService.processAudio(mediaFile);
        } else if (postType == PostType.pdf) {
          processed = await MediaProcessingService.processPdf(mediaFile);
        } else {
          processed = await MediaProcessingService.processImage(mediaFile);
        }

        aspectRatio = processed.aspectRatio;
        metadata = processed.metadata;

        uploadState.value = UploadProgressState(
          isUploading: true,
          progress: 0.3,
          statusText: 'Uploading preview thumbnail...',
        );

        // Upload thumbnail if available
        if (processed.thumbnailFile != null && await processed.thumbnailFile!.exists()) {
          try {
            final thumbPath = 'thumbnails/$postId.jpg';
            await Supabase.instance.client.storage
                .from('posts')
                .upload(thumbPath, processed.thumbnailFile!, fileOptions: const FileOptions(upsert: true));
            thumbnailUrl = Supabase.instance.client.storage.from('posts').getPublicUrl(thumbPath);
          } catch (e) {
            debugPrint('Thumbnail upload warning: $e');
          }
        }

        uploadState.value = UploadProgressState(
          isUploading: true,
          progress: 0.6,
          statusText: 'Uploading media asset...',
        );

        // Upload main media file
        try {
          final extension = mediaFile.path.split('.').last;
          final storagePath = 'media/$postId.$extension';
          await Supabase.instance.client.storage
              .from('posts')
              .upload(storagePath, mediaFile, fileOptions: const FileOptions(upsert: true));
          mediaUrl = Supabase.instance.client.storage.from('posts').getPublicUrl(storagePath);
          
          if (thumbnailUrl.isEmpty) {
            thumbnailUrl = mediaUrl;
          }
        } catch (e) {
          debugPrint('Media upload warning: $e');
          // If Supabase storage is not configured, fallback to local path or placeholder
          mediaUrl = mediaFile.path;
          if (thumbnailUrl.isEmpty) thumbnailUrl = mediaFile.path;
        }
      }

      uploadState.value = UploadProgressState(
        isUploading: true,
        progress: 0.85,
        statusText: 'Publishing post...',
      );

      // 2. Insert master post record
      final postPayload = {
        'id': postId,
        'user_id': currentUser.id,
        'community_id': (communityId != null && communityId.isNotEmpty) ? communityId : null,
        'content': caption,
        'post_type': postType.value,
        'caption': caption,
        'media_url': mediaUrl,
        'thumbnail_url': thumbnailUrl,
        'aspect_ratio': aspectRatio,
        'media_metadata': metadata,
        'visibility': visibility,
        'comments_enabled': commentsEnabled,
        'shares_enabled': sharesEnabled,
        'status': 'published',
        'likes': 0,
        'comments': 0,
        'shares': 0,
      };

      await Supabase.instance.client.from('posts').insert(postPayload);

      // 3. Insert auxiliary data records
      if (postType == PostType.mcq && mcqData != null) {
        await Supabase.instance.client.from('post_mcqs').insert({
          'post_id': postId,
          'question': mcqData.question,
          'options': mcqData.options.map((o) => o.toJson()).toList(),
          'explanation': mcqData.explanation,
          'timer_seconds': mcqData.timerSeconds,
          'difficulty': mcqData.difficulty,
          'category': mcqData.category,
          'xp_reward': mcqData.xpReward,
        });
      } else if (postType == PostType.poll && pollData != null) {
        await Supabase.instance.client.from('post_polls').insert({
          'post_id': postId,
          'question': pollData.question,
          'options': pollData.options.map((o) => o.toJson()).toList(),
          'duration_hours': pollData.durationHours,
          'expires_at': DateTime.now().add(Duration(hours: pollData.durationHours)).toIso8601String(),
        });
      } else if (postType == PostType.question && questionData != null) {
        await Supabase.instance.client.from('post_questions').insert({
          'post_id': postId,
          'question': questionData.question,
          'context': questionData.context,
          'optional_media_url': mediaUrl,
        });
      }

      uploadState.value = UploadProgressState(
        isUploading: false,
        progress: 1.0,
        statusText: 'Post published successfully!',
      );

      Get.snackbar(
        'Published! 🎉',
        'Your ${postType.displayName} post is live.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: const Color(0xFFFFFFFF),
        duration: const Duration(seconds: 2),
      );

      return true;
    } catch (e) {
      debugPrint('Error creating post: $e');
      uploadState.value = UploadProgressState(
        isUploading: false,
        progress: 0.0,
        error: e.toString(),
      );
      Get.snackbar(
        'Upload Error',
        'Could not publish post. Please check connection.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: const Color(0xFFFFFFFF),
      );
      return false;
    }
  }
}
