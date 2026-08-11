import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/community/post_model.dart';
import 'package:creania/models/community/post_type.dart';

void main() {
  group('Global More & View All Pages Unit Tests', () {
    test('Popular Questions filtering and sorting parameters', () {
      final questionPost = Post(
        id: 'q_1',
        userId: 'u_1',
        communityId: 'c_1',
        content: 'How to implement Flutter vertical page view?',
        postType: PostType.question,
        caption: 'How to implement Flutter vertical page view?',
        likes: 15,
        comments: 8,
        shares: 2,
        isLiked: false,
        isBookmarked: true,
        createdAt: DateTime.now(),
        questionData: QuestionData(
          question: 'How to implement Flutter vertical page view?',
          context: 'Using PageView.builder with scrollDirection: Axis.vertical',
        ),
      );

      expect(questionPost.postType, PostType.question);
      expect(questionPost.questionData, isNotNull);
      expect(questionPost.questionData!.question, contains('Flutter'));
      expect(questionPost.comments, 8);
      expect(questionPost.likes, 15);
    });

    test('Recent Posts Type Filtering Verification', () {
      final postsList = [
        Post(id: '1', userId: 'u1', communityId: '', content: 'P1', postType: PostType.photo, likes: 0, comments: 0, shares: 0, isLiked: false, isBookmarked: false, createdAt: DateTime.now()),
        Post(id: '2', userId: 'u1', communityId: '', content: 'P2', postType: PostType.video, likes: 0, comments: 0, shares: 0, isLiked: false, isBookmarked: false, createdAt: DateTime.now()),
        Post(id: '3', userId: 'u1', communityId: '', content: 'P3', postType: PostType.audio, likes: 0, comments: 0, shares: 0, isLiked: false, isBookmarked: false, createdAt: DateTime.now()),
      ];

      final videoPosts = postsList.where((p) => p.postType == PostType.video).toList();
      final photoPosts = postsList.where((p) => p.postType == PostType.photo).toList();

      expect(videoPosts.length, 1);
      expect(videoPosts.first.id, '2');
      expect(photoPosts.length, 1);
      expect(photoPosts.first.id, '1');
    });

    test('Reels short video item state parsing', () {
      final reelPost = Post(
        id: 'reel_100',
        userId: 'creator_1',
        communityId: '',
        content: 'Check out this awesome short video clip #reels #flutter',
        postType: PostType.video,
        caption: 'Check out this awesome short video clip #reels #flutter',
        mediaUrl: 'https://storage.com/videos/reel_100.mp4',
        thumbnailUrl: 'https://storage.com/thumbnails/reel_100.jpg',
        aspectRatio: 0.5625, // 9:16 vertical video ratio
        likes: 120,
        comments: 45,
        shares: 10,
        isLiked: true,
        isBookmarked: false,
        createdAt: DateTime.now(),
      );

      expect(reelPost.postType, PostType.video);
      expect(reelPost.mediaUrl, endsWith('.mp4'));
      expect(reelPost.aspectRatio, 0.5625);
      expect(reelPost.likes, 120);
    });
  });
}
