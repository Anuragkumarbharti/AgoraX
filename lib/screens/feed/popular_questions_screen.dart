import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme.dart';
import '../../models/community/post_model.dart';
import '../../services/post/post_repository.dart';
import '../../widgets/community/feed_question_widget.dart';
import '../../widgets/community/post_card.dart';

class PopularQuestionsScreen extends StatefulWidget {
  const PopularQuestionsScreen({Key? key}) : super(key: key);

  @override
  State<PopularQuestionsScreen> createState() => _PopularQuestionsScreenState();
}

class _PopularQuestionsScreenState extends State<PopularQuestionsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounceTimer;

  List<Post> _questions = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _selectedCategory = 'All';
  String _sortBy = 'Most Answered';
  int _offset = 0;
  final int _limit = 15;
  bool _hasMore = true;

  final List<String> _categories = ['All', 'Tech', 'Science', 'Exam Prep', 'General', 'Career'];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _offset = 0;
        _hasMore = true;
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final fetched = await PostRepository.fetchPopularQuestions(
        category: _selectedCategory == 'All' ? null : _selectedCategory,
        sortBy: _sortBy,
        searchQuery: _searchCtrl.text.trim(),
        limit: _limit,
        offset: _offset,
      );

      setState(() {
        if (refresh || _offset == 0) {
          _questions = fetched;
        } else {
          _questions.addAll(fetched);
        }
        _hasMore = fetched.length >= _limit;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading popular questions: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _loadQuestions(refresh: true);
    });
  }

  void _showSortModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.dialogBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sort Questions', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...['Most Answered', 'Most Viewed', 'Newest', 'Trending'].map((opt) {
              final isSelected = opt == _sortBy;
              return ListTile(
                title: Text(opt, style: GoogleFonts.poppins(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                trailing: isSelected ? Icon(Icons.check_rounded, color: context.primaryColor) : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _sortBy = opt);
                  _loadQuestions(refresh: true);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
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
          'Popular Questions',
          style: GoogleFonts.outfit(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.sort_rounded, color: context.primaryColor),
            onPressed: _showSortModal,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search questions...',
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

          // Category Chips
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, idx) {
                final cat = _categories[idx];
                final isSelected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedCategory = cat);
                      _loadQuestions(refresh: true);
                    },
                    label: Text(
                      cat,
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
              },
            ),
          ),
          const SizedBox(height: 8),

          // Questions Feed Body
          Expanded(
            child: _isLoading
                ? _buildSkeletonList()
                : _hasError
                    ? _buildErrorState()
                    : _questions.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: () => _loadQuestions(refresh: true),
                            color: context.primaryColor,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _questions.length,
                              itemBuilder: (context, index) {
                                final questionPost = _questions[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: PostCard(post: questionPost),
                                );
                              },
                            ),
                          ),
          ),
        ],
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
            height: 120,
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
          Icon(Icons.help_outline_rounded, size: 64, color: context.caption.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text(
            'No Popular Questions Yet',
            style: GoogleFonts.outfit(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'No popular questions available for this filter right now.',
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
          Text('Couldn\'t load questions', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 14)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _loadQuestions(refresh: true),
            style: ElevatedButton.styleFrom(backgroundColor: context.primaryColor),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
