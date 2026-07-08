import 'package:get/get.dart';
import '../models/community_model.dart';
import 'store_controller.dart';

class CommunityController extends GetxController {
  // Current logged in user (mock)
  static const String currentUserId = 'me';

  // User Coins State
  RxInt get userCoins => Get.find<StoreController>().coinsBalance;

  // Communities State
  final RxList<Community> communities = <Community>[].obs;

  // Showcased Community ID for Profile Badge
  final RxString showcasedCommunityId = ''.obs;

  void setShowcasedCommunity(String communityId) {
    showcasedCommunityId.value = communityId;
  }

  @override
  void onInit() {
    super.onInit();
    _loadMockCommunities();
  }

  void _loadMockCommunities() {
    communities.assignAll([
      Community(
        id: 'c1',
        name: 'Flutter India',
        description: 'The largest community of Flutter developers in India. Share, learn and grow together! 🦋',
        category: 'Technology',
        type: 'public',
        owner: 'u2', // Priya Sharma
        coOwnerIds: ['u3'], // Rahul
        admins: ['me'], // Current user is Admin
        members: ['me', 'u2', 'u3', 'u4', 'u5', 'u6', 'u7'],
        memberCount: 12400,
        isVerified: true,
        level: 12,
        xp: 3400,
        creationType: 'coins',
        isApproved: true,
        isLogoUnlocked: true,
        tasks: [],
        rules: '1. Be polite and professional.\n2. Keep discussions related to Flutter and Dart.\n3. No spam or plagiarism.',
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
      ),
      Community(
        id: 'c2',
        name: 'AI & Machine Learning',
        description: 'Explore the frontiers of Artificial Intelligence, Deep Learning and NLP 🤖',
        category: 'Technology',
        type: 'public',
        owner: 'u3', // Rahul
        coOwnerIds: [],
        admins: ['u4'],
        members: ['me', 'u2', 'u3', 'u4'],
        memberCount: 8200,
        isVerified: true,
        level: 8,
        xp: 1200,
        creationType: 'apply',
        isApproved: true,
        isLogoUnlocked: true,
        tasks: [],
        rules: 'No self-promotion. Share high-quality resources only.',
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
      ),
      Community(
        id: 'c3',
        name: 'UX Designers Hub',
        description: 'Dedicated to UI/UX designers, researchers, and product creators. Show your designs! 🎨',
        category: 'Design',
        type: 'public',
        owner: 'me', // Current user is Owner
        coOwnerIds: [],
        admins: [],
        members: ['me', 'u5', 'u6'],
        memberCount: 3,
        isVerified: false,
        level: 3,
        xp: 450,
        creationType: 'coins',
        isApproved: true,
        isLogoUnlocked: true,
        tasks: [],
        rules: 'Give constructive design feedback.',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      Community(
        id: 'c4',
        name: 'Voice Stars Club',
        description: 'A community for talented singers, poets, and voice artists. Host rooms and perform! 🎙️',
        category: 'Entertainment',
        type: 'public',
        owner: 'me', // Current user is Owner
        coOwnerIds: [],
        admins: [],
        members: ['me'],
        memberCount: 1,
        isVerified: false,
        level: 1,
        xp: 0,
        creationType: 'apply',
        isApproved: false, // Pending Admin Approval
        isLogoUnlocked: false, // Logo locked until tasks completed
        tasks: [
          CommunityTask(
            id: 't1',
            title: 'Invite 5 Members',
            description: 'Get at least 5 members to join your community',
            target: 5,
            current: 1,
            isCompleted: false,
          ),
          CommunityTask(
            id: 't2',
            title: 'Host a Community Voice Room',
            description: 'Start a voice room linked to this community for at least 15 mins',
            target: 1,
            current: 0,
            isCompleted: false,
          ),
          CommunityTask(
            id: 't3',
            title: 'Publish 3 Posts',
            description: 'Share 3 updates or announcements in the community feed',
            target: 3,
            current: 1,
            isCompleted: false,
          ),
        ],
        rules: 'Support each other. Avoid abusive language in audio stages.',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ]);
  }

  String? createCommunity({
    required String name,
    required String description,
    required String category,
    required String creationType,
    String? logo,
    String? banner,
  }) {
    if (name.trim().isEmpty) return 'Community name cannot be empty';

    if (communities.any((c) => c.owner == currentUserId)) {
      return 'You can only own one community/family at a time.';
    }

    final id = 'comm_${DateTime.now().millisecondsSinceEpoch}';

    if (creationType == 'coins') {
      if (userCoins.value < 10000) {
        return 'Insufficient coin balance. You need 10,000 coins.';
      }
      userCoins.value -= 10000;

      final newComm = Community(
        id: id,
        name: name,
        description: description,
        category: category,
        type: 'public',
        owner: currentUserId,
        coOwnerIds: [],
        admins: [],
        members: [currentUserId],
        memberCount: 1,
        isVerified: false,
        level: 1,
        xp: 0,
        creationType: 'coins',
        isApproved: true,
        isLogoUnlocked: true,
        tasks: [],
        createdAt: DateTime.now(),
        image: logo,
        banner: banner,
      );

      communities.add(newComm);
      return null; // Success
    } else {
      // Apply type: free but pending + needs tasks
      final newComm = Community(
        id: id,
        name: name,
        description: description,
        category: category,
        type: 'public',
        owner: currentUserId,
        coOwnerIds: [],
        admins: [],
        members: [currentUserId],
        memberCount: 1,
        isVerified: false,
        level: 1,
        xp: 0,
        creationType: 'apply',
        isApproved: false, // Pending
        isLogoUnlocked: false, // Locked until tasks are done
        tasks: [
          CommunityTask(
            id: 't1',
            title: 'Invite 5 Members',
            description: 'Get at least 5 members to join your community',
            target: 5,
            current: 1,
            isCompleted: false,
          ),
          CommunityTask(
            id: 't2',
            title: 'Host a Community Voice Room',
            description: 'Start a voice room linked to this community',
            target: 1,
            current: 0,
            isCompleted: false,
          ),
          CommunityTask(
            id: 't3',
            title: 'Publish 3 Posts',
            description: 'Share 3 updates or announcements in the community feed',
            target: 3,
            current: 0,
            isCompleted: false,
          ),
        ],
        createdAt: DateTime.now(),
        image: logo,
        banner: banner,
      );

      communities.add(newComm);
      return null; // Success
    }
  }

  void joinCommunity(String communityId) {
    final idx = communities.indexWhere((c) => c.id == communityId);
    if (idx != -1) {
      final comm = communities[idx];
      if (!comm.members.contains(currentUserId)) {
        final updatedMembers = [...comm.members, currentUserId];
        final updatedCount = comm.memberCount + 1;
        communities[idx] = comm.copyWith(
          members: updatedMembers,
          memberCount: updatedCount,
        );

        // Update task progress if user is the owner
        if (comm.owner == currentUserId) {
          updateTaskProgress(communityId, 't1', updatedCount);
        }
      }
    }
  }

  void leaveCommunity(String communityId) {
    final idx = communities.indexWhere((c) => c.id == communityId);
    if (idx != -1) {
      final comm = communities[idx];
      if (comm.owner == currentUserId) return; // Owner cannot leave

      final updatedMembers = comm.members.where((id) => id != currentUserId).toList();
      final updatedAdmins = comm.admins.where((id) => id != currentUserId).toList();
      final updatedCoOwners = comm.coOwnerIds.where((id) => id != currentUserId).toList();

      communities[idx] = comm.copyWith(
        members: updatedMembers,
        admins: updatedAdmins,
        coOwnerIds: updatedCoOwners,
        memberCount: comm.memberCount > 1 ? comm.memberCount - 1 : 1,
      );
    }
  }

  void kickMember(String communityId, String userId) {
    final idx = communities.indexWhere((c) => c.id == communityId);
    if (idx != -1) {
      final comm = communities[idx];
      
      final updatedMembers = comm.members.where((id) => id != userId).toList();
      final updatedAdmins = comm.admins.where((id) => id != userId).toList();
      final updatedCoOwners = comm.coOwnerIds.where((id) => id != userId).toList();

      communities[idx] = comm.copyWith(
        members: updatedMembers,
        admins: updatedAdmins,
        coOwnerIds: updatedCoOwners,
        memberCount: comm.memberCount > 1 ? comm.memberCount - 1 : 1,
      );
    }
  }

  void updateTaskProgress(String communityId, String taskId, int incrementTo) {
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

      // Check if all tasks are completed to unlock logo
      final allDone = updatedTasks.every((t) => t.isCompleted);

      communities[idx] = comm.copyWith(
        tasks: updatedTasks,
        isLogoUnlocked: allDone ? true : comm.isLogoUnlocked,
      );
    }
  }

  void approveApplication(String communityId) {
    final idx = communities.indexWhere((c) => c.id == communityId);
    if (idx != -1) {
      final comm = communities[idx];
      communities[idx] = comm.copyWith(isApproved: true);
    }
  }

  void promoteMember(String communityId, String userId, String role) {
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

      communities[idx] = comm.copyWith(
        coOwnerIds: coOwners,
        admins: admins,
      );
    }
  }

  void addXp(String communityId, int amount) {
    final idx = communities.indexWhere((c) => c.id == communityId);
    if (idx != -1) {
      final comm = communities[idx];
      int newXp = comm.xp + amount;
      int newLevel = comm.level;
      
      // Basic leveling logic: 1000 xp per level
      if (newXp >= newLevel * 1000) {
        newXp -= newLevel * 1000;
        newLevel += 1;
      }

      communities[idx] = comm.copyWith(
        xp: newXp,
        level: newLevel,
      );
    }
  }

  // Helper to check user role inside a community
  String getUserRole(Community comm) {
    if (comm.owner == currentUserId) return 'Owner';
    if (comm.coOwnerIds.contains(currentUserId)) return 'Co-Owner';
    if (comm.admins.contains(currentUserId)) return 'Admin';
    if (comm.members.contains(currentUserId)) return 'Member';
    return 'Guest';
  }

  // Check if current user has moderator/admin powers
  bool hasPower(Community comm, String power) {
    final role = getUserRole(comm);
    if (role == 'Owner' || role == 'Co-Owner') return true;
    if (role == 'Admin') {
      // Admins have all powers except changing roles of co-owners/owners
      return power != 'manage_roles';
    }
    return false; // Regular members have no admin powers
  }
}
