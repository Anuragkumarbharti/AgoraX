import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/storage/isar_storage_service.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/user/user_model.dart';
import '../../models/community/post_model.dart';
import '../../models/community/question_model.dart';
import '../settings/settings_screen.dart';
import './gifting_contribution_screen.dart';
import '../../widgets/community/post_attachments_widget.dart';
import '../../widgets/profile/custom_avatar_frame.dart';
import '../../widgets/common/network_error_widget.dart';
import '../../widgets/skeletons/profile_skeleton_widget.dart';
import '../../core/api_error_handler.dart';
import '../../utils/number_formatter.dart';

import '../../services/store/store_controller.dart';
import '../../services/memberships/vip_controller.dart';
import '../../services/memberships/novel_controller.dart';
import '../../services/user/customization_controller.dart';
import '../../services/vault/study_category_controller.dart';
import '../../services/progression/career_progression_controller.dart';
import '../../services/user/premium_identity_controller.dart';
import '../../services/vault/study_vault_controller.dart';
import '../../services/user/user_profile_cache_manager.dart';
import '../../services/user/user_progress_sync_service.dart';
import '../../services/chat/chat_controller.dart';
import '../store/store_home_screen.dart';
import '../study_vault/study_vault_home_screen.dart';
import '../vault/creania_vault_home_screen.dart';
import '../study_vault/my_library_screen.dart';
import '../study_vault/seller_dashboard_screen.dart';
import '../study_vault/admin_vault_panel_screen.dart';
import '../study_vault/membership_center_screen.dart';
import '../vip/vip_purchase_screen.dart';
import '../novel/novel_purchase_screen.dart';
import '../career/career_hub_screen.dart';
import '../events/wallet_screen.dart';
import '../../widgets/gifting/send_gift_dialog.dart';
import '../../widgets/common/optimized_image.dart';
import '../../services/storage/asset_cache_manager.dart';
import './profile_customization_screen.dart';
import './daily_task_screen.dart';
import './badges_screen.dart';
import './account_center_screen.dart';
import './connections_screen.dart';
import './edit_profile_screen.dart';
import '../chat/chat_screen.dart';
import '../../models/room/room_model.dart';
import '../../models/community/community_model.dart';
import '../rooms/voice_room_call_screen.dart';
import '../communities/community_detail_screen.dart';
import '../home/main_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key, this.visitorUser}) : super(key: key);

  final User? visitorUser;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final StoreController _storeCtrl = Get.find<StoreController>();
  final VipController _vipCtrl = Get.find<VipController>();
  final NovelController _novelCtrl = Get.find<NovelController>();
  final CustomizationController _custCtrl = Get.find<CustomizationController>();
  final StudyCategoryController _studyCtrl =
      Get.find<StudyCategoryController>();
  final CareerProgressionController _careerCtrl =
      Get.find<CareerProgressionController>();

  late TabController _tabController;
  User? _userNullable; // nullable to track initialization
  bool _isUserInitialized = false;
  User get _user => _userNullable!;
  set _user(User u) {
    _userNullable = u;
    _isUserInitialized = true;
  }

  bool _isLoadingProfile = true;
  String? _errorMessage;
  bool _isFollowing = false;
  bool _isBlocked = false;
  bool _postsLoaded = false;
  bool _isLoadingPosts = false;

  final List<Post> _posts = [];
  final List<Question> _questions = [];
  final List<Map<String, dynamic>> _communities = [];

  // Reactive state lists for offline-first caching
  final RxList<VoiceRoom> _myArenas = <VoiceRoom>[].obs;
  final RxList<Map<String, dynamic>> _joinedCommunities =
      <Map<String, dynamic>>[].obs;
  final RxBool _isLoadingArenas = true.obs;
  final RxBool _isLoadingJoinedCommunities = true.obs;

  // Gift stats reactive variables
  final RxDouble _giftLifetimeReceived = 0.0.obs;
  final RxDouble _giftLifetimeSent = 0.0.obs;
  final RxDouble _giftMonthlyReceived = 0.0.obs;
  final RxDouble _giftMonthlySent = 0.0.obs;
  final RxList<String> _giftRecentReceivedAvatars = <String>[].obs;
  final RxList<String> _giftRecentSentAvatars = <String>[].obs;
  final RxBool _isLoadingGiftStats = true.obs;

  late final Worker _giftStatsWorker;

  bool get _isMe =>
      widget.visitorUser == null ||
      widget.visitorUser!.id == UserProfileCacheManager.currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    UserProfileCacheManager.addListener(_onProfileCacheChanged);

    // Pre-initialize _user from the visitor user or cached profile for safety
    if (widget.visitorUser != null) {
      _user = widget.visitorUser!;
    } else {
      final cached = UserProfileCacheManager.currentUser;
      if (cached != null) _user = cached;
    }

    _loadUserProfile();

    // Trigger offline-first cached fetches immediately, fresh in background
    _fetchUserArenasBackground();
    _fetchUserJoinedCommunitiesBackground();
    _fetchGiftStatsBackground();

    if (!_isMe) {
      _checkFollowingStatus();
    }

    // Reactively refresh gift stats on new realtime transactions
    _giftStatsWorker =
        ever(UserProfileCacheManager.giftTransactionsTrigger, (_) {
      debugPrint(
          '[ProfileScreen] Realtime gift transaction event triggered cache refresh.');
      _fetchGiftStatsBackground();
      _loadUserProfile();
    });
  }

  @override
  void dispose() {
    UserProfileCacheManager.removeListener(_onProfileCacheChanged);
    _giftStatsWorker.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Offline-First Smart Data Fetchers

  Future<void> _fetchUserArenasBackground() async {
    final profileId =
        _isMe ? UserProfileCacheManager.currentUserId : widget.visitorUser!.id;
    if (profileId.isEmpty) return;

    // 1. Load from Isar Cache
    try {
      final cachedList = await IsarStorageService.to.getCacheList<VoiceRoom>(
        'my_arenas_cache:$profileId',
        (json) => VoiceRoom.fromJson(json),
      );
      if (cachedList != null) {
        _myArenas.assignAll(cachedList);
        _isLoadingArenas.value = false;
      }
    } catch (e) {
      debugPrint('Error loading cached arenas: $e');
    }

    // 2. Fetch fresh background
    try {
      final response = await Supabase.instance.client
          .from('rooms')
          .select()
          .eq('host_id', profileId)
          .neq('status', 'ended');

      final List<VoiceRoom> loaded = [];
      if (response != null) {
        for (final item in response as List) {
          loaded.add(VoiceRoom.fromJson(item));
        }
      }

      _myArenas.assignAll(loaded);
      _isLoadingArenas.value = false;

      // Save cache
      await IsarStorageService.to.saveCacheList<VoiceRoom>(
        'my_arenas_cache:$profileId',
        loaded,
        (room) => room.toJson(),
      );
    } catch (e) {
      debugPrint('Error background fetching user arenas: $e');
      _isLoadingArenas.value = false;
    }
  }

  Future<void> _fetchUserJoinedCommunitiesBackground() async {
    final profileId =
        _isMe ? UserProfileCacheManager.currentUserId : widget.visitorUser!.id;
    if (profileId.isEmpty) return;

    // 1. Load from Isar Cache
    try {
      final cachedPayload = await IsarStorageService.to
          .getCacheEntryPayload('joined_communities_cache:$profileId');
      if (cachedPayload != null && cachedPayload.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedPayload);
        final List<Map<String, dynamic>> results = [];
        for (final row in decoded) {
          final role = row['role'] as String;
          final community =
              Community.fromJson(row['community'] as Map<String, dynamic>);
          results.add({
            'role': role,
            'community': community,
          });
        }
        _joinedCommunities.assignAll(results);
        _isLoadingJoinedCommunities.value = false;
      }
    } catch (e) {
      debugPrint('Error loading cached communities: $e');
    }

    // 2. Fetch fresh background
    try {
      final response = await Supabase.instance.client
          .from('community_memberships')
          .select('role, communities(*)')
          .eq('user_id', profileId);

      if (response != null) {
        final List<Map<String, dynamic>> results = [];
        final List<Map<String, dynamic>> cacheList = [];
        for (final row in response as List<dynamic>) {
          final role = row['role'] as String? ?? 'member';
          final communityData = row['communities'];
          if (communityData != null) {
            final community =
                Community.fromJson(communityData as Map<String, dynamic>);
            results.add({
              'role': role,
              'community': community,
            });
            cacheList.add({
              'role': role,
              'community': community.toJson(),
            });
          }
        }
        _joinedCommunities.assignAll(results);
        _isLoadingJoinedCommunities.value = false;

        // Save cache
        await IsarStorageService.to.saveCacheEntry(
          'joined_communities_cache:$profileId',
          jsonEncode(cacheList),
        );
      }
    } catch (e) {
      debugPrint('Error background fetching user joined communities: $e');
      _isLoadingJoinedCommunities.value = false;
    }
  }

  Future<void> _fetchGiftStatsBackground() async {
    final profileId =
        _isMe ? UserProfileCacheManager.currentUserId : widget.visitorUser!.id;
    if (profileId.isEmpty) return;

    // 1. Load from Isar Cache
    try {
      final cachedPayload = await IsarStorageService.to
          .getCacheEntryPayload('gift_stats_cache:$profileId');
      if (cachedPayload != null && cachedPayload.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(cachedPayload);
        _giftLifetimeReceived.value =
            (decoded['lifetime_received'] as num?)?.toDouble() ?? 0.0;
        _giftLifetimeSent.value =
            (decoded['lifetime_sent'] as num?)?.toDouble() ?? 0.0;
        _giftMonthlyReceived.value =
            (decoded['monthly_received'] as num?)?.toDouble() ?? 0.0;
        _giftMonthlySent.value =
            (decoded['monthly_sent'] as num?)?.toDouble() ?? 0.0;
        _giftRecentReceivedAvatars.assignAll(
            List<String>.from(decoded['recent_received_avatars'] ?? []));
        _giftRecentSentAvatars
            .assignAll(List<String>.from(decoded['recent_sent_avatars'] ?? []));
        _isLoadingGiftStats.value = false;
      }
    } catch (e) {
      debugPrint('Error loading cached gift stats: $e');
    }

    // 2. Fetch fresh background
    try {
      final response = await Supabase.instance.client
          .rpc('get_user_gift_stats_v2', params: {'p_user_id': profileId});

      if (response != null) {
        final Map<String, dynamic> stats = Map<String, dynamic>.from(response);

        // Calculate actual stars received from transactions
        double actualReceived = 0.0;
        try {
          final receivedData = await Supabase.instance.client
              .from('gift_transactions')
              .select('stars_value')
              .eq('receiver_id', profileId);
          if (receivedData != null) {
            for (final item in receivedData as List<dynamic>) {
              actualReceived +=
                  (item['stars_value'] as num?)?.toDouble() ?? 0.0;
            }
          }
        } catch (e) {
          debugPrint('Error calculating actual received stars: $e');
          actualReceived =
              (stats['lifetime_received'] as num?)?.toDouble() ?? 0.0;
        }

        // Calculate actual gold coins sent from transactions
        double actualSentGold = 0.0;
        try {
          final sentData = await Supabase.instance.client
              .from('gift_transactions')
              .select('stars_value, gift_catalog(currency)')
              .eq('sender_id', profileId);
          if (sentData != null) {
            for (final item in sentData as List<dynamic>) {
              final catalog = item['gift_catalog'];
              final currency =
                  catalog != null ? catalog['currency'] as String? : 'gold';
              if (currency == 'gold') {
                actualSentGold +=
                    (item['stars_value'] as num?)?.toDouble() ?? 0.0;
              }
            }
          }
        } catch (e) {
          debugPrint('Error calculating actual sent gold: $e');
          actualSentGold = (stats['lifetime_sent'] as num?)?.toDouble() ?? 0.0;
        }

        _giftLifetimeReceived.value = actualReceived;
        _giftLifetimeSent.value = actualSentGold;
        _giftMonthlyReceived.value =
            (stats['monthly_received'] as num?)?.toDouble() ?? 0.0;
        _giftMonthlySent.value =
            (stats['monthly_sent'] as num?)?.toDouble() ?? 0.0;
        _giftRecentReceivedAvatars.assignAll(
            List<String>.from(stats['recent_received_avatars'] ?? []));
        _giftRecentSentAvatars
            .assignAll(List<String>.from(stats['recent_sent_avatars'] ?? []));
        _isLoadingGiftStats.value = false;

        // Save cache
        final Map<String, dynamic> cacheStats = {
          'lifetime_received': actualReceived,
          'lifetime_sent': actualSentGold,
          'monthly_received': stats['monthly_received'],
          'monthly_sent': stats['monthly_sent'],
          'recent_received_avatars': stats['recent_received_avatars'],
          'recent_sent_avatars': stats['recent_sent_avatars'],
        };
        await IsarStorageService.to.saveCacheEntry(
            'gift_stats_cache:$profileId', jsonEncode(cacheStats));
      }
    } catch (e) {
      debugPrint('Error background fetching gift stats RPC: $e');
      _isLoadingGiftStats.value = false;
    }
  }

  void _onProfileCacheChanged() {
    if (!mounted) return;
    final profileId =
        _isMe ? UserProfileCacheManager.currentUserId : widget.visitorUser!.id;
    final updated = UserProfileCacheManager.rxCache[profileId];
    if (updated != null) {
      setState(() {
        _user = updated;
      });
      // Re-trigger background updates silently
      _fetchUserArenasBackground();
      _fetchUserJoinedCommunitiesBackground();
      _fetchGiftStatsBackground();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) {
      return context.scaffoldBackgroundColor;
    }
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

    final profileId =
        _isMe ? UserProfileCacheManager.currentUserId : widget.visitorUser!.id;

    // Try loading from cache first for immediate UI display
    final cached = UserProfileCacheManager.getCachedUser(profileId);
    if (cached != null) {
      _user = cached;
      _isLoadingProfile = false;
    } else {
      setState(() {
        _isLoadingProfile = true;
        _errorMessage = null;
      });
    }

    try {
      final fetchedData =
          await ApiErrorHandler.executeWithRetry<Map<String, dynamic>?>(
              () async {
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

        if (profileData == null) return null;

        final Map<String, dynamic> merged =
            Map<String, dynamic>.from(profileData);
        merged['silverCoins'] =
            walletData != null ? (walletData['coins_balance'] ?? 0) : 0;
        return merged;
      });

      if (fetchedData == null) {
        if (_isMe) {
          await UserProfileCacheManager.forceLogout(
              message:
                  "Your account is unavailable. Please sign in again or contact support.");
          return;
        }
        if (mounted) {
          setState(() {
            _isLoadingProfile = false;
            _errorMessage = 'Profile unavailable.';
          });
        }
        return;
      }

      // Validate ban/suspension status for active user
      final status = fetchedData['status'] as String?;
      final isBanned = fetchedData['is_banned'] as bool? ?? false;
      final banReason = fetchedData['ban_reason'] as String?;

      if (_isMe && (status == 'suspended' || status == 'banned' || isBanned)) {
        await UserProfileCacheManager.forceLogout(
          message: banReason != null && banReason.isNotEmpty
              ? "Your account has been suspended. Reason: $banReason"
              : "Your account has been suspended.",
        );
        return;
      }

      // Sync VIP and Customization Controllers in background to ensure all assets are synchronized
      if (_isMe) {
        _vipCtrl.loadVipFromDatabase();
        _custCtrl.fetchFullInventoryAndEntitlementsViaRpc();
      }

      if (!mounted) return;
      setState(() {
        _user = User.fromJson(fetchedData);
        if (_isMe) {
          UserProfileCacheManager.setCurrentUser(_user);
        } else {
          UserProfileCacheManager.rxCache[_user.id] = _user;
        }
        _isLoadingProfile = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('[ProfileScreen] Profile fetch exception: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
        if (!_isUserInitialized) {
          _errorMessage = ApiErrorHandler.parseError(e);
        }
      });
    }
  }

  Future<List<VoiceRoom>> _fetchUserArenas() async {
    try {
      final response = await Supabase.instance.client
          .from('rooms')
          .select()
          .eq('host_id', _user.id)
          .neq('status', 'ended');

      if (response == null) return [];
      final list = response as List<dynamic>;
      return list
          .map((item) => VoiceRoom.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching user arenas: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUserJoinedCommunities() async {
    try {
      final response = await Supabase.instance.client
          .from('community_memberships')
          .select('role, communities(*)')
          .eq('user_id', _user.id);

      if (response == null) return [];
      final List<Map<String, dynamic>> results = [];
      for (final row in response as List<dynamic>) {
        final role = row['role'] as String? ?? 'member';
        final communityData = row['communities'];
        if (communityData != null) {
          final community =
              Community.fromJson(communityData as Map<String, dynamic>);
          results.add({
            'role': role,
            'community': community,
          });
        }
      }
      return results;
    } catch (e) {
      debugPrint('Error fetching user joined communities: $e');
      return [];
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'technology':
      case 'tech':
      case 'code':
        return Icons.code_rounded;
      case 'architecture':
        return Icons.architecture_rounded;
      case 'education':
      case 'study':
        return Icons.menu_book_rounded;
      case 'gaming':
        return Icons.sports_esports_rounded;
      case 'music':
        return Icons.music_note_rounded;
      default:
        return Icons.group_work_rounded;
    }
  }

  Color _getCategoryColor(int index) {
    final colors = [
      const Color(0xFFBEC2FF),
      const Color(0xFFDDB7FF),
      const Color(0xFFFBBF24),
      const Color(0xFF10B981),
      const Color(0xFFEF4444),
    ];
    return colors[index % colors.length];
  }

  String _formatCount(num count) {
    return formatCompactNumber(count);
  }

  Future<void> _loadUserPosts() async {
    if (_postsLoaded || _isLoadingPosts) return;
    if (!mounted) return;
    setState(() {
      _isLoadingPosts = true;
    });
    try {
      final profileId = _isMe
          ? UserProfileCacheManager.currentUserId
          : widget.visitorUser!.id;
      final postsResponse = await Supabase.instance.client
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(username, avatar_url)')
          .eq('user_id', profileId)
          .order('created_at', ascending: false);

      List<Post> fetchedPosts = [];
      if (postsResponse != null) {
        final List<dynamic> list = postsResponse as List<dynamic>;
        fetchedPosts = list
            .map((item) => Post.fromJson(item as Map<String, dynamic>))
            .toList();
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
        Get.snackbar(
            'Gift Sent 🎁', 'You sent $giftName to ${_user.displayName}!');
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
              title: const Text('Share Profile',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                Share.share(
                    'Check out ${_user.displayName}\'s profile on Creaniaa: https://creaniaa.com/user/${_user.username}');
              },
            ),
            ListTile(
              leading: Icon(Icons.block_rounded,
                  color: _isBlocked ? Colors.green : Colors.redAccent),
              title: Text(_isBlocked ? 'Unblock User' : 'Block User',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                setState(() => _isBlocked = !_isBlocked);
                Get.snackbar(_isBlocked ? 'Blocked 🚫' : 'Unblocked 🟢',
                    'User has been ${_isBlocked ? 'blocked' : 'unblocked'}.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem_rounded,
                  color: Colors.orangeAccent),
              title: const Text('Report User',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                Get.snackbar('Report Submitted ⚠️',
                    'Thank you for keeping Creaniaa safe. Our moderation team will review this profile.');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile || !_isUserInitialized) {
      return const ProfileSkeletonWidget();
    }

    if (_errorMessage != null) {
      return NetworkErrorStateWidget(
        message: _errorMessage,
        onRetry: _loadUserProfile,
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
                // 1. Cover Photo & Header Section with Curved Divider
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Curve Shadow Layer
                    Positioned.fill(
                      child: CustomPaint(
                        painter: ProfileHeaderCurveShadowPainter(
                          shadowColor: Colors.black,
                        ),
                      ),
                    ),

                    // Clipped Cover Banner Container
                    Obx(() {
                      final profileId = _isMe
                          ? UserProfileCacheManager.currentUserId
                          : (widget.visitorUser?.id ?? _user.id);
                      final liveUser =
                          UserProfileCacheManager.rxCache[profileId] ??
                              (_isMe
                                  ? UserProfileCacheManager.currentUser
                                  : null) ??
                              _user;

                      final String rawCover = (liveUser.coverPhoto != null &&
                              liveUser.coverPhoto!.isNotEmpty &&
                              !liveUser.coverPhoto!
                                  .contains('lh3.googleusercontent.com'))
                          ? liveUser.coverPhoto!
                          : 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809';
                      final String optimizedCover =
                          AssetCacheManager.getOptimizedUrl(
                              rawCover, ImageQuality.medium);

                      final double screenHeight = MediaQuery.of(context).size.height;
                      final double dynamicHeaderHeight = screenHeight * 0.50 + 15.0;

                      return ClipPath(
                        clipper: ProfileHeaderCurveClipper(),
                        child: Container(
                          width: double.infinity,
                          constraints: BoxConstraints(
                            minHeight: dynamicHeaderHeight,
                          ),
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: CachedNetworkImageProvider(
                                optimizedCover,
                                cacheManager: CreaniaAssetCacheManager.instance,
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.only(
                                top: 40, left: 16, right: 16, bottom: 20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.35),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.20),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // App bar buttons
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (!_isMe)
                                      GestureDetector(
                                        onTap: () {
                                          if (Navigator.canPop(context)) {
                                            Navigator.pop(context);
                                          } else {
                                            Get.offAll(
                                                () => const MainScreen());
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.35),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white
                                                    .withOpacity(0.15)),
                                          ),
                                          child: const Icon(
                                              Icons.arrow_back_rounded,
                                              color: Colors.white,
                                              size: 20),
                                        ),
                                      )
                                    else
                                      const SizedBox.shrink(),
                                    if (_isMe)
                                      GestureDetector(
                                        onTap: () => Get.to(
                                            () => const SettingsScreen()),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.35),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white
                                                    .withOpacity(0.15)),
                                          ),
                                          child: const Icon(
                                              Icons.settings_outlined,
                                              color: Colors.white,
                                              size: 20),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Overlapping elements group (Avatar frame, Username, ID, Tags, Status, Badges, Action buttons) shifted down together
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Centered Avatar Frame and Profile Photo
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        CustomAvatarFrame(
                                          userId: liveUser.id,
                                          username: liveUser.username,
                                          size: (liveUser.avatarFrame != null &&
                                                      liveUser.avatarFrame!
                                                          .isNotEmpty &&
                                                      liveUser.avatarFrame !=
                                                          'none' &&
                                                      liveUser.avatarFrame !=
                                                          'normal') ||
                                                  liveUser.vipLevel > 0 ||
                                                  liveUser.novelLevel > 0
                                              ? 112
                                              : 96,
                                          defaultVipLevel: liveUser.vipLevel,
                                          defaultNovelLevel: liveUser.novelLevel,
                                          showBadges: false,
                                          child: CircleAvatar(
                                            radius: 48,
                                            backgroundColor:
                                                const Color(0xFF11131C),
                                            child: OptimizedImage(
                                              imageUrl: (liveUser.avatar != null &&
                                                      liveUser.avatar!.isNotEmpty &&
                                                      !liveUser.avatar!.contains(
                                                          'lh3.googleusercontent.com'))
                                                  ? liveUser.avatar!
                                                  : 'https://api.dicebear.com/7.x/bottts/png?seed=${liveUser.username}',
                                              quality: ImageQuality.thumbnail,
                                              borderRadius:
                                                  BorderRadius.circular(48),
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
                                              border: Border.all(
                                                  color: const Color(0xFF11131C),
                                                  width: 2),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // First Row: Username (Bold, Primary Focus, 18 px)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            liveUser.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              color: context.textPrimary,
                                              fontSize: AppTypography.title,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: -0.4,
                                              shadows: [
                                                Shadow(
                                                  color:
                                                      Colors.black.withOpacity(0.3),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          liveUser.gender == 'female'
                                              ? Icons.female_rounded
                                              : Icons.male_rounded,
                                          color: liveUser.gender == 'female'
                                              ? const Color(0xFFF472B6)
                                              : const Color(0xFF60A5FA),
                                          size: AppDimensions.minIconSize,
                                        ),
                                        if (_isMe) ...[
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () => Get.to(() =>
                                                    const ProfileCustomizationScreen())
                                                ?.then((_) {
                                              UserProfileCacheManager
                                                  .fetchUserProfile(_user.id,
                                                      forceRefresh: true);
                                            }),
                                            child: Icon(Icons.edit_rounded,
                                                color: context.textSecondary,
                                                size: 14),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),

                                    // Second Row: User ID (Smaller, 13 px, Secondary text)
                                    GestureDetector(
                                      onTap: () {
                                        Clipboard.setData(
                                            ClipboardData(text: liveUser.sid));
                                        Get.snackbar(
                                            'Copied', 'ID copied to clipboard.');
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 5),
                                        decoration: BoxDecoration(
                                          color:
                                              context.surfaceColor.withOpacity(0.9),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                              color: context.borderColor,
                                              width: 1.0),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.04),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            )
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'ID: ${liveUser.sid}',
                                              style: GoogleFonts.poppins(
                                                color: context.textSecondary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.content_copy_rounded,
                                              color: context.textSecondary,
                                              size: 11,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    // Third Row: Identity Tag Bar (5 tags in 1 row, max width 320)
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 320),
                                      child: Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: buildTagLightsWidget(
                                            generateDynamicTagLights(liveUser),
                                            context),
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    // Fourth Row: Official Status Tag (Automatic priority role/verified tag)
                                    buildOfficialStatusRow(liveUser, context),
                                    const SizedBox(height: 6),

                                    // Fifth Row: Badge Showcase (with mockup container styling)
                                    buildBadgesShowcaseWidget(
                                        liveUser.showcasedBadges, context),
                                    const SizedBox(height: 12),

                                    // Action Buttons Row inside cover photo banner
                                    _buildActionButtonsRow(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),

                // Rest of the profile content starting on white canvas below the curved divider panel
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Social Stats Section (Followers, Following, Friends, Gifts)
                      _buildSocialStatsSection(),
                      const SizedBox(height: 16),
                      // 4. Bio & Links Section
                      _glassCard(
                        child: Obx(() {
                          final u = UserProfileCacheManager.rxCache[_user.id] ??
                              _user;
                          final bioText = u.bio != null && u.bio!.isNotEmpty
                              ? u.bio!
                              : 'No bio written yet.';
                          final locationText =
                              (u.city != null && u.city!.isNotEmpty)
                                  ? '${u.city}, ${u.country ?? ""}'
                                  : (u.country ?? 'N/A');
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bioText,
                                style: GoogleFonts.inter(
                                    color: context.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4),
                              ),
                              const SizedBox(height: 12),
                              _bioDetailRow(
                                  Icons.location_on_outlined, locationText),
                              const SizedBox(height: 6),
                              _bioDetailRow(Icons.language_rounded,
                                  u.language.toUpperCase()),
                              const SizedBox(height: 6),
                              _bioDetailRow(
                                  Icons.link_rounded,
                                  u.website != null && u.website!.isNotEmpty
                                      ? u.website!
                                      : 'N/A'),
                            ],
                          );
                        }),
                      ),
                      const SizedBox(height: 12),

                      // 5. Personal Info Section
                      _glassCard(
                        child: Obx(() {
                          final u = UserProfileCacheManager.rxCache[_user.id] ??
                              _user;
                          final dobStr = u.dob != null
                              ? DateFormat('dd MMM yyyy').format(u.dob!)
                              : 'N/A';
                          final ageStr = u.age > 0 ? '${u.age} years' : 'N/A';

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Personal Info',
                                  style: GoogleFonts.inter(
                                      color: context.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                              const SizedBox(height: 12),
                              _infoTableRow(
                                  'Gender',
                                  u.gender != null && u.gender!.isNotEmpty
                                      ? u.gender!.capitalizeFirst!
                                      : 'N/A'),
                              _infoTableRow('Age', ageStr),
                              _infoTableRow('Birthday', dobStr),
                              _infoTableRow(
                                  'Country',
                                  u.country != null && u.country!.isNotEmpty
                                      ? u.country!
                                      : 'N/A'),
                              _infoTableRow(
                                  'Language',
                                  u.language.isNotEmpty
                                      ? u.language.toUpperCase()
                                      : 'N/A'),
                              _infoTableRow(
                                  'Profession',
                                  u.profession != null &&
                                          u.profession!.isNotEmpty
                                      ? u.profession!
                                      : 'N/A'),
                              _infoTableRow(
                                  'Education',
                                  u.education != null && u.education!.isNotEmpty
                                      ? u.education!
                                      : 'N/A'),
                              _infoTableRow(
                                  'Website',
                                  u.website != null && u.website!.isNotEmpty
                                      ? u.website!
                                      : 'N/A',
                                  isLast: true),
                            ],
                          );
                        }),
                      ),
                      const SizedBox(height: 12),

                      // 6. My Arenas Section
                      _glassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('My Arenas',
                                style: GoogleFonts.inter(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                            const SizedBox(height: 12),
                            Obx(() {
                              if (_isLoadingArenas.value) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                );
                              }
                              if (_myArenas.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16.0),
                                    child: Text(
                                      'Not Created Any Arena Yet',
                                      style: GoogleFonts.inter(
                                          color: context.textSecondary,
                                          fontSize: 13),
                                    ),
                                  ),
                                );
                              }
                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _myArenas.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final room = _myArenas[index];
                                  final coverUrl = (room.banner != null &&
                                          room.banner!.isNotEmpty)
                                      ? room.banner!
                                      : (room.roomCoverUrl != null &&
                                              room.roomCoverUrl!.isNotEmpty)
                                          ? room.roomCoverUrl!
                                          : 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809';

                                  return GestureDetector(
                                    onTap: () {
                                      final currentUid =
                                          UserProfileCacheManager.currentUserId;
                                      final currentUsername =
                                          UserProfileCacheManager
                                                  .currentUser?.username ??
                                              'Creaniaa Student';
                                      Get.to(
                                        () => VoiceRoomCallScreen(
                                          roomId: room.id,
                                          roomName: room.name,
                                          userId: currentUid.isNotEmpty
                                              ? currentUid
                                              : 'uid_anurag_101',
                                          userName: currentUsername !=
                                                  'Creaniaa Student'
                                              ? currentUsername
                                              : 'anurag_kumar',
                                          isHost: room.hostId == currentUid,
                                        ),
                                      );
                                    },
                                    child: Container(
                                      height: 100,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        image: DecorationImage(
                                          image: NetworkImage(coverUrl),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          gradient: const LinearGradient(
                                            colors: [
                                              Colors.black87,
                                              Colors.transparent
                                            ],
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.redAccent
                                                        .withOpacity(0.2),
                                                    border: Border.all(
                                                        color: Colors.redAccent
                                                            .withOpacity(0.5)),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    room.hostId ==
                                                            UserProfileCacheManager
                                                                .currentUserId
                                                        ? 'OWNER'
                                                        : 'CO-OWNER',
                                                    style: const TextStyle(
                                                        color: Colors.redAccent,
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(room.name,
                                                    style: GoogleFonts.inter(
                                                        color: Colors.white,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${room.totalMembers} members' +
                                                      (room.isLive
                                                          ? '  •  ${room.participantCount} online'
                                                          : ''),
                                                  style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 10),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDDB7FF)
                                                    .withOpacity(0.2),
                                                border: Border.all(
                                                    color:
                                                        const Color(0xFFDDB7FF)
                                                            .withOpacity(0.5)),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text('lvl ${room.level}',
                                                  style: const TextStyle(
                                                      color: Color(0xFFDDB7FF),
                                                      fontSize: 10)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),
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
                                Text('Joined Communities',
                                    style: GoogleFonts.inter(
                                        color: context.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                                Obx(() => Text(
                                      '${_joinedCommunities.length}',
                                      style: TextStyle(
                                          color: context.primaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    )),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Obx(() {
                              if (_isLoadingJoinedCommunities.value) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                );
                              }
                              if (_joinedCommunities.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16.0),
                                    child: Text(
                                      'Not Joined Any Community Yet',
                                      style: GoogleFonts.inter(
                                          color: context.textSecondary,
                                          fontSize: 13),
                                    ),
                                  ),
                                );
                              }
                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _joinedCommunities.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final entry = _joinedCommunities[index];
                                  final Community c = entry['community'];
                                  final String role = entry['role'];

                                  return _communityRow(
                                    c.name,
                                    role,
                                    'Lvl ${c.level}',
                                    c.image,
                                    c.memberCount,
                                    onTap: () => Get.to(() =>
                                        CommunityDetailScreen(
                                            communityId: c.id)),
                                  );
                                },
                              );
                            }),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      context.primaryColor.withOpacity(0.08),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  Get.snackbar('Explore',
                                      'Browse more communities in Explore tab.');
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('More Communities',
                                        style: GoogleFonts.inter(
                                            color: context.primaryColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_rounded,
                                        color: context.primaryColor, size: 14),
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
                              _navItem(Icons.task_alt_rounded, 'Tasks',
                                  () => Get.to(() => const DailyTaskScreen())),
                              _navItem(Icons.work_outline_rounded, 'Career',
                                  () => Get.to(() => const CareerHubScreen())),
                              _navItem(Icons.account_balance_wallet_outlined,
                                  'Wallet', () => Get.to(() => WalletScreen())),
                              _navItem(Icons.storefront_outlined, 'Store',
                                  () => Get.to(() => const StoreHomeScreen())),
                              _navItem(Icons.emoji_events_outlined, 'Badges',
                                  () => Get.to(() => const BadgesScreen())),
                              _navItem(Icons.settings_outlined, 'Settings',
                                  () => Get.to(() => const SettingsScreen())),
                              _navItem(Icons.more_horiz_rounded, 'More',
                                  () => _showMoreOptionsSheet(context)),
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
                            Text('Achievements',
                                style: GoogleFonts.inter(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _achievementBadge(
                                      'VIP',
                                      Icons.diamond_outlined,
                                      const Color(0xFFFFDB3C)),
                                  const SizedBox(width: 12),
                                  _achievementBadge('Dev', Icons.code_rounded,
                                      const Color(0xFFBEC2FF)),
                                  const SizedBox(width: 12),
                                  _achievementBadge(
                                      'Host',
                                      Icons.mic_none_rounded,
                                      const Color(0xFFDDB7FF)),
                                  const SizedBox(width: 12),
                                  _achievementBadge(
                                      'Verified',
                                      Icons.verified_outlined,
                                      const Color(0xFF00F5FF)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 10. Gift Stats Section (Replaces Arena Stats & Old Gift Stats)
                      Obx(() {
                        final monthlyReceivedStr =
                            _formatCount(_giftMonthlyReceived.value.toInt()) +
                                ' ★';
                        final monthlySentStr =
                            _formatCount(_giftMonthlySent.value.toInt()) + ' ★';
                        final lifetimeReceivedStr =
                            _formatCount(_giftLifetimeReceived.value.toInt()) +
                                ' ★';
                        final lifetimeSentStr =
                            _formatCount(_giftLifetimeSent.value.toInt()) +
                                ' ★';

                        return _glassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Get.to(() => GiftingContributionScreen(
                                        userId: _user.id,
                                        username:
                                            _user.displayName ?? 'Student',
                                      ));
                                },
                                child: Row(
                                  children: [
                                    const Icon(Icons.featured_play_list_rounded,
                                        color: Color(0xFFFBBF24), size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Gift Stats',
                                      style: GoogleFonts.poppins(
                                        color: context.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Monthly received gifts',
                                    style: GoogleFonts.poppins(
                                        color: context.textSecondary,
                                        fontSize: 12.5),
                                  ),
                                  Text(
                                    monthlyReceivedStr,
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'monthly contribute',
                                    style: GoogleFonts.poppins(
                                        color: context.textSecondary,
                                        fontSize: 12.5),
                                  ),
                                  Text(
                                    monthlySentStr,
                                    style: GoogleFonts.poppins(
                                      color: context.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  Get.to(() => GiftingContributionScreen(
                                        userId: _user.id,
                                        username:
                                            _user.displayName ?? 'Student',
                                        initialTabIndex: 0,
                                      ));
                                },
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Gifts',
                                      style: GoogleFonts.poppins(
                                          color: context.textSecondary,
                                          fontSize: 12.5),
                                    ),
                                    Row(
                                      children: [
                                        if (_giftRecentReceivedAvatars
                                            .isNotEmpty)
                                          _buildOverlappingAvatars(
                                              _giftRecentReceivedAvatars
                                                  .toList())
                                        else
                                          _buildOverlappingAvatars([
                                            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=80',
                                            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80',
                                            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80',
                                            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=80',
                                          ]),
                                        const SizedBox(width: 6),
                                        Text(
                                          lifetimeReceivedStr,
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFF8B5CFF),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.5,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.chevron_right_rounded,
                                            color: context.textSecondary,
                                            size: 16),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  Get.to(() => GiftingContributionScreen(
                                        userId: _user.id,
                                        username:
                                            _user.displayName ?? 'Student',
                                        initialTabIndex: 1,
                                      ));
                                },
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Contributors',
                                      style: GoogleFonts.poppins(
                                          color: context.textSecondary,
                                          fontSize: 12.5),
                                    ),
                                    Row(
                                      children: [
                                        if (_giftRecentSentAvatars.isNotEmpty)
                                          _buildOverlappingAvatars(
                                              _giftRecentSentAvatars.toList())
                                        else
                                          _buildOverlappingAvatars([
                                            'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=80',
                                            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80',
                                            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80',
                                            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=80',
                                          ]),
                                        const SizedBox(width: 6),
                                        Text(
                                          lifetimeSentStr,
                                          style: GoogleFonts.poppins(
                                            color: context.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.5,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.chevron_right_rounded,
                                            color: context.textSecondary,
                                            size: 16),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 24),

                      // 11. Activity Feed & Tabs
                      _glassCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TabBar(
                              controller: _tabController,
                              indicatorColor: context.primaryColor,
                              labelColor: context.primaryColor,
                              unselectedLabelColor: context.textSecondary,
                              labelStyle: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.bold),
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
                                  _buildPlaceholderFeed(
                                      'No Media Uploaded Yet'),
                                  _buildPlaceholderFeed(
                                      'No Questions Asked Yet'),
                                  _buildPlaceholderFeed(
                                      'No Liked Content Available'),
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
    if (name.contains('president') ||
        name.contains('minister') ||
        user.rTags.contains('Founder')) {
      return 'diamond';
    } else if (user.tagLights.contains('STAR') ||
        user.tagLights.contains('TOP') ||
        name.contains('anurag')) {
      return 'gold';
    } else if (user.tagLights.contains('Official') ||
        user.rTags.contains('Official')) {
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
          icon = Icons.diamond_rounded;
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
          icon = Icons.workspace_premium_rounded;
        }

        tags.add({
          'label': label,
          'color': color,
          'gradient': gradient,
          'icon': icon,
          'imageUrl': t.imageUrl,
          'type': type,
        });
      }
    }

    return tags;
  }

  List<Widget> buildTagLightsWidget(
      List<Map<String, dynamic>> tags, BuildContext context) {
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
      final type = tag['type'] as String?;

      String? localAsset;
      final String cleanLabel = label.trim().toLowerCase();
      final String cleanUrl = (imageUrl ?? '').trim().toLowerCase();
      final String cleanType = (type ?? '').trim().toLowerCase();

      if (cleanUrl.contains('vip_1_tag.png') ||
          cleanUrl.contains('vip_level_1.png') ||
          cleanLabel == 'vip 1' ||
          cleanLabel == 'vip1') {
        localAsset = 'assets/identity_tags/vip_level_1.png';
      } else if (cleanUrl.contains('vip_2_tag.png') ||
          cleanUrl.contains('vip_level_2.png') ||
          cleanLabel == 'vip 2' ||
          cleanLabel == 'vip2') {
        localAsset = 'assets/identity_tags/vip_level_2.png';
      } else if (cleanUrl.contains('id_level_1.png') ||
          (cleanType == 'id_level' &&
              (cleanLabel.contains('1') ||
                  cleanLabel.contains('level 1') ||
                  cleanLabel.contains('lv.1') ||
                  cleanLabel.contains('lv. 1')))) {
        localAsset = 'assets/identity_tags/id_level_1.png';
      } else if (cleanUrl.contains('id_level_2.png') ||
          (cleanType == 'id_level' &&
              (cleanLabel.contains('2') ||
                  cleanLabel.contains('level 2') ||
                  cleanLabel.contains('lv.2') ||
                  cleanLabel.contains('lv. 2')))) {
        localAsset = 'assets/identity_tags/id_level_2.png';
      }

      final String? officialCommAsset =
          getOfficialCommunityTagAssetPath(cleanLabel) ??
              getOfficialCommunityTagAssetPath(cleanUrl) ??
              getOfficialCommunityTagAssetPath(cleanType);
      if (officialCommAsset != null) {
        localAsset = officialCommAsset;
      }

      if (localAsset != null) {
        return Tooltip(
          message: 'Identity Tag: $label',
          child: Image.asset(
            localAsset,
            height: 19,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildTextTagFallback(label, tag),
          ),
        );
      }

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
          imgWidget = Image.network(
            imageUrl,
            height: 19,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildTextTagFallback(label, tag),
          );
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
            Get.snackbar(
                'Tag Info', 'Details page for $label tag (coming soon).');
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
            border:
                Border.all(color: Colors.white.withOpacity(0.2), width: 0.8),
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
          Get.snackbar(
              'Tag Info', 'Details page for $label tag (coming soon).');
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

  Widget buildBadgesShowcaseWidget(
      List<String> activeBadgesList, BuildContext context) {
    final custCtrl = Get.find<CustomizationController>();
    final badgesToUse = activeBadgesList;
    if (badgesToUse.isEmpty) return const SizedBox.shrink();

    final displayList =
        badgesToUse.length > 6 ? badgesToUse.take(5).toList() : badgesToUse;
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
            final meta = custCtrl.badgeMetadata[bName] ??
                {'icon': '🏅', 'rarity': 'Common'};
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
                  border: Border.all(
                      color: Colors.white.withOpacity(0.12), width: 1.0),
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
      child: Text(text,
          style: GoogleFonts.inter(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionButtonsRow() {
    return Row(
      children: _isMe
          ? [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => Get.to(() => const EditProfileScreen())
                        ?.then((res) async {
                      final targetId =
                          UserProfileCacheManager.currentUserId.isNotEmpty
                              ? UserProfileCacheManager.currentUserId
                              : _user.id;
                      final refreshed =
                          await UserProfileCacheManager.fetchUserProfile(
                              targetId,
                              forceRefresh: true);
                      if (refreshed != null && mounted) {
                        setState(() {
                          _user = refreshed;
                        });
                      }
                    }),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text('Edit Profile',
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: context.borderColor.withOpacity(0.6),
                        width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                    ),
                    onPressed: () => Get.to(() => const EditProfileScreen())
                        ?.then((res) async {
                      final targetId =
                          UserProfileCacheManager.currentUserId.isNotEmpty
                              ? UserProfileCacheManager.currentUserId
                              : _user.id;
                      final refreshed =
                          await UserProfileCacheManager.fetchUserProfile(
                              targetId,
                              forceRefresh: true);
                      if (refreshed != null && mounted) {
                        setState(() {
                          _user = refreshed;
                        });
                      }
                    }),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined,
                            color: context.textPrimary, size: 18),
                        const SizedBox(width: 6),
                        Text('Edit Cover',
                            style: GoogleFonts.inter(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () =>
                    Get.to(() => const ProfileCustomizationScreen())?.then((_) {
                  UserProfileCacheManager.fetchUserProfile(_user.id,
                      forceRefresh: true);
                }),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: context.borderColor.withOpacity(0.6),
                        width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Icon(Icons.edit_outlined,
                      color: context.textPrimary, size: 20),
                ),
              ),
            ]
          : [
              Expanded(
                child: Obx(() {
                  final otherId = _user.id;
                  final isFollowed =
                      UserProfileCacheManager.followedUserIds.contains(otherId);
                  final isFollower =
                      UserProfileCacheManager.followerUserIds.contains(otherId);

                  String buttonText = 'Follow';
                  if (isFollowed && isFollower) {
                    buttonText = 'Mutual';
                  } else if (isFollowed) {
                    buttonText = 'Following';
                  } else if (isFollower) {
                    buttonText = 'Follow Back';
                  }

                  return Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        if (buttonText == 'Follow' ||
                            buttonText == 'Follow Back') {
                          UserProfileCacheManager.followUser(otherId);
                        } else {
                          UserProfileCacheManager.unfollowUser(otherId);
                        }
                      },
                      child: Text(buttonText,
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5)),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: context.borderColor.withOpacity(0.6),
                        width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                    ),
                    onPressed: _startDirectChat,
                    child: Text('Message',
                        style: GoogleFonts.inter(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _openSendGiftDialog,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: context.borderColor.withOpacity(0.6),
                        width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Icon(Icons.card_giftcard_rounded,
                      color: context.textPrimary, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _showMoreMenu,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: context.borderColor.withOpacity(0.6),
                        width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Icon(Icons.more_horiz_rounded,
                      color: context.textPrimary, size: 20),
                ),
              ),
            ],
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

  Widget _buildSocialStatsSection() {
    return Obx(() {
      final u = UserProfileCacheManager.rxCache[_user.id] ?? _user;
      final followersCount = u.followers;
      final followingCount = u.following;
      final friendsCount = u.friendsCount;
      final giftsCount = _giftLifetimeReceived.value;
      final contributeCount = _giftLifetimeSent.value;

      return Row(
        children: [
          Expanded(
            child: _statCard(
              _formatCount(followersCount),
              'Followers',
              icon: Icons.people_alt_outlined,
              onTap: () => Get.to(() => ConnectionsScreen(
                    initialTabIndex: 1,
                    targetUserId: u.id,
                    targetUserName: u.displayName,
                  )),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              _formatCount(followingCount),
              'Following',
              icon: Icons.person_add_alt_1_outlined,
              onTap: () => Get.to(() => ConnectionsScreen(
                    initialTabIndex: 0,
                    targetUserId: u.id,
                    targetUserName: u.displayName,
                  )),
            ),
          ),
          const SizedBox(width: 8),
          if (_isMe) ...[
            Expanded(
              child: _statCard(
                _formatCount(friendsCount),
                'Friends',
                icon: Icons.groups_outlined,
                onTap: () => Get.to(() => ConnectionsScreen(
                      initialTabIndex: 2,
                      targetUserId: u.id,
                      targetUserName: u.displayName,
                    )),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard(
                _formatCount(giftsCount) + ' ★',
                'Gifts',
                icon: Icons.card_giftcard_rounded,
                onTap: () => Get.to(() => GiftingContributionScreen(
                      userId: u.id,
                      username: u.displayName,
                    )),
              ),
            ),
          ] else ...[
            Expanded(
              child: _statCard(
                _formatCount(giftsCount) + ' ★',
                'Gifts',
                icon: Icons.card_giftcard_rounded,
                onTap: () => Get.to(() => GiftingContributionScreen(
                      userId: u.id,
                      username: u.displayName,
                    )),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard(
                _formatCount(contributeCount) + ' ★',
                'Contribute',
                icon: Icons.favorite_outline_rounded,
                onTap: () => Get.to(() => GiftingContributionScreen(
                      userId: u.id,
                      username: u.displayName,
                    )),
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _statCard(String value, String label,
      {IconData? icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: context.borderColor.withOpacity(0.6), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: context.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: context.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(height: 4),
              Icon(icon, color: context.primaryColor, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _glassCard(
      {required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: child,
    );
  }

  Widget _bioDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: context.primaryColor, size: 14),
        const SizedBox(width: 8),
        Text(text,
            style:
                GoogleFonts.inter(color: context.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _infoTableRow(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: context.borderColor, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: context.textSecondary, fontSize: 12)),
          Text(value,
              style: GoogleFonts.inter(
                  color: context.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _communityRow(String name, String role, String level,
      String? coverImage, int memberCount,
      {VoidCallback? onTap}) {
    final bool hasUrl = coverImage != null &&
        (coverImage.startsWith('http://') || coverImage.startsWith('https://'));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.borderColor, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: context.primaryColor.withOpacity(0.3), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: hasUrl
                    ? CachedNetworkImage(
                        imageUrl: coverImage,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 1.5)),
                        errorWidget: (context, url, error) => Center(
                          child: Text(
                            name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                                color: context.primaryColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          coverImage ?? name.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                              color: context.primaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.inter(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(role.toUpperCase(),
                          style: GoogleFonts.inter(
                              color: const Color(0xFFF59E0B),
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: context.primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(level,
                            style: TextStyle(
                                color: context.textSecondary, fontSize: 8)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: context.primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('$memberCount members',
                            style: TextStyle(
                                color: context.textSecondary, fontSize: 8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: context.textSecondary, size: 16),
          ],
        ),
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
        Text(title,
            style:
                GoogleFonts.inter(color: context.textSecondary, fontSize: 9)),
      ],
    );
  }

  Widget _navItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: context.primaryColor, size: 20),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.inter(
                  color: context.textPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showMoreOptionsSheet(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: const BoxDecoration(
          color: Color(0xFF11131C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MORE ACTIONS',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _moreOptionItem(
                  Icons.backpack_outlined,
                  'Creaniaa Vault',
                  const Color(0xFFFBBF24),
                  () {
                    Get.back();
                    Get.to(() => const CreaniaVaultHomeScreen());
                  },
                ),
                _moreOptionItem(
                  Icons.library_books_rounded,
                  'My Library',
                  const Color(0xFF3B82F6),
                  () {
                    Get.back();
                    Get.to(() => const MyLibraryScreen());
                  },
                ),
                _moreOptionItem(
                  Icons.dashboard_rounded,
                  'Seller Deck',
                  const Color(0xFF10B981),
                  () {
                    Get.back();
                    Get.to(() => const SellerDashboardScreen());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _moreOptionItem(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _analyticRow(String label, String value,
      {Color color = Colors.white, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: const Color(0xFFC6C5D7), fontSize: 12)),
          Text(value,
              style: GoogleFonts.inter(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
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
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: context.borderColor, width: 0.5)),
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
                      Text(_user.displayName,
                          style: GoogleFonts.inter(
                              color: context.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                      Text('${index + 1}h ago',
                          style: GoogleFonts.inter(
                              color: context.textSecondary, fontSize: 10)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(post.content,
                  style: GoogleFonts.inter(
                      color: context.textPrimary, fontSize: 13, height: 1.45)),
              PostAttachmentsWidget(post: post),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.favorite_rounded,
                      color: Colors.redAccent, size: 14),
                  const SizedBox(width: 4),
                  Text('${post.likes}',
                      style: TextStyle(
                          color: context.textSecondary, fontSize: 11)),
                  const SizedBox(width: 16),
                  Icon(Icons.chat_bubble_rounded,
                      color: context.primaryColor, size: 14),
                  const SizedBox(width: 4),
                  Text('${post.comments}',
                      style: TextStyle(
                          color: context.textSecondary, fontSize: 11)),
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
      child: Text(text,
          style: GoogleFonts.inter(color: context.textSecondary, fontSize: 13)),
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

class _BreathingVTagState extends State<_BreathingVTag>
    with SingleTickerProviderStateMixin {
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
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.15), weight: 50),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.15, end: 1.0), weight: 50),
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
                  color: widget.level.toLowerCase() == 'diamond'
                      ? Colors.cyanAccent
                      : badgeColor,
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

class ProfileHeaderCurveClipper extends CustomClipper<Path> {
  final double radius;

  ProfileHeaderCurveClipper({this.radius = 24.0});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - radius);

    // Smooth top-left rounded corner for white panel below
    path.quadraticBezierTo(0, size.height, radius, size.height);

    // Straight clean edge across middle right above stats section
    path.lineTo(size.width - radius, size.height);

    // Smooth top-right rounded corner for white panel below
    path.quadraticBezierTo(
        size.width, size.height, size.width, size.height - radius);

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

class ProfileHeaderCurveShadowPainter extends CustomPainter {
  final Color shadowColor;

  ProfileHeaderCurveShadowPainter({required this.shadowColor});

  @override
  void paint(Canvas canvas, Size size) {
    // No shadow painter requested
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
