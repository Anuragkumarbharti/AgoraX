import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:creania/core/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/store/store_controller.dart';
import '../../services/memberships/vip_controller.dart';
import '../../services/memberships/novel_controller.dart';
import '../../widgets/memberships/vip_badge_widget.dart';
import '../../widgets/memberships/novel_badge_widget.dart';
import '../../widgets/memberships/vip_avatar_decorator.dart';
import '../../widgets/memberships/novel_avatar_decorator.dart';
import './checkout_screen.dart';

class VipPlan {
  final int level;
  final String name;
  final double basePriceInr;
  final List<String> benefits;
  VipPlan({required this.level, required this.name, required this.basePriceInr, required this.benefits});
  factory VipPlan.fromJson(Map<String, dynamic> json) => VipPlan(
    level: json['level'] ?? 1,
    name: json['name'] ?? '',
    basePriceInr: (json['base_price_inr'] as num?)?.toDouble() ?? 0.0,
    benefits: List<String>.from(json['benefits'] ?? []),
  );
}

class NovelPlan {
  final int level;
  final String name;
  final double basePriceInr;
  final List<String> benefits;
  NovelPlan({required this.level, required this.name, required this.basePriceInr, required this.benefits});
  factory NovelPlan.fromJson(Map<String, dynamic> json) => NovelPlan(
    level: json['level'] ?? 1,
    name: json['name'] ?? '',
    basePriceInr: (json['base_price_inr'] as num?)?.toDouble() ?? 0.0,
    benefits: List<String>.from(json['benefits'] ?? []),
  );
}

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

  List<VipPlan> _vipPlans = [];
  List<NovelPlan> _novelPlans = [];
  bool _isLoadingPlans = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: widget.initialIndex);
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    try {
      final vipRes = await Supabase.instance.client
          .from('vip_plans')
          .select()
          .order('level', ascending: true);
      final novelRes = await Supabase.instance.client
          .from('novel_plans')
          .select()
          .order('level', ascending: true);
      
      setState(() {
        _vipPlans = (vipRes as List).map((e) => VipPlan.fromJson(e)).toList();
        _novelPlans = (novelRes as List).map((e) => NovelPlan.fromJson(e)).toList();
        
        if (_vipPlans.isNotEmpty) {
          if (_vipCtrl.vipLevel.value > _vipPlans.length) {
            _selectedVipLevel = _vipPlans.length;
          } else {
            _selectedVipLevel = _vipCtrl.vipLevel.value.clamp(1, _vipPlans.length);
          }
        }
        if (_novelPlans.isNotEmpty) {
          if (_novelCtrl.novelLevel.value > _novelPlans.length) {
            _selectedNovelLevel = _novelPlans.length;
          } else {
            _selectedNovelLevel = _novelCtrl.novelLevel.value.clamp(1, _novelPlans.length);
          }
        }
        _isLoadingPlans = false;
      });
    } catch (e) {
      debugPrint('Error fetching plans: $e');
      setState(() => _isLoadingPlans = false);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getVipTheme(int lvl) {
    switch (lvl) {
      case 1: return {'name': 'Royal Blue', 'color': Color(0xFF2563EB), 'icon': '👑'};
      case 2: return {'name': 'Amethyst Purple', 'color': Color(0xFF8B5CF6), 'icon': '👑'};
      case 3: return {'name': 'Gold Imperial', 'color': Color(0xFFFFD700), 'icon': '👑'};
      case 4: return {'name': 'Diamond Shimmer', 'color': Color(0xFFF1F5F9), 'icon': '👑'};
      case 5: return {'name': 'Crystal Cyan', 'color': Color(0xFF06B6D4), 'icon': '👑'};
      case 6: return {'name': 'Rainbow Animated', 'color': Color(0xFFEC4899), 'icon': '👑'};
      case 7: return {'name': 'Legendary Black Gold', 'color': Color(0xFFFFD700), 'icon': '👑'};
      default: return {'name': 'Royal Blue', 'color': Color(0xFF2563EB), 'icon': '👑'};
    }
  }

  Map<String, dynamic> _getNovelTheme(int lvl) {
    switch (lvl) {
      case 1: return {'name': 'Astral Blue', 'color': Color(0xFF3B82F6), 'icon': '📖'};
      case 2: return {'name': 'Dragon Purple', 'color': Color(0xFF8B5CF6), 'icon': '📖'};
      case 3: return {'name': 'Eternal Gold', 'color': Color(0xFFFFD700), 'icon': '📖'};
      case 4: return {'name': 'Crimson Fury', 'color': Color(0xFFEF4444), 'icon': '📖'};
      case 5: return {'name': 'Sol Flame', 'color': Color(0xFFF97316), 'icon': '📖'};
      case 6: return {'name': 'Void Spark', 'color': Color(0xFF06B6D4), 'icon': '📖'};
      case 7: return {'name': 'Celestial Monarch', 'color': Color(0xFFFFD700), 'icon': '📖'};
      default: return {'name': 'Astral Blue', 'color': Color(0xFF3B82F6), 'icon': '📖'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
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
                    color: Color(0xFF8B5CF6).withOpacity(0.08),
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
                    color: Color(0xFFD946EF).withOpacity(0.08),
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
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 18),
            onPressed: () => Get.back(),
          ),
          Text(
            'MEMBERSHIPS',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 2,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 48,
      decoration: BoxDecoration(
        color: context.secondaryBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Color(0xFF8B5CFF), Color(0xFFFF4D8D)],
          ),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: context.caption,
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
    if (_isLoadingPlans) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = _getVipTheme(_selectedVipLevel);
    final Color color = theme['color'] as Color;

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVipLevelSlider(color),
          SizedBox(height: 24),
          _buildLiveCosmeticsPreviewCard(color, isVip: true),
          SizedBox(height: 24),
          _buildVipBenefitsCard(color),
          SizedBox(height: 24),
          _buildDurationSelector(isVip: true),
          SizedBox(height: 24),
          _buildPurchaseButtonCard(color, isVip: true),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildNovelTab() {
    if (_isLoadingPlans) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = _getNovelTheme(_selectedNovelLevel);
    final Color color = theme['color'] as Color;

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNovelLevelSlider(color),
          SizedBox(height: 24),
          _buildLiveCosmeticsPreviewCard(color, isVip: false),
          SizedBox(height: 24),
          _buildNovelSpecsCard(color),
          SizedBox(height: 24),
          _buildDurationSelector(isVip: false),
          SizedBox(height: 24),
          _buildPurchaseButtonCard(color, isVip: false),
          SizedBox(height: 40),
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
          style: GoogleFonts.outfit(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _vipPlans.isNotEmpty ? _vipPlans.length.clamp(1, 2) : 2,
            itemBuilder: (context, index) {
              final lvl = index + 1;
              final isSel = _selectedVipLevel == lvl;
              final t = _getVipTheme(lvl);
              return GestureDetector(
                onTap: () => setState(() => _selectedVipLevel = lvl),
                child: Container(
                  width: 90,
                  margin: EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isSel ? color.withOpacity(0.12) : context.secondaryBackgroundColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel ? color : context.borderColor,
                      width: isSel ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('VIP $lvl', style: GoogleFonts.poppins(color: isSel ? Colors.white : context.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text(t['name'].toString().split(' ')[0], style: GoogleFonts.poppins(color: isSel ? color : context.caption, fontSize: 8.5)),
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
          style: GoogleFonts.outfit(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 1,
            itemBuilder: (context, index) {
              final lvl = index + 1;
              final isSel = _selectedNovelLevel == lvl;
              final t = _getNovelTheme(lvl);
              return GestureDetector(
                onTap: () => setState(() => _selectedNovelLevel = lvl),
                child: Container(
                  width: 90,
                  margin: EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isSel ? color.withOpacity(0.12) : context.secondaryBackgroundColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel ? color : context.borderColor,
                      width: isSel ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Level $lvl', style: GoogleFonts.poppins(color: isSel ? Colors.white : context.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text(t['name'].toString().split(' ')[0], style: GoogleFonts.poppins(color: isSel ? color : context.caption, fontSize: 8.5)),
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
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.secondaryBackgroundColor,
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
                style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  'Animated 💫',
                  style: GoogleFonts.poppins(color: color, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              avatarDecorator,
              SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Avatar Frame',
                      style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      isVip
                          ? 'Avatar Frame, Avatar Background, Entry Effect, Gift Effect, Chat Bubble, Badge, Tag Light, and Emoji Effects.'
                          : 'Avatar Frame, Avatar Background, Entry Effect, Gift Effect, Chat Bubble, Badge, Tag Light, and Emoji Effects.',
                      style: GoogleFonts.poppins(color: context.caption, fontSize: 9.5),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: context.secondaryBackgroundColor, borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.palette_outlined, color: context.textSecondary, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Shimmer Profile Theme',
                            style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 9.5, fontWeight: FontWeight.bold),
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
    final List<String> benefits;
    if (_vipPlans.isNotEmpty && _selectedVipLevel <= _vipPlans.length) {
      benefits = _vipPlans[_selectedVipLevel - 1].benefits;
    } else {
      benefits = [
        'Animated Avatar Frame with real-time sync',
        'Premium Chat Bubble for rooms and chats',
        'Profile Avatar Background for your profile page',
        'One-time Entry Effect for room joins',
        'Badge and Tag Light identity for profile and chats',
      ];
    }

    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.secondaryBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MEMBERSHIP BENEFITS',
            style: GoogleFonts.outfit(color: context.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          SizedBox(height: 12),
          ...benefits.map((b) => Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: color, size: 14),
                SizedBox(width: 8),
                Expanded(child: Text(b, style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 11.5))),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildNovelSpecsCard(Color color) {
    final List<String> specs;
    if (_novelPlans.isNotEmpty && _selectedNovelLevel <= _novelPlans.length) {
      specs = _novelPlans[_selectedNovelLevel - 1].benefits;
    } else {
      specs = [
        'Exclusive Avatar Frame with premium loop animation',
        'Unique Avatar Background for the profile page',
        'Novel Entry Effect for one-time room entrance animation',
        'Novel Gift Effect and animated chat styling',
        'Tag Light and Emoji Effects for premium identity',
      ];
    }

    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.secondaryBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NOVEL SPECIFICATIONS',
            style: GoogleFonts.outfit(color: context.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          SizedBox(height: 12),
          ...specs.map((s) => Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: color, size: 14),
                SizedBox(width: 8),
                Expanded(child: Text(s, style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 11.5))),
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
          style: GoogleFonts.outfit(color: context.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        SizedBox(height: 12),
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
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSel ? context.primaryColor : context.secondaryBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel ? context.primaryColor : context.borderColor,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      opt,
                      style: GoogleFonts.poppins(color: isSel ? Colors.white : context.textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold),
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
    
    final double rawBasePrice;
    if (isVip) {
      rawBasePrice = _vipPlans.isNotEmpty && selectedLvl <= _vipPlans.length
          ? _vipPlans[selectedLvl - 1].basePriceInr
          : (selectedLvl <= 1 ? 99.0 : 199.0);
    } else {
      rawBasePrice = _novelPlans.isNotEmpty && selectedLvl <= _novelPlans.length
          ? _novelPlans[selectedLvl - 1].basePriceInr
          : 199.0;
    }

    double multiplier = 1.0;
    if (duration == '90 Days') multiplier = 2.6; // Save ~10%
    if (duration == '1 Year') multiplier = 9.0;  // Save ~25%
    
    final finalPrice = rawBasePrice * multiplier;

    return Obx(() {
      final int activeLvl = isVip ? _vipCtrl.vipLevel.value : _novelCtrl.novelLevel.value;
      final bool isLocked = selectedLvl < activeLvl && activeLvl > 0;
      final bool isActive = selectedLvl == activeLvl && activeLvl > 0;

      final remaining = isVip
          ? _vipCtrl.getRemainingTime()
          : _novelCtrl.getRemainingTime();

      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.borderColor),
          boxShadow: context.smallShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLocked
                      ? 'Higher Tier Active'
                      : isActive 
                          ? 'Expires in ${remaining['displayText']}' 
                          : 'Ready to unlock',
                  style: GoogleFonts.poppins(color: context.caption, fontSize: 9.5),
                ),
                Text(
                  '₹${finalPrice.toInt()}',
                  style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isLocked ? Colors.grey : color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
              onPressed: isLocked ? null : () {
                Get.to(() => CheckoutScreen(
                      productName: isVip ? 'VIP Level $selectedLvl' : 'Novel Level $selectedLvl',
                      category: isVip ? 'VIP' : 'Novel',
                      basePrice: finalPrice,
                      duration: duration,
                    ));
              },
              child: Text(
                isLocked
                    ? (isVip ? 'You already have VIP $activeLvl' : 'You already have Novel $activeLvl')
                    : isActive 
                        ? 'Renew Now' 
                        : 'Upgrade',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    });
  }
}
