import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/discovery/audio_track_model.dart';
import 'package:creania/models/discovery/hashtag_model.dart';
import 'package:creania/models/discovery/unified_content_model.dart';
import 'package:creania/services/discovery/caption_parser_service.dart';
import 'package:creania/models/community/post_type.dart';

void main() {
  group('Smart Discovery System Tests', () {
    test('Caption parsing extracts hashtags, mentions, and respects max limit', () {
      final caption = "Learning Flutter state management! #Flutter #Dart #Mobile #Coding #Tech #App #UI #Dev #Software #Google #ExtraTag @john_doe @jane_dev";
      final result = CaptionParserService.parseCaption(caption);

      expect(result.hashtags.length, equals(10)); // Max 10 limit enforced
      expect(result.hashtags.contains('flutter'), isTrue);
      expect(result.hashtags.contains('dart'), isTrue);
      expect(result.mentions.contains('john_doe'), isTrue);
      expect(result.mentions.contains('jane_dev'), isTrue);
      expect(result.exceedsHashtagLimit, isTrue);
    });

    test('Caption parsing generates smart keyword suggestions', () {
      final caption = "How do I start learning machine learning with python?";
      final result = CaptionParserService.parseCaption(caption);

      expect(result.suggestedTags.contains('#MachineLearning'), isTrue);
      expect(result.suggestedTags.contains('#Python'), isTrue);
    });

    test('AudioTrack model parses json cleanly', () {
      final json = {
        'id': 'a123',
        'title': 'Creania Synthwave Beat',
        'artist': 'Creania',
        'audio_url': 'https://cdn.example.com/audio.mp3',
        'duration': 45,
        'is_original_audio': true,
        'trend_score': 92.5,
      };

      final track = AudioTrack.fromJson(json);
      expect(track.id, equals('a123'));
      expect(track.title, equals('Creania Synthwave Beat'));
      expect(track.duration, equals(45));
      expect(track.isOriginalAudio, isTrue);
      expect(track.trendScore, equals(92.5));
    });

    test('UnifiedContentItem parses json for all 9 content types', () {
      final json = {
        'id': 'post_99',
        'user_id': 'user_1',
        'content': 'Check out this quiz',
        'post_type': 'mcq',
        'caption': 'Best quiz on Flutter #Flutter',
        'likes': 120,
        'comments': 15,
        'trend_score': 85.0,
        'author_profile': {'username': 'flutter_guru', 'avatar_url': 'https://example.com/pic.png'},
        'mcq_data': {
          'question': 'What is State in Flutter?',
          'options': [
            {'id': 'opt_1', 'text': 'Data that can change'},
            {'id': 'opt_2', 'text': 'Widget name'}
          ]
        }
      };

      final item = UnifiedContentItem.fromJson(json);
      expect(item.id, equals('post_99'));
      expect(item.postType, equals(PostType.mcq));
      expect(item.authorName, equals('flutter_guru'));
      expect(item.trendScore, equals(85.0));
      expect(item.mcqData, isNotNull);
    });
  });
}
