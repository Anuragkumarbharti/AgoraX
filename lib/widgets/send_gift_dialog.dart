// lib/widgets/send_gift_dialog.dart

import 'package:flutter/material.dart';
import 'dart:math';
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
  int _selectedComboMultiplier = 1; // Combo trigger: 1x, 5x, 10x, 99x, etc.

  final List<GiftItem> _starGifts = [
    GiftItem(id: 'g1000000-0000-0000-0000-000000000001', name: 'Rose', icon: '🌹', cost: 2, color: Colors.redAccent, currency: 'gold', stars: 2),
    GiftItem(id: 'g1000000-0000-0000-0000-000000000002', name: 'Heart', icon: '❤️', cost: 10, color: Colors.pinkAccent, currency: 'gold', stars: 10),
    GiftItem(id: 'g1000000-0000-0000-0000-000000000003', name: 'Crown', icon: '👑', cost: 500, color: Colors.amber, currency: 'gold', stars: 500),
    GiftItem(id: 'g1000000-0000-0000-0000-000000000004', name: 'Sports Car', icon: '🏎️', cost: 1000, color: Colors.blueAccent, currency: 'gold', stars: 1000),
    GiftItem(id: 'g1000000-0000-0000-0000-000000000005', name: 'Castle', icon: '🏰', cost: 5000, color: Colors.deepPurpleAccent, currency: 'gold', stars: 5000),
    GiftItem(id: 'g1000000-0000-0000-0000-000000000006', name: 'Rocket', icon: '🚀', cost: 10000, color: Colors.cyanAccent, currency: 'gold', stars: 10000),
  ];

  final List<GiftItem> _silverGifts = [
    GiftItem(id: 'g1000000-0000-0000-0000-000000000011', name: 'Like', icon: '👍', cost: 50, color: Colors.blue, currency: 'silver'),
    GiftItem(id: 'g1000000-0000-0000-0000-000000000012', name: 'Coffee', icon: '☕', cost: 100, color: Colors.brown, currency: 'silver'),
    GiftItem(id: 'g1000000-0000-0000-0000-000000000013', name: 'Chocolate', icon: '🍫', cost: 200, color: Colors.amber, currency: 'silver'),
    GiftItem(id: 'g1000000-0000-0000-0000-000000000014', name: 'Flower', icon: '🌼', cost: 500, color: Colors.orange, currency: 'silver'),
    GiftItem(id: 'g1000000-0000-0000-0000-000000000015', name: 'Cake', icon: '🎂', cost: 1000, color: Colors.pink, currency: 'silver'),
    GiftItem(id: 'g1000000-0000-0000-0000-000000000016', name: 'Small Heart', icon: '❤️', cost: 2000, color: Colors.red, currency: 'silver'),
  ];

  GiftItem? _selectedStandardGift;
  VaultItem? _selectedVaultItem;

  // Selected multi-seat targeting tracking lists
  final List<String> _selectedRecipients = [];
  final List<String> _selectedRecipientNames = [];
  final List<int> _selectedSeatIndices = [];

  final RoomController _controller = RoomController.to;
  final StoreController _storeCtrl = Get.find<StoreController>();
  late VaultController _vaultCtrl;
  bool _giftAll = false;

  @override
  void initState() {
    super.initState();
    _vaultCtrl = Get.put(VaultController());
    _selectedStandardGift = _starGifts[0]; // default select
    _initDefaultRecipients();
  }

  void _initDefaultRecipients() {
    _selectedRecipients.clear();
    _selectedRecipientNames.clear();
    _selectedSeatIndices.clear();

    if (widget.targetUserId != null) {
      _selectedRecipients.add(widget.targetUserId!);
      _selectedRecipientNames.add(widget.targetUserName ?? 'User');
      final seats = _controller.roomSeatsInfo[widget.roomId] ?? [];
      final seat = seats.firstWhereOrNull((s) => s['userId'] == widget.targetUserId);
      if (seat != null) {
        _selectedSeatIndices.add(seat['seatIndex'] as int);
      }
    } else {
      // Default to host if targetUserId is null
      final hostId = _controller.rooms.firstWhereOrNull((r) => r.id == widget.roomId)?.hostId;
      if (hostId != null) {
        _selectedRecipients.add(hostId);
        _selectedRecipientNames.add('Host');
        final seats = _controller.roomSeatsInfo[widget.roomId] ?? [];
        final seat = seats.firstWhereOrNull((s) => s['userId'] == hostId);
        if (seat != null) {
          _selectedSeatIndices.add(seat['seatIndex'] as int);
        }
      }
    }
  }

  List<VaultItem> get _giftableVaultItems {
    return _vaultCtrl.vaultItems.where((item) {
      return item.giftable && 
             item.quantity > 0 && 
             (item.expiresAt == null || item.expiresAt!.isAfter(DateTime.now()));
    }).toList();
  }

  void _sendGift() async {
    if (_selectedRecipients.isEmpty) {
      Get.snackbar('No Recipient', 'Please select at least one recipient seat.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    if (_selectedTabIndex == 2) {
      // Send Vault Gift
      final item = _selectedVaultItem;
      if (item == null) {
        Get.snackbar('No Item Selected', 'Please select a Vault item to send.',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orangeAccent, colorText: Colors.white);
        return;
      }

      // Vault gifts are sent to single recipient
      final recipientId = _selectedRecipients[0];
      final recipientName = _selectedRecipientNames[0];

      final res = await _vaultCtrl.giftItem(item, recipientId);
      if (res['success'] == true) {
        if (widget.roomId.isNotEmpty) {
          _controller.sendGiftToRoom(
            widget.roomId,
            giftCost: 0,
            giftName: 'Vault: ${item.displayName}',
            fromUserName: 'Anurag Kumar',
            count: 1,
            targetUserId: recipientId,
            targetUserName: recipientName,
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

    // Standard Gifting Logic (Stars / Silver)
    final gift = _selectedStandardGift;
    if (gift == null) return;

    final receiversList = _giftAll 
        ? (_controller.roomSeatsInfo[widget.roomId] ?? [])
            .where((s) => s['userId'] != null)
            .map((s) => s['userId'] as String)
            .toList()
        : _selectedRecipients;

    final receiverNamesList = _giftAll
        ? (_controller.roomSeatsInfo[widget.roomId] ?? [])
            .where((s) => s['userId'] != null)
            .map((s) => (s['name'] as String? ?? 'User'))
            .toList()
        : _selectedRecipientNames;

    final seatIndicesList = _giftAll
        ? (_controller.roomSeatsInfo[widget.roomId] ?? [])
            .where((s) => s['userId'] != null)
            .map((s) => s['seatIndex'] as int)
            .toList()
        : _selectedSeatIndices;

    if (receiversList.isEmpty) {
      Get.snackbar('No Occupants', 'No occupied seats to gift to.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    final totalQuantity = _selectedComboMultiplier;
    
    final success = await _controller.sendStarGiftToRoom(
      roomId: widget.roomId,
      giftId: gift.id,
      giftName: gift.name,
      giftCost: gift.cost,
      currency: gift.currency,
      targetUserIds: receiversList,
      targetUserNames: receiverNamesList,
      seatIndices: seatIndicesList,
      count: totalQuantity,
      comboCount: _selectedComboMultiplier,
    );

    if (success) {
      if (widget.onGiftSent != null) {
        widget.onGiftSent!(
          gift.name,
          gift.icon,
          gift.cost * totalQuantity,
          gift.currency,
        );
      }
      Get.back();
    }
  }

  void _showAnimationPreview(GiftItem gift) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E).withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.2),
                blurRadius: 20,
              )
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${gift.icon} ${gift.name} Preview',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
                width: 120,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _PreviewParticlesWidget(),
                    ),
                    Center(
                      child: Text(gift.icon, style: const TextStyle(fontSize: 48)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Long Press plays cinematic 60 FPS Bezier path preview on live room.',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Get.back(),
                child: Text('Close', style: GoogleFonts.poppins(color: const Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeReceiversCount = _giftAll 
        ? (_controller.roomSeatsInfo[widget.roomId] ?? []).where((s) => s['userId'] != null).length
        : _selectedRecipients.length;

    final double singleStarCost = _selectedStandardGift != null
        ? (_selectedStandardGift!.currency == 'gold' ? _selectedStandardGift!.cost.toDouble() : _selectedStandardGift!.cost / 100.0)
        : 0.0;
    
    final finalStars = singleStarCost * _selectedComboMultiplier * (activeReceiversCount > 0 ? activeReceiversCount : 1);

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
                      if (activeReceiversCount > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          _selectedTabIndex == 2
                              ? 'To: ${_selectedRecipientNames.join(', ')}'
                              : (_giftAll ? 'To: All Seats' : 'To: ${_selectedRecipientNames.join(', ')}'),
                          style: GoogleFonts.poppins(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]
                    ],
                  ),
                  
                  _buildBalanceIndicator(),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            // Multi-seat checkbox targeting
            const SizedBox(height: 8),
            _buildMultiSeatSelector(),
            const SizedBox(height: 4),

            // Tab Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

            // Gift Grid
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildTabContentView(),
              ),
            ),

            // Combo selection multipliers
            _buildComboSelector(),

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
                                ? '${singleStarCost} ★ × ${_selectedComboMultiplier}x combo × ${activeReceiversCount} seats = ${finalStars.toStringAsFixed(1)} ★'
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
                                ? '⭐ Send Star Gift (${finalStars.toStringAsFixed(0)} ★)'
                                : '🪙 Send Silver Gift (${finalStars.toStringAsFixed(1)} ★)'),
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

  Widget _buildMultiSeatSelector() {
    final seats = _controller.roomSeatsInfo[widget.roomId] ?? [];
    final occupiedSeats = seats.where((s) => s['userId'] != null).toList();
    
    if (occupiedSeats.isEmpty || _giftAll) return const SizedBox.shrink();
    
    return Container(
      height: 62,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: occupiedSeats.length,
        itemBuilder: (context, index) {
          final seat = occupiedSeats[index];
          final uId = seat['userId'] as String;
          final uName = seat['name'] as String? ?? 'User';
          final avatar = seat['avatar'] as String?;
          final seatIdx = seat['seatIndex'] as int;
          
          final isSelected = _selectedRecipients.contains(uId);
          
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  if (_selectedRecipients.length > 1) {
                    _selectedRecipients.remove(uId);
                    _selectedRecipientNames.remove(uName);
                    _selectedSeatIndices.remove(seatIdx);
                  }
                } else {
                  // Max 10 recipients targeting support
                  if (_selectedRecipients.length < 10) {
                    _selectedRecipients.add(uId);
                    _selectedRecipientNames.add(uName);
                    _selectedSeatIndices.add(seatIdx);
                  }
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 14.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF8B5CF6) : Colors.white24,
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundImage: avatar != null && avatar.isNotEmpty
                              ? NetworkImage(avatar)
                              : const AssetImage('assets/images/placeholder.png') as ImageProvider,
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 7, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    uName,
                    style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.white38, fontSize: 8, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildComboSelector() {
    if (_selectedTabIndex == 2) return const SizedBox.shrink(); // No combos for Vault
    
    final combos = [1, 5, 10, 99, 520, 999];
    return Container(
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: combos.length,
        itemBuilder: (context, index) {
          final val = combos[index];
          final isSelected = _selectedComboMultiplier == val;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedComboMultiplier = val;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isSelected ? const Color(0xFFA78BFA) : Colors.white.withOpacity(0.08)),
              ),
              child: Center(
                child: Text(
                  '${val}x',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        },
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
            _giftAll = false; // Reset gift all
            _selectedComboMultiplier = 1; // Reset combos
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
    return Obx(() {
      final val = _selectedTabIndex == 0 
          ? '${_storeCtrl.coinsBalance.value}' 
          : (_selectedTabIndex == 1 ? '${_storeCtrl.silverCoinsBalance.value}' : '${_giftableVaultItems.length}');
      
      final label = _selectedTabIndex == 2 ? 'Vault Items' : 'Balance';
      final symbol = _selectedTabIndex == 0 ? '⭐' : (_selectedTabIndex == 1 ? '🪙' : '🎒');
      
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Text(
          '$symbol $label : $val',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      );
    });
  }

  Widget _buildTabContentView() {
    if (_selectedTabIndex == 2) {
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
          onLongPress: () {
            _showAnimationPreview(gift);
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
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFDB3C),
                      size: 11,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      gift.currency == 'gold' 
                          ? '${gift.cost} ★' 
                          : '${(gift.cost / 100).toStringAsFixed(gift.cost % 100 == 0 ? 0 : 1)} ★',
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

class _PreviewParticlesWidget extends StatefulWidget {
  @override
  State<_PreviewParticlesWidget> createState() => _PreviewParticlesWidgetState();
}

class _PreviewParticlesWidgetState extends State<_PreviewParticlesWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return CustomPaint(
          painter: _PreviewParticlesPainter(_ctrl.value),
        );
      },
    );
  }
}

class _PreviewParticlesPainter extends CustomPainter {
  final double progress;
  _PreviewParticlesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = const Color(0xFFFFDB3C).withOpacity(0.8);
    final count = 8;
    final maxRadius = size.width / 2.5;

    for (int i = 0; i < count; i++) {
      final angle = (i * (2 * 3.14159 / count)) + (progress * 2 * 3.14159);
      final r = maxRadius * (0.6 + 0.4 * sin(progress * 2 * 3.14159 + i));
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      canvas.drawCircle(Offset(x, y), 3.0 * (1 - (r / maxRadius) * 0.3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
