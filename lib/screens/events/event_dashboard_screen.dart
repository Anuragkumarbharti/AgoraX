import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:creania/core/theme.dart';
import '../../models/event_model.dart';
import '../../models/user_model.dart';
import 'organizer_question_management_screen.dart';
import '../../services/event_controller.dart';
import '../profile/profile_screen.dart';

class EventDashboardScreen extends StatefulWidget {
  const EventDashboardScreen({Key? key, required this.event}) : super(key: key);
  final Event event;

  @override
  State<EventDashboardScreen> createState() => _EventDashboardScreenState();
}

class _EventDashboardScreenState extends State<EventDashboardScreen> {
  final List<Map<String, dynamic>> _cheatReports = [
    {
      'username': 'Rahul22',
      'reason': 'Tab switched 3 times',
      'confidence': '95% AI Confidence',
      'action': 'Suspended',
    },
    {
      'username': 'SonalG',
      'reason': 'Abnormal keyboard input speed',
      'confidence': '80% AI Confidence',
      'action': 'Warning Sent',
    },
  ];

  final EventController _controller = Get.find<EventController>();

  // Member moderation state
  String _memberSearch = '';
  String _memberFilter = 'All';

  void _deleteEvent() {
    final hasStarted = widget.event.startDate.isBefore(DateTime.now());
    final hasParticipants = widget.event.participantsCount > 0;

    if (hasStarted || hasParticipants) {
      Get.dialog(
        AlertDialog(
          backgroundColor: context.secondaryBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text(
                'Constraint Blocked',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'This event cannot be deleted because participants have already joined. You may cancel or archive it instead.',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Cancel Event', style: TextStyle(color: context.errorColor)),
            ),
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Close', style: TextStyle(color: context.caption)),
            ),
          ],
        ),
      );
    } else {
      Get.snackbar(
        '🗑️ Event Deleted',
        'Successfully deleted event',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final liveEvent = _controller.events.firstWhereOrNull((e) => e.id == widget.event.id) ?? widget.event;
      final currentUserId = EventController.currentUserId;
      final isOwner = liveEvent.creatorId == currentUserId;
      final isCoOwner = liveEvent.coOwnerId == currentUserId;

      final double entryFee = liveEvent.entryFeeAmount.toDouble();
      final int registeredCount = liveEvent.registeredUserIds.length;
      final double totalCollection = registeredCount * entryFee;

      // Revenue Distribution
      final double platformFee = totalCollection * 0.17;
      final double creatorEarnings = totalCollection * 0.10;
      final double coOwnerEarnings = totalCollection * 0.05;
      final double adminPoolEarnings = totalCollection * 0.10;
      final double prizePool = totalCollection * 0.58;
      final double netRevenue = totalCollection - platformFee;

      // Admin Reward Splits
      final int adminCount = liveEvent.adminIds.length;
      double adminPctEach = 0.0;
      if (adminCount == 1) adminPctEach = 10.0;
      else if (adminCount == 2) adminPctEach = 5.0;
      else if (adminCount == 3) adminPctEach = 3.33;
      else if (adminCount == 4) adminPctEach = 2.50;
      else if (adminCount == 5) adminPctEach = 2.00;

      final double adminEarnEach = adminCount > 0 ? (adminPoolEarnings / adminCount) : 0.0;

      return ListView(
        padding: EdgeInsets.all(16),
        children: [
          // 1. Dashboard Metrics Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Collection',
                  '₹${totalCollection.toInt()}',
                  Icons.payments_rounded,
                  Color(0xFF10B981),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  'Net Revenue',
                  '₹${netRevenue.toInt()}',
                  Icons.monetization_on_rounded,
                  Color(0xFF6366F1),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Platform Fee (17%)',
                  '₹${platformFee.toInt()}',
                  Icons.receipt_long_outlined,
                  Color(0xFFEF4444),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  'Prize Pool (58%)',
                  '₹${prizePool.toInt()}',
                  Icons.emoji_events_outlined,
                  Color(0xFFFBBF24),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Creator Reward (10%)',
                  '₹${creatorEarnings.toInt()}',
                  Icons.person_rounded,
                  Color(0xFFEC4899),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  'Co-Owner Earn (5%)',
                  '₹${coOwnerEarnings.toInt()}',
                  Icons.handshake_rounded,
                  Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // 2. Admin Reward Splits Dashboard Section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.borderColor.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '🛡️ Admin Reward Pool splits',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Total Pool: 10%',
                        style: TextStyle(color: context.primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Active Admins: $adminCount / 5', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                    Text(
                      adminCount > 0 ? 'Each Admin: $adminPctEach%' : 'Each Admin: 0%',
                      style: TextStyle(color: context.accentOrange, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (adminCount > 0) ...[
                  SizedBox(height: 8),
                  Text(
                    'Payout per Admin: ₹${adminEarnEach.toInt()} (from ₹${adminPoolEarnings.toInt()} pool)',
                    style: TextStyle(color: context.caption, fontSize: 11),
                  ),
                ],
                SizedBox(height: 14),
                Divider(color: context.borderColor),
                SizedBox(height: 10),
                
                // Live Mock Control Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.primaryColor,
                          side: BorderSide(color: context.primaryColor),
                          padding: EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(Icons.add, size: 14),
                        label: Text('Add Mock Admin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: adminCount < 5
                            ? () {
                                final nextId = 'admin_${adminCount + 1}';
                                _controller.addAdminToEvent(liveEvent.id, nextId);
                              }
                            : null,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: BorderSide(color: Colors.redAccent),
                          padding: EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(Icons.remove, size: 14),
                        label: Text('Remove Admin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: adminCount > 0
                            ? () {
                                final lastId = liveEvent.adminIds.last;
                                _controller.removeAdminFromEvent(liveEvent.id, lastId);
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // 3. Winnings Payout States
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPayoutCol('Pending Prize Payout', '₹${prizePool.toInt()}', Colors.amber),
                Container(width: 1, height: 32, color: context.borderColor),
                _buildPayoutCol('Paid Prize Money', '₹0', Colors.white30),
                Container(width: 1, height: 32, color: context.borderColor),
                _buildPayoutCol('Refunded Payouts', '₹0', Colors.white30),
              ],
            ),
          ),
          SizedBox(height: 24),

          // 4. AI Anti-Cheat proctoring reports
          Text(
            '🚨 AI Anti-Cheat proctoring reports',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          ..._cheatReports.map((c) => _buildCheatReportRow(c)),
          SizedBox(height: 24),
          
          // 5. Members: Registration Summary
          _buildRegistrationSummary(liveEvent),
          SizedBox(height: 20),

          // 6. Member Moderation Panel
          _buildMemberModerationPanel(liveEvent),
          SizedBox(height: 20),

          // Live Tournament Controls
          _buildMultiRoundDashboard(liveEvent),

          // Secure Question Bank Card (restricted to Owner and Co-Owner)
          if (isOwner || isCoOwner) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.primaryColor.withOpacity(0.12), context.accentOrange.withOpacity(0.12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.primaryColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.enhanced_encryption_rounded, color: context.primaryColor, size: 22),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Secure Question Bank 🔒',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          liveEvent.registrationDeadline.isBefore(DateTime.now())
                              ? 'LOCKED (registration ended)'
                              : 'Configure password & upload questions.',
                          style: TextStyle(color: context.caption, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Get.to(() => OrganizerQuestionManagementScreen(event: liveEvent)),
                    child: Text('Manage', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
          ],
          SizedBox(height: 24),
          
          // 7. Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _actionButton('Invite Member', Icons.person_add_alt_1_outlined, context.accentOrange, _showInviteDialog),
              _actionButton('Archive Event', Icons.archive_outlined, Colors.white60, () {
                Get.snackbar(
                  '🗳️ Archived',
                  'Event archived successfully',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: context.secondaryBackgroundColor,
                  colorText: context.textPrimary,
                );
              }),
              _actionButton('Delete Event', Icons.delete_outline_rounded, context.errorColor, _deleteEvent),
            ],
          ),
          SizedBox(height: 40),
        ],
      );
    });
  }

  Widget _buildRegistrationSummary(Event e) {
    final int total = e.registeredUserIds.length;
    final int confirmed = total;
    final int pending = 0;
    final int remaining = e.maxParticipants - total;
    final double collection = e.currentCollection;
    final double platform = collection * 0.17;
    final double creator = collection * 0.10;
    final double coOwner = collection * 0.05;
    final double adminPool = collection * 0.10;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📋 Registration Summary',
              style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _regMetric('Total Registered', '$total', Colors.white)),
              Expanded(child: _regMetric('Min Required', '${e.minParticipants}', Colors.amber)),
              Expanded(child: _regMetric('Max Allowed', '${e.maxParticipants}', Colors.white)),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _regMetric('Confirmed', '$confirmed', Colors.green)),
              Expanded(child: _regMetric('Pending', '$pending', Colors.orange)),
              Expanded(child: _regMetric('Seats Left', '$remaining', Color(0xFF6366F1))),
            ],
          ),
          Divider(color: context.borderColor, height: 20),
          Text('💰 Earnings Breakdown',
              style: TextStyle(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _regMetric('Platform (17%)', '₹${platform.toInt()}', Colors.red)),
              Expanded(child: _regMetric('Creator (10%)', '₹${creator.toInt()}', Colors.pink)),
            ],
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _regMetric('Co-Owner (5%)', '₹${coOwner.toInt()}', Colors.purple)),
              Expanded(child: _regMetric('Admin Pool (10%)', '₹${adminPool.toInt()}', Colors.blue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _regMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
        SizedBox(height: 2),
        Text(label, style: TextStyle(color: context.caption, fontSize: 9), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildMemberModerationPanel(Event e) {
    final allMembers = _controller.getParticipantsForEvent(e.id);
    final List<Map<String, dynamic>> filtered = allMembers.where((p) {
      final nameMatch = _memberSearch.isEmpty ||
          (p['name'] as String).toLowerCase().contains(_memberSearch.toLowerCase()) ||
          (p['userId'] as String).toLowerCase().contains(_memberSearch.toLowerCase());
      final filterMatch = _memberFilter == 'All' ||
          (_memberFilter == 'Banned' && p['status'] == 'Banned') ||
          (_memberFilter == 'Muted' && p['status'] == 'Muted') ||
          (_memberFilter == 'Online' && p['online'] == true) ||
          (_memberFilter == 'Pending' && p['paymentStatus'] == 'Pending');
      return nameMatch && filterMatch;
    }).toList();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('👤 Members Moderation',
              style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          // Search bar
          TextField(
            onChanged: (v) => setState(() => _memberSearch = v),
            style: TextStyle(color: context.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by name or user ID…',
              hintStyle: TextStyle(color: context.caption, fontSize: 12),
              prefixIcon: Icon(Icons.search_rounded, color: context.caption, size: 18),
              filled: true,
              fillColor: context.scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
          ),
          SizedBox(height: 10),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Online', 'Banned', 'Muted', 'Pending'].map((f) {
                final isSel = _memberFilter == f;
                return Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f, style: TextStyle(color: isSel ? Colors.white : context.textSecondary, fontSize: 10)),
                    selected: isSel,
                    selectedColor: context.primaryColor,
                    backgroundColor: context.scaffoldBackgroundColor,
                    onSelected: (v) { if (v) setState(() => _memberFilter = f); },
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 12),
          if (filtered.isEmpty)
            Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('No members found.', style: TextStyle(color: context.caption, fontSize: 12))),
            )
          else
            ...filtered.map((p) => _buildMemberRow(e, p)),
        ],
      ),
    );
  }

  Widget _buildMemberRow(Event e, Map<String, dynamic> p) {
    final status = p['status'] as String;
    final payStatus = p['paymentStatus'] as String;
    final isOnline = p['online'] as bool? ?? false;
    final isBanned = status == 'Banned';
    final isMuted = status == 'Muted';

    Color borderColor = context.borderColor.withOpacity(0.3);
    if (isBanned) borderColor = Colors.red.withOpacity(0.4);
    if (isMuted) borderColor = Colors.orange.withOpacity(0.4);

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _navigateToUserProfile(p['userId'] as String, p['name'] as String, p['avatar'] as String),
            child: Stack(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(p['avatar'] as String),
                  radius: 20,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? Colors.green : Colors.grey,
                      border: Border.all(color: context.scaffoldBackgroundColor, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _navigateToUserProfile(p['userId'] as String, p['name'] as String, p['avatar'] as String),
                        child: Text(
                          p['name'] as String,
                          style: TextStyle(color: context.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (isBanned) Text('🚫 Banned', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                    if (isMuted) Text('🔇 Muted', style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text(
                  '${p['role']} • ${p['userId']}',
                  style: TextStyle(color: context.caption, fontSize: 9),
                ),
                Text(
                  'Payment: $payStatus • Joined: ${p['joinTime']}',
                  style: TextStyle(
                    color: payStatus == 'Paid' ? Colors.green : Colors.orange,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (act) {
              final uid = p['userId'] as String;
              final eid = e.id;
              if (act == 'view_profile') _navigateToUserProfile(uid, p['name'] as String, p['avatar'] as String);
              if (act == 'kick') _controller.kickMember(eid, uid);
              if (act == 'ban') _controller.banMember(eid, uid);
              if (act == 'unban') _controller.unbanMember(eid, uid);
              if (act == 'mute') _controller.muteMember(eid, uid);
              if (act == 'refund') _controller.refundEntryFee(eid, uid);
              if (act == 'promote_admin') _controller.promoteMember(eid, uid, 'Admin');
              if (act == 'promote_mod') _controller.promoteMember(eid, uid, 'Moderator');
              if (act == 'promote_coowner') _controller.promoteToCoOwner(eid, uid);
              if (act == 'demote') _controller.demoteAdmin(eid, uid);
            },
            icon: Icon(Icons.more_vert_rounded, color: context.caption, size: 18),
            color: context.secondaryBackgroundColor,
            itemBuilder: (ctx) {
              final currentUserId = EventController.currentUserId;
              final isOwner = e.creatorId == currentUserId;
              final isCoOwner = e.coOwnerId == currentUserId;
              final isAdmin = e.adminIds.contains(currentUserId);

              final targetRole = p['role'] as String;
              final targetIsOwner = e.creatorId == p['userId'];
              final targetIsCoOwner = e.coOwnerId == p['userId'];
              final targetIsAdmin = e.adminIds.contains(p['userId']);

              // Normal Admins cannot moderate co-owners or owners
              if (isAdmin && (targetIsOwner || targetIsCoOwner || targetIsAdmin)) {
                return [
                  const PopupMenuItem(value: 'view_profile', child: Text('👤 View Profile', style: TextStyle(color: Colors.white, fontSize: 12))),
                ];
              }

              // Co-owners cannot moderate owners
              if (isCoOwner && targetIsOwner) {
                return [
                  const PopupMenuItem(value: 'view_profile', child: Text('👤 View Profile', style: TextStyle(color: Colors.white, fontSize: 12))),
                ];
              }

              return [
                const PopupMenuItem(value: 'view_profile', child: Text('👤 View Profile', style: TextStyle(color: Colors.white, fontSize: 12))),
                
                // Moderator powers (Kick, Ban, Mute)
                const PopupMenuItem(value: 'kick', child: Text('🥾 Kick Member', style: TextStyle(color: Colors.white, fontSize: 12))),
                if (!isBanned)
                  const PopupMenuItem(value: 'ban', child: Text('🚫 Ban Member', style: TextStyle(color: Colors.red, fontSize: 12))),
                if (isBanned)
                  const PopupMenuItem(value: 'unban', child: Text('🟢 Unban Member', style: TextStyle(color: Colors.green, fontSize: 12))),
                if (!isMuted)
                  const PopupMenuItem(value: 'mute', child: Text('🔇 Mute in Chat', style: TextStyle(color: Colors.orange, fontSize: 12))),
                
                // Co-Owner/Owner powers (Promoting admins/mods, Refunds)
                if (isOwner || isCoOwner) ...[
                  const PopupMenuItem(value: 'promote_admin', child: Text('🛡️ Promote to Admin', style: TextStyle(color: Colors.white, fontSize: 12))),
                  const PopupMenuItem(value: 'promote_mod', child: Text('⭐ Promote to Moderator', style: TextStyle(color: Colors.white, fontSize: 12))),
                  const PopupMenuItem(value: 'demote', child: Text('👤 Demote to Guest', style: TextStyle(color: Colors.white, fontSize: 12))),
                  const PopupMenuItem(value: 'refund', child: Text('💰 Refund Entry Fee', style: TextStyle(color: Colors.amber, fontSize: 12))),
                ],

                // Owner powers (Promoting to Co-Owner)
                if (isOwner)
                  const PopupMenuItem(value: 'promote_coowner', child: Text('🤝 Make Co-Owner', style: TextStyle(color: Colors.purpleAccent, fontSize: 12))),
              ];
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutCol(String label, String value, Color valColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(color: context.caption, fontSize: 9)),
        SizedBox(height: 4),
        Text(value, style: TextStyle(color: valColor, fontSize: 12, fontWeight: FontWeight.w900)),
      ],
    );
  }

  void _showInviteDialog() {
    final inviteNameCtrl = TextEditingController();
    String selectedRole = 'Moderator';
    final roles = ['Co-Owner', 'Admin', 'Moderator', 'Participant'];

    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: context.secondaryBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.person_add_rounded, color: context.primaryColor, size: 24),
                SizedBox(width: 10),
                Text(
                  'Invite Member (Free)',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invited managers or participants do not pay any coins or entry fees to join this event.',
                  style: TextStyle(color: context.caption, fontSize: 11),
                ),
                SizedBox(height: 14),
                Text('Nickname or User ID', style: TextStyle(color: context.textSecondary, fontSize: 11)),
                SizedBox(height: 6),
                TextField(
                  controller: inviteNameCtrl,
                  style: TextStyle(color: context.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. amit_99',
                    hintStyle: TextStyle(color: context.caption, fontSize: 12),
                    filled: true,
                    fillColor: context.scaffoldBackgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                SizedBox(height: 14),
                Text('Assign Role', style: TextStyle(color: context.textSecondary, fontSize: 11)),
                SizedBox(height: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: context.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedRole,
                      items: roles
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e, style: TextStyle(color: context.textPrimary, fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedRole = val!);
                      },
                      dropdownColor: context.scaffoldBackgroundColor,
                      isExpanded: true,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('Cancel', style: TextStyle(color: context.caption)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final name = inviteNameCtrl.text.trim();
                  if (name.isNotEmpty) {
                    Get.back();
                    final participants = _controller.getParticipantsForEvent(widget.event.id);
                    participants.add({
                      'userId': 'invited_${name.toLowerCase().replaceAll(' ', '_')}',
                      'name': name,
                      'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde',
                      'role': selectedRole,
                      'status': 'Approved',
                      'joinTime': 'Just now',
                      'paymentStatus': 'Free Invite',
                      'online': false,
                    });
                    _controller.eventParticipants[widget.event.id] = List.from(participants);
                    Get.snackbar(
                      '🎉 Invite Sent!',
                      'Successfully invited $name as $selectedRole (Free admission)',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: context.accentOrange.withOpacity(0.9),
                      colorText: Colors.white,
                    );
                  }
                },
                child: Text('Send Invite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(color: context.caption, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildCheatReportRow(Map<String, dynamic> report) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.errorColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.gavel_rounded, color: context.errorColor, size: 18),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report['username'] as String,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${report['reason']} • ${report['confidence']}',
                  style: TextStyle(
                      color: context.caption, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.errorColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              report['action'] as String,
              style: TextStyle(
                color: context.errorColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.12),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withOpacity(0.3))),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 18),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
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
      interests: ['Flutter', 'Competitions', 'Networking'],
      communities: [widget.event.organizer],
      followers: 980,
      following: 210,
      isVerified: userId == 'uid_anurag_101',
      isPremium: false,
      reputation: 1540,
      sid: (userId.hashCode.abs() % 900000 + 100000).toString(),
      level: 4,
      xp: 180,
      totalXp: 1000,
    );
    Get.to(() => ProfileScreen(visitorUser: targetUser));
  }

  int _selectedAnalyticsRound = 0;
  bool _isRoundPaused = false;
  int _roundDelayMinutes = 0;
  double _overrideQuestionTimer = 15.0;
  double _nextRoundTimeShift = 0.0;

  Widget _buildMultiRoundDashboard(Event liveEvent) {
    if (!liveEvent.isMultiRound || liveEvent.rounds.isEmpty) {
      return SizedBox.shrink();
    }

    final rounds = liveEvent.rounds;
    final activeRound = rounds[_selectedAnalyticsRound];

    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🏁 Live Tournament Controls',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              DropdownButton<int>(
                value: _selectedAnalyticsRound,
                dropdownColor: context.secondaryBackgroundColor,
                style: TextStyle(color: Colors.white, fontSize: 12),
                underline: SizedBox.shrink(),
                items: List.generate(rounds.length, (i) {
                  return DropdownMenuItem(value: i, child: Text('Round ${i + 1}: ${rounds[i].name}'));
                }),
                onChanged: (v) {
                  setState(() {
                    _selectedAnalyticsRound = v!;
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 12),
          // Round Statistics
          Row(
            children: [
              Expanded(child: _roundMetricCol('Remaining', '15', Colors.green)),
              Expanded(child: _roundMetricCol('Eliminated', '27', Colors.red)),
              Expanded(child: _roundMetricCol('Attendance', '92%', Colors.blue)),
              Expanded(child: _roundMetricCol('Avg Score', '74 pts', Colors.amber)),
            ],
          ),
          Divider(color: context.borderColor, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '⏱️ Question Timer: ${_overrideQuestionTimer.toInt()}s',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.timer_outlined, color: context.primaryColor, size: 14),
            ],
          ),
          Slider(
            value: _overrideQuestionTimer,
            min: 5.0,
            max: 60.0,
            divisions: 11,
            activeColor: context.primaryColor,
            inactiveColor: Colors.white10,
            onChanged: (val) {
              setState(() {
                _overrideQuestionTimer = val;
              });
            },
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📅 Shift Next Round: ${_nextRoundTimeShift.toInt()} mins',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.schedule_rounded, color: context.accentOrange, size: 14),
            ],
          ),
          Slider(
            value: _nextRoundTimeShift,
            min: -15.0,
            max: 45.0,
            divisions: 12,
            activeColor: context.accentOrange,
            inactiveColor: Colors.white10,
            onChanged: (val) {
              setState(() {
                _nextRoundTimeShift = val;
              });
            },
          ),
          Divider(color: context.borderColor, height: 24),
          Text(
            'Admin Actions',
            style: TextStyle(color: context.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRoundPaused ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                    side: BorderSide(color: _isRoundPaused ? Colors.green : Colors.orange),
                  ),
                  onPressed: () {
                    setState(() {
                      _isRoundPaused = !_isRoundPaused;
                    });
                    Get.snackbar(
                      _isRoundPaused ? '⏸️ Round Paused' : '▶️ Round Resumed',
                      'Successfully synchronized event status to all participant client devices.',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  },
                  icon: Icon(_isRoundPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: _isRoundPaused ? Colors.green : Colors.orange, size: 14),
                  label: Text(_isRoundPaused ? 'Resume Round' : 'Pause Round', style: TextStyle(color: _isRoundPaused ? Colors.green : Colors.orange, fontSize: 10)),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.primaryColor),
                  ),
                  onPressed: () {
                    setState(() {
                      _roundDelayMinutes += 10;
                    });
                    Get.snackbar(
                      '⏰ Round Delayed',
                      'Added 10 minutes break buffer before releasing next round questions.',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  },
                  icon: Icon(Icons.alarm_add_rounded, color: context.primaryColor, size: 14),
                  label: Text('Delay 10m ($_roundDelayMinutes)', style: TextStyle(color: context.primaryColor, fontSize: 10)),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.errorColor),
                  ),
                  onPressed: () {
                    Get.dialog(
                      AlertDialog(
                        backgroundColor: context.secondaryBackgroundColor,
                        title: Text('Emergency Stop Event 🚨', style: TextStyle(color: Colors.white, fontSize: 15)),
                        content: Text('This will immediately terminate all active rounds and lock the event results. This action cannot be undone.', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                        actions: [
                          TextButton(onPressed: () => Get.back(), child: Text('Cancel', style: TextStyle(color: context.caption))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: context.errorColor),
                            onPressed: () {
                              Get.back();
                              Get.snackbar('🚨 Emergency Stop Executed', 'Event terminated and locked.');
                            },
                            child: Text('Terminate'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: Icon(Icons.stop_circle_rounded, color: context.errorColor, size: 14),
                  label: Text('Emergency Stop', style: TextStyle(color: context.errorColor, fontSize: 10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundMetricCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        SizedBox(height: 2),
        Text(label, style: TextStyle(color: context.caption, fontSize: 9)),
      ],
    );
  }
}
