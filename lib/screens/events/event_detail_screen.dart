import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:creania/core/theme.dart';
import '../../widgets/common/optimized_image.dart';
import '../../models/community/event_model.dart';
import '../../models/user/user_model.dart';
import '../../services/community/event_controller.dart';
import '../profile/profile_screen.dart';
import './event_dashboard_screen.dart';
import './live_event_lobby_screen.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({Key? key, required this.event}) : super(key: key);
  final Event event;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Timer _timer;
  Duration _timeLeft = const Duration();
  final EventController _controller = Get.find<EventController>();

  bool get _isRegistered => widget.event.registeredUserIds.contains(EventController.currentUserId);

  final List<Map<String, dynamic>> _announcements = [
    {
      'title': 'Syllabus Updated',
      'body': 'Please check the attachments. Graph algorithms (BFS/DFS) added.',
      'time': '1h ago',
    },
    {
      'title': 'Test instructions released',
      'body': 'Make sure screen monitoring permission is granted before launch.',
      'time': '3h ago',
    },
  ];

  final List<Map<String, dynamic>> _leaderboard = [
    {'rank': 1, 'name': 'AdityaK', 'score': 98, 'time': '14m 20s'},
    {'rank': 2, 'name': 'SnehaP', 'score': 95, 'time': '15m 10s'},
    {'rank': 3, 'name': 'KunalR', 'score': 92, 'time': '18m 02s'},
    {'rank': 4, 'name': 'RohanM', 'score': 90, 'time': '16m 45s'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _calculateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateTimeLeft();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _calculateTimeLeft() {
    final diff = widget.event.startDate.difference(DateTime.now());
    if (mounted) {
      setState(() {
        _timeLeft = diff.isNegative ? Duration.zero : diff;
      });
    }
  }

  void _register() {
    if (widget.event.requiredLevel > 14) {
      Get.snackbar(
        'Eligibility Failed 🔒',
        'This event requires Level ${widget.event.requiredLevel}. You are Level 14.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    if (widget.event.isPaid && widget.event.entryFeeType == EntryFeeType.cash) {
      if (_controller.cashBalance.value < widget.event.entryFeeAmount) {
        Get.snackbar(
          'Insufficient Cash 💰',
          'You need ₹${widget.event.entryFeeAmount} in your wallet to register.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: context.errorColor.withOpacity(0.9),
          colorText: Colors.white,
        );
        return;
      }
    }

    if (!widget.event.isOfficial && widget.event.creatorId == EventController.currentUserId) {
      Get.snackbar('Restricted Action ⛔', 'Creators cannot join their own events.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.9), colorText: Colors.white);
      return;
    }

    final isCoOwner = widget.event.coOwnerId == EventController.currentUserId;
    final isAdmin = widget.event.adminIds.contains(EventController.currentUserId);
    if ((isCoOwner || isAdmin) && !widget.event.allowAdminsJoin) {
      Get.snackbar('Restricted Action ⛔', 'Co-owners & Admins are not allowed to join this event.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.9), colorText: Colors.white);
      return;
    }

    _showRegistrationForm();
  }

  void _showRegistrationForm() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final upiCtrl = TextEditingController();
    bool agreeTerms = false;
    bool hasPhoto = false;

    final reqFields = widget.event.requiredRegistrationFields;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.secondaryBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.borderColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '📝 Event Registration Details',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'The event organizer requires you to provide the following details to join.',
                      style: TextStyle(
                        color: context.caption,
                        fontSize: 11,
                      ),
                    ),
                    SizedBox(height: 18),

                    // Profile Photo upload
                    if (reqFields.contains('photo')) ...[
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() => hasPhoto = true);
                          },
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: context.scaffoldBackgroundColor,
                            backgroundImage: hasPhoto
                                ? const NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde')
                                : null,
                            child: !hasPhoto
                                ? Icon(Icons.add_a_photo_outlined, color: context.primaryColor, size: 28)
                                : null,
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Center(
                        child: Text(
                          'Upload Profile Photo',
                          style: TextStyle(color: context.caption, fontSize: 11),
                        ),
                      ),
                      SizedBox(height: 14),
                    ],

                    // Full Name
                    if (reqFields.contains('name')) ...[
                      _modalField('Full Name', nameCtrl, 'Enter your full name', (v) => v!.isEmpty ? 'Name required' : null),
                      SizedBox(height: 12),
                    ],

                    // Email Address
                    if (reqFields.contains('email')) ...[
                      _modalField('Email Address', emailCtrl, 'Enter email address', (v) => !v!.contains('@') ? 'Invalid email' : null),
                      SizedBox(height: 12),
                    ],

                    // Phone Number
                    if (reqFields.contains('phone')) ...[
                      _modalField('Phone Number', phoneCtrl, 'Enter mobile number', (v) => v!.length < 10 ? 'Invalid number' : null),
                      SizedBox(height: 12),
                    ],

                    // UPI ID
                    if (reqFields.contains('upi_id')) ...[
                      _modalField('UPI ID (For cash prize distribution)', upiCtrl, 'e.g. name@upi', (v) => v!.isEmpty ? 'UPI required' : null),
                      SizedBox(height: 12),
                    ],

                    SizedBox(height: 6),
                    // Custom Terms & Conditions from Organizer
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.borderColor.withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚖️ Terms & Conditions',
                            style: TextStyle(
                              color: context.primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            widget.event.termsAndConditions,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),

                    Row(
                      children: [
                        Checkbox(
                          value: agreeTerms,
                          activeColor: context.primaryColor,
                          checkColor: Colors.white,
                          onChanged: (v) {
                            setModalState(() => agreeTerms = v!);
                          },
                        ),
                        Expanded(
                          child: Text(
                            'I agree to the terms and rules of this competition.',
                            style: TextStyle(color: context.textSecondary, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: agreeTerms ? context.primaryColor : context.borderColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: !agreeTerms
                            ? null
                            : () {
                                if (formKey.currentState!.validate()) {
                                  if (reqFields.contains('photo') && !hasPhoto) {
                                    Get.snackbar(
                                      'Photo Required 📸',
                                      'Please upload your profile photo first',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: context.errorColor.withOpacity(0.9),
                                      colorText: Colors.white,
                                    );
                                    return;
                                  }
                                  
                                  Navigator.pop(context); // close sheet

                                  // Simulated Payment Gateway Loader Overlay
                                  Get.dialog(
                                    barrierDismissible: false,
                                    AlertDialog(
                                      backgroundColor: context.secondaryBackgroundColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(color: context.primaryColor),
                                          SizedBox(height: 20),
                                          Text(
                                            'Verifying Payment Gateway...',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Securing connection and confirming entry fee.',
                                            style: TextStyle(color: context.caption, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );

                                  // Confirm registration after 1.5 seconds loader
                                  Timer(const Duration(milliseconds: 1500), () async {
                                    Get.back(); // close loader dialog
                                    
                                    final Map<String, dynamic> regDetails = {
                                      'name': nameCtrl.text,
                                      'email': emailCtrl.text,
                                      'phone': phoneCtrl.text,
                                      'upi_id': upiCtrl.text,
                                    };

                                    final bool joined = await _controller.registerForEvent(widget.event.id, regDetails);
                                    if (joined) {
                                      setState(() {});
                                    }
                                  });
                                }
                              },
                        child: Text(
                          'Confirm Registration',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _modalField(String label, TextEditingController ctrl, String hint, String? Function(String?)? validator) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.textSecondary, fontSize: 11)),
        SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          validator: validator,
          style: TextStyle(color: context.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.caption, fontSize: 12),
            filled: true,
            fillColor: context.scaffoldBackgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final entryColor = widget.event.entryFeeType == EntryFeeType.free
        ? context.accentOrange
        : Color(0xFFFBBF24);

    final userId = EventController.currentUserId;
    final isOwner = widget.event.creatorId == userId;
    final isCoOwner = widget.event.coOwnerId == userId;
    final isAdmin = widget.event.adminIds.contains(userId);
    final hasAdminPrivileges = isOwner || isCoOwner || isAdmin;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          _buildSliverAppBar(),
        ],
        body: Column(
          children: [
            TabBar(
              controller: _tabController,
              indicatorColor: context.primaryColor,
              labelColor: context.primaryColor,
              unselectedLabelColor: context.caption,
              labelStyle:
                  TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: [
                const Tab(text: 'Overview'),
                const Tab(text: 'Announcements'),
                const Tab(text: 'Leaderboard'),
                Tab(text: hasAdminPrivileges ? 'Dashboard' : 'Members'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(entryColor),
                  _buildAnnouncementsTab(),
                  _buildLeaderboardTab(),
                  hasAdminPrivileges
                      ? EventDashboardScreen(event: widget.event)
                      : _buildMembersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(entryColor),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 200,
      backgroundColor: context.scaffoldBackgroundColor,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            OptimizedImage(
              imageUrl: widget.event.bannerUrl,
              preset: MediaSizePreset.lg,
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: widget.event.isOfficial
                              ? context.primaryColor
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.event.isOfficial ? '👑 OFFICIAL' : '🏫 COMMUNITY',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.accentOrange.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: context.accentOrange.withOpacity(0.5)),
                        ),
                        child: Text(
                          widget.event.formatString,
                          style: TextStyle(
                              color: context.accentOrange,
                              fontSize: 9,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.event.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'by ${widget.event.organizer}',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(Color entryColor) {
    final isCompleted = widget.event.status == EventStatus.completed || widget.event.status == EventStatus.resultPublished;
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // ─── WINNER PODIUM (completed events only) ───
        if (isCompleted && widget.event.winners.isNotEmpty) ...[
          _buildWinnerPodium(),
          SizedBox(height: 20),
        ],
        // ─── EVENT TIMELINE ───
        _buildEventTimeline(),
        if (widget.event.isMultiRound && widget.event.rounds.isNotEmpty) ...[
          SizedBox(height: 20),
          _buildTournamentSchedule(),
        ],
        SizedBox(height: 20),
        // Countdown banner (active events only)
        if (!isCompleted)
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Starts in',
                      style: TextStyle(
                          color: context.caption, fontSize: 11)),
                  Text('Countdown Timer',
                      style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Text(
                '${_timeLeft.inDays}d : ${_timeLeft.inHours % 24}h : ${_timeLeft.inMinutes % 60}m : ${_timeLeft.inSeconds % 60}s',
                style: TextStyle(
                  color: context.primaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        Text('About the Event',
            style: TextStyle(
                color: context.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        Text(
          widget.event.description,
          style: TextStyle(
              color: context.textSecondary, fontSize: 13, height: 1.5),
        ),
        _detailRow('Prize Pool', widget.event.prizePool, Icons.military_tech),
        _detailRow('Negative Marking',
            widget.event.negativeMarking ? 'Yes (-0.25)' : 'No', Icons.warning_amber),
        _detailRow('Anti-Cheat Active',
            widget.event.antiCheat.screenMonitoring ? 'Screen Monitoring' : 'None',
            Icons.security),
        if (widget.event.isPaid) ...[
          SizedBox(height: 20),
          Text('⚖️ Revenue Transparency Breakdown',
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.secondaryBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.primaryColor.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                _buildTransparencyBreakdownItem('🏆 Player Prize Pool (58%)', '58%', '₹${(widget.event.minPrizePool).toInt()} - ₹${(widget.event.maxPrizePool).toInt()}', isHighlighted: true),
                Divider(color: context.borderColor),
                _buildTransparencyBreakdownItem('🛡️ Platform Fee (Payment Gateway incl.)', '17%', '₹${(widget.event.minCollection * 0.17).toInt()} - ₹${(widget.event.maxCollection * 0.17).toInt()}'),
                _buildTransparencyBreakdownItem('👑 Creator Reward', '10%', '₹${(widget.event.minCollection * 0.10).toInt()} - ₹${(widget.event.maxCollection * 0.10).toInt()}'),
                _buildTransparencyBreakdownItem('🤝 Co-Owner Reward', '5%', '₹${(widget.event.minCollection * 0.05).toInt()} - ₹${(widget.event.maxCollection * 0.05).toInt()}'),
                _buildTransparencyBreakdownItem('🛡️ Admin Reward Pool', '10%', '₹${(widget.event.minCollection * 0.10).toInt()} - ₹${(widget.event.maxCollection * 0.10).toInt()}'),
                SizedBox(height: 8),
                Text(
                  'Current registered player count (${widget.event.registeredUserIds.length}) has raised ₹${widget.event.currentCollection.toInt()} collection, resulting in a live prize pool of ₹${widget.event.currentPrizePool.toInt()}.',
                  style: TextStyle(color: context.caption, fontSize: 10, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: 20),
        Text('Rules & Regulations',
            style: TextStyle(
                color: context.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        ...widget.event.rules.map(
          (rule) => Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ',
                    style: TextStyle(
                        color: context.primaryColor,
                        fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    rule,
                    style: TextStyle(
                        color: context.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: context.primaryColor, size: 18),
          SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: context.caption, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsTab() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _announcements.length,
      itemBuilder: (ctx, i) {
        final ann = _announcements[i];
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ann['title'] as String,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    ann['time'] as String,
                    style: TextStyle(
                        color: context.caption, fontSize: 11),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                ann['body'] as String,
                style: TextStyle(
                    color: context.textSecondary, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardTab() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _leaderboard.length,
      itemBuilder: (ctx, i) {
        final entry = _leaderboard[i];
        final rank = entry['rank'] as int;
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: rank <= 3
                  ? context.primaryColor.withOpacity(0.3)
                  : context.borderColor.withOpacity(0.4),
            ),
          ),
          child: Row(
            children: [
              Text(
                '$rank',
                style: TextStyle(
                  color: rank == 1
                      ? Color(0xFFFBBF24)
                      : rank == 2
                          ? Color(0xFF94A3B8)
                          : rank == 3
                              ? Color(0xFFB45309)
                              : context.caption,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 16),
              Text(
                entry['name'] as String,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'Score: ${entry['score']}',
                style: TextStyle(
                    color: context.accentOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 12),
              Text(
                entry['time'] as String,
                style: TextStyle(
                    color: context.caption, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(Color entryColor) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: context.secondaryBackgroundColor,
        border: Border(top: BorderSide(color: context.borderColor.withOpacity(0.4))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Entry Fee',
                  style: TextStyle(color: context.caption, fontSize: 11)),
              Text(
                widget.event.entryFeeType == EntryFeeType.free
                    ? 'FREE'
                    : widget.event.entryFeeType == EntryFeeType.cash
                        ? '₹${widget.event.entryFeeAmount}'
                        : '🪙 ${widget.event.entryFeeAmount}',
                style: TextStyle(
                  color: entryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(width: 24),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRegistered
                      ? context.accentOrange
                      : context.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isRegistered
                    ? () => Get.to(() => LiveEventLobbyScreen(event: widget.event))
                    : _register,
                child: Text(
                  _isRegistered ? 'Enter Live Lobby 🚀' : 'Register Now',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransparencyBreakdownItem(String label, String percent, String range, {bool isHighlighted = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isHighlighted ? Colors.white : context.textSecondary,
                fontSize: 11,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            percent,
            style: TextStyle(
              color: isHighlighted ? context.accentOrange : context.caption,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 14),
          Text(
            range,
            style: TextStyle(
              color: isHighlighted ? Color(0xFFFBBF24) : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─── WINNER PODIUM ───────────────────────────────────────────────────────────
  Widget _buildWinnerPodium() {
    final winners = widget.event.winners;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFFFBBF24).withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFBBF24).withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: Color(0xFFFBBF24), size: 22),
              SizedBox(width: 8),
              Text(
                '🏆 Prize Pool Winners',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Text(
                  'VERIFIED ✓',
                  style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Total Distributed: ₹${winners.fold(0.0, (sum, w) => sum + w.prizeWon).toInt()}',
            style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          // Podium row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (winners.length > 1) Expanded(child: _podiumCard(winners[1], '🥈', 2, Color(0xFFC0C0C0), 100)),
              SizedBox(width: 8),
              Expanded(child: _podiumCard(winners[0], '🥇', 1, Color(0xFFFFD700), 120)),
              SizedBox(width: 8),
              if (winners.length > 2) Expanded(child: _podiumCard(winners[2], '🥉', 3, Color(0xFFCD7F32), 80)),
            ],
          ),
          if (winners.length > 3) ...[
            SizedBox(height: 16),
            Divider(color: context.borderColor),
            Text(
              'Other Winners',
              style: TextStyle(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ...winners.sublist(3).map((w) => _buildOtherWinnerRow(w)),
          ],
        ],
      ),
    );
  }

  Widget _podiumCard(EventWinner w, String medal, int rank, Color medalColor, double height) {
    return GestureDetector(
      onTap: () => _navigateToUserProfile(w.userId, w.username, w.avatarUrl),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: medalColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: medalColor.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: medalColor, width: 2),
                image: DecorationImage(
                  image: NetworkImage(w.avatarUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: 6),
            Text(medal, style: TextStyle(fontSize: 18)),
            Text(
              w.username,
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '₹${w.prizeWon.toInt()}',
              style: TextStyle(color: medalColor, fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherWinnerRow(EventWinner w) {
    return GestureDetector(
      onTap: () => _navigateToUserProfile(w.userId, w.username, w.avatarUrl),
      child: Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            ClipOval(
              child: OptimizedImage(imageUrl: w.avatarUrl, width: 32, height: 32, preset: MediaSizePreset.xs, fit: BoxFit.cover),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.username, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  Text(w.community, style: TextStyle(color: context.caption, fontSize: 10)),
                ],
              ),
            ),
            Text(
              '${w.rank} · ₹${w.prizeWon.toInt()}',
              style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToUserProfile(String userId, String username, String avatarUrl) {
    final targetUser = User(
      id: userId,
      username: username.toLowerCase().replaceAll(' ', '_'),
      email: '$userId@creania.app',
      displayName: username,
      avatar: avatarUrl,
      interests: ['Flutter', 'Coding Contest', 'BGMI'],
      communities: [widget.event.organizer],
      followers: 1200,
      following: 340,
      isVerified: userId == 'uid_anurag_101',
      isPremium: false,
      reputation: 1980,
      sid: (userId.hashCode.abs() % 900000 + 100000).toString(),
      level: 5,
      xp: 220,
      totalXp: 1000,
    );
    Get.to(() => ProfileScreen(visitorUser: targetUser));
  }

  // ─── EVENT TIMELINE ───────────────────────────────────────────────────────────
  Widget _buildEventTimeline() {
    final steps = [
      {'label': 'Registration Started', 'icon': Icons.app_registration_rounded, 'done': true},
      {'label': 'Registration Ends', 'icon': Icons.lock_clock_outlined, 'done': widget.event.registrationDeadline.isBefore(DateTime.now())},
      {'label': 'Event Starts', 'icon': Icons.play_circle_outline_rounded, 'done': widget.event.startDate.isBefore(DateTime.now())},
      {'label': 'Event Ends', 'icon': Icons.stop_circle_outlined, 'done': widget.event.endDate.isBefore(DateTime.now())},
      {'label': 'Winner Verification', 'icon': Icons.verified_user_outlined, 'done': widget.event.status == EventStatus.completed || widget.event.status == EventStatus.resultPublished},
      {'label': 'Prize Distribution', 'icon': Icons.payments_outlined, 'done': widget.event.status == EventStatus.resultPublished},
      {'label': 'Completed', 'icon': Icons.check_circle_rounded, 'done': widget.event.status == EventStatus.completed || widget.event.status == EventStatus.resultPublished},
    ];

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📍 Event Timeline',
            style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) {
            final i = entry.key;
            final step = entry.value;
            final isDone = step['done'] as bool;
            final isLast = i == steps.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? context.primaryColor.withOpacity(0.2)
                            : context.secondaryBackgroundColor,
                        border: Border.all(
                          color: isDone ? context.primaryColor : context.borderColor,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        step['icon'] as IconData,
                        size: 14,
                        color: isDone ? context.primaryColor : context.caption,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 24,
                        color: isDone ? context.primaryColor.withOpacity(0.4) : context.borderColor,
                      ),
                  ],
                ),
                SizedBox(width: 12),
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    step['label'] as String,
                    style: TextStyle(
                      color: isDone ? context.textPrimary : context.caption,
                      fontSize: 12,
                      fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTournamentSchedule() {
    final rounds = widget.event.rounds;
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🏆 Tournament Schedule & Rounds',
            style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          ...rounds.asMap().entries.map((entry) {
            final i = entry.key;
            final round = entry.value;
            final isLast = i == rounds.length - 1;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.primaryColor.withOpacity(0.15),
                            border: Border.all(color: context.primaryColor, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(color: context.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        if (!isLast || round.breakTimeMinutes > 0)
                          Container(
                            width: 2,
                            height: 32,
                            color: context.primaryColor.withOpacity(0.3),
                          ),
                      ],
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            round.name,
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Format: ${round.format} • Qs: ${round.totalQuestions} • Criteria: ${round.qualifyingCriteria}',
                            style: TextStyle(color: context.caption, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (round.breakTimeMinutes > 0 && !isLast)
                  Padding(
                    padding: EdgeInsets.only(left: 13),
                    child: Row(
                      children: [
                        Container(
                          width: 2,
                          height: 16,
                          color: context.primaryColor.withOpacity(0.3),
                        ),
                        SizedBox(width: 20),
                        Icon(Icons.coffee_rounded, color: context.accentOrange, size: 12),
                        SizedBox(width: 6),
                        Text(
                          'Break: ${round.breakTimeMinutes} Minutes',
                          style: TextStyle(color: context.accentOrange, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    final registeredUsers = widget.event.registeredUserIds;
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Section 1: Event Managers (Creator, Co-Owner, Admins)
        Text(
          '👑 Event Managers',
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        _buildMemberRow(widget.event.creatorId == 'me' ? 'My Account (Owner)' : 'Priya Sharma (Owner)', 'Owner', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330'),
        if (widget.event.coOwnerId != null)
          _buildMemberRow(widget.event.coOwnerId == 'me' ? 'My Account (Co-Owner)' : 'Rahul Verma (Co-Owner)', 'Co-Owner', 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde'),
        ...widget.event.adminIds.map((adminId) {
          return _buildMemberRow(adminId == 'me' ? 'My Account (Admin)' : 'Amit Patel (Admin)', 'Admin', 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61');
        }),
        Divider(color: context.borderColor, height: 32),

        // Section 2: Members (Registered Users)
        Text(
          '👥 Members (${registeredUsers.length})',
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        if (registeredUsers.isEmpty)
          Text('No members registered yet.', style: TextStyle(color: context.caption, fontSize: 11))
        else
          ...registeredUsers.map((uid) {
            return _buildMemberRow(uid == 'me' ? 'My Account (Guest)' : 'Rohan Das', 'Guest', 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61');
          }),
        Divider(color: context.borderColor, height: 32),

        // Section 3: Audience (Spectators)
        Text(
          '🎙️ Audience & Spectators',
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        _buildMemberRow('Meera Nair', 'Audience', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2'),
        _buildMemberRow('Sonal Gupta', 'Audience', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb'),
      ],
    );
  }

  Widget _buildMemberRow(String displayName, String role, String avatarUrl) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _navigateToUserProfile(displayName.split(' ')[0].toLowerCase(), displayName, avatarUrl),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(avatarUrl),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _navigateToUserProfile(displayName.split(' ')[0].toLowerCase(), displayName, avatarUrl),
              child: Text(
                displayName,
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: role == 'Owner'
                  ? Colors.redAccent.withOpacity(0.12)
                  : role == 'Co-Owner'
                      ? Colors.orangeAccent.withOpacity(0.12)
                      : role == 'Admin'
                          ? Colors.blueAccent.withOpacity(0.12)
                          : Colors.grey.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: role == 'Owner'
                    ? Colors.redAccent
                    : role == 'Co-Owner'
                        ? Colors.orangeAccent
                        : role == 'Admin'
                            ? Colors.blueAccent
                            : Colors.grey,
                width: 0.5,
              ),
            ),
            child: Text(
              role.toUpperCase(),
              style: TextStyle(
                color: role == 'Owner'
                    ? Colors.redAccent
                    : role == 'Co-Owner'
                        ? Colors.orangeAccent
                        : role == 'Admin'
                            ? Colors.blueAccent
                            : Colors.white70,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

