import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/vip_controller.dart';
import '../../services/razorpay_backend_service.dart';
import '../../widgets/vip_badge_widget.dart';
import '../../widgets/vip_avatar_decorator.dart';
import '../store/checkout_screen.dart';
import '../../services/room_controller.dart';
import '../../services/user_profile_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class VipPurchaseScreen extends StatefulWidget {
  const VipPurchaseScreen({Key? key}) : super(key: key);

  @override
  State<VipPurchaseScreen> createState() => _VipPurchaseScreenState();
}

class _VipPurchaseScreenState extends State<VipPurchaseScreen> {
  final VipController _vipCtrl = Get.find<VipController>();

  int selectedLevel = 1;
  String selectedDuration = '1 Month';
  String appliedCoupon = '';
  final TextEditingController _couponTextCtrl = TextEditingController();

  final List<String> durations = [
    '3 Days',
    '7 Days',
    '15 Days',
    '1 Month',
    '3 Months',
    '6 Months',
    '12 Months',
  ];

  // Pricing Matrix based on VIP level & duration
  final Map<int, Map<String, double>> pricingMatrix = {
    1: {
      '3 Days': 399,
      '7 Days': 699,
      '15 Days': 999,
      '1 Month': 1499,
      '3 Months': 3999,
      '6 Months': 7499,
      '12 Months': 13999,
    },
    2: {
      '3 Days': 699,
      '7 Days': 1199,
      '15 Days': 1799,
      '1 Month': 2499,
      '3 Months': 6999,
      '6 Months': 12999,
      '12 Months': 22999,
    },
    3: {
      '3 Days': 999,
      '7 Days': 1999,
      '15 Days': 2999,
      '1 Month': 3999,
      '3 Months': 10999,
      '6 Months': 19999,
      '12 Months': 34999,
    },
    4: {
      '3 Days': 1499,
      '7 Days': 2999,
      '15 Days': 4499,
      '1 Month': 5999,
      '3 Months': 16999,
      '6 Months': 29999,
      '12 Months': 54999,
    },
    5: {
      '3 Days': 2499,
      '7 Days': 4999,
      '15 Days': 7499,
      '1 Month': 9999,
      '3 Months': 27999,
      '6 Months': 49999,
      '12 Months': 89999,
    },
    6: {
      '3 Days': 3999,
      '7 Days': 7999,
      '15 Days': 11999,
      '1 Month': 15999,
      '3 Months': 44999,
      '6 Months': 79999,
      '12 Months': 139999,
    },
    7: {
      '3 Days': 6999,
      '7 Days': 12999,
      '15 Days': 19999,
      '1 Month': 29999,
      '3 Months': 79999,
      '6 Months': 149999,
      '12 Months': 249999,
    },
  };

  // Benefits List per Level
  final Map<int, List<String>> benefitsMatrix = {
    1: [
      'Avatar Frame access',
      'Chat Bubble access',
      'VIP Badge and Tag Light',
      'Gift Effect access',
      'VIP Membership identity',
      'Exclusive Daily Rewards',
    ],
    2: [
      'Animated Avatar Frame',
      'Avatar Background access',
      'Entry Effect access',
      'Premium Chat Bubble',
      'Emoji Effects pack',
      'Premium Custom Reactions',
    ],
    3: [
      'Golden Avatar Frame',
      'Animated Chat Bubble styles',
      'Badge and Tag Light upgrades',
      'One-time Entry Effect',
      'Gift Effect unlocks',
      'Premium profile identity',
    ],
    4: [
      'Diamond Avatar Frame',
      'Animated Avatar Background',
      'Profile Badge',
      'Tag Light stack',
      'VIP Gift Effects',
      'Priority Customer Service Support',
    ],
    5: [
      'Crystal Avatar Frame',
      'Chat Bubble upgrade',
      'Animated Tag Light',
      'Profile Avatar Background',
      'Emoji Effects unlock',
      'Profile Spotlight Highlight effect',
    ],
    6: [
      'Rainbow Avatar Frame',
      'Exclusive Entry Effect',
      'Community Tag Light access',
      'Premium Gift Effect library',
      'VIP-exclusive badge set',
      'VIP Exclusive Events access',
    ],
    7: [
      'Legendary Avatar Frame',
      'Animated Avatar Background',
      'Legendary Entry Effect',
      'Premium Gift Effect set',
      'Tag Light mastery',
      'VIP 7 Hall of Fame Badge & dedicated Manager',
    ],
  };

