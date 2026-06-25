import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import 'voice_room_call_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({Key? key}) : super(key: key);

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  late List<Map<String, dynamic>> _rooms;

  @override
  void initState() {
    super.initState();
    _initializeRooms();
  }

  void _initializeRooms() {
    _rooms = [
      {
        'id': 'room_001',
        'name': 'Flutter Development Discussion',
        'host': 'John Doe',
        'participants': 234,
        'type': 'Discussion',
        'isLive': true,
      },
      {
        'id': 'room_002',
        'name': 'UPSC Preparation - Morning Session',
        'host': 'Raj Kumar',
        'participants': 567,
        'type': 'Study',
        'isLive': true,
      },
      {
        'id': 'room_003',
        'name': 'AI & Machine Learning Q&A',
        'host': 'Sarah Smith',
        'participants': 189,
        'type': 'Discussion',
        'isLive': true,
      },
      {
        'id': 'room_004',
        'name': 'Web Development Tips & Tricks',
        'host': 'Alex Johnson',
        'participants': 0,
        'type': 'Hangout',
        'isLive': false,
      },
      {
        'id': 'room_005',
        'name': 'Gaming Tournament - BGMI',
        'host': 'Pro Gamer X',
        'participants': 0,
        'type': 'Hangout',
        'isLive': false,
      },
      {
        'id': 'room_006',
        'name': 'Business Networking Evening',
        'host': 'Corporate Trainer',
        'participants': 0,
        'type': 'Event',
        'isLive': false,
      },
    ];
  }

  void _joinRoom(Map<String, dynamic> room) {
    Get.to(
      () => VoiceRoomCallScreen(
        roomId: room['id'],
        roomName: room['name'],
        userId: 'user_123', // TODO: Get from auth
        userName: 'Current User', // TODO: Get from auth
        isHost: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveRooms = _rooms.where((r) => r['isLive']).toList();
    final scheduledRooms = _rooms.where((r) => !r['isLive']).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Voice Rooms',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Get.snackbar(
                  'Coming Soon',
                  'Create room feature coming soon',
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
            ),
          ],
          bottom: TabBar(
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
        ),
        body: TabBarView(
          children: [
            // Live Rooms
            _buildRoomsList(context, liveRooms, isLive: true),

            // Scheduled Rooms
            _buildRoomsList(context, scheduledRooms, isLive: false),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomsList(
    BuildContext context,
    List<Map<String, dynamic>> rooms, {
    required bool isLive,
  }) {
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
              isLive ? 'No live rooms' : 'No scheduled rooms',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRoomCard(context, room, isLive),
        );
      },
    );
  }

  Widget _buildRoomCard(
    BuildContext context,
    Map<String, dynamic> room,
    bool isLive,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor, width: 0.5),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isLive)
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: Text(
                              'LIVE',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            room['name'],
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hosted by ${room['host']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Text(
                        room['type'],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryColor,
                              fontSize: 11,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isLive)
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    '${room['participants']} listening',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isLive ? () => _joinRoom(room) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: Text(
                    isLive ? 'Join Now' : 'Notify',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  Get.snackbar(
                    'Saved',
                    '${room['name']} saved',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
                child: const Icon(Icons.bookmark_outline, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
