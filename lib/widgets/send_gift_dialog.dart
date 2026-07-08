import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/theme.dart';
import '../services/room_controller.dart';
import '../services/store_controller.dart';

class GiftItem {
  final String id;
  final String name;
  final String icon;
  final int cost;
  final Color color;
  final String currency; // 'gold' or 'silver'
  final int stars;

  GiftItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.cost,
    required this.color,
    this.currency = 'gold',
    this.stars = 0,
  });
}

class SendGiftDialog extends StatefulWidget {
  final String roomId;
  final int occupiedSeatsCount;
  final String? targetUserId;
  final String? targetUserName;
  final Function(String giftName, String giftIcon, int giftCost, String currency)? onGiftSent;
  
  const SendGiftDialog({
    Key? key,
    required this.roomId,
    this.occupiedSeatsCount = 1,
    this.targetUserId,
    this.targetUserName,
    this.onGiftSent,
  }) : super(key: key);

  @override
  State<SendGiftDialog> createState() => _SendGiftDialogState();
}

class _SendGiftDialogState extends State<SendGiftDialog> {
  final List<GiftItem> _gifts = [
    GiftItem(id: 'gold_star', name: '2-Star Gift', icon: '⭐', cost: 1, color: Colors.yellow, currency: 'gold', stars: 2),
    GiftItem(id: 'silver_star', name: '1-Star Gift', icon: '✨', cost: 100, color: Colors.grey, currency: 'silver', stars: 1),
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
  final StoreController _storeCtrl = Get.find<StoreController>();
  bool _giftAll = false;

  @override
  void initState() {
    super.initState();
    _selectedGift = _gifts[0]; // default selection
  }

  void _sendGift() {
    if (_selectedGift == null) return;

    final countMultiplier = _giftAll ? widget.occupiedSeatsCount : 1;
    final totalCostVal = _selectedGift!.cost * countMultiplier;

    // Check and deduct balance
    if (_selectedGift!.currency == 'gold') {
      if (_storeCtrl.coinsBalance.value < totalCostVal) {
        Get.snackbar('Insufficient Gold 🪙', 'You need $totalCostVal Gold Coins.',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.9), colorText: Colors.white);
        return;
      }
      _storeCtrl.coinsBalance.value -= totalCostVal;
    } else {
      if (_storeCtrl.silverCoinsBalance.value < totalCostVal) {
        Get.snackbar('Insufficient Silver 🥈', 'You need $totalCostVal Silver Coins.',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.9), colorText: Colors.white);
        return;
      }
      _storeCtrl.silverCoinsBalance.value -= totalCostVal;
    }

    // Call RoomController if inside a room
    if (widget.roomId.isNotEmpty) {
      _controller.sendGiftToRoom(
        widget.roomId,
        giftCost: _selectedGift!.cost,
        giftName: _selectedGift!.name,
        fromUserName: 'Anurag Kumar',
        count: countMultiplier,
        targetUserId: widget.targetUserId,
        targetUserName: widget.targetUserName,
        deductCoins: false, // Already deducted above
      );
    }

    // Trigger callback
    if (widget.onGiftSent != null) {
      widget.onGiftSent!(
        _selectedGift!.name,
        _selectedGift!.icon,
        _selectedGift!.cost,
        _selectedGift!.currency,
      );
    }

    Get.back(); // close dialog
  }

  @override
  Widget build(BuildContext context) {
    final finalCost = _selectedGift != null
        ? _selectedGift!.cost * (_giftAll ? widget.occupiedSeatsCount : 1)
        : 0;

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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Send Gift 🎁',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (widget.targetUserName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _giftAll ? 'To: All Seats' : 'To: ${widget.targetUserName}',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Gold Coins
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.bgLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.monetization_on,
                              color: Colors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Obx(() => Text(
                                  '${_storeCtrl.coinsBalance.value}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Silver Coins
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.bgLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.monetization_on,
                              color: Colors.grey,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Obx(() => Text(
                                  '${_storeCtrl.silverCoinsBalance.value}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
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
                              Icon(
                                Icons.monetization_on,
                                color: gift.currency == 'gold' ? Colors.amber : Colors.grey,
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
            
            // "Gift All Seats" Toggle
            if (widget.occupiedSeatsCount > 1)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.bgLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Gift All Seats 🎙️',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedGift != null
                                ? '${_selectedGift!.cost} Coins × ${widget.occupiedSeatsCount} occupied seats = $finalCost Coins'
                                : 'Send to all occupied seats',
                            style: const TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _giftAll,
                      onChanged: (val) {
                        setState(() {
                          _giftAll = val;
                        });
                      },
                      activeColor: Colors.amber,
                      activeTrackColor: Colors.amber.withOpacity(0.3),
                      inactiveThumbColor: AppTheme.textTertiary,
                      inactiveTrackColor: Colors.white10,
                    ),
                  ],
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
                              '($finalCost)',
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
