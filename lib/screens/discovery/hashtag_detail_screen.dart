import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../models/discovery/unified_content_model.dart';
import '../../services/discovery/discovery_service.dart';
import '../../widgets/community/post_card.dart';

class HashtagDetailScreen extends StatefulWidget {
  final String hashtagName;

  const HashtagDetailScreen({Key? key, required this.hashtagName}) : super(key: key);

  @override
  State<HashtagDetailScreen> createState() => _HashtagDetailScreenState();
}

class _HashtagDetailScreenState extends State<HashtagDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DiscoveryService _discoveryService = Get.find<DiscoveryService>();
  final List<UnifiedContentItem> _hashtagPosts = [];
  bool _isLoading = true;

  final List<String> _tabs = ['Top', 'Recent', 'Questions', 'Reels', 'Posts'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _fetchHashtagContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchHashtagContent() async {
    setState(() => _isLoading = true);
    final cleanTag = widget.hashtagName.replaceAll('#', '');
    final posts = await _discoveryService.fetchSmartFeed(
      hashtag: cleanTag,
      limit: 30,
    );
    setState(() {
      _hashtagPosts.assignAll(posts);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cleanTag = widget.hashtagName.startsWith('#') ? widget.hashtagName : '#${widget.hashtagName}';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        title: Text(
          cleanTag,
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Column(
        children: [
          // Header Stats
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            color: AppTheme.cardBg,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Posts', '${_hashtagPosts.length}'),
                Container(height: 24, width: 1, color: Colors.white10),
                _buildStatColumn('Trending Rank', '#1 In Tech'),
                Container(height: 24, width: 1, color: Colors.white10),
                _buildStatColumn('Activity', 'High'),
              ],
            ),
          ),

          // Content List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : _hashtagPosts.isEmpty
                    ? Center(
                        child: Text(
                          'No posts found under $cleanTag',
                          style: GoogleFonts.inter(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _hashtagPosts.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PostCard(post: _hashtagPosts[index]),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}
