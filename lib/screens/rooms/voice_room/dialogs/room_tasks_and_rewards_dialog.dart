import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/progression/room_progression_models.dart';
import '../../../../services/room/room_progression_controller.dart';
import '../../../../services/room/room_controller.dart';
import '../../../../services/voice/voice_controller.dart';

class RoomTasksAndRewardsDialog extends StatefulWidget {
  final String roomId;
  final String roomName;

  const RoomTasksAndRewardsDialog({
    Key? key,
    required this.roomId,
    required this.roomName,
  }) : super(key: key);

  @override
  State<RoomTasksAndRewardsDialog> createState() =>
      _RoomTasksAndRewardsDialogState();
}

class _RoomTasksAndRewardsDialogState extends State<RoomTasksAndRewardsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    final progCtrl = Get.put(RoomProgressionController());
    final roomCtrl = RoomController.to;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        height: 620,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF38BDF8).withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Bar
            _buildHeader(context, progCtrl, roomCtrl),

            const Divider(color: Colors.white10, height: 1),

            // Tab Bar
            TabBar(
              controller: _tabController,
              isScrollable: false,
              indicatorColor: const Color(0xFF38BDF8),
              indicatorWeight: 3,
              labelColor: const Color(0xFF38BDF8),
              unselectedLabelColor: Colors.white54,
              labelStyle: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'Normal'),
                Tab(text: 'Gold'),
                Tab(text: 'Team'),
                Tab(text: 'Community'),
              ],
            ),

            // Tab View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTaskList(progCtrl, 'normal'),
                  _buildTaskList(progCtrl, 'gold'),
                  _buildTaskList(progCtrl, 'team'),
                  _buildTaskList(progCtrl, 'community'),
                ],
              ),
            ),

            // Treasure Chest Section
            _buildTreasureBoxSection(progCtrl),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, RoomProgressionController progCtrl, RoomController roomCtrl) {
    return Obx(() {
      final room = roomCtrl.rooms.firstWhereOrNull((r) => r.id == widget.roomId);
      final levelProg = progCtrl.roomLevelProgresses[widget.roomId];

      final int currentLevel = levelProg?.currentLevel ?? room?.level ?? 1;
      final int currentVp = levelProg?.currentXp ?? room?.xp ?? 0;

      final config = RoomLevelMatrixConfig.getForLevel(currentLevel);
      final nextConfig = RoomLevelMatrixConfig.getForLevel(currentLevel + 1);

      final int targetVp = nextConfig.requiredVp > 0
          ? nextConfig.requiredVp
          : config.requiredVp;
      final double fillRatio = targetVp > 0
          ? (currentVp / targetVp).clamp(0.0, 1.0)
          : 1.0;
      final int percent = (fillRatio * 100).toInt();

      final int activeMemberCount = VoiceController.to.roomUsers.length;
      final double surgeMultiplier =
          progCtrl.calculateActiveMemberSurgeMultiplier(activeMemberCount);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          gradient: LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'LV $currentLevel ${config.title}',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.info_outline,
                          color: Colors.amber, size: 18),
                      onPressed: () => _showLevelPerksSheet(context, currentLevel),
                      tooltip: 'View Level Perks',
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Realtime VP Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Creania Arena VP Progress',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '$currentVp / $targetVp VP ($percent%)',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFFB800),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fillRatio,
                minHeight: 8,
                backgroundColor: Colors.white10,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
              ),
            ),

            const SizedBox(height: 10),
            // Turbo Surge Status Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.3),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on, color: Colors.amber, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Turbo Surge: ${surgeMultiplier}x VP Speed ($activeMemberCount Active Members in Arena)',
                      style: GoogleFonts.outfit(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTaskList(RoomProgressionController progCtrl, String category) {
    return Obx(() {
      final tasks = progCtrl.roomDailyTaskLists[widget.roomId] ?? [];
      final filteredTasks =
          tasks.where((t) => t.category == category).toList();

      if (filteredTasks.isEmpty) {
        return Center(
          child: Text(
            'No tasks available for $category category.',
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: filteredTasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final task = filteredTasks[index];
          final double progressRatio =
              (task.currentValue / task.targetValue).clamp(0.0, 1.0);

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10, width: 0.8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: task.isCompleted
                      ? Colors.green.withOpacity(0.2)
                      : const Color(0xFF38BDF8).withOpacity(0.15),
                  radius: 18,
                  child: Icon(
                    task.isCompleted ? Icons.check_circle : Icons.star,
                    color: task.isCompleted ? Colors.greenAccent : const Color(0xFF38BDF8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.description,
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 10.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressRatio,
                          minHeight: 5,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            task.isCompleted ? Colors.greenAccent : const Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+${task.xpReward} VP',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFFB800),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${task.currentValue}/${task.targetValue}',
                      style: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildTreasureBoxSection(RoomProgressionController progCtrl) {
    final boxes = [
      {'tier': 'normal', 'name': 'Normal Box', 'color': Colors.blueAccent},
      {'tier': 'gold', 'name': 'Gold Box', 'color': Colors.amber},
      {'tier': 'room', 'name': 'Room Box', 'color': Colors.purpleAccent},
      {'tier': 'legendary', 'name': 'Legend Box', 'color': Colors.redAccent},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0B1120),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: boxes.map((box) {
          final String tier = box['tier'] as String;
          final String name = box['name'] as String;
          final Color color = box['color'] as Color;

          return GestureDetector(
            onTap: () async {
              final res = await progCtrl.claimTreasureBox(tier);
              if (res['success'] == true) {
                Get.snackbar(
                  'Treasure Unlocked!',
                  'Earned +${res['coins_earned']} Coins, +${res['silver_earned']} Silver & +${res['vp_earned']} VP!',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.amber.withOpacity(0.9),
                  colorText: Colors.black,
                );
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2, color: color, size: 26),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showLevelPerksSheet(BuildContext context, int currentLevel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creania Arena Level Perks & Unlocks',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: RoomLevelMatrixConfig.levels.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final cfg = RoomLevelMatrixConfig.levels[index];
                    final bool isUnlocked = currentLevel >= cfg.level;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? Colors.purple.withOpacity(0.12)
                            : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isUnlocked
                              ? Colors.purpleAccent.withOpacity(0.4)
                              : Colors.white10,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Level ${cfg.level}: ${cfg.title}',
                                style: GoogleFonts.outfit(
                                  color: isUnlocked ? Colors.amber : Colors.white60,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${cfg.requiredVp} VP',
                                style: GoogleFonts.poppins(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Caps: ${cfg.maxCoOwners} Co-Owners • ${cfg.maxAdmins} Admins • ${cfg.maxHostSeats} Host Seats',
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cfg.description,
                            style: GoogleFonts.outfit(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
