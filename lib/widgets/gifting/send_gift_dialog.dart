// lib/widgets/gifting/send_gift_dialog.dart

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
import '../../utils/number_formatter.dart';
import '../../services/user/user_profile_cache_manager.dart';

class GiftItem {
  final String id;
  final String name;
  final String icon;
  final int cost;
  final String currency; // 'gold' or 'silver'
  final GiftTier tier;
  final String category; // 'Tier 1', 'Tier 2', 'Tier 3', 'Tier 4', 'Tier 5'
  final String? badge; // 'LUCKY', 'HOT', 'VIP', 'EPIC', 'LEGEND', 'MYTHIC'
  final bool isLucky;

  GiftItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.cost,
    required this.currency,
    required this.tier,
    required this.category,
    this.badge,
    this.isLucky = false,
  });
}

class SendGiftDialog extends StatefulWidget {
  final String roomId;
  final int occupiedSeatsCount;
  final String? targetUserId;
  final String? targetUserName;
  final Function(
          String giftName, String giftIcon, int giftCost, String currency)?
      onGiftSent;

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
    '🎰 Lucky Gifts',
    '🥈 Tier 1',
    '🥇 Tier 2',
    '👑 Tier 3',
    '💎 Tier 4',
    '⚡ Tier 5',
  ];

  // Master 35-Gift Catalog (1-to-1 match with Postgres gift_catalog table & GiftMetadataRegistry)
  final List<GiftItem> _allGifts = [
    // 🥈 TIER 1 (15 Gifts: 3 Silver, 12 Gold)
    GiftItem(
        id: 'f1000001-0000-0000-0000-000000000001',
        name: 'Rose',
        icon: '🌹',
        cost: 100,
        currency: 'silver',
        tier: GiftTier.tier1,
        category: '🥈 Tier 1'),
    GiftItem(
        id: 'f1000001-0000-0000-0000-000000000002',
        name: 'Heart',
        icon: '❤️',
        cost: 300,
        currency: 'silver',
        tier: GiftTier.tier1,
        category: '🥈 Tier 1'),
    GiftItem(
        id: 'f1000001-0000-0000-0000-000000000003',
        name: 'Coffee',
        icon: '☕',
        cost: 800,
        currency: 'silver',
        tier: GiftTier.tier1,
        category: '🥈 Tier 1'),
    GiftItem(
        id: 'f1000001-0000-0000-0000-000000000004',
        name: 'Sakura',
        icon: '🌸',
        cost: 2,
        currency: 'gold',
        tier: GiftTier.tier1,
        category: '🥈 Tier 1',
        badge: 'LUCKY',
        isLucky: true),
    GiftItem(
        id: 'f1000001-0000-0000-0000-000000000005',
        name: 'Lucky Star',
        icon: '⭐',
        cost: 2,
        currency: 'gold',
        tier: GiftTier.tier1,
        category: '🥈 Tier 1'),
    GiftItem(
        id: 'f1000001-0000-0000-0000-000000000006',
        name: 'Chocolate',
        icon: '🍫',
        cost: 4,
        currency: 'gold',
        tier: GiftTier.tier1,
        category: '🥈 Tier 1'),
    GiftItem(
        id: 'f1000001-0000-0000-0000-000000000007',
        name: 'Balloon',
        icon: '🎈',
        cost: 4,
        currency: 'gold',
        tier: GiftTier.tier1,
        category: '🥈 Tier 1'),
    GiftItem(
        id: 'f1000001-0000-0000-0000-000000000008',
        name: 'Cake',
        icon: '🍰',
        cost: 5,
        currency: 'gold',
        tier: GiftTier.tier1,
        category: '🥈 Tier 1'),
    GiftItem(
        id: 'f1000001-0000-0000-0000-000000000009',
        name: 'Butterfly',
        icon: '🦋',
        cost: 5,
        currency: 'gold',
        tier: GiftTier.tier1,
        category: '🥈 Tier 1'),
    GiftItem(
        id: 'f1000001-0000-0000-0000-000000000010',
        name: 'Love Letter',
        icon: '💌',
        cost: 8,
        currency: 'gold',
        tier: GiftTier.tier1,
        category: '🥈 Tier 1'),
    GiftItem(
        id: 'f1000001-0000-0000-0000-000000000011',
        name: 'Gift Box',
        icon: '🎁',
        cost: 9,
        currency: 'gold',
        tier: GiftTier.tier1,
        category: '🥈 Tier 1',
        badge: 'LUCKY',
        isLucky: true),
    GiftItem(
        id: 'f1000001-0000-0000-0000-000000000012',
        name: 'Teddy',
        icon: '🧸',
        cost: 9,
        currency: 'gold',
        tier: GiftTier.tier1,
        category: '🥈 Tier 1'),
    GiftItem(
        id: 'f1000001-0000-0000-0000-000000000013',
        name: 'Lucky Clover',
        icon: '🍀',
        cost: 15,
        currency: 'gold',
        tier: GiftTier.tier1,
        category: '🥈 Tier 1'),
    GiftItem(
        id: 'f1000001-0000-0000-0000-000000000014',
        name: 'Moon',
        icon: '🌙',
        cost: 19,
        currency: 'gold',
        tier: GiftTier.tier1,
        category: '🥈 Tier 1'),
    GiftItem(
        id: 'f1000001-0000-0000-0000-000000000015',
        name: 'Sunshine',
        icon: '☀️',
        cost: 19,
        currency: 'gold',
        tier: GiftTier.tier1,
        category: '🥈 Tier 1'),

    // 🥇 TIER 2 (7 Gifts: 2 Silver, 5 Gold)
    GiftItem(
        id: 'f1000002-0000-0000-0000-000000000001',
        name: 'Bouquet',
        icon: '💐',
        cost: 2000,
        currency: 'silver',
        tier: GiftTier.tier2,
        category: '🥇 Tier 2'),
    GiftItem(
        id: 'f1000002-0000-0000-0000-000000000002',
        name: 'Birthday Cake',
        icon: '🎂',
        cost: 5000,
        currency: 'silver',
        tier: GiftTier.tier2,
        category: '🥇 Tier 2'),
    GiftItem(
        id: 'f1000002-0000-0000-0000-000000000003',
        name: 'Diamond Ring',
        icon: '💍',
        cost: 29,
        currency: 'gold',
        tier: GiftTier.tier2,
        category: '🥇 Tier 2',
        badge: 'LUCKY',
        isLucky: true),
    GiftItem(
        id: 'f1000002-0000-0000-0000-000000000004',
        name: 'Crown',
        icon: '👑',
        cost: 49,
        currency: 'gold',
        tier: GiftTier.tier2,
        category: '🥇 Tier 2',
        badge: 'VIP'),
    GiftItem(
        id: 'f1000002-0000-0000-0000-000000000005',
        name: 'Golden Mic',
        icon: '🎤',
        cost: 79,
        currency: 'gold',
        tier: GiftTier.tier2,
        category: '🥇 Tier 2'),
    GiftItem(
        id: 'f1000002-0000-0000-0000-000000000006',
        name: 'Champion Trophy',
        icon: '🏆',
        cost: 119,
        currency: 'gold',
        tier: GiftTier.tier2,
        category: '🥇 Tier 2',
        badge: 'LUCKY',
        isLucky: true),
    GiftItem(
        id: 'f1000002-0000-0000-0000-000000000007',
        name: 'Crystal Diamond',
        icon: '💎',
        cost: 149,
        currency: 'gold',
        tier: GiftTier.tier2,
        category: '🥇 Tier 2'),

    // 👑 TIER 3 (5 Gifts: 1 Silver, 4 Gold)
    GiftItem(
        id: 'f1000003-0000-0000-0000-000000000001',
        name: 'Fireworks',
        icon: '🎆',
        cost: 10000,
        currency: 'silver',
        tier: GiftTier.tier3,
        category: '👑 Tier 3'),
    GiftItem(
        id: 'f1000003-0000-0000-0000-000000000002',
        name: 'Super Car',
        icon: '🏎️',
        cost: 299,
        currency: 'gold',
        tier: GiftTier.tier3,
        category: '👑 Tier 3',
        badge: 'LUCKY',
        isLucky: true),
    GiftItem(
        id: 'f1000003-0000-0000-0000-000000000003',
        name: 'Rocket',
        icon: '🚀',
        cost: 499,
        currency: 'gold',
        tier: GiftTier.tier3,
        category: '👑 Tier 3'),
    GiftItem(
        id: 'f1000003-0000-0000-0000-000000000004',
        name: 'Private Jet',
        icon: '✈️',
        cost: 799,
        currency: 'gold',
        tier: GiftTier.tier3,
        category: '👑 Tier 3'),
    GiftItem(
        id: 'f1000003-0000-0000-0000-000000000005',
        name: 'Treasure Chest',
        icon: '💰',
        cost: 999,
        currency: 'gold',
        tier: GiftTier.tier3,
        category: '👑 Tier 3'),

    // 💎 TIER 4 (4 Gifts: 0 Silver, 4 Gold)
    GiftItem(
        id: 'f1000004-0000-0000-0000-000000000001',
        name: 'Golden Dragon',
        icon: '🐉',
        cost: 1999,
        currency: 'gold',
        tier: GiftTier.tier4,
        category: '💎 Tier 4',
        badge: 'LUCKY',
        isLucky: true),
    GiftItem(
        id: 'f1000004-0000-0000-0000-000000000002',
        name: 'Phoenix',
        icon: '🔥',
        cost: 2999,
        currency: 'gold',
        tier: GiftTier.tier4,
        category: '💎 Tier 4'),
    GiftItem(
        id: 'f1000004-0000-0000-0000-000000000003',
        name: 'Galaxy Portal',
        icon: '🌌',
        cost: 4499,
        currency: 'gold',
        tier: GiftTier.tier4,
        category: '💎 Tier 4'),
    GiftItem(
        id: 'f1000004-0000-0000-0000-000000000004',
        name: 'Crystal Castle',
        icon: '🏰',
        cost: 6999,
        currency: 'gold',
        tier: GiftTier.tier4,
        category: '💎 Tier 4'),

    // ⚡ TIER 5 (4 Gifts: 0 Silver, 4 Gold - Premium Showcase)
    GiftItem(
        id: 'f1000005-0000-0000-0000-000000000001',
        name: 'Celestial Emperor',
        icon: '👑',
        cost: 7999,
        currency: 'gold',
        tier: GiftTier.tier5,
        category: '⚡ Tier 5',
        badge: 'LEGEND'),
    GiftItem(
        id: 'f1000005-0000-0000-0000-000000000002',
        name: 'Planet Creation',
        icon: '🌍',
        cost: 19999,
        currency: 'gold',
        tier: GiftTier.tier5,
        category: '⚡ Tier 5',
        badge: 'MYTHIC'),
    GiftItem(
        id: 'f1000005-0000-0000-0000-000000000003',
        name: 'World Tree',
        icon: '🌳',
        cost: 19999,
        currency: 'gold',
        tier: GiftTier.tier5,
        category: '⚡ Tier 5',
        badge: 'MYTHIC'),
    GiftItem(
        id: 'f1000005-0000-0000-0000-000000000004',
        name: 'Infinity Cosmos',
        icon: '🌠',
        cost: 29999,
        currency: 'gold',
        tier: GiftTier.tier5,
        category: '⚡ Tier 5',
        badge: 'COSMIC'),
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
    _selectedGift = _allGifts[3]; // Default select Sakura
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
      final seat =
          seats.firstWhereOrNull((s) => s['userId'] == widget.targetUserId);
      final resolvedName = UserProfileCacheManager.resolveUsernameForGifting(
        widget.targetUserId,
        passedName: widget.targetUserName,
        seatInfo: seat,
      );
      _selectedRecipients.add(widget.targetUserId!);
      _selectedRecipientNames.add(resolvedName);
      if (seat != null) {
        _selectedSeatIndices.add(seat['seatIndex'] as int);
      }
    } else {
      final firstSeat = seats.firstWhereOrNull((s) => s['userId'] != null);
      if (firstSeat != null) {
        final uId = firstSeat['userId'] as String;
        final resolvedName = UserProfileCacheManager.resolveUsernameForGifting(
          uId,
          passedName: firstSeat['username'] as String? ?? firstSeat['name'] as String?,
          seatInfo: firstSeat,
        );
        final seatIdx = firstSeat['seatIndex'] as int;
        _selectedRecipients.add(uId);
        _selectedRecipientNames.add(resolvedName);
        _selectedSeatIndices.add(seatIdx);
      } else {
        // Rule B: If nobody is on any mic seat, select Room Owner / Host by default!
        final room = _controller.rooms.firstWhereOrNull((r) => r.id == widget.roomId);
        final ownerId = (room?.hostId != null && room!.hostId.isNotEmpty)
            ? room.hostId
            : 'room_owner';
        final resolvedName = UserProfileCacheManager.resolveUsernameForGifting(
          ownerId,
          passedName: room?.ownerName,
        );

        _selectedRecipients.add(ownerId);
        _selectedRecipientNames.add(resolvedName);
        _selectedSeatIndices.add(0);
      }
    }
  }

  List<GiftItem> get _filteredGifts {
    return _allGifts.where((g) {
      if (_selectedCurrencyTab == 1 && g.currency != 'gold') return false;
      if (_selectedCurrencyTab == 2 && g.currency != 'silver') return false;
      if (_selectedCurrencyTab == 3) return false;

      if (_selectedCategory != 'All') {
        if (_selectedCategory == '🎰 Lucky Gifts') {
          return g.isLucky;
        }
        final cleanCat =
            _selectedCategory.replaceAll(RegExp(r'[^\w\s]'), '').trim();
        final cleanGCat = g.category.replaceAll(RegExp(r'[^\w\s]'), '').trim();
        if (!cleanGCat.toLowerCase().contains(cleanCat.toLowerCase()))
          return false;
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
        if (mounted &&
            (Get.isBottomSheetOpen == true || Get.isDialogOpen == true)) {
          Get.back();
        }
        if (widget.onGiftSent != null && _selectedGift != null) {
          widget.onGiftSent!(
            _selectedGift!.name,
            _selectedGift!.icon,
            _selectedGift!.cost * _selectedComboMultiplier,
            _selectedGift!.currency,
          );
        }
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
        ? (_controller.roomSeatsInfo[widget.roomId] ?? [])
            .where((s) => s['userId'] != null)
            .length
        : _selectedRecipients.length;

    final double singleCost =
        _selectedGift != null ? _selectedGift!.cost.toDouble() : 0.0;
    final totalCost = singleCost *
        _selectedComboMultiplier *
        (activeReceiversCount > 0 ? activeReceiversCount : 1);
    final hasValidRecipient = _giftAll || _selectedRecipients.isNotEmpty;
    final screenHeight = MediaQuery.of(context).size.height;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: screenHeight * 0.62,
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
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildCurrencyTabsRow(),
              _buildAvatarOnlyRecipientSelector(),
              if (_selectedCurrencyTab != 3) _buildCategoryChipsRow(),
              const SizedBox(height: 4),
              Expanded(
                child: _selectedCurrencyTab == 3
                    ? _buildVaultView()
                    : _buildHorizontalGiftCarousel(),
              ),
              _buildBottomControlBar(hasValidRecipient, totalCost),
            ],
          ),
        ),
      ),
    );
  }

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
                  _currencyTabPill(0, 'All Gifts', '⭐', null),
                  const SizedBox(width: 6),
                  Obx(() => _currencyTabPill(1, 'Gold', '🟡',
                      formatCompactNumber(_storeCtrl.coinsBalance.value))),
                  const SizedBox(width: 6),
                  Obx(() => _currencyTabPill(
                      2,
                      'Silver',
                      '⚪',
                      formatCompactNumber(
                          _storeCtrl.silverCoinsBalance.value))),
                  const SizedBox(width: 6),
                  Obx(() => _currencyTabPill(
                      3, 'Vault', '🎁', '${_giftableVaultItems.length}')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarOnlyRecipientSelector() {
    final seats = _controller.roomSeatsInfo[widget.roomId] ?? [];
    final occupiedSeats = seats.where((s) => s['userId'] != null).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Text(
            'To:',
            style: GoogleFonts.poppins(
                color: Colors.white38,
                fontSize: 10.5,
                fontWeight: FontWeight.bold),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141624),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'No occupied seats',
                        style: GoogleFonts.inter(
                            color: Colors.white38, fontSize: 10),
                      ),
                    )
                  else
                    ...occupiedSeats.map((seat) {
                      final uId = seat['userId'] as String;
                      final uName = UserProfileCacheManager.resolveUsernameForGifting(
                        uId,
                        passedName: seat['username'] as String? ?? seat['name'] as String?,
                        seatInfo: seat,
                      );
                      final avatar = seat['avatar'] as String?;
                      final seatIdx = seat['seatIndex'] as int;
                      final isSelected =
                          _giftAll || _selectedRecipients.contains(uId);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_giftAll) _giftAll = false;
                            if (isSelected && !_giftAll) {
                              _selectedRecipients.remove(uId);
                              _selectedRecipientNames.removeWhere((n) => n == uName || n == 'User');
                              _selectedSeatIndices.remove(seatIdx);
                            } else {
                              if (!_selectedRecipients.contains(uId)) {
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
                                ? const LinearGradient(colors: [
                                    Color(0xFFFF416C),
                                    Color(0xFFFF4B2B),
                                    Color(0xFF8B5CF6)
                                  ])
                                : const LinearGradient(colors: [
                                    Color(0xFF25283D),
                                    Color(0xFF1A1C29)
                                  ]),
                          ),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundImage:
                                    avatar != null && avatar.isNotEmpty
                                        ? NetworkImage(avatar)
                                        : const AssetImage(
                                                'assets/images/placeholder.png')
                                            as ImageProvider,
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
                                    child: const Icon(Icons.check,
                                        size: 7, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
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
                          color: _giftAll
                              ? const Color(0xFFFF9F43)
                              : const Color(0xFF141624),
                          border: Border.all(
                            color: _giftAll
                                ? Colors.amber
                                : const Color(0xFF25283D),
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

  Widget _currencyTabPill(
      int index, String label, String iconEmoji, String? balanceStr) {
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
            color:
                isSelected ? const Color(0xFFA78BFA) : const Color(0xFF25283D),
            width: isSelected ? 1.5 : 1.0,
          ),
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
                color: isSelected
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF141624),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFA78BFA)
                      : const Color(0xFF25283D),
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

    const int itemsPerPage = 8;
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
        if (pageCount > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pageCount, (idx) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                width: _currentCarouselPage == idx ? 12 : 4,
                height: 4,
                decoration: BoxDecoration(
                  color: _currentCarouselPage == idx
                      ? const Color(0xFF8B5CF6)
                      : Colors.white24,
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
              ? (isGold
                  ? const Color(0xFFFFD700).withOpacity(0.18)
                  : const Color(0xFF8B5CF6).withOpacity(0.25))
              : const Color(0xFF131522),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? (isGold ? const Color(0xFFFFD700) : const Color(0xFFA78BFA))
                : const Color(0xFF23263B),
            width: isSelected ? 1.5 : 1.0,
          ),
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
                    isGold
                        ? _buildGoldCoinIcon(size: 10)
                        : _buildSilverCoinIcon(size: 10),
                    const SizedBox(width: 2),
                    Text(
                      formatCompactNumber(gift.cost),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color:
                            isGold ? const Color(0xFFFFD700) : Colors.white70,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
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
      case 'LUCKY':
        return const LinearGradient(
            colors: [Color(0xFF11998E), Color(0xFF38EF7D)]);
      case 'HOT':
        return const LinearGradient(
            colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)]);
      case 'VIP':
        return const LinearGradient(
            colors: [Color(0xFFF7971E), Color(0xFFFFD200)]);
      case 'LEGEND':
        return const LinearGradient(
            colors: [Color(0xFFF12711), Color(0xFFF5AF19)]);
      case 'MYTHIC':
        return const LinearGradient(
            colors: [Color(0xFF8A2387), Color(0xFFE94057)]);
      case 'COSMIC':
        return const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF00F2FE)]);
      default:
        return const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]);
    }
  }

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
                color: isSelected
                    ? const Color(0xFF8B5CF6).withOpacity(0.25)
                    : const Color(0xFF131522),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFF23263B),
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
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Qty: ${item.quantity}',
                    style: GoogleFonts.inter(
                        color: Colors.amber,
                        fontSize: 8,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

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
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.add_circle,
                          color: Colors.amber, size: 10),
                    ],
                  )),
              const SizedBox(height: 2),
              Obx(() => Row(
                    children: [
                      _buildSilverCoinIcon(size: 11),
                      const SizedBox(width: 3),
                      Text(
                        formatCompactNumber(
                            _storeCtrl.silverCoinsBalance.value),
                        style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  )),
            ],
          ),
          const SizedBox(width: 8),
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
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF7C3AED)
                              : Colors.transparent,
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
          ElevatedButton(
            onPressed: (hasValidRecipient && !_isSending) ? _sendGift : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: (hasValidRecipient && !_isSending)
                    ? const LinearGradient(
                        colors: [
                          Color(0xFFFF416C),
                          Color(0xFFFF4B2B),
                          Color(0xFF8B5CF6)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF3A3D52), Color(0xFF2A2C3D)],
                      ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SENDING...',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ] else ...[
                      const Text('🎁', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        hasValidRecipient
                            ? 'SEND (${formatCompactNumber(totalCost.toInt())})'
                            : 'SELECT SEAT',
                        style: GoogleFonts.poppins(
                          color:
                              hasValidRecipient ? Colors.white : Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
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

  Widget _buildGoldCoinIcon({double size = 11}) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFFFE259), Color(0xFFFFA751)],
      ).createShader(bounds),
      child:
          Icon(Icons.monetization_on_rounded, color: Colors.white, size: size),
    );
  }

  Widget _buildSilverCoinIcon({double size = 11}) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFB0B3B8)],
      ).createShader(bounds),
      child:
          Icon(Icons.monetization_on_rounded, color: Colors.white, size: size),
    );
  }
}
