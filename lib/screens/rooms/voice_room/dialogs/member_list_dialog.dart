import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zego_express_engine/zego_express_engine.dart' hide Text;
import 'package:creania/core/theme.dart';

import '../../../../models/room/room_model.dart';
import '../../../../models/chat/chat_model.dart';
import '../../../chat/chat_screen.dart';
import '../../../../services/chat/chat_controller.dart';
import '../../../../services/room/room_controller.dart';
import '../../../../services/room/room_seat_controller.dart';
import '../../../../services/voice/voice_controller.dart';
import '../../../../services/user/user_profile_cache_manager.dart';
import '../../../../widgets/index.dart';
import '../../../../widgets/common/optimized_image.dart';
import 'mini_profile_dialog.dart';

class MemberListDialog extends StatelessWidget {
  final String roomId;
  final VoiceRoom room;
  const MemberListDialog({required this.roomId, required this.room, Key? key})
      : super(key: key);

  String _getUserDp(String userId) {
    if (userId == 'uid_anurag_101') {
      return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150';
    } else if (userId == 'user_co_1' || userId.contains('priya')) {
      return 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150';
    } else if (userId == 'user_adm_1' || userId.contains('vikram')) {
      return 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150';
    } else if (userId == 'user_man_1' || userId.contains('rajesh')) {
      return 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150';
    } else if (userId == 'user_mod_1' || userId.contains('sneha')) {
      return 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150';
    } else if (userId == 'user_host_1' || userId.contains('karan')) {
      return 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150';
    } else if (userId == 'user_star_1' || userId.contains('siddharth')) {
      return 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150';
    } else if (userId == 'user_elite_1' || userId.contains('arjun')) {
      return 'https://images.unsplash.com/photo-1500048993953-d23a436266cf?w=150';
    } else if (userId == 'user_vip_1' || userId.contains('divya')) {
      return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150';
    } else if (userId == 'user_memb_1' || userId.contains('kabir')) {
      return 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150';
    } else if (userId == 'user_vis_1' || userId.contains('ananya')) {
      return 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150';
    } else {
      return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150';
    }
  }

  void _handleViewProfile(String userId, String name, String role) {
    final occupiedSeats = (RoomController.to.roomSeatsInfo[roomId] ?? [])
        .where((s) => s['userId'] != null)
        .length;

    Get.dialog(
      MiniProfileDialog(
        roomId: roomId,
        callerUserId: RoomController.currentUserId,
        targetUserId: userId,
        targetUserName: name,
        role: role,
        seatIndex: -1,
        isHost: room.hostId == RoomController.currentUserId ||
            room.founderId == RoomController.currentUserId,
        occupiedSeatsCount: occupiedSeats,
      ),
    );
  }

  void _handleChatPressed(String targetId, String targetName) {
    final dp = _getUserDp(targetId);
    Get.back(); // Dismiss MemberListDialog
    Get.back(); // Exit VoiceRoomCallScreen to go home

    // Trigger PIP float bubble with room info
    RoomController.to.showPipBubble(
      roomId,
      room.name,
      dp,
    );

    // Navigate to ChatScreen
    final chatCtrl = Get.find<ChatController>();
    final Conversation conversation = chatCtrl.getOrCreateConversation(
      targetId,
      targetName,
      dp,
    );
    Get.to(() => ChatScreen(conversation: conversation));
  }

