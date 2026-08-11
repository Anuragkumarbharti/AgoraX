import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/community/post_model.dart';
import 'package:creania/models/community/post_type.dart';

void main() {
  group('Post Creation & Data Model Tests', () {
    test('PostType enum serialization & mappings', () {
      expect(PostType.fromString('photo'), PostType.photo);
      expect(PostType.fromString('video'), PostType.video);
      expect(PostType.fromString('audio'), PostType.audio);
      expect(PostType.fromString('pdf'), PostType.pdf);
      expect(PostType.fromString('question'), PostType.question);
      expect(PostType.fromString('mcq'), PostType.mcq);
      expect(PostType.fromString('poll'), PostType.poll);
      expect(PostType.fromString('link'), PostType.link);
      expect(PostType.fromString('text'), PostType.text);
      expect(PostType.fromString('unknown_type'), PostType.text);
    });

    test('Post model JSON parsing with MCQ data', () {
      final json = {
        'id': 'post_123',
        'user_id': 'user_456',
        'community_id': 'comm_789',
        'content': 'Check out this quiz',
        'post_type': 'mcq',
        'caption': 'Check out this quiz',
        'media_url': '',
        'thumbnail_url': '',
        'aspect_ratio': 1.5,
        'likes': 12,
        'comments': 3,
        'shares': 1,
        'is_liked': true,
        'is_bookmarked': false,
        'created_at': DateTime.now().toIso8601String(),
        'mcq_data': {
          'question': 'What is Flutter?',
          'options': [
            {'id': 'opt_0', 'text': 'UI Toolkit', 'is_correct': true},
            {'id': 'opt_1', 'text': 'Database', 'is_correct': false},
          ],
          'explanation': 'Flutter is Google UI Toolkit for cross-platform apps.',
          'timer_seconds': 30,
          'difficulty': 'Easy',
          'xp_reward': 20,
        },
      };

      final post = Post.fromJson(json);

      expect(post.id, 'post_123');
      expect(post.postType, PostType.mcq);
      expect(post.aspectRatio, 1.5);
      expect(post.isLiked, true);
      expect(post.mcqData, isNotNull);
      expect(post.mcqData!.question, 'What is Flutter?');
      expect(post.mcqData!.options.length, 2);
      expect(post.mcqData!.options.first.isCorrect, true);
      expect(post.mcqData!.xpReward, 20);
    });

    test('PollData percentage calculation', () {
      final poll = PollData(
        question: 'Which framework do you prefer?',
        options: [
          PollOption(id: 'opt_a', text: 'Flutter'),
          PollOption(id: 'opt_b', text: 'React Native'),
        ],
        totalVotes: 10,
        optionCounts: {
          'opt_a': 8,
          'opt_b': 2,
        },
      );

      expect(poll.getPercentage('opt_a'), 80.0);
      expect(poll.getPercentage('opt_b'), 20.0);
      expect(poll.getPercentage('opt_c'), 0.0);
    });

    test('PDF Post parsing with media metadata', () {
      final json = {
        'id': 'pdf_post_001',
        'user_id': 'user_111',
        'post_type': 'pdf',
        'caption': 'Flutter Performance Whitepaper',
        'media_url': 'https://storage.com/whitepaper.pdf',
        'thumbnail_url': 'https://storage.com/whitepaper_thumb.jpg',
        'aspect_ratio': 2.5,
        'media_metadata': {
          'file_name': 'whitepaper.pdf',
          'page_count': 14,
          'file_size': 3500000,
        },
        'likes': 45,
        'comments': 7,
        'shares': 12,
        'created_at': DateTime.now().toIso8601String(),
      };

      final post = Post.fromJson(json);

      expect(post.postType, PostType.pdf);
      expect(post.thumbnailUrl, 'https://storage.com/whitepaper_thumb.jpg');
      expect(post.mediaMetadata['page_count'], 14);
      expect(post.mediaMetadata['file_name'], 'whitepaper.pdf');
    });
  });
}
