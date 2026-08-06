import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/room/room_model.dart';
import '../../../core/theme.dart';

/// Global static tracking for room lockout attempts across dialog sessions
class RoomLockoutTracker {
  static final Map<String, int> _failedAttempts = {};
  static final Map<String, DateTime> _lockoutUntil = {};

  static int getFailedAttempts(String roomId) => _failedAttempts[roomId] ?? 0;

  static DateTime? getLockoutUntil(String roomId) {
    final until = _lockoutUntil[roomId];
    if (until != null && DateTime.now().isAfter(until)) {
      _lockoutUntil.remove(roomId);
      return null;
    }
    return until;
  }

  static void recordFailedAttempt(String roomId) {
    final attempts = (_failedAttempts[roomId] ?? 0) + 1;
    _failedAttempts[roomId] = attempts;

    // iPhone-style exponential lockout tiers:
    // Attempt 3: 1 min (60s)
    // Attempt 4: 5 mins (300s)
    // Attempt 5: 15 mins (900s)
    // Attempt 6+: 60 mins (3600s)
    int lockoutSeconds = 0;
    if (attempts == 3) {
      lockoutSeconds = 60;
    } else if (attempts == 4) {
      lockoutSeconds = 300;
    } else if (attempts == 5) {
      lockoutSeconds = 900;
    } else if (attempts >= 6) {
      lockoutSeconds = 3600;
    }

    if (lockoutSeconds > 0) {
      _lockoutUntil[roomId] = DateTime.now().add(Duration(seconds: lockoutSeconds));
    }
  }

  static void resetAttempts(String roomId) {
    _failedAttempts.remove(roomId);
    _lockoutUntil.remove(roomId);
  }
}

class RoomPasswordDialog extends StatefulWidget {
  final VoiceRoom room;
  final bool isInvalidPass;

  const RoomPasswordDialog({
    Key? key,
    required this.room,
    this.isInvalidPass = false,
  }) : super(key: key);

  @override
  State<RoomPasswordDialog> createState() => _RoomPasswordDialogState();
}

class _RoomPasswordDialogState extends State<RoomPasswordDialog> {
  final List<TextEditingController> _pinControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.isInvalidPass) {
      RoomLockoutTracker.recordFailedAttempt(widget.room.id);
    }
    _checkLockoutState();
  }

  void _checkLockoutState() {
    final until = RoomLockoutTracker.getLockoutUntil(widget.room.id);
    if (until != null) {
      final remaining = until.difference(DateTime.now()).inSeconds;
      if (remaining > 0) {
        setState(() {
          _secondsRemaining = remaining;
          _errorMessage = _getLockoutErrorMessage(remaining);
        });
        _startTimer();
        return;
      }
    }

    final failedCount = RoomLockoutTracker.getFailedAttempts(widget.room.id);
    if (widget.isInvalidPass) {
      setState(() {
        _errorMessage = 'Incorrect Password. (${3 - (failedCount % 3)} attempts remaining)';
      });
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final until = RoomLockoutTracker.getLockoutUntil(widget.room.id);
      if (until == null) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _errorMessage = null;
        });
      } else {
        final remaining = until.difference(DateTime.now()).inSeconds;
        if (remaining <= 0) {
          timer.cancel();
          setState(() {
            _secondsRemaining = 0;
            _errorMessage = null;
          });
        } else {
          setState(() {
            _secondsRemaining = remaining;
            _errorMessage = _getLockoutErrorMessage(remaining);
          });
        }
      }
    });
  }

  String _getLockoutErrorMessage(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    final formattedTime = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    return '🔒 Security Lockout: Try again in $formattedTime';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (var c in _pinControllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onPinChanged(int index, String value) {
    if (_secondsRemaining > 0) return;
    if (value.isNotEmpty) {
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _submitPin();
      }
    } else if (index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _submitPin() {
    if (_secondsRemaining > 0) return;
    final enteredPin = _pinControllers.map((c) => c.text).join();
    if (enteredPin.length < 4) return;
    Navigator.pop(context, enteredPin);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLocked = _secondsRemaining > 0;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle indicator
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Lock Icon Badge
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (isLocked ? Colors.redAccent : const Color(0xFF8B5CF6)).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLocked ? Icons.timer_outlined : Icons.lock_rounded,
              color: isLocked ? Colors.redAccent : const Color(0xFF8B5CF6),
              size: 36,
            ),
          ),
          const SizedBox(height: 14),

          // Title & Subtitle
          Text(
            isLocked ? 'Room Access Locked' : 'Password Protected',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isLocked
                ? 'Too many incorrect attempts. Please wait.'
                : 'Enter 4 Digit Password to join ${widget.room.name}',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: context.caption,
            ),
          ),
          const SizedBox(height: 24),

          // 4-Digit PIN Input Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              4,
              (index) => Container(
                width: 52,
                height: 58,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isLocked
                        ? Colors.redAccent.withOpacity(0.5)
                        : _errorMessage != null
                            ? Colors.redAccent
                            : _focusNodes[index].hasFocus
                                ? const Color(0xFF8B5CF6)
                                : Colors.transparent,
                    width: 1.8,
                  ),
                ),
                child: TextField(
                  controller: _pinControllers[index],
                  focusNode: _focusNodes[index],
                  enabled: !isLocked,
                  autofocus: index == 0 && !isLocked,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  obscureText: true,
                  obscuringCharacter: '•',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                  ),
                  onChanged: (val) => _onPinChanged(index, val),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Error Message / Lockout Countdown Banner
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: (isLocked ? Colors.red.shade900 : Colors.redAccent).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _errorMessage!,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isLocked ? Colors.redAccent : Colors.redAccent,
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Confirm & Cancel Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: !isLocked ? _submitPin : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    disabledBackgroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Submit',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
