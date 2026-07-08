import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../models/question_model.dart';
import '../settings/settings_screen.dart';
import '../../widgets/post_attachments_widget.dart';

import '../../services/store_controller.dart';
import '../../services/vip_controller.dart';
import '../../services/novel_controller.dart';
import '../../services/customization_controller.dart';
import '../../services/study_category_controller.dart';
import '../../services/career_progression_controller.dart';
import '../../services/premium_identity_controller.dart';
import '../../services/study_vault_controller.dart';
import '../store/store_home_screen.dart';
import '../study_vault/study_vault_home_screen.dart';
import '../study_vault/my_library_screen.dart';
import '../study_vault/seller_dashboard_screen.dart';
import '../study_vault/admin_vault_panel_screen.dart';
import '../study_vault/membership_center_screen.dart';
import '../vip/vip_purchase_screen.dart';
import '../novel/novel_purchase_screen.dart';
import '../career/career_hub_screen.dart';
import 'profile_customization_screen.dart';
import 'daily_task_screen.dart';
import 'badges_screen.dart';
import 'account_center_screen.dart';
import 'connections_screen.dart';
import '../../widgets/custom_avatar_frame.dart';
import '../../widgets/premium_name_widget.dart';
import '../../widgets/vip_badge_widget.dart';
import '../../widgets/novel_badge_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final StoreController _storeCtrl = Get.find<StoreController>();
  final VipController _vipCtrl = Get.find<VipController>();
  final NovelController _novelCtrl = Get.find<NovelController>();
  final CustomizationController _custCtrl = Get.find<CustomizationController>();
  final StudyCategoryController _studyCtrl = Get.find<StudyCategoryController>();
  final CareerProgressionController _careerCtrl = Get.find<CareerProgressionController>();

  late TabController _tabController;
  late AnimationController _glowController;
  late AnimationController _rotateController;

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
    avatar:
        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200',
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
        [
          'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4'
        ],
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
    {
      'name': 'Flutter India',
      'members': '12.4K',
      'icon': '🦋',
      'role': 'Admin'
    },
    {'name': 'AI & ML Hub', 'members': '8.2K', 'icon': '🤖', 'role': 'Member'},
    {'name': 'DSA Grind', 'members': '5.6K', 'icon': '🧠', 'role': 'Moderator'},
    {
      'name': 'Open Source Dev',
      'members': '3.1K',
      'icon': '🌍',
      'role': 'Member'
    },
  ];

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    _glowController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  Color get _levelColor {
    final level = _user.level;
    if (level <= 5) return const Color(0xFF60A5FA);
    if (level <= 10) return AppTheme.accentColor;
    if (level <= 20) return AppTheme.primaryColor;
    return const Color(0xFFFBBF24);
  }

  Future<void> _pickAndCropAvatar(
      BuildContext context, ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image == null) return;

    // Show Custom Crop & Preview Dialog
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF13131A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PREVIEW & CROP AVATAR',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              // Crop Area with Circular Overlay
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(File(image.path)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Semi-transparent circular crop guide overlay
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFF8B5CF6), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                        )
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Adjust your photo inside the circle',
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('Cancel',
                        style: GoogleFonts.poppins(color: Colors.white38)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // Save custom avatar path to customization controller
                      _custCtrl.customAvatarPath.value = image.path;
                      await _custCtrl.equipItem('Avatar',
                          'Default'); // ensure default avatar is selected
                      Get.back();
                      Get.snackbar(
                        'Avatar Cropped! ✂️',
                        'Preview updated. Tap "Save Changes" to apply.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: const Color(0xFF10B981),
                        colorText: Colors.white,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6)),
                    child: Text('Crop & Save',
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
        post.isBookmarked ? 'Bookmark Removed 📂' : 'Saved to Bookmarks 📂',
        post.isBookmarked
            ? 'Post removed from your bookmarks.'
            : 'Post added to your bookmarks.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1F1F2E),
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
            Clipboard.setData(
                ClipboardData(text: 'https://agorax.com/profile/${_user.sid}'));
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
            // Cover Photo Banner with purple radial-like gradient & circular pattern overlay
            Container(
              height: 180,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF8B5CF6),
                    Color(0xFF13131A),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -50,
                    left: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.03),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.02),
                      ),
                    ),
                  ),
                ],
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt_outlined,
                          size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Edit Cover',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Avatar and Action Buttons positioned cleanly overlapping
            Positioned(
              left: 20,
              bottom: -45,
              right: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: OutlinedButton.icon(
                                  onPressed: () => _showEditProfileSheet(context),
                                  icon: const Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                                  label: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: Colors.white.withOpacity(0.06),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: OutlinedButton.icon(
                                  onPressed: () => Get.to(() => const ProfileCustomizationScreen()),
                                  icon: const Icon(Icons.brush_outlined, size: 14, color: Color(0xFFFFD700)),
                                  label: const Text('Design', style: TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFFFD700)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: const Color(0xFFFFD700).withOpacity(0.08),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
              // Display Name section (Premium text glow and badges)
              Row(
                children: [
                  Flexible(
                    child: PremiumNameWidget(
                      name: _user.displayName,
                      userId: 'me',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFFD700), // Gold name glow color
                        shadows: [
                          Shadow(
                            color: const Color(0xFFFFD700).withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_user.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded,
                        color: Color(0xFF60A5FA), size: 20),
                  ],
                  const SizedBox(width: 6),
                  const Text(
                    '♂',
                    style: TextStyle(
                      color: Color(0xFF00F0FF), // Cyan gender symbol
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Four status badges row (VIP, Lvl, Career, Role)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Obx(() {
                    final vipLvl = _vipCtrl.vipLevel.value;
                    if (vipLvl > 0) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 10, color: Color(0xFF6B7280)),
                            const SizedBox(width: 2),
                            Text(
                              'VIP $vipLvl',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF4B5563),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox();
                  }),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Lvl ${_user.level}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF78350F).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B), width: 1),
                    ),
                    child: Text(
                      'Career 1',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFF59E0B),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF581C87).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC084FC), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.build_circle_outlined, size: 10, color: Color(0xFFC084FC)),
                        const SizedBox(width: 2),
                        Text(
                          'Developer',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFC084FC),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Unique ID Display
              Row(
                children: [
                  Text(
                    'ID: ${_user.sid}',
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _copyToClipboard(_user.sid, 'AgoraX ID'),
                    child: const Icon(
                      Icons.copy_rounded,
                      color: AppTheme.textTertiary,
                      size: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Reputation Badges row
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: PremiumIdentityController.getIdentity('me', _user.displayName)
                    .buildBadgeRow(context, fontSize: 9.5),
              ),

              // Dynamic Tag Row containing levels
              Obx(() {
                return _buildTagRow();
              }),
              const SizedBox(height: 12),

              // Bio Box with Gradient Border matching the mockup style
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.all(1.5), // forms the border stroke
                  decoration: BoxDecoration(
                    color: const Color(0xFF13131A),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _user.bio ?? 'No bio written yet.',
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
                            'https://agorax.com/${_user.username}',
                            style: GoogleFonts.poppins(
                                color: const Color(0xFF38BDF8),
                                fontSize: 12,
                                decoration: TextDecoration.underline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Statistics Horizontal Card (Followers, Following, Rank, Gifts)
              _buildStatisticsCard(),
              
              // Daily Task Card
              _buildDailyTaskCard(),
              
              // Career Task Card
              _buildCareerTaskCard(),
              
              // VIP Management Card
              _buildVipManagementCard(),
              
              // Store equipped items card
              _buildStoreCustomizationCard(),
              
               // Navigation Hub grid
              _buildNavigationHub(),

              // Study Vault Deck (Library & Dashboards)
              _buildStudyVaultDeck(),

              // Wallet Statistics Bar matching the mockup
              _buildWalletStatisticsBar(),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    return Obx(() {
      final avatarUrl = _custCtrl.getAvatarUrl(_custCtrl.activeAvatar.value, _user.avatar ?? '');
      final isWebUrl = avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://');
      
      final vipLvl = _vipCtrl.vipLevel.value;
      final novelLvl = _novelCtrl.novelLevel.value;
      final hasGlow = vipLvl > 0 || novelLvl > 0;
      
      Color glowColor = const Color(0xFF8B5CF6); // default purple
      if (novelLvl > 0) {
        if (novelLvl >= 7) glowColor = const Color(0xFFFFD700); // gold
        else if (novelLvl >= 5) glowColor = const Color(0xFFFF4500); // orange-red
        else glowColor = const Color(0xFFD946EF); // magenta
      } else if (vipLvl > 0) {
        if (vipLvl >= 7) glowColor = const Color(0xFFFFD700);
        else if (vipLvl >= 5) glowColor = const Color(0xFF06B6D4); // cyan
        else glowColor = const Color(0xFF6366F1); // indigo
      }

      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Avatar border glow if VIP/Novel
          if (hasGlow)
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withOpacity(0.3 + (_glowController.value * 0.45)),
                        blurRadius: 10 + (_glowController.value * 12),
                        spreadRadius: 2 + (_glowController.value * 4),
                      ),
                    ],
                  ),
                );
              },
            ),
          
          CustomAvatarFrame(
            userId: 'me',
            username: _user.displayName,
            size: 90,
            defaultNovelLevel: novelLvl,
            defaultVipLevel: vipLvl,
            child: SizedBox(
              width: 90,
              height: 90,
              child: avatarUrl.isNotEmpty
                  ? (isWebUrl
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: AppTheme.bgLight),
                          errorWidget: (context, url, error) => _buildInitialsAvatar(),
                        )
                      : Image.file(
                          File(avatarUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (c, o, s) => _buildInitialsAvatar(),
                        ))
                  : _buildInitialsAvatar(),
            ),
          ),
          
          // Camera overlay for editing
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _showEditAvatarSheet(context),
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFF8B5CF6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
              ),
            ),
          ),

          // Level badge at bottom center (Matching Visitor profile design)
          Positioned(
            bottom: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF09090B), width: 1.5),
              ),
              child: Text(
                'Lv.${_user.level}',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildStatisticsCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatIndicator('1.4K', 'Followers', () {
            _navigateToConnections(1);
          }),
          _buildVerticalDivider(),
          _buildStatIndicator('480', 'Following', () {
            _navigateToConnections(0);
          }),
          _buildVerticalDivider(),
          _buildStatIndicator('1.5K', 'Rank', () {
            Get.to(() => const BadgesScreen());
          }),
          _buildVerticalDivider(),
          _buildStatIndicator('14.2K', 'Gifts', () {
            Get.to(() => const AccountCenterScreen());
          }),
        ],
      ),
    );
  }

  Widget _buildStatIndicator(String value, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withOpacity(0.06),
    );
  }

  void _navigateToConnections(int initialTabIndex) {
    Get.to(() => ConnectionsScreen(initialTabIndex: initialTabIndex));
  }

  Widget _buildWalletStatisticsBar() {
    return Obx(() {
      final goldCoins = _storeCtrl.coinsBalance.value;
      final silverCoins = _studyCtrl.silverCoins.value;

      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Text(
              'Wallet Statistics',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                const SizedBox(width: 4),
                Text(
                  'Gold: ',
                  style: GoogleFonts.poppins(color: AppTheme.textTertiary, fontSize: 12),
                ),
                Text(
                  '${goldCoins.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFFD700),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(Icons.monetization_on, color: Color(0xFF94A3B8), size: 14),
                const SizedBox(width: 4),
                Text(
                  'Silver: ',
                  style: GoogleFonts.poppins(color: AppTheme.textTertiary, fontSize: 12),
                ),
                Text(
                  '${silverCoins.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTagRow() {
    List<Widget> tags = [];

    final isVip = _vipCtrl.vipLevel.value > 0;
    final vipLvl = _vipCtrl.vipLevel.value;
    final isNovel = _novelCtrl.novelLevel.value > 0;
    final novelLvl = _novelCtrl.novelLevel.value;

    // 1. VIP Tag
    if (isVip) {
      tags.add(_buildTagItem(
        label: 'VIP $vipLvl',
        icon: '👑',
        bgColor: const Color(0xFFFFC107).withOpacity(0.12),
        borderColor: const Color(0xFFFFC107).withOpacity(0.3),
        textColor: const Color(0xFFFFC107),
      ));
    }

    // 2. Novel Tag
    if (isNovel) {
      tags.add(_buildTagItem(
        label: 'Novel $novelLvl',
        icon: '📖',
        bgColor: const Color(0xFFF97316).withOpacity(0.12),
        borderColor: const Color(0xFFF97316).withOpacity(0.3),
        textColor: const Color(0xFFF97316),
      ));
    }

    // 3. ID Level Tag
    tags.add(_buildTagItem(
      label: 'ID Lv.${_careerCtrl.idLevel.value}',
      icon: '🌱',
      bgColor: const Color(0xFF8B5CF6).withOpacity(0.12),
      borderColor: const Color(0xFF8B5CF6).withOpacity(0.3),
      textColor: const Color(0xFFA855F7),
    ));

    // 4. Career Level Tag
    final String activeCatName = _studyCtrl.selectedCategory.value ?? 'General Learning';
    final int studyLvl = _studyCtrl.userLevel.value;
    tags.add(_buildTagItem(
      label: '$activeCatName Lv.$studyLvl',
      icon: '🎓',
      bgColor: const Color(0xFF38BDF8).withOpacity(0.12),
      borderColor: const Color(0xFF38BDF8).withOpacity(0.3),
      textColor: const Color(0xFF38BDF8),
    ));

    // 5. Community Tag Bracket
    Color bracketColor;
    String bracketName;
    final lvl = _careerCtrl.idLevel.value;
    if (lvl >= 55) {
      bracketColor = const Color(0xFF10B981);
      bracketName = 'Radiant';
    } else if (lvl >= 50) {
      bracketColor = const Color(0xFFFFD700);
      bracketName = 'Gold';
    } else if (lvl >= 40) {
      bracketColor = const Color(0xFFA855F7);
      bracketName = 'Purple';
    } else if (lvl >= 30) {
      bracketColor = const Color(0xFF3B82F6);
      bracketName = 'Blue';
    } else if (lvl >= 20) {
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

  Widget _buildPremiumStatsGrid() {
    return Obx(() {
      final goldCoins = _storeCtrl.coinsBalance.value;
      final silverCoins = _storeCtrl.silverCoinsBalance.value;
      final idLevelVal = _careerCtrl.idLevel.value;
      final idXpVal = _careerCtrl.idXp.value;
      final studyLevelVal = _studyCtrl.userLevel.value;
      final studyXpVal = _studyCtrl.userXp.value;
      final streak = _studyCtrl.learningStreak.value;
      
      final statsList = [
        {'label': 'ID Level', 'value': 'Lv.$idLevelVal', 'sub': '$idXpVal XP', 'emoji': '🌱'},
        {'label': 'Study Level', 'value': 'Lv.$studyLevelVal', 'sub': '$studyXpVal XP', 'emoji': '🎓'},
        {'label': 'Streak', 'value': '$streak Days', 'sub': '🔥 Active', 'emoji': '⚡'},
        {'label': 'Gold Coins', 'value': '$goldCoins', 'sub': '🪙 Balance', 'emoji': '🪙'},
        {'label': 'Silver Coins', 'value': '$silverCoins', 'sub': '🥈 Balance', 'emoji': '🥈'},
        {'label': 'Posts', 'value': '${_user.totalPosts}', 'sub': 'Published', 'emoji': '📝'},
        {'label': 'Questions', 'value': '${_user.totalQuestions}', 'sub': 'Asked', 'emoji': '❓'},
        {'label': 'Answers', 'value': '14', 'sub': 'Contributed', 'emoji': '💬'},
        {'label': 'Likes', 'value': '1.4K', 'sub': 'Received', 'emoji': '❤️'},
      ];

      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.01),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PROFILE STATISTICS',
              style: GoogleFonts.outfit(
                color: Colors.white30,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.3,
              ),
              itemCount: statsList.length,
              itemBuilder: (context, i) {
                final item = statsList[i];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13131A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.03)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(item['emoji']!, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item['label']!,
                              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['value']!,
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item['sub']!,
                        style: GoogleFonts.poppins(color: AppTheme.textTertiary, fontSize: 8),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildDailyTaskCard() {
    return Obx(() {
      final todayPack = _studyCtrl.getTodayLearningDay();
      final isVideoWatched = _studyCtrl.videoWatchedToday.value;
      final isQuizCompleted = _studyCtrl.quizCompletedToday.value;
      final allCompleted = isVideoWatched && isQuizCompleted;
      final isClaimed = _studyCtrl.xpEarnedToday.value > 0;

      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFD700).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Progress Task',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reward: +50 XP +15 Gold Coins',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFD700).withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: (allCompleted && !isClaimed) 
                  ? () {
                      _storeCtrl.coinsBalance.value += todayPack.coinReward;
                      _studyCtrl.xpEarnedToday.value += todayPack.xpReward;
                      Get.snackbar(
                        'Daily Task Claimed! 🏆',
                        'Earned +${todayPack.xpReward} XP & +${todayPack.coinReward} Coins!',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: const Color(0xFFFFD700),
                        colorText: Colors.black,
                      );
                    }
                  : () {
                      Get.to(() => const DailyTaskScreen());
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isClaimed
                        ? [Colors.grey.shade800, Colors.grey.shade900]
                        : (allCompleted 
                            ? [const Color(0xFFFFD700), const Color(0xFFFBBF24)]
                            : [const Color(0xFFFFD700).withOpacity(0.5), const Color(0xFFFBBF24).withOpacity(0.5)]),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isClaimed 
                      ? 'Claimed ✓' 
                      : (allCompleted ? 'Claim Rewards' : 'Go to Tasks'),
                  style: GoogleFonts.poppins(
                    color: isClaimed ? Colors.white54 : Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCareerTaskCard() {
    return Obx(() {
      final activeCat = _studyCtrl.selectedCategory.value ?? 'Design';
      final progress = 0.45; // 45% complete matching mockup

      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  activeCat.endsWith('Path') ? activeCat : '$activeCat Path',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% Complete',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildVipManagementCard() {
    return Obx(() {
      final vipLvl = _vipCtrl.vipLevel.value;
      final nextVip = vipLvl + 1;
      final progress = 0.60; // 60% progress matching mockup

      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFD700).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'VIP Club',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Flexible(
                  child: Text(
                    'Progress to VIP $nextVip',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFBBF24)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _vipBenefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFFFFD700), size: 12),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreCustomizationCard() {
    return Obx(() {
      final activeFrame = _custCtrl.activeFrame.value;
      final activeEffect = _custCtrl.activeAvatarEffect.value;
      final activeTheme = _custCtrl.activeTheme.value;
      final activeBubble = _custCtrl.activeBubble.value;

      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text('🛒', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'EQUIPPED DECORATIONS',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 1.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Get.to(() => const StoreHomeScreen()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD946EF).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Store ➔',
                      style: TextStyle(
                        color: Color(0xFFD946EF),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            _storeCosmeticItem('Avatar Frame', activeFrame, () {
              Get.to(() => const ProfileCustomizationScreen());
            }),
            const Divider(color: Colors.white10, height: 12),
            _storeCosmeticItem('Entry Effect', activeEffect, () {
              Get.to(() => const ProfileCustomizationScreen());
            }),
            const Divider(color: Colors.white10, height: 12),
            _storeCosmeticItem('Avatar Background', activeTheme, () {
              Get.to(() => const ProfileCustomizationScreen());
            }),
            const Divider(color: Colors.white10, height: 12),
            _storeCosmeticItem('Chat Bubble', activeBubble, () {
              Get.to(() => const ProfileCustomizationScreen());
            }),
            
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.to(() => const ProfileCustomizationScreen()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD946EF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Equip / Customize Profile', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _storeCosmeticItem(String type, String equippedName, VoidCallback onAction) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(type, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
            const SizedBox(height: 2),
            Text(
              equippedName,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          child: const Text('Change', style: TextStyle(color: Color(0xFFD946EF), fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildNavigationHub() {
    final navItems = [
      {
        'title': 'Daily Tasks',
        'sub': 'View learning challenges',
        'icon': Icons.task_rounded,
        'color': const Color(0xFF10B981),
        'target': () => const DailyTaskScreen(),
      },
      {
        'title': 'Store Customization',
        'sub': 'Equip frames & items',
        'icon': Icons.brush_rounded,
        'color': const Color(0xFFD946EF),
        'target': () => const ProfileCustomizationScreen(),
      },
      {
        'title': 'Badges & Medals',
        'sub': 'View unlocked achievements',
        'icon': Icons.workspace_premium_rounded,
        'color': const Color(0xFFFFD700),
        'target': () => const BadgesScreen(),
      },
      {
        'title': 'Account & Wallet',
        'sub': 'Manage coins & transactions',
        'icon': Icons.wallet_rounded,
        'color': const Color(0xFF8B5CF6),
        'target': () => const AccountCenterScreen(),
      },
    ];

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 10.0),
            child: Text(
              'PROFILE NAVIGATION',
              style: GoogleFonts.outfit(
                color: Colors.white30,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.2,
            ),
            itemCount: navItems.length,
            itemBuilder: (context, i) {
              final item = navItems[i];
              return InkWell(
                onTap: () => Get.to(item['target'] as Widget Function()),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13131A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.03)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (item['color'] as Color).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item['title'] as String,
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              item['sub'] as String,
                              style: GoogleFonts.poppins(color: AppTheme.textTertiary, fontSize: 8),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudyVaultDeck() {
    final vaultItems = [
      {
        'title': 'Study Vault',
        'sub': 'Explore Bookshelf',
        'icon': Icons.auto_stories,
        'color': const Color(0xFFFFD700),
        'target': () => const StudyVaultHomeScreen(),
      },
      {
        'title': 'My Library',
        'sub': 'Purchased & VIP Books',
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF10B981),
        'target': () => const MyLibraryScreen(),
      },
      {
        'title': 'Seller Dashboard',
        'sub': 'Manage uploads & earnings',
        'icon': Icons.dashboard_customize_rounded,
        'color': const Color(0xFF3B82F6),
        'target': () => const SellerDashboardScreen(),
      },
      {
        'title': 'Admin Panel',
        'sub': 'Approvals & Payouts',
        'icon': Icons.admin_panel_settings_rounded,
        'color': const Color(0xFFEC4899),
        'target': () => const AdminVaultPanelScreen(),
      },
      {
        'title': 'Membership Center',
        'sub': 'Upgrade VIP & Novel',
        'icon': Icons.card_membership_rounded,
        'color': const Color(0xFF8B5CF6),
        'target': () => const MembershipCenterScreen(),
      },
    ];

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 10.0),
            child: Text(
              'STUDY VAULT DECK',
              style: GoogleFonts.outfit(
                color: Colors.white30,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.2,
            ),
            itemCount: vaultItems.length,
            itemBuilder: (context, i) {
              final item = vaultItems[i];
              return InkWell(
                onTap: () => Get.to(item['target'] as Widget Function()),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13131A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.03)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (item['color'] as Color).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item['title'] as String,
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              item['sub'] as String,
                              style: GoogleFonts.poppins(color: AppTheme.textTertiary, fontSize: 8),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
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
                        errorWidget: (context, url, error) =>
                            _buildAuthorInitialsAvatar(),
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
              const Spacer(),
              GestureDetector(
                onTap: () => _toggleBookmark(post),
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  post.isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                  size: 18,
                  color: post.isBookmarked
                      ? AppTheme.primaryColor
                      : AppTheme.textTertiary,
                ),
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
              const SizedBox(width: 16),
              _qStat(Icons.visibility_outlined, '${q.views}',
                  AppTheme.textTertiary),
              const Spacer(),
              Text(
                _timeAgo(q.createdAt),
                style:
                    const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
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
            child: Center(
                child: Text(c['icon'], style: const TextStyle(fontSize: 26))),
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
            Center(
              child: Stack(
                children: [
                  Obx(() {
                    final avatarUrl = _custCtrl.getAvatarUrl(
                        _custCtrl.activeAvatar.value, _user.avatar ?? '');
                    final bool isWebUrl = avatarUrl.startsWith('http://') ||
                        avatarUrl.startsWith('https://');
                    return Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF8B5CF6), width: 2),
                        image: DecorationImage(
                          image: avatarUrl.isNotEmpty
                              ? (isWebUrl
                                  ? NetworkImage(avatarUrl) as ImageProvider
                                  : FileImage(File(avatarUrl)) as ImageProvider)
                              : const AssetImage('assets/images/logo.png')
                                  as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        _showEditAvatarSheet(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF8B5CF6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
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
              leading: const Icon(Icons.photo_camera_rounded,
                  color: AppTheme.primaryColor),
              title: const Text('Take Photo',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickAndCropAvatar(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppTheme.primaryColor),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickAndCropAvatar(context, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.errorColor),
              title: const Text('Remove Photo',
                  style: TextStyle(color: AppTheme.errorColor)),
              onTap: () {
                Navigator.pop(context);
                _custCtrl.customAvatarPath.value = '';
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
