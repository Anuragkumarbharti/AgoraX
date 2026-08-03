import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:creania/core/theme.dart';
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
    'Coins 🪙',
    'VIP Membership 💎',
    'Novel Membership 📖',
    'Avatar Frames 🖼️',
    'Avatar Backgrounds 🌌',
    'Entry Effects ⚡',
    'Gift Effects 🎁',
    'Chat Bubbles 💬',
    'Badges 🏅',
    'Tag Lights ✨',
    'Emoji Effects 😊',
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
        backgroundColor: context.scaffoldBackgroundColor,
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
                    color: Color(0xFF8B5CF6).withOpacity(0.15),
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
                    color: Color(0xFFD946EF).withOpacity(0.08),
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
                    color: Color(0xFFFFB800).withOpacity(0.05),
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
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMembershipSummaryCard(),
                        SizedBox(height: 18),
                        _buildExpiryWarningsList(),
                        _buildFestivalSaleCarousel(),
                        SizedBox(height: 18),
                        _buildQuickCategorySelector(),
                        SizedBox(height: 20),
                        _buildDailyDealCard(),
                        SizedBox(height: 20),
                        _buildLuckyDrawShortcut(),
                        SizedBox(height: 24),
                        _buildLimitedOffersSection(),
                        SizedBox(height: 24),
                        _buildCosmeticsQuickGrid(),
                        SizedBox(height: 40),
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
      backgroundColor: context.scaffoldBackgroundColor.withOpacity(0.85),
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 18),
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Get.offAll(() => const MainScreen());
          }
        },
      ),
      title: Text(
        'CREANIA MARKET',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w900,
          fontSize: 18,
          letterSpacing: 2,
          color: context.textPrimary,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.gif_box_outlined, color: context.textSecondary),
          tooltip: 'Gift Store',
          onPressed: () => Get.to(() => const GiftMembershipScreen()),
        ),
        IconButton(
          icon: Icon(Icons.history_toggle_off_rounded, color: context.textSecondary),
          tooltip: 'Purchase History',
          onPressed: () => Get.to(() => const StoreHistoryScreen()),
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
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.borderColor, width: 1.5),
              boxShadow: context.smallShadow,
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
                          style: GoogleFonts.poppins(color: context.caption, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '🪙 $coins',
                              style: GoogleFonts.outfit(color: context.accentGold, fontSize: 28, fontWeight: FontWeight.w900),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Coins',
                              style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.accentGold,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => Get.to(() => const CoinStoreScreen()),
                      child: Text(
                        'Buy Coins 🪙',
                        style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 14.0),
                  child: Divider(color: context.borderColor, height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _membershipStatusCol('VIP status', hasVip, '💎 VIP $vipLevel', 'Join VIP', () {
                      Get.to(() => const VipNovelStoreTab(initialIndex: 0));
                    }),
                    Container(height: 30, width: 1, color: context.borderColor),
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
          Text(label, style: GoogleFonts.poppins(color: context.caption, fontSize: 10)),
          SizedBox(height: 4),
          Row(
            children: [
              Text(
                active ? activeText : joinText,
                style: GoogleFonts.poppins(
                  color: active ? context.accentGold : context.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              SizedBox(width: 2),
              Icon(Icons.arrow_forward_ios_rounded, color: context.caption, size: 8),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryWarningsList() {
    return Obx(() {
      final warnings = _custCtrl.getActiveReminders();
      if (warnings.isEmpty) return SizedBox.shrink();

      return Container(
        margin: EdgeInsets.only(bottom: 18),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: warnings.map((warn) {
              return Container(
                margin: EdgeInsets.only(right: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFF97316).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFFF97316).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316), size: 16),
                    SizedBox(width: 8),
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
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Color.lerp(Color(0xFF8B5CF6), Color(0xFFD946EF), glowVal)!.withOpacity(0.4),
              width: 1.2,
            ),
            boxShadow: context.smallShadow,
          ),
          child: Stack(
            children: [
              Positioned(
                bottom: -20,
                right: -20,
                child: Text('⚡', style: TextStyle(fontSize: 90, color: context.textPrimary.withOpacity(0.04))),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.primaryColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'FESTIVAL BASH SALE',
                              style: GoogleFonts.poppins(color: context.primaryColor, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Flat 50% Off Coupons!',
                            style: GoogleFonts.outfit(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Use code FESTIVAL50 inside checkout screen.',
                            style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, color: context.caption, size: 16),
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
                Get.snackbar(
                  'Explore',
                  '${categories[index]} are available inside the premium cosmetics flow.',
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            child: Container(
              margin: EdgeInsets.only(right: 10),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: context.secondaryBackgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderColor),
              ),
              child: Center(
                child: Text(
                  categories[index],
                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold),
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
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: context.surfaceColor,
          border: Border.all(color: context.borderColor),
          boxShadow: context.smallShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.flash_on_rounded, color: context.primaryColor, size: 18),
                    SizedBox(width: 4),
                    Text(
                      'DAILY FLASH DEAL',
                      style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.secondaryBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Text(
                    durationText,
                    style: GoogleFonts.poppins(color: context.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Color(0xFF8B5CF6).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Color(0xFF8B5CF6).withOpacity(0.3)),
                  ),
                  child: Center(child: Text('🖼️', style: TextStyle(fontSize: 24))),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName,
                        style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '₹${discPrice.toInt()}',
                            style: GoogleFonts.poppins(color: context.accentGold, fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '₹${originalPrice.toInt()}',
                            style: TextStyle(color: context.caption, decoration: TextDecoration.lineThrough, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'STOCK REMAINING: $remaining items left',
                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 9.5),
                ),
                Container(
                  width: 140,
                  height: 5,
                  decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(4)),
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
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.secondaryBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.borderColor),
          boxShadow: context.smallShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(color: context.accentGold.withOpacity(0.12), shape: BoxShape.circle),
              child: Text('🎯', style: TextStyle(fontSize: 20)),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LUCKY DRAW WHEEL IS LIVE!',
                    style: GoogleFonts.outfit(color: context.accentGold, fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Spin for VIP rewards, frame drops, and bonus coins.',
                    style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: context.accentGold, size: 14),
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
            Icon(Icons.star_rounded, color: context.accentGold, size: 18),
            SizedBox(width: 6),
            Text(
              'SPECIAL LIMITED PACKS',
              style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
            ),
          ],
        ),
        SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildLimitedCard(
                'Cyber Neon Starter Kit',
                'Basic VIP + 500 Coins + Neon Aura Glow',
                '₹499',
                '₹899',
                'LIMITED QUANTITY',
                Color(0xFF06B6D4),
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
      margin: EdgeInsets.only(right: 14),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: context.smallShadow,
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
                  style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            style: GoogleFonts.poppins(color: context.caption, fontSize: 9),
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
                    style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 6),
                  Text(
                    original,
                    style: TextStyle(color: context.caption, decoration: TextDecoration.lineThrough, fontSize: 10),
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
                  padding: EdgeInsets.all(6),
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
      {'name': 'Avatar Frames', 'price': 300, 'icon': '🖼️'},
      {'name': 'Avatar Backgrounds', 'price': 250, 'icon': '🌌'},
      {'name': 'Entry Effects', 'price': 180, 'icon': '⚡'},
      {'name': 'Gift Effects', 'price': 400, 'icon': '🎁'},
      {'name': 'Chat Bubbles', 'price': 220, 'icon': '💬'},
      {'name': 'Badges', 'price': 160, 'icon': '🏅'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_bag_rounded, color: context.primaryColor, size: 18),
                SizedBox(width: 6),
                Text(
                  'POPULAR COSMETICS',
                  style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
                ),
              ],
            ),
            Text(
              'View All',
              style: GoogleFonts.poppins(color: context.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(height: 12),
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
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.secondaryBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(color: context.secondaryBackgroundColor, borderRadius: BorderRadius.circular(10)),
                        child: Text(item['icon'] as String, style: TextStyle(fontSize: 14)),
                      ),
                      Text(
                        '🪙 ${item['price']}',
                        style: GoogleFonts.poppins(color: context.accentGold, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    item['name'] as String,
                    style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
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
                          backgroundColor: Color(0xFFEF4444).withOpacity(0.9),
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                          mainButton: TextButton(
                            child: Text('Top Up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      padding: EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: context.primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.primaryColor.withOpacity(0.2)),
                      ),
                      child: Center(
                        child: Text(
                          'Unlock',
                          style: GoogleFonts.poppins(color: context.primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
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
