import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:get/get.dart';
import '../core/theme.dart';

class CustomYoutubePlayer extends StatefulWidget {
  final String videoUrl;
  final String videoTitle;
  final int durationSeconds;
  final VoidCallback onWatchCompleted;

  const CustomYoutubePlayer({
    Key? key,
    required this.videoUrl,
    required this.videoTitle,
    required this.durationSeconds,
    required this.onWatchCompleted,
  }) : super(key: key);

  @override
  State<CustomYoutubePlayer> createState() => _CustomYoutubePlayerState();
}

class _CustomYoutubePlayerState extends State<CustomYoutubePlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  
  // YouTube restrictions tracking
  double _maxDurationSeconds = 0.0;
  double _maxPositionWatched = 0.0;
  double _currentPosition = 0.0;
  double _currentPlaybackSpeed = 1.0;
  bool _watchRequirementMet = false;
  
  Timer? _positionTrackerTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    final uri = Uri.tryParse(widget.videoUrl);
    
    // Check if the URL is a direct video stream. If not, we will use a fallback high-quality video stream 
    // to simulate the YouTube player on platforms where raw YouTube iframe links cannot compile natively.
    final bool isDirectVideo = widget.videoUrl.endsWith('.mp4') || 
                               widget.videoUrl.endsWith('.m3u8') || 
                               widget.videoUrl.contains('mixkit.co');
                               
    final streamUrl = isDirectVideo 
        ? widget.videoUrl 
        : 'https://assets.mixkit.co/videos/preview/mixkit-animation-of-a-man-in-front-of-a-screen-42999-large.mp4';

    final streamUri = Uri.parse(streamUrl);

    _controller = VideoPlayerController.networkUrl(streamUri)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isInitialized = true;
          _maxDurationSeconds = _controller!.value.duration.inSeconds.toDouble();
          if (_maxDurationSeconds == 0) {
            _maxDurationSeconds = widget.durationSeconds.toDouble();
          }
          _controller!.play();
        });
        _startTrackingPosition();
      }).catchError((error) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
        });
      });
  }

  void _startTrackingPosition() {
    _positionTrackerTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_controller == null || !_controller!.value.isInitialized) return;
      
      final pos = _controller!.value.position.inMilliseconds / 1000.0;
      
      setState(() {
        _currentPosition = pos;
        
        // Disable Skip Forward: 
        // If current position is ahead of max watched by more than 1.5 seconds,
        // it means they tried to scrub forward. Seek them back to maxPositionWatched.
        if (pos > _maxPositionWatched + 1.5) {
          _controller!.seekTo(Duration(milliseconds: (_maxPositionWatched * 1000).toInt()));
          _currentPosition = _maxPositionWatched;
          Get.snackbar(
            '🔒 Skip Forward Disabled',
            'You must watch the video to unlock the quiz.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppTheme.errorColor.withOpacity(0.9),
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
          );
        } else {
          // Update the maximum position watched so far
          if (pos > _maxPositionWatched) {
            _maxPositionWatched = pos;
          }
        }

        // Check 90% watch time requirement
        if (!_watchRequirementMet && _maxDurationSeconds > 0) {
          final watchedPercentage = _maxPositionWatched / _maxDurationSeconds;
          if (watchedPercentage >= 0.90) {
            _watchRequirementMet = true;
            widget.onWatchCompleted();
            Get.snackbar(
              '🎉 Quiz Unlocked!',
              'You have watched 90% of the video. You can now start the quiz.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppTheme.accentColor.withOpacity(0.9),
              colorText: Colors.white,
            );
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _positionTrackerTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
  }

  void _changeSpeed() {
    // Only allow 1.0x and 1.25x playback speeds
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Playback Speed',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _speedOption(1.0, 'Normal (1.0x)'),
            _speedOption(1.25, '1.25x'),
            const SizedBox(height: 8),
            Text(
              'Note: Speed is limited to maximum 1.25x for learning validation.',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _speedOption(double speed, String label) {
    final isSelected = _currentPlaybackSpeed == speed;
    return ListTile(
      title: Text(label, style: TextStyle(color: isSelected ? AppTheme.primaryColor : Colors.white)),
      trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
      onTap: () {
        setState(() {
          _currentPlaybackSpeed = speed;
          _controller?.setPlaybackSpeed(speed);
        });
        Get.back();
      },
    );
  }

  String _formatDuration(double seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toInt().toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 40),
              const SizedBox(height: 8),
              const Text('Failed to load learning video', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _initializePlayer();
                  });
                },
                child: const Text('Retry'),
              )
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video Player
            GestureDetector(
              onTap: _togglePlay,
              child: VideoPlayer(_controller!),
            ),

            // Top Video Title Overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/e/ef/Youtube_logo.png', // youtube icon
                      width: 24,
                      errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_fill, color: Colors.red, size: 24),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.videoTitle,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Play/Pause Center Indicator
            if (!_controller!.value.isPlaying)
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),

            // Bottom Custom Controls Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Red Progress Indicator
                    Row(
                      children: [
                        Text(
                          _formatDuration(_currentPosition),
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Stack(
                              children: [
                                // Background Bar
                                Container(
                                  height: 4,
                                  color: Colors.white24,
                                ),
                                // Max Watched Range Bar (grayed-out)
                                FractionallySizedBox(
                                  widthFactor: (_maxDurationSeconds > 0)
                                      ? (_maxPositionWatched / _maxDurationSeconds).clamp(0.0, 1.0)
                                      : 0.0,
                                  child: Container(
                                    height: 4,
                                    color: Colors.white38,
                                  ),
                                ),
                                // Active Playing Progress Bar (Red)
                                FractionallySizedBox(
                                  widthFactor: (_maxDurationSeconds > 0)
                                      ? (_currentPosition / _maxDurationSeconds).clamp(0.0, 1.0)
                                      : 0.0,
                                  child: Container(
                                    height: 4,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(_maxDurationSeconds),
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Action controls (Play/Pause, Speed, Watch progress text)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _togglePlay,
                        ),
                        
                        // Watch Time Progress Info Text
                        Text(
                          'Watched: ${(_maxPositionWatched / _maxDurationSeconds * 100).toInt()}% (90% required)',
                          style: TextStyle(
                            color: _watchRequirementMet ? AppTheme.accentColor : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        // Playback Speed Button
                        GestureDetector(
                          onTap: _changeSpeed,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_currentPlaybackSpeed}x',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
