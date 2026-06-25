import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/theme.dart';
import '../services/room_controller.dart';

class GiftItem {
  final String id;
  final String name;
  final String icon;
  final int cost;
  final Color color;

  GiftItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.cost,
    required this.color,
  });
}

class SendGiftDialog extends StatefulWidget {
  final String roomId;
  
  const SendGiftDialog({
    Key? key,
    required this.roomId,
  }) : super(key: key);

  @override
  State<SendGiftDialog> createState() => _SendGiftDialogState();
}

class _SendGiftDialogState extends State<SendGiftDialog> {
  final List<GiftItem> _gifts = [
    GiftItem(id: 'rose', name: 'Rose', icon: '🌹', cost: 10, color: Colors.redAccent),
    GiftItem(id: 'heart', name: 'Heart', icon: '❤️', cost: 50, color: Colors.pinkAccent),
    GiftItem(id: 'coffee', name: 'Coffee', icon: '☕', cost: 100, color: Colors.brown),
    GiftItem(id: 'dj', name: 'DJ Beat', icon: '🎛️', cost: 250, color: Colors.purpleAccent),
    GiftItem(id: 'crown', name: 'Crown', icon: '👑', cost: 500, color: Colors.amber),
    GiftItem(id: 'car', name: 'Sports Car', icon: '🏎️', cost: 1000, color: Colors.blueAccent),
    GiftItem(id: 'yacht', name: 'Yacht', icon: '🛳️', cost: 2500, color: Colors.tealAccent),
    GiftItem(id: 'castle', name: 'Castle', icon: '🏰', cost: 5000, color: Colors.deepPurpleAccent),
  ];

  GiftItem? _selectedGift;
  final RoomController _controller = RoomController.to;

  @override
  void initState() {
    super.initState();
    _selectedGift = _gifts[0]; // default selection
  }

  void _sendGift() {
    if (_selectedGift == null) return;

    final success = _controller.sendGiftToRoom(
      widget.roomId,
      giftCost: _selectedGift!.cost,
      giftName: _selectedGift!.name,
      fromUserName: 'Current User',
    );

    if (success) {
      Get.back(); // close dialog on success
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Send Gift 🎁',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.bgLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          color: Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Obx(() => Text(
                              '${_controller.walletBalance.value}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppTheme.borderColor, height: 1),

            // Grid of Gifts
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: _gifts.length,
                itemBuilder: (context, index) {
                  final gift = _gifts[index];
                  final isSelected = _selectedGift?.id == gift.id;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedGift = gift;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor.withOpacity(0.15) : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.2),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Gift Icon
                          Text(
                            gift.icon,
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(height: 6),
                          // Gift Name
                          Text(
                            gift.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Cost
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.monetization_on,
                                color: Colors.amber,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${gift.cost}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Bottom Action
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _sendGift,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Send Gift',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          if (_selectedGift != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${_selectedGift!.cost})',
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
