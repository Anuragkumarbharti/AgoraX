import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../core/theme.dart';
import '../../services/store_controller.dart';
import '../../services/vip_controller.dart';
import '../../services/novel_controller.dart';
import '../../services/customization_controller.dart';
import '../../widgets/vip_badge_widget.dart';
import '../../widgets/novel_badge_widget.dart';
import 'coin_store_screen.dart';
import 'vip_novel_store_tab.dart';
import 'lucky_draw_screen.dart';
import 'gift_membership_screen.dart';
import 'history_screen.dart';
import 'admin_store_panel.dart';
import '../home/main_screen.dart';

class StoreHomeScreen extends StatefulWidget {
  const StoreHomeScreen({Key? key}) : super(key: key);

  @override
  State<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

class _StoreHomeScreenState extends State<StoreHomeScreen> with TickerProviderStateMixin {
  final StoreController _storeCtrl = Get.put(StoreController());
  final VipController _vipCtrl = Get.find<VipController>();
  final NovelController _novelCtrl = Get.find<NovelController>();
  final CustomizationController _custCtrl = Get.find<CustomizationController>();

  late TabController _categoryTabCtrl;
  late AnimationController _glowAnimCtrl;

  final List<String> categories = [
    'Coins 🪙', 'VIP 💎', 'Novel 📖', 'Frames 🖼️', 'Borders ✨', 'Themes 🎨', 'Gifts 🎁', 'Offers ⚡', 'Limited 👑'
  ];

