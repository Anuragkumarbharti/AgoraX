import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:creania/core/theme.dart';
import 'package:intl/intl.dart';
import '../../models/community/community_model.dart';
import '../../models/community/community_event_model.dart';
import '../../models/user/user_model.dart';
import '../../services/community/community_controller.dart';
import '../../services/user/user_profile_cache_manager.dart';
import '../profile/profile_screen.dart';
import '../../widgets/gems/gem_widgets.dart';
import '../../widgets/community/community_join_button.dart';

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
  String _selectedRankType = 'top_contributors';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _controller.loadCommunityAdditions(widget.communityId);
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
        color = context.accentGold;
        break;
      case 'Co-Owner':
        color = context.accentOrange;
        break;
      case 'Admin':
        color = context.accentPurple;
        break;
      default:
        color = context.accentBlue;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          backgroundColor: context.scaffoldBackgroundColor,
          body: Center(child: Text('Community not found', style: TextStyle(color: Colors.white))),
        );
      }

      final role = _controller.getUserRole(comm);
      final isMember = role != 'Guest';

      return Scaffold(
        backgroundColor: context.scaffoldBackgroundColor,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildSliverAppBar(comm, role, isMember),
            SliverToBoxAdapter(child: _buildHeader(comm, role, isMember)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: context.primaryColor,
                  indicatorWeight: 3,
                  labelColor: context.primaryColor,
                  unselectedLabelColor: context.caption,
                  tabs: const [
                    Tab(text: 'Home'),
                    Tab(text: 'Members'),
                    Tab(text: 'Events'),
                    Tab(text: 'Tasks / Logo'),
                    Tab(text: 'Rankings'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildHomeTab(comm, isMember, role),
              _buildMembersTab(comm),
              _buildEventsTab(comm, role, isMember),
              _buildTasksTab(comm),
              _buildRankingsTab(comm),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSliverAppBar(Community comm, String role, bool isMember) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: context.scaffoldBackgroundColor,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.32),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Get.back(),
        ),
      ),
      actions: [
        if (isMember && ['Owner', 'Co-Owner'].contains(role))
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.32),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
              onPressed: () {
                _showSettingsDialog(context, comm);
              },
            ),
          ),
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.32),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
            onPressed: () {
              Get.snackbar('Link Shared', 'Link copied to clipboard');
            },
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                context.primaryColor.withOpacity(0.8),
                Color(0xFF0F172A),
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
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  gradient: LinearGradient(
                    colors: [context.primaryColor, AppTheme.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: context.primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: (comm.image != null && (comm.image!.startsWith('http://') || comm.image!.startsWith('https://')))
                      ? CachedNetworkImage(
                          imageUrl: comm.image!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
                          errorWidget: (context, url, error) => Center(
                            child: Text(
                              comm.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            comm.image ?? comm.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comm.name,
                          style: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (comm.isVerified) ...[
                          SizedBox(width: 6),
                          Icon(Icons.verified_rounded, color: context.accentBlue, size: 18),
                        ],
                      ],
                    ),
                    const SizedBox.shrink(),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: context.primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: context.primaryColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            'Family Lv.${comm.level}',
                            style: TextStyle(color: context.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 8),
                        _buildRoleLabel(role),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Join/Leave/Actions row
          Row(
            children: [
              Expanded(
                child: CommunityJoinButton(
                  community: comm,
                  height: 40,
                  borderRadius: 10.0,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                ),
              ),
              if (isMember) ...[
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Get.snackbar('Entering Room...', 'Joining community voice room');
                    },
                    icon: Icon(Icons.mic_rounded, size: 16),
                    label: Text('Family Stage'),
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

  void _showApplyDialog(BuildContext context, Community comm, CommunityController ctrl) {
    final introController = TextEditingController();
    final reasonController = TextEditingController();
    String selectedLanguage = 'English';

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1B1D2A),
        title: Text(
          'Apply to ${comm.name}',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This community requires approval to join. Please fill in the details below.',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Text(
                'Introduce Yourself',
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: introController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g., Hi, I am a software engineering student...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF2E303F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Reason for Joining',
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g., I want to practice DSA questions daily...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF2E303F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Preferred Language',
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              StatefulBuilder(
                builder: (context, setState) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E303F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedLanguage,
                      dropdownColor: const Color(0xFF1B1D2A),
                      underline: const SizedBox(),
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: ['English', 'Hindi', 'Spanish', 'French', 'German'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedLanguage = val;
                          });
                        }
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (introController.text.trim().isEmpty || reasonController.text.trim().isEmpty) {
                Get.snackbar('Required Fields', 'Please fill in all the details.', backgroundColor: Colors.amber, colorText: Colors.black);
                return;
              }
              Get.back();
              final error = await ctrl.joinCommunity(
                comm.id,
                introduction: introController.text,
                reason: reasonController.text,
                preferredLanguage: selectedLanguage,
              );
              if (error != null) {
                Get.snackbar('Error', error, backgroundColor: Colors.redAccent, colorText: Colors.white);
              } else {
                Get.snackbar(
                  'Success',
                  'Your application has been submitted successfully!',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            child: Text('Submit', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(Community comm, bool isMember, String role) {
    return ListView(
      padding: EdgeInsets.all(20),
      children: [
        // Latest / Pinned Announcement
        Obx(() {
          final pinned = _controller.communityAnnouncements.firstWhereOrNull((a) => a.isPinned);
          final latest = pinned ?? (_controller.communityAnnouncements.isNotEmpty ? _controller.communityAnnouncements.first : null);
          if (latest == null) return const SizedBox();
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155), width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.campaign_rounded, color: Colors.orangeAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(latest.isPinned ? 'Pinned Announcement' : 'Announcement',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (isMember && ['Owner', 'Co-Owner'].contains(role))
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _controller.deleteAnnouncement(comm.id, latest.id),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(latest.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(latest.content, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.45)),
              ],
            ),
          );
        }),

        // Daily Check-In button for members
        if (isMember) ...[
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _controller.checkIn(comm.id),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Daily Check-In (+50 EXP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primaryColor.withOpacity(0.12),
                foregroundColor: context.primaryColor,
                side: BorderSide(color: context.primaryColor.withOpacity(0.4), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Level Progression Card
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: context.secondaryBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Family Progression', style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(comm.level >= 7 ? 'Max Level' : 'Lv. ${comm.level} ➔ Lv. ${comm.level + 1}',
                      style: TextStyle(color: context.accentGold, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: comm.currentLevelProgress,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(context.primaryColor),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${comm.xp} / ${comm.requiredExpForNextLevel} EXP',
                      style: TextStyle(color: context.caption, fontSize: 11)),
                  Text('${(comm.currentLevelProgress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(color: context.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              // Stats details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statCol('Lifetime', '${comm.lifetimeExp}'),
                  _statCol('Daily', '${comm.dailyExp}'),
                  _statCol('Weekly', '${comm.weeklyExp}'),
                  _statCol('Monthly', '${comm.monthlyExp}'),
                  _statCol('Activity', '${comm.activityScore}'),
                ],
              ),
              const SizedBox(height: 16),
              // Role Capacity Rewards Limits
              Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 14, color: Colors.cyan),
                  const SizedBox(width: 6),
                  Text(
                    'Limits: Owner (1) • Co-Owners (${comm.coOwnerLimit}) • Admins (${comm.adminLimit})',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
              if (comm.level >= 5 && !comm.isVerified) ...[
                const Divider(height: 24, color: Colors.white10),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () {
                      Get.snackbar(
                        'Verification Application',
                        'Verification application submitted! Under platform review.',
                        backgroundColor: Colors.green,
                        colorText: Colors.white,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Apply for Official Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Bio Section
        Text('Bio / Description', style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text(comm.description, style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.5)),
        SizedBox(height: 24),

        // Rules Section
        Text('Family Rules', style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.secondaryBackgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(comm.rules, style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.5)),
        ),
        SizedBox(height: 24),

        // Stats Card
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.secondaryBackgroundColor,
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
        Text(value, style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text(label, style: TextStyle(color: context.caption, fontSize: 11)),
      ],
    );
  }

  Widget _infoStatDivider() {
    return Container(width: 1, height: 24, color: context.borderColor);
  }

  Widget _buildMembersTab(Community comm) {
    final ownerId = comm.owner;
    final coOwners = comm.coOwnerIds;
    final admins = comm.admins;
    
    // Ordinary members
    final members = comm.members.where((id) => id != ownerId && !coOwners.contains(id) && !admins.contains(id)).toList();

    return ListView(
      padding: EdgeInsets.all(20),
      children: [
        // Owner
        _memberSectionTitle('Owner'),
        _memberTile(comm, ownerId, 'Owner'),
        SizedBox(height: 16),

        // Co-Owners
        if (coOwners.isNotEmpty) ...[
          _memberSectionTitle('Co-Owners'),
          ...coOwners.map((id) => _memberTile(comm, id, 'Co-Owner')),
          SizedBox(height: 16),
        ],

        // Admins
        if (admins.isNotEmpty) ...[
          _memberSectionTitle('Admins'),
          ...admins.map((id) => _memberTile(comm, id, 'Admin')),
          SizedBox(height: 16),
        ],

        // Members
        _memberSectionTitle('Members (${members.length})'),
        if (members.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No other members', style: TextStyle(color: context.caption, fontSize: 13)),
          )
        else
          ...members.map((id) => _memberTile(comm, id, 'Member')),
      ],
    );
  }

  Widget _memberSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(title, style: TextStyle(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _memberTile(Community comm, String userId, String roleLabel) {
    return FutureBuilder<User>(
      future: UserProfileCacheManager.fetchUserProfile(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 54,
            decoration: BoxDecoration(
              color: context.secondaryBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
          );
        }

        final user = snapshot.data;
        final String displayName = user?.displayName ?? 'Community Member';
        final String username = user?.username ?? '';
        final avatar = user?.avatar;

        return GestureDetector(
          onTap: () {
            if (user != null) {
              Get.to(() => ProfileScreen(visitorUser: user));
            }
          },
          onLongPress: () {
            _showMemberMiniProfile(context, comm, userId, displayName, roleLabel);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.secondaryBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor.withOpacity(0.3), width: 0.5),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: context.primaryColor.withOpacity(0.2),
                  backgroundImage: avatar != null && avatar.isNotEmpty
                      ? NetworkImage(avatar)
                      : null,
                  child: avatar == null || avatar.isEmpty
                      ? Text(
                          displayName.substring(0, 1).toUpperCase(),
                          style: TextStyle(color: context.primaryColor, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                      if (username.isNotEmpty)
                        Text('@$username', style: TextStyle(color: context.caption, fontSize: 11)),
                    ],
                  ),
                ),
                _buildRoleLabel(roleLabel),
              ],
            ),
          ),
        );
      },
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
        decoration: BoxDecoration(
          color: context.secondaryBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Profile Info Header
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: context.primaryColor.withOpacity(0.2),
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: TextStyle(color: context.primaryColor, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          _buildRoleLabel(currentRole),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Mini Profile Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniProfileStat('Level 14', 'Gamification'),
                _miniProfileStat('Verified', 'Status'),
                _miniProfileStat('Active', 'Activity'),
              ],
            ),
            SizedBox(height: 20),

            Divider(color: context.borderColor, height: 1),
            SizedBox(height: 16),

            // Management actions (if allowed)
            if (canManageOrKick) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text('MANAGE MEMBER ROLE', style: TextStyle(color: context.caption, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 8),
              
              // Promote/Demote to Co-owner (Only Owner can assign Co-owner)
              if (canManage && myRole == 'Owner') ...[
                _actionTile(
                  icon: Icons.workspace_premium_rounded,
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
                  color: context.errorColor,
                  label: 'Remove from Family',
                  onTap: () {
                    Get.back();
                    _controller.kickMember(comm.id, userId);
                    Get.snackbar('Member Removed', '$name has been removed from the family.');
                  },
                ),
            ] else ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No management actions available for this member.', style: TextStyle(color: context.caption, fontSize: 13)),
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
        Text(value, style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
        SizedBox(height: 2),
        Text(label, style: TextStyle(color: context.caption, fontSize: 11)),
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
      title: Text(label, style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right_rounded, color: context.caption, size: 16),
    );
  }

  Widget _buildTasksTab(Community comm) {
    if (comm.creationType == 'coins') {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GemIcon(size: 52),
              SizedBox(height: 12),
              Text(
                'Verified Coins Family',
                style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'This community was created using Coins. Logo and Profile Badge are permanently unlocked.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.caption, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final allDone = comm.isLogoUnlocked;

    return ListView(
      padding: EdgeInsets.all(20),
      children: [
        // Badge unlock banner
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: allDone ? context.successColor.withOpacity(0.12) : context.accentBlue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: allDone ? context.successColor.withOpacity(0.3) : context.accentBlue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                allDone ? Icons.check_circle_rounded : Icons.lock_rounded,
                color: allDone ? context.successColor : context.accentBlue,
                size: 32,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allDone ? 'Logo Badge Unlocked! 🎉' : 'Profile Badge Locked',
                      style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      allDone
                          ? 'Your community logo is now visible on all members\' profiles.'
                          : 'Complete all milestones below to display this community badge on your profile.',
                      style: TextStyle(color: context.textSecondary, fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24),

        Text(
          'Tasks to Complete',
          style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),

        ...comm.tasks.map((task) {
          final pct = task.target > 0 ? (task.current / task.target).clamp(0.0, 1.0) : 0.0;
          return Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.secondaryBackgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(task.title, style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                    Text(
                      '${task.current}/${task.target}',
                      style: TextStyle(
                        color: task.isCompleted ? context.successColor : context.primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(task.description, style: TextStyle(color: context.caption, fontSize: 11)),
                SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: context.scaffoldBackgroundColor,
                    valueColor: AlwaysStoppedAnimation(task.isCompleted ? context.successColor : context.primaryColor),
                  ),
                ),
              ],
            ),
          );
        }).toList(),

        if (comm.owner == 'me' && !allDone) ...[
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              // Dev shortcut to complete tasks
              for (var t in comm.tasks) {
                _controller.updateTaskProgress(comm.id, t.id, t.target);
              }
              Get.snackbar('Milestones Achieved!', 'All tasks completed. Community logo unlocked!');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.secondaryBackgroundColor,
              foregroundColor: context.textPrimary,
            ),
            child: Text('Admin Dev: Auto-Complete Tasks'),
          ),
        ],
      ],
    );
  }

  Widget _statCol(String title, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(color: context.caption, fontSize: 10)),
      ],
    );
  }

  Widget _buildRankingsTab(Community comm) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _controller.getLeaderboard(comm.id, _selectedRankType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFBEC2FF)));
        }
        final list = snapshot.data ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ranking Type', style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: _selectedRankType,
                    dropdownColor: const Color(0xFF1B1D2A),
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: const [
                      DropdownMenuItem(value: 'top_contributors', child: Text('Top Contributors')),
                      DropdownMenuItem(value: 'top_gift_senders', child: Text('Top Senders (Coins)')),
                      DropdownMenuItem(value: 'top_gift_receivers', child: Text('Top Receivers (Stars)')),
                      DropdownMenuItem(value: 'top_active_members', child: Text('Top Active Members')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedRankType = val;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(child: Text('No ranking data available', style: TextStyle(color: context.caption)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final item = list[index];
                        final displayName = item['display_name'] ?? 'User';
                        final username = item['username'] ?? '';
                        final scoreVal = item['contribution'] ?? item['total_sent'] ?? item['total_received'] ?? item['activity_score'] ?? 0;
                        final avatarUrl = item['avatar'];
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.secondaryBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.borderColor.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Text('${index + 1}', style: TextStyle(color: index < 3 ? context.accentGold : Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 12),
                              CircleAvatar(
                                radius: 18,
                                backgroundImage: avatarUrl != null && avatarUrl.toString().isNotEmpty
                                    ? NetworkImage(avatarUrl.toString())
                                    : null,
                                child: avatarUrl == null || avatarUrl.toString().isEmpty
                                    ? Text(displayName.substring(0, 1).toUpperCase())
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                    if (username.isNotEmpty)
                                      Text('@$username', style: TextStyle(color: context.caption, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Text('$scoreVal', style: TextStyle(color: context.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEventsTab(Community comm, String role, bool isMember) {
    final canManage = isMember && ['Owner', 'Co-Owner', 'Admin'].contains(role);
    return Obx(() {
      final list = _controller.communityEvents;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (canManage) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showCreateEventDialog(context, comm),
                    icon: const Icon(Icons.add_box_rounded, size: 16),
                    label: const Text('Host Event', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCreateAnnouncementDialog(context, comm),
                    icon: const Icon(Icons.campaign_rounded, size: 16),
                    label: const Text('Post Notice', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.primaryColor),
                      foregroundColor: context.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          if (list.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Text('No community events scheduled yet.', style: TextStyle(color: context.caption, fontSize: 13)),
              ),
            )
          else
            ...list.map((event) {
              final isRegistered = false; // Simulated participant enrollment
              Color statusColor;
              switch (event.status) {
                case 'live': statusColor = Colors.green; break;
                case 'upcoming': statusColor = Colors.blue; break;
                case 'completed': statusColor = Colors.grey; break;
                case 'cancelled': statusColor = Colors.red; break;
                default: statusColor = Colors.blue;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.secondaryBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            event.status.toUpperCase(),
                            style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (canManage && event.status != 'cancelled')
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _controller.cancelEvent(comm.id, event.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(event.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    if (event.description != null) ...[
                      const SizedBox(height: 6),
                      Text(event.description!, style: TextStyle(color: context.caption, fontSize: 12, height: 1.45)),
                    ],
                    const Divider(height: 24, color: Colors.white10),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 13, color: Colors.white54),
                        const SizedBox(width: 6),
                        Text(
                          '${DateFormat.yMMMd().add_jm().format(event.startTime)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                    if (event.rewards != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded, size: 13, color: Colors.amber),
                          const SizedBox(width: 6),
                          Text(event.rewards!, style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (isMember && event.status == 'upcoming')
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () => _controller.registerForEvent(comm.id, event.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.primaryColor.withOpacity(0.2),
                            foregroundColor: context.primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Register for Event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      );
    });
  }

  void _showSettingsDialog(BuildContext context, Community comm) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1B1D2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Family Settings', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Colors.white70),
                title: const Text('Edit Details', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Get.back();
                  _showEditDetailsDialog(context, comm);
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics_outlined, color: Colors.white70),
                title: const Text('View Analytics', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Get.back();
                  _showAnalyticsDialog(context, comm);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history_edu_rounded, color: Colors.white70),
                title: const Text('View Audit Logs', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Get.back();
                  _showLogsDialog(context, comm);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDetailsDialog(BuildContext context, Community comm) {
    final nameController = TextEditingController(text: comm.name);
    final descController = TextEditingController(text: comm.description);
    final rulesController = TextEditingController(text: comm.rules);
    String selectedJoinMode = comm.joinMode;
    File? selectedCoverImage;
    String? uploadedCoverUrl = comm.image?.isNotEmpty == true ? comm.image : null;
    bool isUploadingCover = false;

    // Collect member profiles for owner/co-owner/admin display
    final allUserIds = <String>{
      comm.owner,
      ...comm.coOwnerIds,
      ...comm.admins,
    }.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          // ─── helpers ───────────────────────────────────────────
          Future<void> pickCover() async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 1200,
              maxHeight: 600,
              imageQuality: 88,
            );
            if (picked == null) return;
            setSheetState(() {
              selectedCoverImage = File(picked.path);
              isUploadingCover = true;
              uploadedCoverUrl = null;
            });
            try {
              final ext = picked.path.split('.').last.toLowerCase();
              final fileName =
                  'community_covers/${comm.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
              final bytes = await selectedCoverImage!.readAsBytes();
              await Supabase.instance.client.storage
                  .from('avatars')
                  .uploadBinary(fileName, bytes,
                      fileOptions:
                          FileOptions(contentType: 'image/$ext', upsert: true));
              final url = Supabase.instance.client.storage
                  .from('avatars')
                  .getPublicUrl(fileName);
              setSheetState(() {
                uploadedCoverUrl = url;
                isUploadingCover = false;
              });
            } catch (_) {
              setSheetState(() => isUploadingCover = false);
              Get.snackbar('Upload Failed', 'Could not upload cover image.',
                  backgroundColor: Colors.redAccent, colorText: Colors.white);
            }
          }

          Widget _roleChip(String label, Color color) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              );

          Widget _memberCard(String userId, String role, Color roleColor) {
            final cached = UserProfileCacheManager.getCachedUser(userId);
            final username = cached?.username ?? userId.substring(0, 8);
            final avatar = cached?.avatar ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF252737),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: roleColor.withOpacity(0.25), width: 1),
              ),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: roleColor.withOpacity(0.2),
                    backgroundImage:
                        avatar.isNotEmpty ? NetworkImage(avatar) : null,
                    child: avatar.isEmpty
                        ? Text(username[0].toUpperCase(),
                            style: TextStyle(
                                color: roleColor,
                                fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('@$username',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const SizedBox.shrink(),
                      ],
                    ),
                  ),
                  _roleChip(role, roleColor),
                ],
              ),
            );
          }

          InputDecoration _fieldDecor(String label, IconData icon) =>
              InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                prefixIcon: Icon(icon, color: Colors.white38, size: 18),
                filled: true,
                fillColor: const Color(0xFF252737),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF7C5CFC), width: 1.5),
                ),
              );

          // ─── Sheet body ────────────────────────────────────────
          return DraggableScrollableSheet(
            initialChildSize: 0.92,
            minChildSize: 0.6,
            maxChildSize: 0.97,
            expand: false,
            builder: (_, scrollCtrl) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1B1D2A),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  // header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_rounded,
                            color: Color(0xFF7C5CFC), size: 22),
                        const SizedBox(width: 10),
                        Text('Edit Community',
                            style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white54),
                            onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  // scrollable content
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      children: [

                        // ── Cover Image ──────────────────────────
                        Text('Cover Image',
                            style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: isUploadingCover ? null : pickCover,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 150,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: uploadedCoverUrl != null
                                    ? Colors.greenAccent.withOpacity(0.5)
                                    : Colors.white12,
                                width: 1.5,
                              ),
                              color: const Color(0xFF252737),
                            ),
                            child: isUploadingCover
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                            color: Color(0xFF7C5CFC),
                                            strokeWidth: 2),
                                        SizedBox(height: 10),
                                        Text('Uploading...',
                                            style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 13)),
                                      ],
                                    ),
                                  )
                                : selectedCoverImage != null
                                    ? Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            child: Image.file(
                                              selectedCoverImage!,
                                              width: double.infinity,
                                              height: 150,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          // green tick
                                          if (uploadedCoverUrl != null)
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.green,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                    Icons.check_rounded,
                                                    color: Colors.white,
                                                    size: 14),
                                              ),
                                            ),
                                          // change chip
                                          Positioned(
                                            bottom: 8,
                                            right: 8,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.black54,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.edit_rounded,
                                                      color: Colors.white,
                                                      size: 12),
                                                  SizedBox(width: 4),
                                                  Text('Change',
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : uploadedCoverUrl != null && uploadedCoverUrl!.startsWith('http')
                                        ? Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                child: CachedNetworkImage(
                                                  imageUrl: uploadedCoverUrl!,
                                                  width: double.infinity,
                                                  height: 150,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 8,
                                                right: 8,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius:
                                                        BorderRadius.circular(20),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.edit_rounded,
                                                          color: Colors.white,
                                                          size: 12),
                                                      SizedBox(width: 4),
                                                      Text('Change',
                                                          style: TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 11)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                  Icons
                                                      .add_photo_alternate_rounded,
                                                  color: Color(0xFF7C5CFC),
                                                  size: 36),
                                              const SizedBox(height: 8),
                                              const Text(
                                                  'Tap to upload cover image',
                                                  style: TextStyle(
                                                      color: Colors.white54,
                                                      fontSize: 13)),
                                              const SizedBox(height: 4),
                                              Text('Visible to all members',
                                                  style: TextStyle(
                                                      color: Colors.white38
                                                          .withOpacity(0.6),
                                                      fontSize: 11)),
                                            ],
                                          ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Basic Info fields ────────────────────
                        Text('Basic Info',
                            style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _fieldDecor(
                              'Family Name', Icons.group_rounded),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descController,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 3,
                          decoration: _fieldDecor(
                              'Description', Icons.info_outline_rounded),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: rulesController,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 2,
                          decoration: _fieldDecor(
                              'Community Rules', Icons.gavel_rounded),
                        ),
                        const SizedBox(height: 12),

                        // Join Mode dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF252737),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedJoinMode,
                              dropdownColor: const Color(0xFF252737),
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white54),
                              items: const [
                                DropdownMenuItem(
                                  value: 'auto_join',
                                  child: Row(children: [
                                    Icon(Icons.flash_on_rounded,
                                        color: Colors.amber, size: 16),
                                    SizedBox(width: 8),
                                    Text('Auto Join',
                                        style:
                                            TextStyle(color: Colors.white)),
                                  ]),
                                ),
                                DropdownMenuItem(
                                  value: 'approval_required',
                                  child: Row(children: [
                                    Icon(Icons.verified_user_rounded,
                                        color: Colors.blue, size: 16),
                                    SizedBox(width: 8),
                                    Text('Apply to Join',
                                        style:
                                            TextStyle(color: Colors.white)),
                                  ]),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null)
                                  setSheetState(
                                      () => selectedJoinMode = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Members Section ──────────────────────
                        Row(
                          children: [
                            const Icon(Icons.people_alt_rounded,
                                color: Color(0xFF7C5CFC), size: 18),
                            const SizedBox(width: 8),
                            Text('Community Members',
                                style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Owner
                        _memberCard(comm.owner, 'Owner',
                            const Color(0xFFFFD700)),

                        // Co-owners
                        ...comm.coOwnerIds.map((id) =>
                            _memberCard(id, 'Co-Owner',
                                const Color(0xFF7C5CFC))),

                        // Admins
                        ...comm.admins
                            .where((id) => id != comm.owner && !comm.coOwnerIds.contains(id))
                            .map((id) => _memberCard(
                                id, 'Admin', const Color(0xFF00BCD4))),

                        if (comm.coOwnerIds.isEmpty && comm.admins.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                  'No co-owners or admins assigned yet.',
                                  style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12)),
                            ),
                          ),

                        const SizedBox(height: 32),

                        // ── Save button ──────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.save_rounded,
                                size: 18),
                            label: Text('Save Changes',
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C5CFC),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final finalImage =
                                  uploadedCoverUrl ?? comm.image ?? '';
                              final success = await _controller
                                  .updateCommunitySettings(comm.id, {
                                'name': nameController.text,
                                'banner': finalImage,
                                'image': finalImage,
                                'description': descController.text,
                                'rules': rulesController.text,
                                'join_mode': selectedJoinMode,
                                'min_id_level': comm.minIdLevel,
                                'language': comm.language,
                                'country': comm.country,
                                'category': comm.category,
                                'visibility': comm.visibility,
                              });
                              if (success) {
                                Get.snackbar('Saved! ✅',
                                    'Community updated successfully.',
                                    backgroundColor: Colors.green,
                                    colorText: Colors.white);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreateAnnouncementDialog(BuildContext context, Community comm) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    bool isPinned = false;

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1B1D2A),
        title: Text('Post Notice', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Title', labelStyle: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Content', labelStyle: TextStyle(color: Colors.white70)),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Pin announcement', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  value: isPinned,
                  onChanged: (val) {
                    if (val != null) setState(() => isPinned = val);
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty || contentController.text.isEmpty) return;
              Get.back();
              final success = await _controller.createAnnouncement(comm.id, titleController.text, contentController.text, isPinned);
              if (success) {
                Get.snackbar('Notice Posted', 'Announcement successfully created.', backgroundColor: Colors.green, colorText: Colors.white);
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  void _showCreateEventDialog(BuildContext context, Community comm) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final rewardsController = TextEditingController();
    final rulesController = TextEditingController();
    final durationHrsController = TextEditingController(text: '2');

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1B1D2A),
        title: Text('Host Family Event', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Event Name', labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rewardsController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Rewards (e.g. 500 Coins)', labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rulesController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Rules', labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationHrsController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duration (Hours)', labelStyle: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              Get.back();
              final start = DateTime.now().add(const Duration(minutes: 5));
              final end = start.add(Duration(hours: int.tryParse(durationHrsController.text) ?? 2));
              final success = await _controller.createCommunityEvent(
                comm.id,
                nameController.text,
                comm.image ?? '',
                descController.text,
                start,
                end,
                CommunityController.currentUserId,
                [],
                50,
                rewardsController.text,
                rulesController.text,
              );
              if (success) {
                Get.snackbar('Event Scheduled', 'Your event is now listed in the Events tab.', backgroundColor: Colors.green, colorText: Colors.white);
              }
            },
            child: const Text('Host'),
          ),
        ],
      ),
    );
  }

  void _showAnalyticsDialog(BuildContext context, Community comm) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1B1D2A),
        title: Text('Family Analytics', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: FutureBuilder<Map<String, dynamic>?>(
          future: _controller.getCommunityAnalytics(comm.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final data = snapshot.data;
            if (data == null) {
              return const Text('Analytics currently unavailable.', style: TextStyle(color: Colors.white70));
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _analyticRow('Total Members', '${data['total_members'] ?? 0}'),
                _analyticRow('Daily Active', '${data['daily_active'] ?? 0}'),
                _analyticRow('Weekly Active', '${data['weekly_active'] ?? 0}'),
                _analyticRow('Monthly Active', '${data['monthly_active'] ?? 0}'),
                _analyticRow('Join Requests', '${data['pending_join_requests'] ?? 0}'),
                _analyticRow('Level', '${data['current_level'] ?? 1}'),
                _analyticRow('Total EXP', '${data['total_exp'] ?? 0}'),
              ],
            );
          },
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogsDialog(BuildContext context, Community comm) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1B1D2A),
        title: Text('Action Audit Logs', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Obx(() {
            final logs = _controller.communityLogs;
            if (logs.isEmpty) {
              return const Center(child: Text('No audit logs captured.', style: TextStyle(color: Colors.white70)));
            }
            return ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${log.actionType.toUpperCase().replaceAll('_', ' ')}',
                        style: const TextStyle(color: Colors.cyan, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(log.description, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat.yMMMd().add_jm().format(log.createdAt),
                        style: const TextStyle(color: Colors.white30, fontSize: 9),
                      ),
                      const Divider(height: 12, color: Colors.white10),
                    ],
                  ),
                );
              },
            );
          }),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _analyticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
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
      color: context.scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) => false;
}
