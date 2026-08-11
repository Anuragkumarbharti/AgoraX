import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme.dart';
import '../../models/community/post_model.dart';
import '../../models/community/post_type.dart';
import '../../services/post/post_repository.dart';
import '../../services/post/post_event_service.dart';
import '../../widgets/community/post_card.dart';

class RecentPostsScreen extends StatefulWidget {
  final String? initialPostType;

  const RecentPostsScreen({Key? key, this.initialPostType}) : super(key: key);

  @override
  State<RecentPostsScreen> createState() => _RecentPostsScreenState();
}

class _RecentPostsScreenState extends State<RecentPostsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounceTimer;

  List<Post> _posts = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _selectedTypeFilter = 'all';
  String _sortBy = 'Newest';

  int _offset = 0;
  final int _limit = 15;
  bool _hasMore = true;
  StreamSubscription<Post>? _postSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.initialPostType != null) {
      _selectedTypeFilter = widget.initialPostType!;
    }
    _loadPosts();
    _postSubscription = PostEventService.to.onPostCreated.listen((newPost) {
      if (mounted) {
        setState(() {
          _posts.insert(0, newPost);
        });
      }
    });

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
        if (!_isLoading && _hasMore) {
          _loadMorePosts();
        }
      }
    });
  }

  @override
  void dispose() {
    _postSubscription?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _offset = 0;
        _hasMore = true;
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final fetched = await PostRepository.fetchRecentPostsFiltered(
        postTypeFilter: _selectedTypeFilter,
        searchQuery: _searchCtrl.text.trim(),
        sortBy: _sortBy,
        limit: _limit,
        offset: _offset,
      );

      setState(() {
        if (refresh || _offset == 0) {
          _posts = fetched;
        } else {
          _posts.addAll(fetched);
        }
        _hasMore = fetched.length >= _limit;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading recent posts: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    _offset += _limit;
    await _loadPosts();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _loadPosts(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Recent Posts Feed',
          style: GoogleFonts.outfit(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search posts...',
                hintStyle: GoogleFonts.poppins(color: context.caption, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: context.caption),
                filled: true,
                fillColor: context.secondaryBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Post Type Filter Chips Bar
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                _buildFilterChip('all', '🌟 All'),
                ...PostType.values.map((t) => _buildFilterChip(t.value, '${t.emoji} ${t.displayName}')).toList(),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Posts Feed
          Expanded(
            child: _isLoading && _posts.isEmpty
                ? _buildSkeletonList()
                : _hasError
                    ? _buildErrorState()
                    : _posts.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: () => _loadPosts(refresh: true),
                            color: context.primaryColor,
                            child: ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.all(12),
                              itemCount: _posts.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _posts.length) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(color: context.primaryColor),
                                    ),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: PostCard(post: _posts[index]),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedTypeFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: isSelected,
        onSelected: (_) {
          setState(() => _selectedTypeFilter = value);
          _loadPosts(refresh: true);
        },
        label: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : context.textPrimary,
          ),
        ),
        selectedColor: context.primaryColor,
        backgroundColor: context.secondaryBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Shimmer.fromColors(
          baseColor: const Color(0xFF1D1F29),
          highlightColor: const Color(0xFF2C2F3E),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dynamic_feed_rounded, size: 64, color: context.caption.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text(
            'No Recent Posts',
            style: GoogleFonts.outfit(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'New posts will appear here.',
            style: GoogleFonts.poppins(color: context.caption, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: context.errorColor),
          const SizedBox(height: 12),
          Text('Couldn\'t load posts', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 14)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _loadPosts(refresh: true),
            style: ElevatedButton.styleFrom(backgroundColor: context.primaryColor),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
