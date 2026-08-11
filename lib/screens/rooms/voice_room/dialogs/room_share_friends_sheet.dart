import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../../../models/chat/chat_model.dart';
import '../../../../models/room/room_model.dart';
import '../../../../services/chat/chat_controller.dart';
import '../../../../services/user/user_profile_cache_manager.dart';
import '../../../../widgets/common/optimized_image.dart';

class ShareUserCandidate {
  final String userId;
  final String name;
  final String avatar;
  final bool isRecent;
  final bool isMutual;
  final DateTime? lastMessageTime;

  ShareUserCandidate({
    required this.userId,
    required this.name,
    required this.avatar,
    this.isRecent = false,
    this.isMutual = false,
    this.lastMessageTime,
  });
}

class RoomShareFriendsSheet extends StatefulWidget {
  final VoiceRoom room;

  const RoomShareFriendsSheet({
    Key? key,
    required this.room,
  }) : super(key: key);

  static void show(BuildContext context, VoiceRoom room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoomShareFriendsSheet(room: room),
    );
  }

  @override
  State<RoomShareFriendsSheet> createState() => _RoomShareFriendsSheetState();
}

class _RoomShareFriendsSheetState extends State<RoomShareFriendsSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final RxString _searchQuery = ''.obs;
  final RxSet<String> _selectedUserIds = <String>{}.obs;
  final RxBool _isSending = false.obs;

  List<ShareUserCandidate> _recentCandidates = [];
  List<ShareUserCandidate> _followingCandidates = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
    _searchCtrl.addListener(() {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 250), () {
        _searchQuery.value = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadCandidates() {
    final Map<String, ShareUserCandidate> seenMap = {};
    final String currentUid = UserProfileCacheManager.currentUserId;

    // 1. Load Recent Conversations from ChatController
    if (Get.isRegistered<ChatController>()) {
      final chatCtrl = Get.find<ChatController>();
      for (final conv in chatCtrl.conversations) {
        if (conv.otherUserId.isEmpty || conv.otherUserId == currentUid) continue;
        final cand = ShareUserCandidate(
          userId: conv.otherUserId,
          name: conv.otherUserName,
          avatar: conv.otherUserAvatar,
          isRecent: true,
          isMutual: conv.isMutualFollow,
          lastMessageTime: conv.lastMessageTime,
        );
        seenMap[conv.otherUserId] = cand;
      }
    }

    // 2. Load Following / Mutual connections from UserProfileCacheManager
    final followed = UserProfileCacheManager.followedUserIds;
    for (final uid in followed) {
      if (uid.isEmpty || uid == currentUid || seenMap.containsKey(uid)) continue;
      final cached = UserProfileCacheManager.getCachedUser(uid);
      final isMutual = UserProfileCacheManager.connectionStatuses[uid] == 'mutual' ||
          UserProfileCacheManager.followerUserIds.contains(uid);

      final cand = ShareUserCandidate(
        userId: uid,
        name: cached?.displayName ?? cached?.username ?? 'User',
        avatar: cached?.avatar ?? '',
        isRecent: false,
        isMutual: isMutual,
      );
      seenMap[uid] = cand;
    }

    // Also check followers
    final followers = UserProfileCacheManager.followerUserIds;
    for (final uid in followers) {
      if (uid.isEmpty || uid == currentUid || seenMap.containsKey(uid)) continue;
      final cached = UserProfileCacheManager.getCachedUser(uid);
      final cand = ShareUserCandidate(
        userId: uid,
        name: cached?.displayName ?? cached?.username ?? 'User',
        avatar: cached?.avatar ?? '',
        isRecent: false,
        isMutual: true,
      );
      seenMap[uid] = cand;
    }

    // Separate into Recent vs Following
    final all = seenMap.values.toList();
    _recentCandidates = all.where((c) => c.isRecent).toList()
      ..sort((a, b) => (b.lastMessageTime ?? DateTime(2000)).compareTo(a.lastMessageTime ?? DateTime(2000)));

    _followingCandidates = all.where((c) => !c.isRecent).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  void _handleBatchSend() async {
    if (_selectedUserIds.isEmpty || _isSending.value) return;

    _isSending.value = true;
    HapticFeedback.mediumImpact();

    final chatCtrl = Get.isRegistered<ChatController>() ? Get.find<ChatController>() : Get.put(ChatController());
    int successCount = 0;

    for (final targetId in _selectedUserIds) {
      final success = await chatCtrl.sendRoomInvitation(
        targetUserId: targetId,
        roomId: widget.room.id,
        roomTitle: widget.room.name,
        hostName: widget.room.ownerName,
        roomCover: widget.room.avatar,
      );
      if (success) successCount++;
    }

    _isSending.value = false;
    Navigator.of(context).pop();

    if (successCount > 0) {
      Get.snackbar(
        'Room Share',
        'Room invitation sent to $successCount friend${successCount > 1 ? 's' : ''}',
        backgroundColor: const Color(0xFF006D2F),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72 + bottomInset,
      decoration: const BoxDecoration(
        color: Color(0xFF121927),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.share_rounded, color: Colors.cyanAccent, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Share Room',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search friends...',
                        hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _searchQuery.value = '';
                      },
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // User Candidates List
          Expanded(
            child: Obx(() {
              final q = _searchQuery.value;
              final filteredRecent = _recentCandidates
                  .where((c) => c.name.toLowerCase().contains(q))
                  .toList();
              final filteredFollowing = _followingCandidates
                  .where((c) => c.name.toLowerCase().contains(q))
                  .toList();

              if (filteredRecent.isEmpty && filteredFollowing.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 44, color: Colors.white30),
                      const SizedBox(height: 10),
                      Text(
                        'No friends found',
                        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (filteredRecent.isNotEmpty) ...[
                    _buildSectionHeader('Recent Conversations'),
                    ...filteredRecent.map((c) => _buildUserTile(c)),
                    const SizedBox(height: 12),
                  ],
                  if (filteredFollowing.isNotEmpty) ...[
                    _buildSectionHeader('Following & Friends'),
                    ...filteredFollowing.map((c) => _buildUserTile(c)),
                  ],
                ],
              );
            }),
          ),

          // Bottom Action Panel with Send Button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1420),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
            ),
            child: SafeArea(
              top: false,
              child: Obx(() {
                final count = _selectedUserIds.length;
                final bool isEnabled = count > 0 && !_isSending.value;

                return SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isEnabled ? _handleBatchSend : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEnabled ? const Color(0xFF006D2F) : Colors.white12,
                      disabledBackgroundColor: Colors.white12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: isEnabled ? 4 : 0,
                    ),
                    child: _isSending.value
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(
                            count > 0 ? 'Send ($count)' : 'Select Friends to Send',
                            style: GoogleFonts.poppins(
                              color: isEnabled ? Colors.white : Colors.white38,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.cyanAccent.withOpacity(0.9),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildUserTile(ShareUserCandidate candidate) {
    return Obx(() {
      final isSelected = _selectedUserIds.contains(candidate.userId);

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyanAccent.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          onTap: () {
            HapticFeedback.selectionClick();
            if (isSelected) {
              _selectedUserIds.remove(candidate.userId);
            } else {
              _selectedUserIds.add(candidate.userId);
            }
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white10,
                backgroundImage: candidate.avatar.isNotEmpty ? NetworkImage(candidate.avatar) : null,
                child: candidate.avatar.isEmpty
                    ? Text(
                        candidate.name.isNotEmpty ? candidate.name[0].toUpperCase() : 'U',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              if (candidate.isMutual)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF2D55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star, size: 8, color: Colors.white),
                  ),
                ),
            ],
          ),
          title: Text(
            candidate.name,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: candidate.isMutual
              ? Text(
                  'Mutual Friend',
                  style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
                )
              : null,
          trailing: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? const Color(0xFF006D2F) : Colors.transparent,
              border: Border.all(
                color: isSelected ? const Color(0xFF006D2F) : Colors.white38,
                width: 2,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ),
      );
    });
  }
}
