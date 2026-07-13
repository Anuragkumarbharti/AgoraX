import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/community_model.dart';
import 'store_controller.dart';
import 'user_profile_cache_manager.dart';

class CommunityController extends GetxController {
  static String get currentUserId => UserProfileCacheManager.currentUserId;

  // User Coins State
  RxInt get userCoins => Get.find<StoreController>().coinsBalance;

  // Communities State
  final RxList<Community> communities = <Community>[].obs;

  // Showcased Community ID for Profile Badge
  final RxString showcasedCommunityId = ''.obs;

  RealtimeChannel? _communitiesSubscription;

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
    super.onClose();
  }

  Future<void> _loadCommunitiesFromDatabase() async {
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
        'type': m['type'],
        'owner': m['owner'],
        'coOwnerIds': m['co_owner_ids'] ?? [],
        'admins': m['admins'] ?? [],
        'members': m['members'] ?? [],
        'memberCount': m['member_count'] ?? 1,
        'isVerified': m['is_verified'] ?? false,
        'createdAt': m['created_at'] ?? DateTime.now().toIso8601String(),
        'level': m['level'] ?? 1,
        'xp': m['xp'] ?? 0,
        'creationType': m['creation_type'] ?? 'coins',
        'isApproved': m['is_approved'] ?? true,
        'isLogoUnlocked': m['is_logo_unlocked'] ?? true,
        'rules': m['rules'] ?? '',
        'tasks': m['tasks'] ?? [],
      })).toList();

      communities.assignAll(loaded);
    } catch (e) {
      debugPrint('DB Load Error: Fallback to initial communities: $e');
      _loadInitialCommunities();
    }
  }

  void subscribeToRealtime() {
    try {
      _communitiesSubscription = Supabase.instance.client
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
    required String name,
    required String username,
    required String description,
    required String category,
    required String creationType,
    String? logo,
    String? banner,
  }) async {
    if (name.trim().isEmpty) return 'Community name cannot be empty';

    if (communities.any((c) => c.owner == currentUserId)) {
      return 'You can only own one community/family at a time.';
    }

    final id = 'comm_${DateTime.now().millisecondsSinceEpoch}';

    final tasksList = creationType == 'coins' ? [] : [
      {
        'id': 't1',
        'title': 'Invite 5 Members',
        'description': 'Get at least 5 members to join your community',
        'target': 5,
        'current': 1,
        'isCompleted': false,
      },
      {
        'id': 't2',
        'title': 'Host a Community Voice Room',
        'description': 'Start a voice room linked to this community',
        'target': 1,
        'current': 0,
        'isCompleted': false,
      },
      {
        'id': 't3',
        'title': 'Publish 3 Posts',
        'description': 'Share 3 updates or announcements in the community feed',
        'target': 3,
        'current': 0,
        'isCompleted': false,
      }
    ];

    if (creationType == 'coins') {
      if (userCoins.value < 10000) {
        return 'Insufficient coin balance. You need 10,000 coins.';
      }
      userCoins.value -= 10000;
      try {
        await Supabase.instance.client
            .from('wallets')
            .update({'coins_balance': userCoins.value})
            .eq('id', currentUserId);
      } catch (_) {}
    }

    try {
      final payload = {
        'id': id,
        'name': name,
        'username': username,
        'description': description,
        'category': category,
        'type': 'public',
        'owner': currentUserId,
        'co_owner_ids': [],
        'admins': [],
        'members': [currentUserId],
        'member_count': 1,
        'is_verified': false,
        'level': 1,
        'xp': 0,
        'creation_type': creationType,
        'is_approved': creationType == 'coins',
        'is_logo_unlocked': creationType == 'coins',
        'rules': 'Be respectful. No spamming or self-promotion.',
        'tasks': tasksList,
        'image': logo,
        'banner': banner,
        'created_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from('communities').insert(payload);
      await _loadCommunitiesFromDatabase();
      return null;
    } catch (e) {
      if (creationType == 'coins') {
        userCoins.value += 10000;
        try {
          await Supabase.instance.client
              .from('wallets')
              .update({'coins_balance': userCoins.value})
              .eq('id', currentUserId);
        } catch (_) {}
      }
      return 'Failed to create community: $e';
    }
  }

  Future<void> joinCommunity(String communityId) async {
    final idx = communities.indexWhere((c) => c.id == communityId);
    if (idx != -1) {
      final comm = communities[idx];
      if (!comm.members.contains(currentUserId)) {
        final updatedMembers = [...comm.members, currentUserId];
        final updatedCount = comm.memberCount + 1;
        
        try {
          await Supabase.instance.client
              .from('communities')
              .update({
                'members': updatedMembers,
                'member_count': updatedCount,
              })
              .eq('id', communityId);
          
          await _loadCommunitiesFromDatabase();

          if (comm.owner == currentUserId) {
            await updateTaskProgress(communityId, 't1', updatedCount);
          }
        } catch (_) {}
      }
    }
  }

  Future<void> leaveCommunity(String communityId) async {
    final idx = communities.indexWhere((c) => c.id == communityId);
    if (idx != -1) {
      final comm = communities[idx];
      if (comm.owner == currentUserId) return;

      final updatedMembers = comm.members.where((id) => id != currentUserId).toList();
      final updatedAdmins = comm.admins.where((id) => id != currentUserId).toList();
      final updatedCoOwners = comm.coOwnerIds.where((id) => id != currentUserId).toList();

      try {
        await Supabase.instance.client
            .from('communities')
            .update({
              'members': updatedMembers,
              'admins': updatedAdmins,
              'co_owner_ids': updatedCoOwners,
              'member_count': comm.memberCount > 1 ? comm.memberCount - 1 : 1,
            })
            .eq('id', communityId);
        
        await _loadCommunitiesFromDatabase();
      } catch (_) {}
    }
  }

  Future<void> kickMember(String communityId, String userId) async {
    final idx = communities.indexWhere((c) => c.id == communityId);
    if (idx != -1) {
      final comm = communities[idx];
      
      final updatedMembers = comm.members.where((id) => id != userId).toList();
      final updatedAdmins = comm.admins.where((id) => id != userId).toList();
      final updatedCoOwners = comm.coOwnerIds.where((id) => id != userId).toList();

      try {
        await Supabase.instance.client
            .from('communities')
            .update({
              'members': updatedMembers,
              'admins': updatedAdmins,
              'co_owner_ids': updatedCoOwners,
              'member_count': comm.memberCount > 1 ? comm.memberCount - 1 : 1,
            })
            .eq('id', communityId);
        
        await _loadCommunitiesFromDatabase();
      } catch (_) {}
    }
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

  Future<void> approveApplication(String communityId) async {
    final idx = communities.indexWhere((c) => c.id == communityId);
    if (idx != -1) {
      try {
        await Supabase.instance.client
            .from('communities')
            .update({'is_approved': true})
            .eq('id', communityId);
        await _loadCommunitiesFromDatabase();
      } catch (_) {}
    }
  }

  Future<void> promoteMember(String communityId, String userId, String role) async {
    final idx = communities.indexWhere((c) => c.id == communityId);
    if (idx != -1) {
      final comm = communities[idx];
      List<String> coOwners = List.from(comm.coOwnerIds);
      List<String> admins = List.from(comm.admins);

      if (role == 'coOwner') {
        admins.remove(userId);
        if (!coOwners.contains(userId)) coOwners.add(userId);
      } else if (role == 'admin') {
        coOwners.remove(userId);
        if (!admins.contains(userId)) admins.add(userId);
      } else {
        coOwners.remove(userId);
        admins.remove(userId);
      }

      try {
        await Supabase.instance.client
            .from('communities')
            .update({
              'co_owner_ids': coOwners,
              'admins': admins,
            })
            .eq('id', communityId);
        
        await _loadCommunitiesFromDatabase();
      } catch (_) {}
    }
  }

  Future<void> addXp(String communityId, int amount) async {
    final idx = communities.indexWhere((c) => c.id == communityId);
    if (idx != -1) {
      final comm = communities[idx];
      int newXp = comm.xp + amount;
      int newLevel = comm.level;
      
      if (newXp >= newLevel * 1000) {
        newXp -= newLevel * 1000;
        newLevel += 1;
      }

      try {
        await Supabase.instance.client
            .from('communities')
            .update({
              'xp': newXp,
              'level': newLevel,
            })
            .eq('id', communityId);
        await _loadCommunitiesFromDatabase();
      } catch (_) {}
    }
  }

  String getUserRole(Community comm) {
    if (comm.owner == currentUserId) return 'Owner';
    if (comm.coOwnerIds.contains(currentUserId)) return 'Co-Owner';
    if (comm.admins.contains(currentUserId)) return 'Admin';
    if (comm.members.contains(currentUserId)) return 'Member';
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
}
