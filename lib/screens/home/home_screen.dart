import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../models/index.dart';
import '../../models/community/post_model.dart';
import '../../models/community/community_model.dart';
import '../../models/community/event_model.dart' as model;
import '../../services/community/event_controller.dart';
import '../../services/community/community_controller.dart';
import '../../widgets/community/post_card.dart';
import '../../widgets/community/community_card.dart';
import '../../widgets/community/community_join_button.dart';
import '../communities/communities_screen.dart';
import '../events/events_screen.dart';
import '../events/event_detail_screen.dart';
import '../profile/daily_task_screen.dart';
import '../../services/vault/study_category_controller.dart';
import '../../services/vault/study_vault_controller.dart';
import '../study_vault/study_vault_home_screen.dart';
import '../study_vault/book_details_screen.dart';
import '../notifications/notification_history_screen.dart';
import '../../services/storage/fcm_notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ScrollController _scrollController;
  final ValueNotifier<bool> _showFloatingButton = ValueNotifier(true);
  final EventController _eventController = Get.find<EventController>();
  final CommunityController _communityCtrl = Get.find<CommunityController>();
  List<Post> _posts = [];
  bool _isLoadingPosts = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      _showFloatingButton.value = _scrollController.offset < 100;
    });
    _fetchRecentPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _showFloatingButton.dispose();
    super.dispose();
  }

  Future<void> _fetchRecentPosts() async {
    try {
      final response = await Supabase.instance.client
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(username, avatar_url)')
          .order('created_at', ascending: false)
          .limit(20);

      if (response != null) {
        final List<dynamic> list = response as List<dynamic>;
        setState(() {
          _posts = list
              .map((item) => Post.fromJson(item as Map<String, dynamic>))
              .toList();
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      setState(() => _isLoadingPosts = false);
    }
  }

  void _createNewPost() {
    final TextEditingController contentCtrl = TextEditingController();
    Get.dialog(
      Builder(builder: (context) {
        return Dialog(
          backgroundColor: context.dialogBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CREATE NEW POST',
                  style: GoogleFonts.outfit(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 4,
                  style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "What's on your mind?",
                    hintStyle:
                        GoogleFonts.poppins(color: context.placeholder, fontSize: 13),
                    filled: true,
                    fillColor: context.elevatedSurfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: context.borderColor),
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
                          style: GoogleFonts.poppins(color: context.caption)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final text = contentCtrl.text.trim();
                        if (text.isEmpty) return;

                        Get.back();

                        // Show uploading dialog
                        Get.dialog(
                          Center(
                              child: CircularProgressIndicator(
                                  color: context.primaryColor)),
                          barrierDismissible: false,
                        );

                        try {
                          final currentUser =
                              Supabase.instance.client.auth.currentUser;
                          if (currentUser == null)
                            throw Exception('Not logged in');

                          final postId =
                              'post_${DateTime.now().millisecondsSinceEpoch}';

                          // Insert post
                          await Supabase.instance.client.from('posts').insert({
                            'id': postId,
                            'user_id': currentUser.id,
                            'content': text,
                            'likes': 0,
                            'comments': 0,
                            'shares': 0,
                          });

                          // Reload posts
                          await _fetchRecentPosts();

                          Get.back(); // close loader
                          Get.snackbar(
                            'Post Shared! 🎉',
                            'Your post was shared successfully.',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: const Color(0xFF10B981),
                            colorText: Colors.white,
                          );
                        } catch (e) {
                          Get.back(); // close loader
                          Get.snackbar('Error ⚠️', 'Failed to share post: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: context.primaryColor),
                      child: Text('Post',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showNotifications() async {
    if (Get.isRegistered<FCMNotificationService>()) {
      FCMNotificationService.to.unreadCount.value = 0;
      FCMNotificationService.to.markAllAsRead();
    }
    Get.to(() => const NotificationHistoryScreen());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 32,
                width: 32,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Text(
                'Creaniaa',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: context.primaryColor,
                ),
              ),
            ],
          ),
          actions: [
            Obx(() {
              final unread = Get.isRegistered<FCMNotificationService>()
                  ? FCMNotificationService.to.unreadCount.value
                  : 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: _showNotifications,
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }),
            IconButton(
              icon: const Icon(Icons.emoji_events_outlined),
              onPressed: () => Get.to(
                () => const EventsScreen(),
                transition: Transition.rightToLeft,
                duration: const Duration(milliseconds: 300),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.groups_rounded),
              onPressed: () => Get.to(
                () => const CommunitiesScreen(),
                transition: Transition.rightToLeft,
                duration: const Duration(milliseconds: 300),
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await _fetchRecentPosts();
            try {
              await _eventController.syncFromSupabase();
            } catch (_) {}
            try {
              await _communityCtrl.syncFromSupabase();
            } catch (_) {}
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            controller: _scrollController,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Daily Learning Mission Card
                  _buildDailyLearningMissionCard(context),
                  const SizedBox(height: 24),

                  // Official Events & Ranking
                  _buildSectionHeader(context, 'Official & Ranking Events'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 140,
                    child: Obx(() {
                      final eventsList = _eventController.events;
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: eventsList.length,
                        itemBuilder: (context, index) {
                          final e = eventsList[index];
                          return GestureDetector(
                            onTap: () =>
                                Get.to(() => EventDetailScreen(event: e)),
                            child: Container(
                              width: 240,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.secondaryBackgroundColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: e.isOfficial
                                      ? context.primaryColor.withOpacity(0.3)
                                      : context.borderColor.withOpacity(0.4),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: e.isOfficial
                                              ? context.primaryColor
                                              : Colors.white12,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          e.isOfficial
                                              ? '👑 OFFICIAL'
                                              : '🏫 COMMUNITY',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      Text(
                                        e.entryFeeType ==
                                                model.EntryFeeType.free
                                            ? 'FREE'
                                            : '₹${e.entryFeeAmount}',
                                        style: TextStyle(
                                          color: e.entryFeeType ==
                                                  model.EntryFeeType.free
                                              ? AppTheme.accentColor
                                              : const Color(0xFFFBBF24),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    e.title,
                                    style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    e.prizePool,
                                    style: const TextStyle(
                                        color: Color(0xFFFBBF24),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 32),

                  // Trending in Study Vault
                  _buildTrendingStudyVault(context),
                  const SizedBox(height: 32),

                  // Official Communities
                  _buildSectionHeader(
                    context,
                    'Official Communities',
                    onViewAll: () => Get.to(() => const CommunitiesScreen()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: Obx(() {
                      final officialComms = _communityCtrl.communities
                          .where((c) => c.type == 'Official')
                          .toList();

                      if (officialComms.isEmpty) {
                        return Center(
                          child: Text(
                            'Loading communities...',
                            style: GoogleFonts.poppins(
                                color: Colors.white30, fontSize: 13),
                          ),
                        );
                      }

                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: officialComms.length,
                        itemBuilder: (context, index) {
                          final comm = officialComms[index];
                          return _buildOfficialCommunityCard(
                              context, comm, _communityCtrl);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 32),

                  // Popular Questions
                  _buildSectionHeader(context, 'Popular Questions'),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildQuestionCard(context, index),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Recent Posts
                  _buildSectionHeader(context, 'Recent Posts'),
                  const SizedBox(height: 12),
                  _isLoadingPosts
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryColor))
                      : _posts.isEmpty
                          ? Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 20),
                                child: Text(
                                  'No posts yet. Be the first to share!',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white30, fontSize: 13),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _posts.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: PostCard(
                                    post: _posts[index],
                                  ),
                                );
                              },
                            ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: ValueListenableBuilder<bool>(
          valueListenable: _showFloatingButton,
          builder: (context, show, _) => show
              ? FloatingActionButton(
                  onPressed: _createNewPost,
                  backgroundColor: AppTheme.primaryColor,
                  child: const Icon(Icons.add),
                )
              : const SizedBox.shrink(),
        ),
      );

  Widget _buildSectionHeader(BuildContext context, String title,
          {VoidCallback? onViewAll}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onViewAll ?? () {},
            child: Text(
              'View All',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.primaryColor,
                  ),
            ),
          ),
        ],
      );

  Widget _buildOfficialCommunityCard(
      BuildContext context, Community comm, CommunityController ctrl) {
    final isJoined = comm.members.contains(CommunityController.currentUserId);
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Image
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: comm.banner ??
                      'https://images.unsplash.com/photo-1579546929518-9e396f3cc809',
                  height: 80,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.white10),
                  errorWidget: (context, url, error) =>
                      Container(color: Colors.white10),
                ),
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFF1E293B).withOpacity(0.8),
                        const Color(0xFF1E293B)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // Floating Avatar/Emoji
                Positioned(
                  bottom: 4,
                  left: 12,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFF1E293B), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        comm.image ?? comm.name.substring(0, 1),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                comm.name,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: Color(0xFF60A5FA),
                              size: 13,
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${comm.memberCount} members',
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    CommunityJoinButton(
                      community: comm,
                      height: 28,
                      width: double.infinity,
                      borderRadius: 6.0,
                      textStyle: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, int index) => Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor, width: 0.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to implement state management in Flutter?',
              style: Theme.of(context).textTheme.bodyLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Flutter',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryColor,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${24 + index} answers',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildDailyLearningMissionCard(BuildContext context) {
    final studyCtrl = Get.find<StudyCategoryController>();
    return Obx(() {
      final selectedCat = studyCtrl.selectedCategory.value;
      final isVideoWatched = studyCtrl.videoWatchedToday.value;
      final isQuizDone = studyCtrl.quizCompletedToday.value;

      String subtitleText =
          'Unlock daily educational videos, quizzes, and earn rewards.';
      String statusText = 'LOCKED';
      Color statusColor = AppTheme.textTertiary;
      IconData statusIcon = Icons.lock_outline_rounded;

      if (selectedCat != null) {
        subtitleText = '$selectedCat path';
        if (isQuizDone) {
          statusText = 'COMPLETED';
          statusColor = AppTheme.accentColor;
          statusIcon = Icons.check_circle_outline_rounded;
        } else if (isVideoWatched) {
          statusText = 'QUIZ UNLOCKED';
          statusColor = AppTheme.primaryColor;
          statusIcon = Icons.bolt_rounded;
        } else {
          statusText = 'IN PROGRESS';
          statusColor = const Color(0xFFFBBF24);
          statusIcon = Icons.play_circle_outline_rounded;
        }
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selectedCat != null
                ? statusColor.withOpacity(0.3)
                : AppTheme.borderColor.withOpacity(0.4),
          ),
          boxShadow: [
            if (selectedCat != null)
              BoxShadow(
                color: statusColor.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'DAILY MISSION',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              selectedCat ?? 'Personalized Daily Learning',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitleText,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  Get.to(() => const DailyTaskScreen());
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      selectedCat != null
                          ? 'Open Daily Task  →'
                          : 'Unlock Learning Path  →',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTrendingStudyVault(BuildContext context) {
    if (!Get.isRegistered<StudyVaultController>()) {
      Get.put(StudyVaultController());
    }
    final vaultCtrl = Get.find<StudyVaultController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Trending in Study Vault',
                style: Theme.of(context).textTheme.headlineSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => Get.to(() => const StudyVaultHomeScreen()),
              child: Text(
                'View All',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
          child: Obx(() {
            final approvedList = vaultCtrl.items
                .where((b) => b.status == 'Approved' && !b.isOfficial)
                .toList();
            if (approvedList.isEmpty) {
              return const Center(
                  child: Text('No books available',
                      style: TextStyle(
                          color: AppTheme.textTertiary, fontSize: 11)));
            }

            return ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: approvedList.length,
              itemBuilder: (context, index) {
                final book = approvedList[index];
                return GestureDetector(
                  onTap: () => Get.to(() => BookDetailsScreen(book: book)),
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(book.coverImage),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          book.title,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          book.sellingPrice == 0
                              ? 'FREE'
                              : '₹${book.sellingPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: book.sellingPrice == 0
                                ? AppTheme.accentColor
                                : const Color(0xFFFFD700),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}
