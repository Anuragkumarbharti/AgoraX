import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/community/community_model.dart';
import '../../models/community/community_event_model.dart';
import '../store/store_controller.dart';
import '../user/user_profile_cache_manager.dart';
import '../network/network_connectivity_service.dart';
import '../network/network_guard.dart';

class CommunityController extends GetxController {
  static String get currentUserId => UserProfileCacheManager.currentUserId;

  // User Coins State (representing gold coins)
  RxInt get userCoins => Get.find<StoreController>().coinsBalance;

  // Communities State
  final RxList<Community> communities = <Community>[].obs;

  // Current User's Community Membership
  final Rxn<CommunityMembership> userMembership = Rxn<CommunityMembership>();

  // Current User's Pending Applications
  final RxList<CommunityApplication> pendingApplications = <CommunityApplication>[].obs;

  // Showcased Community ID for Profile Badge
  final RxString showcasedCommunityId = ''.obs;

  // StarMaker Additions State
  final RxList<CommunityAnnouncement> communityAnnouncements = <CommunityAnnouncement>[].obs;
  final RxList<CommunityEvent> communityEvents = <CommunityEvent>[].obs;
  final RxList<CommunityLog> communityLogs = <CommunityLog>[].obs;

  RealtimeChannel? _communitiesSubscription;
  RealtimeChannel? _membershipsSubscription;
  RealtimeChannel? _applicationsSubscription;

  void setShowcasedCommunity(String communityId) {
    showcasedCommunityId.value = communityId;
  }

  @override
  void onInit() {
    super.onInit();
    _loadCommunitiesFromDatabase();
    subscribeToRealtime();
  }

  @override
  void onClose() {
    _communitiesSubscription?.unsubscribe();
    _membershipsSubscription?.unsubscribe();
    _applicationsSubscription?.unsubscribe();
    super.onClose();
  }

  final RxBool isLoading = false.obs;

  Future<void> syncFromSupabase() => _loadCommunitiesFromDatabase();

