import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/room_model.dart';

class RoomController extends GetxController {
  static RoomController get to => Get.find<RoomController>();

  final RxInt walletBalance = 1000.obs;
  final RxList<VoiceRoom> rooms = <VoiceRoom>[].obs;
  
  // Track participant states per room (simulated local states)
  // roomId -> list of muted user IDs
  final RxMap<String, List<String>> mutedUsers = <String, List<String>>{}.obs;
  // roomId -> list of banned user IDs
  final RxMap<String, List<String>> bannedUsers = <String, List<String>>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _loadInitialRooms();
  }

  void _loadInitialRooms() {
    final now = DateTime.now();
    rooms.assignAll([
      VoiceRoom(
        id: '#VX100001',
        name: 'Coding Hub 🚀',
        description: 'The ultimate space for Flutter & Dart developers to share, debug, and learn together.',
        hostId: 'host_001',
        ownerName: 'Anurag Kumar Bharti',
        communityId: 'comm_001',
        type: 'Public',
        isLive: true,
        participantCount: 142,
        maxParticipants: 500,
        speakerIds: ['host_001', 'user_abc', 'user_xyz'],
        listenerIds: List.generate(139, (i) => 'listener_$i'),
        allowRecording: true,
        allowScreenShare: true,
        createdAt: now.subtract(const Duration(days: 10)),
        startedAt: now.subtract(const Duration(hours: 3)),
        isPermanent: true,
        level: 4,
        xp: 3200,
        totalMembers: 1200,
        totalFollowers: 3400,
        totalGiftsReceived: 24500,
        category: 'Education Room',
        country: 'India',
        language: 'Hindi & English',
        tags: ['flutter', 'dart', 'coding', 'tech'],
        rules: [
          'Be respectful to other developers.',
          'No spamming or self-promotion without approval.',
          'Keep discussion relevant to software development.'
        ],
        coOwnerIds: ['user_abc'],
        adminIds: ['user_xyz', 'user_pqr'],
        starMemberIds: ['user_st1', 'user_st2'],
        avatar: 'https://images.unsplash.com/photo-1542831371-29b0f74f9713?w=150',
        banner: 'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?w=600',
      ),
      VoiceRoom(
        id: '#VX100002',
        name: 'Music Lovers Acoustic 🎸',
        description: 'Singing, acoustic guitars, and chatting about our favorite bands and indie records.',
        hostId: 'host_002',
        ownerName: 'Siddharth Roy',
        communityId: 'comm_002',
        type: 'Public',
        isLive: true,
        participantCount: 89,
        maxParticipants: 300,
        speakerIds: ['host_002', 'musician_1'],
        listenerIds: List.generate(87, (i) => 'listener_$i'),
        allowRecording: false,
        allowScreenShare: false,
        createdAt: now.subtract(const Duration(days: 15)),
        startedAt: now.subtract(const Duration(hours: 1)),
        isPermanent: true,
        level: 2,
        xp: 1200,
        totalMembers: 450,
        totalFollowers: 890,
        totalGiftsReceived: 5600,
        category: 'Music Room',
        country: 'India',
        language: 'English',
        tags: ['music', 'singing', 'acoustic', 'chill'],
        rules: [
          'Wait for your turn on the mic.',
          'Support other musicians with virtual gifts!',
          'Keep criticism constructive and polite.'
        ],
        coOwnerIds: [],
        adminIds: ['admin_m1'],
        starMemberIds: ['star_m1'],
        avatar: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150',
        banner: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600',
      ),
      VoiceRoom(
        id: 'room_temp_1',
        name: 'Chill Hangout Tonight',
        description: 'Just checking in, casual late night chats. Everyone is welcome to grab a mic!',
        hostId: 'host_temp_1',
        ownerName: 'Priya Sharma',
        communityId: 'comm_003',
        type: 'Public',
        isLive: true,
        participantCount: 14,
        maxParticipants: 50,
        speakerIds: ['host_temp_1'],
        listenerIds: List.generate(13, (i) => 'listener_temp_$i'),
        allowRecording: true,
        allowScreenShare: true,
        createdAt: now.subtract(const Duration(hours: 2)),
        startedAt: now.subtract(const Duration(minutes: 90)),
        isPermanent: false,
        level: 1,
        xp: 0,
        totalMembers: 0,
        totalFollowers: 0,
        totalGiftsReceived: 0,
        category: 'Podcast Room',
        country: 'India',
        language: 'Hindi',
        tags: ['chill', 'chat', 'night'],
        rules: ['No abusive language.'],
        coOwnerIds: [],
        adminIds: [],
        starMemberIds: [],
      ),
      VoiceRoom(
        id: 'room_temp_2',
        name: 'Debate: AI vs Human Creativity',
        description: 'Is generative AI replacing artists and writers? Bring your strong arguments.',
        hostId: 'host_temp_2',
        ownerName: 'Vikram Aditya',
        communityId: 'comm_004',
        type: 'Public',
        isLive: true,
        participantCount: 45,
        maxParticipants: 100,
        speakerIds: ['host_temp_2', 'debater_1', 'debater_2'],
        listenerIds: List.generate(42, (i) => 'listener_temp2_$i'),
        allowRecording: true,
        allowScreenShare: true,
        createdAt: now.subtract(const Duration(hours: 1)),
        startedAt: now.subtract(const Duration(minutes: 45)),
        isPermanent: false,
        level: 1,
        xp: 0,
        totalMembers: 0,
        totalFollowers: 0,
        totalGiftsReceived: 0,
        category: 'Debate Room',
        country: 'India',
        language: 'English',
        tags: ['debate', 'ai', 'creativity', 'future'],
        rules: [
          'No personal attacks.',
          'Speak for maximum 3 minutes at a time.',
          'Let others complete their point.'
        ],
        coOwnerIds: [],
        adminIds: [],
        starMemberIds: [],
      ),
      VoiceRoom(
        id: '#VX100003',
        name: 'Weekly Startup Pitch Session 💡',
        description: 'Pitch your startup ideas and get feedback from experienced co-founders.',
        hostId: 'host_003',
        ownerName: 'Amit Mehra',
        communityId: 'comm_005',
        type: 'Public',
        isLive: false,
        participantCount: 0,
        maxParticipants: 200,
        speakerIds: [],
        listenerIds: [],
        allowRecording: true,
        allowScreenShare: true,
        createdAt: now,
        isPermanent: true,
        level: 3,
        xp: 2200,
        totalMembers: 300,
        totalFollowers: 670,
        totalGiftsReceived: 12000,
        category: 'Business Room',
        country: 'Global',
        language: 'English',
        tags: ['startup', 'pitch', 'funding', 'ideas'],
        rules: ['Strictly professional communication only.'],
        coOwnerIds: [],
        adminIds: ['admin_b1'],
        starMemberIds: [],
        avatar: 'https://images.unsplash.com/photo-1515378791036-0648a3ef77b2?w=150',
        banner: 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=600',
      ),
      VoiceRoom(
        id: 'room_temp_3',
        name: 'Upcoming: Gaming Clan Q&A',
        description: 'Discuss strategy and tournament lineups for esports next week.',
        hostId: 'host_temp_3',
        ownerName: 'Hydra OP',
        communityId: 'comm_006',
        type: 'Public',
        isLive: false,
        participantCount: 0,
        maxParticipants: 50,
        speakerIds: [],
        listenerIds: [],
        allowRecording: false,
        allowScreenShare: true,
        createdAt: now,
        isPermanent: false,
        level: 1,
        xp: 0,
        totalMembers: 0,
        totalFollowers: 0,
        totalGiftsReceived: 0,
        category: 'Gaming Room',
        country: 'India',
        language: 'Hindi',
        tags: ['esports', 'pubg', 'gaming', 'chill'],
        rules: ['No toxicity.'],
        coOwnerIds: [],
        adminIds: [],
        starMemberIds: [],
      )
    ]);
  }

  // Create a temporary room (Free)
  void createTemporaryRoom({
    required String name,
    required String description,
    required String category,
    required String country,
    required String language,
    required List<String> tags,
    required List<String> rules,
    required String entryPermission,
    String? avatar,
    String? banner,
  }) {
    final String tempId = 'room_temp_${Random().nextInt(90000) + 10000}';
    final VoiceRoom newRoom = VoiceRoom(
      id: tempId,
      name: name,
      description: description,
      hostId: 'current_user',
      ownerName: 'Current User', // Simulated logged-in user
      communityId: 'comm_custom',
      type: 'Public',
      isLive: true,
      participantCount: 1,
      maxParticipants: 50,
      speakerIds: ['current_user'],
      listenerIds: [],
      allowRecording: true,
      allowScreenShare: true,
      createdAt: DateTime.now(),
      startedAt: DateTime.now(),
      isPermanent: false,
      level: 1,
      xp: 0,
      totalMembers: 0,
      totalFollowers: 0,
      totalGiftsReceived: 0,
      category: category,
      country: country,
      language: language,
      tags: tags,
      rules: rules,
      entryPermission: entryPermission,
      coOwnerIds: [],
      adminIds: [],
      starMemberIds: [],
      avatar: avatar,
      banner: banner,
    );

    rooms.insert(0, newRoom);
    Get.snackbar(
      'Success',
      'Temporary Voice Room created successfully!',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  // Create a permanent room (Costs 599 Gold Coins)
  bool createPermanentRoom({
    required String name,
    required String description,
    required String category,
    required String country,
    required String language,
    required List<String> tags,
    required List<String> rules,
    required String entryPermission,
    String? avatar,
    String? banner,
  }) {
    if (walletBalance.value < 599) {
      Get.snackbar(
        'Insufficient Balance',
        'You need 599 Gold Coins to unlock a Permanent Room. Current balance: ${walletBalance.value} coins.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return false;
    }

    // Deduct coins
    walletBalance.value -= 599;

    // Generate permanent Room ID (e.g. #VX786543)
    final int randomId = Random().nextInt(900000) + 100000;
    final String permId = '#VX$randomId';

    final VoiceRoom newRoom = VoiceRoom(
      id: permId,
      name: name,
      description: description,
      hostId: 'current_user',
      ownerName: 'Current User',
      communityId: 'comm_custom',
      type: 'Public',
      isLive: true,
      participantCount: 1,
      maxParticipants: 200,
      speakerIds: ['current_user'],
      listenerIds: [],
      allowRecording: true,
      allowScreenShare: true,
      createdAt: DateTime.now(),
      startedAt: DateTime.now(),
      isPermanent: true,
      level: 1,
      xp: 0,
      totalMembers: 1,
      totalFollowers: 0,
      totalGiftsReceived: 0,
      category: category,
      country: country,
      language: language,
      tags: tags,
      rules: rules,
      entryPermission: entryPermission,
      coOwnerIds: [],
      adminIds: [],
      starMemberIds: [],
      avatar: avatar ?? 'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?w=150',
      banner: banner ?? 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600',
    );

    rooms.insert(0, newRoom);
    Get.snackbar(
      'Success',
      'Unlocked Permanent Voice Room: $permId! Deducted 599 Gold Coins.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.withOpacity(0.8),
      colorText: Colors.white,
    );
    return true;
  }

  // Send a gift inside a room
  // This deducts coins from the user, updates the room XP, and triggers level-up popups if threshold is met
  bool sendGiftToRoom(String roomId, {required int giftCost, required String giftName, required String fromUserName}) {
    if (walletBalance.value < giftCost) {
      Get.snackbar(
        'Insufficient Coins',
        'You need $giftCost Gold Coins to send this gift. You currently have ${walletBalance.value} coins.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return false;
    }

    walletBalance.value -= giftCost;

    final int index = rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final VoiceRoom oldRoom = rooms[index];

      // XP gained is equal to gift cost * 5
      final int xpGain = giftCost * 5;
      final int newXp = oldRoom.xp + xpGain;
      
      // Calculate level-up: Each level requires level * 1000 XP
      int newLevel = oldRoom.level;
      int tempLevel = oldRoom.level;
      int xpNeeded = tempLevel * 1000;
      int remainingXp = newXp;

      while (remainingXp >= xpNeeded && tempLevel < 10) {
        remainingXp -= xpNeeded;
        tempLevel++;
        xpNeeded = tempLevel * 1000;
      }
      newLevel = tempLevel;

      final bool leveledUp = newLevel > oldRoom.level;

      final VoiceRoom updatedRoom = VoiceRoom(
        id: oldRoom.id,
        name: oldRoom.name,
        description: oldRoom.description,
        hostId: oldRoom.hostId,
        communityId: oldRoom.communityId,
        type: oldRoom.type,
        isLive: oldRoom.isLive,
        participantCount: oldRoom.participantCount,
        maxParticipants: oldRoom.maxParticipants,
        speakerIds: oldRoom.speakerIds,
        listenerIds: oldRoom.listenerIds,
        recordingUrl: oldRoom.recordingUrl,
        allowRecording: oldRoom.allowRecording,
        allowScreenShare: oldRoom.allowScreenShare,
        createdAt: oldRoom.createdAt,
        startedAt: oldRoom.startedAt,
        endedAt: oldRoom.endedAt,
        avatar: oldRoom.avatar,
        banner: oldRoom.banner,
        ownerName: oldRoom.ownerName,
        category: oldRoom.category,
        country: oldRoom.country,
        language: oldRoom.language,
        tags: oldRoom.tags,
        rules: oldRoom.rules,
        level: newLevel,
        xp: leveledUp ? remainingXp : newXp,
        badges: oldRoom.badges + (leveledUp ? 1 : 0),
        totalMembers: oldRoom.totalMembers,
        totalFollowers: oldRoom.totalFollowers,
        totalGiftsReceived: oldRoom.totalGiftsReceived + giftCost,
        isPermanent: oldRoom.isPermanent,
        entryPermission: oldRoom.entryPermission,
        coOwnerIds: oldRoom.coOwnerIds,
        adminIds: oldRoom.adminIds,
        starMemberIds: oldRoom.starMemberIds,
        extraCoOwnerSlots: oldRoom.extraCoOwnerSlots,
        extraAdminSlots: oldRoom.extraAdminSlots,
        extraStarMemberSlots: oldRoom.extraStarMemberSlots,
      );

      rooms[index] = updatedRoom;

      if (leveledUp) {
        Get.dialog(
          LevelUpDialog(
            roomId: roomId,
            roomName: oldRoom.name,
            oldLevel: oldRoom.level,
            newLevel: newLevel,
          ),
          barrierDismissible: true,
        );
      } else {
        Get.snackbar(
          'Gift Sent! 🎁',
          '$fromUserName sent a $giftName ($giftCost Coins) to the room! +$xpGain Room XP.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF6366F1).withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    }
    return true;
  }

  // Buy role slots upgrade (using Gold Coins)
  bool buyRoleUpgrade(String roomId, String roleType, int cost) {
    if (walletBalance.value < cost) {
      Get.snackbar(
        'Insufficient Balance',
        'Upgrading role slots costs $cost coins. Current balance: ${walletBalance.value} coins.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return false;
    }

    walletBalance.value -= cost;

    final int index = rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final VoiceRoom oldRoom = rooms[index];
      int coSlots = oldRoom.extraCoOwnerSlots;
      int adminSlots = oldRoom.extraAdminSlots;
      int starSlots = oldRoom.extraStarMemberSlots;

      if (roleType == 'Co-owner') {
        coSlots++;
      } else if (roleType == 'Admin') {
        adminSlots++;
      } else if (roleType == 'Star Member') {
        starSlots++;
      }

      rooms[index] = VoiceRoom(
        id: oldRoom.id,
        name: oldRoom.name,
        description: oldRoom.description,
        hostId: oldRoom.hostId,
        communityId: oldRoom.communityId,
        type: oldRoom.type,
        isLive: oldRoom.isLive,
        participantCount: oldRoom.participantCount,
        maxParticipants: oldRoom.maxParticipants,
        speakerIds: oldRoom.speakerIds,
        listenerIds: oldRoom.listenerIds,
        recordingUrl: oldRoom.recordingUrl,
        allowRecording: oldRoom.allowRecording,
        allowScreenShare: oldRoom.allowScreenShare,
        createdAt: oldRoom.createdAt,
        startedAt: oldRoom.startedAt,
        endedAt: oldRoom.endedAt,
        avatar: oldRoom.avatar,
        banner: oldRoom.banner,
        ownerName: oldRoom.ownerName,
        category: oldRoom.category,
        country: oldRoom.country,
        language: oldRoom.language,
        tags: oldRoom.tags,
        rules: oldRoom.rules,
        level: oldRoom.level,
        xp: oldRoom.xp,
        badges: oldRoom.badges,
        totalMembers: oldRoom.totalMembers,
        totalFollowers: oldRoom.totalFollowers,
        totalGiftsReceived: oldRoom.totalGiftsReceived,
        isPermanent: oldRoom.isPermanent,
        entryPermission: oldRoom.entryPermission,
        coOwnerIds: oldRoom.coOwnerIds,
        adminIds: oldRoom.adminIds,
        starMemberIds: oldRoom.starMemberIds,
        extraCoOwnerSlots: coSlots,
        extraAdminSlots: adminSlots,
        extraStarMemberSlots: starSlots,
      );

      Get.snackbar(
        'Upgrade Unlocked! ⭐',
        'Purchased 1 extra $roleType slot for room ${oldRoom.id}.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
      );
      return true;
    }
    return false;
  }

  // Moderation: Mute User
  void toggleMuteUser(String roomId, String userId) {
    final list = mutedUsers[roomId] ?? [];
    if (list.contains(userId)) {
      list.remove(userId);
      Get.snackbar('Moderation', 'User unmuted', snackPosition: SnackPosition.BOTTOM);
    } else {
      list.add(userId);
      Get.snackbar('Moderation', 'User muted', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.amber.withOpacity(0.8));
    }
    mutedUsers[roomId] = List<String>.from(list);
  }

  // Moderation: Ban User
  void banUser(String roomId, String userId) {
    final list = bannedUsers[roomId] ?? [];
    if (!list.contains(userId)) {
      list.add(userId);
      bannedUsers[roomId] = List<String>.from(list);
      Get.snackbar('Moderation', 'User banned and kicked from room', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.8));
    }
  }

  // Add Member
  void followRoom(String roomId) {
    final int index = rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final old = rooms[index];
      rooms[index] = VoiceRoom(
        id: old.id,
        name: old.name,
        description: old.description,
        hostId: old.hostId,
        communityId: old.communityId,
        type: old.type,
        isLive: old.isLive,
        participantCount: old.participantCount,
        maxParticipants: old.maxParticipants,
        speakerIds: old.speakerIds,
        listenerIds: old.listenerIds,
        recordingUrl: old.recordingUrl,
        allowRecording: old.allowRecording,
        allowScreenShare: old.allowScreenShare,
        createdAt: old.createdAt,
        startedAt: old.startedAt,
        endedAt: old.endedAt,
        avatar: old.avatar,
        banner: old.banner,
        ownerName: old.ownerName,
        category: old.category,
        country: old.country,
        language: old.language,
        tags: old.tags,
        rules: old.rules,
        level: old.level,
        xp: old.xp,
        badges: old.badges,
        totalMembers: old.totalMembers + 1,
        totalFollowers: old.totalFollowers + 1,
        totalGiftsReceived: old.totalGiftsReceived,
        isPermanent: old.isPermanent,
        entryPermission: old.entryPermission,
        coOwnerIds: old.coOwnerIds,
        adminIds: old.adminIds,
        starMemberIds: old.starMemberIds,
        extraCoOwnerSlots: old.extraCoOwnerSlots,
        extraAdminSlots: old.extraAdminSlots,
        extraStarMemberSlots: old.extraStarMemberSlots,
      );
      Get.snackbar('Room joined', 'You are now a member of ${old.name}', snackPosition: SnackPosition.BOTTOM);
    }
  }

  // Level Up logic helper
  int getXpForNextLevel(int currentLevel) {
    return currentLevel * 1000;
  }
}

// Interactive level up dialog widget
class LevelUpDialog extends StatelessWidget {
  final String roomId;
  final String roomName;
  final int oldLevel;
  final int newLevel;

  const LevelUpDialog({
    Key? key,
    required this.roomId,
    required this.roomName,
    required this.oldLevel,
    required this.newLevel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.amber, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.stars,
              color: Colors.amber,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              'ROOM LEVEL UP! 🎉',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              roomName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLevelCircle(context, oldLevel.toString(), 'Level'),
                const SizedBox(width: 16),
                const Icon(Icons.arrow_forward, color: Colors.white54, size: 28),
                const SizedBox(width: 16),
                _buildLevelCircle(context, newLevel.toString(), 'Level', isNew: true),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'New role slots and entry permissions have been unlocked for this room!',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text(
                'Awesome!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCircle(BuildContext context, String text, String label, {bool isNew = false}) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isNew ? Colors.amber : Colors.white10,
            border: Border.all(
              color: isNew ? Colors.amberAccent : Colors.white24,
              width: 2,
            ),
            boxShadow: isNew
                ? [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.4),
                      blurRadius: 10,
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isNew ? Colors.black87 : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}
