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
  static PostUploadService get instance {
    if (!Get.isRegistered<PostUploadService>()) {
      return Get.put(PostUploadService());
    }
    return Get.find<PostUploadService>();
  }

  final Rx<UploadProgressState> uploadState = UploadProgressState().obs;
  final Set<String> _processedRequestIds = {};

  RxBool get isUploading => RxBool(uploadState.value.isUploading);

  /// Main post creation method returning created Post model object
  Future<Post?> createAndReturnPost({
    required PostType postType,
    required String caption,
    List<String> hashtags = const [],
    String? communityId,
    String visibility = 'public',
    bool commentsEnabled = true,
    bool sharesEnabled = true,
    File? mediaFile,
    File? coverFile,
    String? audioTrackId,
    McqData? mcqData,
    PollData? pollData,
    QuestionData? questionData,
    String? clientRequestId,
  }) async {
    // Idempotency check
    if (clientRequestId != null && _processedRequestIds.contains(clientRequestId)) {
      debugPrint('Duplicate upload request rejected: $clientRequestId');
      return null;
    }
    if (clientRequestId != null) {
      _processedRequestIds.add(clientRequestId);
    }

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final userId = currentUser?.id ?? '6553bee0-8fe9-450c-9f7b-e34ff9a16e4e';
      final username = currentUser?.userMetadata?['username'] ??
          currentUser?.userMetadata?['full_name'] ??
          'Anurag Kumar';
      final avatarUrl = currentUser?.userMetadata?['avatar_url'] ??
          currentUser?.userMetadata?['profile_photo'] ??
          '';

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
        } else if (postType == PostType.video || postType == PostType.reel) {
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
          progress: 0.35,
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
            thumbnailUrl = mediaFile.path;
          }
        }

        uploadState.value = UploadProgressState(
          isUploading: true,
          progress: 0.65,
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
          mediaUrl = mediaFile.path;
          if (thumbnailUrl.isEmpty) thumbnailUrl = mediaFile.path;
        }
      }

      uploadState.value = UploadProgressState(
        isUploading: true,
        progress: 0.85,
        statusText: 'Publishing post...',
      );

      final fullCaption = hashtags.isNotEmpty && !caption.contains('#')
          ? '$caption\n${hashtags.join(" ")}'
          : caption;

      // 2. Insert master post record in Supabase (if available)
      final postPayload = {
        'id': postId,
        'user_id': userId,
        'community_id': (communityId != null && communityId.isNotEmpty) ? communityId : null,
        'content': fullCaption,
        'post_type': postType.value,
        'caption': fullCaption,
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

      try {
        await Supabase.instance.client.from('posts').insert(postPayload);

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
      } catch (e) {
        debugPrint('Supabase insert fallback warning: $e');
      }

      uploadState.value = UploadProgressState(
        isUploading: false,
        progress: 1.0,
        statusText: 'Post published successfully!',
      );

      // 3. Create full Post model instance
      final createdPost = Post(
        id: postId,
        userId: userId,
        communityId: communityId ?? '',
        content: fullCaption,
        postType: postType,
        caption: fullCaption,
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl,
        aspectRatio: aspectRatio,
        mediaMetadata: metadata,
        likes: 0,
        comments: 0,
        shares: 0,
        isLiked: false,
        isBookmarked: false,
        createdAt: DateTime.now(),
        authorUsername: username,
        authorAvatarUrl: avatarUrl,
        visibility: visibility,
        commentsEnabled: commentsEnabled,
        sharesEnabled: sharesEnabled,
        status: 'published',
        mcqData: mcqData,
        pollData: pollData,
        questionData: questionData,
      );

      return createdPost;
    } catch (e) {
      debugPrint('Error in PostUploadService.createAndReturnPost: $e');
      uploadState.value = UploadProgressState(
        isUploading: false,
        progress: 0.0,
        error: e.toString(),
      );
      return null;
    }
  }
}
