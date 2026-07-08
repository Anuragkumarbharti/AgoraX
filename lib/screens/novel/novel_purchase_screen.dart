import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/novel_controller.dart';
import '../../widgets/novel_badge_widget.dart';
import '../../widgets/novel_avatar_decorator.dart';

class NovelPurchaseScreen extends StatefulWidget {
  const NovelPurchaseScreen({Key? key}) : super(key: key);

  @override
  State<NovelPurchaseScreen> createState() => _NovelPurchaseScreenState();
}

class _NovelPurchaseScreenState extends State<NovelPurchaseScreen> {
  final NovelController _novelCtrl = Get.find<NovelController>();

  int selectedLevel = 1; // 1 to 7
  String selectedDuration = '1 Month';
  String appliedCoupon = '';
  double discountPercentage = 0.0;
  String selectedPaymentMethod = 'UPI (Google Pay)';

  final TextEditingController _couponTextCtrl = TextEditingController();
  final TextEditingController _giftUserCtrl = TextEditingController();

  final List<String> durations = [
    '3 Days',
    '7 Days',
    '15 Days',
    '1 Month',
    '3 Months',
    '6 Months',
    '12 Months',
  ];

  // Pricing Matrix based on Novel level & duration
  final Map<int, Map<String, double>> pricingMatrix = {
    1: {
      '3 Days': 999, '7 Days': 1999, '15 Days': 2999, '1 Month': 4999,
      '3 Months': 13999, '6 Months': 24999, '12 Months': 44999,
    },
    2: {
      '3 Days': 1999, '7 Days': 3999, '15 Days': 5999, '1 Month': 8999,
      '3 Months': 24999, '6 Months': 44999, '12 Months': 79999,
    },
    3: {
      '3 Days': 2999, '7 Days': 5999, '15 Days': 8999, '1 Month': 12999,
      '3 Months': 34999, '6 Months': 64999, '12 Months': 119999,
    },
    4: {
      '3 Days': 4999, '7 Days': 8999, '15 Days': 12999, '1 Month': 18999,
      '3 Months': 49999, '6 Months': 89999, '12 Months': 169999,
    },
    5: {
      '3 Days': 6999, '7 Days': 12999, '15 Days': 18999, '1 Month': 27999,
      '3 Months': 74999, '6 Months': 139999, '12 Months': 249999,
    },
    6: {
      '3 Days': 9999, '7 Days': 18999, '15 Days': 27999, '1 Month': 39999,
      '3 Months': 109999, '6 Months': 199999, '12 Months': 349999,
    },
    7: {
      '3 Days': 19999, '7 Days': 34999, '15 Days': 49999, '1 Month': 79999,
      '3 Months': 249999, '6 Months': 499999, '12 Months': 999999,
    },
  };

  // Level Names & Theme colors
  Map<String, dynamic> getLevelTheme(int lvl) {
    switch (lvl) {
      case 1:
        return {'name': 'Classic Novel', 'color': const Color(0xFF2563EB), 'emoji': '🛡️', 'benefits': [
          'Luxury Border', 'Luxury Badge', 'Luxury Mini Profile', 'Luxury Chat Bubble',
          'Luxury Avatar Ring', 'Luxury Profile Theme', 'Luxury Banner'
        ]};
      case 2:
        return {'name': 'Galaxy Novel', 'color': const Color(0xFF7C3AED), 'emoji': '🌌', 'benefits': [
          'Everything in Novel 1', 'Galaxy Entrance Animation', 'Galaxy Profile Border',
          'Galaxy Wallpaper Theme', 'Premium Name Glow', 'Galaxy Voice Room Card'
        ]};
      case 3:
        return {'name': 'Royal Palace Novel', 'color': const Color(0xFFFFD700), 'emoji': '👑', 'benefits': [
          'Everything in Novel 2', 'Royal Palace Crown', 'Gold Theme Layout',
          'Royal Entry Announcement', 'Royal Username Effect', 'Luxury Gift Sparkle Effects'
        ]};
      case 4:
        return {'name': 'Dragon Fire Novel', 'color': const Color(0xFFDC2626), 'emoji': '🔥', 'benefits': [
          'Everything in Novel 3', 'Dragon Fire animation background', 'Crimson Fire Border',
          'Dragon Room Entrance Banner', 'Dragon Profile Particle Effects', 'Animated Join Status'
        ]};
      case 5:
        return {'name': 'Phoenix Flame Novel', 'color': const Color(0xFFF97316), 'emoji': '🦅', 'benefits': [
          'Everything in Novel 4', 'Phoenix Wings Decoration', 'Flame Ring Aura',
          'Luxury Audio Voice Effect', 'Phoenix Chat Bubble', 'Exclusive Theme wallpaper'
        ]};
      case 6:
        return {'name': 'Celestial Sky Novel', 'color': const Color(0xFF06B6D4), 'emoji': '💎', 'benefits': [
          'Everything in Novel 5', 'Celestial Sky Diamond Glow', 'Celestial Entry Banner',
          'Animated Profile Header', 'Exclusive Background BGM', 'Premium Dynamic Theme'
        ]};
      case 7:
        return {'name': 'IMMORTAL NOVEL', 'color': const Color(0xFFFFD700), 'emoji': '🔮', 'benefits': [
          'Immortal Crown & Cosmic Border', 'Cosmic Black + Gold Theme', 'Legendary Golden Glow',
          'Immortal Entry & Exit Animation', 'Animated Cosmic Stars', 'Immortal Mini Profile Theme',
          'Luxury Voice Room Card', 'Animated Gift Effects', 'Exclusive BGM & Dynamic Wallpaper'
        ]};
      default:
        return {'name': 'Novel', 'color': Colors.blue, 'emoji': '✦', 'benefits': []};
    }
  }

