import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/room/room_model.dart';
import '../../../services/room/room_entry_permission_engine.dart';
import '../../../services/room/room_moderation_controller.dart';
import '../../../core/theme.dart';

class RoomEntryDeniedSheet extends StatefulWidget {
  final VoiceRoom room;
  final RoomEntryResult result;
  final VoidCallback? onPasswordTap;

  const RoomEntryDeniedSheet({
    Key? key,
    required this.room,
    required this.result,
    this.onPasswordTap,
  }) : super(key: key);

  @override
  State<RoomEntryDeniedSheet> createState() => _RoomEntryDeniedSheetState();
}

class _RoomEntryDeniedSheetState extends State<RoomEntryDeniedSheet> {
  Timer? _countdownTimer;
  Duration _remainingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.result.status == RoomEntryStatus.temporaryKick &&
        widget.result.kickEntry != null) {
      _remainingDuration = widget.result.kickEntry!.remainingTime;
      _startCountdownTimer();
    }
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      final remaining = widget.result.kickEntry?.remainingTime ?? Duration.zero;
      setState(() {
        _remainingDuration = remaining;
      });
      if (remaining.inSeconds <= 0) {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return '00 Hours 00 Minutes 00 Seconds';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')} Hours ${minutes.toString().padLeft(2, '0')} Minutes ${seconds.toString().padLeft(2, '0')} Seconds';
  }

  String _formatRejoinDate(DateTime date) {
    final now = DateTime.now();
    final isTomorrow = date.day == now.day + 1;
    final timeStr = DateFormat('hh:mm a').format(date);
    if (isTomorrow) {
      return 'Tomorrow at $timeStr';
    }
    return '${DateFormat('dd MMM yyyy').format(date)} at $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Build view according to status
          if (widget.result.status == RoomEntryStatus.temporaryKick)
            _buildTemporaryKickView(context, isDark)
          else if (widget.result.status == RoomEntryStatus.permanentBan)
            _buildPermanentBanView(context, isDark)
          else
            _buildWhyCantIJoinView(context, isDark),
        ],
      ),
    );
  }

  // ── 1. Temporary Kick View ──────────────────────────────────────────────────
  Widget _buildTemporaryKickView(BuildContext context, bool isDark) {
    final kick = widget.result.kickEntry!;
    final rejoinDate = kick.expiresAt;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.timer_outlined,
            color: Colors.orangeAccent,
            size: 40,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '❌ Removed from Room',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'You have been temporarily removed from this room.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: context.caption,
          ),
        ),
        const SizedBox(height: 20),

        // Kick Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              _buildDetailRow('Removed By', kick.removedBy),
              const Divider(height: 16),
              _buildDetailRow('Reason', kick.reason),
              const Divider(height: 16),
              _buildDetailRow('Restriction', '${kick.restrictionDuration.inHours} Hours'),
              const Divider(height: 16),
              _buildDetailRow(
                'Remaining Time',
                _formatDuration(_remainingDuration),
                valueColor: Colors.orangeAccent,
                isBold: true,
              ),
              const Divider(height: 16),
              _buildDetailRow(
                'Rejoin Available',
                _formatRejoinDate(rejoinDate),
                valueColor: const Color(0xFF10B981),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Disabled Join Button with Countdown
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: null, // Disabled
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: Colors.grey.withOpacity(0.25),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              _remainingDuration.inSeconds > 0
                  ? 'Rejoin Disabled (${_remainingDuration.inHours}h ${(_remainingDuration.inMinutes % 60)}m left)'
                  : 'Rejoin Room',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 2. Permanent Ban View ──────────────────────────────────────────────────
  Widget _buildPermanentBanView(BuildContext context, bool isDark) {
    final ban = widget.result.banEntry!;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.block_rounded,
            color: Colors.redAccent,
            size: 40,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '🚫 Permanently Banned',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'You are permanently banned from entering this room.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: context.caption,
          ),
        ),
        const SizedBox(height: 20),

        // Ban Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              _buildDetailRow('Action By', ban.actionBy),
              const Divider(height: 16),
              _buildDetailRow('Reason', ban.reason),
              const Divider(height: 16),
              _buildDetailRow('Ban Date', DateFormat('dd MMM yyyy').format(ban.banDate)),
              const Divider(height: 16),
              _buildDetailRow('Appeal Status', ban.appealStatus, valueColor: const Color(0xFF10B981)),
            ],
          ),
        ),
        const SizedBox(height: 24),

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
                  'Close',
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
                onPressed: () {
                  Navigator.pop(context);
                  Get.snackbar(
                    'Appeal Submitted 📩',
                    'Your unban appeal has been sent to the Room Owner.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: const Color(0xFF8B5CF6),
                    colorText: Colors.white,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Appeal Ban',
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
    );
  }

  // ── 3. Why Can't I Join? Lock Rejection View ──────────────────────────────
  Widget _buildWhyCantIJoinView(BuildContext context, bool isDark) {
    IconData icon;
    Color color;
    String title;
    String description;
    String? ctaLabel;
    VoidCallback? ctaAction;

    switch (widget.result.status) {
      case RoomEntryStatus.followersOnly:
        icon = Icons.favorite_rounded;
        color = Colors.pinkAccent;
        title = '❤️ Followers Only Room';
        description = widget.result.message;
        ctaLabel = 'Follow Owner';
        ctaAction = () {
          Navigator.pop(context);
          Get.snackbar(
            'Owner Followed ❤️',
            'You are now following ${widget.room.ownerName}. Try joining again!',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.pinkAccent,
            colorText: Colors.white,
          );
        };
        break;

      case RoomEntryStatus.followingOnly:
        icon = Icons.arrow_forward_rounded;
        color = Colors.blueAccent;
        title = '➡ Following Only Room';
        description = widget.result.message;
        break;

      case RoomEntryStatus.friendsOnly:
        icon = Icons.people_rounded;
        color = Colors.purpleAccent;
        title = '👥 Friends Only Room';
        description = widget.result.message;
        ctaLabel = 'Request Friend';
        ctaAction = () {
          Navigator.pop(context);
          Get.snackbar(
            'Friend Request Sent 👥',
            'Request sent to ${widget.room.ownerName}.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.purpleAccent,
            colorText: Colors.white,
          );
        };
        break;

      case RoomEntryStatus.familyOnly:
        icon = Icons.home_rounded;
        color = Colors.amber;
        title = '🏠 Family Only Room';
        description = widget.result.message;
        break;

      case RoomEntryStatus.vipOnly:
        icon = Icons.workspace_premium_rounded;
        color = Colors.amber.shade600;
        title = '👑 VIP Only Room';
        description =
            'Minimum Requirement: VIP ${widget.result.requiredVipLevel}\nYour VIP: VIP ${widget.result.userVipLevel}';
        ctaLabel = 'Upgrade VIP';
        ctaAction = () {
          Navigator.pop(context);
          Get.snackbar(
            'VIP Store 👑',
            'Opening VIP Store to upgrade tier...',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.amber.shade700,
            colorText: Colors.white,
          );
        };
        break;

      case RoomEntryStatus.inviteOnly:
        icon = Icons.mail_rounded;
        color = const Color(0xFF10B981);
        title = '✉ Invitation Required';
        description = widget.result.message;
        ctaLabel = 'Request Invitation';
        ctaAction = () {
          Navigator.pop(context);
          Get.snackbar(
            'Invite Requested ✉',
            'Request sent to Room Owner & Co-Owners.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF10B981),
            colorText: Colors.white,
          );
        };
        break;

      case RoomEntryStatus.roomFull:
        icon = Icons.groups_rounded;
        color = Colors.deepOrangeAccent;
        title = '👥 Room Full';
        description =
            'Current Capacity: ${widget.result.currentCapacity} / ${widget.result.maxCapacity}';
        break;

      case RoomEntryStatus.roomClosed:
      default:
        icon = Icons.error_outline_rounded;
        color = Colors.redAccent;
        title = '🔒 Access Denied';
        description = widget.result.message;
        break;
    }

    return Column(
      children: [
        // "Why Can't I Join?" Header Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Why Can\'t I Join?',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 40),
        ),
        const SizedBox(height: 14),

        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 8),

        Text(
          description,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: context.caption,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        // CTA Buttons
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
                  'Dismiss',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ),
            if (ctaLabel != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: ctaAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    ctaLabel,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: context.caption,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? context.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
