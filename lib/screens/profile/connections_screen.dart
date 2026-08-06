import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:creania/core/theme.dart';
import '../../models/user/user_model.dart';
import './profile_screen.dart';
import '../../widgets/profile/custom_avatar_frame.dart';
import '../../services/user/user_profile_cache_manager.dart';
import '../../widgets/skeletons/followers_skeleton_widget.dart';

class ConnectionsScreen extends StatefulWidget {
  final int initialTabIndex; // 0 for Following, 1 for Followers, 2 for Friends
  final String? targetUserId;
  final String? targetUserName;

  const ConnectionsScreen({
    Key? key,
    this.initialTabIndex = 0,
    this.targetUserId,
    this.targetUserName,
  }) : super(key: key);

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final RxList<User> _followingList = <User>[].obs;
  final RxList<User> _followersList = <User>[].obs;
  final RxList<User> _friendsList = <User>[].obs;
  RealtimeChannel? _screenRealtimeChannel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _loadConnections();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _screenRealtimeChannel?.unsubscribe();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    try {
      _screenRealtimeChannel = Supabase.instance.client
          .channel('public:connections_screen_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'connections',
            callback: (payload) {
              _loadConnections();
            },
          );
      _screenRealtimeChannel?.subscribe();
    } catch (e) {
      debugPrint('[ConnectionsScreen] Realtime setup failed: $e');
    }
  }

  void _loadConnections() async {
    final String tid = widget.targetUserId ?? UserProfileCacheManager.currentUserId;
    if (tid.isEmpty) return;

    try {
      if (_followingList.isEmpty && _followersList.isEmpty) {
        setState(() => _isLoading = true);
      }

      // Query database connections
      final followingRes = await Supabase.instance.client
          .from('connections')
          .select('profiles:following_id (*)')
          .eq('follower_id', tid);

      final followersRes = await Supabase.instance.client
          .from('connections')
          .select('profiles:follower_id (*)')
          .eq('following_id', tid);

      final friendsRes = await Supabase.instance.client
          .from('connections')
          .select('profiles:following_id (*)')
          .eq('follower_id', tid)
          .eq('status', 'friends');

      final List<User> loadedFollowing = [];
      if (followingRes != null) {
        for (final item in followingRes as List) {
          if (item['profiles'] != null) {
            loadedFollowing.add(User.fromJson(item['profiles']));
          }
        }
      }

      final List<User> loadedFollowers = [];
      if (followersRes != null) {
        for (final item in followersRes as List) {
          if (item['profiles'] != null) {
            loadedFollowers.add(User.fromJson(item['profiles']));
          }
        }
      }

      final List<User> loadedFriends = [];
      if (friendsRes != null) {
        for (final item in friendsRes as List) {
          if (item['profiles'] != null) {
            loadedFriends.add(User.fromJson(item['profiles']));
          }
        }
      }

      _followingList.assignAll(loadedFollowing);
      _followersList.assignAll(loadedFollowers);
      _friendsList.assignAll(loadedFriends);
    } catch (e) {
      debugPrint('[ConnectionsScreen] Error loading connections: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _unfollowUser(User user) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: context.secondaryBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Unfollow ${user.displayName}?',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            'Are you sure you want to stop following this user?',
            style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: context.caption)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.errorColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await UserProfileCacheManager.unfollowUser(user.id);
                _loadConnections();
                Get.snackbar(
                  'Unfollowed 💔',
                  'You unfollowed ${user.displayName}',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: context.scaffoldBackgroundColor.withOpacity(0.9),
                  colorText: Colors.white,
                );
              },
              child: Text('Unfollow', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _removeFollower(User user) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: context.secondaryBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Remove Follower?',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            'Creaniaa will not tell ${user.displayName} they were removed from your followers.',
            style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: context.caption)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.errorColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  // Removing a follower means deleting their follow to us
                  await Supabase.instance.client
                      .from('connections')
                      .delete()
                      .eq('follower_id', user.id)
                      .eq('following_id', UserProfileCacheManager.currentUserId);
                  _loadConnections();
                } catch (_) {}
                Get.snackbar(
                  'Follower Removed 👤',
                  'Removed ${user.displayName} from followers.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: context.scaffoldBackgroundColor.withOpacity(0.9),
                  colorText: Colors.white,
                );
              },
              child: Text('Remove', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.targetUserName != null ? "${widget.targetUserName}'s Connections" : 'Connections';
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary, size: AppDimensions.minIconSize),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: AppTypography.title,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.primaryColor,
          labelColor: context.primaryColor,
          unselectedLabelColor: context.textSecondary,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          labelStyle: GoogleFonts.poppins(fontSize: 12.0, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12.0, fontWeight: FontWeight.w500),
          tabs: [
            Obx(() => Tab(height: AppDimensions.minTouchTarget, text: 'Following (${_followingList.length})')),
            Obx(() => Tab(height: AppDimensions.minTouchTarget, text: 'Followers (${_followersList.length})')),
            Obx(() => Tab(height: AppDimensions.minTouchTarget, text: 'Friends (${_friendsList.length})')),
          ],
        ),
      ),
      body: _isLoading
          ? const FollowersSkeletonWidget()
          : Column(
              children: [
                // Search Box
                Container(
                  padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding, vertical: AppSpacing.sm),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                    style: TextStyle(color: context.textPrimary, fontSize: AppTypography.body),
                    decoration: InputDecoration(
                      hintText: 'Search by name or SID...',
                      hintStyle: TextStyle(color: context.textSecondary, fontSize: AppTypography.body),
                      prefixIcon: Icon(Icons.search, color: context.textSecondary, size: AppDimensions.minIconSize),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: context.textSecondary, size: AppDimensions.minIconSize),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: context.surfaceColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: context.borderColor, width: 0.8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: context.borderColor, width: 0.8),
                      ),
                    ),
                  ),
                ),

                // Lists View
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFollowingTab(),
                      _buildFollowersTab(),
                      _buildFriendsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFollowingTab() {
    return Obx(() {
      final filtered = _followingList.where((u) {
        return u.displayName.toLowerCase().contains(_searchQuery) ||
            u.sid.contains(_searchQuery);
      }).toList();

      if (filtered.isEmpty) {
        return _buildEmptyState('No following found');
      }

      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filtered.length,
        separatorBuilder: (c, idx) => Divider(color: context.borderColor.withOpacity(0.5), height: 16),
        itemBuilder: (c, idx) {
          final u = filtered[idx];
          final isMe = u.id == UserProfileCacheManager.currentUserId;
          return _buildUserTile(
            user: u,
            actionButton: isMe
                ? const SizedBox.shrink()
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.borderColor),
                      backgroundColor: context.surfaceColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size(80, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () => _unfollowUser(u),
                    child: Text(
                      'Following',
                      style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
          );
        },
      );
    });
  }

  Widget _buildFollowersTab() {
    return Obx(() {
      final filtered = _followersList.where((u) {
        return u.displayName.toLowerCase().contains(_searchQuery) ||
            u.sid.contains(_searchQuery);
      }).toList();

      if (filtered.isEmpty) {
        return _buildEmptyState('No followers found');
      }

      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filtered.length,
        separatorBuilder: (c, idx) => Divider(color: context.borderColor.withOpacity(0.5), height: 16),
        itemBuilder: (c, idx) {
          final u = filtered[idx];
          final isMe = u.id == UserProfileCacheManager.currentUserId;

          return Obx(() {
            final isFollowingBack = UserProfileCacheManager.followedUserIds.contains(u.id);
            return _buildUserTile(
              user: u,
              actionButton: isMe
                  ? const SizedBox.shrink()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isFollowingBack)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              minimumSize: const Size(80, 32),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: () async {
                              await UserProfileCacheManager.followUser(u.id);
                              _loadConnections();
                            },
                            child: Text(
                              'Follow Back',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          )
                        else
                          Text(
                            'Follows You',
                            style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 10),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.more_vert_rounded, color: context.textSecondary),
                          onPressed: () => _removeFollower(u),
                        ),
                      ],
                    ),
            );
          });
        },
      );
    });
  }

  Widget _buildFriendsTab() {
    return Obx(() {
      final filtered = _friendsList.where((u) {
        return u.displayName.toLowerCase().contains(_searchQuery) ||
            u.sid.contains(_searchQuery);
      }).toList();

      if (filtered.isEmpty) {
        return _buildEmptyState('No mutual friends found');
      }

      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filtered.length,
        separatorBuilder: (c, idx) => Divider(color: context.borderColor.withOpacity(0.5), height: 16),
        itemBuilder: (c, idx) {
          final u = filtered[idx];
          final isMe = u.id == UserProfileCacheManager.currentUserId;
          return _buildUserTile(
            user: u,
            actionButton: isMe
                ? const SizedBox.shrink()
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.borderColor),
                      backgroundColor: context.surfaceColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size(80, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () => _unfollowUser(u),
                    child: Text(
                      'Unfollow',
                      style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
          );
        },
      );
    });
  }

  Widget _buildUserTile({required User user, required Widget actionButton}) {
    return Obx(() {
      final isMutual = UserProfileCacheManager.followedUserIds.contains(user.id) &&
          UserProfileCacheManager.followerUserIds.contains(user.id);

      return InkWell(
        onTap: () {
          final isMe = user.id == UserProfileCacheManager.currentUserId;
          if (isMe) {
            Get.to(() => const ProfileScreen());
          } else {
            Get.to(() => ProfileScreen(visitorUser: user));
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            children: [
              // Avatar
              CustomAvatarFrame(
                userId: user.id,
                username: user.displayName,
                size: 48,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: user.avatar != null && user.avatar!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: user.avatar!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: context.primaryColor.withOpacity(0.1),
                            child: Center(
                              child: Text(
                                user.displayName.isNotEmpty ? user.displayName[0] : 'U',
                                style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user.displayName,
                          style: GoogleFonts.poppins(
                            color: context.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (user.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, color: Color(0xFF60A5FA), size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'ID: ${user.sid}',
                          style: GoogleFonts.poppins(
                            color: context.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        if (isMutual) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 0.5),
                            ),
                            child: Text(
                              'Mutual',
                              style: GoogleFonts.poppins(color: const Color(0xFF10B981), fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Action Button
              actionButton,
            ],
          ),
        ),
      );
    });
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off_rounded, color: context.caption, size: 48),
          SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.poppins(color: context.caption, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
