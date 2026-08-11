import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/community/post_model.dart';

class PostRepository {
  /// Fetch paginated lightweight feed posts
  static Future<List<Post>> fetchFeedPosts({
    String? communityId,
    int limit = 15,
    int offset = 0,
  }) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final userId = currentUser?.id;

      // Try RPC function first
      try {
        final rpcResult = await Supabase.instance.client.rpc(
          'get_feed_posts',
          params: {
            'p_user_id': userId,
            'p_community_id': communityId,
            'p_limit': limit,
            'p_offset': offset,
          },
        );

        if (rpcResult != null && rpcResult is List) {
          return rpcResult
              .map((item) => Post.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
      } catch (rpcErr) {
        debugPrint('RPC get_feed_posts not found or fallback needed: $rpcErr');
      }

      // Fallback query
      dynamic filterBuilder = Supabase.instance.client
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(username, avatar_url)');

      if (communityId != null && communityId.isNotEmpty) {
        filterBuilder = filterBuilder.eq('community_id', communityId);
      }

      final response = await filterBuilder
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      if (response != null && response is List) {
        return response
            .map((item) => Post.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error in PostRepository.fetchFeedPosts: $e');
      return [];
    }
  }

  /// Submit MCQ vote
  static Future<Map<String, dynamic>?> submitMcqVote(String postId, String optionId) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return null;

      final res = await Supabase.instance.client.rpc(
        'submit_mcq_vote',
        params: {
          'p_post_id': postId,
          'p_user_id': currentUser.id,
          'p_option_id': optionId,
        },
      );

      if (res != null && res is Map) {
        return Map<String, dynamic>.from(res);
      }

      // Local fallback
      await Supabase.instance.client.from('post_mcq_votes').upsert({
        'post_id': postId,
        'user_id': currentUser.id,
        'option_id': optionId,
      });

      return {
        'success': true,
        'selected_option_id': optionId,
      };
    } catch (e) {
      debugPrint('Error submitting MCQ vote: $e');
      return null;
    }
  }

  /// Submit Poll vote
  static Future<Map<String, dynamic>?> submitPollVote(String postId, String optionId) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return null;

      final res = await Supabase.instance.client.rpc(
        'submit_poll_vote',
        params: {
          'p_post_id': postId,
          'p_user_id': currentUser.id,
          'p_option_id': optionId,
        },
      );

      if (res != null && res is Map) {
        return Map<String, dynamic>.from(res);
      }

      // Local fallback
      await Supabase.instance.client.from('post_poll_votes').upsert({
        'post_id': postId,
        'user_id': currentUser.id,
        'option_id': optionId,
      });

