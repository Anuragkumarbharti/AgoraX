import 'dart:convert';

class MCQQuestion {
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;

  MCQQuestion({
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
  });

  Map<String, dynamic> toJson() => {
        'questionText': questionText,
        'options': options,
        'correctAnswerIndex': correctAnswerIndex,
        'explanation': explanation,
      };

  factory MCQQuestion.fromJson(Map<String, dynamic> json) {
    return MCQQuestion(
      questionText: json['questionText'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswerIndex: json['correctAnswerIndex'] ?? 0,
      explanation: json['explanation'] ?? '',
    );
  }
}

class DailyLearningDay {
  final int dayNumber;
  final String youtubeUrl;
  final String videoTitle;
  final int videoDurationSeconds;
  final List<MCQQuestion> questions;
  final int xpReward;
  final int coinReward;
  final String difficultyLevel;
  final DateTime publishDate;

  DailyLearningDay({
    required this.dayNumber,
    required this.youtubeUrl,
    required this.videoTitle,
    required this.videoDurationSeconds,
    required this.questions,
    required this.xpReward,
    required this.coinReward,
    required this.difficultyLevel,
    required this.publishDate,
  });

  Map<String, dynamic> toJson() => {
        'dayNumber': dayNumber,
        'youtubeUrl': youtubeUrl,
        'videoTitle': videoTitle,
        'videoDurationSeconds': videoDurationSeconds,
        'questions': questions.map((q) => q.toJson()).toList(),
        'xpReward': xpReward,
        'coinReward': coinReward,
        'difficultyLevel': difficultyLevel,
        'publishDate': publishDate.toIso8601String(),
      };

  factory DailyLearningDay.fromJson(Map<String, dynamic> json) {
    return DailyLearningDay(
      dayNumber: json['dayNumber'] ?? 1,
      youtubeUrl: json['youtubeUrl'] ?? '',
      videoTitle: json['videoTitle'] ?? '',
      videoDurationSeconds: json['videoDurationSeconds'] ?? 300,
      questions: (json['questions'] as List? ?? [])
          .map((q) => MCQQuestion.fromJson(q))
          .toList(),
      xpReward: json['xpReward'] ?? 50,
      coinReward: json['coinReward'] ?? 10,
      difficultyLevel: json['difficultyLevel'] ?? 'Medium',
      publishDate: DateTime.parse(json['publishDate'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class CategoryLearningPack {
  final String categoryId;
  final List<DailyLearningDay> days;

  CategoryLearningPack({
    required this.categoryId,
    required this.days,
  });

  Map<String, dynamic> toJson() => {
        'categoryId': categoryId,
        'days': days.map((d) => d.toJson()).toList(),
      };

  factory CategoryLearningPack.fromJson(Map<String, dynamic> json) {
    return CategoryLearningPack(
      categoryId: json['categoryId'] ?? '',
      days: (json['days'] as List? ?? [])
          .map((d) => DailyLearningDay.fromJson(d))
          .toList(),
    );
  }
}