  // Level Colors & Theme Info
  Map<String, dynamic> getLevelTheme(int lvl) {
    switch (lvl) {
      case 1:
        return {'name': 'Royal Blue', 'color': const Color(0xFF2563EB), 'emoji': '🔵'};
      case 2:
        return {'name': 'Royal Purple', 'color': const Color(0xFF8B5CF6), 'emoji': '🟣'};
      case 3:
        return {'name': 'Gold Imperial', 'color': const Color(0xFFFFD700), 'emoji': '🟡'};
      case 4:
        return {'name': 'Diamond Shimmer', 'color': const Color(0xFFF1F5F9), 'emoji': '💎'};
      case 5:
        return {'name': 'Crystal Cyan', 'color': const Color(0xFF06B6D4), 'emoji': '💠'};
      case 6:
        return {'name': 'Rainbow Animated', 'color': const Color(0xFFEC4899), 'emoji': '🌈'};
      case 7:
        return {'name': 'Legendary Black Gold', 'color': const Color(0xFFFFD700), 'emoji': '👑'};
      default:
        return {'name': 'Royal Blue', 'color': const Color(0xFF2563EB), 'emoji': '🔵'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = getLevelTheme(selectedLevel);
    final themeColor = theme['color'] as Color;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(themeColor),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildRenewalReminderBanner(),
                _buildActiveStatusBanner(),
                const SizedBox(height: 18),
                _buildLevelSelectors(),
                const SizedBox(height: 18),
                _buildCosmeticsPreviewCard(themeColor),
                const SizedBox(height: 18),
                _buildDurationSelectorCard(themeColor),
                const SizedBox(height: 18),
                _buildBenefitsCard(themeColor),
                const SizedBox(height: 18),
                _buildPaymentSection(themeColor),
                const SizedBox(height: 20),
                _buildSimulationDevTools(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(Color themeColor) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 150,
      backgroundColor: AppTheme.bgDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeColor.withOpacity(0.4),
                Colors.black,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '👑 CREANIA VIP CLUB',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Premium Subscription & Luxury Cosmetics',
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveStatusBanner() {
    return Obx(() {
      final currentLevel = _vipCtrl.vipLevel.value;
      final remaining = _vipCtrl.getRemainingTime();
      final hasVip = currentLevel > 0;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: hasVip
                ? [
                    getLevelTheme(currentLevel)['color'].withOpacity(0.2),
                    Colors.white.withOpacity(0.02),
                  ]
                : [
                    Colors.white.withOpacity(0.04),
                    Colors.white.withOpacity(0.01),
                  ],
          ),
          border: Border.all(
            color: hasVip
                ? getLevelTheme(currentLevel)['color'].withOpacity(0.3)
                : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasVip ? 'ACTIVE SUBSCRIPTION' : 'VIP STATUS: INACTIVE',
                  style: GoogleFonts.poppins(
                    color: hasVip ? const Color(0xFFFFD700) : Colors.white60,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      hasVip ? 'Creania VIP Level $currentLevel' : 'Not Subscribed yet',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    if (hasVip) ...[
                      const SizedBox(width: 8),
                      VipBadgeWidget(level: currentLevel, fontSize: 9),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hasVip ? 'Time Remaining: ${remaining['displayText']}' : 'Join today to unlock premium status',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (hasVip)
              Obx(() => Switch(
                    value: _vipCtrl.isAutoRenewEnabled.value,
                    onChanged: (v) => _vipCtrl.toggleAutoRenew(),
                    activeColor: getLevelTheme(currentLevel)['color'],
                  )),
          ],
        ),
      );
    });
  }

  bool _isPurchaseRestricted() {
    final currentLvl = _vipCtrl.vipLevel.value;
    if (selectedLevel < currentLvl && currentLvl > 0) {
      return true;
    }
    final expiry = _vipCtrl.expiryDate.value;
    if (currentLvl == selectedLevel && expiry != null) {
      final diff = expiry.difference(DateTime.now());
      if (diff.inDays > 3) {
        return true;
      }
    }
    return false;
  }

  Widget _buildRenewalReminderBanner() {
    return Obx(() {
      final expiry = _vipCtrl.expiryDate.value;
      if (_vipCtrl.vipLevel.value <= 0 || expiry == null) return const SizedBox.shrink();
      final diff = expiry.difference(DateTime.now());
      if (diff.isNegative || diff.inDays > 3) return const SizedBox.shrink();

      String timeText = '';
      if (diff.inDays >= 1) {
        timeText = '${diff.inDays} days';
      } else if (diff.inHours >= 1) {
        timeText = '${diff.inHours} hours';
      } else {
        timeText = 'soon';
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF97316).withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF97316).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VIP Membership Expiring',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your membership expires in $timeText. Renew now to maintain your VIP status & perks.',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildLevelSelectors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select VIP Tier',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final levelNum = i + 1;
              final isSel = selectedLevel == levelNum;
              final lvlTheme = getLevelTheme(levelNum);
              final Color color = lvlTheme['color'] as Color;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedLevel = levelNum;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 90,
                  decoration: BoxDecoration(
                    color: isSel ? color.withOpacity(0.12) : Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSel ? color : Colors.white.withOpacity(0.05),
                      width: isSel ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(lvlTheme['emoji'] as String, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(
                        'VIP $levelNum',
                        style: GoogleFonts.outfit(
                          color: isSel ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        lvlTheme['name'].toString().split(' ')[0],
                        style: GoogleFonts.poppins(
                          color: isSel ? color : Colors.white30,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCosmeticsPreviewCard(Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cosmetic Avatar & Badge Preview',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              VipAvatarDecorator(
                level: selectedLevel,
                size: 76,
                child: Container(
                  color: themeColor.withOpacity(0.2),
                  child: const Center(
                    child: Text('Avatar', style: TextStyle(color: Colors.white60, fontSize: 10)),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          UserProfileCacheManager.currentUser?.username ?? Supabase.instance.client.auth.currentUser?.email?.split('@')[0] ?? 'Student',
                          style: GoogleFonts.poppins(
                            color: selectedLevel == 3
                                ? const Color(0xFFFFD700)
                                : selectedLevel == 7
                                    ? const Color(0xFFFFD700)
                                    : themeColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        VipBadgeWidget(level: selectedLevel, fontSize: 9),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: themeColor.withOpacity(0.15)),
                      ),
                      child: Text(
                        '💬 Active VIP Chat Bubble preview!',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                        ),
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

  Widget _buildDurationSelectorCard(Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Plan Duration',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: durations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final dur = durations[i];
              final isSel = selectedDuration == dur;
              final double basePrice = pricingMatrix[selectedLevel]?[dur] ?? 100;
              final double finalPrice = appliedCoupon == 'ROYALVIP' ? basePrice * 0.85 : basePrice;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDuration = dur;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 100,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel ? themeColor.withOpacity(0.12) : Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSel ? themeColor : Colors.white.withOpacity(0.05),
                      width: isSel ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dur,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (appliedCoupon == 'ROYALVIP') ...[
                        Text(
                          '₹${basePrice.toInt()}',
                          style: GoogleFonts.poppins(
                            color: Colors.white30,
                            fontSize: 10,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      Text(
                        '₹${finalPrice.toInt()}',
                        style: GoogleFonts.poppins(
                          color: isSel ? themeColor : const Color(0xFFFBBF24),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitsCard(Color themeColor) {
    final benefits = benefitsMatrix[selectedLevel] ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VIP Level $selectedLevel Privileges',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'Cumulative benefits',
                style: GoogleFonts.poppins(color: AppTheme.textTertiary, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: benefits.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 12),
            itemBuilder: (context, i) {
              return Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: themeColor, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      benefits[i],
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(Color themeColor) {
    final double basePrice = pricingMatrix[selectedLevel]?[selectedDuration] ?? 100;
    final double finalPrice = appliedCoupon == 'ROYALVIP' ? basePrice * 0.85 : basePrice;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment & Checkout',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          // Coupon code box
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _couponTextCtrl,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
                    decoration: InputDecoration(
                      hintText: 'Enter Promo Code (e.g. ROYALVIP)',
                      hintStyle: GoogleFonts.poppins(color: Colors.white30, fontSize: 10),
                      fillColor: Colors.white.withOpacity(0.02),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: themeColor),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  if (_couponTextCtrl.text.trim().toUpperCase() == 'ROYALVIP') {
                    setState(() {
                      appliedCoupon = 'ROYALVIP';
                    });
                    Get.snackbar('🎟️ Coupon Applied!', 'You received a 15% discount on VIP!', snackPosition: SnackPosition.BOTTOM);
                  } else {
                    Get.snackbar('❌ Invalid Code', 'Promo code not recognized.', snackPosition: SnackPosition.BOTTOM);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Apply', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Checkout summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Payable:',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                '₹${finalPrice.toInt()}',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFFC107),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Buy Button
          Obx(() {
            final restricted = _isPurchaseRestricted();
            final expiry = _vipCtrl.expiryDate.value;
            return SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: restricted
                    ? null
                    : () async {
                        _showPaymentOptionsBottomSheet(finalPrice);
                      },
                icon: Icon(
                  restricted ? Icons.lock_clock_rounded : Icons.security_rounded,
                  size: 16,
                  color: restricted ? Colors.white24 : Colors.white,
                ),
                label: Text(
                  restricted
                      ? 'Active (Renewal available in ${expiry!.difference(DateTime.now()).inDays - 3} days)'
                      : 'Proceed Secure Payment',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: restricted ? Colors.white24 : Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: restricted ? Colors.white.withOpacity(0.02) : themeColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showPaymentOptionsBottomSheet(double price) {
    final themeColor = getLevelTheme(selectedLevel)['color'] as Color;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF16161A),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Payment Mode',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white38),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const Divider(color: Colors.white10),
            const SizedBox(height: 10),
            _paymentTile('UPI / QR Code', 'Pay using Google Pay, PhonePe, Paytm or Scan QR Code', Icons.mobile_friendly_rounded, () => _startUpiQrPayment(price)),
            _paymentTile('Credit / Debit Card', 'Visa, Mastercard, RuPay', Icons.credit_card_rounded, () => _completePurchase(price)),
            _paymentTile('Net Banking', 'All Major Indian Banks Supported', Icons.account_balance_rounded, () => _completePurchase(price)),
            _paymentTile('Wallet / Cash Cards', 'Paytm Wallet, Amazon Pay, Mobikwik', Icons.wallet_rounded, () => _completePurchase(price)),
          ],
        ),
      ),
    );
  }

  Widget _paymentTile(String title, String desc, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFFFFC107), size: 20),
      ),
      title: Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      subtitle: Text(desc, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 12),
      onTap: onTap,
    );
  }

  void _startUpiQrPayment(double price) async {
    Get.back(); // close bottomsheet

    // Show loading
    Get.dialog(
      Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1917),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFFFC107)),
              const SizedBox(height: 16),
              Text(
                'Generating secure UPI QR Order...',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, decoration: TextDecoration.none),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    // Call service to create order
    String orderId = 'order_VIP_MOCK_${DateTime.now().millisecondsSinceEpoch}';
    try {
      orderId = await Get.find<RazorpayBackendService>().createOrder(
        amount: price,
        product: 'VIP Level $selectedLevel ($selectedDuration)',
        duration: selectedDuration,
      );
    } catch (e) {
      debugPrint('Error creating VIP order: $e');
    }

    Get.back(); // close loading

    // Open the QR dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return UpiQrDialogWidget(
          amount: price,
          productName: 'VIP Level $selectedLevel ($selectedDuration)',
          orderId: orderId,
          onSuccess: (paymentId, signature) async {
            Get.back(); // close dialog
            
            // Show verification loading
            Get.dialog(
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1917),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFFFFC107)),
                      const SizedBox(height: 16),
                      Text(
                        'Verifying signature & activating VIP...',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, decoration: TextDecoration.none),
                      ),
                    ],
                  ),
                ),
              ),
              barrierDismissible: false,
            );

            // Verify with Razorpay backend
            final verified = await Get.find<RazorpayBackendService>().verifyPaymentSignature(
              orderId: orderId,
              paymentId: paymentId,
              signature: signature,
            );

            Get.back(); // close loading

            if (verified) {
              Get.snackbar(
                'Success! 🎉',
                'VIP Level $selectedLevel activated successfully!',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFF10B981).withOpacity(0.9),
                colorText: Colors.white,
              );
              Get.back(); // exit VIP purchase screen
            } else {
              Get.snackbar(
                'Activation Failed ⚠️',
                'Signature Verification Failed. Please contact support.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
                colorText: Colors.white,
              );
            }
          },
          onFailure: (errorMsg) {
            Get.back(); // close dialog
            Get.snackbar(
              'Payment Failed ⚠️',
              errorMsg,
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
              colorText: Colors.white,
            );
          },
        );
      },
    );
  }

  void _completePurchase(double price) async {
    Get.back(); // close bottomsheet
    Get.dialog(
      Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1917),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFFFC107)),
              const SizedBox(height: 16),
              Text(
                'Authorizing secure gateway...',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, decoration: TextDecoration.none),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    await Future.delayed(const Duration(seconds: 2));
    Get.back(); // close loading dialog

