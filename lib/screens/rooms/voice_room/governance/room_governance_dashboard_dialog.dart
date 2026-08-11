import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../models/room/room_governance_model.dart';
import '../../../../services/room/room_governance_controller.dart';
import '../../../../services/user/user_profile_cache_manager.dart';
import 'dialogs/anti_fake_admin_dialog.dart';
import 'widgets/role_priority_badge_widget.dart';

class RoomGovernanceDashboardDialog extends StatefulWidget {
  final String roomId;
  final String roomName;

  const RoomGovernanceDashboardDialog({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  static Future<void> show(BuildContext context, {required String roomId, required String roomName}) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoomGovernanceDashboardDialog(roomId: roomId, roomName: roomName),
    );
  }

  @override
  State<RoomGovernanceDashboardDialog> createState() => _RoomGovernanceDashboardDialogState();
}

class _RoomGovernanceDashboardDialogState extends State<RoomGovernanceDashboardDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late RoomGovernanceController _controller;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    if (!Get.isRegistered<RoomGovernanceController>()) {
      _controller = Get.put(RoomGovernanceController());
    } else {
      _controller = Get.find<RoomGovernanceController>();
    }
    _controller.fetchGovernanceOverview(widget.roomId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0B1120),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF3B82F6), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Room Governance Dashboard',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        widget.roomName,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: const Color(0xFF3B82F6),
            labelColor: const Color(0xFF3B82F6),
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: '📊 Scores & Ranks'),
              Tab(text: '🛡️ Role Counters'),
              Tab(text: '🚨 Emergency Hub'),
              Tab(text: '📜 Activity Logs'),
              Tab(text: '⚠️ Warnings'),
            ],
          ),
          const Divider(color: Colors.white10, height: 1),

          // Tab Body
          Expanded(
            child: Obx(() {
              if (_controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
              }
              final overview = _controller.overview.value;
              if (overview == null) {
                return const Center(child: Text('Failed to load governance data.', style: TextStyle(color: Colors.white54)));
              }

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildScoresTab(overview),
                  _buildRoleCountersTab(overview),
                  _buildEmergencyTab(overview),
                  _buildLogsTab(overview),
                  _buildWarningsTab(overview),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // 1. Scores & Ranks Tab
  Widget _buildScoresTab(RoomGovernanceOverview overview) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Governance Level Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF1E1B4B), const Color(0xFF312E81)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('👑 Room Governance Level', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Level ${overview.governanceLevel}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                overview.governanceRankName,
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 4),
              const Text('Higher Governance Levels boost discovery priority, unlock exclusive room themes & official event eligibility.', style: TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Health Score & Security Score Grid
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    const Text('Room Health Score', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    Text('${overview.healthScore} / 100', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 22)),
                    const SizedBox(height: 4),
                    const Text('Retention & Mic Rate', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade500.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    const Text('Security Score', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    Text('${overview.securityScore.toStringAsFixed(1)} ⭐', style: TextStyle(color: Colors.amber.shade400, fontWeight: FontWeight.bold, fontSize: 22)),
                    const SizedBox(height: 4),
                    const Text('Spam & Abuse Index', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 2. Role Counters Tab
  Widget _buildRoleCountersTab(RoomGovernanceOverview overview) {
    final counters = overview.roleCounters;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Live Realtime Role Counters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        _counterTile('⭐ Creator / Owner', '${counters.owner} / ${counters.maxOwners}', const Color(0xFFFFD700)),
        _counterTile('💎 Co-Owners', '${counters.coOwner} / ${counters.maxCoOwners}', const Color(0xFF9D4EDD)),
        _counterTile('🛡️ Admins', '${counters.admin} / ${counters.maxAdmins}', const Color(0xFF3A86EF)),
        _counterTile('🎧 Audience Members', '${counters.audience}', Colors.white70),
      ],
    );
  }

  Widget _counterTile(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  // 3. Emergency Hub Tab
  Widget _buildEmergencyTab(RoomGovernanceOverview overview) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _controller.isEmergencyMode.value ? Colors.red.shade900.withOpacity(0.4) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _controller.isEmergencyMode.value ? Colors.red : Colors.white24, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🚨 1-Click Emergency Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  Switch(
                    value: _controller.isEmergencyMode.value,
                    activeColor: Colors.redAccent,
                    onChanged: (val) => _controller.toggleEmergencyMode(widget.roomId, val),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('In case of spam attacks or severe room abuse, 1-click Emergency Mode instantly locks all seats, slows chat, disables mic requests, and mutes audience.', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  // 4. Audit & Activity Logs Tab
  Widget _buildLogsTab(RoomGovernanceOverview overview) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: overview.permissionHistory.length,
      itemBuilder: (ctx, idx) {
        final item = overview.permissionHistory[idx];
        final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(item.createdAt);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${item.actionType} (${item.newRole ?? ""})', style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(formattedDate, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Actor Role: ${item.actorRole}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        );
      },
    );
  }

  // 5. Warnings Tab
  Widget _buildWarningsTab(RoomGovernanceOverview overview) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: overview.activeWarnings.length,
      itemBuilder: (ctx, idx) {
        final warning = overview.activeWarnings[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade700, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Warning Level ${warning.warningLevel}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Reason: ${warning.reason}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
              const Text('Active ⚠️', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }
}
