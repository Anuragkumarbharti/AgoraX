import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/common/optimized_image.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/chat/chat_model.dart';
import '../../services/chat/chat_controller.dart';
import '../../services/room/room_controller.dart';
import '../../services/user/user_profile_cache_manager.dart';
import '../../models/room/room_model.dart';
import '../../models/user/user_model.dart';
import '../../widgets/profile/custom_avatar_frame.dart';
import '../rooms/voice_room_call_screen.dart';
import '../../services/room/room_pip_controller.dart';
import '../profile/profile_screen.dart';
import './chat_screen.dart';
import './new_chat_screen.dart';
import '../../widgets/skeletons/chat_list_skeleton_widget.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({Key? key}) : super(key: key);

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final ChatController _ctrl;
  final TextEditingController _searchCtrl = TextEditingController();

  // Animation controllers for premium looks
  late final AnimationController _entranceAnimCtrl;
  late final AnimationController _glowAnimCtrl;
  late final AnimationController _typingAnimCtrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<ChatController>();

    _entranceAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _glowAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _typingAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _searchCtrl.addListener(() {
      _ctrl.searchQuery.value = _searchCtrl.text;
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _glowAnimCtrl.stop();
      _typingAnimCtrl.stop();
    } else if (state == AppLifecycleState.resumed) {
      _glowAnimCtrl.repeat(reverse: true);
      _typingAnimCtrl.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    _entranceAnimCtrl.dispose();
    _glowAnimCtrl.dispose();
    _typingAnimCtrl.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final localDt = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(localDt.year, localDt.month, localDt.day);
    final diffDays = today.difference(itemDate).inDays;

    if (diffDays == 0) return DateFormat('h:mm a').format(localDt);
    if (diffDays == 1) return 'Yesterday';
    return DateFormat('MMM d').format(localDt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: FadeTransition(
          opacity:
              CurvedAnimation(parent: _entranceAnimCtrl, curve: Curves.easeIn),
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              _buildLiveInArenaSection(),
              const SizedBox(height: 8),
              Expanded(child: _buildConversationList()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.to(() => const NewChatScreen(),
            transition: Transition.rightToLeftWithFade),
        backgroundColor: AppTheme.primaryColor,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.bgLight.withOpacity(0.4),
        border: Border(
            bottom: BorderSide(color: AppTheme.borderColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Text(
            'Messages',
            style: GoogleFonts.outfit(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Get.snackbar('Messages', 'Chat & presence synced.',
                  backgroundColor: AppTheme.bgLight,
                  colorText: AppTheme.textPrimary);
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.bgLight,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      color: AppTheme.textPrimary, size: 20),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded,
              color: AppTheme.textTertiary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                hintStyle: TextStyle(
                    color: AppTheme.textTertiary.withOpacity(0.8),
                    fontSize: 14),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close,
                  size: 16, color: AppTheme.textTertiary),
              onPressed: () {
                _searchCtrl.clear();
                _ctrl.searchQuery.value = '';
              },
            ),
        ],
      ),
    );
  }

  List<LiveArenaUser> _getLiveArenaUsers() {
    final List<LiveArenaUser> list = [];

    if (!Get.isRegistered<RoomController>()) {
      return list;
    }

    final roomCtrl = Get.find<RoomController>();
    for (final room in roomCtrl.rooms) {
      if (!room.isLive) continue;

      final hostId = room.hostId;
      final isMutual =
          UserProfileCacheManager.connectionStatuses[hostId] == 'mutual' ||
              (UserProfileCacheManager.followerUserIds.contains(hostId) &&
                  UserProfileCacheManager.followedUserIds.contains(hostId));
      final isFollowing =
          UserProfileCacheManager.followedUserIds.contains(hostId) ||
              roomCtrl.favoriteRoomIds.contains(room.id);
      final isVerified =
          UserProfileCacheManager.getCachedUser(hostId)?.isVerified ?? false;

      // 5-Tier Priority Rank: 1 = Friend (Mutual), 2 = Following, 3 = Verified, 4 = Others
      int priority = 4;
      if (isMutual) {
        priority = 1;
      } else if (isFollowing) {
        priority = 2;
      } else if (isVerified) {
        priority = 3;
      }

      list.add(LiveArenaUser(
        userId: hostId,
        username: room.ownerName,
        avatar: room.avatar ??
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
        avatarFrame: room.roomTheme.toLowerCase().contains('gold')
            ? 'Golden Frame'
            : 'Normal',
        vipBadge: (UserProfileCacheManager.getCachedUser(hostId)?.vipLevel !=
                    null &&
                UserProfileCacheManager.getCachedUser(hostId)!.vipLevel > 0)
            ? 'VIP ${UserProfileCacheManager.getCachedUser(hostId)!.vipLevel}'
            : null,
        isSpeaking:
            room.speakerIds.contains(hostId) || room.hostIds.contains(hostId),
        roomId: room.id,
        room: room,
        isFollowed: isFollowing,
        isMutual: isMutual,
        isVerified: isVerified,
        priorityRank: priority,
      ));
    }

    // Sort by Priority Rank
    list.sort((a, b) => a.priorityRank.compareTo(b.priorityRank));
    return list;
  }

  void _joinArena(VoiceRoom room) {
    if (room.entryPermission != 'everyone') {
      final currentUid = UserProfileCacheManager.currentUserId;
      final allowed = room.coOwnerIds.contains(currentUid) ||
          room.adminIds.contains(currentUid) ||
          room.moderatorIds.contains(currentUid) ||
          room.hostId == currentUid;
      if (!allowed) {
        Get.snackbar(
          'Private Arena',
          'You do not have permission to join this private room.',
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
        return;
      }
    }

    final currentUid = UserProfileCacheManager.currentUserId;
    final currentUsername =
        UserProfileCacheManager.currentUser?.username ?? 'Creaniaa Student';

    // Record visit in recents
    if (Get.isRegistered<RoomController>()) {
      Get.find<RoomController>().addRecentRoom(room.id);
    }

    Get.to(
      () => VoiceRoomCallScreen(
        roomId: room.id,
        roomName: room.name,
        userId: currentUid.isNotEmpty ? currentUid : 'uid_anurag_101',
        userName: currentUsername != 'Creaniaa Student'
            ? currentUsername
            : 'anurag_kumar',
        isHost: room.hostId == currentUid,
      ),
    );
  }

  Widget _buildLiveInArenaSection() {
    return Obx(() {
      final liveUsers = _getLiveArenaUsers();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Live in Arena',
                  style: GoogleFonts.outfit(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (liveUsers.isNotEmpty)
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      'View All',
                      style: GoogleFonts.outfit(
                        color: AppTheme.primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (liveUsers.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.bgLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.borderColor.withOpacity(0.3)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.groups_outlined,
                        size: 32, color: AppTheme.textTertiary.withOpacity(0.5)),
                    const SizedBox(height: 6),
                    Text(
                      'No one is live in Arena right now.',
                      style: GoogleFonts.outfit(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Check back later!',
                      style: GoogleFonts.outfit(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                children: [
                  // 1. Party Broadcast (Always First, Circular Icon)
                  _buildPartyBroadcastItem(),

                  // 2. Real Live Arena Users
                  ...liveUsers.map((user) => _buildArenaUserAvatar(user)),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      );
    });
  }

  Widget _buildPartyBroadcastItem() {
    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _glowAnimCtrl,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryColor
                        .withOpacity(0.3 + 0.7 * _glowAnimCtrl.value),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor
                          .withOpacity(0.25 * _glowAnimCtrl.value),
                      blurRadius: 8,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.volume_up_rounded,
                      color: Colors.white, size: 24),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Party Broadcast',
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildArenaUserAvatar(LiveArenaUser user) {
    Color borderColor = Colors.green;
    if (user.isMutual) {
      borderColor = const Color(0xFFFF2D55); // Pink circular border for Friends
    } else if (user.room.hostId == user.userId) {
      borderColor = const Color(0xFFFFD700); // Gold border for Host
    } else if (user.isVerified) {
      borderColor = Colors.blueAccent;
    }

    return GestureDetector(
      onTap: () => _joinArena(user.room),
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              children: [
                AnimatedBuilder(
                  animation: _glowAnimCtrl,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: user.isSpeaking
                              ? AppTheme.accentColor
                                  .withOpacity(0.3 + 0.7 * _glowAnimCtrl.value)
                              : borderColor
                                  .withOpacity(0.4 + 0.6 * _glowAnimCtrl.value),
                          width: 2.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: user.isSpeaking
                                ? AppTheme.accentColor
                                    .withOpacity(0.3 * _glowAnimCtrl.value)
                                : borderColor
                                    .withOpacity(0.25 * _glowAnimCtrl.value),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(user.avatar),
                      ),
                    );
                  },
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppTheme.successColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.bgDark, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              user.username,
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationList() {
    return Obx(() {
      if (_ctrl.isLoading.value && _ctrl.conversations.isEmpty) {
        return const ChatListSkeletonWidget();
      }

      final query = _ctrl.searchQuery.value.trim().toLowerCase();
      final Map<String, Conversation> dedupMap = {};

      for (final c in _ctrl.conversations) {
        if (c.otherUserId.isEmpty) continue;
        if (query.isNotEmpty &&
            !c.otherUserName.toLowerCase().contains(query) &&
            !c.lastMessage.toLowerCase().contains(query)) {
          continue;
        }

        // Deduplicate by otherUserId or canonical ID
        if (!dedupMap.containsKey(c.otherUserId) ||
            c.lastMessageTime.isAfter(dedupMap[c.otherUserId]!.lastMessageTime)) {
          dedupMap[c.otherUserId] = c;
        }
      }

      final filtered = dedupMap.values.toList();

      final listWidget = filtered.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: AppTheme.textTertiary.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'No conversations found',
                        style: GoogleFonts.outfit(
                            color: AppTheme.textTertiary, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              itemCount: filtered.length,
              physics: const AlwaysScrollableScrollPhysics(),
              itemBuilder: (context, idx) {
                final conv = filtered[idx];
                return _buildSwipeableConversationTile(conv);
              },
            );

      return RefreshIndicator(
        onRefresh: () async {
          await _ctrl.refreshConversations();
        },
        child: listWidget,
      );
    });
  }


  Widget _buildSwipeableConversationTile(Conversation conv) {
    return Dismissible(
      key: Key('swipe_${conv.id}'),
      background: Container(
        color: AppTheme.primaryColor.withOpacity(0.8),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Row(
          children: [
            Icon(Icons.mark_chat_read_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Mark Read',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: AppTheme.errorColor.withOpacity(0.8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 10),
            Icon(Icons.delete_outline_rounded, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Mark Read / Pin Option
          _ctrl.markConversationRead(conv.id);
          Get.snackbar(
              'Conversation Updated', '${conv.otherUserName} marked read',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppTheme.bgLight);
          return false; // Don't remove from list
        } else {
          // Swipe Left: Archive / Delete Options
          bool delete = false;
          await Get.dialog(
            AlertDialog(
              backgroundColor: AppTheme.bgLight,
              title: const Text('Delete Chat?'),
              content: Text(
                  'Do you want to delete this chat with ${conv.otherUserName}?'),
              actions: [
                TextButton(
                    onPressed: () => Get.back(), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor),
                  onPressed: () {
                    delete = true;
                    Get.back();
                  },
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (delete) {
            _ctrl.conversations.removeWhere((c) => c.id == conv.id);
          }
          return delete;
        }
      },
      child: _buildConversationTile(conv),
    );
  }

  Widget _buildConversationTile(Conversation conv) {
    return Obx(() {
      final isTyping = Get.find<ChatController>().typingState[conv.id] ?? false;
      final currentUid = UserProfileCacheManager.currentUserId;
      final isMe = conv.lastMessage.isNotEmpty &&
          (conv.lastMessageSenderId == currentUid || conv.lastMessageSenderId == 'me');

      return InkWell(
        onTap: () => _openChat(conv),
        onLongPress: () => _showConvOptions(conv),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar with frame and online indicator
              GestureDetector(
                onTap: () => Get.to(() => ProfileScreen(
                      visitorUser: UserProfileCacheManager.getCachedUser(
                              conv.otherUserId) ??
                          User.fromJson({
                            'id': conv.otherUserId,
                            'username': conv.otherUserName,
                            'displayName': conv.otherUserName,
                            'avatar_url': conv.otherUserAvatar,
                          }),
                    )),
                child: Stack(
                  children: [
                    CustomAvatarFrame(
                      userId: conv.otherUserId,
                      username: conv.otherUserName,
                      size: 52,
                      child: OptimizedImage(
                        imageUrl: UserProfileCacheManager
                                .rxCache[conv.otherUserId]?.avatar ??
                            conv.otherUserAvatar,
                        preset: MediaSizePreset.xs,
                        fit: BoxFit.cover,
                        errorWidget:
                            const Icon(Icons.person, color: Colors.white30),
                      ),
                    ),
                    if (conv.otherUserOnline)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: AppTheme.successColor,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppTheme.bgDark, width: 2),
                          ),
                        ),
                      ),
                    // "ARENA" Tag if inside Arena (Zoya, Arjun etc have them in reference)
                    if (conv.otherUserOnline)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ARENA',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 6,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Message Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Get.to(() => ProfileScreen(
                                visitorUser: UserProfileCacheManager
                                        .rxCache[conv.otherUserId] ??
                                    User.fromJson({
                                      'id': conv.otherUserId,
                                      'username': conv.otherUserName,
                                      'displayName': conv.otherUserName,
                                      'avatar_url': conv.otherUserAvatar,
                                    }),
                              )),
                          child: Builder(builder: (context) {
                            final cached = UserProfileCacheManager.rxCache[conv.otherUserId] ??
                                UserProfileCacheManager.getCachedUser(conv.otherUserId);
                            final String resolvedName = (cached?.displayName != null && cached!.displayName.isNotEmpty)
                                ? cached.displayName
                                : ((cached?.username != null && cached!.username.isNotEmpty)
                                    ? cached.username
                                    : (conv.otherUserName.isNotEmpty && conv.otherUserName != 'User' && conv.otherUserName != 'Creaniaa User'
                                        ? conv.otherUserName
                                        : ''));
                            if (resolvedName.isEmpty && conv.otherUserId.isNotEmpty) {
                              UserProfileCacheManager.fetchUserProfile(conv.otherUserId);
                            }
                            final String displayName = resolvedName.isNotEmpty
                                ? resolvedName
                                : 'User ${conv.otherUserId.length > 6 ? conv.otherUserId.substring(0, 6) : conv.otherUserId}';

                            return Text(
                              displayName,
                              style: GoogleFonts.outfit(
                                color: AppTheme.textPrimary,
                                fontWeight: conv.unreadCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 15,
                              ),
                            );
                          }),
                        ),
                        if (conv.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              color: Color(0xFF60A5FA), size: 14),
                        ],
                        if (UserProfileCacheManager
                                    .rxCache[conv.otherUserId]?.vipLevel !=
                                null &&
                            UserProfileCacheManager
                                    .rxCache[conv.otherUserId]!.vipLevel >
                                0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: AppTheme.accentColor, width: 0.5),
                            ),
                            child: Text(
                              'VIP ${UserProfileCacheManager.rxCache[conv.otherUserId]!.vipLevel}',
                              style: const TextStyle(
                                  color: AppTheme.accentColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        if (conv.isMuted) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.volume_off_rounded,
                              color: AppTheme.textTertiary.withOpacity(0.6),
                              size: 14),
                        ],
                        const Spacer(),
                        Text(
                          _formatTime(conv.lastMessageTime),
                          style: GoogleFonts.outfit(
                            color: conv.unreadCount > 0
                                ? AppTheme.accentColor
                                : AppTheme.textTertiary,
                            fontSize: 11,
                            fontWeight: conv.unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Status Ticks - Single source of truth from conv.lastMessageStatus
                        if (isMe && conv.lastMessage.isNotEmpty && !isTyping) ...[
                          _buildDeliveryStatusIcon(conv.lastMessageStatus),
                          const SizedBox(width: 4),
                        ],

                        // Last message or Typing indicator
                        Expanded(
                          child: isTyping
                              ? Row(
                                  children: [
                                    Text(
                                      'Typing',
                                      style: GoogleFonts.outfit(
                                        color: AppTheme.accentColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    _buildTypingDotsAnimation(),
                                  ],
                                )
                              : Text(
                                  conv.lastMessage,
                                  style: GoogleFonts.outfit(
                                    color: conv.unreadCount > 0
                                        ? AppTheme.textPrimary
                                        : AppTheme.textTertiary,
                                    fontSize: 13,
                                    fontWeight: conv.unreadCount > 0
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                        if (conv.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppTheme
                                  .successColor, // Bright Green badge in reference images
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${conv.unreadCount}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        if (conv.isPinned) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.push_pin_rounded,
                              color: AppTheme.textTertiary.withOpacity(0.7),
                              size: 12),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildDeliveryStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time_rounded,
            size: 14, color: AppTheme.textTertiary);
      case MessageStatus.sent:
        return const Icon(Icons.done_rounded,
            size: 14, color: AppTheme.textTertiary);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded,
            size: 14, color: AppTheme.textTertiary);
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded,
            size: 14, color: Color(0xFF60A5FA));
    }
  }

  Widget _buildTypingDotsAnimation() {
    return AnimatedBuilder(
      animation: _typingAnimCtrl,
      builder: (context, child) {
        final dotsCount = (_typingAnimCtrl.value * 3.99).floor();
        String dots = '';
        for (int i = 0; i < dotsCount; i++) {
          dots += '.';
        }
        return SizedBox(
          width: 20,
          child: Text(
            dots,
            style: const TextStyle(
                color: AppTheme.accentColor,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  void _openChat(Conversation conv) {
    _ctrl.markConversationRead(conv.id);
    Get.to(
      () => ChatScreen(conversation: conv),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 250),
    );
  }

  void _showConvOptions(Conversation conv) {
    HapticFeedback.mediumImpact();
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Row(
              children: [
                CircleAvatar(
                    radius: 22,
                    backgroundImage: NetworkImage(conv.otherUserAvatar)),
                const SizedBox(width: 12),
                Text(conv.otherUserName,
                    style: GoogleFonts.outfit(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            _optionTile(
              icon: conv.isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              color: AppTheme.warningColor,
              label: conv.isPinned ? 'Unpin' : 'Pin Chat',
              onTap: () {
                _ctrl.togglePin(conv.id);
                Get.back();
              },
            ),
            _optionTile(
              icon: conv.isMuted
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: AppTheme.textSecondary,
              label: conv.isMuted ? 'Unmute' : 'Mute',
              onTap: () {
                _ctrl.toggleMute(conv.id);
                Get.back();
              },
            ),
            _optionTile(
              icon: Icons.delete_outline_rounded,
              color: AppTheme.errorColor,
              label: 'Delete Conversation',
              onTap: () {
                _ctrl.deleteConversation(conv.id);
                Get.back();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(
      {required IconData icon,
      required Color color,
      required String label,
      required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(label,
          style: GoogleFonts.outfit(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
    );
  }
}

class LiveArenaUser {
  final String userId;
  final String username;
  final String avatar;
  final String? avatarFrame;
  final String? vipBadge;
  final bool isSpeaking;
  final String roomId;
  final VoiceRoom room;
  final bool isFollowed;
  final bool isMutual;
  final bool isVerified;
  final int priorityRank;

  LiveArenaUser({
    required this.userId,
    required this.username,
    required this.avatar,
    this.avatarFrame,
    this.vipBadge,
    required this.isSpeaking,
    required this.roomId,
    required this.room,
    this.isFollowed = false,
    this.isMutual = false,
    this.isVerified = false,
    this.priorityRank = 4,
  });
}

// Simple copyWith extension for Conversation
extension ConversationExtension on Conversation {
  Conversation copyWith({
    bool? isPinned,
    bool? isMuted,
    int? unreadCount,
  }) {
    return Conversation(
      id: id,
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      otherUserAvatar: otherUserAvatar,
      otherUserOnline: otherUserOnline,
      isVerified: isVerified,
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      levelTitle: levelTitle,
      level: level,
      lastMessageSenderId: lastMessageSenderId,
    );
  }
}
