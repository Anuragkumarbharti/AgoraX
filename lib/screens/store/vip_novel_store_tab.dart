import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../core/theme.dart';
import '../../services/store_controller.dart';
import '../../services/vip_controller.dart';
import '../../services/novel_controller.dart';
import '../../widgets/vip_badge_widget.dart';
import '../../widgets/novel_badge_widget.dart';
import '../../widgets/vip_avatar_decorator.dart';
import '../../widgets/novel_avatar_decorator.dart';
import 'checkout_screen.dart';

class VipNovelStoreTab extends StatefulWidget {
  final int initialIndex;
  const VipNovelStoreTab({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<VipNovelStoreTab> createState() => _VipNovelStoreTabState();
}

class _VipNovelStoreTabState extends State<VipNovelStoreTab> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final VipController _vipCtrl = Get.find<VipController>();
  final NovelController _novelCtrl = Get.find<NovelController>();

  int _selectedVipLevel = 1;
  int _selectedNovelLevel = 1;
  
  String _vipDuration = '30 Days';
  String _novelDuration = '30 Days';

  final List<double> vipBasePrices = [0, 99, 199, 399, 799, 1999, 3999, 7999];
  final List<double> novelBasePrices = [0, 199, 399, 799, 1499, 2999, 5999, 11999];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: widget.initialIndex);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getVipTheme(int lvl) {
    switch (lvl) {
      case 1: return {'name': 'Royal Blue', 'color': const Color(0xFF2563EB), 'icon': '👑'};
      case 2: return {'name': 'Amethyst Purple', 'color': const Color(0xFF8B5CF6), 'icon': '👑'};
      case 3: return {'name': 'Gold Imperial', 'color': const Color(0xFFFFD700), 'icon': '👑'};
      case 4: return {'name': 'Diamond Shimmer', 'color': const Color(0xFFF1F5F9), 'icon': '👑'};
      case 5: return {'name': 'Crystal Cyan', 'color': const Color(0xFF06B6D4), 'icon': '👑'};
      case 6: return {'name': 'Rainbow Animated', 'color': const Color(0xFFEC4899), 'icon': '👑'};
      case 7: return {'name': 'Legendary Black Gold', 'color': const Color(0xFFFFD700), 'icon': '👑'};
      default: return {'name': 'Royal Blue', 'color': const Color(0xFF2563EB), 'icon': '👑'};
    }
  }