  final List<Map<String, String>> paymentOptions = [
    {'name': 'UPI (Google Pay)', 'icon': '📱'},
    {'name': 'UPI (PhonePe)', 'icon': '🟣'},
    {'name': 'UPI (Paytm)', 'icon': '🔵'},
    {'name': 'Credit Card', 'icon': '💳'},
    {'name': 'Wallet (Paytm)', 'icon': '👛'},
    {'name': 'Net Banking', 'icon': '🏦'},
  ];

  @override
  void dispose() {
    _couponTextCtrl.dispose();
    _giftUserCtrl.dispose();
    super.dispose();
  }

  void _applyCoupon() {
    final code = _couponTextCtrl.text.trim().toUpperCase();
    final discount = _novelCtrl.couponDiscounts[code] ?? 0.0;
    setState(() {
      appliedCoupon = code;
      discountPercentage = discount;
    });

    if (discount > 0) {
      Get.snackbar(
        '🎟️ Coupon Applied!',
        'Saved ${(discount * 100).toStringAsFixed(0)}% using coupon $code',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981).withOpacity(0.95),
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        '⚠️ Invalid Coupon',
        'This coupon code does not exist or has expired.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444).withOpacity(0.95),
        colorText: Colors.white,
      );
    }
  }

  void _processPayment({String? giftFriend}) {
    final rawPrice = pricingMatrix[selectedLevel]![selectedDuration]!;
    final finalPrice = rawPrice * (1.0 - discountPercentage);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pop(context); // dismiss gateway dialog
          
          _novelCtrl.purchaseNovel(
            selectedLevel,
            selectedDuration,
            rawPrice,
            couponCode: discountPercentage > 0 ? appliedCoupon : null,
            friendUsername: giftFriend,
          );

          // Success Dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Text('🎉 ', style: TextStyle(fontSize: 24)),
                  Text(
                    giftFriend != null ? 'Collectible Gifted!' : 'Success!',
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Text(
                giftFriend != null
                    ? 'Successfully gifted Novel Level $selectedLevel to @$giftFriend!'
                    : 'Congratulations! Your Novel Level $selectedLevel status is now active.',
                style: GoogleFonts.poppins(color: const Color(0xFFCBD5E1)),
              ),
              actions: [
                TextButton(
                  child: Text('Awesome', style: TextStyle(color: getLevelTheme(selectedLevel)['color'])),
                  onPressed: () {
                    Navigator.pop(context);
                    if (giftFriend == null) {
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
          );
        });

        return Dialog(
          backgroundColor: const Color(0xFF0F172A).withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFFFFD700)),
                const SizedBox(height: 24),
                Text(
                  'Simulating Luxury Gateway...',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Securing transaction of ₹${finalPrice.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGiftingSheet() {
    _giftUserCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF09090B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 30,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Gift Novel Collectible 🎁',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Buy Novel Level $selectedLevel ($selectedDuration) for a friend to unlock this premium luxury identity on their profile.',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _giftUserCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Enter Friend's Username or SID",
                  prefixIcon: const Icon(Icons.person_outline, color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: getLevelTheme(selectedLevel)['color'],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    final name = _giftUserCtrl.text.trim();
                    if (name.isEmpty) {
                      Get.snackbar('Input Error', 'Please enter a valid friend username.');
                      return;
                    }
                    Navigator.pop(context);
                    _processPayment(giftFriend: name);
                  },
                  child: Text(
                    'Confirm Gift - ₹${(pricingMatrix[selectedLevel]![selectedDuration]! * (1.0 - discountPercentage)).toStringAsFixed(0)}',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCompareSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF09090B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text('Novel Collectibles Grid 📊', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildCompareRow('Novel Tier', ['Novel 1-3', 'Novel 4-5', 'Novel 6-7'], header: true),
                      _buildCompareRow('Cosmetics', ['Static Borders', 'Feather & Dragon wings', 'Immortal Cosmic Crown']),
                      _buildCompareRow('Profile Theme', ['Royal Blue / Gold', 'Red / Orange Flame', 'Dynamic Cosmic Black-Gold']),
                      _buildCompareRow('Daily Rewards', ['1.5x Boost', '2.0x Boost', '3.5x boost + Hall of Fame']),
                      _buildCompareRow('Animations', ['Welcome splash', 'Fire/Flame Banner', 'Cosmic Entry & Exit Banner']),
                      _buildCompareRow('Audio features', ['None', 'Custom voice effects', 'Collector Background Music']),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCompareRow(String feature, List<String> details, {bool header = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: header ? Colors.white.withOpacity(0.05) : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: GoogleFonts.outfit(
                color: header ? const Color(0xFFFFD700) : Colors.white70,
                fontSize: 13,
                fontWeight: header ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
          ...details.map(
            (e) => Expanded(
              flex: 2,
              child: Text(
                e,
                style: GoogleFonts.poppins(
                  color: header ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight: header ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = getLevelTheme(selectedLevel);
    final activeColor = activeTheme['color'] as Color;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        title: Text(
          '👑 NOVEL COLLECTIBLES',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.4, -0.6),
            radius: 1.3,
            colors: [
              activeColor.withOpacity(0.12),
              const Color(0xFF09090B),
            ],
            stops: const [0.0, 0.7],
          ),
        ),
        child: Obx(() {
          final remaining = _novelCtrl.getRemainingTime();
          final hasNovel = _novelCtrl.novelLevel.value > 0;
          final double rawPrice = pricingMatrix[selectedLevel]![selectedDuration]!;
          final double finalPrice = rawPrice * (1.0 - discountPercentage);

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top status banner
                _buildRenewalReminderBanner(),
                _buildActiveStatusCard(remaining, hasNovel),
                const SizedBox(height: 24),

                // 2. Swiper header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SELECT NOVEL TIER',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white60,
                          letterSpacing: 1.0,
                        ),
                      ),
                      TextButton(
                        onPressed: _showCompareSheet,
                        child: Text(
                          'Compare Grid 📊',
                          style: TextStyle(color: getLevelTheme(selectedLevel)['color']),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 3. Horizontal Level tabs
                _buildLevelTabsRow(),
                const SizedBox(height: 16),

                // 4. Detailed preview card
                _buildPreviewCard(selectedLevel),
                const SizedBox(height: 28),

                // 5. Durations list
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'CHOOSE COLLECTIBLE DURATION',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white60,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildDurationChips(),
                const SizedBox(height: 28),

                // 6. Payment block
                _buildCheckoutContainer(rawPrice, finalPrice),
              ],
            ),
          );
        }),
      ),
    );
  }

  bool _isPurchaseRestricted() {
    final currentLvl = _novelCtrl.novelLevel.value;
    final expiry = _novelCtrl.expiryDate.value;
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
      final expiry = _novelCtrl.expiryDate.value;
      if (_novelCtrl.novelLevel.value <= 0 || expiry == null) return const SizedBox.shrink();
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
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
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
                    'Novel Membership Expiring',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your Novel membership expires in $timeText. Renew now to maintain your premium benefits.',
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

  Widget _buildActiveStatusCard(Map<String, dynamic> remaining, bool hasNovel) {
    final int currentLevel = _novelCtrl.novelLevel.value;
    final theme = getLevelTheme(currentLevel > 0 ? currentLevel : 1);
    final Color color = theme['color'] as Color;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            hasNovel ? color.withOpacity(0.2) : Colors.white.withOpacity(0.03),
            Colors.black.withOpacity(0.6),
          ],
        ),
        border: Border.all(
          color: hasNovel ? color.withOpacity(0.4) : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          NovelAvatarDecorator(
            level: currentLevel,
            size: 64,
            child: Container(color: Colors.white10),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      hasNovel ? 'Novel Level $currentLevel' : 'Not Active',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    if (hasNovel) ...[
                      const SizedBox(width: 6),
                      NovelBadgeWidget(level: currentLevel, fontSize: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  hasNovel ? 'Duration Left: ${remaining['displayText']}' : 'Unlock Novel to claim highest luxury status.',
                  style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          if (hasNovel)
            Column(
              children: [
                Switch(
                  value: _novelCtrl.isAutoRenewEnabled.value,
                  onChanged: (v) => _novelCtrl.toggleAutoRenew(),
                  activeColor: color,
                ),
                Text(
                  'Auto-Renew',
                  style: GoogleFonts.poppins(color: Colors.white30, fontSize: 8),
                )
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLevelTabsRow() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 7,
        itemBuilder: (context, index) {
          final lvl = index + 1;
          final isSel = selectedLevel == lvl;
          final theme = getLevelTheme(lvl);
          final Color color = theme['color'] as Color;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedLevel = lvl;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? color : Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSel ? Colors.white30 : Colors.white.withOpacity(0.05),
                ),
                boxShadow: isSel
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Text(theme['emoji'] as String, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Text(
                    'Novel $lvl',
                    style: GoogleFonts.outfit(
                      color: isSel ? Colors.white : Colors.white70,
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
    );
  }

  Widget _buildPreviewCard(int lvl) {
    final theme = getLevelTheme(lvl);
    final Color color = theme['color'] as Color;
    final List<String> benefits = theme['benefits'] as List<String>;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withOpacity(0.02),
        border: Border.all(
          color: color.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NovelAvatarDecorator(
                  level: lvl,
                  size: 72,
                  child: Container(color: Colors.white10),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        theme['name'] as String,
                        style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      NovelBadgeWidget(level: lvl, fontSize: 10),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 30),
            Text(
              'UNLOCKED PRIVILEGES',
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: color, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            Column(
              children: benefits.map((b) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: color, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          b,
                          style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.85), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationChips() {
    final priceMap = pricingMatrix[selectedLevel]!;
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: durations.length,
        itemBuilder: (context, index) {
          final d = durations[index];
          final price = priceMap[d] ?? 0.0;
          final isSel = selectedDuration == d;
          final themeColor = getLevelTheme(selectedLevel)['color'] as Color;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedDuration = d;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSel ? themeColor.withOpacity(0.12) : Colors.white.withOpacity(0.01),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSel ? themeColor : Colors.white.withOpacity(0.05),
                  width: isSel ? 2 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    d,
                    style: GoogleFonts.poppins(
                      color: isSel ? Colors.white : Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '₹${price.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      color: isSel ? themeColor : Colors.white30,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCheckoutContainer(double rawPrice, double finalPrice) {
    final themeColor = getLevelTheme(selectedLevel)['color'] as Color;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponTextCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enter Coupon (NOVEL100, SUPREME)',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.02),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _applyCoupon,
                child: Text('Apply', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'SELECT PAYMENT METHOD',
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white30),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.8,
            ),
            itemCount: paymentOptions.length,
            itemBuilder: (context, index) {
              final pm = paymentOptions[index];
              final isSel = selectedPaymentMethod == pm['name'];
              return GestureDetector(
                onTap: () => setState(() => selectedPaymentMethod = pm['name']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isSel ? themeColor.withOpacity(0.12) : Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel ? themeColor : Colors.white.withOpacity(0.04),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(pm['icon']!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pm['name']!,
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Duration: $selectedDuration', style: GoogleFonts.poppins(color: Colors.white30, fontSize: 11)),
                  Row(
                    children: [
                      Text(
                        '₹${finalPrice.toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      if (discountPercentage > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '₹${rawPrice.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white30, decoration: TextDecoration.lineThrough, fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.gif_box_outlined, color: Colors.white70),
                    tooltip: 'Gift to friend',
                    onPressed: _showGiftingSheet,
                  ),
                  const SizedBox(width: 6),
                  Obx(() {
                    final restricted = _isPurchaseRestricted();
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: restricted ? Colors.white.withOpacity(0.02) : themeColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: restricted ? null : () => _processPayment(),
                      child: Text(
                        restricted
                            ? 'Active (No renewal)'
                            : 'Unlock Now',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: restricted ? Colors.white24 : Colors.white,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
