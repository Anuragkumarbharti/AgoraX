import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:creania/core/theme.dart';
import '../../services/memberships/vip_controller.dart';
import '../../services/store/razorpay_backend_service.dart';
import '../../widgets/memberships/vip_badge_widget.dart';
import '../../widgets/memberships/vip_avatar_decorator.dart';
import '../store/checkout_screen.dart';
import '../../services/room/room_controller.dart';
import '../../services/user/user_profile_cache_manager.dart';
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

  @override
  void initState() {
    super.initState();
    if (_vipCtrl.vipLevel.value > 2) {
      selectedLevel = 2;
    } else {
      selectedLevel = _vipCtrl.vipLevel.value.clamp(1, 2);
    }
  }

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
  };

  // Level Colors & Theme Info
  Map<String, dynamic> getLevelTheme(int lvl) {
    switch (lvl) {
      case 1:
        return {'name': 'Royal Blue', 'color': Color(0xFF2563EB), 'emoji': '🔵'};
      case 2:
        return {'name': 'Royal Purple', 'color': Color(0xFF8B5CF6), 'emoji': '🟣'};
      case 3:
        return {'name': 'Gold Imperial', 'color': Color(0xFFFFD700), 'emoji': '🟡'};
      case 4:
        return {'name': 'Diamond Shimmer', 'color': Color(0xFFF1F5F9), 'emoji': '💎'};
      case 5:
        return {'name': 'Crystal Cyan', 'color': Color(0xFF06B6D4), 'emoji': '💠'};
      case 6:
        return {'name': 'Rainbow Animated', 'color': Color(0xFFEC4899), 'emoji': '🌈'};
      case 7:
        return {'name': 'Legendary Black Gold', 'color': Color(0xFFFFD700), 'emoji': '👑'};
      default:
        return {'name': 'Royal Blue', 'color': Color(0xFF2563EB), 'emoji': '🔵'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = getLevelTheme(selectedLevel);
    final themeColor = theme['color'] as Color;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(themeColor),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildRenewalReminderBanner(),
                _buildActiveStatusBanner(),
                SizedBox(height: 18),
                _buildLevelSelectors(),
                SizedBox(height: 18),
                if (selectedLevel <= 2) ...[
                  _buildCosmeticsPreviewCard(themeColor),
                  SizedBox(height: 18),
                  _buildDurationSelectorCard(themeColor),
                  SizedBox(height: 18),
                  _buildBenefitsCard(themeColor),
                  SizedBox(height: 18),
                  _buildPaymentSection(themeColor),
                ] else ...[
                  _buildComingSoonWidget(themeColor),
                ],
                SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonWidget(Color themeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeColor.withOpacity(0.2), width: 1.5),
        boxShadow: context.smallShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_outlined,
              size: 52,
              color: themeColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Coming Soon',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We are currently designing premium benefits and custom cosmetics for this VIP tier. Stay tuned!',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: context.textSecondary,
              height: 1.6,
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
      backgroundColor: context.scaffoldBackgroundColor,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.32),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
          onPressed: () => Get.back(),
        ),
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
              SizedBox(height: 4),
              Text(
                'Premium Subscription & Luxury Cosmetics',
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: 10,
                ),
              ),
              SizedBox(height: 20),
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
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasVip
                ? getLevelTheme(currentLevel)['color'].withOpacity(0.3)
                : context.borderColor,
          ),
          boxShadow: context.smallShadow,
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasVip ? 'ACTIVE SUBSCRIPTION' : 'VIP STATUS: INACTIVE',
                  style: GoogleFonts.poppins(
                    color: hasVip ? context.accentGold : context.caption,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      hasVip ? 'Creaniaa VIP Level $currentLevel' : 'Not Subscribed yet',
                      style: GoogleFonts.outfit(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    if (hasVip) ...[
                      SizedBox(width: 8),
                      VipBadgeWidget(level: currentLevel, fontSize: 9),
                    ],
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  hasVip ? 'Time Remaining: ${remaining['displayText']}' : 'Join today to unlock premium status',
                  style: GoogleFonts.poppins(
                    color: context.textSecondary,
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
    return false;
  }

  Widget _buildRenewalReminderBanner() {
    return Obx(() {
      final expiry = _vipCtrl.expiryDate.value;
      if (_vipCtrl.vipLevel.value <= 0 || expiry == null) return SizedBox.shrink();
      final diff = expiry.difference(DateTime.now());
      if (diff.isNegative || diff.inDays > 3) return SizedBox.shrink();

      String timeText = '';
      if (diff.inDays >= 1) {
        timeText = '${diff.inDays} days';
      } else if (diff.inHours >= 1) {
        timeText = '${diff.inHours} hours';
      } else {
        timeText = 'soon';
      }

      return Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFFF97316).withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(0xFFF97316).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316), size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VIP Membership Expiring',
                    style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Your membership expires in $timeText. Renew now to maintain your VIP status & perks.',
                    style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 10),
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
    final currentLvl = _vipCtrl.vipLevel.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select VIP Tier',
          style: GoogleFonts.poppins(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 2,
            separatorBuilder: (_, __) => SizedBox(width: 8),
            itemBuilder: (context, i) {
              final levelNum = i + 1;
              final isSel = selectedLevel == levelNum;
              final isLocked = levelNum < currentLvl && currentLvl > 0;
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
                    color: isSel
                        ? color.withOpacity(0.12)
                        : (isLocked ? Colors.black38 : context.surfaceColor),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSel ? color : context.borderColor,
                      width: isSel ? 2 : 1,
                    ),
                    boxShadow: isSel ? null : context.smallShadow,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      isLocked
                          ? Icon(Icons.lock_rounded, color: Colors.white38, size: 22)
                          : Text(lvlTheme['emoji'] as String, style: TextStyle(fontSize: 22)),
                      SizedBox(height: 4),
                      Text(
                        'VIP $levelNum',
                        style: GoogleFonts.outfit(
                          color: isLocked
                              ? Colors.white38
                              : (isSel ? color : context.textSecondary),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        isLocked ? 'Active: VIP $currentLvl' : lvlTheme['name'].toString().split(' ')[0],
                        style: GoogleFonts.poppins(
                          color: isLocked ? Colors.redAccent.withOpacity(0.7) : (isSel ? color : context.caption),
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: context.smallShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cosmetic Avatar & Badge Preview',
            style: GoogleFonts.poppins(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              VipAvatarDecorator(
                level: selectedLevel,
                size: 76,
                child: Container(
                  color: themeColor.withOpacity(0.2),
                  child: Center(
                    child: Text('Avatar', style: TextStyle(color: context.textSecondary, fontSize: 10)),
                  ),
                ),
              ),
              SizedBox(width: 18),
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
                                ? context.accentGold
                                : selectedLevel == 7
                                    ? context.accentGold
                                    : themeColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        VipBadgeWidget(level: selectedLevel, fontSize: 9),
                      ],
                    ),
                    SizedBox(height: 6),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: themeColor.withOpacity(0.15)),
                      ),
                      child: Text(
                        '💬 Active VIP Chat Bubble preview!',
                        style: GoogleFonts.poppins(
                          color: context.textPrimary,
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
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: durations.length,
            separatorBuilder: (_, __) => SizedBox(width: 8),
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
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel ? themeColor.withOpacity(0.12) : context.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSel ? themeColor : context.borderColor,
                      width: isSel ? 2 : 1,
                    ),
                    boxShadow: isSel ? null : context.smallShadow,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dur,
                        style: GoogleFonts.outfit(
                          color: isSel ? themeColor : context.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      if (appliedCoupon == 'ROYALVIP') ...[
                        Text(
                          '₹${basePrice.toInt()}',
                          style: GoogleFonts.poppins(
                            color: context.caption,
                            fontSize: 10,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      Text(
                        '₹${finalPrice.toInt()}',
                        style: GoogleFonts.poppins(
                          color: isSel ? themeColor : context.accentOrange,
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: context.smallShadow,
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
                  color: context.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'Cumulative benefits',
                style: GoogleFonts.poppins(color: context.caption, fontSize: 9),
              ),
            ],
          ),
          SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: benefits.length,
            separatorBuilder: (_, __) => Divider(color: context.borderColor, height: 12),
            itemBuilder: (context, i) {
              return Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: themeColor, size: 16),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      benefits[i],
                      style: GoogleFonts.poppins(
                        color: context.textSecondary,
                        fontSize: 11.5,
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: context.smallShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment & Checkout',
            style: GoogleFonts.poppins(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 12),
          // Coupon code box
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _couponTextCtrl,
                    style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 11),
                    decoration: InputDecoration(
                      hintText: 'Enter Promo Code (e.g. ROYALVIP)',
                      hintStyle: GoogleFonts.poppins(color: context.placeholder, fontSize: 10),
                      fillColor: context.scaffoldBackgroundColor,
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: themeColor),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
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
          SizedBox(height: 16),
          // Checkout summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Payable:',
                style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                '₹${finalPrice.toInt()}',
                style: GoogleFonts.poppins(
                  color: context.accentGold,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Buy Button
          Obx(() {
            final restricted = _isPurchaseRestricted();
            final currentLvl = _vipCtrl.vipLevel.value;
            final isSameLevel = selectedLevel == currentLvl && currentLvl > 0;

            String buttonText = 'Proceed Secure Payment';
            if (restricted) {
              buttonText = 'You already have VIP $currentLvl';
            } else if (isSameLevel) {
              buttonText = 'Renew VIP $selectedLevel • ₹${finalPrice.toInt()}';
            } else if (currentLvl > 0 && selectedLevel > currentLvl) {
              buttonText = 'Upgrade to VIP $selectedLevel • ₹${finalPrice.toInt()}';
            } else {
              buttonText = 'Unlock VIP $selectedLevel • ₹${finalPrice.toInt()}';
            }

            return SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: restricted
                    ? null
                    : () {
                        Get.to(() => CheckoutScreen(
                          productName: 'VIP Level $selectedLevel',
                          category: 'VIP',
                          basePrice: finalPrice,
                          duration: selectedDuration == '1 Month' ? '30 Days' : selectedDuration,
                        ));
                      },
                icon: Icon(
                  restricted ? Icons.lock_rounded : Icons.security_rounded,
                  size: 16,
                  color: restricted ? Colors.white24 : Colors.white,
                ),
                label: Text(
                  buttonText,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: restricted ? Colors.white24 : Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: restricted ? Colors.grey.withOpacity(0.3) : themeColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

}
