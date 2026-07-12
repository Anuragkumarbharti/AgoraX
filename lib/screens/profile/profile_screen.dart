import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
import '../../services/career_daily_controller.dart';
import '../../services/id_daily_controller.dart';
import '../../services/premium_identity_controller.dart';
import '../../services/study_vault_controller.dart';
import '../../services/user_profile_cache_manager.dart';
import '../../services/user_progress_sync_service.dart';
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
import 'edit_profile_screen.dart';
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

  late User _user;
  bool _isLoadingProfile = true;
  String? _errorMessage;
  bool _isAdmin = false;

  final List<Post> _posts = [];
  final List<Question> _questions = [];
  final List<Map<String, dynamic>> _communities = [];

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
    UserProfileCacheManager.addListener(_onProfileCacheUpdated);
    _loadUserProfile();
  }

  void _onProfileCacheUpdated() {
    final cachedMe = UserProfileCacheManager.getCachedUser(UserProfileCacheManager.currentUserId);
    if (cachedMe != null && mounted) {
      setState(() {
        _user = cachedMe;
        _custCtrl.activeFrame.value = cachedMe.avatarFrame ?? 'Normal';
        _vipCtrl.vipLevel.value = cachedMe.vipLevel;
        _novelCtrl.novelLevel.value = cachedMe.novelLevel;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoadingProfile = true;
      _errorMessage = null;
    });
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoadingProfile = false;
          _errorMessage = 'User is not logged in';
        });
        return;
      }
      final currentUserId = UserProfileCacheManager.currentUserId;
      
      final profileData = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', currentUserId)
          .maybeSingle();
          
      final walletData = await Supabase.instance.client
          .from('wallets')
          .select()
          .eq('id', currentUserId)
          .maybeSingle();

      dynamic adminData;
      try {
        adminData = await Supabase.instance.client
            .from('admins')
            .select()
            .eq('id', currentUser.id)
            .maybeSingle();
      } catch (e) {
        debugPrint('Warning: admins table query failed. Check RLS policy infinite recursion: $e');
        adminData = null;
      }

      if (profileData == null) {
        setState(() {
          _isLoadingProfile = false;
          _errorMessage = 'Profile row not found in backend database.';
        });
        return;
      }

      final Map<String, dynamic> mergedData = Map<String, dynamic>.from(profileData);
      mergedData['email'] = currentUser.email ?? '';
      mergedData['silverCoins'] = walletData != null ? (walletData['coins_balance'] ?? 0) : 0;

      // Fetch only this user's posts
      List<Post> fetchedPosts = [];
      try {
        final postsResponse = await Supabase.instance.client
            .from('posts')
            .select('*, profiles(username, avatar_url)')
            .eq('user_id', currentUserId)
            .order('created_at', ascending: false);

        if (postsResponse != null) {
          final List<dynamic> list = postsResponse as List<dynamic>;
          fetchedPosts = list.map((item) => Post.fromJson(item as Map<String, dynamic>)).toList();
        }
      } catch (postError) {
        debugPrint('Error fetching posts for user: $postError');
      }

      setState(() {
        _isAdmin = adminData != null;
        _user = User.fromJson(mergedData);

        _custCtrl.activeFrame.value = profileData['avatar_frame'] ?? 'Normal';
        _vipCtrl.vipLevel.value = profileData['vip_level'] ?? 0;
        _novelCtrl.novelLevel.value = profileData['novel_level'] ?? 0;
        
        _posts.clear();
        _posts.addAll(fetchedPosts);
        _questions.clear();
        _communities.clear();
        
        _isLoadingProfile = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
        _errorMessage = 'Failed to load profile: $e';
      });
    }
  }

  @override
  void dispose() {
    UserProfileCacheManager.removeListener(_onProfileCacheUpdated);
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
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: Text('Cancel',
                          style: GoogleFonts.poppins(color: Colors.white38)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Close crop dialog
                        Get.back();

                        // Show loading indicator
                        Get.dialog(
                          const Center(
                            child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                          ),
                          barrierDismissible: false,
                        );

                        try {
                          final userId = UserProfileCacheManager.currentUserId;
                          final file = File(image.path);
                          final path = '$userId/avatar.png';

                          debugPrint('[Avatar Upload] Uploading to: avatars/$path');
                          await Supabase.instance.client.storage.from('avatars').upload(
                            path,
                            file,
                            fileOptions: const FileOptions(upsert: true),
                          );
                          final publicUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(path);
                          debugPrint('[Avatar Upload] Upload Success. URL: $publicUrl');

                          // Update database
                          await Supabase.instance.client
                              .from('profiles')
                              .update({'avatar_url': publicUrl})
                              .eq('id', userId);

                          // Invalidate local cache and sync
                          UserProfileCacheManager.invalidateCache(userId);
                          await UserProgressSyncService.syncFromSupabase();

                          // Reload profile data
                          await _loadUserProfile();

                          // Close loading indicator
                          Get.back();

                          Get.snackbar(
                            'Avatar Updated! ✂️',
                            'Your profile photo was successfully saved and updated.',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: const Color(0xFF10B981),
                            colorText: Colors.white,
                          );
                        } catch (e) {
                          // Close loading indicator
                          Get.back();
                          Get.snackbar('Upload Failed ⚠️', 'Failed to upload image: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6)),
                      child: Text('Crop & Save',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
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
    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppTheme.errorColor, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadUserProfile,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                ClipboardData(text: 'https://creania.com/profile/${_user.sid}'));
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
            // Cover Photo Banner with dynamic background cover
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: (_user.coverPhoto == null || _user.coverPhoto!.isEmpty)
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF8B5CF6),
                          Color(0xFF13131A),
                        ],
                      )
                    : null,
                image: (_user.coverPhoto != null && _user.coverPhoto!.isNotEmpty)
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(_user.coverPhoto!),
                        fit: BoxFit.cover,
                      )
                    : null,
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
                onTap: () async {
                  final picker = ImagePicker();
                  final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                  if (pickedFile == null) return;

                  // Show loading indicator
                  Get.dialog(
                    const Center(
                      child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    ),
                    barrierDismissible: false,
                  );

                  try {
                    final userId = UserProfileCacheManager.currentUserId;
                    final file = File(pickedFile.path);
                    final path = '$userId/banner.png';

                    debugPrint('[Cover Upload] Uploading to: banners/$path');
                    await Supabase.instance.client.storage.from('banners').upload(
                      path,
                      file,
                      fileOptions: const FileOptions(upsert: true),
                    );
                    final publicUrl = Supabase.instance.client.storage.from('banners').getPublicUrl(path);
                    debugPrint('[Cover Upload] Upload Success. URL: $publicUrl');

                    // Update database
                    await Supabase.instance.client
                        .from('profiles')
                        .update({'cover_photo': publicUrl})
                        .eq('id', userId);

                    // Invalidate local cache and sync
                    UserProfileCacheManager.invalidateCache(userId);
                    await UserProgressSyncService.syncFromSupabase();

                    // Reload profile data
                    await _loadUserProfile();

                    // Close loading indicator
                    Get.back();

                    Get.snackbar(
                      'Cover Updated! 🖼️',
                      'Your cover banner was successfully updated.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: const Color(0xFF10B981),
                      colorText: Colors.white,
                    );
                  } catch (e) {
                    // Close loading indicator
                    Get.back();
                    Get.snackbar('Upload Failed ⚠️', 'Failed to upload cover: $e');
                  }
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
                    onTap: () => _copyToClipboard(_user.sid, 'Creania ID'),
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
                child: Obx(() {
                  return PremiumIdentityController.getIdentity(
                    _user.id,
                    _user.displayName,
                    vipLevel: _vipCtrl.vipLevel.value,
                    novelLevel: _novelCtrl.novelLevel.value,
                    idLevel: _user.level,
                    careerLevel: _careerCtrl.careerLevel.value,
                    badgesList: _user.badges,
                  ).buildBadgeRow(context, fontSize: 9.5);
                }),
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
                            'https://creania.com/${_user.username}',
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
              // About Me section displaying additional profile metadata and socials
              _buildAboutCard(),

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
            userId: _user.id,
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

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }

  Widget _buildStatisticsCard() {
    final List<Widget> items = [];

    if (_user.followers > 0) {
      items.add(
        _buildStatIndicator(_formatCount(_user.followers), 'Followers', () {
          _navigateToConnections(1);
        }),
      );
    }

    if (_user.following > 0) {
      if (items.isNotEmpty) items.add(_buildVerticalDivider());
      items.add(
        _buildStatIndicator(_formatCount(_user.following), 'Following', () {
          _navigateToConnections(0);
        }),
      );
    }

    // Rank (if reputation > 0)
    if (_user.reputation > 0) {
      if (items.isNotEmpty) items.add(_buildVerticalDivider());
      items.add(
        _buildStatIndicator('${_formatCount(_user.reputation)}', 'Rank', () {
          Get.to(() => const BadgesScreen());
        }),
      );
    }

    // Gifts (if diamonds > 0)
    if (_user.diamonds > 0) {
      if (items.isNotEmpty) items.add(_buildVerticalDivider());
      items.add(
        _buildStatIndicator('${_formatCount(_user.diamonds)}', 'Gifts', () {
          Get.to(() => const AccountCenterScreen());
        }),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

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
        children: items,
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
        {'label': 'Answers', 'value': '0', 'sub': 'Contributed', 'emoji': '💬'},
        {'label': 'Likes', 'value': '0', 'sub': 'Received', 'emoji': '❤️'},
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
    final idCtrl = Get.find<IdDailyController>();
    return Obx(() {
      final completedCount = idCtrl.completedTasksCount;
      final totalCount = idCtrl.totalTasksCount;
      final progressVal = totalCount > 0 ? completedCount / totalCount : 0.0;

      return Container(
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.015),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  // Liquid Glass Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/id_daily_icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Middle Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ID Daily Tasks',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$completedCount of $totalCount completed',
                          style: GoogleFonts.poppins(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Mini Linear Progress
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressVal,
                            minHeight: 4,
                            backgroundColor: Colors.white.withOpacity(0.05),
                            valueColor: const AlwaysStoppedAnimation(AppTheme.accentColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Arrow action button
                  GestureDetector(
                    onTap: () => Get.to(() => const DailyTaskScreen(initialCategory: 'id')),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildCareerTaskCard() {
    final careerCtrl = Get.find<CareerDailyController>();
    return Obx(() {
      final completedCount = careerCtrl.completedTasksCount;
      final totalCount = careerCtrl.totalTasksCount;
      final progressVal = totalCount > 0 ? completedCount / totalCount : 0.0;

      return Container(
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.015),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  // Liquid Glass Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/career_daily_icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Middle Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Career Daily Tasks',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$completedCount of $totalCount completed',
                          style: GoogleFonts.poppins(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Mini Linear Progress
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressVal,
                            minHeight: 4,
                            backgroundColor: Colors.white.withOpacity(0.05),
                            valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Arrow action button
                  GestureDetector(
                    onTap: () => Get.to(() => const DailyTaskScreen(initialCategory: 'career')),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    final List<Map<String, dynamic>> vaultItems = [
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
    ];

    if (_isAdmin) {
      vaultItems.add({
        'title': 'Admin Panel',
        'sub': 'Approvals & Payouts',
        'icon': Icons.admin_panel_settings_rounded,
        'color': const Color(0xFFEC4899),
        'target': () => const AdminVaultPanelScreen(),
      });
    }

    vaultItems.add({
      'title': 'Membership Center',
      'sub': 'Upgrade VIP & Novel',
      'icon': Icons.card_membership_rounded,
      'color': const Color(0xFF8B5CF6),
      'target': () => const MembershipCenterScreen(),
    });

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

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppTheme.textTertiary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsTab() {
    if (_posts.isEmpty) {
      return _buildEmptyState('No posts shared yet', Icons.notes_rounded);
    }
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
    if (_questions.isEmpty) {
      return _buildEmptyState('No questions asked yet', Icons.help_outline_rounded);
    }
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
    if (_communities.isEmpty) {
      return _buildEmptyState('No communities joined yet', Icons.groups_rounded);
    }
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
    Get.to(() => const EditProfileScreen())?.then((_) {
      _loadUserProfile();
    });
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

  Widget _buildAboutCard() {
    final hasAboutInfo = (_user.profession != null && _user.profession!.isNotEmpty) ||
        (_user.education != null && _user.education!.isNotEmpty) ||
        (_user.country != null && _user.country!.isNotEmpty) ||
        _user.dob != null ||
        (_user.gender != null && _user.gender!.isNotEmpty) ||
        (_user.website != null && _user.website!.isNotEmpty) ||
        (_user.instagram != null && _user.instagram!.isNotEmpty) ||
        (_user.youtube != null && _user.youtube!.isNotEmpty) ||
        (_user.twitter != null && _user.twitter!.isNotEmpty);

    if (!hasAboutInfo) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
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
            children: [
              const Text('ℹ️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'ABOUT ME',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_user.profession != null && _user.profession!.isNotEmpty)
            _aboutItem(Icons.work_outline_rounded, 'Profession', _user.profession!),
          if (_user.education != null && _user.education!.isNotEmpty)
            _aboutItem(Icons.school_outlined, 'Education', _user.education!),
          if ((_user.city != null && _user.city!.isNotEmpty) ||
              (_user.state != null && _user.state!.isNotEmpty) ||
              (_user.country != null && _user.country!.isNotEmpty))
            _aboutItem(
              Icons.location_on_outlined,
              'Location',
              [
                if (_user.city != null && _user.city!.isNotEmpty) _user.city,
                if (_user.state != null && _user.state!.isNotEmpty) _user.state,
                if (_user.country != null && _user.country!.isNotEmpty) _user.country,
              ].join(', '),
            ),
          if (_user.dob != null)
            _aboutItem(
              Icons.cake_outlined,
              'Birthday',
              '${DateFormat('dd MMM yyyy').format(_user.dob!)} (${_user.age} years old)',
            ),
          if (_user.gender != null && _user.gender!.isNotEmpty)
            _aboutItem(Icons.person_outline_rounded, 'Gender', _user.gender!),
          if (_user.website != null && _user.website!.isNotEmpty)
            _aboutItem(Icons.language_rounded, 'Website', _user.website!, isLink: true),
          if (_user.instagram != null && _user.instagram!.isNotEmpty)
            _aboutItem(Icons.camera_alt_rounded, 'Instagram', _user.instagram!),
          if (_user.youtube != null && _user.youtube!.isNotEmpty)
            _aboutItem(Icons.play_circle_outline_rounded, 'YouTube', _user.youtube!),
          if (_user.twitter != null && _user.twitter!.isNotEmpty)
            _aboutItem(Icons.chat_bubble_outline_rounded, 'Twitter/X', _user.twitter!),
        ],
      ),
    );
  }

  Widget _aboutItem(IconData icon, String label, String value, {bool isLink = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.white54),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.white70, height: 1.3),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white54)),
                  TextSpan(
                    text: value,
                    style: isLink
                        ? const TextStyle(color: Color(0xFF38BDF8), decoration: TextDecoration.underline)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
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
