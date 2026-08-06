import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/room/room_model.dart';

class RoomEntryLockBadges extends StatelessWidget {
  final VoiceRoom room;
  final bool compact;

  const RoomEntryLockBadges({
    Key? key,
    required this.room,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final activeLocks = room.activeLocks;

    if (activeLocks.isEmpty) {
      return _buildBadge(
        icon: Icons.lock_open_rounded,
        label: 'Public',
        color: const Color(0xFF10B981),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: activeLocks.map((lock) {
        switch (lock) {
          case 'password':
            return _buildBadge(
              icon: Icons.lock_rounded,
              label: 'Password',
              color: const Color(0xFF8B5CF6),
            );
          case 'followers_only':
            return _buildBadge(
              icon: Icons.favorite_rounded,
              label: 'Followers',
              color: Colors.pinkAccent,
            );
          case 'following_only':
            return _buildBadge(
              icon: Icons.arrow_forward_rounded,
              label: 'Following',
              color: Colors.blueAccent,
            );
          case 'friends_only':
            return _buildBadge(
              icon: Icons.people_rounded,
              label: 'Friends',
              color: Colors.purpleAccent,
            );
          case 'family_only':
            return _buildBadge(
              icon: Icons.home_rounded,
              label: 'Family',
              color: Colors.amber,
            );
          case 'vip_only':
            return _buildBadge(
              icon: Icons.workspace_premium_rounded,
              label: 'VIP',
              color: Colors.amber.shade700,
            );
          case 'invite_only':
            return _buildBadge(
              icon: Icons.mail_rounded,
              label: 'Invite',
              color: const Color(0xFF10B981),
            );
          default:
            return const SizedBox.shrink();
        }
      }).toList(),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 10 : 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: compact ? 8 : 9,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
