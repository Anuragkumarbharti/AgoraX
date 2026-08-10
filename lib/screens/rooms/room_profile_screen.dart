import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../widgets/common/optimized_image.dart';
import '../../models/room/room_model.dart';
import '../../models/progression/room_progression_models.dart';
import '../../services/room/room_controller.dart';
import '../../widgets/room/room_upgrade_dialog.dart';

class RoomProfileScreen extends StatelessWidget {
  final String roomId;

  const RoomProfileScreen({
    Key? key,
    required this.roomId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final RoomController controller = RoomController.to;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Obx(() {
        final roomIndex = controller.rooms.indexWhere((r) => r.id == roomId);
        if (roomIndex == -1) {
          return const Center(child: Text('Arena not found'));
        }
        final VoiceRoom room = controller.rooms[roomIndex];

        final int roomLvl = room.level > 0 ? room.level : 1;
        final nextCfg = RoomLevelMatrixConfig.getForLevel(roomLvl + 1);
        final int xpNeeded = nextCfg.requiredVp > 0 ? nextCfg.requiredVp : 35500;
        final double xpProgress = (room.xp / xpNeeded).clamp(0.0, 1.0);

        return CustomScrollView(
          slivers: [
            // Sliver App Bar with Banner
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: AppTheme.bgDark,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Banner Image
                    room.banner != null
                        ? OptimizedImage(
                            imageUrl: room.banner!,
                            preset: MediaSizePreset.lg,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                    // Glass Overlay at the bottom of the banner
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (room.isPermanent)
                  IconButton(
                    icon: const Icon(Icons.workspace_premium, color: Colors.amber),
                    onPressed: () {
                      Get.dialog(RoomUpgradeDialog(roomId: roomId));
                    },
                  ),
              ],
            ),

            // Room Profile Details
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar and Name Section
                    Transform.translate(
                      offset: const Offset(0, -40),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Avatar Circle
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.bgDark, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                )
                              ],
                              color: AppTheme.primaryColor.withOpacity(0.2),
                            ),
                            child: CircleAvatar(
                              radius: 36,
                              backgroundColor: Colors.transparent,
                              backgroundImage: room.avatar != null ? NetworkImage(room.avatar!) : null,
                              child: room.avatar == null
                                  ? Text(
                                      room.name.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // ID and Room Type Label
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        room.id,
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: room.isPermanent
                                              ? Colors.amber.withOpacity(0.2)
                                              : AppTheme.textTertiary.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: room.isPermanent ? Colors.amber : AppTheme.textTertiary,
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Text(
                                          room.isPermanent ? 'Permanent' : 'Temporary',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: room.isPermanent ? Colors.amber : AppTheme.textTertiary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    room.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Transform.translate(
                      offset: const Offset(0, -24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Description
                          Text(
                            room.description,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // XP and Level Progress (for Permanent Rooms)
                          if (room.isPermanent) ...[
                            _buildLevelProgressCard(context, room, xpProgress, xpNeeded),
                            const SizedBox(height: 16),
                          ],

                          // Basic info: Tags, Country, Category, etc.
                          _buildQuickStatsCard(context, room),
                          const SizedBox(height: 16),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    controller.followRoom(room.id);
                                  },
                                  icon: const Icon(Icons.group_add, color: Colors.white),
                                  label: const Text(
                                    'Join Community',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                              if (room.isPermanent) ...[
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Get.dialog(RoomUpgradeDialog(roomId: roomId));
                                  },
                                  icon: const Icon(Icons.workspace_premium_rounded, color: Colors.amber),
                                  label: const Text('Upgrade'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.amber,
                                    side: const BorderSide(color: Colors.amber),
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Collapsible Rules Accordion
                          _buildRulesAccordion(context, room.rules),
                          const SizedBox(height: 12),

                          // Collapsible Member Roster Accordion
                          _buildMemberRosterAccordion(context, room),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        );
      }),
    );
  }

  Widget _buildLevelProgressCard(BuildContext context, VoiceRoom room, double xpProgress, int xpNeeded) {
    String formatVp(int val) {
      if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
      if (val >= 1000) {
        final double inK = val / 1000.0;
        return inK % 1 == 0 ? '${inK.toInt()}K' : '${inK.toStringAsFixed(1)}K';
      }
      return '$val';
    }

    final String currentStr = formatVp(room.xp);
    final String targetStr = formatVp(xpNeeded);
    final int percent = (xpProgress * 100).toInt();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.cardBg, AppTheme.bgLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.military_tech, color: Colors.amber, size: 24),
                  const SizedBox(width: 6),
                  Text(
                    'LV.${room.level} / Arena VP',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Text(
                '$currentStr / $targetStr VP ($percent%)',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: xpProgress,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s AP: +${room.todayRoomXp}',
                style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
              ),
              Text(
                room.level < 7 ? 'Next Reward at LV.${room.level + 1}' : 'Max Level Achieved',
                style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard(BuildContext context, VoiceRoom room) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Row 1: Members and Followers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(context, 'Members', '${room.totalMembers}'),
              Container(width: 1, height: 30, color: context.borderColor),
              _buildStatItem(context, 'Followers', '${room.totalFollowers}'),
              Container(width: 1, height: 30, color: context.borderColor),
              _buildStatItem(context, 'Gifts Received', '${room.totalGiftsReceived}'),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: context.borderColor, height: 1),
          const SizedBox(height: 16),
          // Info List
          _buildInfoRow(context, 'Owner', room.ownerName),
          _buildInfoRow(context, 'Category', room.category),
          _buildInfoRow(context, 'Language', room.language),
          _buildInfoRow(context, 'Country', room.country),
          const SizedBox(height: 8),
          // Tags wrap
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: room.tags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.secondaryBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.borderColor),
              ),
              child: Text(
                '#$tag',
                style: TextStyle(color: context.textSecondary, fontSize: 11),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: context.caption,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.caption, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRulesAccordion(BuildContext context, List<String> rules) {
    return ExpansionTile(
      title: const Text(
        'Arena Rules 📝',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      backgroundColor: AppTheme.cardBg,
      collapsedBackgroundColor: AppTheme.cardBg,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: rules.isEmpty
          ? [const Text('No rules defined. Play nice!', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))]
          : rules.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key + 1}. ',
                      style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
    );
  }

  Widget _buildMemberRosterAccordion(BuildContext context, VoiceRoom room) {
    final coOwners = room.coOwnerIds;
    final admins = room.adminIds;
    final stars = room.starMemberIds;

    // Slots limit
    final coLimit = 1 + room.extraCoOwnerSlots;
    final adminLimit = 3 + room.extraAdminSlots;
    final starLimit = 5 + room.extraStarMemberSlots;

    return ExpansionTile(
      title: const Text(
        'Community Hierarchy & Roles 👑',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      backgroundColor: AppTheme.cardBg,
      collapsedBackgroundColor: AppTheme.cardBg,
      childrenPadding: const EdgeInsets.all(16),
      children: [
        // Owner
        _buildRoleGroupHeader(context, 'Arena Owner', '1/1', Colors.amber),
        _buildUserTile(context, 'Current Owner (Anurag Kumar Bharti)', 'Owner', Colors.amber),
        const SizedBox(height: 12),

        // Co-owners
        _buildRoleGroupHeader(context, 'Co-owners', '${coOwners.length}/$coLimit', Colors.purpleAccent),
        if (coOwners.isEmpty)
          _buildEmptyRoleTile(context, 'No Co-owners assigned')
        else
          ...coOwners.map((id) => _buildUserTile(context, 'Co-owner ($id)', 'Co-owner', Colors.purpleAccent)),
        const SizedBox(height: 12),

        // Admins
        _buildRoleGroupHeader(context, 'Admins', '${admins.length}/$adminLimit', Colors.blueAccent),
        if (admins.isEmpty)
          _buildEmptyRoleTile(context, 'No Admins assigned')
        else
          ...admins.map((id) => _buildUserTile(context, 'Admin ($id)', 'Admin', Colors.blueAccent)),
        const SizedBox(height: 12),

        // Star Members
        _buildRoleGroupHeader(context, 'Star Members', '${stars.length}/$starLimit', Colors.tealAccent),
        if (stars.isEmpty)
          _buildEmptyRoleTile(context, 'No Star Members assigned')
        else
          ...stars.map((id) => _buildUserTile(context, 'Star ($id)', 'Star Member', Colors.tealAccent)),
      ],
    );
  }

  Widget _buildRoleGroupHeader(BuildContext context, String name, String ratio, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, top: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
          ),
          Text(
            ratio,
            style: TextStyle(color: context.caption, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, String name, String role, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: context.secondaryBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderColor.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.person, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              role,
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyRoleTile(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.scaffoldBackgroundColor.withOpacity(0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.borderColor.withOpacity(0.3)),
        ),
        child: Text(
          text,
          style: TextStyle(color: context.caption, fontSize: 11, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}
