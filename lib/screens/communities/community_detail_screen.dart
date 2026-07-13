import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../models/community_model.dart';
import '../../services/community_controller.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId;
  const CommunityDetailScreen({Key? key, required this.communityId}) : super(key: key);

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  final _controller = Get.find<CommunityController>();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildRoleLabel(String role) {
    Color color;
    switch (role) {
      case 'Owner':
        color = Colors.amber;
        break;
      case 'Co-Owner':
        color = Colors.orange;
        break;
      case 'Admin':
        color = Colors.purpleAccent;
        break;
      default:
        color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4), width: 0.8),
      ),
      child: Text(
        role,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final comm = _controller.communities.firstWhere(
        (c) => c.id == widget.communityId,
        orElse: () => Community(
          id: '',
          name: 'Not Found',
          username: '',
          description: '',
          category: '',
          type: 'public',
          owner: '',
          coOwnerIds: [],
          admins: [],
          members: [],
          memberCount: 0,
          isVerified: false,
          creationType: 'coins',
          tasks: [],
          createdAt: DateTime.now(),
        ),
      );

      if (comm.id.isEmpty) {
        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: const Center(child: Text('Community not found', style: TextStyle(color: Colors.white))),
        );
      }

      final role = _controller.getUserRole(comm);
      final isMember = role != 'Guest';

      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildSliverAppBar(comm),
            SliverToBoxAdapter(child: _buildHeader(comm, role, isMember)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.primaryColor,
                  indicatorWeight: 3,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: AppTheme.textTertiary,
                  tabs: const [
                    Tab(text: 'Home'),
                    Tab(text: 'Members'),
                    Tab(text: 'Tasks / Logo'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildHomeTab(comm),
              _buildMembersTab(comm),
              _buildTasksTab(comm),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSliverAppBar(Community comm) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppTheme.bgDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_rounded, color: Colors.white),
          onPressed: () {
            Get.snackbar('Link Shared', 'Link copied to clipboard');
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor.withOpacity(0.8),
                const Color(0xFF0F172A),
              ],
            ),
          ),
          child: Center(
            child: Opacity(
              opacity: 0.1,
              child: Icon(Icons.groups_rounded, size: 100, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Community comm, String role, bool isMember) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Logo
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    comm.image ?? comm.name.substring(0, 1),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comm.name,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (comm.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, color: Color(0xFF60A5FA), size: 18),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Family ID: ${comm.id.hashCode.abs() % 900000 + 100000}',
                      style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            'Family Lv.${comm.level}',
                            style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildRoleLabel(role),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Join/Leave/Actions row
          Row(
            children: [
              Expanded(
                child: isMember
                    ? OutlinedButton(
                        onPressed: () {
                          if (role == 'Owner') {
                            Get.snackbar('Action Denied', 'Owner cannot leave the community.');
                          } else {
                            _controller.leaveCommunity(comm.id);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.errorColor),
                          foregroundColor: AppTheme.errorColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Leave Family'),
                      )
                    : ElevatedButton(
                        onPressed: () => _controller.joinCommunity(comm.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Join Family'),
                      ),
              ),
              if (isMember) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Get.snackbar('Entering Room...', 'Joining community voice room');
                    },
                    icon: const Icon(Icons.mic_rounded, size: 16),
                    label: const Text('Family Stage'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(Community comm) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Bio Section
        const Text('Bio / Description', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(comm.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
        const SizedBox(height: 24),

        // Rules Section
        const Text('Family Rules', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.bgLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(comm.rules, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
        ),
        const SizedBox(height: 24),

        // Stats Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _infoStatItem('${comm.memberCount}', 'Members'),
              _infoStatDivider(),
              _infoStatItem(comm.category, 'Category'),
              _infoStatDivider(),
              _infoStatItem(comm.creationType == 'coins' ? 'Verified' : 'Task Lock', 'Badge Status'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
      ],
    );
  }

  Widget _infoStatDivider() {
    return Container(width: 1, height: 24, color: AppTheme.borderColor);
  }

  Widget _buildMembersTab(Community comm) {
    final ownerId = comm.owner;
    final coOwners = comm.coOwnerIds;
    final admins = comm.admins;
    
    // Ordinary members
    final members = comm.members.where((id) => id != ownerId && !coOwners.contains(id) && !admins.contains(id)).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Owner
        _memberSectionTitle('Owner'),
        _memberTile(comm, ownerId, 'Owner'),
        const SizedBox(height: 16),

        // Co-Owners
        if (coOwners.isNotEmpty) ...[
          _memberSectionTitle('Co-Owners'),
          ...coOwners.map((id) => _memberTile(comm, id, 'Co-Owner')),
          const SizedBox(height: 16),
        ],

        // Admins
        if (admins.isNotEmpty) ...[
          _memberSectionTitle('Admins'),
          ...admins.map((id) => _memberTile(comm, id, 'Admin')),
          const SizedBox(height: 16),
        ],

        // Members
        _memberSectionTitle('Members (${members.length})'),
        if (members.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No other members', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
          )
        else
          ...members.map((id) => _memberTile(comm, id, 'Member')),
      ],
    );
  }

  Widget _memberSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _memberTile(Community comm, String userId, String roleLabel) {
    final String name = userId == 'me'
        ? 'Anurag Kumar (You)'
        : (userId == 'u2'
            ? 'Priya Sharma'
            : (userId == 'u3'
                ? 'Rahul Verma'
                : (userId == 'u4' ? 'Ananya Patel' : 'Member $userId')));

    return GestureDetector(
      onTap: () => _showMemberMiniProfile(context, comm, userId, name, roleLabel),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.3), width: 0.5),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
              child: Text(name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            _buildRoleLabel(roleLabel),
          ],
        ),
      ),
    );
  }

  void _showMemberMiniProfile(
    BuildContext context,
    Community comm,
    String userId,
    String name,
    String currentRole,
  ) {
    final String myRole = _controller.getUserRole(comm);
    final bool canManage = _controller.hasPower(comm, 'manage_roles') && userId != CommunityController.currentUserId;

    final bool isTargetOwner = currentRole == 'Owner';
    final bool isTargetCoOwner = currentRole == 'Co-Owner';

    final bool canKick = (myRole == 'Owner' && !isTargetOwner) ||
        (myRole == 'Co-Owner' && !isTargetOwner && !isTargetCoOwner) ||
        (myRole == 'Admin' && currentRole == 'Member');

    final bool canManageOrKick = canManage || canKick;

    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Profile Info Header
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: AppTheme.primaryColor, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildRoleLabel(currentRole),
                          const SizedBox(width: 8),
                          Text('ID: ${userId.hashCode.abs() % 900000 + 100000}', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Mini Profile Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniProfileStat('Level 14', 'Gamification'),
                _miniProfileStat('Verified', 'Status'),
                _miniProfileStat('Active', 'Activity'),
              ],
            ),
            const SizedBox(height: 20),

            const Divider(color: AppTheme.borderColor, height: 1),
            const SizedBox(height: 16),

            // Management actions (if allowed)
            if (canManageOrKick) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('MANAGE MEMBER ROLE', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              
              // Promote/Demote to Co-owner (Only Owner can assign Co-owner)
              if (canManage && myRole == 'Owner') ...[
                _actionTile(
                  icon: Icons.star_rounded,
                  color: Colors.amber,
                  label: currentRole == 'Co-Owner' ? 'Demote from Co-Owner' : 'Make Co-Owner',
                  onTap: () {
                    Get.back();
                    _controller.promoteMember(comm.id, userId, currentRole == 'Co-Owner' ? 'member' : 'coOwner');
                    Get.snackbar('Role Updated', '$name is now ${currentRole == 'Co-Owner' ? 'a Member' : 'a Co-Owner'}.');
                  },
                ),
              ],

              // Promote/Demote to Admin (Owner & Co-owners can assign Admins)
              if (canManage && (myRole == 'Owner' || myRole == 'Co-Owner')) ...[
                if (myRole == 'Owner' || (currentRole != 'Owner' && currentRole != 'Co-Owner'))
                  _actionTile(
                    icon: Icons.security_rounded,
                    color: Colors.purpleAccent,
                    label: currentRole == 'Admin' ? 'Demote from Admin' : 'Make Admin',
                    onTap: () {
                      Get.back();
                      _controller.promoteMember(comm.id, userId, currentRole == 'Admin' ? 'member' : 'admin');
                      Get.snackbar('Role Updated', '$name is now ${currentRole == 'Admin' ? 'a Member' : 'an Admin'}.');
                    },
                  ),
              ],

              // Demote to Member (Owner & Co-owners can demote back to member)
              if (canManage && currentRole != 'Member' && currentRole != 'Owner') ...[
                if (myRole == 'Owner' || (myRole == 'Co-Owner' && currentRole != 'Co-Owner'))
                  _actionTile(
                    icon: Icons.person_outline_rounded,
                    color: Colors.blue,
                    label: 'Demote to Member',
                    onTap: () {
                      Get.back();
                      _controller.promoteMember(comm.id, userId, 'member');
                      Get.snackbar('Role Demoted', '$name is now a regular Member.');
                    },
                  ),
              ],

              // Kick from family
              if (canKick)
                _actionTile(
                  icon: Icons.gavel_rounded,
                  color: AppTheme.errorColor,
                  label: 'Remove from Family',
                  onTap: () {
                    Get.back();
                    _controller.kickMember(comm.id, userId);
                    Get.snackbar('Member Removed', '$name has been removed from the family.');
                  },
                ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No management actions available for this member.', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniProfileStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
      ],
    );
  }

  Widget _actionTile({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary, size: 16),
    );
  }

  Widget _buildTasksTab(Community comm) {
    if (comm.creationType == 'coins') {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stars_rounded, color: Colors.amber, size: 52),
              SizedBox(height: 12),
              Text(
                'Verified Coins Family',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'This community was created using Coins. Logo and Profile Badge are permanently unlocked.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final allDone = comm.isLogoUnlocked;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Badge unlock banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: allDone ? Colors.green.withOpacity(0.12) : Colors.blue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: allDone ? Colors.green.withOpacity(0.3) : Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                allDone ? Icons.check_circle_rounded : Icons.lock_rounded,
                color: allDone ? Colors.green : Colors.blue,
                size: 32,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allDone ? 'Logo Badge Unlocked! 🎉' : 'Profile Badge Locked',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      allDone
                          ? 'Your community logo is now visible on all members\' profiles.'
                          : 'Complete all milestones below to display this community badge on your profile.',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'Tasks to Complete',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        ...comm.tasks.map((task) {
          final pct = task.target > 0 ? (task.current / task.target).clamp(0.0, 1.0) : 0.0;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(task.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                    Text(
                      '${task.current}/${task.target}',
                      style: TextStyle(
                        color: task.isCompleted ? Colors.green : AppTheme.primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(task.description, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: AppTheme.bgDark,
                    valueColor: AlwaysStoppedAnimation(task.isCompleted ? Colors.green : AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
          );
        }).toList(),

        if (comm.owner == 'me' && !allDone) ...[
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              // Dev shortcut to complete tasks
              for (var t in comm.tasks) {
                _controller.updateTaskProgress(comm.id, t.id, t.target);
              }
              Get.snackbar('Milestones Achieved!', 'All tasks completed. Community logo unlocked!');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.bgLight,
              foregroundColor: Colors.white,
            ),
            child: const Text('Admin Dev: Auto-Complete Tasks'),
          ),
        ],
      ],
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.bgDark,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) => false;
}
