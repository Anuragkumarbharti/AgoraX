import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../models/question_model.dart';
import '../settings/settings_screen.dart';
import '../../widgets/post_attachments_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final User _user = User(
    id: 'me',
    username: 'anurag_dev',
    email: 'anurag@example.com',
    displayName: 'Anurag Kumar',
    bio:
        '🚀 Flutter Developer | AI Enthusiast | Building AgoraX\n💡 Love discussing tech, DSA & open source',
    interests: ['Flutter', 'AI', 'DSA'],
    communities: ['Flutter India', 'AI Community', 'Web Dev'],
    followers: 3240,
    following: 512,
    isVerified: true,
    isPremium: true,
    reputation: 4850,
    avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200',
    sid: '773091',
    level: 14,
    xp: 3450,
    totalXp: 5000,
    totalPosts: 87,
    totalQuestions: 34,
    badges: [
      '🏆 Top Contributor',
      '🎤 Voice Host',
      '💡 Problem Solver',
      '🔥 Streak Master',
      '⭐ Rising Star',
      '💎 Premium',
    ],
    levelTitle: 'Expert',
  );

  final List<Post> _posts = List.generate(
    5,
    (i) {
      final contentList = [
        'Just shipped a new feature in AgoraX! Voice rooms are now 50% faster 🚀 #Flutter #Performance',
        'Building the UI for AgoraX voice rooms. Using CustomPainters for the audio waves makes it look so alive! 🌊',
        'Just added dark mode support to the design system. HSL colors for gradients are clean.',
        'Working on a new feature today. Any comments or suggestions on the UI design?',
        'Quick question: What state management library do you prefer in Flutter for large-scale applications?',
        'AgoraX is going live soon. Get ready to experience voice-first community hosting! 🎤',
      ];
      final imagesList = [
        ['https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400'],
        null,
        null,
        null,
        null,
      ];
      final videosList = [
        null,
        ['https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4'],
        null,
        null,
        null,
      ];
      final pdfsList = [
        null,
        null,
        ['AgoraX_Architecture_Design.pdf'],
        null,
        null,
      ];
      final docUrlsList = [
        null,
        null,
        null,
        ['AgoraX_StateManagement_Proposal.docx'],
        null,
      ];
      final likesList = [42, 128, 64, 96, 210];
      final commentsList = [8, 24, 12, 48, 56];
      final sharesList = [2, 10, 4, 8, 15];

      return Post(
        id: 'p$i',
        userId: 'me',
        communityId: 'flutter',
        content: i < contentList.length ? contentList[i] : '',
        images: i < imagesList.length ? imagesList[i] : null,
        videos: i < videosList.length ? videosList[i] : null,
        pdfs: i < pdfsList.length ? pdfsList[i] : null,
        docUrls: i < docUrlsList.length ? docUrlsList[i] : null,
        likes: i < likesList.length ? likesList[i] : 0,
        comments: i < commentsList.length ? commentsList[i] : 0,
        shares: i < sharesList.length ? sharesList[i] : 0,
        isLiked: i % 2 == 0,
        isBookmarked: i % 3 == 0,
        createdAt: DateTime.now().subtract(Duration(hours: i * 4)),
      );
    },
  );

  final List<Question> _questions = List.generate(
    5,
    (i) => Question(
      id: 'q$i',
      userId: 'me',
      communityId: 'flutter',
      title: [
        'How to implement custom scroll physics in Flutter?',
        'Best practices for handling WebSocket reconnection in Dart?',
        'What\'s the difference between isolates and compute() in Flutter?',
        'How to optimise ListView for 10,000+ items without jank?',
        'RenderFlex overflow error even with Expanded widget — why?',
      ][i],
      description: 'Detailed question description...',
      tags: [
        ['Flutter', 'UI', 'Scroll'],
        ['Dart', 'WebSocket', 'Network'],
        ['Flutter', 'Concurrency', 'Isolate'],
        ['Flutter', 'Performance', 'ListView'],
        ['Flutter', 'Layout', 'Debug'],
      ][i],
      views: 400 + i * 150,
      answers: 3 + i * 2,
      upvotes: 45 + i * 18,
      isUpvoted: i % 2 == 0,
      isBookmarked: false,
      isAnonymous: false,
      isAnswered: i % 3 == 0,
      createdAt: DateTime.now().subtract(Duration(days: i * 3 + 1)),
    ),
  );

  final List<Map<String, dynamic>> _communities = [
    {'name': 'Flutter India', 'members': '12.4K', 'icon': '🦋', 'role': 'Admin'},
    {'name': 'AI & ML Hub', 'members': '8.2K', 'icon': '🤖', 'role': 'Member'},
    {'name': 'DSA Grind', 'members': '5.6K', 'icon': '🧠', 'role': 'Moderator'},
    {'name': 'Open Source Dev', 'members': '3.1K', 'icon': '🌍', 'role': 'Member'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color get _levelColor {
    final level = _user.level;
    if (level <= 5) return const Color(0xFF60A5FA);
    if (level <= 10) return AppTheme.accentColor;
    if (level <= 20) return AppTheme.primaryColor;
    return const Color(0xFFFBBF24);
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(innerBoxIsScrolled),
          SliverToBoxAdapter(child: _buildProfileBody()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primaryColor,
                indicatorWeight: 3,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: AppTheme.textTertiary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Posts'),
                  Tab(text: 'Questions'),
                  Tab(text: 'Communities'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPostsTab(),
            _buildQuestionsTab(),
            _buildCommunitiesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool innerBoxIsScrolled) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: 'https://agorax.com/profile/${_user.sid}'));
            Get.snackbar(
              'Share Link Copied 🔗',
              'Profile link copied to clipboard.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.9),
              colorText: Colors.white,
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: () => Get.to(() => const SettingsScreen()),
        ),
      ],
    );
  }

  Widget _buildProfileBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Cover Photo Banner
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.8),
                    AppTheme.secondaryColor.withOpacity(0.6),
                    const Color(0xFF0F172A),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
              child: Opacity(
                opacity: 0.05,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                  ),
                  itemCount: 24,
                  itemBuilder: (_, i) => Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),
            // Edit Cover Button
            Positioned(
              right: 16,
              bottom: 12,
              child: GestureDetector(
                onTap: () {
                  Get.snackbar(
                    'Edit Cover',
                    'Cover image edit sheet coming soon',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt_outlined, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Edit Cover',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Avatar positioned overlapping
            Positioned(
              left: 20,
              bottom: -40,
              child: _buildAvatar(),
            ),
            // Edit Profile Button positioned overlapping
            Positioned(
              right: 20,
              bottom: -20,
              child: ElevatedButton.icon(
                onPressed: () => _showEditProfileSheet(context),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.bgLight,
                  foregroundColor: AppTheme.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 50), // space for overlapping avatar
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Single Username Display
              Row(
                children: [
                  Text(
                    _user.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_user.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded, color: Color(0xFF60A5FA), size: 20),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              
              // Unique ID Display
              Row(
                children: [
                  Text(
                    'ID: ${_user.sid}',
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _copyToClipboard(_user.sid, 'AgoraX ID'),
                    child: const Icon(
                      Icons.copy_rounded,
                      color: AppTheme.textTertiary,
                      size: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Level Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _levelColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _levelColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, size: 14, color: _levelColor),
                    const SizedBox(width: 3),
                    Text(
                      'Lv.${_user.level} ${_user.levelTitle}',
                      style: TextStyle(
                        color: _levelColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Bio
              Text(
                _user.bio ?? '',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              
              // XP Bar
              _buildXpBar(),
              const SizedBox(height: 20),
              
              // Stats Row
              _buildStatsRow(),
              const SizedBox(height: 20),
              
              // Badges
              _buildBadgesRow(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        // Level ring
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_levelColor, _levelColor.withOpacity(0.3)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.bgDark,
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(38),
                  child: _user.avatar != null && _user.avatar!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _user.avatar!,
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => _buildInitialsAvatar(),
                        )
                      : _buildInitialsAvatar(),
                ),
              ),
            ),
          ),
        ),
        // Level badge
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _levelColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.bgDark, width: 2),
            ),
            child: Center(
              child: Text(
                '${_user.level}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        // Camera overlay for editing
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: () => _showEditAvatarSheet(context),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.bgDark, width: 2),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildXpBar() {
    final progress = _user.xp / _user.totalXp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_formatNumber(_user.xp)} XP',
              style: TextStyle(
                  color: _levelColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
            Text(
              '${_formatNumber(_user.totalXp)} XP to Lv.${_user.level + 1}',
              style: const TextStyle(
                  color: AppTheme.textTertiary, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppTheme.borderColor,
            valueColor: AlwaysStoppedAnimation(
              _levelColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _statItem(_formatNumber(_user.followers), 'Followers'),
        _statDivider(),
        _statItem(_formatNumber(_user.following), 'Following'),
        _statDivider(),
        _statItem('${_user.totalPosts}', 'Posts'),
        _statDivider(),
        _statItem('${_user.communities.length}', 'Communities'),
      ],
    );
  }

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 28,
      color: AppTheme.borderColor,
    );
  }

  Widget _buildBadgesRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Badges',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _user.badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.2),
                      AppTheme.secondaryColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _user.badges[i],
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────── Tabs ───────────

  Widget _buildPostsTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _buildPostCard(_posts[i]),
    );
  }

  Widget _buildPostCard(Post post) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _user.avatar != null && _user.avatar!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _user.avatar!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                        ),
                        errorWidget: (context, url, error) => _buildAuthorInitialsAvatar(),
                      )
                    : _buildAuthorInitialsAvatar(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _user.displayName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (_user.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              size: 14, color: Color(0xFF60A5FA)),
                        ],
                      ],
                    ),
                    Text(
                      '${_timeAgo(post.createdAt)} · @${_user.username}',
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    color: AppTheme.textTertiary, size: 20),
                color: AppTheme.bgLight,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {},
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  const PopupMenuItem(value: 'pin', child: Text('Pin Post')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Content
          Text(
            post.content,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          PostAttachmentsWidget(post: post),
          const SizedBox(height: 14),
          // Actions
          Row(
            children: [
              _postAction(
                  post.isLiked ? Icons.favorite : Icons.favorite_outline,
                  '${post.likes}',
                  post.isLiked ? AppTheme.errorColor : AppTheme.textTertiary),
              const SizedBox(width: 20),
              _postAction(Icons.chat_bubble_outline, '${post.comments}',
                  AppTheme.textTertiary),
              const SizedBox(width: 20),
              _postAction(
                  Icons.repeat_rounded, '${post.shares}', AppTheme.textTertiary),
              const Spacer(),
              Icon(
                post.isBookmarked
                    ? Icons.bookmark
                    : Icons.bookmark_outline,
                size: 18,
                color: post.isBookmarked
                    ? AppTheme.primaryColor
                    : AppTheme.textTertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _postAction(IconData icon, String count, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          count,
          style: TextStyle(color: color, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildQuestionsTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _questions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _buildQuestionCard(_questions[i]),
    );
  }

  Widget _buildQuestionCard(Question q) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Answered badge
          if (q.isAnswered)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(bottom: 8),
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
          // Tags
          Wrap(
            spacing: 6,
            children: q.tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                      color: AppTheme.primaryColor, fontSize: 11),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Stats
          Row(
            children: [
              _qStat(Icons.arrow_upward_rounded, '${q.upvotes}',
                  q.isUpvoted ? AppTheme.primaryColor : AppTheme.textTertiary),
              const SizedBox(width: 16),
              _qStat(Icons.chat_bubble_outline_rounded, '${q.answers} answers',
                  AppTheme.textTertiary),
              const SizedBox(width: 16),
              _qStat(Icons.visibility_outlined, '${q.views}',
                  AppTheme.textTertiary),
              const Spacer(),
              Text(
                _timeAgo(q.createdAt),
                style: const TextStyle(
                    color: AppTheme.textTertiary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qStat(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  Widget _buildCommunitiesTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _communities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _buildCommunityCard(_communities[i]),
    );
  }

  Widget _buildCommunityCard(Map<String, dynamic> c) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.3),
                  AppTheme.secondaryColor.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                Center(child: Text(c['icon'], style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['name'],
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${c['members']} members',
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: c['role'] == 'Admin'
                  ? AppTheme.primaryColor.withOpacity(0.2)
                  : c['role'] == 'Moderator'
                      ? AppTheme.accentColor.withOpacity(0.15)
                      : AppTheme.bgLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: c['role'] == 'Admin'
                      ? AppTheme.primaryColor.withOpacity(0.4)
                      : c['role'] == 'Moderator'
                          ? AppTheme.accentColor.withOpacity(0.4)
                          : AppTheme.borderColor),
            ),
            child: Text(
              c['role'],
              style: TextStyle(
                color: c['role'] == 'Admin'
                    ? AppTheme.primaryColor
                    : c['role'] == 'Moderator'
                        ? AppTheme.accentColor
                        : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Profile',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textTertiary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _editField('Display Name', _user.displayName),
            const SizedBox(height: 12),
            _editField('Username', '@${_user.username}'),
            const SizedBox(height: 12),
            _editField('Bio', _user.bio ?? '', maxLines: 3),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField(String label, String value, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: value,
          maxLines: maxLines,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.bgDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: AppTheme.accentColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showEditAvatarSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile Photo',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppTheme.primaryColor),
              title: const Text('Take Photo', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _mockPickImage('Camera');
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryColor),
              title: const Text('Choose from Gallery', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _mockPickImage('Gallery');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
              title: const Text('Remove Photo', style: TextStyle(color: AppTheme.errorColor)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile photo removed'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mockPickImage(String source) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Profile photo updated from $source!'),
        backgroundColor: AppTheme.accentColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    return Center(
      child: Text(
        _user.displayName.substring(0, 1).toUpperCase(),
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildAuthorInitialsAvatar() {
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
      child: Text(
        _user.displayName.substring(0, 1),
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// Sticky TabBar delegate for NestedScrollView
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(
        color: AppTheme.bgDark,
        child: tabBar,
      );

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}
