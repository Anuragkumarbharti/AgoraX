class CaptionParserResult {
  final List<String> hashtags;
  final List<String> mentions;
  final List<String> suggestedTags;
  final bool exceedsHashtagLimit;

  CaptionParserResult({
    required this.hashtags,
    required this.mentions,
    required this.suggestedTags,
    this.exceedsHashtagLimit = false,
  });
}

class CaptionParserService {
  static const int maxHashtags = 10;

  static CaptionParserResult parseCaption(String text) {
    final RegExp tagRegExp = RegExp(r'#([a-zA-Z0-9_]+)');
    final RegExp mentionRegExp = RegExp(r'@([a-zA-Z0-9_]+)');

    final Set<String> extractedTags = {};
    final Set<String> extractedMentions = {};

    for (final match in tagRegExp.allMatches(text)) {
      final tag = match.group(1);
      if (tag != null && tag.isNotEmpty) {
        extractedTags.add(tag.toLowerCase());
      }
    }

    for (final match in mentionRegExp.allMatches(text)) {
      final mention = match.group(1);
      if (mention != null && mention.isNotEmpty) {
        extractedMentions.add(mention);
      }
    }

    final bool exceedsLimit = extractedTags.length > maxHashtags;

    // Smart Recommendations based on caption keywords
    final List<String> smartSuggestions = _generateKeywordSuggestions(text, extractedTags);

    return CaptionParserResult(
      hashtags: extractedTags.take(maxHashtags).toList(),
      mentions: extractedMentions.toList(),
      suggestedTags: smartSuggestions,
      exceedsHashtagLimit: exceedsLimit,
    );
  }

  static List<String> _generateKeywordSuggestions(String text, Set<String> existingTags) {
    final lower = text.toLowerCase();
    final Map<String, List<String>> keywordMap = {
      'flutter': ['#Flutter', '#Dart', '#MobileDev', '#Widget'],
      'python': ['#Python', '#DataScience', '#AI', '#Coding'],
      'machine learning': ['#MachineLearning', '#AI', '#DeepLearning', '#Python'],
      'ai': ['#AI', '#ArtificialIntelligence', '#Tech', '#Future'],
      'exam': ['#ExamPrep', '#StudyGram', '#Quiz', '#Preparation'],
      'quiz': ['#QuizTime', '#MCQ', '#Trivia', '#Knowledge'],
      'code': ['#Programming', '#Developer', '#CodeLife', '#Tech'],
      'design': ['#UIUX', '#Design', '#Figma', '#Creative'],
      'college': ['#CampusLife', '#Student', '#StudyGroup', '#Creania'],
    };

    final Set<String> suggestions = {};
    keywordMap.forEach((keyword, tags) {
      if (lower.contains(keyword)) {
        for (var t in tags) {
          final clean = t.replaceAll('#', '').toLowerCase();
          if (!existingTags.contains(clean)) {
            suggestions.add(t);
          }
        }
      }
    });

    if (suggestions.isEmpty && existingTags.isEmpty) {
      suggestions.addAll(['#Trending', '#Creania', '#Study', '#Learn']);
    }

    return suggestions.take(6).toList();
  }
}