  Future<void> _loadCommunitiesFromDatabase() async {
    isLoading.value = true;
    try {
      final List<dynamic> list = await Supabase.instance.client
          .from('communities')
          .select()
          .order('created_at', ascending: false);
      final loaded = list.map((m) => Community.fromJson({
        'id': m['id'],
        'name': m['name'],
        'description': m['description'],
        'image': m['image'],
        'banner': m['banner'],
        'category': m['category'],
        'type': m['type'] ?? 'public',
        'owner': m['owner'],
        'co_owner_ids': m['co_owner_ids'] ?? [],
        'admins': m['admins'] ?? [],
        'members': m['members'] ?? [],
        'member_count': m['member_count'] ?? 0,
        'is_verified': m['is_verified'] ?? false,
        'created_at': m['created_at'] ?? DateTime.now().toIso8601String(),
        'level': m['level'] ?? 1,
        'xp': m['xp'] ?? 0,
        'creation_type': m['creation_type'] ?? 'coins',
        'is_approved': m['is_approved'] ?? true,
        'is_logo_unlocked': m['is_logo_unlocked'] ?? true,
        'rules': m['rules'] ?? '',
        'tasks': m['tasks'] ?? [],
        'is_official': m['is_official'] ?? false,
        'join_mode': m['join_mode'] ?? 'auto_join',
        'language': m['language'] ?? 'en',
        'country': m['country'] ?? 'IN',
        'min_id_level': m['min_id_level'] ?? 1,
        'preferred_languages': m['preferred_languages'] ?? [],
        'preferred_countries': m['preferred_countries'] ?? [],
        'preferred_interests': m['preferred_interests'] ?? [],
        'tags': m['tags'] ?? [],
        'visibility': m['visibility'] ?? 'public',
        'lifetime_exp': m['lifetime_exp'] ?? 0,
        'daily_exp': m['daily_exp'] ?? 0,
        'weekly_exp': m['weekly_exp'] ?? 0,
        'monthly_exp': m['monthly_exp'] ?? 0,
        'activity_score': m['activity_score'] ?? 0,
        'co_owner_limit': m['co_owner_limit'] ?? 2,
        'admin_limit': m['admin_limit'] ?? 5,
      })).toList();

      communities.assignAll(loaded);
      await _loadUserMembership();
      await _loadUserApplications();
    } catch (e) {
      debugPrint('DB Load Error: Fallback to initial communities: $e');
      _loadInitialCommunities();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadUserMembership() async {
    if (currentUserId.isEmpty) {
      userMembership.value = null;
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('community_memberships')
          .select()
          .eq('user_id', currentUserId)
          .maybeSingle();
      if (res != null) {
        userMembership.value = CommunityMembership.fromJson(res);
      } else {
        userMembership.value = null;
      }
    } catch (e) {
      userMembership.value = null;
      debugPrint('Load User Membership Error: $e');
    }
  }

  Future<void> _loadUserApplications() async {
    if (currentUserId.isEmpty) {
      pendingApplications.clear();
      return;
    }
    try {
      final List<dynamic> res = await Supabase.instance.client
          .from('community_applications')
          .select()
          .eq('user_id', currentUserId)
          .eq('status', 'pending');
      pendingApplications.assignAll(
          res.map((r) => CommunityApplication.fromJson(r)).toList());
    } catch (e) {
      debugPrint('Load User Applications Error: $e');
    }
  }

  void subscribeToRealtime() {
    try {
      final client = Supabase.instance.client;
      _communitiesSubscription = client
          .channel('public:communities')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'communities',
            callback: (payload) {
              _loadCommunitiesFromDatabase();
            },
          );
      _communitiesSubscription?.subscribe();

      _membershipsSubscription = client
          .channel('public:community_memberships')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'community_memberships',
            callback: (payload) {
              _loadCommunitiesFromDatabase();
            },
          );
      _membershipsSubscription?.subscribe();

      _applicationsSubscription = client
          .channel('public:community_applications')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'community_applications',
            callback: (payload) {
              _loadCommunitiesFromDatabase();
            },
          );
      _applicationsSubscription?.subscribe();
    } catch (e) {
      debugPrint('Realtime Sub failed: $e');
    }
  }

  void _loadInitialCommunities() {
    if (communities.isEmpty) {
      final names = [
        'Flutter India 🦋',
        'AI & ML Hub 🤖',
        'DSA Grinders 🧠',
        'Web Dev Café ☕',
        'Open Source 🌍',
        'UPSC Aspirants 📚'
      ];
      final descs = [
        'Official community for Flutter developers across India',
        'Discuss AI, ML, and the future of intelligent systems',
        'Crack DSA together — daily challenges and solutions',
        'All things frontend, backend, and full-stack web dev',
        'Build and contribute to open source projects',
        'Study smart, crack UPSC together',
      ];
      for (int i = 0; i < names.length; i++) {
        communities.add(
          Community(
            id: 'c$i',
            name: names[i],
            description: descs[i],
            category: [
              'Technology',
              'AI',
              'Education',
              'Technology',
              'Open Source',
              'Education'
            ][i],
            type: 'public',
            owner: 'admin',
            admins: const [],
            coOwnerIds: const [],
            members: const ['u2', 'u3', 'u4'],
            memberCount: [12400, 8200, 5600, 4800, 3100, 9800][i],
            isVerified: i % 2 == 0,
            createdAt: DateTime.now().subtract(Duration(days: i * 30)),
            image: null,
            banner: null,
            tasks: const [],
          ),
        );
      }
    }
  }

  Future<String?> createCommunity({
    required String id,
    required String name,
    required String description,
    required String category,
    required String language,
    required String country,
    required String rules,
    required String joinMode,
    required int minIdLevel,
    required List<String> preferredLanguages,
    required List<String> preferredCountries,
    required List<String> preferredInterests,
    required List<String> tags,
    required String visibility,
    String? logo,
    String? banner,
    required String creationMethod,
    String? identityTag,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc('create_community_rpc', params: {
        'p_id': id,
        'p_name': name,
        'p_description': description,
        'p_category': category,
        'p_language': language,
        'p_country': country,
        'p_rules': rules,
        'p_join_mode': joinMode,
        'p_min_id_level': minIdLevel,
        'p_preferred_languages': preferredLanguages,
        'p_preferred_countries': preferredCountries,
        'p_preferred_interests': preferredInterests,
        'p_tags': tags,
        'p_visibility': visibility,
        'p_image': logo,
        'p_banner': banner,
        'p_creation_method': creationMethod,
        'p_identity_tag': identityTag,
      });

      if (response != null && response is Map && response['success'] == false) {
        return response['error']?.toString() ?? 'Failed to create community';
      }

      await _loadCommunitiesFromDatabase();
      await UserProfileCacheManager.rebuildAndSyncCurrentUserTagSystem();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> joinCommunity(String communityId, {
    String? introduction,
    String? reason,
    String? preferredLanguage,
    String? optionalMessage,
  }) async {
    if (!NetworkGuard.checkInternet(actionName: 'community')) {
      return 'No internet connection.';
    }
    try {
      final response = await Supabase.instance.client.rpc('join_community_rpc', params: {
        'p_community_id': communityId,
        'p_introduction': introduction,
        'p_reason': reason,
        'p_preferred_language': preferredLanguage,
        'p_optional_message': optionalMessage,
      });

      if (response != null && response is Map) {
        if (response['success'] == false) {
          return response['error']?.toString() ?? 'Failed to join community';
        }
        await _loadCommunitiesFromDatabase();
        await UserProfileCacheManager.rebuildAndSyncCurrentUserTagSystem();
        return null;
      }
      return 'Unexpected backend response';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> leaveCommunity(String communityId) async {
    if (!NetworkGuard.checkInternet(actionName: 'community')) {
      return 'No internet connection.';
    }
    try {
      final response = await Supabase.instance.client.rpc('leave_community_rpc', params: {
        'p_community_id': communityId,
      });

      if (response != null && response is Map && response['success'] == false) {
        return response['error']?.toString() ?? 'Failed to leave community';
      }

      await _loadCommunitiesFromDatabase();
      await UserProfileCacheManager.rebuildAndSyncCurrentUserTagSystem();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> processApplication(String applicationId, String action) async {
    try {
      final response = await Supabase.instance.client.rpc('process_application_rpc', params: {
        'p_application_id': applicationId,
        'p_action': action,
      });

      if (response != null && response is Map && response['success'] == false) {
        return response['error']?.toString() ?? 'Failed to process application';
      }

      await _loadCommunitiesFromDatabase();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> manageMemberRole(String communityId, String targetUserId, String role) async {
    try {
      final response = await Supabase.instance.client.rpc('manage_member_role_rpc', params: {
        'p_community_id': communityId,
        'p_target_user_id': targetUserId,
        'p_role': role,
      });

      if (response != null && response is Map && response['success'] == false) {
        return response['error']?.toString() ?? 'Failed to manage role';
      }

      await _loadCommunitiesFromDatabase();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> promoteMember(String communityId, String userId, String role) async {
    final backendRole = role == 'coOwner' ? 'co_owner' : role;
    return manageMemberRole(communityId, userId, backendRole);
  }

  Future<String?> kickMember(String communityId, String userId) async {
    return manageMemberRole(communityId, userId, 'kick');
  }

  Future<void> updateTaskProgress(String communityId, String taskId, int incrementTo) async {
    final idx = communities.indexWhere((c) => c.id == communityId);
    if (idx != -1) {
      final comm = communities[idx];
      final updatedTasks = comm.tasks.map((task) {
        if (task.id == taskId) {
          final isCompleted = incrementTo >= task.target;
          return task.copyWith(
            current: incrementTo,
            isCompleted: isCompleted,
          );
        }
        return task;
      }).toList();

      final allDone = updatedTasks.every((t) => t.isCompleted);

      try {
        await Supabase.instance.client
            .from('communities')
            .update({
              'tasks': updatedTasks.map((t) => t.toJson()).toList(),
              'is_logo_unlocked': allDone ? true : comm.isLogoUnlocked,
            })
            .eq('id', communityId);
        
        await _loadCommunitiesFromDatabase();
      } catch (_) {}
    }
  }
  Future<void> addXp(String communityId, int amount, {String sourceType = 'normal'}) async {
    try {
      final res = await Supabase.instance.client.rpc('add_community_exp_rpc', params: {
        'p_community_id': communityId,
        'p_user_id': currentUserId,
        'p_source_type': sourceType,
        'p_amount': amount,
      });
      debugPrint('add_community_exp_rpc response: $res');
      await _loadCommunitiesFromDatabase();
    } catch (e) {
      debugPrint('addXp failed: $e');
    }
  }

  Future<bool> checkIn(String communityId) async {
    try {
      final response = await Supabase.instance.client.rpc('check_in_community_rpc', params: {
        'p_community_id': communityId,
      });
      if (response != null && response['success'] == true) {
        await _loadCommunitiesFromDatabase();
        return true;
      } else {
        final err = response?['error'] ?? 'Check-in failed.';
        Get.snackbar('Check-in', err,
            backgroundColor: const Color(0xFF1E1E2E),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
        return false;
      }
    } catch (e) {
      Get.snackbar('Check-in', e.toString(),
          backgroundColor: const Color(0xFF1E1E2E),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getLeaderboard(String communityId, String type) async {
    try {
      final response = await Supabase.instance.client.rpc('get_community_leaderboard_rpc', params: {
        'p_community_id': communityId,
        'p_type': type,
        'p_limit': 20,
      });
      if (response != null && response['success'] == true && response['data'] != null) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
    } catch (e) {
      debugPrint('getLeaderboard failed: $e');
    }
    return [];
  }
  String getUserRole(Community comm) {
    if (userMembership.value != null && userMembership.value!.communityId == comm.id) {
      final r = userMembership.value!.role;
      if (r == 'owner') return 'Owner';
      if (r == 'co_owner') return 'Co-Owner';
      if (r == 'admin') return 'Admin';
      return 'Member';
    }
    return 'Guest';
  }

  bool hasPower(Community comm, String power) {
    final role = getUserRole(comm);
    if (role == 'Owner' || role == 'Co-Owner') return true;
    if (role == 'Admin') {
      return power != 'manage_roles';
    }
    return false;
  }

  Future<List<Community>> searchCommunities(String query) async {
    if (query.trim().isEmpty) return communities;
    try {
      final response = await Supabase.instance.client
          .rpc('search_communities', params: {'p_query': query});
      if (response != null && response is List) {
        return (response as List)
            .map((json) => Community.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Search communities failed: $e');
    }
    return communities.where((c) =>
        c.name.toLowerCase().contains(query.toLowerCase()) ||
        c.username.toLowerCase().contains(query.toLowerCase()) ||
        c.id.toLowerCase().contains(query.toLowerCase())).toList();
  }

  Future<void> loadCommunityAdditions(String communityId) async {
    try {
      // Announcements
      final annRes = await Supabase.instance.client
          .from('community_announcements')
          .select()
          .eq('community_id', communityId)
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);
      communityAnnouncements.assignAll((annRes as List).map((a) => CommunityAnnouncement.fromJson(a)).toList());

      // Events
      final evRes = await Supabase.instance.client
          .from('community_events')
          .select()
          .eq('community_id', communityId)
          .order('start_time', ascending: true);
      communityEvents.assignAll((evRes as List).map((e) => CommunityEvent.fromJson(e)).toList());

      // Logs
      if (userMembership.value != null && ['owner', 'co_owner', 'admin'].contains(userMembership.value!.role)) {
        final logRes = await Supabase.instance.client
            .from('community_logs')
            .select()
            .eq('community_id', communityId)
            .order('created_at', ascending: false)
            .limit(30);
        communityLogs.assignAll((logRes as List).map((l) => CommunityLog.fromJson(l)).toList());
      } else {
        communityLogs.clear();
      }
    } catch (e) {
      debugPrint('Load additions failed: $e');
    }
  }

  Future<bool> createAnnouncement(String communityId, String title, String content, bool isPinned) async {
    try {
      final res = await Supabase.instance.client.rpc('create_announcement_rpc', params: {
        'p_community_id': communityId,
        'p_title': title,
        'p_content': content,
        'p_is_pinned': isPinned,
      });
      if (res != null && res['success'] == true) {
        await loadCommunityAdditions(communityId);
        return true;
      }
    } catch (e) {
      debugPrint('Create announcement failed: $e');
    }
    return false;
  }

  Future<bool> deleteAnnouncement(String communityId, String announcementId) async {
    try {
      final res = await Supabase.instance.client.rpc('delete_announcement_rpc', params: {
        'p_community_id': communityId,
        'p_announcement_id': announcementId,
      });
      if (res != null && res['success'] == true) {
        await loadCommunityAdditions(communityId);
        return true;
      }
    } catch (e) {
      debugPrint('Delete announcement failed: $e');
    }
    return false;
  }

  Future<bool> pinAnnouncement(String communityId, String announcementId, bool isPinned) async {
    try {
      final res = await Supabase.instance.client.rpc('pin_announcement_rpc', params: {
        'p_community_id': communityId,
        'p_announcement_id': announcementId,
        'p_is_pinned': isPinned,
      });
      if (res != null && res['success'] == true) {
        await loadCommunityAdditions(communityId);
        return true;
      }
    } catch (e) {
      debugPrint('Pin announcement failed: $e');
    }
    return false;
  }

  Future<bool> createCommunityEvent(
    String communityId,
    String name,
    String banner,
    String description,
    DateTime startTime,
    DateTime endTime,
    String hostId,
    List<String> coHosts,
    int maxParticipants,
    String rewards,
    String rules,
  ) async {
    try {
      final res = await Supabase.instance.client.rpc('create_community_event_rpc', params: {
        'p_community_id': communityId,
        'p_name': name,
        'p_banner': banner,
        'p_description': description,
        'p_start_time': startTime.toIso8601String(),
        'p_end_time': endTime.toIso8601String(),
        'p_host_id': hostId,
        'p_co_hosts': coHosts,
        'p_max_participants': maxParticipants,
        'p_rewards': rewards,
        'p_rules': rules,
      });
      if (res != null && res['success'] == true) {
        await loadCommunityAdditions(communityId);
        return true;
      }
    } catch (e) {
      debugPrint('Create community event failed: $e');
    }
    return false;
  }

  Future<bool> registerForEvent(String communityId, String eventId) async {
    try {
      final res = await Supabase.instance.client.rpc('register_for_event_rpc', params: {
        'p_event_id': eventId,
      });
      if (res != null && res['success'] == true) {
        await loadCommunityAdditions(communityId);
        return true;
      } else {
        final err = res?['error'] ?? 'Registration failed.';
        Get.snackbar('Registration', err, backgroundColor: Colors.amber, colorText: Colors.black);
      }
    } catch (e) {
      debugPrint('Register for event failed: $e');
    }
    return false;
  }

  Future<bool> cancelEvent(String communityId, String eventId) async {
    try {
      final res = await Supabase.instance.client.rpc('cancel_event_rpc', params: {
        'p_community_id': communityId,
        'p_event_id': eventId,
      });
      if (res != null && res['success'] == true) {
        await loadCommunityAdditions(communityId);
        return true;
      }
    } catch (e) {
      debugPrint('Cancel event failed: $e');
    }
    return false;
  }

  Future<bool> updateCommunitySettings(String communityId, Map<String, dynamic> s) async {
    try {
      final res = await Supabase.instance.client.rpc('update_community_settings_rpc', params: {
        'p_community_id': communityId,
        'p_name': s['name'],
        'p_banner': s['banner'],
        'p_avatar': s['image'],
        'p_description': s['description'],
        'p_rules': s['rules'],
        'p_join_mode': s['join_mode'],
        'p_min_id_level': s['min_id_level'],
        'p_language': s['language'],
        'p_country': s['country'],
        'p_category': s['category'],
        'p_visibility': s['visibility'],
      });
      if (res != null && res['success'] == true) {
        await _loadCommunitiesFromDatabase();
        return true;
      }
    } catch (e) {
      debugPrint('Update settings failed: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>?> getCommunityAnalytics(String communityId) async {
    try {
      final res = await Supabase.instance.client.rpc('get_community_analytics_rpc', params: {
        'p_community_id': communityId,
      });
      if (res != null && res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      debugPrint('Get analytics failed: $e');
    }
    return null;
  }

  Future<List<CommunityMembership>> getDetailedMembers(String communityId) async {
    try {
      final res = await Supabase.instance.client.rpc('get_community_members_detailed_rpc', params: {
        'p_community_id': communityId,
      });
      if (res != null && res['success'] == true && res['data'] != null) {
        return (res['data'] as List).map((m) => CommunityMembership.fromJson(Map<String, dynamic>.from(m))).toList();
      }
    } catch (e) {
      debugPrint('Get detailed members failed: $e');
    }
    return [];
  }
}