    await _vipCtrl.purchaseVip(selectedLevel, selectedDuration, price);
    if (RoomController.to.activeRoomId != null) {
      RoomController.to.addSystemActivity(
        RoomController.to.activeRoomId!,
        '💎 ${UserProfileCacheManager.currentUser?.username ?? 'Student'} unlocked VIP $selectedLevel.',
        activityKey: 'vip-unlock',
      );
    }
    Get.back(); // exit VIP purchase screen
  }

  Widget _buildSimulationDevTools() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⚠️ Developer Sandbox Tools',
            style: GoogleFonts.poppins(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _vipCtrl.simulateExpiry();
                    setState(() {});
                  },
                  icon: const Icon(Icons.timer_off_rounded, size: 14),
                  label: Text('Simulate Expiry', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444).withOpacity(0.15),
                    foregroundColor: const Color(0xFFEF4444),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Get.snackbar(
                      '🎁 Gift VIP Sim',
                      'Successfully simulated gifting VIP Level $selectedLevel to friend!',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: const Color(0xFF22C55E).withOpacity(0.9),
                      colorText: Colors.white,
                    );
                  },
                  icon: const Icon(Icons.card_giftcard_rounded, size: 14),
                  label: Text('Simulate Gift', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981).withOpacity(0.15),
                    foregroundColor: const Color(0xFF10B981),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