  @override
  void initState() {
    super.initState();
    _categoryTabCtrl = TabController(length: categories.length, vsync: this);
    _glowAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _categoryTabCtrl.dispose();
    _glowAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Get.offAll(() => const MainScreen());
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF07070A),
        body: Stack(
        children: [
          // Background Radial Ambient Glows
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.15),
                    blurRadius: 100,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            top: 250,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD946EF).withOpacity(0.08),
                    blurRadius: 120,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB800).withOpacity(0.05),
                    blurRadius: 100,
                  )
                ],
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildStoreHeader(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMembershipSummaryCard(),
                        const SizedBox(height: 18),
                        _buildExpiryWarningsList(),
                        _buildFestivalSaleCarousel(),
                        const SizedBox(height: 18),
                        _buildQuickCategorySelector(),
                        const SizedBox(height: 20),
                        _buildDailyDealCard(),
                        const SizedBox(height: 20),
                        _buildLuckyDrawShortcut(),
                        const SizedBox(height: 24),
                        _buildLimitedOffersSection(),
                        const SizedBox(height: 24),
                        _buildCosmeticsQuickGrid(),
                        const SizedBox(height: 40),
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

  Widget _buildStoreHeader() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: const Color(0xFF07070A).withOpacity(0.85),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Get.offAll(() => const MainScreen());
          }
        },
      ),
      title: Text(
        'AGORAX MARKET',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w900,
          fontSize: 18,
          letterSpacing: 2,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.gif_box_outlined, color: Colors.white70),
          tooltip: 'Gift Store',
          onPressed: () => Get.to(() => const GiftMembershipScreen()),
        ),
        IconButton(
          icon: const Icon(Icons.history_toggle_off_rounded, color: Colors.white70),
          tooltip: 'Purchase History',
          onPressed: () => Get.to(() => const StoreHistoryScreen()),
        ),
        IconButton(
          icon: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFFFFD700)),
          tooltip: 'Admin Panel',
          onPressed: () => Get.to(() => const AdminStorePanel()),
        ),
      ],
    );
  }

  Widget _buildMembershipSummaryCard() {
    return Obx(() {
      final coins = _storeCtrl.coinsBalance.value;
      final vipLevel = _vipCtrl.vipLevel.value;
      final hasVip = vipLevel > 0;
      final novelLevel = _novelCtrl.novelLevel.value;
      final hasNovel = novelLevel > 0;

      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E1B4B).withOpacity(0.4),
                  const Color(0xFF09090B).withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF312E81).withOpacity(0.5), width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR WALLET',
                          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '🪙 $coins',
                              style: GoogleFonts.outfit(color: const Color(0xFFFFD700), fontSize: 28, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Coins',
                              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => Get.to(() => const CoinStoreScreen()),
                      child: Text(
                        'Buy Coins 🪙',
                        style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14.0),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _membershipStatusCol('VIP status', hasVip, '💎 VIP $vipLevel', 'Join VIP', () {
                      Get.to(() => const VipNovelStoreTab(initialIndex: 0));
                    }),
                    Container(height: 30, width: 1, color: Colors.white10),
                    _membershipStatusCol('Novel status', hasNovel, '📖 Novel $novelLevel', 'Unlock Novel', () {
                      Get.to(() => const VipNovelStoreTab(initialIndex: 1));
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _membershipStatusCol(String label, bool active, String activeText, String joinText, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.white30, fontSize: 10)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                active ? activeText : joinText,
                style: GoogleFonts.poppins(
                  color: active ? const Color(0xFFFFD700) : const Color(0xFFD946EF),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 8),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryWarningsList() {
    return Obx(() {
      final warnings = _custCtrl.getActiveReminders();
      if (warnings.isEmpty) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.only(bottom: 18),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: warnings.map((warn) {
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF97316).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      warn,
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10.5),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      );
    });
  }

  Widget _buildFestivalSaleCarousel() {
    return AnimatedBuilder(
      animation: _glowAnimCtrl,
      builder: (context, child) {
        final glowVal = _glowAnimCtrl.value;
        return Container(
          width: double.infinity,
          height: 125,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF3B0764),
                const Color(0xFF0F172A).withOpacity(0.9),
                const Color(0xFF701A75),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC084FC).withOpacity(0.12 * glowVal),
                blurRadius: 15,
                spreadRadius: 1,
              )
            ],
            border: Border.all(
              color: Color.lerp(const Color(0xFF8B5CF6), const Color(0xFFD946EF), glowVal)!.withOpacity(0.4),
              width: 1.2,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                bottom: -20,
                right: -20,
                child: Text('⚡', style: TextStyle(fontSize: 90, color: Colors.white.withOpacity(0.04))),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEC4899).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'FESTIVAL BASH SALE',
                              style: GoogleFonts.poppins(color: const Color(0xFFF472B6), fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Flat 50% Off Coupons!',
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Use code FESTIVAL50 inside checkout screen.',
                            style: GoogleFonts.poppins(color: Colors.white60, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickCategorySelector() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              if (index == 0) {
                Get.to(() => const CoinStoreScreen());
              } else if (index == 1) {
                Get.to(() => const VipNovelStoreTab(initialIndex: 0));
              } else if (index == 2) {
                Get.to(() => const VipNovelStoreTab(initialIndex: 1));
              } else {
                Get.snackbar('Explore', '${categories[index]} store tab coming soon!', snackPosition: SnackPosition.BOTTOM);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B4B).withOpacity(0.3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF312E81).withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  categories[index],
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyDealCard() {
    return Obx(() {
      final seconds = _storeCtrl.dailyDealTimeSeconds.value;
      final originalPrice = _storeCtrl.dailyDealOriginalPrice.value;
      final discPrice = _storeCtrl.dailyDealDiscountedPrice.value;
      final remaining = _storeCtrl.dailyDealStockRemaining.value;
      final itemName = _storeCtrl.dailyDealItem.value;

      final hours = seconds ~/ 3600;
      final mins = (seconds % 3600) ~/ 60;
      final secs = seconds % 60;

      final durationText = '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0F172A),
              const Color(0xFF1E1B4B).withOpacity(0.5),
            ],
          ),
          border: Border.all(color: const Color(0xFFD946EF).withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flash_on_rounded, color: Color(0xFFD946EF), size: 18),
                    const SizedBox(width: 4),
                    Text(
                      'DAILY FLASH DEAL',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    durationText,
                    style: GoogleFonts.poppins(color: const Color(0xFFD946EF), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                  ),
                  child: const Center(child: Text('🖼️', style: TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName,
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '₹${discPrice.toInt()}',
                            style: GoogleFonts.poppins(color: const Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₹${originalPrice.toInt()}',
                            style: const TextStyle(color: Colors.white24, decoration: TextDecoration.lineThrough, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD946EF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: () {
                    // Navigate to checkout
                    Get.toNamed('/checkout', arguments: {
                      'name': itemName,
                      'category': 'Frame',
                      'basePrice': originalPrice,
                      'duration': '30 Days',
                    });
                  },
                  child: Text(
                    'Buy Deal',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'STOCK REMAINING: $remaining items left',
                  style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9.5),
                ),
                Container(
                  width: 140,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: remaining / 15.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildLuckyDrawShortcut() {
    return InkWell(
      onTap: () => Get.to(() => const LuckyDrawScreen()),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFFB800).withOpacity(0.1), shape: BoxShape.circle),
              child: const Text('🎯', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LUCKY DRAW WHEEL IS LIVE!',
                    style: GoogleFonts.outfit(color: const Color(0xFFFFB800), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Spin for VIP rewards, frame drops, and bonus coins.',
                    style: GoogleFonts.poppins(color: Colors.white60, fontSize: 10),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFFFB800), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitedOffersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 18),
            const SizedBox(width: 6),
            Text(
              'SPECIAL LIMITED PACKS',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildLimitedCard(
                'Immortal Sovereign Bundle',
                'VIP 7 + 10,000 Coins + Crown Particle Effect',
                '₹8,999',
                '₹14,999',
                'ONLY 4 LEFT',
                const Color(0xFFFFD700),
              ),
              _buildLimitedCard(
                'Cyber Neon Starter Kit',
                'Basic VIP + 500 Coins + Neon Aura Glow',
                '₹499',
                '₹899',
                'LIMITED QUANTITY',
                const Color(0xFF06B6D4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLimitedCard(String name, String desc, String price, String original, String badge, Color color) {
    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151518),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  badge,
                  style: GoogleFonts.poppins(color: color, fontSize: 7.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Text(
            desc,
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    price,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    original,
                    style: const TextStyle(color: Colors.white24, decoration: TextDecoration.lineThrough, fontSize: 10),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Get.toNamed('/checkout', arguments: {
                    'name': name,
                    'category': 'VIP',
                    'basePrice': double.parse(price.replaceAll(RegExp(r'[^0-9]'), '')),
                    'duration': '30 Days',
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(Icons.arrow_forward_rounded, color: color, size: 14),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCosmeticsQuickGrid() {
    final list = [
      {'name': 'Dragon Wings Aura', 'price': 300, 'icon': '⚔️'},
      {'name': 'Sapphire Seat Glow', 'price': 250, 'icon': '🪑'},
      {'name': 'Neon Echo Voice Mod', 'price': 180, 'icon': '🎙️'},
      {'name': 'Imperial Name Glow', 'price': 400, 'icon': '✨'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_bag_rounded, color: Color(0xFFD946EF), size: 18),
                const SizedBox(width: 6),
                Text(
                  'POPULAR COSMETICS',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
                ),
              ],
            ),
            Text(
              'View All',
              style: GoogleFonts.poppins(color: const Color(0xFFD946EF), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111115),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFF1E1B4B), borderRadius: BorderRadius.circular(10)),
                        child: Text(item['icon'] as String, style: const TextStyle(fontSize: 14)),
                      ),
                      Text(
                        '🪙 ${item['price']}',
                        style: GoogleFonts.poppins(color: const Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    item['name'] as String,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  InkWell(
                    onTap: () {
                      final success = _storeCtrl.deductCoins(item['price'] as int, 'Unlocked ${item['name']}');
                      if (success) {
                        Get.snackbar(
                          'Success! 🎉',
                          'Unlocked ${item['name']}. You can equip it in the Customization panel.',
                          backgroundColor: Colors.green.withOpacity(0.9),
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      } else {
                        Get.snackbar(
                          'Insufficient Balance 🪙',
                          'You need more coins to buy this item.',
                          backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                          mainButton: TextButton(
                            child: const Text('Top Up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Get.back();
                              Get.to(() => const CoinStoreScreen());
                            },
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
                      ),
                      child: Center(
                        child: Text(
                          'Unlock',
                          style: GoogleFonts.poppins(color: const Color(0xFFA78BFA), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
