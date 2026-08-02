import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../models/index.dart';
import '../../models/event_model.dart' as model;
import '../../services/event_controller.dart';
import '../../services/community_controller.dart';
import '../../widgets/post_card.dart';
import '../../widgets/community_card.dart';
import '../../widgets/community_join_button.dart';
import '../communities/communities_screen.dart';
import '../events/events_screen.dart';
import '../events/event_detail_screen.dart';
import '../profile/daily_task_screen.dart';
import '../../services/study_category_controller.dart';
import '../../services/study_vault_controller.dart';
import '../study_vault/study_vault_home_screen.dart';
import '../study_vault/book_details_screen.dart';
import '../events/wallet_screen.dart';
import '../rooms/rooms_screen.dart';
import '../notifications/notification_history_screen.dart';
import '../../services/fcm_notification_service.dart';



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

  void _showNotifications() async {
    if (Get.isRegistered<FCMNotificationService>()) {
      FCMNotificationService.to.unreadCount.value = 0;
      FCMNotificationService.to.markAllAsRead();
    }
    Get.to(() => const NotificationHistoryScreen());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090B12) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 28,
              width: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, color: Color(0xFF6D5DF6), size: 28),
            ),
            const SizedBox(width: 8),
            Text(
              'Creania',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: const Color(0xFF6D5DF6),
              ),
            ),
          ],
        ),
        actions: [
          // Wallet Balance Pill
          GestureDetector(
            onTap: () => Get.to(() => WalletScreen()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF191E29) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? const Color(0xFF2D3645) : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF4B400),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 12),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '29,549',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Notifications Bell
          Obx(() {
            final unread = Get.isRegistered<FCMNotificationService>()
                ? FCMNotificationService.to.unreadCount.value
                : 0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(Icons.notifications_none_rounded, color: isDark ? Colors.white : const Color(0xFF374151)),
                  onPressed: () => Get.to(() => const NotificationHistoryScreen()),
                ),
                if (unread > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                      child: Center(
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
          
          // User Avatar Pill
          GestureDetector(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.only(right: 16, left: 4),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF6D5DF6),
                child: const CircleAvatar(
                  radius: 14,
                  backgroundImage: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb'),
                ),
              ),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Welcome & XP Level Progress Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151923) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? const Color(0xFF2D3645) : const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundImage: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good morning, Riya! 👋',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Let's learn, connect & grow together.",
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Level badge & XP bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6D5DF6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.military_tech_rounded, color: Color(0xFF6D5DF6), size: 16),
                              Text(
                                'Lv. 12',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: const Color(0xFF6D5DF6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '2560 / 5000 XP',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6D5DF6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Quick Actions Grid (2x4)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.9,
                children: [
                  _buildQuickActionTile('Study Room', Icons.school_rounded, const Color(0xFF6D5DF6), isDark, () => Get.to(() => const StudyVaultHomeScreen())),
                  _buildQuickActionTile('Debate Room', Icons.record_voice_over_rounded, const Color(0xFFF97316), isDark, () => Get.to(() => RoomsScreen())),
                  _buildQuickActionTile('Quiz', Icons.quiz_rounded, const Color(0xFF22C55E), isDark, () => Get.to(() => const DailyTaskScreen())),
                  _buildQuickActionTile('Practice', Icons.menu_book_rounded, const Color(0xFF38BDF8), isDark, () => Get.to(() => const StudyVaultHomeScreen())),
                  _buildQuickActionTile('Audio Room', Icons.headphones_rounded, const Color(0xFF3B82F6), isDark, () => Get.to(() => RoomsScreen())),
                  _buildQuickActionTile('Create Room', Icons.add_box_rounded, const Color(0xFFEC4899), isDark, () => Get.to(() => RoomsScreen())),
                  _buildQuickActionTile('Community', Icons.groups_rounded, const Color(0xFF8B5CF6), isDark, () => Get.to(() => const CommunitiesScreen())),
                  _buildQuickActionTile('Events', Icons.event_rounded, const Color(0xFFF59E0B), isDark, () => Get.to(() => const EventsScreen())),
                ],
              ),
              const SizedBox(height: 24),

              // Recommended Rooms Header & Cards
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recommended Rooms',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Get.to(() => RoomsScreen()),
                    child: Text(
                      'See all >',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: const Color(0xFF6D5DF6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Recommended Room 1
              _buildRecommendedRoomCard(
                title: 'Physics Study Room',
                subtitle: 'Concept + PYQ Discussion',
                tag: 'STUDY',
                listeners: '128',
                lang: 'English',
                imgUrl: 'https://images.unsplash.com/photo-1522202176988-66273c2fd55f',
                isDark: isDark,
              ),
              const SizedBox(height: 12),

              // Recommended Room 2
              _buildRecommendedRoomCard(
                title: "India's Future Economy",
                subtitle: '5 vs 5 Debate',
                tag: 'DEBATE',
                listeners: '96',
                lang: 'English',
                imgUrl: 'https://images.unsplash.com/photo-1543269865-cbf427effbad',
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              // Daily Goals Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151923) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? const Color(0xFF2D3645) : const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🔥 ', style: TextStyle(fontSize: 16)),
                        Text(
                          'Daily Goals',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Keep your streak alive!',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '7 Days',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            Text(
                              'Current Streak',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '120 XP',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            Text(
                              "Today's Goal",
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                        // Ring chart indicator
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 50,
                              height: 50,
                              child: CircularProgressIndicator(
                                value: 0.75,
                                strokeWidth: 5,
                                backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6D5DF6)),
                              ),
                            ),
                            Text(
                              '75%',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: const Color(0xFF6D5DF6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Recent Community Posts
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Community Feed',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Get.to(() => const CommunitiesScreen()),
                    child: Text(
                      'View all >',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: const Color(0xFF6D5DF6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _isLoadingPosts
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6D5DF6)))
                  : _posts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'No posts yet. Be the first to share!',
                              style: GoogleFonts.outfit(color: isDark ? Colors.white38 : const Color(0xFF6B7280), fontSize: 13),
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
    );
  }

  Widget _buildQuickActionTile(String title, IconData icon, Color color, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF374151),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedRoomCard({
    required String title,
    required String subtitle,
    required String tag,
    required String listeners,
    required String lang,
    required String imgUrl,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151923) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF2D3645) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(
              imageUrl: imgUrl,
              width: 84,
              height: 84,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey[200]),
              errorWidget: (_, __, ___) => Container(color: Colors.grey[300]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6D5DF6).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF6D5DF6),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, size: 12, color: Color(0xFF6B7280)),
                    const SizedBox(width: 3),
                    Text(listeners, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF6B7280))),
                    const SizedBox(width: 10),
                    const Icon(Icons.language_rounded, size: 12, color: Color(0xFF6B7280)),
                    const SizedBox(width: 3),
                    Text(lang, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF6B7280))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Get.to(() => RoomsScreen()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6D5DF6),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Join',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {VoidCallback? onViewAll}) => Row(
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

  Widget _buildOfficialCommunityCard(BuildContext context, Community comm, CommunityController ctrl) {
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
                  imageUrl: comm.banner ?? 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809',
                  height: 80,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.white10),
                  errorWidget: (context, url, error) => Container(color: Colors.white10),
                ),
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, const Color(0xFF1E293B).withOpacity(0.8), const Color(0xFF1E293B)],
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
                      border: Border.all(color: const Color(0xFF1E293B), width: 2),
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
                        color: AppTheme.textPrimary,
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