      return {
        'success': true,
        'user_selected_option_id': optionId,
      };
    } catch (e) {
      debugPrint('Error submitting poll vote: $e');
      return null;
    }
  }

  /// Toggle Like
  static Future<bool> toggleLike(String postId, bool isCurrentlyLiked) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return isCurrentlyLiked;

      if (isCurrentlyLiked) {
        await Supabase.instance.client
            .from('post_likes')
            .delete()
            .match({'user_id': currentUser.id, 'post_id': postId});
        return false;
      } else {
        await Supabase.instance.client.from('post_likes').insert({
          'user_id': currentUser.id,
          'post_id': postId,
        });
        return true;
      }
    } catch (e) {
      debugPrint('Error toggling post like: $e');
      return !isCurrentlyLiked;
    }
  }

  /// Toggle Bookmark
  static Future<bool> toggleBookmark(String postId, bool isCurrentlyBookmarked) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return isCurrentlyBookmarked;

      if (isCurrentlyBookmarked) {
        await Supabase.instance.client
            .from('post_bookmarks')
            .delete()
            .match({'user_id': currentUser.id, 'post_id': postId});
        return false;
      } else {
        await Supabase.instance.client.from('post_bookmarks').insert({
          'user_id': currentUser.id,
          'post_id': postId,
        });
        return true;
      }
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
      return !isCurrentlyBookmarked;
    }
  }

  /// Report Post
  static Future<bool> reportPost(String postId, String reason) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return false;

      await Supabase.instance.client.from('post_reports').insert({
        'post_id': postId,
        'reporter_id': currentUser.id,
        'reason': reason,
      });

      return true;
    } catch (e) {
      debugPrint('Error reporting post: $e');
      return false;
    }
  }

  /// Fetch Popular Questions with filters and sorting
  static Future<List<Post>> fetchPopularQuestions({
    String? category,
    String sortBy = 'Most Answered',
    String? searchQuery,
    int limit = 15,
    int offset = 0,
  }) async {
    try {
      dynamic query = Supabase.instance.client
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(username, avatar_url)')
          .eq('post_type', 'question');

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        query = query.ilike('content', '%${searchQuery.trim()}%');
      }

      if (sortBy == 'Most Answered') {
        query = query.order('comments', ascending: false);
      } else if (sortBy == 'Most Viewed' || sortBy == 'Upvoted') {
        query = query.order('likes', ascending: false);
      } else {
        query = query.order('created_at', ascending: false);
      }

      final response = await query.range(offset, offset + limit - 1);
      if (response != null && response is List) {
        return response
            .map((item) => Post.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error in PostRepository.fetchPopularQuestions: $e');
      return [];
    }
  }

  /// Fetch Recent Posts with type filter & search
  static Future<List<Post>> fetchRecentPostsFiltered({
    String? postTypeFilter,
    String? communityId,
    String? searchQuery,
    String sortBy = 'Newest',
    int limit = 15,
    int offset = 0,
  }) async {
    try {
      dynamic query = Supabase.instance.client
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(username, avatar_url)');

      if (postTypeFilter != null && postTypeFilter.isNotEmpty && postTypeFilter != 'all') {
        query = query.eq('post_type', postTypeFilter);
      }

      if (communityId != null && communityId.isNotEmpty) {
        query = query.eq('community_id', communityId);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        query = query.ilike('content', '%${searchQuery.trim()}%');
      }

      if (sortBy == 'Trending') {
        query = query.order('likes', ascending: false);
      } else {
        query = query.order('created_at', ascending: false);
      }

      final response = await query.range(offset, offset + limit - 1);
      if (response != null && response is List) {
        return response
            .map((item) => Post.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error in PostRepository.fetchRecentPostsFiltered: $e');
      return [];
    }
  }

  /// Fetch Reels (Video Posts)
  static Future<List<Post>> fetchReels({
    int limit = 15,
    int offset = 0,
  }) async {
    try {
      final response = await Supabase.instance.client
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(username, avatar_url)')
          .eq('post_type', 'video')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (response != null && response is List) {
        return response
            .map((item) => Post.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error in PostRepository.fetchReels: $e');
      return [];
    }
  }

  /// Fetch New Posts
  static Future<List<Post>> fetchNewPosts({
    int limit = 15,
    int offset = 0,
  }) async {
    try {
      final response = await Supabase.instance.client
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(username, avatar_url)')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (response != null && response is List) {
        return response
            .map((item) => Post.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error in PostRepository.fetchNewPosts: $e');
      return [];
    }
  }

  /// Fetch Saved / Bookmarked Posts
  static Future<List<Post>> fetchSavedPosts({
    int limit = 15,
    int offset = 0,
  }) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return [];

      final bookmarksRes = await Supabase.instance.client
          .from('post_bookmarks')
          .select('post_id')
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (bookmarksRes == null || bookmarksRes is! List || bookmarksRes.isEmpty) {
        return [];
      }

      final postIds = (bookmarksRes as List).map((b) => b['post_id'].toString()).toList();

      final postsRes = await Supabase.instance.client
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(username, avatar_url)')
          .filter('id', 'in', postIds);

      if (postsRes != null && postsRes is List) {
        return postsRes
            .map((item) => Post.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error in PostRepository.fetchSavedPosts: $e');
      return [];
    }
  }
}
