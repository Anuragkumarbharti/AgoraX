import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../models/discovery/unified_content_model.dart';
import '../../services/discovery/discovery_service.dart';
import '../../widgets/community/post_card.dart';
import 'hashtag_detail_screen.dart';
import 'audio_detail_screen.dart';

class TrendingScreen extends StatefulWidget {
  const TrendingScreen({Key? key}) : super(key: key);

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DiscoveryService _discoveryService = Get.put(DiscoveryService());
  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _tabs = [
    'For You',
    'Trending Now',
    'Rising Fast',
    'Reels',
    'Questions',
    'MCQ',
    'Audio',
    'Hashtags',
    'Educational',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadCurrentTabFeed();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _loadCurrentTabFeed();
  }

  void _loadCurrentTabFeed() {
    final tabName = _tabs[_tabController.index];
    String feedType = 'trending_now';

    switch (tabName) {
      case 'For You': feedType = 'for_you'; break;
      case 'Trending Now': feedType = 'trending_now'; break;
      case 'Rising Fast': feedType = 'rising_fast'; break;
      case 'Reels': feedType = 'reels'; break;
      case 'Questions': feedType = 'questions'; break;
      case 'MCQ': feedType = 'mcq'; break;
      case 'Audio': feedType = 'audio'; break;
      case 'Hashtags': feedType = 'hashtags'; break;
      case 'Educational': feedType = 'educational'; break;
    }

    _discoveryService.fetchSmartFeed(feedType: feedType);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        title: Text(
          'Creania Discovery & Trends',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              // Search Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search posts, #hashtags, audio, topics...',
                    hintStyle: GoogleFonts.inter(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                    filled: true,
                    fillColor: AppTheme.cardBg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // Category Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppTheme.primaryColor,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.white60,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
              ),
            ],
          ),
        ),
      ),
      body: Obx(() {
        if (_discoveryService.isLoadingFeed.value && _discoveryService.feedPosts.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        final posts = _discoveryService.feedPosts;
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.explore_outlined, color: Colors.white24, size: 54),
                const SizedBox(height: 12),
                Text(
                  'No trending content yet in this feed',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _loadCurrentTabFeed(),
          color: AppTheme.primaryColor,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Stack(
                  children: [
                    PostCard(
                      post: post,
                      onHashtagTap: (tag) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HashtagDetailScreen(hashtagName: tag),
                          ),
                        );
                      },
                      onAudioTap: (audioTrack) {
                        if (audioTrack != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AudioDetailScreen(audioTrack: audioTrack),
                            ),
                          );
                        }
                      },
                    ),

                    // Badge Overlay if Trending or Rising Fast
                    if (post.trendScore > 50.0)
                      Positioned(
                        top: 12,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Colors.deepOrange, Colors.orangeAccent]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.whatshot, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '🔥 Trending',
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
