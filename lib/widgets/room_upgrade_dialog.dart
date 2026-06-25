import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/theme.dart';
import '../models/room_model.dart';
import '../services/room_controller.dart';

class RoomUpgradeDialog extends StatelessWidget {
  final String roomId;

  const RoomUpgradeDialog({
    Key? key,
    required this.roomId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final RoomController controller = RoomController.to;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgDark.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Obx(() {
          final roomIndex = controller.rooms.indexWhere((r) => r.id == roomId);
          if (roomIndex == -1) {
            return const Center(child: Text('Room not found'));
          }
          final VoiceRoom room = controller.rooms[roomIndex];

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Premium Upgrades Store 💎',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unlock more roles for your community',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          '${controller.walletBalance.value}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.borderColor, height: 1),
              const SizedBox(height: 16),

              // Upgrade Cards
              _buildUpgradeCard(
                context,
                roleName: 'Co-owner',
                icon: Icons.workspace_premium,
                currentSlots: 1 + room.extraCoOwnerSlots, // Base is 1
                cost: 250,
                color: Colors.purpleAccent,
                onTap: () => controller.buyRoleUpgrade(roomId, 'Co-owner', 250),
              ),
              const SizedBox(height: 12),
              _buildUpgradeCard(
                context,
                roleName: 'Admin',
                icon: Icons.shield,
                currentSlots: 3 + room.extraAdminSlots, // Base is 3
                cost: 150,
                color: Colors.blueAccent,
                onTap: () => controller.buyRoleUpgrade(roomId, 'Admin', 150),
              ),
              const SizedBox(height: 12),
              _buildUpgradeCard(
                context,
                roleName: 'Star Member',
                icon: Icons.star,
                currentSlots: 5 + room.extraStarMemberSlots, // Base is 5
                cost: 50,
                color: Colors.amber,
                onTap: () => controller.buyRoleUpgrade(roomId, 'Star Member', 50),
              ),

              const SizedBox(height: 24),
              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.bgLight,
                    side: const BorderSide(color: AppTheme.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Close Store',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildUpgradeCard(
    BuildContext context, {
    required String roleName,
    required IconData icon,
    required int currentSlots,
    required int cost,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+1 $roleName Slot',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Current Total: $currentSlots slots',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // Buy button
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$cost',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
