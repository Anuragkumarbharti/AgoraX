import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../models/room_model.dart';
import '../../services/room_controller.dart';
import 'create_room_screen.dart';
import 'room_profile_screen.dart';
import 'voice_room_call_screen.dart';

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
        backgroundColor: AppTheme.primaryColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  void _joinArena(VoiceRoom room) {
    // Record visit in recents
    _controller.addRecentRoom(room.id);

    Get.to(
      () => VoiceRoomCallScreen(
        roomId: room.id,
        roomName: room.name,
        userId: 'uid_anurag_101', // Fixed unique User ID
        userName: 'anurag_kumar', // Copyable username
        isHost: room.hostId == 'uid_anurag_101',
      ),
    );
  }

  // Check role of current user in a room
  String? _getUserRoleInArena(VoiceRoom room) {
    const userId = 'uid_anurag_101';
    if (room.ownerName == 'Anurag Kumar Bharti' || room.ownerName == 'Current User' || room.hostId == userId) {
      return 'Owner';
    }
    if (room.coOwnerIds.contains(userId)) {
      return 'Co-owner';
    }
    if (room.adminIds.contains(userId)) {
      return 'Admin';
    }
    if (room.hostId == userId) {
      return 'Host';
    }
    if (room.starMemberIds.contains(userId)) {
      return 'Star Member';
    }
    return null;
  }

  // Get Role Badge color
  Color _getRoleBadgeColor(String role) {
    switch (role) {
      case 'Owner':
        return const Color(0xFFFFD700); // Gold
      case 'Co-owner':
        return const Color(0xFF9D4EDD); // Purple
      case 'Admin':
        return const Color(0xFF24A0ED); // Blue
      case 'Host':
        return const Color(0xFF2EC4B6); // Green
      case 'Star Member':
        return const Color(0xFFF72585); // Pink
      default:
        return AppTheme.textTertiary;
    }
  }

  // Filter Arenas based on Search, Category, and Filters
  List<VoiceRoom> _getFilteredArenas({String? categoryOverride}) {
    List<VoiceRoom> baseList = _controller.rooms;
    
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
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(color: Color(0xFF334155), width: 1.5),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                        child: const Text(
                          'Reset All',
                          style: TextStyle(color: AppTheme.primaryColor),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF334155)),
                  const SizedBox(height: 12),

                  // Sort Options
                  Text('Sort By', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildFilterChipModal('Trending', _sortBy == 'Trending', (selected) {
                        setModalState(() => _sortBy = 'Trending');
                      }),
                      const SizedBox(width: 10),
                      _buildFilterChipModal('Online Users', _sortBy == 'Online Users', (selected) {
                        setModalState(() => _sortBy = 'Online Users');
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Category Filter
                  Text('Category', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['All', 'Communities', 'Music Lounge', 'Hangout', 'Gaming Zone', 'Study Hub', 'Coaching Hub', 'Debate Arena', 'Broadcast']
                        .map((cat) => _buildFilterChipModal(cat, _filterCategory == cat, (selected) {
                              setModalState(() => _filterCategory = cat);
                            }))
                        .toList(),
                  ),
                  const SizedBox(height: 20),

                  // Language Filter
                  Text('Language', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['All', 'English', 'Hindi', 'Spanish', 'Arabic']
                        .map((lang) => _buildFilterChipModal(lang, _filterLanguage == lang, (selected) {
                              setModalState(() => _filterLanguage = lang);
                            }))
                        .toList(),
                  ),
                  const SizedBox(height: 20),

                  // Country Filter
                  Text('Country', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['All', 'India', 'USA', 'Global']
                        .map((country) => _buildFilterChipModal(country, _filterCountry == country, (selected) {
                              setModalState(() => _filterCountry = country);
                            }))
                        .toList(),
                  ),
                  const SizedBox(height: 20),

                  // Room Type Filter
                  Text('Arena Status', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildFilterChipModal('All', _filterRoomType == 'All', (selected) {
                        setModalState(() => _filterRoomType = 'All');
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChipModal('Permanent', _filterRoomType == 'Permanent', (selected) {
                        setModalState(() => _filterRoomType = 'Permanent');
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChipModal('Temporary', _filterRoomType == 'Temporary', (selected) {
                        setModalState(() => _filterRoomType = 'Temporary');
                      }),
                    ],
                  ),
                  const SizedBox(height: 32),

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
                        backgroundColor: AppTheme.primaryColor,
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
      backgroundColor: Colors.white.withOpacity(0.04),
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.white12,
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white10, width: 0.5),
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
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
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
                  const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Obx(() => Text(
                        '${_controller.walletBalance.value}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Create Arena button (plus)
          IconButton(
            onPressed: () => Get.to(() => const CreateRoomScreen()),
            icon: const Icon(Icons.add_circle, color: Color(0xFF8B5CF6), size: 28),
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
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: TabBar(
        controller: _topTabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          // Search Field
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppTheme.textTertiary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search arenas by ID, name, tag...',
                        hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
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
                      icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Filter Button
          GestureDetector(
            onTap: _openFiltersBottomSheet,
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_filterCategory != 'All' || _filterLanguage != 'All' || _filterCountry != 'All' || _filterRoomType != 'All' || _sortBy != 'Trending')
                      ? AppTheme.primaryColor
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Icon(
                Icons.tune_rounded,
                color: (_filterCategory != 'All' || _filterLanguage != 'All' || _filterCountry != 'All' || _filterRoomType != 'All' || _sortBy != 'Trending')
                    ? AppTheme.primaryColor
                    : Colors.white70,
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
      color: AppTheme.primaryColor,
      backgroundColor: const Color(0xFF1E293B),
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

                  const SizedBox(height: 16),

                  // Public Arena Discovery Category selector
                  _buildCategorySelectionRow(),

                  const SizedBox(height: 16),

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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
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
            // Header stats block (Like first reference image: User EXP / Level status)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.15),
                    const Color(0xFF8B5CF6).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: const Border(
                  bottom: BorderSide(color: Colors.white10, width: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Simulated user avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 1.5),
                          image: const DecorationImage(
                            image: CachedNetworkImageProvider('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Anurag Kumar Bharti',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, color: Colors.blueAccent, size: 14),
                              ],
                            ),
                            const Text(
                              'ID: 2095195',
                              style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Gold Privilege',
                              style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_forward_ios, size: 8, color: Colors.amber),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress Bar for user EXP
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LV.5 / Creator EXP',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        '158k/240k',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      value: 0.65,
                      minHeight: 5,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Today\'s EXP: +1,240',
                        style: TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                      ),
                      Text(
                        'Next Reward at LV.6',
                        style: TextStyle(color: Colors.amber, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Middle: 4 Quick Actions (Room Income, Report, Gifts, Course)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMyRoomsQuickAction(Icons.account_balance_wallet_rounded, 'Income', Colors.amber),
                  _buildMyRoomsQuickAction(Icons.analytics_rounded, 'Report', Colors.blue),
                  _buildMyRoomsQuickAction(Icons.card_giftcard_rounded, 'Gifts', Colors.pink),
                  _buildMyRoomsQuickAction(Icons.school_rounded, 'Academy', Colors.teal), // Fixed: Colors.emerald -> Colors.teal
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Colors.white10, height: 1),
            ),

            // Horizontal sub-tabs for Roles
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Managed Arenas',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  Text(
                    '(${matchingMyRooms.length} Active)',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                  ),
                ],
              ),
            ),

            // Horizontal Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: _myRoomsRoles.map((role) {
                  final isSelected = _myRoomsActiveRole == role;
                  final roleCount = _getMyRoomsByRole(role).length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text('$role ($roleCount)'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _myRoomsActiveRole = role;
                          });
                        }
                      },
                      backgroundColor: Colors.white.withOpacity(0.03),
                      selectedColor: _getRoleBadgeColor(role).withOpacity(0.15),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? _getRoleBadgeColor(role) : Colors.white60,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? _getRoleBadgeColor(role).withOpacity(0.6) : Colors.white12,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Cards section
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: matchingMyRooms.isEmpty
                  ? _buildMyRoomsEmptyState(_myRoomsActiveRole)
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: matchingMyRooms.length,
                      itemBuilder: (context, index) {
                        return _buildMyArenaRoleCard(matchingMyRooms[index], _myRoomsActiveRole);
                      },
                    ),
            ),
          ],
        ),
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
          backgroundColor: AppTheme.bgLight,
          colorText: Colors.white,
        );
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.heart_broken_rounded, size: 48, color: Colors.pink.withOpacity(0.4)),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => Get.to(() => const CreateRoomScreen()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF72585),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            child: const Text('Enter my arena', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── "MY ARENA" SPECIFIC CARD DESIGN ──
  Widget _buildMyArenaRoleCard(VoiceRoom room, String role) {
    final liveParticipants = room.participantCount + (_liveCountsOffset[room.id] ?? 0);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.all(12),
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
                      errorWidget: (context, url, error) => const Icon(Icons.radio, color: Colors.white38),
                    )
                  : const Icon(Icons.radio, color: Colors.white38),
            ),
          ),
          const SizedBox(width: 12),
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
                    const SizedBox(width: 4),
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'ID: ${room.id}',
                      style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                    ),
                    const SizedBox(width: 8),
                    // Level badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'LV.${room.level}',
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Stats row
                Row(
                  children: [
                    // Member count (simulated online)
                    Icon(Icons.people_outline, color: room.isLive ? const Color(0xFF10B981) : AppTheme.textTertiary, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      room.isLive ? '$liveParticipants Online' : 'Offline',
                      style: TextStyle(
                        color: room.isLive ? const Color(0xFF10B981) : AppTheme.textTertiary,
                        fontSize: 10,
                        fontWeight: room.isLive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Last active time
                    const Icon(Icons.access_time, color: AppTheme.textTertiary, size: 12),
                    const SizedBox(width: 3),
                    const Text(
                      'Active 2m ago',
                      style: TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Enter Button
          ElevatedButton(
            onPressed: () => _joinArena(room),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getRoleBadgeColor(role).withOpacity(0.2),
              foregroundColor: _getRoleBadgeColor(role),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _discoveryCategories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          final category = _discoveryCategories[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              avatar: Icon(
                category['icon'] as IconData,
                color: isSelected ? Colors.white : AppTheme.textTertiary,
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
              backgroundColor: const Color(0xFF1E293B),
              selectedColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryColor : Colors.white.withOpacity(0.08),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'No arenas active in this category',
            style: TextStyle(color: AppTheme.textTertiary),
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
      padding: const EdgeInsets.all(16),
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
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Name bar
              Container(width: 100, height: 12, color: Colors.white10),
              const SizedBox(height: 6),
              // Subtitle bar
              Container(width: 60, height: 10, color: Colors.white10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiscoveryEmptyState(String type) {
    String message = "No recently visited arenas.";
    if (type == 'Favorite') {
      message = "No favorite rooms."; // Exact string from reqs
    } else if (type == 'Recent') {
      message = "No recently visited rooms."; // Exact string from reqs
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            type == 'Favorite' ? Icons.bookmark_border_rounded : Icons.history_toggle_off_rounded,
            size: 64,
            color: AppTheme.textTertiary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w500),
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
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildTrendingLane(String title, List<VoiceRoom> laneRooms) {
    if (laneRooms.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lane Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    backgroundColor: AppTheme.bgLight,
                    colorText: Colors.white,
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.primaryColor),
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: laneRooms.length,
            itemBuilder: (context, index) {
              return _buildPremiumArenaCard(laneRooms[index]);
            },
          ),
        ),
        const SizedBox(height: 12),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          ),
        if (!_hasMore && gridRooms.length > 4)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No more arenas found.',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
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
      margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.55),
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
            room.avatar != null
                ? CachedNetworkImage(
                    imageUrl: room.avatar!,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      decoration: const BoxDecoration(
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
                    decoration: const BoxDecoration(
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.85),
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
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5), // Fixed: Colors.black50 -> Colors.black.withOpacity(0.5)
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                    color: isFavorite ? Colors.redAccent : Colors.white70,
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
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
              const Positioned(
                bottom: 80,
                right: 8,
                child: Icon(
                  Icons.lock_rounded,
                  color: Colors.white70,
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
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: room.tags.map((tag) => Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '#$tag',
                              style: const TextStyle(color: Colors.white70, fontSize: 7),
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
                        const Shadow(
                          color: Colors.black87,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Host Details and Participant Counts
                  Row(
                    children: [
                      // Host Avatar
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white54, width: 0.8),
                          image: const DecorationImage(
                            image: CachedNetworkImageProvider('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Online participants
                      Expanded(
                        child: Text(
                          room.isLive ? '$liveParticipants online' : 'Offline',
                          style: TextStyle(
                            color: room.isLive ? const Color(0xFF10B981) : Colors.white54,
                            fontSize: 9,
                            fontWeight: room.isLive ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
      color: AppTheme.primaryColor,
      backgroundColor: const Color(0xFF1E293B),
      child: liveArenas.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.radio_button_off, size: 64, color: AppTheme.textTertiary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'No live arenas active right now.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
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
      color: AppTheme.primaryColor,
      backgroundColor: const Color(0xFF1E293B),
      child: scheduledArenas.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note_rounded, size: 64, color: AppTheme.textTertiary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'No scheduled events currently.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: scheduledArenas.length,
              itemBuilder: (context, index) {
                final room = scheduledArenas[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Large Event Icon/Cover
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 70,
                          height: 70,
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          child: const Icon(Icons.rocket_launch_rounded, color: AppTheme.primaryColor, size: 36),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                room.category.toUpperCase(),
                                style: const TextStyle(color: AppTheme.primaryColor, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              room.name,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Host: ${room.ownerName}',
                              style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.calendar_month, color: Colors.amber, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'Tomorrow, 7:00 PM',
                                  style: GoogleFonts.poppins(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
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
                          side: const BorderSide(color: AppTheme.primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: const Text('RSVP', style: TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
