import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/discovery/unified_content_model.dart';
import '../../models/discovery/hashtag_model.dart';
import '../../models/discovery/audio_track_model.dart';

class DiscoveryService extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Feeds cache state
  final RxList<UnifiedContentItem> feedPosts = <UnifiedContentItem>[].obs;
  final RxBool isLoadingFeed = false.obs;
  final RxString activeFeedType = 'trending_now'.obs;
  final RxString activeCategory = ''.obs;

  // Search / Autocomplete suggestions state
  final RxList<HashtagModel> hashtagSuggestions = <HashtagModel>[].obs;
  final RxList<Map<String, dynamic>> mentionSuggestions = <Map<String, dynamic>>[].obs;
  final RxList<AudioTrack> audioCatalog = <AudioTrack>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadAudioCatalog();
  }

  Future<List<UnifiedContentItem>> fetchSmartFeed({
    String feedType = 'trending_now',
    String? category,
    String? contentType,
    String? hashtag,
    int limit = 15,
    int offset = 0,
  }) async {
    try {
      isLoadingFeed.value = true;
      activeFeedType.value = feedType;

      final userId = _supabase.auth.currentUser?.id;
      final response = await _supabase.rpc(
        'get_smart_feed',
        params: {
          'p_user_id': userId,
          'p_feed_type': feedType,
          'p_category': (category != null && category.isNotEmpty) ? category : null,
          'p_content_type': (contentType != null && contentType.isNotEmpty) ? contentType : null,
          'p_hashtag': (hashtag != null && hashtag.isNotEmpty) ? hashtag : null,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      final List<UnifiedContentItem> items = [];
      if (response != null && response is List) {
        for (var item in response) {
          items.add(UnifiedContentItem.fromJson(item as Map<String, dynamic>));
        }
      }

      if (offset == 0) {
        feedPosts.assignAll(items);
      } else {
        feedPosts.addAll(items);
      }

      return items;
    } catch (e) {
      return [];
    } finally {
      isLoadingFeed.value = false;
    }
  }

  Future<List<HashtagModel>> fetchHashtagSuggestions(String query) async {
    try {
      final response = await _supabase.rpc(
        'get_hashtag_suggestions',
        params: {
          'p_query': query,
          'p_limit': 10,
        },
      );

      final List<HashtagModel> tags = [];
      if (response != null && response is List) {
        for (var item in response) {
          tags.add(HashtagModel.fromJson(item as Map<String, dynamic>));
        }
      }
      hashtagSuggestions.assignAll(tags);
      return tags;
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchMentionSuggestions(String query) async {
    try {
      final response = await _supabase.rpc(
        'get_mention_suggestions',
        params: {
          'p_query': query,
          'p_limit': 10,
        },
      );

      final List<Map<String, dynamic>> users = [];
      if (response != null && response is List) {
        for (var item in response) {
          users.add(item as Map<String, dynamic>);
        }
      }
      mentionSuggestions.assignAll(users);
      return users;
    } catch (_) {
      return [];
    }
  }

  Future<List<AudioTrack>> loadAudioCatalog({String query = ''}) async {
    try {
      final response = await _supabase.rpc(
        'search_audio_tracks',
        params: {
          'p_query': query,
          'p_limit': 20,
        },
      );

      final List<AudioTrack> tracks = [];
      if (response != null && response is List) {
        for (var item in response) {
          tracks.add(AudioTrack.fromJson(item as Map<String, dynamic>));
        }
      }
      audioCatalog.assignAll(tracks);
      return tracks;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> checkDuplicateQuestion(String questionText) async {
    try {
      final response = await _supabase.rpc(
        'check_duplicate_question',
        params: {
          'p_question_text': questionText,
        },
      );
      if (response != null && response is Map<String, dynamic>) {
        return response;
      }
    } catch (_) {}
    return {'is_duplicate_suspected': false, 'similar_questions': []};
  }

  Future<bool> toggleSavePost(String postId, bool isCurrentlySaved) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      if (isCurrentlySaved) {
        await _supabase.from('post_saves').delete().eq('post_id', postId).eq('user_id', userId);
        return false;
      } else {
        await _supabase.from('post_saves').insert({'post_id': postId, 'user_id': userId});
        return true;
      }
    } catch (_) {
      return isCurrentlySaved;
    }
  }

  Future<void> submitFeedFeedback({
    required String postId,
    required String creatorId,
    required String feedbackType, // 'not_interested', 'mute_creator', 'report'
    String reason = '',
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('user_feed_feedback').insert({
        'user_id': userId,
        'post_id': postId,
        'creator_id': creatorId,
        'feedback_type': feedbackType,
        'reason': reason,
      });

      // Remove from active local feed
      feedPosts.removeWhere((item) => item.id == postId || (feedbackType == 'mute_creator' && item.userId == creatorId));
    } catch (_) {}
  }
}