  Widget _buildMemberTile(
    BuildContext context, {
    required String userId,
    required String fallbackName,
    required String role,
    required bool isOnline,
    required bool isSpeaking,
    required String seatText,
    required VoidCallback onViewProfile,
    required VoidCallback onChatPressed,
  }) {
    return Obx(() {
      final profile = UserProfileCacheManager.rxCache[userId] ??
          UserProfileCacheManager.getCachedUser(userId);
      final name = profile?.username ?? fallbackName;
      final avatarUrl = profile?.avatar ?? '';
      final level = profile?.level ?? 1;
      final nobleLevel = profile?.novelLevel ?? 0;
      final vipLevel = profile?.vipLevel ?? 0;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            CustomAvatarFrame(
              userId: userId,
              username: name,
              size: 38,
              child: CircleAvatar(
                radius: 17,
                backgroundImage:
                    avatarUrl.isNotEmpty ? OptimizedImage.getOptimizedImageProvider(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: GoogleFonts.poppins(
                            color: context.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSpeaking) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.mic,
                            color: Color(0xFF00FF66), size: 10),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 0.5),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'Lv $level',
                          style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 7,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (nobleLevel > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 3, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'Novel $nobleLevel',
                            style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 7,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (vipLevel > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 3, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'VIP $vipLevel',
                            style: const TextStyle(
                                color: Colors.purpleAccent,
                                fontSize: 7,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      _buildRoleBadgeTag(role, seatText),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOnline)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF66).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Online',
                        style: TextStyle(
                            color: Color(0xFF00FF66),
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold)),
                  ),
                // Show Manage button ONLY, remove Message button
                ElevatedButton(
                  onPressed: onViewProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.18),
                    foregroundColor: const Color(0xFFC084FC),
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(60, 26),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                          color: const Color(0xFF8B5CF6).withOpacity(0.40),
                          width: 1),
                    ),
                  ),
                  child: Text(
                    'Manage',
                    style: GoogleFonts.poppins(
                        fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildRoleBadgeTag(String role, String seatText) {
    String tagLabel = '';
    Color tagBgColor = Colors.transparent;
    Color tagTextColor = Colors.white;

    final lowerRole = role.toLowerCase();
    if (lowerRole == 'creator' || lowerRole == 'owner' || lowerRole == 'founder') {
      tagLabel = '👑 Creator';
      tagBgColor = const Color(0xFFFFD700).withOpacity(0.2);
      tagTextColor = const Color(0xFFFFD700);
    } else if (lowerRole == 'co-owner' || lowerRole == 'co owner') {
      tagLabel = '💎 Co Owner';
      tagBgColor = const Color(0xFF9C27B0).withOpacity(0.2);
      tagTextColor = const Color(0xFFCE93D8);
    } else if (lowerRole == 'admin' || lowerRole == 'moderator') {
      tagLabel = '🛡 Admin';
      tagBgColor = const Color(0xFF2563EB).withOpacity(0.2);
      tagTextColor = const Color(0xFF60A5FA);
    } else if (lowerRole == 'host' || seatText == 'Host') {
      tagLabel = '🎤 Host';
      tagBgColor = const Color(0xFFEF4444).withOpacity(0.2);
      tagTextColor = const Color(0xFFA7F3D0);
    } else if (seatText.isNotEmpty && seatText != 'Audience') {
      tagLabel = '🎙️ $seatText';
      tagBgColor = Colors.cyan.withOpacity(0.2);
      tagTextColor = Colors.cyanAccent;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: tagBgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: tagTextColor.withOpacity(0.5), width: 0.8),
      ),
      child: Text(
        tagLabel,
        style: GoogleFonts.poppins(
          color: tagTextColor,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: Get.width * 0.9,
          height: 480,
          decoration: BoxDecoration(
            color: context.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: TabBar(
                  isScrollable: true,
                  indicatorColor: context.primaryColor,
                  labelColor: context.primaryColor,
                  unselectedLabelColor: context.textSecondary,
                  tabs: const [
                    Tab(text: 'Online'),
                    Tab(text: 'Management'),
                    Tab(text: 'Speakers'),
                    Tab(text: 'Elites'),
                    Tab(text: 'VIPs'),
                    Tab(text: 'Audience'),
                  ],
                ),
              ),
              Expanded(
                child: Obx(() {
                  final Map<String, dynamic> userMap = {};
                  final dbMembers = RoomController.to.activeMembers;

                  if (dbMembers.isNotEmpty) {
                    for (final m in dbMembers) {
                      final profile =
                          UserProfileCacheManager.getCachedUser(m.userId);
                      final voiceUser = VoiceController.to.roomUsers
                          .firstWhereOrNull((u) => u.userID == m.userId);
                      userMap[m.userId] = voiceUser ??
                          ZegoUser(m.userId, profile?.username ?? 'Member');
                    }
                  } else {
                    for (final u in VoiceController.to.roomUsers) {
                      userMap[u.userID] = u;
                    }
                  }

                  final onlineUsers = userMap.values.cast<ZegoUser>().toList();
                  final onlineUserIds =
                      onlineUsers.map((u) => u.userID).toSet();

                  return TabBarView(
                    children: [
                      _buildOnlineTab(context, onlineUsers),
                      _buildManagementTab(context, onlineUserIds),
                      _buildSpeakersTab(context, onlineUserIds),
                      _buildElitesTab(context, onlineUserIds),
                      _buildVipsTab(context, onlineUserIds),
                      _buildAudienceTab(context, onlineUserIds, onlineUsers),
                    ],
                  );
                }),
              ),
              TextButton(
                onPressed: () => Get.back(),
                child: Text('Close',
                    style: GoogleFonts.poppins(color: context.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineTab(BuildContext context, List<ZegoUser> onlineUsers) {
    if (onlineUsers.isEmpty) {
      return Center(
          child: Text('No users online',
              style: TextStyle(color: context.textSecondary)));
    }

    final sortedUsers = List<ZegoUser>.from(onlineUsers);
    sortedUsers.sort((a, b) {
      final roleA = RoomController.to.getUserRole(room, a.userID);
      final roleB = RoomController.to.getUserRole(room, b.userID);
      final weightA = RoomController.to.getRoleWeight(roleA);
      final weightB = RoomController.to.getRoleWeight(roleB);
      return weightB.compareTo(weightA);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedUsers.length,
      itemBuilder: (context, index) {
        final u = sortedUsers[index];
        final seatsList = RoomController.to.roomSeatsInfo[roomId] ?? [];
        final role = RoomController.to.getUserRole(room, u.userID, seatsInfo: seatsList);
        final seatIndex = seatsList.indexWhere((s) => s['userId'] == u.userID);
        final seatText = seatIndex != -1 ? RoomSeatController.getSeatName(seatIndex) : 'Audience';
        final isSpeaking =
            seatIndex != -1 && seatsList[seatIndex]['isSpeaking'] == true;

        return _buildMemberTile(
          context,
          userId: u.userID,
          fallbackName: u.userName,
          role: role,
          isOnline: true,
          isSpeaking: isSpeaking,
          seatText: seatText,
          onViewProfile: () => _handleViewProfile(u.userID, u.userName, role),
          onChatPressed: () => _handleChatPressed(u.userID, u.userName),
        );
      },
    );
  }

  Widget _buildManagementTab(BuildContext context, Set<String> onlineUserIds) {
    return Obx(() {
      final staffRoles = [
        'Founder',
        'Owner',
        'Arena Owner',
        'Co-owner',
        'Co-Owner',
        'Admin',
        'Moderator'
      ];
      final staff = RoomController.to.activeMembers.where((m) {
        return staffRoles.any((r) => r.toLowerCase() == m.role.toLowerCase());
      }).toList();

      if (staff.isEmpty) {
        return Center(
            child: Text('No management staff found',
                style: TextStyle(color: context.textSecondary)));
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: staff.length,
        itemBuilder: (context, index) {
          final m = staff[index];
          final isOnline = onlineUserIds.contains(m.userId);
          final seatsList = RoomController.to.roomSeatsInfo[roomId] ?? [];
          final seatIndex =
              seatsList.indexWhere((s) => s['userId'] == m.userId);
          final seatText =
              seatIndex != -1 ? RoomSeatController.getSeatName(seatIndex) : 'Audience';

          return _buildMemberTile(
            context,
            userId: m.userId,
            fallbackName: 'Staff Member',
            role: m.role,
            isOnline: isOnline,
            isSpeaking: false,
            seatText: seatText,
            onViewProfile: () => _handleViewProfile(m.userId, 'Staff', m.role),
            onChatPressed: () => _handleChatPressed(m.userId, 'Staff'),
          );
        },
      );
    });
  }

  Widget _buildSpeakersTab(BuildContext context, Set<String> onlineUserIds) {
    return Obx(() {
      final seatsList = RoomController.to.roomSeatsInfo[roomId] ?? [];
      final speakerSeats = seatsList.where((s) => s['userId'] != null).toList();

      if (speakerSeats.isEmpty) {
        return Center(
            child: Text('No active speakers',
                style: TextStyle(color: context.textSecondary)));
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: speakerSeats.length,
        itemBuilder: (context, index) {
          final seat = speakerSeats[index];
          final uId = seat['userId'] as String;
          final isOnline = onlineUserIds.contains(uId);
          final seatIndex = seat['seatIndex'] as int;

          return _buildMemberTile(
            context,
            userId: uId,
            fallbackName: seat['name'] ?? 'Speaker',
            role: seat['role'] ?? 'Speaker',
            isOnline: isOnline,
            isSpeaking: isOnline,
            seatText: RoomSeatController.getSeatName(seatIndex),
            onViewProfile: () => _handleViewProfile(
                uId, seat['name'] ?? 'Speaker', seat['role'] ?? 'Speaker'),
            onChatPressed: () =>
                _handleChatPressed(uId, seat['name'] ?? 'Speaker'),
          );
        },
      );
    });
  }

  Widget _buildElitesTab(BuildContext context, Set<String> onlineUserIds) {
    return Obx(() {
      final elites = RoomController.to.activeMembers.where((m) {
        final profile = UserProfileCacheManager.rxCache[m.userId] ??
            UserProfileCacheManager.getCachedUser(m.userId);
        return (profile?.level ?? 1) >= 20;
      }).toList();

      if (elites.isEmpty) {
        return Center(
            child: Text('No Elite members',
                style: TextStyle(color: context.textSecondary)));
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: elites.length,
        itemBuilder: (context, index) {
          final m = elites[index];
          final isOnline = onlineUserIds.contains(m.userId);
          return _buildMemberTile(
            context,
            userId: m.userId,
            fallbackName: 'Elite Member',
            role: m.role,
            isOnline: isOnline,
            isSpeaking: false,
            seatText: '',
            onViewProfile: () => _handleViewProfile(m.userId, 'Elite', m.role),
            onChatPressed: () => _handleChatPressed(m.userId, 'Elite'),
          );
        },
      );
    });
  }

  Widget _buildVipsTab(BuildContext context, Set<String> onlineUserIds) {
    return Obx(() {
      final vips = RoomController.to.activeMembers.where((m) {
        final profile = UserProfileCacheManager.rxCache[m.userId] ??
            UserProfileCacheManager.getCachedUser(m.userId);
        return (profile?.vipLevel ?? 0) > 0 || (profile?.novelLevel ?? 0) > 0;
      }).toList();

      if (vips.isEmpty) {
        return Center(
            child: Text('No VIP members',
                style: TextStyle(color: context.textSecondary)));
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: vips.length,
        itemBuilder: (context, index) {
          final m = vips[index];
          final isOnline = onlineUserIds.contains(m.userId);
          return _buildMemberTile(
            context,
            userId: m.userId,
            fallbackName: 'VIP Member',
            role: m.role,
            isOnline: isOnline,
            isSpeaking: false,
            seatText: '',
            onViewProfile: () => _handleViewProfile(m.userId, 'VIP', m.role),
            onChatPressed: () => _handleChatPressed(m.userId, 'VIP'),
          );
        },
      );
    });
  }

  Widget _buildAudienceTab(BuildContext context, Set<String> onlineUserIds,
      List<ZegoUser> onlineUsers) {
    return Obx(() {
      final seatsList = RoomController.to.roomSeatsInfo[roomId] ?? [];
      final speakerUserIds =
          seatsList.map((s) => s['userId']).where((id) => id != null).toSet();

      final audience =
          onlineUsers.where((u) => !speakerUserIds.contains(u.userID)).toList();

      if (audience.isEmpty) {
        return Center(
            child: Text('No audience connected',
                style: TextStyle(color: context.textSecondary)));
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: audience.length,
        itemBuilder: (context, index) {
          final u = audience[index];
          final member = RoomController.to.activeMembers
              .firstWhereOrNull((m) => m.userId == u.userID);
          final role = member?.role ?? 'Audience';

          return _buildMemberTile(
            context,
            userId: u.userID,
            fallbackName: u.userName,
            role: role,
            isOnline: true,
            isSpeaking: false,
            seatText: 'Audience',
            onViewProfile: () => _handleViewProfile(u.userID, u.userName, role),
            onChatPressed: () => _handleChatPressed(u.userID, u.userName),
          );
        },
      );
    });
  }
}