  Map<String, dynamic> _getNovelTheme(int lvl) {
    switch (lvl) {
      case 1: return {'name': 'Astral Blue', 'color': const Color(0xFF3B82F6), 'icon': '📖'};
      case 2: return {'name': 'Dragon Purple', 'color': const Color(0xFF8B5CF6), 'icon': '📖'};
      case 3: return {'name': 'Eternal Gold', 'color': const Color(0xFFFFD700), 'icon': '📖'};
      case 4: return {'name': 'Crimson Fury', 'color': const Color(0xFFEF4444), 'icon': '📖'};
      case 5: return {'name': 'Sol Flame', 'color': const Color(0xFFF97316), 'icon': '📖'};
      case 6: return {'name': 'Void Spark', 'color': const Color(0xFF06B6D4), 'icon': '📖'};
      case 7: return {'name': 'Celestial Monarch', 'color': const Color(0xFFFFD700), 'icon': '📖'};
      default: return {'name': 'Astral Blue', 'color': const Color(0xFF3B82F6), 'icon': '📖'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070A),
      body: Stack(
        children: [
          // Background Gradient Ambient Glows
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
                    color: const Color(0xFF8B5CF6).withOpacity(0.08),
                    blurRadius: 100,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD946EF).withOpacity(0.08),
                    blurRadius: 100,
                  )
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildVipTab(),
                      _buildNovelTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            onPressed: () => Get.back(),
          ),
          Text(
            'MEMBERSHIPS',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 2,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF111115),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
          ),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
        tabs: const [
          Tab(text: '💎 VIP Club'),
          Tab(text: '📖 Novelist'),
        ],
      ),
    );
  }

  Widget _buildVipTab() {
    final theme = _getVipTheme(_selectedVipLevel);
    final Color color = theme['color'] as Color;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVipLevelSlider(color),
          const SizedBox(height: 24),
          _buildLiveCosmeticsPreviewCard(color, isVip: true),
          const SizedBox(height: 24),
          _buildVipBenefitsCard(color),
          const SizedBox(height: 24),
          _buildDurationSelector(isVip: true),
          const SizedBox(height: 24),
          _buildPurchaseButtonCard(color, isVip: true),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildNovelTab() {
    final theme = _getNovelTheme(_selectedNovelLevel);
    final Color color = theme['color'] as Color;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNovelLevelSlider(color),
          const SizedBox(height: 24),
          _buildLiveCosmeticsPreviewCard(color, isVip: false),
          const SizedBox(height: 24),
          _buildNovelSpecsCard(color),
          const SizedBox(height: 24),
          _buildDurationSelector(isVip: false),
          const SizedBox(height: 24),
          _buildPurchaseButtonCard(color, isVip: false),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildVipLevelSlider(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT VIP TIER',
          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            itemBuilder: (context, index) {
              final lvl = index + 1;
              final isSel = _selectedVipLevel == lvl;
              final t = _getVipTheme(lvl);
              return GestureDetector(
                onTap: () => setState(() => _selectedVipLevel = lvl),
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isSel ? color.withOpacity(0.12) : const Color(0xFF111115),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel ? color : Colors.white.withOpacity(0.04),
                      width: isSel ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('VIP $lvl', style: GoogleFonts.poppins(color: isSel ? Colors.white : Colors.white60, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(t['name'].toString().split(' ')[0], style: GoogleFonts.poppins(color: isSel ? color : Colors.white24, fontSize: 8.5)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNovelLevelSlider(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT NOVELIST TIER',
          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            itemBuilder: (context, index) {
              final lvl = index + 1;
              final isSel = _selectedNovelLevel == lvl;
              final t = _getNovelTheme(lvl);
              return GestureDetector(
                onTap: () => setState(() => _selectedNovelLevel = lvl),
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isSel ? color.withOpacity(0.12) : const Color(0xFF111115),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel ? color : Colors.white.withOpacity(0.04),
                      width: isSel ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Level $lvl', style: GoogleFonts.poppins(color: isSel ? Colors.white : Colors.white60, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(t['name'].toString().split(' ')[0], style: GoogleFonts.poppins(color: isSel ? color : Colors.white24, fontSize: 8.5)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLiveCosmeticsPreviewCard(Color color, {required bool isVip}) {
    final String title = isVip ? 'VIP $_selectedVipLevel Live Previews' : 'Novel $_selectedNovelLevel Live Previews';
    final dynamic avatarDecorator = isVip
        ? VipAvatarDecorator(level: _selectedVipLevel, size: 70, child: const CircleAvatar(backgroundColor: Colors.white10))
        : NovelAvatarDecorator(level: _selectedNovelLevel, size: 70, child: const CircleAvatar(backgroundColor: Colors.white10));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111115),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  'Animated 💫',
                  style: GoogleFonts.poppins(color: color, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              avatarDecorator,
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Avatar Frame',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isVip
                          ? 'Avatar Frame, Avatar Background, Entry Effect, Gift Effect, Chat Bubble, Badge, Tag Light, and Emoji Effects.'
                          : 'Avatar Frame, Avatar Background, Entry Effect, Gift Effect, Chat Bubble, Badge, Tag Light, and Emoji Effects.',
                      style: GoogleFonts.poppins(color: Colors.white30, fontSize: 9.5),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.palette_outlined, color: Colors.white70, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Shimmer Profile Theme',
                            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVipBenefitsCard(Color color) {
    final benefits = [
      'Animated Avatar Frame with real-time sync',
      'Premium Chat Bubble for rooms and chats',
      'Profile Avatar Background for your profile page',
      'One-time Entry Effect for room joins',
      'Badge and Tag Light identity for profile and chats',
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111115),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MEMBERSHIP BENEFITS',
            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          ...benefits.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: color, size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(b, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11.5))),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildNovelSpecsCard(Color color) {
    final specs = [
      'Exclusive Avatar Frame with premium loop animation',
      'Unique Avatar Background for the profile page',
      'Novel Entry Effect for one-time room entrance animation',
      'Novel Gift Effect and animated chat styling',
      'Tag Light and Emoji Effects for premium identity',
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111115),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NOVEL SPECIFICATIONS',
            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          ...specs.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: color, size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(s, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11.5))),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildDurationSelector({required bool isVip}) {
    final currentDuration = isVip ? _vipDuration : _novelDuration;
    final options = ['30 Days', '90 Days', '1 Year'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHOOSE MEMBERSHIP DURATION',
          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        Row(
          children: options.map((opt) {
            final isSel = currentDuration == opt;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isVip) {
                      _vipDuration = opt;
                    } else {
                      _novelDuration = opt;
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF1E1B4B) : const Color(0xFF111115),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.04),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      opt,
                      style: GoogleFonts.poppins(color: isSel ? Colors.white : Colors.white60, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPurchaseButtonCard(Color color, {required bool isVip}) {
    final int selectedLvl = isVip ? _selectedVipLevel : _selectedNovelLevel;
    final String duration = isVip ? _vipDuration : _novelDuration;
    final double rawBasePrice = isVip ? vipBasePrices[selectedLvl] : novelBasePrices[selectedLvl];

    double multiplier = 1.0;
    if (duration == '90 Days') multiplier = 2.6; // Save ~10%
    if (duration == '1 Year') multiplier = 9.0;  // Save ~25%
    
    final finalPrice = rawBasePrice * multiplier;

    return Obx(() {
      // Check remaining days alert banner
      final bool isActive = isVip
          ? _vipCtrl.vipLevel.value == selectedLvl
          : _novelCtrl.novelLevel.value == selectedLvl;

      final remaining = isVip
          ? _vipCtrl.getRemainingTime()
          : _novelCtrl.getRemainingTime();

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF151518),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? 'Expires in ${remaining['displayText']}' : 'Ready to unlock',
                  style: GoogleFonts.poppins(color: Colors.white30, fontSize: 9.5),
                ),
                Text(
                  '₹${finalPrice.toInt()}',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
              onPressed: () {
                Get.to(() => CheckoutScreen(
                      productName: isVip ? 'VIP Level $selectedLvl' : 'Novel Level $selectedLvl',
                      category: isVip ? 'VIP' : 'Novel',
                      basePrice: finalPrice,
                      duration: duration,
                    ));
              },
              child: Text(
                isActive ? 'Renew Now' : 'Upgrade',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    });
  }
}
