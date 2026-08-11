import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/community/post_type.dart';
import '../../models/discovery/audio_track_model.dart';
import '../post_creation/create_post_screen.dart';

class AudioDetailScreen extends StatefulWidget {
  final AudioTrack audioTrack;

  const AudioDetailScreen({Key? key, required this.audioTrack}) : super(key: key);

  @override
  State<AudioDetailScreen> createState() => _AudioDetailScreenState();
}

class _AudioDetailScreenState extends State<AudioDetailScreen> {
  bool _isPlaying = false;

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.audioTrack;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        title: Text(
          'Original Audio',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Track Card Header
          Container(
            padding: const EdgeInsets.all(20),
            color: AppTheme.cardBg,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: track.coverUrl.isNotEmpty
                      ? Image.network(track.coverUrl, width: 80, height: 80, fit: BoxFit.cover)
                      : Container(
                          width: 80,
                          height: 80,
                          color: AppTheme.surfaceColor,
                          child: const Icon(Icons.music_note, color: AppTheme.primaryColor, size: 40),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.artist,
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${track.usageCount} reels • Trending Score: ${track.trendScore.toInt()}',
                        style: GoogleFonts.inter(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _togglePlay,
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: AppTheme.primaryColor,
                    size: 44,
                  ),
                ),
              ],
            ),
          ),

          // Prominent CTA Button: "Use Audio"
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  _audioPlayer.stop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreatePostScreen(
                        initialType: PostType.reel,
                        initialAudioTrack: track,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.movie_creation_outlined, color: Colors.white),
                label: Text(
                  'Use Audio in Reel / Post',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),

          const Divider(color: Colors.white10),

          // Audio Posts Grid placeholder / header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('Posts using this audio', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),

          Expanded(
            child: Center(
              child: Text(
                'Reels using this track will appear here',
                style: GoogleFonts.inter(color: Colors.white38),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
