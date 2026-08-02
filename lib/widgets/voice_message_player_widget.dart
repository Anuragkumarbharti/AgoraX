import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../core/theme.dart';
import '../models/chat_model.dart';

class VoiceMessagePlayerWidget extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;

  const VoiceMessagePlayerWidget({
    Key? key,
    required this.message,
    required this.isMe,
  }) : super(key: key);

  @override
  State<VoiceMessagePlayerWidget> createState() => _VoiceMessagePlayerWidgetState();
}

class _VoiceMessagePlayerWidgetState extends State<VoiceMessagePlayerWidget> {
  VideoPlayerController? _playerCtrl;
  bool _isInitializing = false;
  bool _isError = false;
  bool _isPlaying = false;
  double _currentSpeed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  final List<double> _speeds = [1.0, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (_isInitializing) return;
    setState(() => _isInitializing = true);

    try {
      final String? audioPath = widget.message.mediaUrl ?? widget.message.content;
      if (audioPath == null || audioPath.isEmpty) {
        setState(() {
          _isInitializing = false;
          _isError = true;
        });
        return;
      }

      File? audioFile;
      if (audioPath.startsWith('http://') || audioPath.startsWith('https://')) {
        // Download once and cache locally
        final file = await DefaultCacheManager().getSingleFile(audioPath);
        audioFile = file;
      } else {
        final localFile = File(audioPath);
        if (await localFile.exists()) {
          audioFile = localFile;
        }
      }

      if (audioFile != null && await audioFile.exists()) {
        _playerCtrl = VideoPlayerController.file(audioFile);
      } else if (audioPath.startsWith('http')) {
        _playerCtrl = VideoPlayerController.networkUrl(Uri.parse(audioPath));
      }

      if (_playerCtrl != null) {
        await _playerCtrl!.initialize();
        _duration = _playerCtrl!.value.duration;
        
        _playerCtrl!.addListener(() {
          if (!mounted) return;
          final pos = _playerCtrl!.value.position;
          final isP = _playerCtrl!.value.isPlaying;
          setState(() {
            _position = pos;
            _isPlaying = isP;
          });

          if (pos >= _duration && _duration > Duration.zero) {
            _playerCtrl!.pause();
            _playerCtrl!.seekTo(Duration.zero);
            setState(() => _isPlaying = false);
          }
        });
      }
    } catch (e) {
      debugPrint('VoiceMessagePlayer error: $e');
      _isError = true;
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  @override
  void dispose() {
    _playerCtrl?.dispose();
    super.dispose();
  }

  void _togglePlayPause() async {
    if (_playerCtrl == null || !_playerCtrl!.value.isInitialized) {
      await _initPlayer();
    }

    if (_playerCtrl != null && _playerCtrl!.value.isInitialized) {
      HapticFeedback.selectionClick();
      if (_isPlaying) {
        await _playerCtrl!.pause();
      } else {
        await _playerCtrl!.setPlaybackSpeed(_currentSpeed);
        await _playerCtrl!.play();
      }
    }
  }

  void _cycleSpeed() {
    HapticFeedback.selectionClick();
    final idx = _speeds.indexOf(_currentSpeed);
    final nextIdx = (idx + 1) % _speeds.length;
    final nextSpeed = _speeds[nextIdx];
    setState(() {
      _currentSpeed = nextSpeed;
    });
    if (_playerCtrl != null && _playerCtrl!.value.isInitialized) {
      _playerCtrl!.setPlaybackSpeed(nextSpeed);
    }
  }

  void _stopPlayer() {
    if (_playerCtrl != null && _playerCtrl!.value.isInitialized) {
      _playerCtrl!.pause();
      _playerCtrl!.seekTo(Duration.zero);
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isMe ? Colors.white : AppTheme.textPrimary;
    final secondaryTextColor = widget.isMe ? Colors.white70 : AppTheme.textTertiary;
    final accentColor = widget.isMe ? Colors.white : AppTheme.primaryColor;

    final Duration effectiveDuration = _duration > Duration.zero 
        ? _duration 
        : Duration(seconds: widget.message.audioDurationSeconds > 0 ? widget.message.audioDurationSeconds : 10);

    return Container(
      constraints: const BoxConstraints(minWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Play/Pause Button
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isMe ? Colors.white.withOpacity(0.25) : AppTheme.primaryColor.withOpacity(0.15),
                  ),
                  child: _isInitializing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accentColor,
                          ),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: accentColor,
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 8),

              // Stop Button (if playing)
              if (_isPlaying) ...[
                GestureDetector(
                  onTap: _stopPlayer,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent.withOpacity(0.2),
                    ),
                    child: const Icon(Icons.stop_rounded, color: Colors.redAccent, size: 16),
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // Interactive Slider / Seekbar
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: accentColor,
                    inactiveTrackColor: widget.isMe ? Colors.white.withOpacity(0.3) : AppTheme.borderColor,
                    thumbColor: accentColor,
                  ),
                  child: Slider(
                    value: _position.inMilliseconds.toDouble().clamp(0, effectiveDuration.inMilliseconds.toDouble()),
                    max: effectiveDuration.inMilliseconds.toDouble() > 0 ? effectiveDuration.inMilliseconds.toDouble() : 1.0,
                    onChanged: (val) {
                      if (_playerCtrl != null && _playerCtrl!.value.isInitialized) {
                        _playerCtrl!.seekTo(Duration(milliseconds: val.toInt()));
                      }
                    },
                  ),
                ),
              ),

              // Speed Pill Toggle (1x / 1.5x / 2x)
              GestureDetector(
                onTap: _cycleSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.isMe ? Colors.white.withOpacity(0.2) : AppTheme.bgDark.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: widget.isMe ? Colors.white30 : AppTheme.borderColor, width: 0.5),
                  ),
                  child: Text(
                    '${_currentSpeed == 1.0 ? '1' : _currentSpeed}x',
                    style: GoogleFonts.outfit(
                      color: textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 2),

          // Duration and Status Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isPlaying ? '-${_formatDuration(effectiveDuration - _position)}' : _formatDuration(effectiveDuration),
                style: GoogleFonts.outfit(color: secondaryTextColor, fontSize: 10, fontWeight: FontWeight.w500),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('h:mm a').format(widget.message.timestamp),
                    style: TextStyle(fontSize: 9, color: secondaryTextColor),
                  ),
                  if (widget.isMe) ...[
                    const SizedBox(width: 4),
                    _buildDeliveryStatusTick(widget.message.status),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryStatusTick(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time_rounded, size: 10, color: Colors.white60);
      case MessageStatus.sent:
        return const Icon(Icons.done_rounded, size: 11, color: Colors.white60);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded, size: 11, color: Colors.white60);
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded, size: 11, color: Color(0xFF60A5FA));
    }
  }
}
