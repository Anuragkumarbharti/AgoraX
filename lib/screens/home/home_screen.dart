import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/index.dart';
import '../../models/event_model.dart' as model;
import '../../services/event_controller.dart';
import '../../widgets/post_card.dart';
import '../../widgets/community_card.dart';
import '../communities/communities_screen.dart';
import '../events/events_screen.dart';
import '../events/event_detail_screen.dart';
import '../profile/daily_task_screen.dart';
import '../../services/study_category_controller.dart';
import '../../services/study_vault_controller.dart';
import '../study_vault/study_vault_home_screen.dart';
import '../study_vault/book_details_screen.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ScrollController _scrollController;
  bool _showFloatingButton = true;
  final EventController _eventController = Get.find<EventController>();
  List<Post> _posts = [];
  bool _isLoadingPosts = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      setState(() {
        _showFloatingButton = _scrollController.offset < 100;
      });
    });
    _fetchRecentPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
          _posts = list.map((item) => Post.fromJson(item as Map<String, dynamic>)).toList();
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
                'CREATE NEW POST',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 4,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  hintStyle: GoogleFonts.poppins(color: Colors.white30, fontSize: 13),
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
                    child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white38)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final text = contentCtrl.text.trim();
                      if (text.isEmpty) return;

                      Get.back();
                      
                      // Show uploading dialog
                      Get.dialog(
                        const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                        barrierDismissible: false,
                      );

                      try {
                        final currentUser = Supabase.instance.client.auth.currentUser;
                        if (currentUser == null) throw Exception('Not logged in');
                        
                        final postId = 'post_${DateTime.now().millisecondsSinceEpoch}';
                        
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
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                    child: Text('Post', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotifications() {
    Get.bottomSheet(
      Container(
        color: AppTheme.bgLight,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _notificationItem('🏆 Weekly Coding Challenge starting in 30 min!', '10m ago'),
            _notificationItem('🎉 You earned a "Top Contributor" badge!', '2h ago'),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _notificationItem(String text, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Text(time, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
        ],
      ),
    );
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
              'Creania',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _showNotifications,
          ),
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
      body: SingleChildScrollView(
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
                        onTap: () => Get.to(() => EventDetailScreen(event: e)),
                        child: Container(
                          width: 240,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: e.isOfficial
                                  ? AppTheme.primaryColor.withOpacity(0.3)
                                  : AppTheme.borderColor.withOpacity(0.4),
                            ),
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
                                      color: e.isOfficial ? AppTheme.primaryColor : Colors.white12,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      e.isOfficial ? '👑 OFFICIAL' : '🏫 COMMUNITY',
                                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  Text(
                                    e.entryFeeType == model.EntryFeeType.free ? 'FREE' : '₹${e.entryFeeAmount}',
                                    style: TextStyle(
                                      color: e.entryFeeType == model.EntryFeeType.free ? AppTheme.accentColor : const Color(0xFFFBBF24),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                e.title,
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                e.prizePool,
                                style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.w700),
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

              // Trending Communities
              _buildSectionHeader(context, 'Trending Communities'),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: CommunityCard(
                        community: Community(
                          id: '$index',
                          name: ['Flutter', 'AI', 'Web Dev', 'UPSC', 'Gaming'][index],
                          description: 'Discussion on ${['Flutter', 'AI', 'Web Dev', 'UPSC', 'Gaming'][index]}',
                          category: 'Technology',
                          type: 'public',
                          owner: 'admin',
                          admins: [],
                          members: [],
                          memberCount: 1000 + (index * 500),
                          isVerified: index % 2 == 0,
                          createdAt: DateTime.now(),
                        ),
                      ),
                    );
                  },
                ),
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
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : _posts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'No posts yet. Be the first to share!',
                              style: GoogleFonts.poppins(color: Colors.white30, fontSize: 13),
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
      floatingActionButton: _showFloatingButton
          ? FloatingActionButton(
              onPressed: _createNewPost,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add),
            )
          : null,
    );

  Widget _buildSectionHeader(BuildContext context, String title) => Row(
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
          onPressed: () {},
          child: Text(
            'View All',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.primaryColor,
                ),
          ),
        ),
      ],
    );

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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

      String subtitleText = 'Unlock daily educational videos, quizzes, and earn rewards.';
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
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                color: Colors.white,
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
                  backgroundColor: selectedCat != null ? AppTheme.primaryColor : AppTheme.cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  Get.to(() => const DailyTaskScreen());
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      selectedCat != null ? 'Open Daily Task  →' : 'Unlock Learning Path  →',
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
            final approvedList = vaultCtrl.items.where((b) => b.status == 'Approved' && !b.isOfficial).toList();
            if (approvedList.isEmpty) {
              return const Center(child: Text('No books available', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)));
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
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          book.sellingPrice == 0 ? 'FREE' : '₹${book.sellingPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: book.sellingPrice == 0 ? AppTheme.accentColor : const Color(0xFFFFD700),
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

