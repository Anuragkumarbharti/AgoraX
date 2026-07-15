import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:creania/core/theme.dart';
import '../../models/room_model.dart';
import '../../services/room_controller.dart';
import '../../services/user_profile_cache_manager.dart';
import 'create_room_screen.dart';
import 'room_profile_screen.dart';
import 'voice_room_call_screen.dart';
import '../../widgets/custom_avatar_frame.dart';
import '../../widgets/premium_name_widget.dart';
import '../../models/user_model.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({Key? key}) : super(key: key);

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> with TickerProviderStateMixin {
  final RoomController _controller = RoomController.to;
  late TabController _topTabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // State variables
  String _searchQuery = '';
  int _selectedCategoryIndex = 0; // Index for Discovery Categories
  String _myRoomsActiveRole = 'Owner'; // Selected sub-chip under "My Arenas"
  
  // Simulated State variables
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasMore = true;
  List<VoiceRoom> _paginatedRooms = [];
  Timer? _liveUpdateTimer;
  final Map<String, int> _liveCountsOffset = {}; // Real-time simulated counts

  // Filters State
  String _filterCategory = 'All';
  String _filterLanguage = 'All';
  String _filterCountry = 'All';
  String _filterRoomType = 'All';

  String _getRoomPrivilege(int level) {
    if (level >= 10) return 'Diamond Privilege';
    if (level >= 7) return 'Gold Privilege';
    if (level >= 4) return 'Silver Privilege';
    return 'Bronze Privilege';
  }

  Color _getPrivilegeColor(int level) {
    if (level >= 10) return Color(0xFF00E5FF);
    if (level >= 7) return Colors.amber;
    if (level >= 4) return Color(0xFFC0C0C0);
    return Color(0xFFCD7F32);
  }

  String _formatXpValue(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toString();
  }
  String _sortBy = 'Trending'; // 'Trending' or 'Online Users'

  // Constant Categories
  final List<Map<String, dynamic>> _discoveryCategories = [
    {'name': 'For You', 'icon': Icons.stars_rounded},
    {'name': 'Communities', 'icon': Icons.group_work_rounded},
    {'name': 'Music Lounge', 'icon': Icons.music_note_rounded},
    {'name': 'Hangout', 'icon': Icons.nightlife_rounded},
    {'name': 'Gaming Zone', 'icon': Icons.sports_esports_rounded},
    {'name': 'Study Hub', 'icon': Icons.menu_book_rounded},
    {'name': 'Coaching Hub', 'icon': Icons.psychology_rounded},
    {'name': 'Debate Arena', 'icon': Icons.forum_rounded},
    {'name': 'Broadcast', 'icon': Icons.podcasts_rounded},
    {'name': 'Recent Arenas', 'icon': Icons.history_rounded},
    {'name': 'Favorite Arenas', 'icon': Icons.bookmark_rounded},
  ];

  final List<String> _myRoomsRoles = ['Owner', 'Co-owner', 'Admin', 'Host', 'Star Member'];

  @override
  void initState() {
    super.initState();
    _topTabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
    
    // Initial pagination load
    _loadMoreData();

    // Setup periodic timer for real-time online user count updates
    _liveUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          for (var room in _controller.rooms) {
            if (room.isLive) {
              // Vary between -3 and +3
              _liveCountsOffset[room.id] = (_liveCountsOffset[room.id] ?? 0) + (Random().nextInt(7) - 3);
              // Avoid negative count
              if ((room.participantCount + (_liveCountsOffset[room.id] ?? 0)) < 1) {
                _liveCountsOffset[room.id] = 1 - room.participantCount;
              }
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _topTabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _liveUpdateTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore && _selectedCategoryIndex != 0) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1200));

    if (mounted) {
      setState(() {
        final allRooms = _controller.rooms;
        int currentLength = _paginatedRooms.length;
        int nextLength = currentLength + 4;
        if (nextLength >= allRooms.length) {
          _paginatedRooms = List.from(allRooms);
          _hasMore = false;
        } else {
          _paginatedRooms = allRooms.sublist(0, nextLength);
          _hasMore = true;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _isRefreshing = true;
    });
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _paginatedRooms = _controller.rooms.take(4).toList();
        _hasMore = true;
        _liveCountsOffset.clear();
      });
      Get.snackbar(
        'Refreshed',
        'Arenas list updated successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.primaryColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  void _joinArena(VoiceRoom room) {
    // Record visit in recents
    _controller.addRecentRoom(room.id);

    final currentUid = UserProfileCacheManager.currentUserId;
    final currentUsername = UserProfileCacheManager.currentUser?.username ?? 'Creania Student';

    Get.to(
      () => VoiceRoomCallScreen(
        roomId: room.id,
        roomName: room.name,
        userId: currentUid.isNotEmpty ? currentUid : 'uid_anurag_101',
        userName: currentUsername != 'Creania Student' ? currentUsername : 'anurag_kumar',
        isHost: room.hostId == currentUid || room.hostId == 'uid_anurag_101',
      ),
    );
  }

  // Check role of current user in a room
  String? _getUserRoleInArena(VoiceRoom room) {
    final userId = UserProfileCacheManager.currentUserId;
    if (room.hostId == userId || room.ownerName == 'Current User' || room.hostId == 'uid_anurag_101') {
      return 'Owner';
    }
    if (room.coOwnerIds.contains(userId) || room.coOwnerIds.contains('uid_anurag_101')) {
      return 'Co-owner';
    }
    if (room.adminIds.contains(userId) || room.adminIds.contains('uid_anurag_101')) {
      return 'Admin';
    }
    if (room.hostId == userId || room.hostId == 'uid_anurag_101') {
      return 'Host';
    }
    if (room.starMemberIds.contains(userId) || room.starMemberIds.contains('uid_anurag_101')) {
      return 'Star Member';
    }
    return null;
  }

  // Get Role Badge color
  Color _getRoleBadgeColor(String role) {
    switch (role) {
      case 'Owner':
        return Color(0xFFFFD700); // Gold
      case 'Co-owner':
        return Color(0xFF9D4EDD); // Purple
      case 'Admin':
        return Color(0xFF24A0ED); // Blue
      case 'Host':
        return Color(0xFF2EC4B6); // Green
      case 'Star Member':
        return Color(0xFFF72585); // Pink
      default:
        return context.caption;
    }
  }

  // Filter Arenas based on Search, Category, and Filters
  List<VoiceRoom> _getFilteredArenas({String? categoryOverride}) {
    List<VoiceRoom> baseList = List<VoiceRoom>.from(_controller.rooms);
    
    // Apply search query
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      baseList = baseList.where((room) {
        return room.name.toLowerCase().contains(query) ||
            room.id.toLowerCase().contains(query) ||
            room.category.toLowerCase().contains(query) ||
            room.tags.any((t) => t.toLowerCase().contains(query));
      }).toList();
    }

    // Apply Discovery Category selection (if not "For You", "Recent", or "Favorite")
    final selectedCategoryName = _discoveryCategories[_selectedCategoryIndex]['name'];
    if (categoryOverride != null) {
      baseList = baseList.where((r) => r.category == categoryOverride).toList();
    } else if (selectedCategoryName != 'For You' &&
        selectedCategoryName != 'Recent Arenas' &&
        selectedCategoryName != 'Favorite Arenas') {
      baseList = baseList.where((r) => r.category.toLowerCase() == selectedCategoryName.toLowerCase()).toList();
    } else if (selectedCategoryName == 'Recent Arenas') {
      baseList = baseList.where((r) => _controller.recentRoomIds.contains(r.id)).toList();
      // Maintain recent order
      baseList.sort((a, b) {
        return _controller.recentRoomIds.indexOf(a.id).compareTo(_controller.recentRoomIds.indexOf(b.id));
      });
    } else if (selectedCategoryName == 'Favorite Arenas') {
      baseList = baseList.where((r) => _controller.favoriteRoomIds.contains(r.id)).toList();
    }

    // Apply Bottom Sheet filters
    if (_filterCategory != 'All') {
      baseList = baseList.where((r) => r.category.toLowerCase() == _filterCategory.toLowerCase()).toList();
    }
    if (_filterLanguage != 'All') {
      baseList = baseList.where((r) => r.language.toLowerCase().contains(_filterLanguage.toLowerCase())).toList();
    }
    if (_filterCountry != 'All') {
      baseList = baseList.where((r) => r.country.toLowerCase() == _filterCountry.toLowerCase()).toList();
    }
    if (_filterRoomType != 'All') {
      baseList = baseList.where((r) {
        if (_filterRoomType == 'Permanent') return r.isPermanent;
        if (_filterRoomType == 'Temporary') return !r.isPermanent;
        return true;
      }).toList();
    }

    // Apply Sorting
    if (_sortBy == 'Online Users') {
      baseList.sort((a, b) {
        final aCount = a.participantCount + (_liveCountsOffset[a.id] ?? 0);
        final bCount = b.participantCount + (_liveCountsOffset[b.id] ?? 0);
        return bCount.compareTo(aCount);
      });
    } else {
      // Default: Sort by level (Trending)
      baseList.sort((a, b) => b.level.compareTo(a.level));
    }

    return baseList;
  }

  // Get rooms where user has the specified active role
  List<VoiceRoom> _getMyRoomsByRole(String role) {
    return _controller.rooms.where((room) {
      return _getUserRoleInArena(room) == role;
    }).toList();
  }

  // Open Filters Dialog / Bottom Sheet
  void _openFiltersBottomSheet() {
    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: context.secondaryBackgroundColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(color: Color(0xFF334155), width: 1.5),
              ),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.caption,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Arenas',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _filterCategory = 'All';
                            _filterLanguage = 'All';
                            _filterCountry = 'All';
                            _filterRoomType = 'All';
                            _sortBy = 'Trending';
                          });
                        },
                        child: Text(
                          'Reset All',
                          style: TextStyle(color: context.primaryColor),
                        ),
                      ),
                    ],
                  ),
                  Divider(color: Color(0xFF334155)),
                  SizedBox(height: 12),

                  // Sort Options
                  Text('Sort By', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      _buildFilterChipModal('Trending', _sortBy == 'Trending', (selected) {
                        setModalState(() => _sortBy = 'Trending');
                      }),
                      SizedBox(width: 10),
                      _buildFilterChipModal('Online Users', _sortBy == 'Online Users', (selected) {
                        setModalState(() => _sortBy = 'Online Users');
                      }),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Category Filter
                  Text('Category', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['All', 'Communities', 'Music Lounge', 'Hangout', 'Gaming Zone', 'Study Hub', 'Coaching Hub', 'Debate Arena', 'Broadcast']
                        .map((cat) => _buildFilterChipModal(cat, _filterCategory == cat, (selected) {
                              setModalState(() => _filterCategory = cat);
                            }))
                        .toList(),
                  ),
                  SizedBox(height: 20),

                  // Language Filter
                  Text('Language', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['All', 'English', 'Hindi', 'Spanish', 'Arabic']
                        .map((lang) => _buildFilterChipModal(lang, _filterLanguage == lang, (selected) {
                              setModalState(() => _filterLanguage = lang);
                            }))
                        .toList(),
                  ),
                  SizedBox(height: 20),

                  // Country Filter
                  Text('Country', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['All', 'India', 'USA', 'Global']
                        .map((country) => _buildFilterChipModal(country, _filterCountry == country, (selected) {
                              setModalState(() => _filterCountry = country);
                            }))
                        .toList(),
                  ),
                  SizedBox(height: 20),

                  // Room Type Filter
                  Text('Arena Status', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      _buildFilterChipModal('All', _filterRoomType == 'All', (selected) {
                        setModalState(() => _filterRoomType = 'All');
                      }),
                      SizedBox(width: 8),
                      _buildFilterChipModal('Permanent', _filterRoomType == 'Permanent', (selected) {
                        setModalState(() => _filterRoomType = 'Permanent');
                      }),
                      SizedBox(width: 8),
                      _buildFilterChipModal('Temporary', _filterRoomType == 'Temporary', (selected) {
                        setModalState(() => _filterRoomType = 'Temporary');
                      }),
                    ],
                  ),
                  SizedBox(height: 32),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {}); // Rebuild main UI with new filters
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Apply Filters',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildFilterChipModal(String label, bool isSelected, Function(bool) onSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: context.borderColor,
      selectedColor: context.primaryColor.withOpacity(0.2),
      checkmarkColor: context.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? context.primaryColor : context.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? context.primaryColor : Colors.white12,
          width: 1.0,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── TOP APP BAR ──
            _buildCustomAppBar(context),

            // ── TAB HEADER ──
            _buildTabSelector(),

            // ── MAIN CONTENT ──
            Expanded(
              child: TabBarView(
                controller: _topTabController,
                physics: const NeverScrollableScrollPhysics(), // Handle navigation via tabs only
                children: [
                  // Tab 1: Explore View
                  _buildExploreTabContent(),

                  // Tab 2: Live Arenas View
                  _buildLiveTabContent(),

                  // Tab 3: Arena Events View
                  _buildEventsTabContent(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CUSTOM TOP BAR WITH GRADIENTS AND GLASSMORPHISM ──
  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.borderColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Branding Logo
          Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 32,
                width: 32,
                fit: BoxFit.contain,
              ),
              SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFF72585)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  'Creania',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Wallet indicator (gold coins)
          GestureDetector(
            onTap: () => _controller.walletBalance.value += 100, // cheat coin add
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.secondaryBackgroundColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.1),
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                  SizedBox(width: 4),
                  Obx(() => Text(
                        '${_controller.walletBalance.value}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )),
                ],
              ),
            ),
          ),
          SizedBox(width: 12),
          // Create Arena button (plus)
          IconButton(
            onPressed: () => Get.to(() => const CreateRoomScreen()),
            icon: Icon(Icons.add_circle, color: Color(0xFF8B5CF6), size: 28),
            tooltip: 'Create Arena',
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // ── CUSTOM TOP TABS DESIGN ──
  Widget _buildTabSelector() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 12, 16, 8),
      height: 48,
      decoration: BoxDecoration(
        color: context.secondaryBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: TabBar(
        controller: _topTabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF6366F1).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: context.textSecondary,
        labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Explore'),
          Tab(text: 'Live'),
          Tab(text: 'Arena Events'),
        ],
      ),
    );
  }

  // ── SEARCH BAR & FILTER ROW ──
  Widget _buildSearchFilterRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          // Search Field
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: context.secondaryBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderColor),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.search, color: context.caption, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: context.textPrimary, fontSize: 14),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                        _controller.searchRooms(val);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search arenas by ID, name, tag...',
                        hintStyle: TextStyle(color: context.caption, fontSize: 13),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white54, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                        _controller.searchRooms('');
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: 10),
          // Filter Button
          GestureDetector(
            onTap: _openFiltersBottomSheet,
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: context.secondaryBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_filterCategory != 'All' || _filterLanguage != 'All' || _filterCountry != 'All' || _filterRoomType != 'All' || _sortBy != 'Trending')
                      ? context.primaryColor
                      : context.borderColor,
                ),
              ),
              child: Icon(
                Icons.tune_rounded,
                color: (_filterCategory != 'All' || _filterLanguage != 'All' || _filterCountry != 'All' || _filterRoomType != 'All' || _sortBy != 'Trending')
                    ? context.primaryColor
                    : context.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── EXPLORE TAB SCROLLABLE VIEW ──
  Widget _buildExploreTabContent() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: context.primaryColor,
      backgroundColor: context.secondaryBackgroundColor,
      child: _isRefreshing
          ? _buildSkeletonGrid()
          : SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search & Filter input
                  _buildSearchFilterRow(),

                  // Dedicated "My Arenas" section
                  _buildMyArenasSection(),

                  SizedBox(height: 16),

                  // Public Arena Discovery Category selector
                  _buildCategorySelectionRow(),

                  SizedBox(height: 16),

                  // Switch between discovery states
                  _buildDiscoveryListContent(),
                ],
              ),
            ),
    );
  }

  // ── DEDICATED "MY ARENAS" VIEW AT THE TOP ──
  Widget _buildMyArenasSection() {
    // Determine active list
    final matchingMyRooms = _getMyRoomsByRole(_myRoomsActiveRole);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.secondaryBackgroundColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header stats block
            Obx(() {
              final myUid = UserProfileCacheManager.currentUserId;
              
              // Find first room where user is Owner, Co-owner, or Admin
              final activeRoom = _controller.rooms.firstWhereOrNull((r) {
                final role = _getUserRoleInArena(r);
                return role == 'Owner' || role == 'Co-owner' || role == 'Admin';
              });

              final hasRoom = activeRoom != null;
              final roomName = hasRoom ? activeRoom.name : 'Create your Arena';
              final roomAvatar = hasRoom ? activeRoom.avatar : null;
              final roomId = hasRoom ? 'Arena ID: ${activeRoom.id}' : '';

              final roomProgress = hasRoom ? _controller.roomLevelProgresses[activeRoom.id] : null;
              final stats = hasRoom ? _controller.roomStats[activeRoom.id] : null;

              final int currentLevel = roomProgress?.currentLevel ?? activeRoom?.level ?? 1;
              final int currentXp = roomProgress?.currentXp ?? activeRoom?.xp ?? 0;
              final int xpNeeded = _controller.getXpForNextLevel(currentLevel);
              final double xpProgress = xpNeeded > 0 ? (currentXp / xpNeeded).clamp(0.0, 1.0) : 0.0;
              final int todayExtraXp = stats?.todayExtraXpPoints ?? 0;
              
              final String privilegeName = _getRoomPrivilege(currentLevel);
              final Color privilegeColor = _getPrivilegeColor(currentLevel);

              return Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF6366F1).withOpacity(0.15),
                      Color(0xFF8B5CF6).withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border(
                    bottom: BorderSide(color: context.borderColor, width: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Room avatar (shows blank circle or placeholder if no room)
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: hasRoom ? privilegeColor : context.caption,
                              width: 1.5,
                            ),
                            image: hasRoom && roomAvatar != null && roomAvatar.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(roomAvatar),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: context.borderColor,
                          ),
                          child: !hasRoom
                              ? Center(
                                  child: Icon(
                                    Icons.meeting_room_outlined,
                                    color: context.caption,
                                    size: 20,
                                  ),
                                )
                              : null,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                roomName,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              if (hasRoom) ...[
                                SizedBox(height: 2),
                                Text(
                                  roomId,
                                  style: TextStyle(
                                    color: context.caption,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Only show Privilege if hasRoom
                        if (hasRoom)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: privilegeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: privilegeColor, width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  privilegeName,
                                  style: TextStyle(color: privilegeColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(width: 2),
                                Icon(Icons.arrow_forward_ios, size: 8, color: privilegeColor),
                              ],
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 12),
                    // Progress Bar for user EXP
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'LV.$currentLevel / Creator EXP',
                          style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_formatXpValue(currentXp)}/${_formatXpValue(xpNeeded)}',
                          style: TextStyle(color: context.textSecondary, fontSize: 10),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: xpProgress,
                        minHeight: 5,
                        backgroundColor: context.borderColor,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Today\'s EXP: +$todayExtraXp',
                          style: TextStyle(color: context.caption, fontSize: 10),
                        ),
                        Text(
                          'Next Reward at LV.${currentLevel + 1}',
                          style: TextStyle(color: privilegeColor, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            // Middle: 4 Quick Actions (Room Income, Report, Gifts, Course)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMyRoomsQuickAction(Icons.account_balance_wallet_rounded, 'Income', Colors.amber),
                  _buildMyRoomsQuickAction(Icons.analytics_rounded, 'Report', Colors.blue),
                  _buildMyRoomsQuickAction(Icons.card_giftcard_rounded, 'Gifts', Colors.pink),
                  _buildMyRoomsQuickAction(Icons.school_rounded, 'Academy', Colors.teal),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: context.borderColor, height: 1),
            ),

            // Horizontal sub-tabs for Roles
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Obx(() {
                final ownerCount = _getMyRoomsByRole('Owner').length;
                final coOwnerCount = _getMyRoomsByRole('Co-owner').length;
                final adminCount = _getMyRoomsByRole('Admin').length;
                final activeCount = _getMyRoomsByRole(_myRoomsActiveRole).length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Managed Arenas',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: context.textSecondary),
                        ),
                        Text(
                          '($activeCount Active)',
                          style: GoogleFonts.poppins(fontSize: 12, color: context.caption),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildRoleChip('Owner', ownerCount),
                          SizedBox(width: 8),
                          _buildRoleChip('Co-owner', coOwnerCount),
                          SizedBox(width: 8),
                          _buildRoleChip('Admin', adminCount),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),

            Obx(() {
              final myUid = UserProfileCacheManager.currentUserId;
              final matchingRooms = _getMyRoomsByRole(_myRoomsActiveRole);

              if (matchingRooms.isNotEmpty) {
                return Column(
                  children: matchingRooms.map((room) => _buildOwnedRoomCard(room)).toList(),
                );
              } else {
                if (_myRoomsActiveRole == 'Owner') {
                  return _buildCreateRoomCard();
                } else {
                  return Container(
                    margin: EdgeInsets.fromLTRB(16, 8, 16, 16),
                    padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Center(
                      child: Text(
                        'You are not a ${_myRoomsActiveRole.toLowerCase()} in any active arenas.',
                        style: GoogleFonts.poppins(fontSize: 12, color: context.caption),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateRoomCard() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.03),
            Colors.white.withOpacity(0.005),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add_to_photos_rounded, color: context.primaryColor, size: 24),
          ),
          SizedBox(height: 12),
          Text(
            'Host Your Own Arena',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Host live voice panels, gaming lounges, study circles, and build your community.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: context.caption,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Get.to(() => const CreateRoomScreen()),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Create Arena',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnedRoomCard(VoiceRoom room) {
    return GestureDetector(
      onTap: () {
        Get.to(
          () => VoiceRoomCallScreen(
            roomId: room.id,
            roomName: room.name,
            userId: UserProfileCacheManager.currentUserId,
            userName: UserProfileCacheManager.currentUser?.username ?? 'Creania Student',
            isHost: true,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: (room.avatar != null && room.avatar!.isNotEmpty) || (room.banner != null && room.banner!.isNotEmpty)
                  ? Image.network(
                      (room.avatar != null && room.avatar!.isNotEmpty) ? room.avatar! : room.banner!,
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildCardDefaultBanner(),
                    )
                  : _buildCardDefaultBanner(),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar / DP
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: room.avatar != null && room.avatar!.isNotEmpty
                        ? NetworkImage(room.avatar!)
                        : null,
                    backgroundColor: context.primaryColor.withOpacity(0.1),
                    child: room.avatar == null || room.avatar!.isEmpty
                        ? Icon(Icons.meeting_room_rounded, color: context.primaryColor)
                        : null,
                  ),
                  SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          room.username.startsWith('@') ? room.username : '@${room.username}',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Arena ID: ${room.id}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: context.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow
                  IconButton(
                    onPressed: () {
                      Get.to(
                        () => VoiceRoomCallScreen(
                          roomId: room.id,
                          roomName: room.name,
                          userId: UserProfileCacheManager.currentUserId,
                          userName: UserProfileCacheManager.currentUser?.username ?? 'Creania Student',
                          isHost: true,
                        ),
                      );
                    },
                    icon: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardDefaultBanner() {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.primaryColor.withOpacity(0.2),
            Color(0xFF6366F1).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.image, color: context.caption, size: 28),
      ),
    );
  }

  Widget _buildMyRoomsQuickAction(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        Get.snackbar(
          label,
          'Opening simulated $label panel...',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: context.secondaryBackgroundColor,
          colorText: Colors.white,
        );
      },
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String role, int count) {
    final isSelected = _myRoomsActiveRole == role;
    return GestureDetector(
      onTap: () {
        setState(() {
          _myRoomsActiveRole = role;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber.withOpacity(0.1) : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.white.withOpacity(0.06),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check, size: 12, color: Colors.amber),
              SizedBox(width: 4),
            ],
            Text(
              '$role ($count)',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.amber : context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── EMPTY STATE WIDGETS ──
  Widget _buildMyRoomsEmptyState(String role) {
    String message = "You don't have any arenas in this category.";
    if (role == 'Owner') {
      message = "You haven't created any arenas yet.";
    } else {
      message = "You're not a $role of any arena";
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.heart_broken_rounded, size: 48, color: Colors.pink.withOpacity(0.4)),
          SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(color: context.caption, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => Get.to(() => const CreateRoomScreen()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFF72585),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            child: Text('Enter my arena', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── "MY ARENA" SPECIFIC CARD DESIGN ──
  Widget _buildMyArenaRoleCard(VoiceRoom room, String role) {
    final liveParticipants = room.participantCount + (_liveCountsOffset[room.id] ?? 0);
    
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          // Cover Image / Banner
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 60,
              height: 60,
              color: Colors.grey[800],
              child: room.avatar != null
                  ? CachedNetworkImage(
                      imageUrl: room.avatar!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Icon(Icons.radio, color: context.caption),
                    )
                  : Icon(Icons.radio, color: context.caption),
            ),
          ),
          SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.name,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 4),
                    // Role Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getRoleBadgeColor(role).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _getRoleBadgeColor(role).withOpacity(0.4), width: 0.5),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(
                          color: _getRoleBadgeColor(role),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'ID: ${room.id}',
                      style: TextStyle(color: context.caption, fontSize: 10),
                    ),
                    SizedBox(width: 8),
                    // Level badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'LV.${room.level}',
                        style: TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                // Stats row
                Row(
                  children: [
                    // Member count (simulated online)
                    Icon(Icons.people_outline, color: room.isLive ? Color(0xFF10B981) : context.caption, size: 12),
                    SizedBox(width: 3),
                    Text(
                      room.isLive ? '$liveParticipants Online' : 'Offline',
                      style: TextStyle(
                        color: room.isLive ? Color(0xFF10B981) : context.caption,
                        fontSize: 10,
                        fontWeight: room.isLive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    SizedBox(width: 12),
                    // Last active time
                    Icon(Icons.access_time, color: context.caption, size: 12),
                    SizedBox(width: 3),
                    Text(
                      'Active 2m ago',
                      style: TextStyle(color: context.caption, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          // Enter Button
          ElevatedButton(
            onPressed: () => _joinArena(room),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getRoleBadgeColor(role).withOpacity(0.2),
              foregroundColor: _getRoleBadgeColor(role),
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _getRoleBadgeColor(role).withOpacity(0.4), width: 1),
              ),
            ),
            child: Text(
              'Enter',
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── PUBLIC ARENA DISCOVERY: CATEGORY CHIPS ROW ──
  Widget _buildCategorySelectionRow() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: _discoveryCategories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          final category = _discoveryCategories[index];
          return Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              avatar: Icon(
                category['icon'] as IconData,
                color: isSelected ? Colors.white : context.caption,
                size: 14,
              ),
              label: Text(category['name'] as String),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategoryIndex = index;
                  });
                }
              },
              backgroundColor: context.secondaryBackgroundColor,
              selectedColor: context.primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : context.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? context.primaryColor : context.borderColor,
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            ),
          );
        },
      ),
    );
  }

  // ── SWITCH TO CHOSEN DISCOVERY CATEGORY VIEW ──
  Widget _buildDiscoveryListContent() {
    final activeCategoryName = _discoveryCategories[_selectedCategoryIndex]['name'];
    final baseFiltered = _getFilteredArenas();

    if (activeCategoryName == 'For You') {
      return _buildForYouDiscoveryLayout();
    }

    if (activeCategoryName == 'Recent Arenas') {
      if (baseFiltered.isEmpty) {
        return _buildDiscoveryEmptyState('Recent');
      }
      return _buildGeneralCategoryGrid(baseFiltered);
    }

    if (activeCategoryName == 'Favorite Arenas') {
      if (baseFiltered.isEmpty) {
        return _buildDiscoveryEmptyState('Favorite');
      }
      return _buildGeneralCategoryGrid(baseFiltered);
    }

    // General category listings (e.g. Communities, Gaming, etc.)
    if (baseFiltered.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'No arenas active in this category',
            style: TextStyle(color: context.caption),
          ),
        ),
      );
    }

    return _buildGeneralCategoryGrid(baseFiltered);
  }

  // ── SKELETON PLACEHOLDER ──
  Widget _buildSkeletonGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(16),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: context.secondaryBackgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 10),
              // Name bar
              Container(width: 100, height: 12, color: context.borderColor),
              SizedBox(height: 6),
              // Subtitle bar
              Container(width: 60, height: 10, color: context.borderColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiscoveryEmptyState(String type) {
    String message = "No recently visited arenas.";
    if (type == 'Favorite') {
      message = "No favorite arenas.";
    } else if (type == 'Recent') {
      message = "No recently visited arenas.";
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            type == 'Favorite' ? Icons.bookmark_border_rounded : Icons.history_toggle_off_rounded,
            size: 64,
            color: context.caption.withOpacity(0.5),
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 15, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── "FOR YOU" MULTI-LANE LAYOUT ──
  Widget _buildForYouDiscoveryLayout() {
    return Column(
      children: [
        _buildTrendingLane('🔥 Trending Now', _getFilteredArenas().take(4).toList()),
        _buildTrendingLane('🚀 Rising Arenas', _getFilteredArenas().where((r) => r.isLive).toList()),
        _buildTrendingLane('👑 Elite Arenas', _getFilteredArenas().where((r) => r.level >= 3).toList()),
        _buildTrendingLane('🎁 Top Gifted', _getFilteredArenas().where((r) => r.totalGiftsReceived > 5000).toList()),
        _buildTrendingLane('🎤 Most Active', _getFilteredArenas().where((r) => r.participantCount > 40).toList()),
        _buildTrendingLane('🎮 Gaming Trends', _getFilteredArenas(categoryOverride: 'Gaming Zone')),
        _buildTrendingLane('🎓 Study Trends', _getFilteredArenas(categoryOverride: 'Study Hub')),
        _buildTrendingLane('🆕 New Arenas', _getFilteredArenas().where((r) => !r.isPermanent).toList()),
        SizedBox(height: 40),
      ],
    );
  }

  Widget _buildTrendingLane(String title, List<VoiceRoom> laneRooms) {
    if (laneRooms.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lane Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {
                  Get.snackbar(
                    title,
                    'Viewing all items in $title...',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: context.secondaryBackgroundColor,
                    colorText: Colors.white,
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: context.primaryColor),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_ios, size: 10, color: context.primaryColor),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Horizontal List
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: laneRooms.length,
            itemBuilder: (context, index) {
              return _buildPremiumArenaCard(laneRooms[index]);
            },
          ),
        ),
        SizedBox(height: 12),
      ],
    );
  }

  // ── CORE GENERAL GRID DISPLAY ──
  Widget _buildGeneralCategoryGrid(List<VoiceRoom> gridRooms) {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: gridRooms.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemBuilder: (context, index) {
            return _buildPremiumArenaCard(gridRooms[index], isGrid: true);
          },
        ),
        if (_isLoading)
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(color: context.primaryColor),
            ),
          ),
        if (!_hasMore && gridRooms.length > 4)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No more arenas found.',
                style: TextStyle(color: context.caption, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  // ── HIGH-FIDELITY GLASSMORPHIC CARD DESIGN ──
  Widget _buildPremiumArenaCard(VoiceRoom room, {bool isGrid = false}) {
    final liveParticipants = room.participantCount + (_liveCountsOffset[room.id] ?? 0);
    final isFavorite = _controller.favoriteRoomIds.contains(room.id);

    Widget cardContent = Container(
      width: isGrid ? double.infinity : 160,
      margin: isGrid ? EdgeInsets.zero : EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: context.secondaryBackgroundColor.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: room.isPermanent ? Colors.amber.withOpacity(0.3) : Colors.white.withOpacity(0.06),
          width: room.isPermanent ? 1.2 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cover Image
            (room.avatar != null && room.avatar!.isNotEmpty) || (room.banner != null && room.banner!.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: (room.avatar != null && room.avatar!.isNotEmpty) ? room.avatar! : room.banner!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: context.secondaryBackgroundColor,
                      child: Center(child: CircularProgressIndicator(color: context.primaryColor, strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(Icons.radio, color: Colors.white.withOpacity(0.15), size: 36),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(Icons.radio, color: Colors.white.withOpacity(0.15), size: 36),
                  ),

            // Gradient Overlay for text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.85),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // Top Badges Overlay (Category tag & Level & Live status)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Category Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.primaryColor.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      room.category,
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Level Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'LV.${room.level}',
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        fontWeight: FontWeight.w900, // Fixed: FontWeight.black -> FontWeight.w900
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Heart / Bookmark floating button (top right overlay, just below Level)
            Positioned(
              top: 36,
              right: 8,
              child: GestureDetector(
                onTap: () => _controller.toggleFavoriteRoom(room.id),
                child: Container(
                  padding: EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5), // Fixed: Colors.black50 -> Colors.black.withOpacity(0.5)
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                    color: isFavorite ? Colors.redAccent : context.textSecondary,
                    size: 14,
                  ),
                ),
              ),
            ),

            // Live indicator (if live)
            if (room.isLive)
              Positioned(
                top: 36,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: GoogleFonts.poppins(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

            // Lock Indicator if private
            if (room.entryPermission != 'everyone')
              Positioned(
                bottom: 80,
                right: 8,
                child: Icon(
                  Icons.lock_rounded,
                  color: context.textSecondary,
                  size: 14,
                ),
              ),

            // Info Details Overlay
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tags (horizontal list or wraps)
                  if (room.tags.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: 4.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: room.tags.map((tag) => Container(
                            margin: EdgeInsets.only(right: 4),
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(color: context.textSecondary, fontSize: 7),
                            ),
                          )).toList(),
                        ),
                      ),
                    ),

                  // Room Name
                  Text(
                    room.name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6),

                  // Host Details and Participant Counts
                  Obx(() {
                    final u = UserProfileCacheManager.rxCache[room.hostId] ?? UserProfileCacheManager.getCachedUser(room.hostId);
                    final String uName = u?.username ?? room.ownerName ?? 'Host';
                    final String uAvatar = u?.avatar ?? '';
                    final int uLevel = u?.level ?? 1;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Host Avatar & Frame
                            CustomAvatarFrame(
                              userId: room.hostId,
                              username: uName,
                              size: 20,
                              child: CircleAvatar(
                                radius: 10,
                                backgroundImage: uAvatar.isNotEmpty ? CachedNetworkImageProvider(uAvatar) : null,
                                backgroundColor: context.primaryColor.withOpacity(0.1),
                                child: uAvatar.isEmpty ? Icon(Icons.person, size: 10, color: context.textSecondary) : null,
                              ),
                            ),
                            SizedBox(width: 6),
                            // Owner Name
                            Expanded(
                              child: PremiumNameWidget(
                                name: uName,
                                userId: room.hostId,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'LV.$uLevel',
                                    style: TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Owner',
                                    style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              room.isLive ? '$liveParticipants live' : 'Offline',
                              style: TextStyle(
                                color: room.isLive ? Color(0xFF10B981) : Colors.white54,
                                fontSize: 8.5,
                                fontWeight: room.isLive ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Inkwell wrapper for navigation + tap effect
    return GestureDetector(
      onTap: () => _joinArena(room),
      child: cardContent,
    );
  }

  // ── LIVE TAB CONTENT ──
  Widget _buildLiveTabContent() {
    final liveArenas = _getFilteredArenas().where((r) => r.isLive).toList();

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: context.primaryColor,
      backgroundColor: context.secondaryBackgroundColor,
      child: liveArenas.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.radio_button_off, size: 64, color: context.caption.withOpacity(0.5)),
                  SizedBox(height: 16),
                  Text(
                    'No live arenas active right now.',
                    style: TextStyle(color: context.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: EdgeInsets.all(16),
              itemCount: liveArenas.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemBuilder: (context, index) {
                return _buildPremiumArenaCard(liveArenas[index], isGrid: true);
              },
            ),
    );
  }

  // ── EVENTS TAB CONTENT ──
  Widget _buildEventsTabContent() {
    final scheduledArenas = _getFilteredArenas().where((r) => !r.isLive).toList();

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: context.primaryColor,
      backgroundColor: context.secondaryBackgroundColor,
      child: scheduledArenas.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note_rounded, size: 64, color: context.caption.withOpacity(0.5)),
                  SizedBox(height: 16),
                  Text(
                    'No scheduled events currently.',
                    style: TextStyle(color: context.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: scheduledArenas.length,
              itemBuilder: (context, index) {
                final room = scheduledArenas[index];
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: context.secondaryBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.borderColor),
                  ),
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Large Event Icon/Cover
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 70,
                          height: 70,
                          color: context.primaryColor.withOpacity(0.1),
                          child: Icon(Icons.rocket_launch_rounded, color: context.primaryColor, size: 36),
                        ),
                      ),
                      SizedBox(width: 14),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: context.primaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                room.category.toUpperCase(),
                                style: TextStyle(color: context.primaryColor, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              room.name,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Host: ${room.ownerName}',
                              style: TextStyle(color: context.caption, fontSize: 11),
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.calendar_month, color: Colors.amber, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Tomorrow, 7:00 PM',
                                  style: GoogleFonts.poppins(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      // Action indicator
                      OutlinedButton(
                        onPressed: () {
                          Get.snackbar(
                            'Registered',
                            'You will be notified when this event starts!',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.green.withOpacity(0.9),
                            colorText: Colors.white,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: context.primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text('RSVP', style: TextStyle(color: context.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
