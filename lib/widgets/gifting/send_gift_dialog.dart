// lib/widgets/gifting/send_gift_dialog.dart

import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/store/store_controller.dart';
import '../common/optimized_image.dart';
import '../../services/vault/vault_controller.dart';
import '../../services/gifting/gift_send_service.dart';
import '../../services/gifting/arena_gift_recipient_manager.dart';
import '../../models/vault/vault_models.dart';
import '../../models/gift/gift_animation_metadata.dart';
import '../../utils/number_formatter.dart';
import '../../services/user/user_profile_cache_manager.dart';
import '../../screens/store/coin_store_screen.dart';

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
  int _selectedTabIndex = 0;
  int _selectedComboMultiplier = 1;

  final PageController _pageController = PageController(initialPage: 0);
  final ScrollController _tabScrollController = ScrollController();

  final List<String> _starMakerTabs = [
    'All',
    '🎰 Lucky Gifts',
    '🎉 Event',
    '⚪ Silver',
    '🟡 Gold',
    '🎒 Vault',
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
        name: 'Lucky Gem',
        icon: '💎',
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

  // ── Recipient state is managed by ArenaGiftRecipientManager ────────────────
  // Local fields only kept for backward-compat with GiftSendService API;
  // actual source of truth lives in ArenaGiftRecipientManager.
  late ArenaGiftRecipientManager _recipientMgr;

  final StoreController _storeCtrl = Get.find<StoreController>();
  late VaultController _vaultCtrl;
  bool _isPriceAscending =
      true; // true = Price Low->High, false = Price High->Low

  int get _selectedRecipientCount => _recipientMgr.activeCount;

  int get _effectiveMultiplier {
    if (_selectedRecipientCount <= 0) return 0;
    if (_selectedComboMultiplier <= 0) return 1;
    if (_selectedComboMultiplier > 100) return 100;
    return _selectedComboMultiplier;
  }

  void _onRecipientSelectionChanged() {
    if (_selectedComboMultiplier <= 0) {
      _selectedComboMultiplier = 1;
    }
  }

  @override
  void initState() {
    super.initState();
    _vaultCtrl = Get.find<VaultController>();
    _selectedGift = _allGifts[3]; // Default select Sakura
    // Initialise recipient manager — auto-selects all occupied seats
    // or Room Owner fallback if no seats are occupied.
    // If targetUserId is set (tap-to-gift flow), only that user is pre-selected.
    _recipientMgr = ArenaGiftRecipientManager.to;
    _recipientMgr.initForRoom(
      widget.roomId,
      targetUserId: widget.targetUserId,
      targetUserName: widget.targetUserName,
    );
    _onRecipientSelectionChanged();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabScrollController.dispose();
    // Clean up recipient manager state when panel closes
    _recipientMgr.disposeForRoom();
    super.dispose();
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

    // Validate recipients via manager (handles Room Owner fallback internally)
    final finalRecipients =
        _recipientMgr.validateAndGetFinalRecipients(widget.roomId);

    if (finalRecipients.isEmpty) {
      Get.snackbar(
        'No Recipient Available',
        'Could not determine a gift recipient. Please try again.',
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
        isVault: _selectedTabIndex == 5,
        giftAll: false, // manager handles 'all' selection internally
        selectedRecipients:
            finalRecipients.map((e) => e.userId).toList(),
        selectedRecipientNames:
            finalRecipients.map((e) => e.userName).toList(),
        selectedSeatIndices:
            finalRecipients.map((e) => e.seatIndex).toList(),
        comboMultiplier: _effectiveMultiplier,
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
            _selectedGift!.cost * _effectiveMultiplier,
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

  List<GiftItem> _getGiftsForTab(int tabIndex) {
    List<GiftItem> gifts;
    switch (tabIndex) {
      case 0: // All (All Tier 1 through Tier 5 gifts!)
        gifts = List<GiftItem>.from(_allGifts);
        break;
      case 1: // Lucky Gifts
        gifts = _allGifts.where((g) => g.isLucky).toList();
        break;
      case 2: // Event (Tier 5 & Special showcase gifts)
        gifts = _allGifts
            .where((g) =>
                g.tier == GiftTier.tier5 ||
                g.badge == 'LEGEND' ||
                g.badge == 'MYTHIC' ||
                g.badge == 'COSMIC' ||
                g.category.contains('Tier 5'))
            .toList();
        break;
      case 3: // Silver
        gifts = _allGifts.where((g) => g.currency == 'silver').toList();
        break;
      case 4: // Gold
        gifts = _allGifts.where((g) => g.currency == 'gold').toList();
        break;
      default:
        gifts = [];
    }

    gifts.sort((a, b) => _isPriceAscending
        ? a.cost.compareTo(b.cost)
        : b.cost.compareTo(a.cost));

    return gifts;
  }

  @override
  Widget build(BuildContext context) {
    final activeReceiversCount = _selectedRecipientCount;
    final effectiveMultiplier = _effectiveMultiplier;

    final double singleCost =
        _selectedGift != null ? _selectedGift!.cost.toDouble() : 0.0;
    final totalCost = singleCost * effectiveMultiplier;
    final hasValidRecipient =
        activeReceiversCount > 0 && effectiveMultiplier > 0;

    // Calculate exact height for 2 rows of the 4-column gift grid
    final screenWidth = MediaQuery.of(context).size.width;
    final gridItemWidth =
        (screenWidth - 20.0 - 24.0) / 4.0; // 20=hPad*2, 24=3×spacing
    final gridItemHeight = gridItemWidth / 0.73;
    final gridTwoRowHeight = (gridItemHeight * 2 + 6 + 10)
        .ceilToDouble(); // 2rows + 1spacing + padding

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: double.infinity,
              // No fixed height — shrinks to exactly 2-row grid + other elements
              decoration: BoxDecoration(
                color: const Color(0xFF111226).withValues(alpha: 0.70),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF171735).withValues(alpha: 0.75),
                    width: 1.2,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6F5BFF).withValues(alpha: 0.12),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  _buildAvatarOnlyRecipientSelector(),
                  _buildStarMakerCategoryBar(),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: gridTwoRowHeight,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _starMakerTabs.length,
                      onPageChanged: (index) {
                        setState(() {
                          _selectedTabIndex = index;
                        });
                        if (_tabScrollController.hasClients) {
                          _tabScrollController.animateTo(
                            (index * 75.0).clamp(0.0,
                                _tabScrollController.position.maxScrollExtent),
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                      itemBuilder: (context, index) {
                        if (index == 5) {
                          return _buildVaultView();
                        }
                        final tabGifts = _getGiftsForTab(index);
                        return _buildTabGridView(tabGifts);
                      },
                    ),
                  ),
                  _buildBottomControlBar(hasValidRecipient, totalCost),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarOnlyRecipientSelector() {
    return Obx(() {
      final displayable = _recipientMgr.displayableRecipients;
      final activeIds =
          _recipientMgr.activeRecipients.map((e) => e.userId).toSet();

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
                    ...displayable.map((entry) {
                      final isSelected = activeIds.contains(entry.userId);
                      final isOwner = entry.isRoomOwner;
                      final isProtected =
                          _recipientMgr.isQuickGiftProtected(entry.userId);

                      return GestureDetector(
                        onTap: () {
                          _recipientMgr.toggleRecipient(entry);
                          _onRecipientSelectionChanged();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 8),
                          width: 34,
                          height: 34,
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            // Owner gets an amber/gold ring; others get the
                            // standard pink-purple gradient ring when selected.
                            gradient: isSelected
                                ? (isOwner
                                    ? const LinearGradient(colors: [
                                        Color(0xFFFFD700),
                                        Color(0xFFFF9F43),
                                        Color(0xFF8B5CF6),
                                      ])
                                    : const LinearGradient(colors: [
                                        Color(0xFFFF416C),
                                        Color(0xFFFF4B2B),
                                        Color(0xFF8B5CF6),
                                      ]))
                                : const LinearGradient(colors: [
                                    Color(0xFF25283D),
                                    Color(0xFF1A1C29),
                                  ]),
                          ),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundImage: (entry.avatarUrl != null &&
                                        entry.avatarUrl!.isNotEmpty)
                                    ? OptimizedImage.getOptimizedImageProvider(
                                        entry.avatarUrl!,
                                        preset: MediaSizePreset.xs,
                                      )
                                    : const AssetImage(
                                        'assets/images/placeholder.png'),
                                // Owner badge: small crown overlay on avatar
                                child: isOwner
                                    ? Align(
                                        alignment: Alignment.topCenter,
                                        child: Transform.translate(
                                          offset: const Offset(0, -4),
                                          child: const Text(
                                            '👑',
                                            style: TextStyle(fontSize: 8),
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              if (isSelected)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(1.5),
                                    decoration: BoxDecoration(
                                      color: isProtected
                                          ? const Color(0xFFFF9F43)
                                          : const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isProtected ? Icons.lock : Icons.check,
                                      size: 7,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStarMakerCategoryBar() {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _tabScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _starMakerTabs.length,
              itemBuilder: (context, index) {
                final tabName = _starMakerTabs[index];
                final isSelected = _selectedTabIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (index == 0 && _selectedTabIndex == 0) {
                        // All tab already selected — toggle sort
                        _isPriceAscending = !_isPriceAscending;
                      } else {
                        _selectedTabIndex = index;
                      }
                    });
                    if (index != 0 && _pageController.hasClients) {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF6F5BFF)],
                            )
                          : null,
                      color: isSelected ? null : const Color(0xFF141624),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFA78BFA)
                            : const Color(0xFF25283D),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF6F5BFF)
                                    .withValues(alpha: 0.35),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tabName,
                            style: GoogleFonts.poppins(
                              color: isSelected ? Colors.white : Colors.white60,
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          if (index == 0) ...[
                            const SizedBox(width: 3),
                            SizedBox(
                              width: 14,
                              height: 18,
                              child: ClipRect(
                                child: OverflowBox(
                                  maxHeight: 32,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => setState(
                                            () => _isPriceAscending = true),
                                        child: Icon(
                                          Icons.arrow_drop_up_rounded,
                                          size: 16,
                                          color: _isPriceAscending
                                              ? Colors.white
                                              : Colors.white
                                                  .withValues(alpha: 0.18),
                                        ),
                                      ),
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => setState(
                                            () => _isPriceAscending = false),
                                        child: Icon(
                                          Icons.arrow_drop_down_rounded,
                                          size: 16,
                                          color: !_isPriceAscending
                                              ? Colors.white
                                              : Colors.white
                                                  .withValues(alpha: 0.18),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabGridView(List<GiftItem> gifts) {
    if (gifts.isEmpty) {
      return Center(
        child: Text(
          'No gifts available in this section.',
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 6,
        childAspectRatio: 0.73,
      ),
      itemCount: gifts.length,
      itemBuilder: (context, index) {
        final gift = gifts[index];
        final isSelected = _selectedGift?.id == gift.id;
        return _buildGiftCardItem(gift, isSelected);
      },
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
      child: Container(
        color: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _BreathingGiftArtwork(
                      gift: gift,
                      isSelected: isSelected,
                      size: 66,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      gift.name,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
                          ? _buildGoldCoinIcon(size: 11)
                          : _buildSilverCoinIcon(size: 11),
                      const SizedBox(width: 3),
                      Text(
                        formatCompactNumber(gift.cost),
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color:
                              isGold ? const Color(0xFFFFD700) : Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (gift.badge != null)
              Positioned(
                top: 0,
                right: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: _getBadgeGradient(gift.badge!),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    gift.badge!,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 6.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
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
          childAspectRatio: 0.72,
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF8B5CF6).withOpacity(0.22)
                    : const Color(0xFF101220),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFA78BFA)
                      : const Color(0xFF222538),
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          item.category == 'Premium' ? '👑' : '🎒',
                          style: const TextStyle(fontSize: 42),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.displayName,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Qty: ${item.quantity}',
                      style: GoogleFonts.inter(
                        color: Colors.amber,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Future<void> _showCustomQuantityDialog() async {
    final TextEditingController ctrl = TextEditingController();
    int? customVal;

    if (_selectedRecipientCount <= 0) {
      Get.snackbar(
        'No Recipient Selected',
        'Please select recipients before choosing a custom multiplier.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.amber,
        colorText: Colors.black,
      );
      return;
    }

    await Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF141624),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter Custom Gift Multiplier (1x - 100x) 🎁',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Multiplier applies to EACH selected recipient',
                style: GoogleFonts.inter(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'e.g. 2, 5, 10, 20, 50, 100',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF090A10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF7C3AED)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [2, 5, 10, 20, 50, 100].map((preset) {
                  return ActionChip(
                    backgroundColor: const Color(0xFF282B40),
                    label: Text(
                      '${preset}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                    onPressed: () {
                      ctrl.text = '$preset';
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white60)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final val = int.tryParse(ctrl.text.trim());
                      if (val == null || val < 1 || val > 100) {
                        Get.snackbar(
                          'Invalid Multiplier',
                          'Please enter a valid multiplier between 1x and 100x',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.redAccent,
                          colorText: Colors.white,
                        );
                      } else {
                        customVal = val;
                        Get.back();
                      }
                    },
                    child: const Text('Apply',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (customVal != null) {
      setState(() {
        _selectedComboMultiplier = customVal!;
      });
    }
  }

  Widget _buildBottomControlBar(bool hasValidRecipient, double totalCost) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111226).withValues(alpha: 0.75),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF171735).withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Get.to(() => CoinStoreScreen());
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141624),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF282B40)),
                  ),
                  child: Row(
                    children: [
                      _buildGoldCoinIcon(size: 13),
                      const SizedBox(width: 4),
                      Obx(() => Text(
                            formatCompactNumber(_storeCtrl.coinsBalance.value),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          )),
                      const SizedBox(width: 3),
                      const Icon(Icons.chevron_right,
                          color: Colors.white54, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141624),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF282B40)),
                  ),
                  child: Row(
                    children: [
                      _buildSilverCoinIcon(size: 13),
                      const SizedBox(width: 4),
                      Obx(() => Text(
                            formatCompactNumber(
                                _storeCtrl.silverCoinsBalance.value),
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          )),
                      const SizedBox(width: 3),
                      const Icon(Icons.chevron_right,
                          color: Colors.white54, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF141624),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF282B40)),
                ),
                child: Row(
                  children: [
                    // Minus (-) Button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_selectedComboMultiplier > 1) {
                            _selectedComboMultiplier--;
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.remove,
                            color: Colors.white70, size: 12),
                      ),
                    ),
                    const SizedBox(width: 5),
                    // Multiplier Count & Arrow Picker Dialog
                    GestureDetector(
                      onTap: _showCustomQuantityDialog,
                      child: Row(
                        children: [
                          Text(
                            '${_effectiveMultiplier}',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_right,
                              color: Colors.white70, size: 14),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    // Plus (+) Button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_selectedComboMultiplier < 100) {
                            _selectedComboMultiplier++;
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white70, size: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed:
                    (hasValidRecipient && !_isSending) ? _sendGift : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: (hasValidRecipient && !_isSending)
                        ? const LinearGradient(
                            colors: [
                              Color(0xFF7C3AED),
                              Color(0xFF6F5BFF),
                              Color(0xFF8B5CF6)
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF3A3D52), Color(0xFF2A2C3D)],
                          ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: (hasValidRecipient && !_isSending)
                        ? [
                            BoxShadow(
                              color: const Color(0xFF6F5BFF).withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                    alignment: Alignment.center,
                    child: Text(
                      _isSending
                          ? 'SENDING...'
                          : (hasValidRecipient ? 'Send' : 'SELECT SEAT'),
                      style: GoogleFonts.poppins(
                        color:
                            hasValidRecipient ? Colors.white : Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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

class _BreathingGiftArtwork extends StatefulWidget {
  final GiftItem gift;
  final bool isSelected;
  final double size;

  const _BreathingGiftArtwork({
    Key? key,
    required this.gift,
    required this.isSelected,
    this.size = 52,
  }) : super(key: key);

  @override
  State<_BreathingGiftArtwork> createState() => _BreathingGiftArtworkState();
}

class _BreathingGiftArtworkState extends State<_BreathingGiftArtwork>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.12).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isSelected) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _BreathingGiftArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.repeat(reverse: true);
      } else {
        _controller.animateTo(
          0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildArtworkContent() {
    final meta = GiftMetadataRegistry.getMetadata(widget.gift.id);
    final assetPath = meta.resolvedGifAssetPath;
    final isGold = widget.gift.currency == 'gold';
    final themeColor = meta.themeColor;
    final isSelected = widget.isSelected;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft circular/elliptical light purple glow (#6F5BFF) behind the gift image
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.size * 1.15,
            height: widget.size * 1.15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  isSelected
                      ? const Color(0xFF6F5BFF).withOpacity(0.85)
                      : const Color(0xFF6F5BFF).withOpacity(0.35),
                  const Color(0xFF6F5BFF).withOpacity(0.0),
                ],
                stops: const [0.2, 1.0],
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6F5BFF).withOpacity(0.55),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
          Image.asset(
            assetPath,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Text(
                  widget.gift.icon,
                  style: TextStyle(
                    fontSize: widget.size * 0.85,
                    height: 1.0,
                    shadows: [
                      Shadow(
                        color: (isGold ? const Color(0xFFFFD700) : themeColor)
                            .withOpacity(0.6),
                        blurRadius: 20,
                      ),
                      Shadow(
                        color: Colors.black.withOpacity(0.85),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: _buildArtworkContent(),
    );
  }
}
