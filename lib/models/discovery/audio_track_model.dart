class AudioTrack {
  final String id;
  final String title;
  final String artist;
  final String coverUrl;
  final String audioUrl;
  final String licenseType;
  final int duration;
  final int startOffset;
  final int endOffset;
  final bool isOriginalAudio;
  final int usageCount;
  final double trendScore;

  AudioTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.coverUrl = '',
    required this.audioUrl,
    this.licenseType = 'platform',
    this.duration = 30,
    this.startOffset = 0,
    this.endOffset = 30,
    this.isOriginalAudio = false,
    this.usageCount = 0,
    this.trendScore = 0.0,
  });

  factory AudioTrack.fromJson(Map<String, dynamic> json) {
    return AudioTrack(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Audio Track',
      artist: json['artist']?.toString() ?? 'Unknown Artist',
      coverUrl: json['cover_url']?.toString() ?? '',
      audioUrl: json['audio_url']?.toString() ?? '',
      licenseType: json['license_type']?.toString() ?? 'platform',
      duration: (json['duration'] as num?)?.toInt() ?? 30,
      startOffset: (json['start_offset'] as num?)?.toInt() ?? 0,
      endOffset: (json['end_offset'] as num?)?.toInt() ?? 30,
      isOriginalAudio: json['is_original_audio'] == true,
      usageCount: (json['audio_usage_count'] as num?)?.toInt() ?? 0,
      trendScore: (json['trend_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'cover_url': coverUrl,
      'audio_url': audioUrl,
      'license_type': licenseType,
      'duration': duration,
      'start_offset': startOffset,
      'end_offset': endOffset,
      'is_original_audio': isOriginalAudio,
      'audio_usage_count': usageCount,
      'trend_score': trendScore,
    };
  }
}
