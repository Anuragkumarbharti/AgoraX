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
import '../../services/premium_identity_controller.dart';
import '../../services/study_vault_controller.dart';
import '../../services/user_profile_cache_manager.dart';
import '../../services/user_progress_sync_service.dart';
import '../../services/chat_controller.dart';
import '../store/store_home_screen.dart';
import '../study_vault/study_vault_home_screen.dart';
import '../study_vault/my_library_screen.dart';
import '../study_vault/seller_dashboard_screen.dart';
import '../study_vault/admin_vault_panel_screen.dart';
import '../study_vault/membership_center_screen.dart';
import '../vip/vip_purchase_screen.dart';
import '../novel/novel_purchase_screen.dart';
import '../career/career_hub_screen.dart';
import '../events/wallet_screen.dart';
import '../../widgets/send_gift_dialog.dart';
import '../../widgets/optimized_image.dart';
import '../../services/asset_cache_manager.dart';
import 'profile_customization_screen.dart';
import 'daily_task_screen.dart';
import 'badges_screen.dart';
import 'account_center_screen.dart';
import 'connections_screen.dart';
import 'edit_profile_screen.dart';
import '../chat/chat_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key, this.visitorUser}) : super(key: key);

  final User? visitorUser;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final StoreController _storeCtrl = Get.find<StoreController>();
  final VipController _vipCtrl = Get.find<VipController>();
  final NovelController _novelCtrl = Get.find<NovelController>();
  final CustomizationController _custCtrl = Get.find<CustomizationController>();
  final StudyCategoryController _studyCtrl = Get.find<StudyCategoryController>();
  final CareerProgressionController _careerCtrl = Get.find<CareerProgressionController>();

  late TabController _tabController;
  late User _user;
  bool _isLoadingProfile = true;
  String? _errorMessage;
  bool _isFollowing = false;
  bool _isBlocked = false;
  bool _postsLoaded = false;
  bool _isLoadingPosts = false;

  final List<Post> _posts = [];
  final List<Question> _questions = [];
  final List<Map<String, dynamic>> _communities = [];

  bool get _isMe => widget.visitorUser == null || widget.visitorUser!.id == UserProfileCacheManager.currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserProfile();
    if (!_isMe) {
      _checkFollowingStatus();
    }
  }

  void _checkFollowingStatus() async {
    try {
      final currentUid = UserProfileCacheManager.currentUserId;
      final visitorUid = widget.visitorUser!.id;
      final response = await Supabase.instance.client
          .from('followers')
          .select()
          .eq('follower_id', currentUid)
          .eq('following_id', visitorUid)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _isFollowing = response != null;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoadingProfile = true;
      _errorMessage = null;
    });
    try {
      final profileId = _isMe ? UserProfileCacheManager.currentUserId : widget.visitorUser!.id;
      
      final profileData = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', profileId)
          .maybeSingle();
          
      final walletData = await Supabase.instance.client
          .from('wallets')
          .select()
          .eq('id', profileId)
          .maybeSingle();

      if (profileData == null) {
        setState(() {
          _isLoadingProfile = false;
          _errorMessage = 'Profile row not found in database.';
        });
        return;
      }

      final Map<String, dynamic> mergedData = Map<String, dynamic>.from(profileData);
      mergedData['silverCoins'] = walletData != null ? (walletData['coins_balance'] ?? 0) : 0;

      setState(() {
        _user = User.fromJson(mergedData);
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

  Future<void> _loadUserPosts() async {
    if (_postsLoaded || _isLoadingPosts) return;
    if (!mounted) return;
    setState(() {
      _isLoadingPosts = true;
    });
    try {
      final profileId = _isMe ? UserProfileCacheManager.currentUserId : widget.visitorUser!.id;
      final postsResponse = await Supabase.instance.client
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(username, avatar_url)')
          .eq('user_id', profileId)
          .order('created_at', ascending: false);

      List<Post> fetchedPosts = [];
      if (postsResponse != null) {
        final List<dynamic> list = postsResponse as List<dynamic>;
        fetchedPosts = list.map((item) => Post.fromJson(item as Map<String, dynamic>)).toList();
      }
      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(fetchedPosts);
          _postsLoaded = true;
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
        });
      }
    }
  }

  void _toggleFollow() async {
    final currentUid = UserProfileCacheManager.currentUserId;
    final visitorUid = widget.visitorUser!.id;
    setState(() {
      _isFollowing = !_isFollowing;
    });

    try {
      if (_isFollowing) {
        await Supabase.instance.client.from('followers').insert({
          'follower_id': currentUid,
          'following_id': visitorUid,
        });
      } else {
        await Supabase.instance.client
            .from('followers')
            .delete()
            .eq('follower_id', currentUid)
            .eq('following_id', visitorUid);
      }
      _loadUserProfile();
    } catch (e) {
      setState(() {
        _isFollowing = !_isFollowing;
      });
      Get.snackbar('Error', 'Could not complete request: $e');
    }
  }

  void _startDirectChat() async {
    try {
      final chatCtrl = Get.find<ChatController>();
      final conversation = chatCtrl.getOrCreateConversation(
        widget.visitorUser!.id,
        widget.visitorUser!.displayName,
        widget.visitorUser!.avatar ?? '',
      );
      Get.to(() => ChatScreen(conversation: conversation));
    } catch (e) {
      Get.snackbar('Error', 'Failed to start message: $e');
    }
  }

  void _openSendGiftDialog() {
    Get.dialog(SendGiftDialog(
      roomId: 'direct_gift',
      targetUserId: _user.id,
      targetUserName: _user.displayName,
      occupiedSeatsCount: 1,
      onGiftSent: (giftName, giftIcon, cost, currency) {
        Get.snackbar('Gift Sent 🎁', 'You sent $giftName to ${_user.displayName}!');
        _loadUserProfile();
      },
    ));
  }

  void _showMoreMenu() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: const BoxDecoration(
          color: Color(0xFF11131C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share_rounded, color: Colors.white),
              title: const Text('Share Profile', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                Share.share('Check out ${_user.displayName}\'s profile on Creania: https://creania.com/user/${_user.username}');
              },
            ),
            ListTile(
              leading: Icon(Icons.block_rounded, color: _isBlocked ? Colors.green : Colors.redAccent),
              title: Text(_isBlocked ? 'Unblock User' : 'Block User', style: const TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                setState(() => _isBlocked = !_isBlocked);
                Get.snackbar(_isBlocked ? 'Blocked 🚫' : 'Unblocked 🟢', 'User has been ${_isBlocked ? 'blocked' : 'unblocked'}.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem_rounded, color: Colors.orangeAccent),
              title: const Text('Report User', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                Get.snackbar('Report Submitted ⚠️', 'Thank you for keeping Creania safe. Our moderation team will review this profile.');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: Color(0xFF11131C),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFBEC2FF))),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF11131C),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF11131C),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Cover Photo & Header Section
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover Banner
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuBQXG_YXV_OQP0-xJhu5HQN_kSn29aNlQpdYprfy_6Lt6p7S1_iFiPZLBOCoYJyYLzD0jEMn_nDJdbzzTPPd9TPWvJOwbk2Hx0LhOeMno3fyDDnF0AexwryfifU6lOGkltd25UuY-QDuOgq-sQKBI_660pJrJUwMlGT4P1ZqHI7FpHXm4QzmIXTfLHKh-g5G0vX9VSCr97WBuxDAJjWw-oKaHFOSMYfd4JInnsuQE_mpojplk9j2obIfxP_OmYQFk2XxAFzsoJAuPrc',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Color(0xFF11131C)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // App bar buttons
                Positioned(
                  top: 40,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D1F29).withOpacity(0.5),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      if (_isMe)
                        GestureDetector(
                          onTap: () => Get.to(() => const SettingsScreen()),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D1F29).withOpacity(0.5),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                          ),
                        ),
                    ],
                  ),
                ),
                // Avatar + User Info (Overlapped)
                Positioned(
                  bottom: -60,
                  left: 16,
                  right: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Avatar Container
                      Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFFA855F7), Color(0xFFFFD700)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 46,
                              backgroundColor: const Color(0xFF11131C),
                              child: OptimizedImage(
                                imageUrl: _user.avatar != null && _user.avatar!.isNotEmpty
                                    ? _user.avatar!
                                    : 'https://lh3.googleusercontent.com/aida-public/AB6AXuCybH5Mu5-PZ_dMHWuWFu9UFqwNpHtc79GaJ1SCz5v_bdFVOBIBr6-Cbgapb6sfnES7omhgh6mLz1FBQpMfCdnTcBsYtqmihxZELjY4zaJAwKYf6bU-AtUsm-WZRdG9uAznurNgCeHKjz02JXnJcB3olfo16_NN_dQPu_losBj6pac8-KtnTIXZREq6hInG6VPAEfdXysXJ11taDrh7Te-i-xDA02rAOPFka-22raXdTq9vSpH1pBr5u3Wsl9JF1x6b8CiVtPwIoSmu',
                                quality: ImageQuality.thumbnail,
                                borderRadius: BorderRadius.circular(46),
                                width: 90,
                                height: 90,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF11131C), width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 64),

            // Profile info block
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First Row: Username, VTag (first), and TagLights
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _user.displayName,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // VTag shown first with breathing pulse animation
                      _BreathingVTag(
                        level: getVTagLevel(_user),
                        onTap: () {
                          Get.snackbar('Verification Info', 'This user is verified at the ${getVTagLevel(_user).toUpperCase()} tier.');
                        },
                      ),
                      const SizedBox(width: 6),
                      // TagLights list (Dynamic level tags + DB custom tags with +N overflow)
                      ...buildTagLightsWidget(generateDynamicTagLights(_user), context),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Second Row: ID
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _user.sid));
                          Get.snackbar('Copied', 'ID copied to clipboard.');
                        },
                        onLongPress: () {
                          Get.snackbar('Share ID', 'Profile ID: ${_user.sid}');
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ID : ${_user.sid}',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF9CA3AF),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.content_copy_rounded,
                              color: Color(0xFF9CA3AF),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _user.gender == 'female' ? Icons.female_rounded : Icons.male_rounded,
                        color: const Color(0xFFBEC2FF),
                        size: 14,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Third Row: RTag
                  buildRTagWidget(_user.rTags, context),

                  // Fourth Row: Badge Showcase
                  buildBadgesShowcaseWidget(_user.showcasedBadges, context),
                  const SizedBox(height: 12),

                  // Action Buttons row
                  Row(
                    children: _isMe
                        ? [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5865F2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                ),
                                onPressed: () => Get.to(() => const EditProfileScreen()),
                                child: Text('Edit Profile', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: const Color(0xFF1D1F29).withOpacity(0.5),
                                ),
                                onPressed: () => Get.snackbar('Edit Cover', 'Select cover image customization.'),
                                child: Text('Edit Cover', style: GoogleFonts.inter(color: const Color(0xFFE1E1EF), fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => Get.to(() => const ProfileCustomizationScreen()),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1D1F29).withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: const Icon(Icons.brush_rounded, color: Color(0xFFE1E1EF), size: 20),
                              ),
                            ),
                          ]
                        : [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5865F2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                ),
                                onPressed: _toggleFollow,
                                child: Text(_isFollowing ? 'Following' : 'Follow', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: const Color(0xFF1D1F29).withOpacity(0.5),
                                ),
                                onPressed: _startDirectChat,
                                child: Text('Message', style: GoogleFonts.inter(color: const Color(0xFFE1E1EF), fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _openSendGiftDialog,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1D1F29).withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFE1E1EF), size: 20),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _showMoreMenu,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1D1F29).withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: const Icon(Icons.more_horiz_rounded, color: Color(0xFFE1E1EF), size: 20),
                              ),
                            ),
                          ],
                  ),
                  const SizedBox(height: 24),
                  // 3. Social Stats Section
                  Row(
                    children: [
                      Expanded(child: _statCard('${_user.followers}', 'Followers')),
                      const SizedBox(width: 8),
                      Expanded(child: _statCard('${_user.following}', 'Following')),
                      const SizedBox(width: 8),
                      if (_isMe) ...[
                        Expanded(child: _statCard('89', 'Friends')),
                        const SizedBox(width: 8),
                        Expanded(child: _statCard('123.5K', 'Gifts')),
                      ] else ...[
                        Expanded(child: _statCard('123.5K', 'Gifts')),
                        const SizedBox(width: 8),
                        Expanded(child: _statCard('450K', 'Contribute')),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 4. Bio & Links Section
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Building digital experiences. Exploring the intersection of design and code. Coffee enthusiast. ☕',
                          style: GoogleFonts.inter(color: const Color(0xFFE1E1EF), fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        _bioDetailRow(Icons.location_on_outlined, 'Tokyo, JP'),
                        const SizedBox(height: 6),
                        _bioDetailRow(Icons.language_rounded, 'EN, JP'),
                        const SizedBox(height: 6),
                        _bioDetailRow(Icons.link_rounded, 'alexmercer.dev'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 5. Personal Info Section
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Personal Info', style: GoogleFonts.inter(color: const Color(0xFFC6C5D7), fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 12),
                        _infoTableRow('Gender', 'Male'),
                        _infoTableRow('Age', '17 years'),
                        _infoTableRow('Birthday', '17 Jul 2008'),
                        _infoTableRow('Country', 'India'),
                        _infoTableRow('Language', 'en'),
                        _infoTableRow('Profession', 'Biotechnology'),
                        _infoTableRow('Education', 'Maharaja'),
                        _infoTableRow('Website', '.com', isLast: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 6. My Arenas Section
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Arenas', style: GoogleFonts.inter(color: const Color(0xFFC6C5D7), fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 12),
                        Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: const DecorationImage(
                              image: NetworkImage(
                                'https://lh3.googleusercontent.com/aida-public/AB6AXuB9yUadsJtCT-c_Cf9DLuryOK7_kcxgFsWq3XYDuuAcOjeu0DU36SQktoT_33IHojANOTZRGphogVbNnt1hD2Ovqm4SCE548pGnq6uQHZfztL4iVKpghOFEWQ7Ov-7r8pafl__pxJEgSmpqr15CHy_-BA7Hvi9xef0yTDe14EK7IZemFJM6GzFEeyjDx4We_umfQ6zZyowKDytt8EOc9t-cbqYlFFyypbutljnn1TGY9eL_q_r6ULwsr8UW0MCnTEFyRnxW-DQTqZ4B',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                colors: [Colors.black87, Colors.transparent],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withOpacity(0.2),
                                        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('OWNER', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Cybernetic Arena', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDDB7FF).withOpacity(0.2),
                                    border: Border.all(color: const Color(0xFFDDB7FF).withOpacity(0.5)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('lvl 2', style: TextStyle(color: Color(0xFFDDB7FF), fontSize: 10)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 7. Joined Communities Section
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Joined Communities', style: GoogleFonts.inter(color: const Color(0xFFC6C5D7), fontWeight: FontWeight.bold, fontSize: 12)),
                            const Text('5l', style: TextStyle(color: Color(0xFFBEC2FF), fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _communityRow('Neo-Tokyo Architects', 'Admin', 'Lvl 24', Icons.architecture_rounded, const Color(0xFFBEC2FF)),
                        const SizedBox(height: 8),
                        _communityRow('Rust Devs Global', 'Member', 'Lvl 15', Icons.code_rounded, const Color(0xFFDDB7FF)),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBEC2FF).withOpacity(0.08),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {},
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('More Communities', style: GoogleFonts.inter(color: const Color(0xFFBEC2FF), fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward_rounded, color: Color(0xFFBEC2FF), size: 14),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 8. Quick Actions Section
                  if (_isMe) ...[
                    _glassCard(
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        childAspectRatio: 1.5,
                        children: [
                          _navItem(Icons.task_alt_rounded, 'Tasks', () => Get.to(() => const DailyTaskScreen())),
                          _navItem(Icons.work_outline_rounded, 'Career', () => Get.to(() => const CareerHubScreen())),
                          _navItem(Icons.account_balance_wallet_outlined, 'Wallet', () => Get.to(() => WalletScreen())),
                          _navItem(Icons.storefront_outlined, 'Store', () => Get.to(() => const StoreHomeScreen())),
                          _navItem(Icons.emoji_events_outlined, 'Badges', () => Get.to(() => const BadgesScreen())),
                          _navItem(Icons.settings_outlined, 'Settings', () => Get.to(() => const SettingsScreen())),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 9. Achievements Section
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Achievements', style: GoogleFonts.inter(color: const Color(0xFFC6C5D7), fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _achievementBadge('VIP', Icons.diamond_outlined, const Color(0xFFFFDB3C)),
                              const SizedBox(width: 12),
                              _achievementBadge('Dev', Icons.code_rounded, const Color(0xFFBEC2FF)),
                              const SizedBox(width: 12),
                              _achievementBadge('Host', Icons.mic_none_rounded, const Color(0xFFDDB7FF)),
                              const SizedBox(width: 12),
                              _achievementBadge('Verified', Icons.verified_outlined, const Color(0xFF00F5FF)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 10. Gift Stats Section (Replaces Arena Stats & Old Gift Stats)
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.featured_play_list_rounded, color: Color(0xFFFBBF24), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Gift Stats',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Monthly received gifts',
                              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12.5),
                            ),
                            Text(
                              '12.5K',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFFBBF24),
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'monthly contribute',
                              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12.5),
                            ),
                            Text(
                              '450K',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Gifts',
                              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12.5),
                            ),
                            Row(
                              children: [
                                _buildOverlappingAvatars([
                                  'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=80',
                                  'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80',
                                  'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80',
                                  'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=80',
                                ]),
                                const SizedBox(width: 6),
                                Text(
                                  '123.5K',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF8B5CFF),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 16),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Contributors',
                              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12.5),
                            ),
                            Row(
                              children: [
                                _buildOverlappingAvatars([
                                  'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=80',
                                  'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80',
                                  'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80',
                                  'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=80',
                                ]),
                                const SizedBox(width: 6),
                                Text(
                                  '842k',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 16),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 11. Activity Feed & Tabs
                  _glassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TabBar(
                          controller: _tabController,
                          indicatorColor: const Color(0xFFBEC2FF),
                          labelColor: const Color(0xFFBEC2FF),
                          unselectedLabelColor: const Color(0xFFC6C5D7),
                          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                          tabs: const [
                            Tab(text: 'Posts'),
                            Tab(text: 'Media'),
                            Tab(text: 'Questions'),
                            Tab(text: 'Likes'),
                          ],
                        ),
                        SizedBox(
                          height: 350,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildPostsFeed(),
                              _buildPlaceholderFeed('No Media Uploaded Yet'),
                              _buildPlaceholderFeed('No Questions Asked Yet'),
                              _buildPlaceholderFeed('No Liked Content Available'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String getVTagLevel(User? user) {
    if (user == null) return 'blue';
    final name = user.displayName.toLowerCase();
    if (name.contains('president') || name.contains('minister') || user.rTags.contains('Founder')) {
      return 'diamond';
    } else if (user.tagLights.contains('STAR') || user.tagLights.contains('TOP') || name.contains('anurag')) {
      return 'gold';
    } else if (user.tagLights.contains('Official') || user.rTags.contains('Official')) {
      return 'purple';
    }
    return 'blue';
  }

  List<Map<String, dynamic>> generateDynamicTagLights(User user) {
    final List<Map<String, dynamic>> tags = [];

    // 1. VIP tag (V7)
    if (user.vipLevel > 0) {
      tags.add({'label': 'V${user.vipLevel}', 'color': const Color(0xFF8B5CFF)});
    }

    // 2. Novel tag (N5)
    if (user.novelLevel > 0) {
      tags.add({'label': 'N${user.novelLevel}', 'color': const Color(0xFFFF4D8D)});
    }

    // 3. ID Level tag (L42)
    if (user.level > 0) {
      tags.add({'label': 'L${user.level}', 'color': const Color(0xFFFFB020)});
    }

    // 4. Community Level tag (C20)
    tags.add({'label': 'C${user.communities.length}', 'color': const Color(0xFF22C55E)});

    // 5. DB custom tags (e.g. TOP, DEV, MOD, EMP, BOT, STAR, 🔥)
    final tagList = user.tagLights.isEmpty ? ['V5', 'N3', 'L42', 'C12', '🔥'] : user.tagLights;
    for (var t in tagList) {
      t = t.trim();
      if (t == 'Verified' || t == '✓') continue;
      if (t.startsWith('VIP Level ') || t.startsWith('V')) continue;
      if (t.startsWith('Novel ') || t.startsWith('N')) continue;
      if (t.startsWith('ID Level ') || t.startsWith('L')) continue;
      if (t.startsWith('Community Level ') || t.startsWith('C')) continue;

      Color color = const Color(0xFFBEC2FF);
      if (t.toUpperCase() == 'DEV' || t.toUpperCase() == 'DEVELOPER') {
        color = const Color(0xFF00C2FF);
      } else if (t.toUpperCase() == 'MOD' || t.toUpperCase() == 'MODERATOR') {
        color = const Color(0xFFEF4444);
      } else if (t.toUpperCase() == 'EMP' || t.toUpperCase() == 'EMPLOYEE') {
        color = const Color(0xFFFF7A09);
      } else if (t.toUpperCase() == 'BOT') {
        color = const Color(0xFFBEC2FF);
      } else if (t.toUpperCase() == 'TOP') {
        color = const Color(0xFFFFB020);
      } else if (t.toUpperCase() == 'STAR') {
        color = const Color(0xFFDDB7FF);
      } else if (t == '🔥') {
        color = const Color(0xFFFF4D8D);
      }
      tags.add({'label': t, 'color': color});
    }

    return tags;
  }

  List<Widget> buildTagLightsWidget(List<Map<String, dynamic>> tags, BuildContext context) {
    final List<Map<String, dynamic>> displayTags = [];
    bool hasOverflow = false;
    int overflowCount = 0;

    if (tags.length <= 6) {
      displayTags.addAll(tags);
    } else {
      displayTags.addAll(tags.take(5));
      hasOverflow = true;
      overflowCount = tags.length - 5;
    }

    final List<Widget> widgets = displayTags.map((tag) {
      final label = tag['label'] as String;
      final color = tag['color'] as Color;

      Gradient? gradient;
      Color bg = color.withOpacity(0.12);
      Color borderCol = color.withOpacity(0.4);
      Color textCol = color;

      if (label.startsWith('V') && RegExp(r'^\d+$').hasMatch(label.substring(1))) {
        gradient = const LinearGradient(
          colors: [Color(0xFFFFE259), Color(0xFFFFA751)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        borderCol = const Color(0xFFFFA751);
        textCol = Colors.white;
      } else if (label.startsWith('N') && RegExp(r'^\d+$').hasMatch(label.substring(1))) {
        gradient = const LinearGradient(
          colors: [Color(0xFF8A2387), Color(0xFFE94057)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        borderCol = const Color(0xFFE94057);
        textCol = Colors.white;
      } else if (label == 'TOP') {
        bg = const Color(0xFFFF7A09).withOpacity(0.2);
        borderCol = const Color(0xFFFF7A09);
        textCol = const Color(0xFFFF9F43);
      } else if (label == 'DEV') {
        bg = const Color(0xFF00C2FF).withOpacity(0.2);
        borderCol = const Color(0xFF00C2FF);
        textCol = const Color(0xFF8CF3FF);
      } else if (label == 'MOD') {
        bg = const Color(0xFFEF4444).withOpacity(0.2);
        borderCol = const Color(0xFFEF4444);
        textCol = const Color(0xFFFF8E8E);
      }

      return Tooltip(
        message: 'Tap to see details about $label',
        child: GestureDetector(
          onTap: () {
            Get.snackbar('Tag Info', 'Details page for $label tag (coming soon).');
          },
          child: Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: gradient,
              color: gradient == null ? bg : null,
              border: Border.all(color: borderCol, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: borderCol.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                )
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: textCol,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();

    if (hasOverflow) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.8),
          ),
          child: Text(
            '+$overflowCount',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  String? getHighestRTag(List<String> rawRoles) {
    final priority = [
      'Founder',
      'Developer',
      'Official',
      'Employee',
      'Admin',
      'Moderator',
      'Partner',
      'Verified',
      'Tester'
    ];

    final rolesSet = rawRoles.map((r) => r.trim().toLowerCase()).toSet();

    for (var role in priority) {
      if (rolesSet.contains(role.toLowerCase())) {
        return role;
      }
    }
    return null;
  }

  Widget buildRTagWidget(List<String> rawRoles, BuildContext context) {
    final rolesToUse = rawRoles.isEmpty ? ['Founder'] : rawRoles;
    final role = getHighestRTag(rolesToUse);
    if (role == null) return const SizedBox.shrink();

    Gradient gradient;
    Color textColor = Colors.white;
    Color borderColor;

    switch (role.toLowerCase()) {
      case 'founder':
        gradient = const LinearGradient(
          colors: [Color(0xFF1E1E24), Color(0xFF0F0F12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        borderColor = const Color(0xFFFFB020);
        textColor = const Color(0xFFFFB020);
        break;
      case 'developer':
        gradient = const LinearGradient(
          colors: [Color(0xFF00C2FF), Color(0xFF0EA5E9)],
        );
        borderColor = const Color(0xFF00C2FF).withOpacity(0.5);
        break;
      case 'official':
        gradient = const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
        );
        borderColor = const Color(0xFF3B82F6).withOpacity(0.5);
        break;
      case 'employee':
        gradient = const LinearGradient(
          colors: [Color(0xFF8B5CFF), Color(0xFF6366F1)],
        );
        borderColor = const Color(0xFF8B5CFF).withOpacity(0.5);
        break;
      case 'admin':
        gradient = const LinearGradient(
          colors: [Color(0xFFFF7A09), Color(0xFFFFB020)],
        );
        borderColor = const Color(0xFFFFB020).withOpacity(0.5);
        break;
      case 'moderator':
        gradient = const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFF991B1B)],
        );
        borderColor = const Color(0xFFEF4444).withOpacity(0.5);
        break;
      case 'support':
        gradient = const LinearGradient(
          colors: [Color(0xFF22C55E), Color(0xFF15803D)],
        );
        borderColor = const Color(0xFF22C55E).withOpacity(0.5);
        break;
      case 'partner':
        gradient = const LinearGradient(
          colors: [Color(0xFFFF4D8D), Color(0xFFBE185D)],
        );
        borderColor = const Color(0xFFFF4D8D).withOpacity(0.5);
        break;
      case 'tester':
      default:
        gradient = const LinearGradient(
          colors: [Color(0xFF6B7280), Color(0xFF374151)],
        );
        borderColor = const Color(0xFF6B7280).withOpacity(0.5);
        break;
    }

    return Tooltip(
      message: 'Official Role: $role. Tap for role details.',
      child: GestureDetector(
        onTap: () {
          Get.snackbar('Role Info', 'Details about the official $role role (coming soon).');
        },
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: gradient,
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_rounded, color: Colors.white, size: 13),
              const SizedBox(width: 6),
              Text(
                role,
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildBadgesShowcaseWidget(List<String> activeBadgesList, BuildContext context) {
    final custCtrl = Get.find<CustomizationController>();
    final badgesToUse = activeBadgesList.isEmpty ? ['Anniversary', 'Founder Badge', 'Early User', 'Beta Tester'] : activeBadgesList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            itemCount: badgesToUse.take(4).length,
            itemBuilder: (context, index) {
              final bName = badgesToUse[index];
              final meta = custCtrl.badgeMetadata[bName] ?? {'icon': '🏅', 'rarity': 'Common'};
              final iconStr = meta['icon'] as String? ?? '🏅';
              
              return Tooltip(
                message: '$bName badge. Long press for info.',
                child: GestureDetector(
                  onTap: () {
                    Get.snackbar('Badge Info', '$bName details (coming soon).');
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        )
                      ],
                    ),
                    child: Center(
                      child: Text(
                        iconStr,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _glassChip(String text, {Color color = const Color(0xFFE1E1EF)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Text(text, style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildOverlappingAvatars(List<String> imageUrls) {
    return SizedBox(
      height: 20,
      width: 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(imageUrls.length, (index) {
          return Positioned(
            left: index * 10.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: CircleAvatar(
                radius: 8,
                backgroundImage: NetworkImage(imageUrls[index]),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _statCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1F29).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(color: const Color(0xFFC6C5D7), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF1D1F29).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: child,
    );
  }

  Widget _bioDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFC6C5D7), size: 14),
        const SizedBox(width: 8),
        Text(text, style: GoogleFonts.inter(color: const Color(0xFFC6C5D7), fontSize: 12)),
      ],
    );
  }

  Widget _infoTableRow(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: const Color(0xFFC6C5D7), fontSize: 12)),
          Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _communityRow(String name, String role, String level, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1F29).withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(role.toUpperCase(), style: GoogleFonts.inter(color: const Color(0xFFFFDB3C), fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(level, style: const TextStyle(color: Colors.white70, fontSize: 8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFC6C5D7), size: 16),
        ],
      ),
    );
  }

  Widget _achievementBadge(String title, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(title, style: GoogleFonts.inter(color: Colors.white70, fontSize: 9)),
      ],
    );
  }

  Widget _navItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFC6C5D7), size: 20),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(color: const Color(0xFFC6C5D7), fontSize: 9)),
        ],
      ),
    );
  }

  Widget _analyticRow(String label, String value, {Color color = Colors.white, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: const Color(0xFFC6C5D7), fontSize: 12)),
          Text(value, style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPostsFeed() {
    if (!_postsLoaded && !_isLoadingPosts) {
      Future.microtask(() => _loadUserPosts());
    }

    if (_isLoadingPosts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(color: Color(0xFFBEC2FF)),
        ),
      );
    }

    if (_posts.isEmpty) {
      return _buildPlaceholderFeed('No Posts Shared Yet');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(
                      _user.avatar != null && _user.avatar!.isNotEmpty
                          ? _user.avatar!
                          : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_user.displayName, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('${index + 1}h ago', style: GoogleFonts.inter(color: const Color(0xFFC6C5D7), fontSize: 10)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(post.content, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, height: 1.45)),
              PostAttachmentsWidget(post: post),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 14),
                  const SizedBox(width: 4),
                  Text('${post.likes}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(width: 16),
                  const Icon(Icons.chat_bubble_rounded, color: Color(0xFFBEC2FF), size: 14),
                  const SizedBox(width: 4),
                  Text('${post.comments}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderFeed(String text) {
    return Center(
      child: Text(text, style: GoogleFonts.inter(color: const Color(0xFFC6C5D7), fontSize: 13)),
    );
  }
}

class _BreathingVTag extends StatefulWidget {
  final String level;
  final VoidCallback? onTap;

  const _BreathingVTag({
    Key? key,
    required this.level,
    this.onTap,
  }) : super(key: key);

  @override
  State<_BreathingVTag> createState() => _BreathingVTagState();
}

class _BreathingVTagState extends State<_BreathingVTag> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.15, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _startPeriodicTimer();
  }

  void _startPeriodicTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return false;
      _controller.forward(from: 0.0);
      return true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String checkIcon = '✓';

    switch (widget.level.toLowerCase()) {
      case 'diamond':
        badgeColor = const Color(0xFFE2E8F0);
        break;
      case 'gold':
        badgeColor = const Color(0xFFFFB020);
        break;
      case 'purple':
        badgeColor = const Color(0xFF8B5CFF);
        break;
      case 'blue':
      default:
        badgeColor = const Color(0xFF00C2FF);
        break;
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: 'Verified ${widget.level.toUpperCase()}',
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badgeColor.withOpacity(0.2),
              border: Border.all(color: badgeColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                )
              ],
            ),
            child: Center(
              child: Text(
                checkIcon,
                style: TextStyle(
                  color: widget.level.toLowerCase() == 'diamond' ? Colors.cyanAccent : badgeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
