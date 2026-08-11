import 'package:flutter/material.dart';

enum PostType {
  text,
  photo,
  video,
  reel,
  audio,
  pdf,
  question,
  mcq,
  poll,
  link;

  String get value {
    switch (this) {
      case PostType.text:
        return 'text';
      case PostType.photo:
        return 'photo';
      case PostType.video:
        return 'video';
      case PostType.reel:
        return 'reel';
      case PostType.audio:
        return 'audio';
      case PostType.pdf:
        return 'pdf';
      case PostType.question:
        return 'question';
      case PostType.mcq:
        return 'mcq';
      case PostType.poll:
        return 'poll';
      case PostType.link:
        return 'link';
    }
  }

  static PostType fromString(String? type) {
    if (type == null) return PostType.text;
    switch (type.toLowerCase()) {
      case 'photo':
      case 'image':
        return PostType.photo;
      case 'video':
        return PostType.video;
      case 'reel':
      case 'reels':
      case 'short':
        return PostType.reel;
      case 'audio':
        return PostType.audio;
      case 'pdf':
      case 'document':
      case 'doc':
        return PostType.pdf;
      case 'question':
        return PostType.question;
      case 'mcq':
      case 'quiz':
        return PostType.mcq;
      case 'poll':
        return PostType.poll;
      case 'link':
      case 'url':
        return PostType.link;
      case 'text':
      default:
        return PostType.text;
    }
  }

  String get displayName {
    switch (this) {
      case PostType.text:
        return 'Text';
      case PostType.photo:
        return 'Photo';
      case PostType.video:
        return 'Video';
      case PostType.reel:
        return 'Reel';
      case PostType.audio:
        return 'Audio';
      case PostType.pdf:
        return 'PDF';
      case PostType.question:
        return 'Question';
      case PostType.mcq:
        return 'MCQ / Quiz';
      case PostType.poll:
        return 'Poll';
      case PostType.link:
        return 'Link';
    }
  }

  String get emoji {
    switch (this) {
      case PostType.text:
        return '📝';
      case PostType.photo:
        return '🖼️';
      case PostType.video:
        return '🎥';
      case PostType.reel:
        return '🎬';
      case PostType.audio:
        return '🎵';
      case PostType.pdf:
        return '📄';
      case PostType.question:
        return '❓';
      case PostType.mcq:
        return '☑️';
      case PostType.poll:
        return '📊';
      case PostType.link:
        return '🔗';
    }
  }

  IconData get iconData {
    switch (this) {
      case PostType.text:
        return Icons.notes_rounded;
      case PostType.photo:
        return Icons.photo_library_rounded;
      case PostType.video:
        return Icons.videocam_rounded;
      case PostType.reel:
        return Icons.movie_creation_rounded;
      case PostType.audio:
        return Icons.graphic_eq_rounded;
      case PostType.pdf:
        return Icons.picture_as_pdf_rounded;
      case PostType.question:
        return Icons.help_outline_rounded;
      case PostType.mcq:
        return Icons.quiz_rounded;
      case PostType.poll:
        return Icons.poll_rounded;
      case PostType.link:
        return Icons.link_rounded;
    }
  }

  Color get color {
    switch (this) {
      case PostType.text:
        return const Color(0xFF6366F1);
      case PostType.photo:
        return const Color(0xFFEC4899);
      case PostType.video:
        return const Color(0xFFEF4444);
      case PostType.reel:
        return const Color(0xFFFF0050);
      case PostType.audio:
        return const Color(0xFF8B5CF6);
      case PostType.pdf:
        return const Color(0xFFF59E0B);
      case PostType.question:
        return const Color(0xFF10B981);
      case PostType.mcq:
        return const Color(0xFF06B6D4);
      case PostType.poll:
        return const Color(0xFF3B82F6);
      case PostType.link:
        return const Color(0xFF14B8A6);
    }
  }
}
