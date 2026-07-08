import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../models/event_model.dart';
import '../../services/event_controller.dart';
import 'event_detail_screen.dart';
import 'create_event_screen.dart';
import 'wallet_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({Key? key}) : super(key: key);

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final EventController _controller = Get.find<EventController>();

  final List<Map<String, dynamic>> _pastWinners = [
    {
      'name': 'Rahul Sharma',
      'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde',
      'rank': '1st',
      'prize': '🏆 ₹10,000 + Gold Badge',
      'event': 'Weekly Coding Challenge #42',
    },
    {
      'name': 'Pooja Verma',
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
      'rank': '2nd',
      'prize': '🥈 ₹5,000 + Silver Badge',
      'event': 'Weekly Coding Challenge #42',
    },
    {
      'name': 'Amit Kumar',
      'avatar': 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61',
      'rank': '3rd',
      'prize': '🥉 ₹2,500',
      'event': 'Weekly Coding Challenge #42',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Event> get _officialEvents =>
      _controller.events.where((e) => e.isOfficial && e.status != EventStatus.completed && e.status != EventStatus.archived).toList();

  List<Event> get _communityEvents =>
      _controller.events.where((e) => !e.isOfficial && e.status != EventStatus.completed && e.status != EventStatus.archived).toList();

  List<Event> get _pastEvents =>
      _controller.events.where((e) => (e.status == EventStatus.completed || e.status == EventStatus.resultPublished) && DateTime.now().difference(e.endDate).inDays <= 7).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'AgoraX Events',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Obx(() {
            return TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppTheme.accentColor),
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
              label: Text(
                '₹${_controller.cashBalance.value.toInt()}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => Get.to(() => const WalletScreen()),
            );
          }),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textTertiary,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Official'),
            Tab(text: 'Community'),
            Tab(text: 'Past Events'),
            Tab(text: 'My Events'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Host Event',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => Get.to(() => const CreateEventScreen()),
      ),
      body: Obx(() {
        return TabBarView(
          controller: _tabController,
          children: [
            _buildEventsList(_officialEvents, true),
            _buildEventsList(_communityEvents, false),
            _buildPastEventsTab(),
            _buildMyEventsTab(),
          ],
        );
      }),
    );
  }

  Widget _buildEventsList(List<Event> list, bool isOfficial) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isOfficial) ...[
          _buildFeaturedBanner(),
          const SizedBox(height: 20),
          _buildSectionTitle('🔥 Active Competitions'),
        ] else ...[
          _buildSectionTitle('🏫 College & Club Events'),
        ],
        const SizedBox(height: 12),
        ...list.map((e) => _buildEventCard(e)),
        const SizedBox(height: 24),
        if (isOfficial) ...[
          _buildSectionTitle('🏆 Hall of Fame (Past Winners)'),
          const SizedBox(height: 12),
          ..._pastWinners.map((w) => _buildWinnerCard(w)),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildFeaturedBanner() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: NetworkImage(
              'https://images.unsplash.com/photo-1504384308090-c894fdcc538d'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.85),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        alignment: Alignment.bottomLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '👑 FEATURED EVENT',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'National AI Hackathon 2026',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Text(
              'Prize Pool: ₹1,50,000 • Starts in 2 days',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    final entryColor = event.entryFeeType == EntryFeeType.free
        ? AppTheme.accentColor
        : const Color(0xFFFBBF24);

    final int registeredCount = event.registeredUserIds.length;
    final int maxSeats = event.maxParticipants;
    final int seatsLeft = maxSeats - registeredCount;
    final double progress = maxSeats > 0 ? (registeredCount / maxSeats) : 0.0;

    // Time calculations
    final now = DateTime.now();
    final regDiff = event.registrationDeadline.difference(now);
    final startDiff = event.startDate.difference(now);

    final String regEndsStr = regDiff.isNegative
        ? 'Closed'
        : '${regDiff.inHours}h ${regDiff.inMinutes % 60}m';
    final String startInStr = startDiff.isNegative
        ? 'Live / Started'
        : '${startDiff.inDays > 0 ? '${startDiff.inDays}d ' : ''}${startDiff.inHours % 24}h ${startDiff.inMinutes % 60}m';

    return GestureDetector(
      onTap: () => Get.to(() => EventDetailScreen(event: event)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: event.isPaid
                ? AppTheme.primaryColor.withOpacity(0.35)
                : event.isOfficial
                    ? AppTheme.accentColor.withOpacity(0.3)
                    : AppTheme.borderColor.withOpacity(0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner/Image Header
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  Image.network(
                    event.bannerUrl,
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.85),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: event.isPaid
                            ? const Color(0xFF8B5CF6) // Purple for Paid Events
                            : event.isOfficial
                                ? AppTheme.primaryColor
                                : Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            event.isPaid
                                ? Icons.payments_rounded
                                : event.isOfficial
                                    ? Icons.verified_user_rounded
                                    : Icons.campaign_rounded,
                            color: Colors.white,
                            size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            event.isPaid
                                ? '🏆 PAID EVENT'
                                : event.isOfficial
                                    ? '👑 OFFICIAL'
                                    : '🏫 COMMUNITY',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1))
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            event.formatString,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content Panel
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Community and Organizer Metadata
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 8,
                        backgroundColor: AppTheme.primaryColor,
                        child: Icon(Icons.people, size: 10, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        event.organizer,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: Colors.blue, size: 12),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Standard / Paid Detail Ranges
                  if (event.isPaid) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '🏆 Projected Prize Pool',
                          style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                        ),
                        Text(
                          '₹${event.minPrizePool.toInt()} - ₹${event.maxPrizePool.toInt()}',
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Winner Ranges Grid (1st, 2nd, 3rd)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.bgDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildRewardRangeItem('🥇 1st', event.minPrizePool * 0.50, event.maxPrizePool * 0.50),
                          Container(width: 1, height: 24, color: AppTheme.borderColor),
                          _buildRewardRangeItem('🥈 2nd', event.minPrizePool * 0.30, event.maxPrizePool * 0.30),
                          Container(width: 1, height: 24, color: AppTheme.borderColor),
                          _buildRewardRangeItem('🥉 3rd', event.minPrizePool * 0.20, event.maxPrizePool * 0.20),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Prize Pool', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                        Text(
                          event.prizePool,
                          style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Registration Progress Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Seats: $registeredCount / $maxSeats Joined',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Min Req: ${event.minParticipants}',
                        style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppTheme.bgDark,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0
                            ? Colors.redAccent
                            : event.isPaid
                                ? const Color(0xFF8B5CF6)
                                : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Timing and Entry Fee Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 13, color: AppTheme.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            'Ends in: $regEndsStr',
                            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: entryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: entryColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          event.entryFeeType == EntryFeeType.free
                              ? 'FREE ENTRY'
                              : 'Entry: ₹${event.entryFeeAmount}',
                          style: TextStyle(
                            color: entryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
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
      ),
    );
  }

  Widget _buildRewardRangeItem(String title, double min, double max) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(
          '₹${min.toInt()}-₹${max.toInt()}',
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildWinnerCard(Map<String, dynamic> winner) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(winner['avatar'] as String),
            radius: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  winner['name'] as String,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  winner['event'] as String,
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                winner['rank'] as String,
                style: const TextStyle(
                  color: AppTheme.accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                winner['prize'] as String,
                style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _myEventsFilter = 'Upcoming';

  Widget _buildPastEventsTab() {
    return Obx(() {
      final list = _pastEvents;
      if (list.isEmpty) {
        return const Center(
          child: Text(
            'No completed events in the last 7 days.',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final e = list[index];
          return _buildPastEventCard(e);
        },
      );
    });
  }

  Widget _buildPastEventCard(Event e) {
    return GestureDetector(
      onTap: () => Get.to(() => EventDetailScreen(event: e)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                image: DecorationImage(
                  image: NetworkImage(e.bannerUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            e.status == EventStatus.resultPublished ? 'RESULTS OUT' : 'COMPLETED',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.organizer,
                        style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                      ),
                      Text(
                        e.entryFeeType == EntryFeeType.free
                            ? 'FREE'
                            : e.entryFeeType == EntryFeeType.cash
                                ? '₹${e.entryFeeAmount}'
                                : '🪙 ${e.entryFeeAmount}',
                        style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    e.title,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _pastCardMetric(Icons.people_alt_outlined, '${e.participantsCount} Joined'),
                      _pastCardMetric(Icons.emoji_events_outlined, e.prizePool),
                      _pastCardMetric(Icons.person_pin_circle_outlined, '${e.winners.length} Winners'),
                    ],
                  ),
                  const Divider(color: AppTheme.borderColor, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ended: ${_formatDate(e.endDate)}',
                        style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                      ),
                      Text(
                        'Duration: ${e.durationString}',
                        style: const TextStyle(color: AppTheme.accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pastCardMetric(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 12),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildMyEventsTab() {
    final List<Event> matched = [];
    final myId = EventController.currentUserId;
    
    for (final e in _controller.events) {
      final isOwner = e.creatorId == myId;
      final isCoOwner = e.coOwnerId == myId;
      final isAdmin = e.adminIds.contains(myId);
      
      if (isOwner || isCoOwner || isAdmin) {
        bool match = false;
        if (_myEventsFilter == 'Upcoming') {
          match = e.status == EventStatus.registrationOpen || e.status == EventStatus.registrationClosed || e.status == EventStatus.startingSoon;
        } else if (_myEventsFilter == 'Live') {
          match = e.status == EventStatus.live;
        } else if (_myEventsFilter == 'Completed') {
          match = e.status == EventStatus.completed || e.status == EventStatus.resultPublished;
        } else if (_myEventsFilter == 'Cancelled') {
          match = e.status == EventStatus.archived;
        }
        if (match) {
          matched.add(e);
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['Upcoming', 'Live', 'Completed', 'Cancelled'].map((f) {
            final isSel = _myEventsFilter == f;
            return ChoiceChip(
              label: Text(f, style: TextStyle(color: isSel ? Colors.white : AppTheme.textSecondary, fontSize: 11)),
              selected: isSel,
              selectedColor: AppTheme.primaryColor,
              backgroundColor: AppTheme.cardBg,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _myEventsFilter = f;
                  });
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        _buildSectionTitle('🛡️ Events You Manage ($_myEventsFilter)'),
        const SizedBox(height: 12),
        if (matched.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No $_myEventsFilter events where you are Host/Admin.',
                style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
              ),
            ),
          )
        else
          ...matched.map((e) {
            String roleBadge = '👑 Owner';
            Color badgeCol = const Color(0xFFF59E0B);
            if (e.coOwnerId == myId) {
              roleBadge = '🛡️ Co-Owner';
              badgeCol = const Color(0xFF10B981);
            } else if (e.adminIds.contains(myId)) {
              roleBadge = '🛡️ Admin';
              badgeCol = const Color(0xFF3B82F6);
            }
            return _buildMyManagedRow(e, roleBadge, badgeCol);
          }),
      ],
    );
  }

  Widget _buildMyManagedRow(Event event, String roleBadge, Color roleColor) {
    return GestureDetector(
      onTap: () => Get.to(() => EventDetailScreen(event: event)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: NetworkImage(event.bannerUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    event.organizer,
                    style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: roleColor.withOpacity(0.3)),
              ),
              child: Text(
                roleBadge,
                style: TextStyle(
                  color: roleColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
