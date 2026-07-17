import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../core/theme.dart';
import '../../services/community_controller.dart';
import '../../models/community_model.dart';
import '../../models/community_event_model.dart';
import '../../models/user_model.dart';
import '../../services/user_profile_cache_manager.dart';
import '../profile/profile_screen.dart';
import 'community_detail_screen.dart';
import 'create_community_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({Key? key}) : super(key: key);

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> with SingleTickerProviderStateMixin {
  final _controller = Get.find<CommunityController>();

  // State filters
  final RxString _selectedFilter = 'Recommended'.obs;
  final RxString _selectedCategory = 'All'.obs;
  final RxString _searchQuery = ''.obs;
  final RxBool _isSearching = false.obs;
  final RxBool _filterOfficial = false.obs;
  final RxBool _filterVerified = false.obs;
  final RxString _selectedLanguage = 'All'.obs;

  final TextEditingController _searchTextController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Technology',
    'Design',
    'Music',
    'Gaming',
    'Education',
    'Entertainment',
    'Sports',
    'Business'
  ];

  final List<String> _languages = [
    'All',
    'English',
    'Hindi',
    'Spanish',
    'French',
    'German'
  ];

  @override
  void initState() {
    super.initState();
    _controller.syncFromSupabase();
  }

  @override
  void dispose() {
    _searchTextController.dispose();
    super.dispose();
  }

  Future<void> _checkCreationAndNavigate() async {
    final user = UserProfileCacheManager.getCachedUser(CommunityController.currentUserId);
    final userLevel = user?.level ?? 1;
    final userCoins = _controller.userCoins.value;

    int ticketCount = 0;
    try {
      final res = await Supabase.instance.client
          .from('inventory')
          .select('id')
          .eq('user_id', CommunityController.currentUserId)
          .or('asset_id.eq.community_creation_ticket,asset_id.eq.creation_ticket')
          .eq('status', 'Active');
      if (res != null && res is List) {
        ticketCount = res.length;
      }
    } catch (_) {}

    final hasLevel = userLevel >= 25;
    final hasCoins = userCoins >= 699;
    final hasTicket = ticketCount > 0;

    if (hasLevel || hasCoins || hasTicket) {
      Get.to(() => const CreateCommunityScreen());
    } else {
      _showRequirementsDialog(userLevel, userCoins, ticketCount);
    }
  }

  void _showRequirementsDialog(int currentLevel, int currentCoins, int currentTickets) {
    final hasLevel = currentLevel >= 25;
    final hasCoins = currentCoins >= 699;
    final hasTicket = currentTickets > 0;

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1B1D2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Requirements Unmet',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To create a family, you must meet at least ONE of the following criteria:',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
            ),
            const SizedBox(height: 16),
            _requirementItem('User Level 25 or above', hasLevel, 'Current: Lv.$currentLevel'),
            const SizedBox(height: 12),
            _requirementItem('699 Gold Coins', hasCoins, 'Current: $currentCoins Coins'),
            const SizedBox(height: 12),
            _requirementItem('Community Creation Ticket', hasTicket, 'Current: $currentTickets Tickets'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _requirementItem(String label, bool isMet, String detail) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isMet ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: isMet ? Colors.green : Colors.redAccent,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(detail, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  List<Community> _getFilteredCommunities() {
    List<Community> list = List.from(_controller.communities);

    // Search Query
    if (_searchQuery.value.trim().isNotEmpty) {
      final q = _searchQuery.value.toLowerCase().trim();
      list = list.where((c) =>
          c.name.toLowerCase().contains(q) ||
          c.id.toLowerCase().contains(q) ||
          c.username.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q) ||
          c.category.toLowerCase().contains(q)).toList();
    }

    // Category Filter
    if (_selectedCategory.value != 'All') {
      list = list.where((c) => c.category.toLowerCase() == _selectedCategory.value.toLowerCase()).toList();
    }

    // Language Filter
    if (_selectedLanguage.value != 'All') {
      list = list.where((c) => c.language.toLowerCase() == _selectedLanguage.value.toLowerCase()).toList();
    }

    // Official Check
    if (_filterOfficial.value) {
      list = list.where((c) => c.isOfficial || c.type == 'Official').toList();
    }

    // Verified Check
    if (_filterVerified.value) {
      list = list.where((c) => c.isVerified).toList();
    }

    // Sort order based on select tab filter
    switch (_selectedFilter.value) {
      case 'Recommended':
        list.sort((a, b) {
          if (a.isOfficial && !b.isOfficial) return -1;
          if (!a.isOfficial && b.isOfficial) return 1;
          return b.activityScore.compareTo(a.activityScore);
        });
        break;
      case 'Trending':
        list.sort((a, b) => b.activityScore.compareTo(a.activityScore));
        break;
      case 'Official':
        list = list.where((c) => c.isOfficial || c.type == 'Official').toList();
        break;
      case 'Newest':
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'Highest Level':
        list.sort((a, b) => b.level.compareTo(a.level));
        break;
      case 'Most Members':
        list.sort((a, b) => b.memberCount.compareTo(a.memberCount));
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Obx(() {
          if (_isSearching.value) {
            return TextField(
              controller: _searchTextController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search families by ID or Name...',
                hintStyle: TextStyle(color: Colors.white30),
                border: InputBorder.none,
              ),
              onChanged: (val) => _searchQuery.value = val,
            );
          }
          return Text(
            'Families',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          );
        }),
        actions: [
          IconButton(
            icon: Obx(() => Icon(
                  _isSearching.value ? Icons.close_rounded : Icons.search_rounded,
                  color: Colors.white,
                )),
            onPressed: () {
              if (_isSearching.value) {
                _searchTextController.clear();
                _searchQuery.value = '';
                _isSearching.value = false;
              } else {
                _isSearching.value = true;
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: () => _showFilterSheet(context),
          ),
          Obx(() {
            final joinedId = _controller.userMembership.value?.communityId;
            if (joinedId != null) return const SizedBox();
            return IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: _checkCreationAndNavigate,
            );
          }),
        ],
      ),
      body: Obx(() {
        final joinedId = _controller.userMembership.value?.communityId;
        final joinedComm = _controller.communities.firstWhereOrNull((c) => c.id == joinedId);
        final list = _getFilteredCommunities();

        return Column(
          children: [
            // 1. Quick actions row
            _buildQuickActionsRow(joinedId),
            
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _controller.syncFromSupabase(),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    // 2. Pinned My Community Card
                    if (joinedComm != null) ...[
                      _buildMyCommunityCard(joinedComm),
                      const SizedBox(height: 20),
                    ],

                    // Title Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Explore Families',
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${list.length} found',
                          style: TextStyle(color: context.caption, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 3. Main Catalog List
                    if (list.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          return _buildCommunityListItemCard(list[index], joinedId);
                        },
                      ),
                    const SizedBox(height: 80), // Padding for Floating FAB space
                  ],
                ),
              ),
            ),
          ],
        );
      }),
      floatingActionButton: Obx(() {
        final joinedId = _controller.userMembership.value?.communityId;
        if (joinedId != null) return const SizedBox();
        return FloatingActionButton.extended(
          onPressed: _checkCreationAndNavigate,
          backgroundColor: context.primaryColor,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.create_rounded, size: 18),
          label: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
        );
      }),
    );
  }

  Widget _buildQuickActionsRow(String? joinedId) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Dynamic button: My Family OR Create Family
          _buildQuickActionChip(
            label: joinedId != null ? 'My Family' : 'Create Family',
            icon: joinedId != null ? Icons.home_rounded : Icons.add_circle_outline_rounded,
            isSelected: false,
            onPressed: () {
              if (joinedId != null) {
                Get.to(() => CommunityDetailScreen(communityId: joinedId));
              } else {
                _checkCreationAndNavigate();
              }
            },
          ),
          ...['Recommended', 'Trending', 'Official', 'Newest', 'Highest Level', 'Most Members'].map((filter) {
            return Obx(() {
              final isSelected = _selectedFilter.value == filter;
              return _buildQuickActionChip(
                label: filter,
                icon: _getIconForFilter(filter),
                isSelected: isSelected,
                onPressed: () => _selectedFilter.value = filter,
              );
            });
          }),
        ],
      ),
    );
  }

  IconData _getIconForFilter(String filter) {
    switch (filter) {
      case 'Recommended': return Icons.thumb_up_alt_rounded;
      case 'Trending': return Icons.local_fire_department_rounded;
      case 'Official': return Icons.verified_user_rounded;
      case 'Newest': return Icons.new_releases_rounded;
      case 'Highest Level': return Icons.military_tech_rounded;
      case 'Most Members': return Icons.groups_rounded;
      default: return Icons.explore_rounded;
    }
  }

  Widget _buildQuickActionChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.white60),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        selected: isSelected,
        selectedColor: context.primaryColor,
        backgroundColor: const Color(0xFF1E293B),
        onSelected: (_) => onPressed(),
      ),
    );
  }

  Widget _buildMyCommunityCard(Community comm) {
    final role = _controller.getUserRole(comm);
    final completedTasks = comm.tasks.where((t) => t.isCompleted).length;
    final totalTasks = comm.tasks.length;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.indigoAccent.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner & Basic details row
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.indigoAccent, width: 2),
                ),
                child: Center(
                  child: Text(
                    comm.image ?? comm.name.substring(0, 1),
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comm.name,
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (comm.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Lv.${comm.level}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text('Role: $role', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress & Task stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('EXP progress: ${comm.xp}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
              Text('Tasks: $completedTasks/$totalTasks completed', style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: comm.xp > 0 ? (comm.xp / (comm.level * 2000)).clamp(0.0, 1.0) : 0.0,
              backgroundColor: Colors.white10,
              color: Colors.indigoAccent,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Get.to(() => CommunityDetailScreen(communityId: comm.id)),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Open Family', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityListItemCard(Community comm, String? currentJoinedId) {
    final isThisJoined = currentJoinedId == comm.id;
    final isOtherJoined = currentJoinedId != null && currentJoinedId != comm.id;

    // Cooldown logic
    final user = UserProfileCacheManager.getCachedUser(CommunityController.currentUserId);
    final nextJoin = user?.communityNextJoinTime;
    final isCooldown = nextJoin != null && nextJoin.isAfter(DateTime.now());

    String formatCooldown(DateTime dt) {
      final diff = dt.difference(DateTime.now());
      if (diff.isNegative) return 'Join';
      final hrs = diff.inHours;
      final mins = diff.inMinutes % 60;
      return '${hrs}h ${mins}m';
    }

    final isApplied = _controller.pendingApplications.any((a) => a.communityId == comm.id);

    return InkWell(
      onTap: () => _showPreviewModal(context, comm, currentJoinedId),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner header
              Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: comm.banner ?? 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809',
                    height: 90,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.white10),
                    errorWidget: (context, url, error) => Container(color: Colors.white10),
                  ),
                  Container(
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, const Color(0xFF0F172A).withOpacity(0.8)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Icons/Labels
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Row(
                      children: [
                        if (comm.isOfficial)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(6)),
                            child: const Text('OFFICIAL', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        if (comm.activityScore > 100) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(6)),
                            child: const Text('TRENDING', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IconButton(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                      onPressed: () => _showMenuOptions(context, comm),
                    ),
                  ),
                  // Avatar
                  Positioned(
                    bottom: 8,
                    left: 12,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0F172A), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          comm.image ?? comm.name.substring(0, 1),
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Description and title body
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comm.name,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (comm.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 14),
                        ],
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text('Lv.${comm.level}', style: const TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('ID: ${comm.id}', style: TextStyle(color: context.caption, fontSize: 11)),
                    const SizedBox(height: 6),
                    Text(
                      comm.description,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Country, language, members row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.language_rounded, size: 12, color: Colors.white38),
                            const SizedBox(width: 4),
                            Text('${comm.language.toUpperCase()} • ${comm.country}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.people_alt_rounded, size: 12, color: Colors.white38),
                            const SizedBox(width: 4),
                            Text(
                              '${(comm.memberCount * 0.12).round() + 1} Online / ${comm.memberCount} Members',
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Colors.white10),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Category: ${comm.category}',
                              style: TextStyle(color: context.caption, fontSize: 10),
                            ),
                            Text(
                              comm.joinMode == 'approval_required' ? 'Requires Approval' : 'Auto Join',
                              style: const TextStyle(color: Colors.green, fontSize: 9),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 32,
                          width: 120,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (isThisJoined) {
                                Get.to(() => CommunityDetailScreen(communityId: comm.id));
                              } else if (isOtherJoined) {
                                Get.snackbar('Locked', 'You must leave your current Family before joining another.', backgroundColor: Colors.amber, colorText: Colors.black);
                              } else if (isApplied) {
                                Get.snackbar('Applied', 'Your application is currently pending approval.', backgroundColor: Colors.indigo, colorText: Colors.white);
                              } else if (isCooldown) {
                                Get.snackbar('Cooldown Active', 'You left a family recently. Cooldown: ${formatCooldown(nextJoin!)}', backgroundColor: Colors.amber, colorText: Colors.black);
                              } else {
                                if (comm.joinMode == 'approval_required') {
                                  _showApplyDialog(context, comm, _controller);
                                } else {
                                  final err = await _controller.joinCommunity(comm.id);
                                  if (err != null) {
                                    Get.snackbar('Error', err, backgroundColor: Colors.redAccent, colorText: Colors.white);
                                  } else {
                                    Get.snackbar('Joined', 'Welcome to ${comm.name}!', backgroundColor: Colors.green, colorText: Colors.white);
                                    _controller.syncFromSupabase();
                                  }
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isThisJoined
                                  ? Colors.green
                                  : (isOtherJoined || isCooldown ? Colors.white10 : context.primaryColor),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              isThisJoined
                                  ? 'Open'
                                  : (isOtherJoined
                                      ? 'Locked'
                                      : (isApplied
                                          ? 'Applied'
                                          : (isCooldown ? formatCooldown(nextJoin!) : (comm.joinMode == 'approval_required' ? 'Apply' : 'Join')))),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.sentiment_dissatisfied_rounded, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'No families match your active filter.',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search criteria or categories.',
            style: TextStyle(color: context.caption, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _searchTextController.clear();
              _searchQuery.value = '';
              _selectedCategory.value = 'All';
              _selectedLanguage.value = 'All';
              _filterVerified.value = false;
              _filterOfficial.value = false;
            },
            child: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }

  void _showMenuOptions(BuildContext context, Community comm) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1B1D2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share_rounded, color: Colors.white70),
              title: const Text('Share Family link', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                Get.snackbar('Link Shared', 'Family sharing link copied to clipboard.', backgroundColor: Colors.green, colorText: Colors.white);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.white70),
              title: const Text('Copy Family ID', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                Clipboard.setData(ClipboardData(text: comm.id));
                Get.snackbar('ID Copied', 'Family ID ${comm.id} copied to clipboard.', backgroundColor: Colors.green, colorText: Colors.white);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: Colors.white70),
              title: const Text('Report Family', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                Get.snackbar('Report Filed', 'Report successfully submitted. Our moderation team will investigate.', backgroundColor: Colors.green, colorText: Colors.white);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF161925),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filters', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Categories dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory.value,
                dropdownColor: const Color(0xFF161925),
                decoration: const InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: Colors.white60)),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (val) {
                  if (val != null) _selectedCategory.value = val;
                },
              ),
              const SizedBox(height: 16),

              // Languages dropdown
              DropdownButtonFormField<String>(
                value: _selectedLanguage.value,
                dropdownColor: const Color(0xFF161925),
                decoration: const InputDecoration(labelText: 'Language', labelStyle: TextStyle(color: Colors.white60)),
                items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (val) {
                  if (val != null) _selectedLanguage.value = val;
                },
              ),
              const SizedBox(height: 20),

              // Checkbox switches
              Obx(() => CheckboxListTile(
                    title: const Text('Official Platforms only', style: TextStyle(color: Colors.white70)),
                    value: _filterOfficial.value,
                    onChanged: (val) => _filterOfficial.value = val ?? false,
                  )),
              Obx(() => CheckboxListTile(
                    title: const Text('Verified tags only', style: TextStyle(color: Colors.white70)),
                    value: _filterVerified.value,
                    onChanged: (val) => _filterVerified.value = val ?? false,
                  )),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPreviewModal(BuildContext context, Community comm, String? currentJoinedId) {
    final isThisJoined = currentJoinedId == comm.id;
    final isOtherJoined = currentJoinedId != null && currentJoinedId != comm.id;
    final isApplied = _controller.pendingApplications.any((a) => a.communityId == comm.id);

    Get.bottomSheet(
      isScrollControlled: true,
      Container(
        height: Get.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Banner & close
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: comm.banner ?? 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809',
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, const Color(0xFF0F172A).withOpacity(0.9)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Get.back(),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 20,
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 2)),
                        child: Center(child: Text(comm.image ?? comm.name.substring(0, 1), style: const TextStyle(fontSize: 32))),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(comm.name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              if (comm.isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 18),
                              ],
                            ],
                          ),
                          Text('ID: ${comm.id}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Overview stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _previewStat('Level', '${comm.level}'),
                      _previewStat('Members', '${comm.memberCount}'),
                      _previewStat('Category', comm.category),
                    ],
                  ),
                  const Divider(height: 32, color: Colors.white10),

                  // Info list
                  _previewInfoRow('Country / Region', comm.country),
                  _previewInfoRow('Language', comm.language.toUpperCase()),
                  _previewInfoRow('Min ID Level Req', 'Lv.${comm.minIdLevel}'),
                  _previewInfoRow('Admission', comm.joinMode == 'approval_required' ? 'Apply for approval' : 'Auto Join'),
                  const SizedBox(height: 16),

                  // Description
                  Text('Description', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(comm.description, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.45)),
                  const SizedBox(height: 20),

                  // Rules
                  Text('Rules', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(comm.rules, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.45)),
                  const Divider(height: 32, color: Colors.white10),
                  Text('Members', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  FutureBuilder<List<CommunityMembership>>(
                    future: _controller.getDetailedMembers(comm.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        ));
                      }
                      final members = snapshot.data ?? [];
                      if (members.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('No members found.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                        );
                      }
                      return Column(
                        children: members.map((m) {
                          return FutureBuilder<User>(
                            future: UserProfileCacheManager.fetchUserProfile(m.userId),
                            builder: (context, userSnap) {
                              final name = userSnap.data?.displayName ?? 'Member ${m.userId.substring(0, 8)}';
                              final username = userSnap.data?.username ?? '';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.white10,
                                  backgroundImage: userSnap.data?.avatar != null && userSnap.data!.avatar!.isNotEmpty
                                      ? NetworkImage(userSnap.data!.avatar!)
                                      : null,
                                  child: userSnap.data?.avatar == null || userSnap.data!.avatar!.isEmpty
                                      ? Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12))
                                      : null,
                                ),
                                title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                subtitle: username.isNotEmpty ? Text('@$username', style: const TextStyle(color: Colors.white38, fontSize: 11)) : null,
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                                  child: Text(m.role.toUpperCase(), style: const TextStyle(color: Colors.white60, fontSize: 8, fontWeight: FontWeight.bold)),
                                ),
                                onTap: () async {
                                  Get.back(); // close modal
                                  final userObj = await UserProfileCacheManager.fetchUserProfile(m.userId);
                                  Get.to(() => ProfileScreen(visitorUser: userObj));
                                },
                              );
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),

            // Bottom CTA button
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF161925),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    Get.back();
                    if (isThisJoined) {
                      Get.to(() => CommunityDetailScreen(communityId: comm.id));
                    } else if (isOtherJoined) {
                      Get.snackbar('Locked', 'You must leave your current Family first.', backgroundColor: Colors.amber, colorText: Colors.black);
                    } else {
                      if (comm.joinMode == 'approval_required') {
                        _showApplyDialog(context, comm, _controller);
                      } else {
                        final err = await _controller.joinCommunity(comm.id);
                        if (err != null) {
                          Get.snackbar('Error', err, backgroundColor: Colors.redAccent, colorText: Colors.white);
                        } else {
                          Get.snackbar('Joined', 'Welcome to ${comm.name}!', backgroundColor: Colors.green, colorText: Colors.white);
                          _controller.syncFromSupabase();
                        }
                      }
                    }
                  },
                  child: Text(
                    isThisJoined
                        ? 'Open Family'
                        : (isOtherJoined
                            ? 'Already in another Family'
                            : (isApplied
                                ? 'Application Pending'
                                : (comm.joinMode == 'approval_required' ? 'Apply to Join' : 'Join Family'))),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  Widget _previewInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
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
                ctrl.syncFromSupabase();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            child: Text('Submit', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
