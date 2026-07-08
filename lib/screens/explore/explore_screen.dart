import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../models/question_model.dart';
import '../../models/community_model.dart';
import '../profile/user_profile_screen.dart';
import '../../widgets/post_attachments_widget.dart';
import '../../services/study_vault_controller.dart';
import '../study_vault/study_vault_home_screen.dart';
import '../study_vault/book_details_screen.dart';


class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _searchController;
  late TabController _tabController;
  final List<String> _tabs = [
    'All',
    'Posts',
    'Questions',
    'Communities',
    'Users',
    'Study Vault'
  ];

  // ── Mock data ──
  final List<Post> _posts = List.generate(
      10,
      (i) => Post(
            id: 'p$i',
            userId: 'u$i',
            communityId: 'comm$i',
            content: [
              '🔥 Flutter 3.24 dropped! The impeller engine improvements are massive. Our app is now butter-smooth on low-end devices.',
              '💡 AI is changing how we write code. Here\'s how I use GitHub Copilot with a custom prompt that 10x\'s my productivity...',
              'Just cracked Google\'s LC Hard in my morning session 🎯 Solved "Alien Dictionary" using topological sort. Drop a ❤️ if you want the full breakdown.',
              'Hot take: CSS Grid is underrated. Most devs jump to Flexbox for everything but Grid solves 2D layouts so elegantly.',
              'Started my open source journey 6 months ago. Today I hit 500 ⭐ on my first package! 🥹 Never give up!',
              'How I went from 0 to SDE-3 at a FAANG in 18 months — the complete roadmap 🧵👇',
              'WebSocket vs SSE vs Long Polling — I tested all 3 in a real app. The winner might surprise you...',
              'Rust is taking over backend development and I\'m here for it. Rewrote our API, memory usage dropped 80%.',
              'My team just shipped real-time collaboration using CRDTs. Here\'s what we learned about distributed state 🔬',
              'Voice rooms are the future of online communities. That\'s why we built AgoraX 🎙️',
            ][i % 10],
            images: [
              [
                'https://images.unsplash.com/photo-1618401471353-b98aedd07871?w=400'
              ],
              null,
              null,
              [
                'https://images.unsplash.com/photo-1507238691740-187a5b1d37b8?w=400'
              ],
              null,
              null,
              null,
              null,
              null,
              null,
            ][i % 10],
            videos: [
              null,
              null,
              null,
              null,
              null,
              [
                'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4'
              ],
              null,
              null,
              null,
              null,
            ][i % 10],
            pdfs: [
              null,
              ['AI_Coding_Prompts_Booklet.pdf'],
              null,
              null,
              null,
              null,
              null,
              ['Rust_Backend_Optimization.pdf'],
              null,
              null,
            ][i % 10],
            docUrls: [
              null,
              null,
              ['TopologicalSort_AlienDict.docx'],
              null,
              null,
              null,
              null,
              null,
              ['CRDT_DistributedState_Report.docx'],
              null,
            ][i % 10],
            likes: 200 + i * 73,
            comments: 28 + i * 12,
            shares: 15 + i * 5,
            isLiked: i % 3 == 0,
            isBookmarked: i % 7 == 0,
            createdAt: DateTime.now().subtract(Duration(hours: i * 3 + 1)),
          ));

  final List<User> _postAuthors = List.generate(
      10,
      (i) => User(
            id: 'u$i',
            username: [
              'flutter_dev',
              'ai_coder',
              'algomaster',
              'webwizard',
              'oss_hero',
              'sde_ninja',
              'netguru',
              'rustacean',
              'distrib_sys',
              'voice_builder'
            ][i % 10],
            email: '',
            displayName: [
              'Rohan Sharma',
              'Priya Mehta',
              'Arjun Singh',
              'Kavya Nair',
              'Dev Patel',
              'Ananya Roy',
              'Karan Joshi',
              'Shreya Das',
              'Vikram Menon',
              'Aditya Kumar'
            ][i % 10],
            avatar: [
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
              'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
              'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150',
              'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150',
              'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150',
              'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=150',
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
              'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150',
              'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150',
            ][i % 10],
            sid: '108${290 + i}',
            interests: [],
            communities: [],
            followers: 500 + i * 300,
            following: 100 + i * 50,
            isVerified: i % 3 == 0,
            isPremium: i % 4 == 0,
            reputation: 1000 + i * 400,
            level: 5 + i * 2,
            xp: 1000 + i * 500,
            totalXp: 5000,
            totalPosts: 20 + i * 10,
            totalQuestions: 5 + i * 3,
            badges: i % 2 == 0
                ? ['🏆 Top Contributor', '🎤 Voice Host']
                : ['💡 Problem Solver'],
            levelTitle: i < 3
                ? 'Explorer'
                : i < 7
                    ? 'Expert'
                    : 'Legend',
          ));

  final List<Question> _questions = List.generate(
      8,
      (i) => Question(
            id: 'q$i',
            userId: 'u$i',
            communityId: 'flutter',
            title: [
              'How to implement infinite scroll with pagination in Flutter?',
              'What\'s the best way to handle JWT token refresh automatically?',
              'Explaining Raft consensus algorithm simply — can anyone help?',
              'How does the V8 JS engine handle garbage collection?',
              'Best practices for API rate limiting in Node.js?',
              'How to design a URL shortener like bit.ly from scratch?',
              'Difference between process and thread in operating systems?',
              'How to handle CORS errors in a production Flutter web app?',
            ][i],
            description: '',
            tags: [
              ['Flutter', 'Pagination', 'UI'],
              ['Auth', 'JWT', 'Network'],
              ['Distributed', 'Algorithms', 'Consensus'],
              ['JavaScript', 'V8', 'Memory'],
              ['Node.js', 'API', 'Performance'],
              ['System Design', 'Database', 'Scalability'],
              ['OS', 'Concurrency', 'Theory'],
              ['Flutter', 'Web', 'CORS'],
            ][i],
            views: 1200 + i * 400,
            answers: 6 + i * 3,
            upvotes: 120 + i * 45,
            isUpvoted: i % 3 == 0,
            isBookmarked: i % 5 == 0,
            isAnonymous: false,
            isAnswered: i % 2 == 0,
            createdAt: DateTime.now().subtract(Duration(hours: i * 5 + 2)),
          ));

  final List<Community> _communities = List.generate(6, (i) {
    final names = [
      'Flutter India 🦋',
      'AI & ML Hub 🤖',
      'DSA Grinders 🧠',
      'Web Dev Café ☕',
      'Open Source 🌍',
      'UPSC Aspirants 📚'
    ];
    final descs = [
      'Official community for Flutter developers across India',
      'Discuss AI, ML, and the future of intelligent systems',
      'Crack DSA together — daily challenges and solutions',
      'All things frontend, backend, and full-stack web dev',
      'Build and contribute to open source projects',
      'Study smart, crack UPSC together',
    ];
    return Community(
      id: 'c$i',
      name: names[i],
      description: descs[i],
      category: [
        'Technology',
        'AI',
        'Education',
        'Technology',
        'Open Source',
        'Education'
      ][i],
      type: 'public',
      owner: 'admin',
      admins: [],
      members: [],
      memberCount: [12400, 8200, 5600, 4800, 3100, 9800][i],
      isVerified: i % 2 == 0,
      createdAt: DateTime.now().subtract(Duration(days: i * 30)),
    );
  });

  final List<User> _users = List.generate(
      8,
      (i) => User(
            id: 'usr$i',
            username: [
              'top_coder',
              'flutter_queen',
              'ai_wizard',
              'open_src_king',
              'dsa_grinder',
              'react_dev',
              'cloud_arch',
              'mobile_guru'
            ][i],
            email: '',
            displayName: [
              'Rahul Tiwari',
              'Sneha Kapoor',
              'Nikhil Gupta',
              'Tanvi Shah',
              'Mohit Yadav',
              'Ritika Singh',
              'Saurabh Verma',
              'Pooja Mishra'
            ][i],
            avatar: [
              'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=150',
              'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150',
              'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150',
              'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=150',
              'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=150',
              'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150',
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
              'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
            ][i % 8],
            sid: '204${810 + i}',
            interests: [],
            communities: ['c1', 'c2'],
            followers: 800 + i * 400,
            following: 200 + i * 80,
            isVerified: i % 3 == 0,
            isPremium: i % 4 == 0,
            reputation: 2000 + i * 600,
            level: 8 + i * 2,
            xp: 2000 + i * 800,
            totalXp: 6000,
            totalPosts: 30 + i * 15,
            totalQuestions: 8 + i * 4,
            badges: ['🏆 Top Contributor'],
            levelTitle: i < 4 ? 'Expert' : 'Legend',
          ));

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _toggleLike(Post post) {
    final idx = _posts.indexWhere((p) => p.id == post.id);
    if (idx != -1) {
      setState(() {
        final current = _posts[idx];
        final newIsLiked = !current.isLiked;
        _posts[idx] = current.copyWith(
          isLiked: newIsLiked,
          likes: current.likes + (newIsLiked ? 1 : -1),
        );
      });
    }
  }

  void _toggleBookmark(Post post) {
    final idx = _posts.indexWhere((p) => p.id == post.id);
    if (idx != -1) {
      setState(() {
        final current = _posts[idx];
        final newIsBookmarked = !current.isBookmarked;
        _posts[idx] = current.copyWith(isBookmarked: newIsBookmarked);
      });
      Get.snackbar(
        post.isBookmarked ? 'Bookmark Removed 🗑️' : 'Bookmarked 📚',
        post.isBookmarked
            ? 'Post removed from bookmarks.'
            : 'Post added to bookmarks.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
      );
    }
  }

  void _commentPost(BuildContext context, Post post) {
    final TextEditingController controller = TextEditingController();
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF13131A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADD COMMENT',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Write your comment...',
                  hintStyle:
                      GoogleFonts.poppins(color: Colors.white30, fontSize: 13),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('Cancel',
                        style: GoogleFonts.poppins(color: Colors.white38)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isEmpty) return;
                      final idx = _posts.indexWhere((p) => p.id == post.id);
                      if (idx != -1) {
                        setState(() {
                          final current = _posts[idx];
                          _posts[idx] =
                              current.copyWith(comments: current.comments + 1);
                        });
                      }
                      Get.back();
                      Get.snackbar(
                        'Comment Posted 💬',
                        'Your comment was posted successfully!',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: const Color(0xFF10B981),
                        colorText: Colors.white,
                        duration: const Duration(seconds: 1),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6)),
                    child: Text('Post',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _sharePost(Post post) {
    Share.share(post.content);
    final idx = _posts.indexWhere((p) => p.id == post.id);
    if (idx != -1) {
      setState(() {
        final current = _posts[idx];
        _posts[idx] = current.copyWith(shares: current.shares + 1);
      });
    }
  }

  void _toggleUpvoteQuestion(Question q) {
    final idx = _questions.indexWhere((item) => item.id == q.id);
    if (idx != -1) {
      setState(() {
        final current = _questions[idx];
        final newIsUpvoted = !current.isUpvoted;
        _questions[idx] = current.copyWith(
          isUpvoted: newIsUpvoted,
          upvotes: current.upvotes + (newIsUpvoted ? 1 : -1),
        );
      });
    }
  }

  void _answerQuestion(BuildContext context, Question q) {
    final TextEditingController controller = TextEditingController();
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF13131A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SUBMIT YOUR ANSWER',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Type your answer details here...',
                  hintStyle:
                      GoogleFonts.poppins(color: Colors.white30, fontSize: 13),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('Cancel',
                        style: GoogleFonts.poppins(color: Colors.white38)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isEmpty) return;
                      final idx =
                          _questions.indexWhere((item) => item.id == q.id);
                      if (idx != -1) {
                        setState(() {
                          final current = _questions[idx];
                          _questions[idx] = current.copyWith(
                            answers: current.answers + 1,
                            isAnswered: true,
                          );
                        });
                      }
                      Get.back();
                      Get.snackbar(
                        'Answer Submitted 🎉',
                        'Thank you! Your answer has been posted.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: const Color(0xFF10B981),
                        colorText: Colors.white,
                        duration: const Duration(milliseconds: 1500),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6)),
                    child: Text('Submit',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header + Search ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Explore',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined,
                            color: AppTheme.textSecondary),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: AppTheme.borderColor, width: 0.8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.search,
                            color: AppTheme.textTertiary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() {}),
                            style: const TextStyle(
                                color: AppTheme.textPrimary, fontSize: 14),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Search posts, questions, people...',
                              hintStyle: TextStyle(
                                  color: AppTheme.textTertiary, fontSize: 14),
                              filled: false,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.tune_rounded,
                              color: AppTheme.primaryColor, size: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Tab Bar ──
            const SizedBox(height: 14),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 3,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textTertiary,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),

            // ── Content ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllTab(),
                  _buildPostsTab(),
                  _buildQuestionsTab(),
                  _buildCommunitiesTab(),
                  _buildUsersTab(),
                  _buildStudyVaultTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────── ALL TAB ────────────────
  Widget _buildAllTab() {
    final query = _searchController.text.trim().toLowerCase();
    final filteredPosts = _posts.asMap().entries.where((e) {
      final post = e.value;
      final author = _postAuthors[e.key];
      return post.content.toLowerCase().contains(query) ||
          author.displayName.toLowerCase().contains(query) ||
          author.username.toLowerCase().contains(query);
    }).toList();

    final filteredQuestions = _questions.where((q) {
      return q.title.toLowerCase().contains(query) ||
          q.tags.any((t) => t.toLowerCase().contains(query));
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        GestureDetector(
          onTap: () => Get.to(() => const StudyVaultHomeScreen()),
          child: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_stories, color: Colors.white, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📚 Explore Study Vault',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Buy, sell & read handwritten notes, project manuals, solved assignments and academic guides!',
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 10.5, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
              ],
            ),
          ),
        ),
        if (filteredPosts.isNotEmpty) ...[
          _sectionHeader(query.isEmpty ? '🔥 Trending Posts' : 'Posts Found'),
          const SizedBox(height: 10),
          ...filteredPosts.take(3).map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRichPostCard(e.value, _postAuthors[e.key]),
            );
          }).toList(),
          const SizedBox(height: 14),
        ],
        if (query.isEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader('👥 Recommended Communities'),
              TextButton(
                onPressed: () => _tabController.animateTo(3),
                child: const Text('See All',
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _communities.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) =>
                  _buildHorizontalCommunityCard(_communities[i]),
            ),
          ),
          const SizedBox(height: 20),
          // ── Trending Room Events & Popular Competitions ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader('⚔️ Trending Room Events'),
              TextButton(
                onPressed: () {},
                child: const Text('View All',
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildTrendingEventCard('Weekly Coding Challenge #43',
                    '🏆 ₹15K Pool', '💻 Coding', AppTheme.primaryColor),
                const SizedBox(width: 10),
                _buildTrendingEventCard('GATE Aptitude Battle',
                    '🪙 5,000 Coins', '📐 Test', const Color(0xFFF59E0B)),
                const SizedBox(width: 10),
                _buildTrendingEventCard(
                    'UI Design Hackathon',
                    '💎 3 Months Premium',
                    '🎨 Design',
                    const Color(0xFFEC4899)),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (filteredQuestions.isNotEmpty) ...[
          _sectionHeader(query.isEmpty ? '❓ Top Questions' : 'Questions Found'),
          const SizedBox(height: 10),
          ...filteredQuestions.take(3).map((q) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRichQuestionCard(q),
            );
          }).toList(),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPostsTab() {
    final query = _searchController.text.trim().toLowerCase();
    final filteredPosts = _posts.asMap().entries.where((e) {
      final post = e.value;
      final author = _postAuthors[e.key];
      return post.content.toLowerCase().contains(query) ||
          author.displayName.toLowerCase().contains(query) ||
          author.username.toLowerCase().contains(query);
    }).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filteredPosts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final entry = filteredPosts[i];
        return _buildRichPostCard(entry.value, _postAuthors[entry.key]);
      },
    );
  }

  Widget _buildRichPostCard(Post post, User author) {
    return GestureDetector(
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(user: author),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: author.avatar != null && author.avatar!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: author.avatar!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                            ),
                            errorWidget: (context, url, error) =>
                                _buildInitialsAvatar(author, radius: 20),
                          )
                        : _buildInitialsAvatar(author, radius: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(user: author),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              author.displayName,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (author.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded,
                                  size: 14, color: Color(0xFF60A5FA)),
                            ],
                            if (author.isPremium) ...[
                              const SizedBox(width: 4),
                              const Text('👑', style: TextStyle(fontSize: 12)),
                            ],
                          ],
                        ),
                        Text(
                          '@${author.username} · ${_timeAgo(post.createdAt)}',
                          style: const TextStyle(
                              color: AppTheme.textTertiary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                // Level chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Lv.${author.level}',
                    style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.more_vert,
                    color: AppTheme.textTertiary, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            // Content
            Text(
              post.content,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.55,
              ),
            ),
            PostAttachmentsWidget(post: post),
            const SizedBox(height: 14),
            // Divider
            const Divider(color: AppTheme.borderColor, height: 1),
            const SizedBox(height: 10),
            // Actions
            Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(post),
                  behavior: HitTestBehavior.opaque,
                  child: _postAction(
                    post.isLiked ? Icons.favorite : Icons.favorite_outline,
                    _formatNumber(post.likes),
                    post.isLiked ? AppTheme.errorColor : AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(width: 18),
                GestureDetector(
                  onTap: () => _commentPost(context, post),
                  behavior: HitTestBehavior.opaque,
                  child: _postAction(Icons.chat_bubble_outline,
                      _formatNumber(post.comments), AppTheme.textTertiary),
                ),
                const SizedBox(width: 18),
                GestureDetector(
                  onTap: () => _sharePost(post),
                  behavior: HitTestBehavior.opaque,
                  child: _postAction(Icons.repeat_rounded,
                      _formatNumber(post.shares), AppTheme.textTertiary),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _toggleBookmark(post),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      post.isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_outline,
                      size: 18,
                      color: post.isBookmarked
                          ? AppTheme.primaryColor
                          : AppTheme.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _postAction(IconData icon, String count, Color color) => Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(count, style: TextStyle(color: color, fontSize: 13)),
        ],
      );

  // ──────────────── QUESTIONS TAB ────────────────
  Widget _buildQuestionsTab() {
    final query = _searchController.text.trim().toLowerCase();
    final filteredQuestions = _questions.where((q) {
      return q.title.toLowerCase().contains(query) ||
          q.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filteredQuestions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _buildRichQuestionCard(filteredQuestions[i]),
    );
  }

  Widget _buildRichQuestionCard(Question q) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: q.isAnswered
              ? AppTheme.accentColor.withOpacity(0.25)
              : AppTheme.borderColor.withOpacity(0.5),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top badges row
          Row(
            children: [
              if (q.isAnswered)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 12, color: AppTheme.accentColor),
                      SizedBox(width: 4),
                      Text('Answered',
                          style: TextStyle(
                              color: AppTheme.accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              if (!q.isAnswered)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.help_outline,
                          size: 12, color: AppTheme.warningColor),
                      SizedBox(width: 4),
                      Text('Open',
                          style: TextStyle(
                              color: AppTheme.warningColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              const Spacer(),
              Text(_timeAgo(q.createdAt),
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            q.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: q.tags
                .map((tag) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(tag,
                          style: const TextStyle(
                              color: AppTheme.primaryColor, fontSize: 11)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.borderColor, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: () => _toggleUpvoteQuestion(q),
                behavior: HitTestBehavior.opaque,
                child: _qStat(
                  Icons.arrow_upward_rounded,
                  _formatNumber(q.upvotes),
                  q.isUpvoted ? AppTheme.primaryColor : AppTheme.textTertiary,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => _answerQuestion(context, q),
                behavior: HitTestBehavior.opaque,
                child: _qStat(Icons.chat_bubble_outline_rounded,
                    '${q.answers} answers', AppTheme.textTertiary),
              ),
              const SizedBox(width: 16),
              _qStat(Icons.visibility_outlined, _formatNumber(q.views),
                  AppTheme.textTertiary),
              const Spacer(),
              GestureDetector(
                onTap: () => _answerQuestion(context, q),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Answer',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qStat(IconData icon, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      );

  // ──────────────── COMMUNITIES TAB ────────────────
  Widget _buildCommunitiesTab() {
    final query = _searchController.text.trim().toLowerCase();
    final filteredCommunities = _communities.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.category.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query);
    }).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filteredCommunities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) =>
          _buildFullCommunityCard(filteredCommunities[i]),
    );
  }

  Widget _buildHorizontalCommunityCard(Community c) {
    final icons = ['🦋', '🤖', '🧠', '☕', '🌍', '📚'];
    final idx = _communities.indexOf(c);
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icons[idx % icons.length], style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(c.name.split(' ')[0],
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('${_formatNumber(c.memberCount)} members',
              style:
                  const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                minimumSize: Size.zero,
                elevation: 0,
              ),
              child: const Text('Join',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullCommunityCard(Community c) {
    final icons = ['🦋', '🤖', '🧠', '☕', '🌍', '📚'];
    final idx = _communities.indexOf(c);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.primaryColor.withOpacity(0.25),
                AppTheme.secondaryColor.withOpacity(0.15),
              ]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(icons[idx % icons.length],
                  style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(c.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          )),
                    ),
                    if (c.isVerified)
                      const Icon(Icons.verified_rounded,
                          color: Color(0xFF60A5FA), size: 16),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${_formatNumber(c.memberCount)} members · ${c.category}',
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(c.description,
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
              minimumSize: Size.zero,
            ),
            child: const Text('Join',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    final query = _searchController.text.trim().toLowerCase();
    final filteredUsers = _users.where((u) {
      return u.displayName.toLowerCase().contains(query) ||
          u.username.toLowerCase().contains(query) ||
          u.sid.toLowerCase().contains(query) ||
          u.sid.replaceAll('#', '').contains(query);
    }).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filteredUsers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _buildUserCard(filteredUsers[i]),
    );
  }

  Widget _buildUserCard(User u) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserProfileScreen(user: u)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar with level ring
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: u.avatar != null && u.avatar!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: u.avatar!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                          ),
                          errorWidget: (context, url, error) =>
                              _buildInitialsAvatar(u, radius: 26),
                        )
                      : _buildInitialsAvatar(u, radius: 26),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.bgDark, width: 1.5),
                    ),
                    child: Center(
                      child: Text('${u.level}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(u.displayName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          )),
                      if (u.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            size: 14, color: Color(0xFF60A5FA)),
                      ],
                      if (u.isPremium) ...[
                        const SizedBox(width: 4),
                        const Text('👑', style: TextStyle(fontSize: 11)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('@${u.username}',
                          style: const TextStyle(
                              color: AppTheme.textTertiary, fontSize: 12)),
                      const SizedBox(width: 8),
                      Text('ID: ${u.sid}',
                          style: const TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatNumber(u.followers)} followers · ${u.levelTitle}',
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Follow',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            )),
        TextButton(
          onPressed: () {},
          child: const Text('See all',
              style: TextStyle(color: AppTheme.primaryColor, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildTrendingEventCard(
      String title, String prize, String tag, Color color) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                      color: color, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
              const Icon(Icons.flash_on, color: Color(0xFFFBBF24), size: 14),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            prize,
            style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontSize: 9,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar(User u, {double radius = 20}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
      child: Text(
        u.displayName.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.9,
        ),
      ),
    );
  }

  Widget _buildStudyVaultTab() {
    if (!Get.isRegistered<StudyVaultController>()) {
      Get.put(StudyVaultController());
    }
    final vaultCtrl = Get.find<StudyVaultController>();
    final query = _searchController.text.trim().toLowerCase();

    final filteredBooks = vaultCtrl.items.where((book) {
      if (query.isNotEmpty) {
        return book.title.toLowerCase().contains(query) ||
            book.authorName.toLowerCase().contains(query) ||
            book.branch.toLowerCase().contains(query) ||
            book.tags.any((t) => t.toLowerCase().contains(query));
      }
      return book.status == 'Approved';
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              query.isEmpty ? '📚 Browse Study Vault' : '🔍 Books & Notes Found',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            if (query.isEmpty)
              TextButton(
                onPressed: () => Get.to(() => const StudyVaultHomeScreen()),
                child: const Text('Go to Bookshelf ➔', style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
              )
          ],
        ),
        const SizedBox(height: 12),
        filteredBooks.isEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: const Center(child: Text('No books or notes matching query.', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12))),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.65,
                ),
                itemCount: filteredBooks.length,
                itemBuilder: (context, i) {
                  final book = filteredBooks[i];
                  return GestureDetector(
                    onTap: () => Get.to(() => BookDetailsScreen(book: book)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 110,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(image: NetworkImage(book.coverImage), fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(book.title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(book.sellingPrice == 0 ? 'FREE' : '₹${book.sellingPrice.toStringAsFixed(0)}', style: TextStyle(color: book.sellingPrice == 0 ? AppTheme.accentColor : const Color(0xFFFFD700), fontSize: 9.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              )
      ],
    );
  }
}

