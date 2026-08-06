import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/room/room_model.dart';
import '../../../../services/room/room_controller.dart';
import 'member_list_dialog.dart';
import 'room_audio_settings_dialog.dart';
import 'room_settings_dialog.dart';

/// Helper model for Room Option items
class RoomOptionItem {
  final String id;
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  RoomOptionItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.onTap,
  });
}

/// Clean Minimal Grid Sheet for Room Options
class RoomOptionsSheet extends StatelessWidget {
  final String roomId;
  final VoiceRoom? room;

  const RoomOptionsSheet({
    required this.roomId,
    this.room,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = RoomController.to;
    final activeRoom = room ??
        controller.rooms.firstWhereOrNull((r) => r.id == roomId) ??
        VoiceRoom.dummy(roomId);

    final options = [
      RoomOptionItem(
        id: 'settings',
        title: 'Room Settings',
        icon: Icons.settings,
        onTap: () {
          Get.back();
          Get.dialog(RoomSettingsDialog(roomId: roomId, room: activeRoom));
        },
      ),
      RoomOptionItem(
        id: 'music',
        title: 'Play Music',
        icon: Icons.music_note,
        onTap: () {
          Get.back();
          Get.dialog(RoomAudioSettingsDialog(roomId: roomId));
        },
      ),
      RoomOptionItem(
        id: 'mode',
        title: 'Switch Mode',
        icon: Icons.swap_horiz,
        onTap: () {
          Get.back();
          _showSwitchModeDialog(context, roomId);
        },
      ),
      RoomOptionItem(
        id: 'inbox',
        title: 'Inbox',
        icon: Icons.chat_bubble,
        onTap: () {
          Get.back();
          _showRoomInboxDialog(context);
        },
      ),
      RoomOptionItem(
        id: 'notice',
        title: 'Room Notice',
        icon: Icons.campaign,
        onTap: () {
          Get.back();
          _showRoomNoticeDialog(context, activeRoom);
        },
      ),
      RoomOptionItem(
        id: 'rankings',
        title: 'Rankings',
        icon: Icons.emoji_events,
        onTap: () {
          Get.back();
          _showRoomRankingsDialog(context);
        },
      ),
      RoomOptionItem(
        id: 'events',
        title: 'Events',
        icon: Icons.celebration,
        onTap: () {
          Get.back();
          _showRoomEventsDialog(context);
        },
      ),
      RoomOptionItem(
        id: 'gift_wall',
        title: 'Gift Wall',
        icon: Icons.card_giftcard,
        onTap: () {
          Get.back();
          _showGiftWallDialog(context);
        },
      ),
      RoomOptionItem(
        id: 'share',
        title: 'Share Room',
        icon: Icons.share,
        onTap: () {
          Get.back();
          _showShareRoomDialog(context, activeRoom);
        },
      ),
      RoomOptionItem(
        id: 'effects',
        title: 'Room Effects',
        icon: Icons.auto_awesome,
        onTap: () {
          Get.back();
          _showRoomEffectsDialog(context);
        },
      ),
      RoomOptionItem(
        id: 'members',
        title: 'Member List',
        icon: Icons.group,
        onTap: () {
          Get.back();
          Get.dialog(MemberListDialog(roomId: roomId, room: activeRoom));
        },
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161822),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Drag Handle Bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Sheet Title Bar with Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Room Options',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              GestureDetector(
                onTap: Get.back,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Colors.white10,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Compact Clean Grid (4 Items per row)
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: options.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (context, index) {
                  final item = options[index];
                  return _buildOptionIconTile(item);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// Clean White Icon Button with Subtitle Label
  Widget _buildOptionIconTile(RoomOptionItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Clean White Icon on Translucent Circle Container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1.0,
              ),
            ),
            child: Center(
              child: Icon(
                item.icon,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Subtitle Label
          Text(
            item.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Custom Dialogs for Interactive Features
  // ==========================================

  void _showSwitchModeDialog(BuildContext context, String roomId) {
    final modes = [
      {
        'title': 'Audio Party',
        'desc': 'Standard 10-seat voice stage for chatting & hanging out.',
        'icon': Icons.groups_rounded,
        'color': Colors.cyanAccent
      },
      {
        'title': 'Debate Arena',
        'desc': 'Red vs Blue team seats with timer & vote counters.',
        'icon': Icons.local_fire_department_rounded,
        'color': Colors.redAccent
      },
      {
        'title': 'Mic Pass',
        'desc': 'Sequential queue speaker mode for formal speeches.',
        'icon': Icons.mic_rounded,
        'color': Colors.amberAccent
      },
      {
        'title': 'VIP Lounge',
        'desc': 'Exclusive high-tier seating with VIP status badges.',
        'icon': Icons.workspace_premium_rounded,
        'color': Colors.purpleAccent
      },
      {
        'title': 'Radio & BGM',
        'desc': 'Hi-Fi music streaming studio with DJ controls.',
        'icon': Icons.radio_rounded,
        'color': Colors.greenAccent
      },
    ];

    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF121927),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: Get.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🔄 Switch Room Mode',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final m in modes)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          (m['color'] as Color).withValues(alpha: 0.2),
                      child: Icon(
                        m['icon'] as IconData,
                        color: m['color'] as Color,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      m['title'] as String,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      m['desc'] as String,
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    onTap: () {
                      Get.back();
                      Get.snackbar(
                        'Room Mode Updated',
                        'Mode switched to ${m['title']}',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.purpleAccent,
                        colorText: Colors.white,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomInboxDialog(BuildContext context) {
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF121927),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: Get.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '💬 Room Inbox & Invites',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.mail_rounded, color: Colors.white),
                ),
                title: Text(
                  'System Announcement',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Welcome to Creania Voice Stage! Respect community guidelines.',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.pinkAccent,
                  child: Icon(Icons.card_giftcard, color: Colors.white),
                ),
                title: Text(
                  'Gift Received',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'AnuragK sent you 500 Gold Coins!',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomNoticeDialog(BuildContext context, VoiceRoom room) {
    final controller = TextEditingController(
      text: room.bulletin.isNotEmpty
          ? room.bulletin
          : 'Welcome everyone! Have fun & respect speakers.',
    );

    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF121927),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: Get.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '📢 Room Notice',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Enter room notice or bulletin...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B4DB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Get.back();
                    Get.snackbar(
                      'Notice Published',
                      'Room notice updated successfully!',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.cyan,
                      colorText: Colors.white,
                    );
                  },
                  child: Text(
                    'Save & Publish Notice',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomRankingsDialog(BuildContext context) {
    final ranks = [
      {
        'name': 'AnuragK 👑',
        'xp': '124,500 XP',
        'badge': 'TOP 1',
        'color': Colors.amber
      },
      {
        'name': 'Priya S ✨',
        'xp': '98,200 XP',
        'badge': 'TOP 2',
        'color': Colors.grey.shade300
      },
      {
        'name': 'Vikram R 🚀',
        'xp': '76,100 XP',
        'badge': 'TOP 3',
        'color': Colors.orangeAccent
      },
      {
        'name': 'Sneha M 💎',
        'xp': '45,300 XP',
        'badge': 'TOP 4',
        'color': Colors.cyanAccent
      },
    ];

    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF121927),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: Get.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🏆 Room Leaderboard',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final r in ranks)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: r['color'] as Color,
                    child: Text(
                      r['badge'] as String,
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  title: Text(
                    r['name'] as String,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Text(
                    r['xp'] as String,
                    style: GoogleFonts.poppins(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomEventsDialog(BuildContext context) {
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF121927),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: Get.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🎉 Live Room Events',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.pink.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.pinkAccent),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: Colors.amber,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gold Coin Rush Event 🚀',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Send gifts to earn 2x XP and rare avatar frames!',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showGiftWallDialog(BuildContext context) {
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF121927),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: Get.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🎁 Room Gift Wall',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _giftBadgeItem('👑 Super Car', 'x12'),
                  _giftBadgeItem('🚀 Rocket', 'x45'),
                  _giftBadgeItem('💎 Diamond Ring', 'x99'),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _giftBadgeItem(String name, String count) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_giftcard,
              color: Colors.pinkAccent,
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(name, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11)),
          Text(
            count,
            style: GoogleFonts.poppins(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      );

  void _showShareRoomDialog(BuildContext context, VoiceRoom room) {
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF121927),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: Get.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🔗 Share Room Invite',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, color: Colors.cyanAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'creania.app/room/$roomId',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: 'https://creania.app/room/$roomId'),
                        );
                        Get.back();
                        Get.snackbar(
                          'Link Copied',
                          'Room invite link copied to clipboard!',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.green,
                          colorText: Colors.white,
                        );
                      },
                      child: Text(
                        'Copy',
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomEffectsDialog(BuildContext context) {
    final fxList = [
      {
        'name': 'Neon Purple',
        'icon': Icons.palette_rounded,
        'color': Colors.purpleAccent
      },
      {
        'name': 'Cyber Sparkles',
        'icon': Icons.auto_awesome,
        'color': Colors.cyanAccent
      },
      {
        'name': 'Gold Confetti',
        'icon': Icons.stars,
        'color': Colors.amberAccent
      },
    ];

    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF121927),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: Get.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '✨ Room Effects & Themes',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final fx in fxList)
                ListTile(
                  leading: Icon(
                    fx['icon'] as IconData,
                    color: fx['color'] as Color,
                  ),
                  title: Text(
                    fx['name'] as String,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () {
                    Get.back();
                    Get.snackbar(
                      'Effect Applied',
                      '${fx['name']} activated for room!',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.purple,
                      colorText: Colors.white,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
