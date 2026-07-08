import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../models/user_model.dart';
import 'user_profile_screen.dart';
import '../../widgets/custom_avatar_frame.dart';

class ConnectionsScreen extends StatefulWidget {
  final int initialTabIndex; // 0 for Following, 1 for Followers
  const ConnectionsScreen({Key? key, this.initialTabIndex = 0}) : super(key: key);

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Mock list of following users
  final RxList<User> _followingList = <User>[
    User(
      id: 'uid_rahul_101',
      username: 'rahul_verma',
      email: 'rahul@example.com',
      displayName: 'Rahul Verma',
      avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      interests: ['Flutter', 'Dart'],
      communities: [],
      followers: 1400,
      following: 480,
      isVerified: true,
      isPremium: true,
      reputation: 517420,
      sid: '517420',
      level: 7,
    ),
    User(
      id: 'uid_priya_102',
      username: 'priya_sharma',
      email: 'priya@example.com',
      displayName: 'Priya Sharma',
      avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
      interests: ['AI', 'Python'],
      communities: [],
      followers: 2450,
      following: 310,
      isVerified: true,
      isPremium: false,
      reputation: 3450,
      sid: '320914',
      level: 12,
    ),
    User(
      id: 'uid_alex_103',
      username: 'alex_code',
      email: 'alex@example.com',
      displayName: 'Alex Mercer',
      avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
      interests: ['Go', 'Docker'],
      communities: [],
      followers: 980,
      following: 890,
      isVerified: false,
      isPremium: true,
      reputation: 8750,
      sid: '887612',
      level: 22,
    ),
    User(
      id: 'uid_sara_104',
      username: 'sara_design',
      email: 'sara@example.com',
      displayName: 'Sara Khan',
      avatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150',
      interests: ['UI/UX', 'Figma'],
      communities: [],
      followers: 4120,
      following: 200,
      isVerified: true,
      isPremium: true,
      reputation: 19800,
      sid: '614592',
      level: 15,
    ),
  ].obs;

  // Mock list of followers
  final RxList<User> _followersList = <User>[
    User(
      id: 'uid_rahul_101',
      username: 'rahul_verma',
      email: 'rahul@example.com',
      displayName: 'Rahul Verma',
      avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      interests: ['Flutter', 'Dart'],
      communities: [],
      followers: 1400,
      following: 480,
      isVerified: true,
      isPremium: true,
      reputation: 517420,
      sid: '517420',
      level: 7,
    ),
    User(
      id: 'uid_sara_104',
      username: 'sara_design',
      email: 'sara@example.com',
      displayName: 'Sara Khan',
      avatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150',
      interests: ['UI/UX', 'Figma'],
      communities: [],
      followers: 4120,
      following: 200,
      isVerified: true,
      isPremium: true,
      reputation: 19800,
      sid: '614592',
      level: 15,
    ),
    User(
      id: 'uid_kabir_105',
      username: 'kabir_singh',
      email: 'kabir@example.com',
      displayName: 'Kabir Dev',
      avatar: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150',
      interests: ['Node.js', 'React'],
      communities: [],
      followers: 530,
      following: 610,
      isVerified: false,
      isPremium: false,
      reputation: 980,
      sid: '109823',
      level: 4,
    ),
    User(
      id: 'uid_neha_106',
      username: 'neha_writes',
      email: 'neha@example.com',
      displayName: 'Neha Gupta',
      avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      interests: ['Writing', 'Poetry'],
      communities: [],
      followers: 1850,
      following: 410,
      isVerified: false,
      isPremium: true,
      reputation: 4320,
      sid: '776102',
      level: 9,
    ),
  ].obs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _unfollowUser(User user) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.bgLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Unfollow ${user.displayName}?',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            'Are you sure you want to stop following this user?',
            style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: AppTheme.textTertiary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                _followingList.removeWhere((item) => item.id == user.id);
                Navigator.pop(ctx);
                Get.snackbar(
                  'Unfollowed 💔',
                  'You unfollowed ${user.displayName}',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppTheme.bgDark.withOpacity(0.9),
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
          backgroundColor: AppTheme.bgLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Remove Follower?',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            'AgoraX will not tell ${user.displayName} they were removed from your followers.',
            style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: AppTheme.textTertiary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                _followersList.removeWhere((item) => item.id == user.id);
                Navigator.pop(ctx);
                Get.snackbar(
                  'Follower Removed 👤',
                  'Removed ${user.displayName} from followers.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppTheme.bgDark.withOpacity(0.9),
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
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Connections',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textTertiary,
          labelStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
          tabs: [
            Obx(() => Tab(text: 'Following (${_followingList.length})')),
            Obx(() => Tab(text: 'Followers (${_followersList.length})')),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name or SID...',
                hintStyle: const TextStyle(color: AppTheme.textTertiary),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textTertiary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.bgLight.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
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
        separatorBuilder: (c, idx) => const Divider(color: Colors.white10, height: 16),
        itemBuilder: (c, idx) {
          final u = filtered[idx];
          return _buildUserTile(
            user: u,
            actionButton: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.borderColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(80, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () => _unfollowUser(u),
              child: Text(
                'Following',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
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
        separatorBuilder: (c, idx) => const Divider(color: Colors.white10, height: 16),
        itemBuilder: (c, idx) {
          final u = filtered[idx];
          final isFollowingBack = _followingList.any((item) => item.id == u.id);

          return _buildUserTile(
            user: u,
            actionButton: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isFollowingBack)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size(80, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () {
                      _followingList.add(u);
                      Get.snackbar(
                        'Followed! 💖',
                        'You followed ${u.displayName}',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    },
                    child: Text(
                      'Follow Back',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textTertiary),
                  onPressed: () => _removeFollower(u),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildUserTile({required User user, required Widget actionButton}) {
    // Determine if mutual
    final isMutual = _followingList.any((item) => item.id == user.id) &&
        _followersList.any((item) => item.id == user.id);

    return InkWell(
      onTap: () => Get.to(() => UserProfileScreen(user: user)),
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
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          child: Center(
                            child: Text(
                              user.displayName.isNotEmpty ? user.displayName[0] : 'U',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                          color: Colors.white,
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
                          color: AppTheme.textTertiary,
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
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group_off_rounded, color: AppTheme.textTertiary, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.poppins(color: AppTheme.textTertiary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
