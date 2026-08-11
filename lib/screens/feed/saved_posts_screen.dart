import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme.dart';
import '../../models/community/post_model.dart';
import '../../services/post/post_repository.dart';
import '../../widgets/community/post_card.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({Key? key}) : super(key: key);

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final ScrollController _scrollCtrl = ScrollController();

  List<Post> _savedPosts = [];
  bool _isLoading = true;
  bool _hasError = false;
  int _offset = 0;
  final int _limit = 15;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPosts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _offset = 0;
        _hasMore = true;
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final fetched = await PostRepository.fetchSavedPosts(
        limit: _limit,
        offset: _offset,
      );

      setState(() {
        if (refresh || _offset == 0) {
          _savedPosts = fetched;
        } else {
          _savedPosts.addAll(fetched);
        }
        _hasMore = fetched.length >= _limit;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading saved posts: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Saved Posts',
          style: GoogleFonts.outfit(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading && _savedPosts.isEmpty
          ? _buildSkeletonList()
          : _hasError
              ? _buildErrorState()
              : _savedPosts.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () => _loadSavedPosts(refresh: true),
                      color: context.primaryColor,
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(12),
                        itemCount: _savedPosts.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PostCard(post: _savedPosts[index]),
                          );
                        },
                      ),
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
          Icon(Icons.bookmark_outline_rounded, size: 64, color: context.caption.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text(
            'No Saved Posts Yet',
            style: GoogleFonts.outfit(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Posts you save will appear here.',
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
          Text('Couldn\'t load saved posts', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 14)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _loadSavedPosts(refresh: true),
            style: ElevatedButton.styleFrom(backgroundColor: context.primaryColor),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
