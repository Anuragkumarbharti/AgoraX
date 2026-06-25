import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../models/room_model.dart';
import '../../services/room_controller.dart';
import 'create_room_screen.dart';
import 'room_profile_screen.dart';
import 'voice_room_call_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({Key? key}) : super(key: key);

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final RoomController _controller = RoomController.to;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _joinRoom(VoiceRoom room) {
    Get.to(
      () => VoiceRoomCallScreen(
        roomId: room.id,
        roomName: room.name,
        userId: 'uid_anurag_101', // Fixed unique User ID
        userName: 'anurag_kumar', // Copyable username
        isHost: false,
      ),
    );
  }

  List<VoiceRoom> _filterRooms(List<VoiceRoom> rooms) {
    if (_searchQuery.trim().isEmpty) return rooms;
    final query = _searchQuery.toLowerCase().trim();

    return rooms.where((room) {
      final nameMatch = room.name.toLowerCase().contains(query);
      final idMatch = room.id.toLowerCase().contains(query);
      final categoryMatch = room.category.toLowerCase().contains(query);
      final countryMatch = room.country.toLowerCase().contains(query);
      final langMatch = room.language.toLowerCase().contains(query);
      final tagMatch = room.tags.any((t) => t.toLowerCase().contains(query));

      return nameMatch || idMatch || categoryMatch || countryMatch || langMatch || tagMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(
          'Voice Rooms',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        actions: [
          // Wallet indicator
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Obx(() => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.bgLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${_controller.walletBalance.value}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )),
          ),
          // Create Room Button
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor, size: 28),
            onPressed: () => Get.to(() => const CreateRoomScreen()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by Name, ID (#VX100...), Tag or Category',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textTertiary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textTertiary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Tabs
          Expanded(
            child: Obx(() {
              final filtered = _filterRooms(_controller.rooms);
              final liveRooms = filtered.where((r) => r.isLive).toList();
              final scheduledRooms = filtered.where((r) => !r.isLive).toList();

              return DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: AppTheme.textTertiary,
                      indicatorColor: AppTheme.primaryColor,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.radio_button_on, size: 16),
                              const SizedBox(width: 8),
                              Text('Live (${liveRooms.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Text('Scheduled (${scheduledRooms.length})'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildRoomsList(liveRooms, isLive: true),
                          _buildRoomsList(scheduledRooms, isLive: false),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsList(List<VoiceRoom> rooms, {required bool isLive}) {
    if (rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLive ? Icons.radio_button_off : Icons.calendar_today,
              size: 64,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              isLive ? 'No live rooms found' : 'No scheduled rooms found',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRoomCard(room, isLive),
        );
      },
    );
  }

  Widget _buildRoomCard(VoiceRoom room, bool isLive) {
    return GestureDetector(
      onTap: () => Get.to(() => RoomProfileScreen(roomId: room.id)),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: room.isPermanent ? Colors.amber.withOpacity(0.5) : AppTheme.borderColor,
            width: room.isPermanent ? 1.5 : 0.5,
          ),
          boxShadow: room.isPermanent
              ? [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section (Room ID, Permanent Tag, Level)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      room.id,
                      style: TextStyle(
                        color: room.isPermanent ? Colors.amber : AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: room.isPermanent ? Colors.amber.withOpacity(0.15) : AppTheme.bgLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        room.isPermanent ? 'Permanent' : 'Temporary',
                        style: TextStyle(
                          color: room.isPermanent ? Colors.amber : AppTheme.textTertiary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (room.isPermanent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.indigoAccent, width: 0.5),
                    ),
                    child: Text(
                      'LV ${room.level}',
                      style: const TextStyle(
                        color: Colors.indigoAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Middle Section: Name, Owner, Category Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.bgLight,
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: room.avatar != null
                        ? Image.network(room.avatar!, fit: BoxFit.cover)
                        : Center(
                            child: Text(
                              room.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Host
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hosted by ${room.ownerName}',
                        style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      // Info row: Category, Country, Language
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              room.category,
                              style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '• ${room.language} • ${room.country}',
                            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Live status or scheduled date
                if (isLive)
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      '${room.participantCount} in call',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  )
              ],
            ),
            const SizedBox(height: 16),

            // Bottom Section: Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLive ? () => _joinRoom(room) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLive
                          ? (room.isPermanent ? Colors.amber : AppTheme.primaryColor)
                          : AppTheme.bgLight,
                      foregroundColor: isLive
                          ? (room.isPermanent ? Colors.black87 : Colors.white)
                          : AppTheme.textTertiary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isLive ? 'Join Call' : 'Scheduled',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => Get.to(() => RoomProfileScreen(roomId: room.id)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                  child: const Icon(Icons.info_outline, size: 20, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
