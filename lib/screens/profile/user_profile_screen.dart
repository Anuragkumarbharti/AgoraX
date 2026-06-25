import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../models/question_model.dart';
import '../../widgets/post_attachments_widget.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({Key? key, required this.user}) : super(key: key);

  final User user;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFollowing = false;
  bool _isMessageSent = false;

  late List<Post> _posts;
  late List<Question> _questions;
  late List<Map<String, dynamic>> _communities;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _generateMockData();
  }

  void _generateMockData() {
    final u = widget.user;
    _posts = List.generate(6, (i) => Post(
      id: 'p$i',
      userId: u.id,
      communityId: 'flutter',
      content: [
        'Just shipped a major update today 🚀 Check it out and let me know what you think!',
        'Hot take: Most apps don\'t need a state management library. Simple setState works fine for most cases.',
        'Learned something new about Dart isolates today — sharing with the community 🧵',
        'What\'s your favourite Flutter package? Mine is go_router. So clean and easy to use.',
        'Building something exciting in public. Day 7 update: auth flow is done! 💪',
        'Code review tip: Always review your own PR before requesting a review. Saves everyone time.',
      ][i % 6],
      likes: 80 + i * 33,
      comments: 12 + i * 7,
      shares: 5 + i * 2,
      isLiked: i % 4 == 0,
      isBookmarked: false,
      createdAt: DateTime.now().subtract(Duration(hours: i * 8 + 3)),
    ));

    _questions = List.generate(4, (i) => Question(
      id: 'q$i',
      userId: u.id,
      communityId: 'flutter',
      title: [
        'How to handle deep linking in Flutter with go_router?',
        'Best way to persist state across app restarts?',
        'MethodChannel vs PlatformView — when to use which?',
        'How to test asynchronous code in Flutter unit tests?',
      ][i],
      description: '',
      tags: [
        ['Flutter', 'Navigation'],
        ['Flutter', 'Storage', 'Hive'],
        ['Flutter', 'Platform'],
        ['Flutter', 'Testing', 'Dart'],
      ][i],
      views: 300 + i * 100,
      answers: 2 + i * 3,
      upvotes: 30 + i * 15,
      isUpvoted: i % 2 == 0,
      isBookmarked: false,
      isAnonymous: false,
      isAnswered: i % 2 == 1,
      createdAt: DateTime.now().subtract(Duration(days: i * 4 + 2)),
    ));

    _communities = [
      {'name': 'Flutter India', 'members': '12.4K', 'icon': '🦋'},
      {'name': 'AI & ML Hub', 'members': '8.2K', 'icon': '🤖'},
      {'name': 'Web Dev Café', 'members': '4.8K', 'icon': '🌐'},
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color get _levelColor {
    final level = widget.user.level;
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
    final u = widget.user;
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(u),
          SliverToBoxAdapter(child: _buildProfileBody(u)),
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
            _buildPostsTab(u),
            _buildQuestionsTab(),
            _buildCommunitiesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(User u) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: 'https://agorax.com/profile/${u.sid}'));
            Get.snackbar(
              'Link Copied 📋',
              'Profile link copied to clipboard.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.9),
              colorText: Colors.white,
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: () => _showOptionsSheet(),
        ),
      ],
    );
  }

  Widget _buildProfileBody(User u) {
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
                    _levelColor.withOpacity(0.8),
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
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            // Avatar positioned overlapping
            Positioned(
              left: 20,
              bottom: -40,
              child: _buildAvatar(u),
            ),
            // Follow & Message buttons positioned overlapping
            Positioned(
              right: 20,
              bottom: -20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Message Button
                  GestureDetector(
                    onTap: () {
                      setState(() => _isMessageSent = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Message conversation started with ${u.displayName}'),
                          backgroundColor: AppTheme.accentColor,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.bgLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mail_outline, size: 16, color: AppTheme.textPrimary),
                          SizedBox(width: 6),
                          Text(
                            'Message',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Follow Button
                  GestureDetector(
                    onTap: () => setState(() => _isFollowing = !_isFollowing),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: _isFollowing
                            ? null
                            : const LinearGradient(colors: [
                                AppTheme.primaryColor,
                                AppTheme.secondaryColor,
                              ]),
                        color: _isFollowing ? AppTheme.bgLight : null,
                        borderRadius: BorderRadius.circular(10),
                        border: _isFollowing ? Border.all(color: AppTheme.borderColor) : null,
                      ),
                      child: Text(
                        _isFollowing ? 'Following' : 'Follow',
                        style: TextStyle(
                          color: _isFollowing ? AppTheme.textSecondary : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
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
                    u.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (u.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded, color: Color(0xFF60A5FA), size: 20),
                  ],
                  if (u.isPremium) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFFFBBF24),
                          Color(0xFFF59E0B)
                        ]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '👑',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              
              // Unique ID Display
              Row(
                children: [
                  Text(
                    'ID: ${u.sid}',
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _copyToClipboard(u.sid, 'AgoraX ID'),
                    child: const Icon(
                      Icons.copy_rounded,
                      color: AppTheme.textTertiary,
                      size: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Level Badge & Reputation
              Row(
                children: [
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
                          'Lv.${u.level} ${u.levelTitle}',
                          style: TextStyle(
                            color: _levelColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatNumber(u.reputation)} Reputation',
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (u.bio != null && u.bio!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  u.bio!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              
              // XP Bar
              _buildXpBar(u),
              const SizedBox(height: 20),
              
              // Stats
              _buildStatsRow(u),
              const SizedBox(height: 20),
              
              // Badges
              if (u.badges.isNotEmpty) _buildBadgesRow(u),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(User u) {
    return Stack(
      children: [
        Container(
          width: 86,
          height: 86,
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
                  child: u.avatar != null && u.avatar!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: u.avatar!,
                          width: 74,
                          height: 74,
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
                          errorWidget: (context, url, error) => _buildInitialsAvatar(u),
                        )
                      : _buildInitialsAvatar(u),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _levelColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.bgDark, width: 2),
            ),
            child: Center(
              child: Text(
                '${u.level}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildXpBar(User u) {
    final progress = u.xp / u.totalXp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_formatNumber(u.xp)} XP',
              style: TextStyle(
                  color: _levelColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
            Text(
              'Next level: ${_formatNumber(u.totalXp)} XP',
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
            minHeight: 7,
            backgroundColor: AppTheme.borderColor,
            valueColor: AlwaysStoppedAnimation(_levelColor),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(User u) {
    return Row(
      children: [
        _statItem(_formatNumber(u.followers), 'Followers'),
        _statDivider(),
        _statItem(_formatNumber(u.following), 'Following'),
        _statDivider(),
        _statItem('${u.totalPosts}', 'Posts'),
        _statDivider(),
        _statItem('${u.communities.length}', 'Communities'),
      ],
    );
  }

  Widget _statItem(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textTertiary, fontSize: 11)),
          ],
        ),
      );

  Widget _statDivider() => Container(
      width: 1, height: 26, color: AppTheme.borderColor);

  Widget _buildBadgesRow(User u) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Badges',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: u.badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppTheme.primaryColor.withOpacity(0.15),
                  AppTheme.secondaryColor.withOpacity(0.08),
                ]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Text(u.badges[i],
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500)),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ─────────── Tabs ───────────

  Widget _buildPostsTab(User u) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _buildPostCard(_posts[i], u),
    );
  }

  Widget _buildPostCard(Post post, User u) {
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
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: u.avatar != null && u.avatar!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: u.avatar!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                        ),
                        errorWidget: (context, url, error) => _buildAuthorInitialsAvatar(u),
                      )
                    : _buildAuthorInitialsAvatar(u),
              ),
              const SizedBox(width: 10),
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
                                fontSize: 14)),
                        if (u.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              size: 14, color: Color(0xFF60A5FA)),
                        ],
                      ],
                    ),
                    Text('${_timeAgo(post.createdAt)} · @${u.username}',
                        style: const TextStyle(
                            color: AppTheme.textTertiary, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.more_vert,
                  color: AppTheme.textTertiary, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(post.content,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14, height: 1.5)),
          PostAttachmentsWidget(post: post),
          const SizedBox(height: 14),
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
              _postAction(Icons.repeat_rounded, '${post.shares}',
                  AppTheme.textTertiary),
              const Spacer(),
              const Icon(Icons.bookmark_outline,
                  size: 18, color: AppTheme.textTertiary),
            ],
          ),
        ],
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
          Text(q.title,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.4)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: q.tags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(tag,
                  style: const TextStyle(
                      color: AppTheme.primaryColor, fontSize: 11)),
            )).toList(),
          ),
          const SizedBox(height: 12),
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
              Text(_timeAgo(q.createdAt),
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 11)),
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
              gradient: LinearGradient(colors: [
                AppTheme.primaryColor.withOpacity(0.25),
                AppTheme.secondaryColor.withOpacity(0.15),
              ]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(c['icon'], style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c['name'],
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text('${c['members']} members',
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 12)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              minimumSize: Size.zero,
            ),
            child: const Text('Join', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showOptionsSheet() {
    final u = widget.user;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _sheetOption(Icons.share_outlined, 'Share Profile', () {
              Navigator.pop(context);
            }),
            _sheetOption(Icons.block_outlined, 'Block @${u.username}', () {
              Navigator.pop(context);
            }),
            _sheetOption(Icons.flag_outlined, 'Report Profile', () {
              Navigator.pop(context);
            },
                color: AppTheme.errorColor),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sheetOption(IconData icon, String label, VoidCallback onTap,
      {Color color = AppTheme.textPrimary}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w500, fontSize: 15)),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
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

  Widget _buildInitialsAvatar(User u) {
    return Center(
      child: Text(
        u.displayName.substring(0, 1).toUpperCase(),
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildAuthorInitialsAvatar(User u) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
      child: Text(
        u.displayName.substring(0, 1).toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

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
