import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class VoiceMessageRecorderWidget extends StatefulWidget {
  final Function(int seconds, String filePath) onSend;
  final VoidCallback onCancel;
  final bool isLocked;

  const VoiceMessageRecorderWidget({
    Key? key,
    required this.onSend,
    required this.onCancel,
    this.isLocked = false,
  }) : super(key: key);

  @override
  State<VoiceMessageRecorderWidget> createState() => _VoiceMessageRecorderWidgetState();
}

class _VoiceMessageRecorderWidgetState extends State<VoiceMessageRecorderWidget>
    with SingleTickerProviderStateMixin {
  int _seconds = 0;
  Timer? _timer;
  late AnimationController _animCtrl;
  final List<double> _waveBars = List.generate(20, (_) => 0.2);
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _seconds++;
        for (int i = 0; i < _waveBars.length; i++) {
          _waveBars[i] = (0.2 + _random.nextDouble() * 0.8).clamp(0.1, 1.0);
        }
      });
      if (_seconds >= 120) {
        _send();
      }
    });
  }

  void _send() {
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    widget.onSend(_seconds, 'voice_rec_${DateTime.now().millisecondsSinceEpoch}.m4a');
  }

  void _cancel() {
    _timer?.cancel();
    HapticFeedback.lightImpact();
    widget.onCancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(int sec) {
    final m = (sec ~/ 60).toString().padLeft(1, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.errorColor.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pulse Recording Dot
          FadeTransition(
            opacity: _animCtrl,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: AppTheme.errorColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_seconds),
            style: GoogleFonts.outfit(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),

          // Live Waveform Visualizer
          Expanded(
            child: SizedBox(
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _waveBars.map((heightFactor) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 3,
                    height: 24 * heightFactor,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Action buttons: Cancel / Send (Lock Mode vs Slide Mode)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor, size: 22),
            onPressed: _cancel,
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _send,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
