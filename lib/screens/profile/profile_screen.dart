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
import '../../widgets/custom_avatar_frame.dart';

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
    UserProfileCacheManager.addListener(_onProfileCacheChanged);
    _loadUserProfile();
    if (!_isMe) {
      _checkFollowingStatus();
    }
  }

  @override
  void dispose() {
    UserProfileCacheManager.removeListener(_onProfileCacheChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onProfileCacheChanged() {
    if (!mounted) return;
    final profileId = _isMe ? UserProfileCacheManager.currentUserId : widget.visitorUser!.id;
    final updatedUser = UserProfileCacheManager.getCachedUser(profileId);
    if (updatedUser != null) {
      setState(() {
        _user = updatedUser;
      });
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

  Color _resolveProfileBackgroundColor() {
    final theme = _user.membershipAssets['profile_theme'];
    if (theme == 'royal_blue') {
      return const Color(0xFF0F1E36);
    } else if (theme == 'amethyst_purple') {
      return const Color(0xFF1B0F36);
    } else if (theme == 'astral_blue') {
      return const Color(0xFF0E1A2F);
    }
    return const Color(0xFF11131C);
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
        if (_isMe) {
          await UserProfileCacheManager.forceLogout(
            message: "Your account is unavailable. Please sign in again or contact support."
          );
          return;
        }
        setState(() {
          _isLoadingProfile = false;
          _errorMessage = 'Profile row not found in database.';
        });
        return;
      }

      // Validate ban/suspension status for active user
      final status = profileData['status'] as String?;
      final isBanned = profileData['is_banned'] as bool? ?? false;
      final banReason = profileData['ban_reason'] as String?;

      if (_isMe && (status == 'suspended' || status == 'banned' || isBanned)) {
        await UserProfileCacheManager.forceLogout(
          message: banReason != null && banReason.isNotEmpty
              ? "Your account has been suspended. Reason: $banReason"
              : "Your account has been suspended.",
        );
        return;
      }

      final Map<String, dynamic> mergedData = Map<String, dynamic>.from(profileData);
      mergedData['silverCoins'] = walletData != null ? (walletData['coins_balance'] ?? 0) : 0;

      setState(() {
        _user = User.fromJson(mergedData);
        if (_isMe) {
          UserProfileCacheManager.setCurrentUser(_user);
        } else {
          UserProfileCacheManager.rxCache[_user.id] = _user;
        }
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

    final String? bgEffectUrl = _user.membershipAssets['background_effect'];

    return Scaffold(
      backgroundColor: _resolveProfileBackgroundColor(),
      body: Container(
        decoration: BoxDecoration(
          image: bgEffectUrl != null && bgEffectUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(bgEffectUrl),
                  fit: BoxFit.cover,
                  opacity: 0.15,
                )
              : null,
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadUserProfile();
            _checkFollowingStatus();
          },
          child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                // Centered Avatar Stack
                Positioned(
                  bottom: -55,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CustomAvatarFrame(
                          userId: _user.id,
                          username: _user.username,
                          size: (_user.avatarFrame != null && _user.avatarFrame!.isNotEmpty && _user.avatarFrame != 'none' && _user.avatarFrame != 'normal') || _user.vipLevel > 0 || _user.novelLevel > 0 ? 112 : 96,
                          defaultVipLevel: _user.vipLevel,
                          defaultNovelLevel: _user.novelLevel,
                          showBadges: false,
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: const Color(0xFF11131C),
                            child: OptimizedImage(
                              imageUrl: _user.avatar != null && _user.avatar!.isNotEmpty
                                  ? _user.avatar!
                                  : 'https://lh3.googleusercontent.com/aida-public/AB6AXuCybH5Mu5-PZ_dMHWuWFu9UFqwNpHtc79GaJ1SCz5v_bdFVOBIBr6-Cbgapb6sfnES7omhgh6mLz1FBQpMfCdnTcBsYtqmihxZELjY4zaJAwKYf6bU-AtUsm-WZRdG9uAznurNgCeHKjz02JXnJcB3olfo16_NN_dQPu_losBj6pac8-KtnTIXZREq6hInG6VPAEfdXysXJ11taDrh7Te-i-xDA02rAOPFka-22raXdTq9vSpH1pBr5u3Wsl9JF1x6b8CiVtPwIoSmu',
                              quality: ImageQuality.thumbnail,
                              borderRadius: BorderRadius.circular(48),
                              width: 96,
                              height: 96,
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 64),

            // Profile info block
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // First Row: Username (Bold, Primary Focus, 18 px)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _user.displayName,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _user.gender == 'female' ? Icons.female_rounded : Icons.male_rounded,
                        color: _user.gender == 'female' ? const Color(0xFFF472B6) : const Color(0xFF60A5FA),
                        size: 16,
                      ),
                      if (_isMe) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => Get.to(() => const ProfileCustomizationScreen()),
                          child: const Icon(Icons.edit_rounded, color: Colors.white70, size: 14),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Second Row: User ID (Smaller, 13 px, Secondary text)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _user.sid));
                      Get.snackbar('Copied', 'ID copied to clipboard.');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ID: ${_user.sid}',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.content_copy_rounded,
                            color: Colors.white54,
                            size: 11,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Third Row: Identity Tag Bar (5 tags in 1 row, max width 320)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: buildTagLightsWidget(generateDynamicTagLights(_user), context),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Fourth Row: Official Status Tag (Automatic priority role/verified tag)
                  buildOfficialStatusRow(_user, context),
                  const SizedBox(height: 6),

                  // Fifth Row: Badge Showcase (with mockup container styling)
                  buildBadgesShowcaseWidget(_user.showcasedBadges, context),
                  const SizedBox(height: 8),

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
    final tagSystem = user.tagSystem;

    if (tagSystem != null) {
      for (var t in tagSystem.identityTagBar) {
        final label = t.value;
        final type = t.type;
        Color color = const Color(0xFFBEC2FF);
        Gradient? gradient;
        IconData? icon;

        if (type == 'id_level') {
          color = const Color(0xFF3B82F6);
          gradient = const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
          icon = Icons.star_rounded;
        } else if (type == 'community') {
          color = const Color(0xFFEC4899);
          gradient = const LinearGradient(
            colors: [Color(0xFFF472B6), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
          icon = Icons.favorite_rounded;
        } else if (type == 'vip') {
          color = const Color(0xFF3B82F6);
          gradient = const LinearGradient(
            colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
          icon = Icons.diamond_rounded;
        } else if (type == 'noble') {
          color = const Color(0xFFD97706);
          gradient = const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
          icon = Icons.workspace_premium_rounded;
        } else if (type == 'special') {
          color = const Color(0xFF8B5CF6);
          gradient = const LinearGradient(
            colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
          icon = Icons.star_border_rounded;
        }

        tags.add({
          'label': label,
          'color': color,
          'gradient': gradient,
          'icon': icon,
          'imageUrl': t.imageUrl,
        });
      }
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
      final imageUrl = tag['imageUrl'] as String?;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        Widget imgWidget;
        if (imageUrl.startsWith('asset://')) {
          imgWidget = Image.asset(
            imageUrl.replaceAll('asset://', ''),
            height: 19,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildTextTagFallback(label, tag),
          );
        } else {
          String? localAsset;
          if (imageUrl.contains('vip_1_tag.png')) {
            localAsset = 'assets/identity_tags/vip_level_1.png';
          } else if (imageUrl.contains('vip_2_tag.png')) {
            localAsset = 'assets/identity_tags/vip_level_2.png';
          }

          if (localAsset != null) {
            imgWidget = Image.asset(
              localAsset,
              height: 19,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildTextTagFallback(label, tag),
            );
          } else {
            imgWidget = Image.network(
              imageUrl,
              height: 19,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildTextTagFallback(label, tag),
            );
          }
        }
        return Tooltip(
          message: 'Identity Tag: $label',
          child: imgWidget,
        );
      }

      final color = tag['color'] as Color;
      final gradient = tag['gradient'] as Gradient?;
      final icon = tag['icon'] as IconData?;

      Color bg = color.withOpacity(0.12);
      Color borderCol = color.withOpacity(0.4);
      Color textCol = color;

      if (gradient != null) {
        borderCol = color;
        textCol = Colors.white;
      }

      return Tooltip(
        message: 'Identity Tag: $label',
        child: GestureDetector(
          onTap: () {
            Get.snackbar('Tag Info', 'Details page for $label tag (coming soon).');
          },
          child: Container(
            height: 19,
            padding: const EdgeInsets.symmetric(horizontal: 8),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: textCol, size: 9),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: textCol,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
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

  Widget _buildTextTagFallback(String label, Map<String, dynamic> tag) {
    final color = tag['color'] as Color? ?? const Color(0xFFBEC2FF);
    final gradient = tag['gradient'] as Gradient?;
    final icon = tag['icon'] as IconData?;

    Color bg = color.withOpacity(0.12);
    Color borderCol = color.withOpacity(0.4);
    Color textCol = color;

    if (gradient != null) {
      borderCol = color;
      textCol = Colors.white;
    }

    return Tooltip(
      message: 'Identity Tag: $label',
      child: GestureDetector(
        onTap: () {
          Get.snackbar('Tag Info', 'Details page for $label tag (coming soon).');
        },
        child: Container(
          height: 19,
          padding: const EdgeInsets.symmetric(horizontal: 8),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: textCol, size: 9),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: textCol,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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


  Widget buildOfficialStatusRow(User user, BuildContext context) {
    final status = user.tagSystem?.officialStatus;
    
    // Fallback if tagSystem is not loaded yet
    if (status == null) {
      return const SizedBox.shrink();
    }

    final List<Widget> widgets = [];

    if (status.verifiedTag != null && status.verifiedTag!.isNotEmpty) {
      widgets.add(_buildSingleStatusBadge(status.verifiedTag!, isRole: false));
    }

    if (status.roleTag != null && status.roleTag!.isNotEmpty) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(width: 8));
      widgets.add(_buildSingleStatusBadge(status.roleTag!, isRole: true));
    }

    if (widgets.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: widgets,
    );
  }

  Widget _buildSingleStatusBadge(String label, {required bool isRole}) {
    Gradient gradient;
    Color borderColor;
    IconData icon;

    if (!isRole) {
      // Verified Tag
      gradient = const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
      );
      borderColor = const Color(0xFF3B82F6).withOpacity(0.5);
      icon = Icons.verified_user_rounded;
    } else {
      // Role Tag
      gradient = const LinearGradient(
        colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
      );
      borderColor = const Color(0xFF8B5CF6).withOpacity(0.5);
      icon = Icons.shield_rounded;
    }

    return Container(
      height: 19,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: gradient,
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBadgesShowcaseWidget(List<String> activeBadgesList, BuildContext context) {
    final custCtrl = Get.find<CustomizationController>();
    final badgesToUse = activeBadgesList;
    if (badgesToUse.isEmpty) return const SizedBox.shrink();

    final displayList = badgesToUse.length > 6 
        ? badgesToUse.take(5).toList() 
        : badgesToUse;
    final extraCount = badgesToUse.length > 6 ? badgesToUse.length - 5 : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...displayList.map((bName) {
            final meta = custCtrl.badgeMetadata[bName] ?? {'icon': '🏅', 'rarity': 'Common'};
            final iconStr = meta['icon'] as String? ?? '🏅';
            final rarity = meta['rarity'] as String? ?? 'Common';
            
            Color glowColor = const Color(0xFFFFB020);
            if (rarity == 'Legendary') {
              glowColor = const Color(0xFFFFD700);
            } else if (rarity == 'Mythic') {
              glowColor = const Color(0xFFEF4444);
            } else if (rarity == 'Epic') {
              glowColor = const Color(0xFF8B5CFF);
            } else if (rarity == 'Rare') {
              glowColor = const Color(0xFF3B82F6);
            }

            return Tooltip(
              message: '$bName Badge ($rarity)',
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                  border: Border.all(color: glowColor, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(0.15),
                      blurRadius: 4,
                      spreadRadius: 0.5,
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    iconStr,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            );
          }).toList(),
          if (extraCount > 0) ...[
            Tooltip(
              message: '$extraCount more badges',
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                  border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.0),
                ),
                child: Center(
                  child: Text(
                    '+$extraCount',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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
