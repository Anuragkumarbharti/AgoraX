// lib/widgets/send_gift_dialog.dart

import 'package:flutter/material.dart';
import 'dart:math';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/room/room_controller.dart';
import '../../services/store/store_controller.dart';
import '../../services/vault/vault_controller.dart';
import '../../services/gifting/gift_send_service.dart';
import '../../models/vault/vault_models.dart';
import '../../models/gift/gift_animation_metadata.dart';
import './gift_animation_overlay.dart';
import '../../utils/number_formatter.dart';

class GiftItem {
  final String id;
  final String name;
  final String icon;
  final int cost;
  final Color color;
  final String currency; // 'gold' or 'silver'
  final int stars;
  final String category; // 'All', 'Popular', 'New', 'Romantic', 'Luxury', 'Fun', 'Party', 'Fantasy', 'Vehicles', 'Animals', 'Magic'
  final String? badge; // 'HOT', 'NEW', 'VIP', 'LUCKY', 'LEGEND', 'EVENT', 'LIMITED'
  final bool isLucky;

  GiftItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.cost,
    required this.color,
    this.currency = 'gold',
    this.stars = 0,
    this.category = 'All',
    this.badge,
    bool? isLucky,
  }) : isLucky = isLucky ?? (badge == 'LUCKY' || category.contains('Magic'));
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
  // 0 = All, 1 = Gold, 2 = Silver, 3 = Vault
  int _selectedCurrencyTab = 0;
  String _selectedCategory = 'All';
  int _selectedComboMultiplier = 1;
  int _currentCarouselPage = 0;

  final PageController _pageController = PageController();

  final List<String> _categories = [
    'All',
    '🔥 Popular',
    '🆕 New',
    '❤️ Romantic',
    '💎 Luxury',
    '😄 Fun',
    '🎉 Party',
    '🐉 Fantasy',
    '🚗 Vehicles',
    '🐼 Animals',
    '🪄 Magic',
  ];

  // Master Mixed Catalog (1-to-1 match with Supabase Postgres gift_catalog table)
  final List<GiftItem> _allGifts = [
    // Page 1 Items (Gold & Silver mixed side-by-side)
    GiftItem(id: 'a2000000-0000-0000-0000-000000000003', name: 'Rose', icon: '🌹', cost: 10, color: Colors.pink, currency: 'gold', stars: 10, category: '❤️ Romantic', badge: 'HOT'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000024', name: 'Heart', icon: '❤️', cost: 1500, color: Colors.redAccent, currency: 'silver', stars: 15, category: '❤️ Romantic', badge: 'NEW'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000011', name: 'Crown', icon: '👑', cost: 99, color: Colors.amber, currency: 'gold', stars: 99, category: '💎 Luxury', badge: 'VIP'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000012', name: 'Butterfly', icon: '🦋', cost: 99, color: Colors.purple, currency: 'gold', stars: 99, category: '🐉 Fantasy'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000005', name: 'Coffee', icon: '☕', cost: 20, color: Colors.brown, currency: 'gold', stars: 20, category: '🔥 Popular'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000030', name: 'Diamond', icon: '💎', cost: 5000, color: Colors.cyan, currency: 'silver', stars: 50, category: '💎 Luxury', badge: 'LUCKY'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000013', name: 'Sports Car', icon: '🏎️', cost: 499, color: Colors.deepOrange, currency: 'gold', stars: 499, category: '🚗 Vehicles', badge: 'LEGEND'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000014', name: 'Private Jet', icon: '✈️', cost: 499, color: Colors.cyanAccent, currency: 'gold', stars: 499, category: '🚗 Vehicles', badge: 'VIP'),

    // Page 2 Items
    GiftItem(id: 'a2000000-0000-0000-0000-000000000001', name: 'Like', icon: '👍', cost: 2, color: Colors.blue, currency: 'gold', stars: 2, category: '🔥 Popular'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000002', name: 'Flower', icon: '🌼', cost: 5, color: Colors.orange, currency: 'gold', stars: 5, category: '🔥 Popular', badge: 'NEW'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000004', name: 'Heart', icon: '❤️', cost: 15, color: Colors.redAccent, currency: 'gold', stars: 15, category: '❤️ Romantic'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000006', name: 'Chocolate', icon: '🍫', cost: 25, color: Colors.brown, currency: 'gold', stars: 25, category: '❤️ Romantic'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000007', name: 'Cake', icon: '🎂', cost: 30, color: Colors.pink, currency: 'gold', stars: 30, category: '🎉 Party', badge: 'LUCKY'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000008', name: 'Balloon', icon: '🎈', cost: 35, color: Colors.purpleAccent, currency: 'gold', stars: 35, category: '🎉 Party'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000009', name: 'Gift Box', icon: '🎁', cost: 40, color: Colors.red, currency: 'gold', stars: 40, category: '🎉 Party', badge: 'LUCKY'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000010', name: 'Diamond', icon: '💎', cost: 50, color: Colors.cyan, currency: 'gold', stars: 50, category: '💎 Luxury', badge: 'LUCKY'),

    // Silver Items
    GiftItem(id: 'a2000000-0000-0000-0000-000000000021', name: 'Like', icon: '👍', cost: 200, color: Colors.blue, currency: 'silver', stars: 2, category: '🔥 Popular'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000022', name: 'Flower', icon: '🌼', cost: 500, color: Colors.orange, currency: 'silver', stars: 5, category: '🔥 Popular'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000023', name: 'Rose', icon: '🌹', cost: 1000, color: Colors.pink, currency: 'silver', stars: 10, category: '❤️ Romantic'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000025', name: 'Coffee', icon: '☕', cost: 2000, color: Colors.brown, currency: 'silver', stars: 20, category: '🔥 Popular'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000026', name: 'Chocolate', icon: '🍫', cost: 2500, color: Colors.brown, currency: 'silver', stars: 25, category: '❤️ Romantic'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000027', name: 'Cake', icon: '🎂', cost: 3000, color: Colors.pink, currency: 'silver', stars: 30, category: '🎉 Party', badge: 'LUCKY'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000028', name: 'Balloon', icon: '🎈', cost: 3500, color: Colors.purpleAccent, currency: 'silver', stars: 35, category: '🎉 Party'),
    GiftItem(id: 'a2000000-0000-0000-0000-000000000029', name: 'Gift Box', icon: '🎁', cost: 4000, color: Colors.red, currency: 'silver', stars: 40, category: '🎉 Party', badge: 'LUCKY'),
  ];

  GiftItem? _selectedGift;
  VaultItem? _selectedVaultItem;

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
    _vaultCtrl = Get.find<VaultController>();
    _selectedGift = _allGifts[0]; // Default select Rose
    _initDefaultRecipients();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _initDefaultRecipients() {
    _selectedRecipients.clear();
    _selectedRecipientNames.clear();
    _selectedSeatIndices.clear();

    final seats = _controller.roomSeatsInfo[widget.roomId] ?? [];

    if (widget.targetUserId != null) {
      _selectedRecipients.add(widget.targetUserId!);
      _selectedRecipientNames.add(widget.targetUserName ?? 'User');
      final seat = seats.firstWhereOrNull((s) => s['userId'] == widget.targetUserId);
      if (seat != null) {
        _selectedSeatIndices.add(seat['seatIndex'] as int);
      }
    } else {
      // Auto-select the first occupied seat (including self if user is on a seat)
      final firstSeat = seats.firstWhereOrNull((s) => s['userId'] != null);
      if (firstSeat != null) {
        final uId = firstSeat['userId'] as String;
        final uName = firstSeat['name'] as String? ?? 'User';
        final seatIdx = firstSeat['seatIndex'] as int;
        _selectedRecipients.add(uId);
        _selectedRecipientNames.add(uName);
        _selectedSeatIndices.add(seatIdx);
      }
    }
  }

  List<GiftItem> get _filteredGifts {
    return _allGifts.where((g) {
      if (_selectedCurrencyTab == 1 && g.currency != 'gold') return false;
      if (_selectedCurrencyTab == 2 && g.currency != 'silver') return false;
      if (_selectedCurrencyTab == 3) return false;

      if (_selectedCategory != 'All') {
        final cleanCat = _selectedCategory.replaceAll(RegExp(r'[^\w\s]'), '').trim();
        final cleanGCat = g.category.replaceAll(RegExp(r'[^\w\s]'), '').trim();
        if (!cleanGCat.toLowerCase().contains(cleanCat.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  List<VaultItem> get _giftableVaultItems {
    return _vaultCtrl.vaultItems.where((item) {
      return item.giftable &&
          item.quantity > 0 &&
          (item.expiresAt == null || item.expiresAt!.isAfter(DateTime.now()));
    }).toList();
  }

  bool _isSending = false;

  void _sendGift() async {
    if (_isSending) return;
    debugPrint('[Gift] Button Clicked: Gift "${_selectedGift?.name}" to ${_selectedRecipientNames.join(", ")}');
    if (!_giftAll && _selectedRecipients.isEmpty) {
      Get.snackbar(
        'No Recipient Selected',
        'Please select a seat/recipient first.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.amber,
        colorText: Colors.black,
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final success = await GiftSendService.to.sendGift(
        roomId: widget.roomId,
        gift: _selectedGift,
        vaultItem: _selectedVaultItem,
        isVault: _selectedCurrencyTab == 3,
        giftAll: _giftAll,
        selectedRecipients: _selectedRecipients,
        selectedRecipientNames: _selectedRecipientNames,
        selectedSeatIndices: _selectedSeatIndices,
        comboMultiplier: _selectedComboMultiplier,
      );

      if (success) {
        // Backend confirmed success! ONLY NOW close the dialog panel
        if (mounted) Get.back();
        if (widget.onGiftSent != null) {
          if (_selectedCurrencyTab == 3 && _selectedVaultItem != null) {
            widget.onGiftSent!(_selectedVaultItem!.displayName, '🎁', 0, 'vault');
          } else if (_selectedGift != null) {
            widget.onGiftSent!(
              _selectedGift!.name,
              _selectedGift!.icon,
              _selectedGift!.cost * _selectedComboMultiplier,
              _selectedGift!.currency,
            );
          }
        }
      } else {
        // Keep gift panel open, error already shown, no animation played, no double coins deducted
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeReceiversCount = _giftAll
        ? (_controller.roomSeatsInfo[widget.roomId] ?? []).where((s) => s['userId'] != null).length
        : _selectedRecipients.length;

    final double singleCost = _selectedGift != null ? _selectedGift!.cost.toDouble() : 0.0;
    final totalCost = singleCost * _selectedComboMultiplier * (activeReceiversCount > 0 ? activeReceiversCount : 1);
    final hasValidRecipient = _giftAll || _selectedRecipients.isNotEmpty;
    final screenHeight = MediaQuery.of(context).size.height;

    // Bottom Anchored Half Screen Modal Panel
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: screenHeight * 0.62, // Sufficient vertical space for 2 rows of gift cards
          decoration: BoxDecoration(
            color: const Color(0xFF090A10).withOpacity(0.97),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: const Border(
              top: BorderSide(color: Color(0xFF2A2D42), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.9),
                blurRadius: 25,
                offset: const Offset(0, -10),
              )
            ],
          ),
          child: Column(
            children: [
              // Top Drag Handle Indicator
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── 1. FULL-WIDTH TOP CURRENCY TABS ──
              _buildCurrencyTabsRow(),

              // ── 2. DEDICATED RECIPIENT AVATAR SELECTOR (ONLY AVATARS) ──
              _buildAvatarOnlyRecipientSelector(),

              // ── 3. CATEGORY CHIPS SCROLLER ──
              if (_selectedCurrencyTab != 3) _buildCategoryChipsRow(),

              const SizedBox(height: 4),

              // ── 4. HORIZONTAL GIFT CAROUSEL (PAGEVIEW 2 ROWS x 4 COLUMNS) ──
              Expanded(
                child: _selectedCurrencyTab == 3 ? _buildVaultView() : _buildHorizontalGiftCarousel(),
              ),

              // ── 5. FIXED BOTTOM CONTROL BAR ──
              _buildBottomControlBar(hasValidRecipient, totalCost),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. FULL-WIDTH TOP CURRENCY TABS ──
  Widget _buildCurrencyTabsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _currencyTabPill(0, 'All', '⭐', null),
                  const SizedBox(width: 6),
                  Obx(() => _currencyTabPill(1, 'Gold', '🟡', formatCompactNumber(_storeCtrl.coinsBalance.value))),
                  const SizedBox(width: 6),
                  Obx(() => _currencyTabPill(2, 'Silver', '⚪', formatCompactNumber(_storeCtrl.silverCoinsBalance.value))),
                  const SizedBox(width: 6),
                  Obx(() => _currencyTabPill(3, 'Vault', '🎁', '${_giftableVaultItems.length}')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. DEDICATED RECIPIENT AVATAR SELECTOR (ONLY AVATARS, AT THE TOP) ──
  Widget _buildAvatarOnlyRecipientSelector() {
    final seats = _controller.roomSeatsInfo[widget.roomId] ?? [];
    final occupiedSeats = seats.where((s) => s['userId'] != null).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Text(
            'To:',
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  if (occupiedSeats.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141624),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'No occupied seats',
                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                      ),
                    )
                  else
                    ...occupiedSeats.map((seat) {
                      final uId = seat['userId'] as String;
                      final uName = seat['name'] as String? ?? 'User';
                      final avatar = seat['avatar'] as String?;
                      final seatIdx = seat['seatIndex'] as int;
                      final isSelected = _giftAll || _selectedRecipients.contains(uId);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_giftAll) _giftAll = false;
                            if (isSelected && !_giftAll) {
                              _selectedRecipients.remove(uId);
                              _selectedRecipientNames.remove(uName);
                              _selectedSeatIndices.remove(seatIdx);
                            } else {
                              if (_selectedRecipients.length < 10) {
                                _selectedRecipients.add(uId);
                                _selectedRecipientNames.add(uName);
                                _selectedSeatIndices.add(seatIdx);
                              }
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 8),
                          width: 34,
                          height: 34,
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isSelected
                                ? const LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B), Color(0xFF8B5CF6)])
                                : const LinearGradient(colors: [Color(0xFF25283D), Color(0xFF1A1C29)]),
                            boxShadow: isSelected
                                ? [BoxShadow(color: const Color(0xFFFF416C).withOpacity(0.4), blurRadius: 8)]
                                : [],
                          ),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundImage: avatar != null && avatar.isNotEmpty
                                    ? NetworkImage(avatar)
                                    : const AssetImage('assets/images/placeholder.png') as ImageProvider,
                              ),
                              if (isSelected)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
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
                        ),
                      );
                    }).toList(),

                  // "Gift All" Avatar Circle Button
                  if (occupiedSeats.length > 1)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _giftAll = !_giftAll;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(left: 2, right: 4),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _giftAll ? const Color(0xFFFF9F43) : const Color(0xFF141624),
                          border: Border.all(
                            color: _giftAll ? Colors.amber : const Color(0xFF25283D),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            '🎙️',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _currencyTabPill(int index, String label, String iconEmoji, String? balanceStr) {
    final isSelected = _selectedCurrencyTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCurrencyTab = index;
          _currentCarouselPage = 0;
          if (_pageController.hasClients) {
            _pageController.jumpToPage(0);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF141624),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFA78BFA) : const Color(0xFF25283D),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.4),
                    blurRadius: 10,
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(iconEmoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (balanceStr != null && balanceStr.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                balanceStr,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.amberAccent : Colors.white38,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // ── 2. RECIPIENT SELECTION ROW ("kisko gift de rahe ho") ──
  Widget _buildRecipientSelectionBar(int activeReceiversCount) {
    final seats = _controller.roomSeatsInfo[widget.roomId] ?? [];
    final occupiedSeats = seats.where((s) => s['userId'] != null).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Text(
            'To:',
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  if (occupiedSeats.isEmpty)
                    Text(
                      'No occupied seats',
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                    )
                  else
                    ...occupiedSeats.map((seat) {
                      final uId = seat['userId'] as String;
                      final uName = seat['name'] as String? ?? 'User';
                      final avatar = seat['avatar'] as String?;
                      final seatIdx = seat['seatIndex'] as int;
                      final isSelected = _selectedRecipients.contains(uId);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedRecipients.remove(uId);
                              _selectedRecipientNames.remove(uName);
                              _selectedSeatIndices.remove(seatIdx);
                            } else {
                              if (_selectedRecipients.length < 10) {
                                _selectedRecipients.add(uId);
                                _selectedRecipientNames.add(uName);
                                _selectedSeatIndices.add(seatIdx);
                              }
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF7C3AED).withOpacity(0.25) : const Color(0xFF141624),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF25283D),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 9,
                                backgroundImage: avatar != null && avatar.isNotEmpty
                                    ? NetworkImage(avatar)
                                    : const AssetImage('assets/images/placeholder.png') as ImageProvider,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                uName,
                                style: GoogleFonts.inter(
                                  color: isSelected ? Colors.amberAccent : Colors.white70,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 3),
                                const Icon(Icons.check_circle, size: 10, color: Color(0xFF10B981)),
                              ]
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),
          if (occupiedSeats.length > 1) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                setState(() {
                  _giftAll = !_giftAll;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _giftAll ? const Color(0xFFFF9F43) : const Color(0xFF141624),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _giftAll ? Colors.amber : const Color(0xFF25283D)),
                ),
                child: Text(
                  'All Seats 🎙️',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            )
          ]
        ],
      ),
    );
  }

  // ── 3. CATEGORY CHIPS SCROLLER ──
  Widget _buildCategoryChipsRow() {
    return Container(
      height: 30,
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = cat;
                _currentCarouselPage = 0;
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(0);
                }
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF141624),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? const Color(0xFFA78BFA) : const Color(0xFF25283D),
                ),
              ),
              child: Center(
                child: Text(
                  cat,
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontSize: 9.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 4. HORIZONTAL GIFT CAROUSEL (PAGEVIEW 2 ROWS x 4 COLUMNS = 8 ITEMS PER PAGE) ──
  Widget _buildHorizontalGiftCarousel() {
    final filtered = _filteredGifts;
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No gifts found in this category.',
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    const int itemsPerPage = 8; // 2 rows x 4 columns (8 items per page for portrait rendering)
    final int pageCount = (filtered.length / itemsPerPage).ceil();

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: pageCount,
            onPageChanged: (page) {
              setState(() {
                _currentCarouselPage = page;
              });
            },
            itemBuilder: (context, pageIndex) {
              final startIdx = pageIndex * itemsPerPage;
              final endIdx = min(startIdx + itemsPerPage, filtered.length);
              final pageGifts = filtered.sublist(startIdx, endIdx);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.74,
                  ),
                  itemCount: pageGifts.length,
                  itemBuilder: (context, index) {
                    final gift = pageGifts[index];
                    final isSelected = _selectedGift?.id == gift.id;
                    return _buildGiftCardItem(gift, isSelected);
                  },
                ),
              );
            },
          ),
        ),

        // Page Indicator Dots
        if (pageCount > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pageCount, (idx) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                width: _currentCarouselPage == idx ? 12 : 4,
                height: 4,
                decoration: BoxDecoration(
                  color: _currentCarouselPage == idx ? const Color(0xFF8B5CF6) : Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildGiftCardItem(GiftItem gift, bool isSelected) {
    final isGold = gift.currency == 'gold';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGift = gift;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? (isGold ? const Color(0xFFFFD700).withOpacity(0.18) : const Color(0xFF8B5CF6).withOpacity(0.25))
              : const Color(0xFF131522),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? (isGold ? const Color(0xFFFFD700) : const Color(0xFFA78BFA))
                : const Color(0xFF23263B),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isGold ? Colors.amber : const Color(0xFF8B5CF6)).withOpacity(0.35),
                    blurRadius: 8,
                  )
                ]
              : [],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.03),
                  ),
                  child: Text(
                    gift.icon,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    gift.name,
                    style: GoogleFonts.poppins(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    isGold ? _buildGoldCoinIcon(size: 10) : _buildSilverCoinIcon(size: 10),
                    const SizedBox(width: 2),
                    Text(
                      formatCompactNumber(gift.cost),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: isGold ? const Color(0xFFFFD700) : Colors.white70,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (gift.badge != null)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: _getBadgeGradient(gift.badge!),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    gift.badge!,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 5.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  LinearGradient _getBadgeGradient(String badge) {
    switch (badge) {
      case 'HOT':
        return const LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)]);
      case 'NEW':
        return const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057)]);
      case 'VIP':
        return const LinearGradient(colors: [Color(0xFFF7971E), Color(0xFFFFD200)]);
      case 'LUCKY':
        return const LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)]);
      case 'LEGEND':
        return const LinearGradient(colors: [Color(0xFFF12711), Color(0xFFF5AF19)]);
      default:
        return const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]);
    }
  }

  // ── VAULT TAB VIEW ──
  Widget _buildVaultView() {
    return Obx(() {
      final vaultItemsList = _giftableVaultItems;
      if (vaultItemsList.isEmpty) {
        return Center(
          child: Text(
            'No giftable items found in your Vault.',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
          ),
        );
      }

      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.8,
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
                color: isSelected ? const Color(0xFF8B5CF6).withOpacity(0.25) : const Color(0xFF131522),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF23263B),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.category == 'Premium' ? '👑' : '🎒',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.displayName,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Qty: ${item.quantity}',
                    style: GoogleFonts.inter(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  // ── 5. FIXED BOTTOM CONTROL BAR ──
  Widget _buildBottomControlBar(bool hasValidRecipient, double totalCost) {
    final combos = [1, 5, 10, 99, 520, 1314];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF090A10),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        border: Border(top: BorderSide(color: Color(0xFF1E2032))),
      ),
      child: Row(
        children: [
          // Left: Balance Display
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(() => Row(
                    children: [
                      _buildGoldCoinIcon(size: 11),
                      const SizedBox(width: 3),
                      Text(
                        formatCompactNumber(_storeCtrl.coinsBalance.value),
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.add_circle, color: Colors.amber, size: 10),
                    ],
                  )),
              const SizedBox(height: 2),
              Obx(() => Row(
                    children: [
                      _buildSilverCoinIcon(size: 11),
                      const SizedBox(width: 3),
                      Text(
                        formatCompactNumber(_storeCtrl.silverCoinsBalance.value),
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  )),
            ],
          ),

          const SizedBox(width: 8),

          // VIP Button
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('👑', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 3),
                  Text(
                    'VIP',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Center: Combo Selector Multipliers (1x, 5x, 10x, 99x, 520x, 1314x)
          if (_selectedCurrencyTab != 3)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141624),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF282B40)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: combos.map((val) {
                      final isSelected = _selectedComboMultiplier == val;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedComboMultiplier = val;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${val}x',
                            style: GoogleFonts.inter(
                              color: isSelected ? Colors.white : Colors.white60,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

          const SizedBox(width: 8),

          // Right: Premium SEND Button
          ElevatedButton(
            onPressed: (hasValidRecipient && !_isSending) ? _sendGift : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: (hasValidRecipient && !_isSending)
                    ? const LinearGradient(
                        colors: [Color(0xFFFF416C), Color(0xFFFF4B2B), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF3A3D52), Color(0xFF2A2C3D)],
                      ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: (hasValidRecipient && !_isSending)
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF4B2B).withOpacity(0.4),
                          blurRadius: 10,
                        )
                      ]
                    : [],
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSending) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SENDING...',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ] else ...[
                      const Text('🎁', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        hasValidRecipient
                            ? (_selectedCurrencyTab == 3 ? 'SEND' : 'SEND (${formatCompactNumber(totalCost.toInt())})')
                            : 'SELECT SEAT',
                        style: GoogleFonts.poppins(
                          color: hasValidRecipient ? Colors.white : Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helpers for currency icons
  Widget _buildGoldCoinIcon({double size = 11}) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFFFE259), Color(0xFFFFA751)],
      ).createShader(bounds),
      child: Icon(Icons.monetization_on_rounded, color: Colors.white, size: size),
    );
  }

  Widget _buildSilverCoinIcon({double size = 11}) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFB0B3B8)],
      ).createShader(bounds),
      child: Icon(Icons.monetization_on_rounded, color: Colors.white, size: size),
    );
  }
}
