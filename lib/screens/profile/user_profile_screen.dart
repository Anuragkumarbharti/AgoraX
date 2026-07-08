import 'dart:math' as math;
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../models/question_model.dart';
import '../../widgets/post_attachments_widget.dart';
import '../../widgets/send_gift_dialog.dart';
import '../../services/room_controller.dart';
import 'badges_screen.dart';
import '../../services/chat_controller.dart';
import '../../models/chat_model.dart';
import '../chat/chat_screen.dart';
import '../communities/community_detail_screen.dart';
import 'profile_screen.dart';
import '../../widgets/vip_badge_widget.dart';
import '../../widgets/vip_avatar_decorator.dart';
import '../../widgets/novel_badge_widget.dart';
import '../../widgets/novel_avatar_decorator.dart';
import '../../widgets/custom_avatar_frame.dart';
import '../../services/customization_controller.dart';
import '../../services/premium_identity_controller.dart';
import '../../widgets/index.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({Key? key, required this.user}) : super(key: key);

  final User user;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _glowController;
  late AnimationController _rotateController;

  bool _isFollowing = false;
  bool _isBlocked = false;
  String _coverPhotoUrl =
      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800';

  late List<Post> _posts;
  late List<Question> _questions;
  late List<Map<String, dynamic>> _communities;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _generateMockData();
  }

  void _generateMockData() {
    final u = widget.user;
    _posts = List.generate(
        6,
        (i) => Post(
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

    _questions = List.generate(
        4,
        (i) => Question(
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
      {
        'id': 'c1',
        'name': 'Flutter India',
        'members': '12.4K',
        'icon': '🦋',
        'role': 'Moderator'
      },
      {
        'id': 'c2',
        'name': 'AI & ML Hub',
        'members': '8.2K',
        'icon': '🤖',
        'role': 'Member'
      },
      {
        'id': 'c3',
        'name': 'Web Dev Café',
        'members': '4.8K',
        'icon': '🌐',
        'role': 'Captain'
      },
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    _glowController.dispose();
    _rotateController.dispose();
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
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.4, -0.6),
            radius: 1.2,
            colors: [
              Color(0xFF1E1B4B), // Dark blue-purple
              Color(0xFF09090B), // Black
            ],
            stops: [0.0, 0.6],
          ),
        ),
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildSliverAppBar(u),
            SliverToBoxAdapter(child: _buildProfileBody(u)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF8B5CF6),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFF8B5CF6),
                  unselectedLabelColor: AppTheme.textTertiary,
                  labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Widget _buildSliverAppBar(User u) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        u.displayName,
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          onPressed: () {
            Clipboard.setData(
                ClipboardData(text: 'https://agorax.com/profile/${u.sid}'));
            Get.snackbar(
              'Link Copied 📋',
              'Profile link copied to clipboard.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.9),
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
        // COVER BANNER & AVATAR SECTION
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Cover Photo Banner
            Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(_coverPhotoUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      const Color(0xFF09090B).withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),

            // Avatar overlapping
            Positioned(
              left: 20,
              bottom: -46,
              child: _buildAvatar(u),
            ),

            // Follow & Message buttons positioned cleanly next to avatar
            Positioned(
              right: 20,
              bottom: -40,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Message Button
                  GestureDetector(
                    onTap: () {
                      final chatCtrl = Get.find<ChatController>();
                      final Conversation conversation =
                          chatCtrl.getOrCreateConversation(
                        u.id,
                        u.displayName,
                        u.avatar ?? '',
                      );
                      Get.to(() => ChatScreen(conversation: conversation));
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.mail_outline_rounded,
                                  size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                'Message',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Follow Button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isFollowing = !_isFollowing;
                      });
                      Get.snackbar(
                        _isFollowing ? 'Following 💖' : 'Unfollowed 💔',
                        _isFollowing
                            ? 'You followed ${u.displayName}.'
                            : 'You unfollowed ${u.displayName}.',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: _isFollowing
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFFD946EF), Color(0xFFEF408B)]),
                        color: _isFollowing
                            ? Colors.white.withOpacity(0.06)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        border: _isFollowing
                            ? Border.all(color: Colors.white.withOpacity(0.12))
                            : null,
                        boxShadow: _isFollowing
                            ? null
                            : [
                                BoxShadow(
                                  color:
                                      const Color(0xFFEF408B).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ],
                      ),
                      child: Text(
                        _isFollowing ? 'Following' : 'Follow',
                        style: GoogleFonts.poppins(
                          color: _isFollowing
                              ? AppTheme.textSecondary
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 54), // spacing for avatar overlap

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Username, Verified, Gender Row
              _buildNameSection(u),
              const SizedBox(height: 12),

              // Dynamic Tag Row containing levels (NO separate cards below)
              _buildTagRow(u),
              const SizedBox(height: 16),

              // Follow Stats Row
              _buildStatsCard(u),
              const SizedBox(height: 16),

              // Secondary Actions Row: Call, Gift, Block, Report
              _buildSecondaryActionsRow(u),
              const SizedBox(height: 16),

              // Status & Bio
              _buildBioSection(u),
              const SizedBox(height: 16),

              // Community Card (role, level, member count, etc.)
              _buildFamilyCard(u),
              const SizedBox(height: 16),

              // Badges Section
              _buildBadgesRow(u),
              const SizedBox(height: 16),

              // Chips Section
              _buildChipsSection(),
              const SizedBox(height: 16),

              // Personal Info Section
              _buildPersonalInfoSection(u),
              const SizedBox(height: 16),

              // Top Supporters
              _buildTopFansSection(),
              const SizedBox(height: 16),

              // Contribution Points
              _buildContributionSection(),
              const SizedBox(height: 16),

              // Spotify Listening Status Card
              _buildSpotifyCard(u),
              const SizedBox(height: 16),

              // Social Links
              _buildSocialsSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVipNameText(String text, int vipLevel) {
    final style = GoogleFonts.poppins(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );

    if (vipLevel <= 0) {
      return Text(text, style: style);
    }

    switch (vipLevel) {
      case 1:
        return Text(text,
            style: style.copyWith(color: const Color(0xFF2563EB)));
      case 2:
        return Text(text,
            style: style.copyWith(color: const Color(0xFF8B5CF6)));
      case 3:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFD97706)],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white)),
        );
      case 4:
        return Text(text,
            style: style.copyWith(color: const Color(0xFFF1F5F9), shadows: [
              const Shadow(color: Colors.white30, blurRadius: 4),
            ]));
      case 5:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF06B6D4), Color(0xFF22D3EE)],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white)),
        );
      case 6:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF007F), Color(0xFFFFBF00), Color(0xFF00F0FF)],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white)),
        );
      case 7:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFF1C1917), Color(0xFFFFD700)],
          ).createShader(bounds),
          child: Text(text,
              style: style.copyWith(color: Colors.white, shadows: [
                const Shadow(color: Color(0xFFD4AF37), blurRadius: 6),
              ])),
        );
      default:
        return Text(text, style: style);
    }
  }

  Widget _buildNovelNameText(String text, int novelLvl) {
    final style = GoogleFonts.poppins(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );

    switch (novelLvl) {
      case 1:
        return Text(text,
            style: style.copyWith(color: const Color(0xFF2563EB)));
      case 2:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFC084FC)],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white)),
        );
      case 3:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFD97706)],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white)),
        );
      case 4:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
          ).createShader(bounds),
          child: Text(text,
              style: style.copyWith(color: Colors.white, shadows: [
                const Shadow(color: Colors.redAccent, blurRadius: 4),
              ])),
        );
      case 5:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFF97316), Color(0xFFFDBA74)],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white)),
        );
      case 6:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF06B6D4), Color(0xFF22D3EE), Colors.white],
          ).createShader(bounds),
          child: Text(text,
              style: style.copyWith(color: Colors.white, shadows: [
                const Shadow(color: Colors.cyanAccent, blurRadius: 6),
              ])),
        );
      case 7:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFF1C1917), Color(0xFFFFD700)],
          ).createShader(bounds),
          child: Text(text,
              style: style.copyWith(color: Colors.white, shadows: [
                const Shadow(color: Color(0xFFFFD700), blurRadius: 8),
              ])),
        );
      default:
        return Text(text, style: style);
    }
  }

  Widget _buildNameSection(User u) {
    int novelLevel = 0;
    int vipLevel = 0;

    if (u.isPremium) {
      if (u.reputation > 6000) {
        novelLevel = 7;
      } else if (u.reputation > 4000) {
        novelLevel = 5;
      } else if (u.reputation > 2500) {
        novelLevel = 3;
      } else if (u.reputation > 1500) {
        novelLevel = 1;
      }

      if (novelLevel <= 0) {
        if (u.reputation > 5000) {
          vipLevel = 7;
        } else if (u.reputation > 3000) {
          vipLevel = 5;
        } else if (u.reputation > 1000) {
          vipLevel = 3;
        } else {
          vipLevel = 2;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PremiumNameWidget(
              name: u.displayName,
              userId: u.id,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            if (u.isVerified)
              const Icon(Icons.verified_rounded,
                  color: Color(0xFF38BDF8), size: 20),
            if (novelLevel > 0) ...[
              const SizedBox(width: 6),
              NovelBadgeWidget(level: novelLevel, fontSize: 11),
            ] else if (vipLevel > 0) ...[
              const SizedBox(width: 6),
              VipBadgeWidget(level: vipLevel, fontSize: 11),
            ],
            const SizedBox(width: 6),
            Text(
              u.id.hashCode % 2 == 0 ? '♂' : '♀',
              style: TextStyle(
                color: u.id.hashCode % 2 == 0
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFFF43F5E),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: PremiumIdentityController.getIdentity(u.id, u.displayName)
              .buildBadgeRow(context, fontSize: 9.5),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              'ID: ${u.sid}',
              style: GoogleFonts.poppins(
                color: AppTheme.textTertiary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _copyToClipboard(u.sid, 'AgoraX ID'),
              child: Icon(Icons.copy_rounded,
                  color: AppTheme.textTertiary.withOpacity(0.8), size: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatar(User u) {
    final isMe = u.id == 'me' ||
        u.id == 'uid_anurag_101' ||
        u.username == 'Anurag Kumar' ||
        u.displayName == 'Anurag Kumar';

    int novelLevel = 0;
    int activeNovel = 0;
    int vipLevel = 0;

    if (!isMe) {
      if (u.isPremium) {
        if (u.reputation > 6000) {
          novelLevel = 7;
          activeNovel = 7;
        } else if (u.reputation > 4000) {
          novelLevel = 5;
          activeNovel = 5;
        } else if (u.reputation > 2500) {
          novelLevel = 3;
          activeNovel = 3;
        } else if (u.reputation > 1500) {
          novelLevel = 1;
          activeNovel = 1;
        }

        if (u.reputation > 5000) {
          vipLevel = 7;
        } else if (u.reputation > 3000) {
          vipLevel = 5;
        } else if (u.reputation > 1000) {
          vipLevel = 3;
        } else {
          vipLevel = 2;
        }
      }
    }

    return Obx(() {
      final custCtrl = Get.find<CustomizationController>();
      final activeAvatarVal = custCtrl.activeAvatar.value;
      final avatarUrl = isMe
          ? custCtrl.getAvatarUrl(activeAvatarVal, u.avatar ?? '')
          : (u.avatar ?? '');

      return SizedBox(
        width: 110,
        height: 110,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            CustomAvatarFrame(
              userId: u.id,
              username: u.displayName,
              size: 90,
              defaultNovelLevel: activeNovel,
              defaultVipLevel: vipLevel,
              child: SizedBox(
                width: 90,
                height: 90,
                child: avatarUrl.isNotEmpty
                    ? (avatarUrl.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(avatarUrl),
                            fit: BoxFit.cover,
                          ))
                    : _buildInitialsAvatar(u),
              ),
            ),
            // Level badge at bottom
            Positioned(
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: const Color(0xFF09090B), width: 1.5),
                ),
                child: Text(
                  'Lv.${u.level}',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTagRow(User u) {
    List<Widget> tags = [];

    // 1. VIP Tag
    if (u.isPremium) {
      tags.add(_buildTagItem(
        label: 'VIP',
        icon: '👑',
        bgColor: const Color(0xFFFFC107).withOpacity(0.12),
        borderColor: const Color(0xFFFFC107).withOpacity(0.3),
        textColor: const Color(0xFFFFC107),
      ));
    }

    // 2. Novel Tag
    if (u.id.hashCode % 3 == 0) {
      tags.add(_buildTagItem(
        label: 'Novel',
        icon: '📖',
        bgColor: const Color(0xFFF97316).withOpacity(0.12),
        borderColor: const Color(0xFFF97316).withOpacity(0.3),
        textColor: const Color(0xFFF97316),
      ));
    }

    // 3. ID Level Tag
    tags.add(_buildTagItem(
      label: 'ID Lv.${u.level}',
      icon: '🌱',
      bgColor: const Color(0xFF8B5CF6).withOpacity(0.12),
      borderColor: const Color(0xFF8B5CF6).withOpacity(0.3),
      textColor: const Color(0xFFA855F7),
    ));

    // 4. Career Level Tag (Simulated for demo)
    if (u.id.hashCode % 2 == 0) {
      tags.add(_buildTagItem(
        label: 'Design Lv.14 (Practitioner)',
        icon: '🎓',
        bgColor: const Color(0xFF38BDF8).withOpacity(0.12),
        borderColor: const Color(0xFF38BDF8).withOpacity(0.3),
        textColor: const Color(0xFF38BDF8),
      ));
    }

    // 5. Community Tag Bracket
    Color bracketColor;
    String bracketName;
    if (u.level >= 55) {
      bracketColor = const Color(0xFF10B981);
      bracketName = 'Radiant';
    } else if (u.level >= 50) {
      bracketColor = const Color(0xFFFFD700);
      bracketName = 'Gold';
    } else if (u.level >= 40) {
      bracketColor = const Color(0xFFA855F7);
      bracketName = 'Purple';
    } else if (u.level >= 30) {
      bracketColor = const Color(0xFF3B82F6);
      bracketName = 'Blue';
    } else if (u.level >= 20) {
      bracketColor = const Color(0xFF94A3B8);
      bracketName = 'Silver';
    } else {
      bracketColor = const Color(0xFFB45309);
      bracketName = 'Bronze';
    }

    tags.add(_buildTagItem(
      label: '$bracketName Class',
      icon: '🏆',
      bgColor: bracketColor.withOpacity(0.12),
      borderColor: bracketColor.withOpacity(0.3),
      textColor: bracketColor,
    ));

    // 6. Verified Tag
    if (u.isVerified) {
      tags.add(_buildTagItem(
        label: 'Verified',
        icon: '✔',
        bgColor: const Color(0xFF22C55E).withOpacity(0.12),
        borderColor: const Color(0xFF22C55E).withOpacity(0.3),
        textColor: const Color(0xFF22C55E),
      ));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: tags
            .map((t) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: t,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildTagItem({
    required String label,
    required String icon,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection(User u) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            u.bio ?? 'No bio written yet.',
            style: GoogleFonts.poppins(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.link_rounded,
                  color: Color(0xFF38BDF8), size: 14),
              const SizedBox(width: 6),
              Text(
                'https://agorax.com/${u.username}',
                style: GoogleFonts.poppins(
                    color: const Color(0xFF38BDF8),
                    fontSize: 12,
                    decoration: TextDecoration.underline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryActionsRow(User u) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Send Gift
          _actionPill(
            icon: Icons.card_giftcard_rounded,
            label: 'Gift',
            color: const Color(0xFFFFC107),
            onTap: () {
              Get.dialog(SendGiftDialog(
                roomId: 'global_room',
                occupiedSeatsCount: 0,
                targetUserId: u.id,
                targetUserName: u.displayName,
              ));
            },
          ),
          const SizedBox(width: 8),

          // Block
          _actionPill(
            icon: Icons.block_flipped,
            label: _isBlocked ? 'Unblock' : 'Block',
            color: Colors.redAccent,
            onTap: () {
              setState(() {
                _isBlocked = !_isBlocked;
              });
              Get.snackbar(
                _isBlocked ? 'Blocked 🚫' : 'Unblocked 🛡',
                _isBlocked
                    ? '${u.displayName} has been blocked.'
                    : '${u.displayName} has been unblocked.',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
          ),
          const SizedBox(width: 8),

          // Report
          _actionPill(
            icon: Icons.report_problem_outlined,
            label: 'Report',
            color: Colors.orangeAccent,
            onTap: () {
              Get.snackbar(
                'Reported ⚠️',
                'Report successfully filed against ${u.displayName}.',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _actionPill(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(User u) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(
            _formatNumber(u.followers),
            'Followers',
            onTap: () => _showFollowersFollowingBottomSheet(
              title: 'Followers',
              users: _getMockFollowers(),
            ),
          ),
          _statDivider(),
          _statItem(
            _formatNumber(u.following),
            'Following',
            onTap: () => _showFollowersFollowingBottomSheet(
              title: 'Following',
              users: _getMockFollowing(),
            ),
          ),
          _statDivider(),
          _statItem('1.5K', 'Rank'),
          _statDivider(),
          _statItem('14.2K', 'Gifts'),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, {VoidCallback? onTap}) {
    final item = Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: AppTheme.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: item,
      );
    }
    return item;
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white10,
    );
  }

  Widget _buildFamilyCard(User u) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Get.to(() => const CommunityDetailScreen(communityId: 'c3'));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF3B0764).withOpacity(0.6), // deep purple
              Colors.black.withOpacity(0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                      child: Text('🦋', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Web Dev Café',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              color: Color(0xFF38BDF8), size: 14),
                        ],
                      ),
                      Text(
                        'Role: Captain',
                        style: GoogleFonts.poppins(
                            color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white30, size: 14),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _communityBadgeDetail('Level 12', 'Community Level'),
                _communityBadgeDetail('4.8K', 'Members'),
                _communityBadgeDetail('Feb 2026', 'Join Date'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _communityBadgeDetail(String main, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          main,
          style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Text(
          desc,
          style:
              GoogleFonts.poppins(color: AppTheme.textTertiary, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildBadgesRow(User u) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Badges',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () => Get.to(() => const BadgesScreen()),
              child: Text(
                'View All >',
                style: GoogleFonts.poppins(
                    color: const Color(0xFF8B5CF6),
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: u.badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final badgeColors = [
                [const Color(0xFFFFC107), const Color(0xFFF59E0B)],
                [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
                [const Color(0xFF38BDF8), const Color(0xFF1D4ED8)],
                [const Color(0xFFF97316), const Color(0xFFEF4444)],
              ];
              final colors = badgeColors[i % badgeColors.length];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    colors[0].withOpacity(0.15),
                    colors[1].withOpacity(0.05),
                  ]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors[0].withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(['🏆', '💡', '🔥', '💎'][i % 4],
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(
                      u.badges[i],
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChipsSection() {
    final chips = [
      'AI Enthusiast',
      'Gamer',
      'Fast Learner',
      'Top Supporter',
      'Friendly'
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chips',
          style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips.map((c) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Text(
                c,
                style: GoogleFonts.poppins(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoSection(User u) {
    final infoItems = [
      {'label': 'Gender', 'val': u.id.hashCode % 2 == 0 ? 'Male' : 'Female'},
      {'label': 'Age', 'val': '24 years'},
      {'label': 'Country', 'val': 'India'},
      {'label': 'Language', 'val': 'English'},
      {'label': 'Profession', 'val': 'Content Creator'},
      {'label': 'Website', 'val': 'https://agorax.com/${u.username}'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Info',
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: infoItems.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Colors.white10, height: 12),
            itemBuilder: (context, i) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    infoItems[i]['label']!,
                    style: GoogleFonts.poppins(
                        color: AppTheme.textTertiary, fontSize: 12),
                  ),
                  Text(
                    infoItems[i]['val']!,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopFansSection() {
    final topFans = [
      {
        'name': 'Vikram',
        'img':
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100',
        'rank': 1
      },
      {
        'name': 'Priya',
        'img':
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100',
        'rank': 2
      },
    ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showContributorListBottomSheet(
        title: 'Top Supporters',
        items: _getSupportersData(),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top Supporters',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Row(
                        children: topFans.map((f) {
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage:
                                      NetworkImage(f['img'] as String),
                                ),
                                Positioned(
                                  bottom: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: [
                                        const Color(0xFFFFC107),
                                        const Color(0xFFC0C0C0),
                                      ][(f['rank'] as int) - 1],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${f['rank']}',
                                      style: const TextStyle(
                                          fontSize: 8,
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+42',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white30, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildContributionSection() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showContributorListBottomSheet(
        title: 'Contributions',
        items: _getContributorsData(),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Contribution Points',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  '4.5K XP',
                  style: GoogleFonts.poppins(
                      color: const Color(0xFFD946EF),
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _contributionRing(
                    label: 'ID XP', val: 0.6, color: const Color(0xFF8B5CF6)),
                _contributionRing(
                    label: 'Career XP',
                    val: 0.4,
                    color: const Color(0xFF38BDF8)),
                _contributionRing(
                    label: 'Room XP', val: 0.8, color: const Color(0xFFEC4899)),
                _contributionRing(
                    label: 'Community XP',
                    val: 0.5,
                    color: const Color(0xFF22C55E)),
              ],
            ),
            const Divider(color: Colors.white10, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Contributed to',
                  style: GoogleFonts.poppins(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  '8 Users & 2 Families',
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF38BDF8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Row(
                  children: [
                    'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100',
                    'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100',
                    'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=100',
                  ].map((url) {
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundImage: NetworkImage(url),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+8 more',
                    style: GoogleFonts.poppins(
                        color: AppTheme.textTertiary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _contributionRing(
      {required String label, required double val, required Color color}) {
    return Column(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: val,
                strokeWidth: 4,
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Text(
                '${(val * 100).toInt()}%',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
              color: AppTheme.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSocialsSection() {
    final socials = [
      {'name': 'Instagram', 'color': const Color(0xFFE1306C)},
      {'name': 'GitHub', 'color': const Color(0xFF333333)},
      {'name': 'LinkedIn', 'color': const Color(0xFF0077B5)},
      {'name': 'Twitter', 'color': const Color(0xFF1DA1F2)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Other Socials',
          style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: socials.map((s) {
            return Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Center(
                child: Icon(
                  s['name'] == 'Instagram'
                      ? Icons.camera_alt_rounded
                      : s['name'] == 'GitHub'
                          ? Icons.code_rounded
                          : s['name'] == 'LinkedIn'
                              ? Icons.work_outline_rounded
                              : Icons.chat_bubble_outline_rounded,
                  color: s['color'] as Color,
                  size: 22,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInitialsAvatar(User u) {
    return Container(
      color: AppTheme.primaryColor.withOpacity(0.2),
      child: Center(
        child: Text(
          u.displayName.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  void _showOptionsSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: const BoxDecoration(
          color: Color(0xFF18181B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.block_flipped, color: Colors.redAccent),
              title: Text('Block User',
                  style: GoogleFonts.poppins(
                      color: Colors.redAccent, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                Get.snackbar('Blocked 🚫',
                    '${widget.user.displayName} has been blocked.',
                    snackPosition: SnackPosition.BOTTOM);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_gmailerrorred_outlined,
                  color: Colors.orangeAccent),
              title: Text('Report Abuse',
                  style:
                      GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                Get.snackbar('Report Filed ⚠️',
                    'Thank you for reporting. We will investigate.',
                    snackPosition: SnackPosition.BOTTOM);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      '$label Copied 📋',
      '$label copied to clipboard.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF22C55E).withOpacity(0.9),
      colorText: Colors.white,
    );
  }

  // ─────────── Tabs ───────────

  Widget _buildPostsTab(User u) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _buildPostCard(u, _posts[i]),
    );
  }

  Widget _buildPostCard(User u, Post post) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CachedNetworkImage(
                  imageUrl: u.avatar!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
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
                          u.displayName,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (u.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              size: 14, color: Color(0xFF38BDF8)),
                        ],
                      ],
                    ),
                    Text(
                      '${_timeAgo(post.createdAt)} · @${u.username}',
                      style: GoogleFonts.poppins(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.content,
            style: GoogleFonts.poppins(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              GestureDetector(
                onTap: () => _toggleLike(post),
                behavior: HitTestBehavior.opaque,
                child: _postAction(
                  post.isLiked ? Icons.favorite : Icons.favorite_outline,
                  '${post.likes}',
                  post.isLiked ? AppTheme.errorColor : AppTheme.textTertiary,
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () => _commentPost(context, post),
                behavior: HitTestBehavior.opaque,
                child: _postAction(Icons.chat_bubble_outline,
                    '${post.comments}', AppTheme.textTertiary),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () => _sharePost(post),
                behavior: HitTestBehavior.opaque,
                child: _postAction(Icons.repeat_rounded, '${post.shares}',
                    AppTheme.textTertiary),
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
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          count,
          style: GoogleFonts.poppins(
              color: color, fontSize: 12, fontWeight: FontWeight.bold),
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
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: q.tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF8B5CF6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () => _toggleUpvoteQuestion(q),
                behavior: HitTestBehavior.opaque,
                child: _qStat(
                  Icons.arrow_upward_rounded,
                  '${q.upvotes}',
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
              const Spacer(),
              Text(
                _timeAgo(q.createdAt),
                style: GoogleFonts.poppins(
                    color: AppTheme.textTertiary, fontSize: 10),
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
        Text(label,
            style: GoogleFonts.poppins(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Get.to(() => CommunityDetailScreen(communityId: c['id'] ?? 'c1'));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withOpacity(0.2),
                    const Color(0xFFD946EF).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                  child: Text(c['icon'], style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c['name'],
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${c['members']} members',
                    style: GoogleFonts.poppins(
                        color: AppTheme.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                c['role'],
                style: GoogleFonts.poppins(
                  color: const Color(0xFF8B5CF6),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpotifyCard(User u) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1DB954).withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note_rounded,
              color: Color(0xFF1DB954), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Listening to Spotify',
                  style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  'Blinding Lights - The Weeknd',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.equalizer_rounded,
              color: Color(0xFF1DB954), size: 16),
        ],
      ),
    );
  }

  void _showFollowersFollowingBottomSheet({
    required String title,
    required List<User> users,
  }) {
    Get.bottomSheet(
      Container(
        height: Get.height * 0.65,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F12),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white54, size: 20),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10),
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final u = users[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(u.avatar ??
                            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150'),
                      ),
                      title: Row(
                        children: [
                          Text(
                            u.displayName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (u.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified,
                                color: Color(0xFF38BDF8), size: 14),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '@${u.username}',
                        style: GoogleFonts.poppins(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Lv.${u.level}',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF8B5CF6),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onTap: () {
                        Get.back(); // close bottom sheet
                        if (u.id == 'me' || u.id == 'uid_anurag_101') {
                          Get.to(() => const ProfileScreen());
                        } else {
                          Get.to(() => UserProfileScreen(user: u));
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showContributorListBottomSheet({
    required String title,
    required List<Map<String, dynamic>> items,
  }) {
    Get.bottomSheet(
      Container(
        height: Get.height * 0.65,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F12),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white54, size: 20),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10),
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final mockUser = User(
                    id: item['id'] ?? 'user_$index',
                    username: item['name']
                        .toString()
                        .toLowerCase()
                        .replaceAll(' ', '_'),
                    email: '${item['id']}@example.com',
                    displayName: item['name'],
                    avatar: item['avatar'],
                    interests: ['Flutter', 'AI'],
                    communities: ['AgoraX Stage'],
                    followers: 140,
                    following: 90,
                    isVerified: index == 0,
                    isPremium: index % 2 == 0,
                    reputation: 350,
                    sid: (100000 + index * 12345).toString(),
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(item['avatar']),
                      ),
                      title: Row(
                        children: [
                          Text(
                            item['name'],
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (index == 0) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified,
                                color: Color(0xFF38BDF8), size: 14),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        item['role'] ?? 'Supporter',
                        style: GoogleFonts.poppins(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item['amount'] ?? '',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFFC107),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Rank #${index + 1}',
                            style: GoogleFonts.poppins(
                              color: Colors.white30,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Get.back(); // close bottom sheet
                        if (mockUser.id == 'me' ||
                            mockUser.id == 'uid_anurag_101') {
                          Get.to(() => const ProfileScreen());
                        } else {
                          Get.to(() => UserProfileScreen(user: mockUser));
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  List<User> _getMockFollowers() {
    return [
      User(
        id: 'user_priya_1',
        username: 'priya_sharma',
        email: 'priya@example.com',
        displayName: 'Priya Sharma',
        avatar:
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
        interests: ['Flutter', 'Design'],
        communities: ['AgoraX Design Club'],
        followers: 120,
        following: 80,
        isVerified: true,
        isPremium: true,
        reputation: 150,
        sid: '109283',
        level: 15,
        xp: 200,
        totalXp: 1000,
      ),
      User(
        id: 'user_vikram_2',
        username: 'vikram_singh',
        email: 'vikram@example.com',
        displayName: 'Vikram Singh',
        avatar:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        interests: ['Kotlin', 'Backend'],
        communities: ['AgoraX Backend Devs'],
        followers: 320,
        following: 110,
        isVerified: false,
        isPremium: false,
        reputation: 90,
        sid: '182739',
        level: 8,
        xp: 450,
        totalXp: 1000,
      ),
    ];
  }

  List<User> _getMockFollowing() {
    return [
      User(
        id: 'user_rahul_3',
        username: 'rahul_dev',
        email: 'rahul@example.com',
        displayName: 'Rahul Dev',
        avatar:
            'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=150',
        interests: ['Dart', 'AI'],
        communities: ['AgoraX Flutteristas'],
        followers: 512,
        following: 240,
        isVerified: true,
        isPremium: false,
        reputation: 400,
        sid: '192837',
        level: 22,
        xp: 800,
        totalXp: 1000,
      ),
    ];
  }

  List<Map<String, dynamic>> _getSupportersData() {
    return [
      {
        'id': 'user_vikram_2',
        'name': 'Vikram Singh',
        'avatar':
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        'role': 'Top Supporter',
        'amount': '5.2K XP',
      },
      {
        'id': 'user_priya_1',
        'name': 'Priya Sharma',
        'avatar':
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
        'role': 'VIP Supporter',
        'amount': '3.1K XP',
      },
    ];
  }

  List<Map<String, dynamic>> _getContributorsData() {
    return [
      {
        'id': 'user_priya_1',
        'name': 'Priya Sharma',
        'avatar':
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
        'role': 'Flutter India Community',
        'amount': '4.2K XP',
      },
      {
        'id': 'user_vikram_2',
        'name': 'Vikram Singh',
        'avatar':
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        'role': 'AI & ML Hub',
        'amount': '2.8K XP',
      },
    ];
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(
        color: const Color(0xFF09090B),
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
