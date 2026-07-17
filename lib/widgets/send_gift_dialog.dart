// lib/widgets/send_gift_dialog.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/room_controller.dart';
import '../services/store_controller.dart';
import '../services/vault_controller.dart';
import '../models/vault_models.dart';

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
  int _selectedTabIndex = 0; // 0 = Stars, 1 = Silver, 2 = Vault

  final List<GiftItem> _starGifts = [
    GiftItem(id: 'rose', name: 'Rose', icon: '🌹', cost: 2, color: Colors.redAccent, currency: 'gold', stars: 2),
    GiftItem(id: 'heart', name: 'Heart', icon: '❤️', cost: 10, color: Colors.pinkAccent, currency: 'gold', stars: 10),
    GiftItem(id: 'crown', name: 'Crown', icon: '👑', cost: 500, color: Colors.amber, currency: 'gold', stars: 500),
    GiftItem(id: 'car', name: 'Car', icon: '🚗', cost: 1000, color: Colors.blueAccent, currency: 'gold', stars: 1000),
    GiftItem(id: 'castle', name: 'Castle', icon: '🏰', cost: 5000, color: Colors.deepPurpleAccent, currency: 'gold', stars: 5000),
    GiftItem(id: 'rocket', name: 'Rocket', icon: '🚀', cost: 10000, color: Colors.cyanAccent, currency: 'gold', stars: 10000),
  ];

  final List<GiftItem> _silverGifts = [
    GiftItem(id: 'like', name: 'Like', icon: '👍', cost: 50, color: Colors.blue, currency: 'silver'),
    GiftItem(id: 'coffee', name: 'Coffee', icon: '☕', cost: 100, color: Colors.brown, currency: 'silver'),
    GiftItem(id: 'chocolate', name: 'Chocolate', icon: '🍫', cost: 200, color: Colors.amber, currency: 'silver'),
    GiftItem(id: 'flower', name: 'Flower', icon: '🌼', cost: 500, color: Colors.orange, currency: 'silver'),
    GiftItem(id: 'cake', name: 'Cake', icon: '🎂', cost: 1000, color: Colors.pink, currency: 'silver'),
    GiftItem(id: 'small_heart', name: 'Small Heart', icon: '❤️', cost: 2000, color: Colors.red, currency: 'silver'),
  ];

  GiftItem? _selectedStandardGift;
  VaultItem? _selectedVaultItem;

  final RoomController _controller = RoomController.to;
  final StoreController _storeCtrl = Get.find<StoreController>();
  late VaultController _vaultCtrl;
  bool _giftAll = false;

  @override
  void initState() {
    super.initState();
    _vaultCtrl = Get.put(VaultController());
    _selectedStandardGift = _starGifts[0]; // default select
  }

  List<VaultItem> get _giftableVaultItems {
    return _vaultCtrl.vaultItems.where((item) {
      return item.giftable && 
             item.quantity > 0 && 
             (item.expiresAt == null || item.expiresAt!.isAfter(DateTime.now()));
    }).toList();
  }

  void _sendGift() async {
    if (_selectedTabIndex == 2) {
      // Send Vault Gift
      final item = _selectedVaultItem;
      if (item == null) {
        Get.snackbar('No Item Selected', 'Please select a Vault item to send.',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orangeAccent, colorText: Colors.white);
        return;
      }

      final String dbReceiverId = widget.targetUserId ?? _controller.rooms.firstWhereOrNull((r) => r.id == widget.roomId)?.hostId ?? '';
      if (dbReceiverId.isEmpty) {
        Get.snackbar('No Recipient', 'Please select a recipient seat.',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
        return;
      }

      final res = await _vaultCtrl.giftItem(item, dbReceiverId);
      if (res['success'] == true) {
        // Publish visual room animation & notification
        if (widget.roomId.isNotEmpty) {
          _controller.sendGiftToRoom(
            widget.roomId,
            giftCost: 0,
            giftName: 'Vault: ${item.displayName}',
            fromUserName: 'Anurag Kumar',
            count: 1,
            targetUserId: dbReceiverId,
            targetUserName: widget.targetUserName ?? 'Host',
            deductCoins: false,
          );
        }

        if (widget.onGiftSent != null) {
          widget.onGiftSent!(
            'Vault: ${item.displayName}',
            '🎒',
            0,
            'vault',
          );
        }

        Get.back();
        Get.snackbar(
          'Gift Sent! 🎁',
          'Successfully sent ${item.displayName} from your Vault.',
          backgroundColor: const Color(0xFF10B981).withOpacity(0.8),
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Gift Failed',
          res['reason'] ?? 'Failed to send Vault gift.',
          backgroundColor: Colors.redAccent.withOpacity(0.8),
          colorText: Colors.white,
        );
      }
      return;
    }

    // Standard Gift sending logic (Stars / Silver)
    final gift = _selectedStandardGift;
    if (gift == null) return;

    final countMultiplier = _giftAll ? widget.occupiedSeatsCount : 1;
    final totalCostVal = gift.cost * countMultiplier;

    // Check balance
    if (gift.currency == 'gold') {
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

    if (widget.roomId.isNotEmpty) {
      _controller.sendGiftToRoom(
        widget.roomId,
        giftCost: gift.cost,
        giftName: gift.name,
        fromUserName: 'Anurag Kumar',
        count: countMultiplier,
        targetUserId: widget.targetUserId,
        targetUserName: widget.targetUserName,
        deductCoins: false,
      );
    }

    if (widget.onGiftSent != null) {
      widget.onGiftSent!(
        gift.name,
        gift.icon,
        gift.cost,
        gift.currency,
      );
    }

    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final finalCost = _selectedStandardGift != null
        ? _selectedStandardGift!.cost * (_giftAll ? widget.occupiedSeatsCount : 1)
        : 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF11131C).withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
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
            // Top Header: Title & Dynamic Balance
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
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      if (widget.targetUserName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _selectedTabIndex == 2
                              ? 'To: ${widget.targetUserName}'
                              : (_giftAll ? 'To: All Seats' : 'To: ${widget.targetUserName}'),
                          style: GoogleFonts.poppins(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ]
                    ],
                  ),
                  
                  // Dynamic Tab Balance
                  _buildBalanceIndicator(),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            // Tab Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _tabButton(0, '⭐ Stars'),
                  const SizedBox(width: 8),
                  _tabButton(1, '🪙 Silver'),
                  const SizedBox(width: 8),
                  _tabButton(2, '🎒 Vault'),
                ],
              ),
            ),

            // Gift selection view
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildTabContentView(),
              ),
            ),

            // "Gift All Seats" Toggle (Only visible for Star & Silver tabs)
            if (_selectedTabIndex != 2 && widget.occupiedSeatsCount > 1)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Gift All Seats 🎙️',
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedStandardGift != null
                                ? '${_selectedStandardGift!.cost} Coins × ${widget.occupiedSeatsCount} occupied seats = $finalCost Coins'
                                : 'Send to all occupied seats',
                            style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
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
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.white10,
                    ),
                  ],
                ),
              ),

            // Bottom Actions Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _sendGift,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _selectedTabIndex == 2
                            ? '🎁 Send Vault Gift'
                            : (_selectedTabIndex == 0
                                ? '⭐ Send Star Gift ($finalCost)'
                                : '🪙 Send Silver Gift ($finalCost)'),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
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

  Widget _tabButton(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
            _giftAll = false; // Reset gift all on tab switch
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFA78BFA) : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceIndicator() {
    String label = '';
    IconData icon = Icons.stars_rounded;
    Color iconColor = Colors.amber;
    String balance = '0';

    if (_selectedTabIndex == 0) {
      label = 'Balance';
      icon = Icons.stars_rounded;
      iconColor = const Color(0xFFFFDB3C);
      balance = '${_storeCtrl.coinsBalance.value}';
    } else if (_selectedTabIndex == 1) {
      label = 'Balance';
      icon = Icons.monetization_on_rounded;
      iconColor = Colors.grey;
      balance = '${_storeCtrl.silverCoinsBalance.value}';
    } else {
      // Vault tab has no dynamic coin balance - show Vault icon
      label = 'Vault Items';
      icon = Icons.backpack_outlined;
      iconColor = const Color(0xFFFBBF24);
      balance = '${_giftableVaultItems.length}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 4),
          Obx(() {
            // Force reactive listen
            final val = _selectedTabIndex == 0 
                ? '${_storeCtrl.coinsBalance.value}' 
                : (_selectedTabIndex == 1 ? '${_storeCtrl.silverCoinsBalance.value}' : '${_giftableVaultItems.length}');
            return Text(
              '$label: $val',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTabContentView() {
    if (_selectedTabIndex == 2) {
      // Vault content
      return Obx(() {
        final vaultItemsList = _giftableVaultItems;
        if (vaultItemsList.isEmpty) {
          return Container(
            height: 180,
            alignment: Alignment.center,
            child: Text(
              'No giftable assets found in Vault.',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: vaultItemsList.length,
          itemBuilder: (context, index) {
            final item = vaultItemsList[index];
            final isSelected = _selectedVaultItem?.id == item.id;
            final rColor = isSelected ? const Color(0xFF8B5CF6) : Colors.white10;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedVaultItem = item;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF8B5CF6).withOpacity(0.15) : Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.06), width: 1.2),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Center(
                              child: item.thumbnailUrl != null
                                  ? Image.network(item.thumbnailUrl!, fit: BoxFit.contain)
                                  : Text(
                                      item.category == 'Premium' ? '👑' : '🎒',
                                      style: const TextStyle(fontSize: 22),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.displayName,
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Giftable Badge
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Giftable ✓',
                          style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 6, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    // Quantity Badge
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Qty ×${item.quantity}',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 7, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      });
    }

    // Stars or Silver Content
    final giftsList = _selectedTabIndex == 0 ? _starGifts : _silverGifts;

    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: giftsList.length,
      itemBuilder: (context, index) {
        final gift = giftsList[index];
        final isSelected = _selectedStandardGift?.id == gift.id && 
            (_selectedTabIndex == 0 ? gift.currency == 'gold' : gift.currency == 'silver');

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedStandardGift = gift;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF8B5CF6).withOpacity(0.15) : Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.06),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  gift.icon,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(height: 6),
                Text(
                  gift.name,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      gift.currency == 'gold' ? Icons.stars_rounded : Icons.monetization_on_rounded,
                      color: gift.currency == 'gold' ? const Color(0xFFFFDB3C) : Colors.grey,
                      size: 11,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${gift.cost}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white70,
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
    );
  }
}
