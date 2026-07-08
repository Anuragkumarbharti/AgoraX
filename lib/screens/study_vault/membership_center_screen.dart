import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/vip_controller.dart';
import '../../services/novel_controller.dart';
import '../../services/store_controller.dart';

class MembershipCenterScreen extends StatefulWidget {
  const MembershipCenterScreen({Key? key}) : super(key: key);

  @override
  State<MembershipCenterScreen> createState() => _MembershipCenterScreenState();
}

class _MembershipCenterScreenState extends State<MembershipCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final VipController _vipCtrl = Get.find<VipController>();
  final NovelController _novelCtrl = Get.find<NovelController>();

  int _selectedVipLevel = 1;
  int _selectedNovelLevel = 1;
  String _selectedVipDuration = '1 Month';
  String _selectedNovelDuration = '1 Month';

  Timer? _cooldownTimer;
  final RxString _vipCooldownText = ''.obs;
  final RxString _novelCooldownText = ''.obs;
  final RxDouble _vipCooldownProgress = 0.0.obs;
  final RxDouble _novelCooldownProgress = 0.0.obs;

  // VIP Pricing Matrix
  final Map<int, Map<String, double>> vipPricing = {
    1: {'3 Days': 99, '7 Days': 219, '15 Days': 449, '1 Month': 849, '6 Months': 4749, 'Yearly': 8999},
    2: {'3 Days': 199, '7 Days': 439, '15 Days': 899, '1 Month': 1699, '6 Months': 9499, 'Yearly': 17999},
    3: {'3 Days': 399, '7 Days': 879, '15 Days': 1799, '1 Month': 3399, '6 Months': 18999, 'Yearly': 35999},
    4: {'3 Days': 799, '7 Days': 1759, '15 Days': 3599, '1 Month': 6799, '6 Months': 37999, 'Yearly': 71999},
    5: {'3 Days': 1599, '7 Days': 3519, '15 Days': 7199, '1 Month': 13599, '6 Months': 75999, 'Yearly': 143999},
    6: {'3 Days': 3199, '7 Days': 7039, '15 Days': 14399, '1 Month': 27199, '6 Months': 151999, 'Yearly': 287999},
    7: {'3 Days': 6399, '7 Days': 14079, '15 Days': 28799, '1 Month': 54399, '6 Months': 303999, 'Yearly': 575999},
  };

  // Novel Pricing Matrix
  final Map<int, Map<String, double>> novelPricing = {
    1: {'3 Days': 399, '7 Days': 879, '15 Days': 1799, '1 Month': 3399, '6 Months': 19149, 'Yearly': 36499},
    2: {'3 Days': 799, '7 Days': 1759, '15 Days': 3599, '1 Month': 6799, '6 Months': 38299, 'Yearly': 72999},
    3: {'3 Days': 1599, '7 Days': 3519, '15 Days': 7199, '1 Month': 13599, '6 Months': 76599, 'Yearly': 145999},
    4: {'3 Days': 3199, '7 Days': 7039, '15 Days': 14399, '1 Month': 27199, '6 Months': 153199, 'Yearly': 291999},
    5: {'3 Days': 6399, '7 Days': 14079, '15 Days': 28799, '1 Month': 54399, '6 Months': 306399, 'Yearly': 583999},
    6: {'3 Days': 12799, '7 Days': 28159, '15 Days': 57599, '1 Month': 108799, '6 Months': 612799, 'Yearly': 1167999},
    7: {'3 Days': 25599, '7 Days': 56319, '15 Days': 115199, '1 Month': 217599, '6 Months': 1225599, 'Yearly': 2335999},
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedVipLevel = _vipCtrl.vipLevel.value > 0 ? _vipCtrl.vipLevel.value : 1;
    _selectedNovelLevel = _novelCtrl.novelLevel.value > 0 ? _novelCtrl.novelLevel.value : 1;
    _startCooldownTimer();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCooldowns();
    });
    _updateCooldowns();
  }

  void _updateCooldowns() {
    final now = DateTime.now();

    // VIP claim cooldown calculation
    if (_vipCtrl.vipLevel.value > 0) {
      final lastVip = _vipCtrl.lastClaimTime.value;
      if (lastVip == null) {
        _vipCooldownText.value = 'Available Now';
        _vipCooldownProgress.value = 1.0;
      } else {
        final diff = now.difference(lastVip);
        if (diff.inHours >= 24) {
          _vipCooldownText.value = 'Available Now';
          _vipCooldownProgress.value = 1.0;
        } else {
          final remaining = const Duration(hours: 24) - diff;
          _vipCooldownText.value = '${remaining.inHours}h ${remaining.inMinutes % 60}m ${remaining.inSeconds % 60}s';
          _vipCooldownProgress.value = diff.inSeconds / const Duration(hours: 24).inSeconds;
        }
      }
    } else {
      _vipCooldownText.value = 'Lock';
      _vipCooldownProgress.value = 0.0;
    }

    // Novel claim cooldown calculation
    if (_novelCtrl.novelLevel.value > 0) {
      final lastNovel = _novelCtrl.lastClaimTime.value;
      if (lastNovel == null) {
        _novelCooldownText.value = 'Available Now';
        _novelCooldownProgress.value = 1.0;
      } else {
        final diff = now.difference(lastNovel);
        if (diff.inHours >= 24) {
          _novelCooldownText.value = 'Available Now';
          _novelCooldownProgress.value = 1.0;
        } else {
          final remaining = const Duration(hours: 24) - diff;
          _novelCooldownText.value = '${remaining.inHours}h ${remaining.inMinutes % 60}m ${remaining.inSeconds % 60}s';
          _novelCooldownProgress.value = diff.inSeconds / const Duration(hours: 24).inSeconds;
        }
      }
    } else {
      _novelCooldownText.value = 'Lock';
      _novelCooldownProgress.value = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Membership Center',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(icon: Icon(Icons.workspace_premium_rounded), text: '💎 VIP Club'),
            Tab(icon: Icon(Icons.menu_book_rounded), text: '🔮 Novel Hub'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVipTab(),
          _buildNovelTab(),
        ],
      ),
    );
  }

  Widget _buildVipTab() {
    return Obx(() {
      final currentLevel = _vipCtrl.vipLevel.value;
      final timeInfo = _vipCtrl.getRemainingTime();
      final hasVip = currentLevel > 0;

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current status card
          _buildStatusCard(
            title: hasVip ? 'VIP Level $currentLevel Active' : 'No VIP Active',
            subtitle: hasVip ? timeInfo['displayText'] ?? '' : 'Unlock premium customisations & daily claims',
            icon: Icons.star_rounded,
            color: const Color(0xFFFFD700),
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            isAutoRenew: _vipCtrl.isAutoRenewEnabled.value,
            onRenewToggle: () => _vipCtrl.toggleAutoRenew(),
            showClaim: hasVip,
            claimText: _vipCooldownText.value,
            claimProgress: _vipCooldownProgress.value,
            onClaim: () => _vipCtrl.claimDailyCoins(),
            claimCoins: _vipCtrl.getDailyCoinsAmount(),
          ),
          const SizedBox(height: 20),

          // Upgrade Slider Title
          Text(
            'Select VIP Level to Buy/Upgrade',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 10),

          // VIP Level Selector (1-7)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (index) {
                final level = index + 1;
                final isSelected = _selectedVipLevel == level;
                return GestureDetector(
                  onTap: () => setState(() => _selectedVipLevel = level),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)])
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'V$level',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.white38,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),

          // Pricing Grid for VIP
          Text(
            'Select Duration Package',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 10),
          _buildDurationGrid(
            pricingMap: vipPricing[_selectedVipLevel] ?? {},
            selectedDuration: _selectedVipDuration,
            onSelect: (dur) => setState(() => _selectedVipDuration = dur),
          ),
          const SizedBox(height: 20),

          // Action Button
          Builder(
            builder: (context) {
              final isLowerOrEqual = _selectedVipLevel <= currentLevel;
              return ElevatedButton(
                onPressed: isLowerOrEqual ? null : () {
                  final price = vipPricing[_selectedVipLevel]?[_selectedVipDuration] ?? 0.0;
                  Get.toNamed(
                    '/checkout',
                    arguments: {
                      'name': 'VIP Level $_selectedVipLevel',
                      'category': 'VIP',
                      'basePrice': price,
                      'duration': _selectedVipDuration,
                    }
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: isLowerOrEqual ? Colors.grey : const Color(0xFF8B5CF6),
                ),
                child: Text(
                  isLowerOrEqual
                      ? 'Locked (Active: VIP $currentLevel)'
                      : 'Unlock VIP $_selectedVipLevel ($_selectedVipDuration) • ₹${vipPricing[_selectedVipLevel]?[_selectedVipDuration]?.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
              );
            }
          ),
          const SizedBox(height: 24),

          // VIP Feature comparison deck
          Text(
            'VIP Perks Breakdown',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          _buildVipPerksBreakdown(),
        ],
      );
    });
  }

  Widget _buildNovelTab() {
    return Obx(() {
      final currentLevel = _novelCtrl.novelLevel.value;
      final timeInfo = _novelCtrl.getRemainingTime();
      final hasNovel = currentLevel > 0;

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current status card
          _buildStatusCard(
            title: hasNovel ? 'Novel Level $currentLevel Active' : 'No Novel Active',
            subtitle: hasNovel ? timeInfo['displayText'] ?? '' : 'Exclusive custom layouts & reader coins',
            icon: Icons.book_rounded,
            color: const Color(0xFF10B981),
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            isAutoRenew: _novelCtrl.isAutoRenewEnabled.value,
            onRenewToggle: () => _novelCtrl.toggleAutoRenew(),
            showClaim: hasNovel,
            claimText: _novelCooldownText.value,
            claimProgress: _novelCooldownProgress.value,
            onClaim: () => _novelCtrl.claimDailyCoins(),
            claimCoins: _novelCtrl.getDailyCoinsAmount(),
          ),
          const SizedBox(height: 20),

          // Equip visual style widget (Novel Collector System)
          if (hasNovel && _novelCtrl.ownedNovels.isNotEmpty) ...[
            Text(
              'Equip Owned Novel Style',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bgLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Equipped Style: Level ${_novelCtrl.activeNovelStyle.value}',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
                  ),
                  DropdownButton<int>(
                    dropdownColor: AppTheme.bgLight,
                    value: _novelCtrl.ownedNovels.contains(_novelCtrl.activeNovelStyle.value) 
                        ? _novelCtrl.activeNovelStyle.value 
                        : _novelCtrl.ownedNovels.first,
                    items: _novelCtrl.ownedNovels.map((int lvl) {
                      return DropdownMenuItem<int>(
                        value: lvl,
                        child: Text('Level $lvl', style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        _novelCtrl.switchActiveStyle(val);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Level Selection Slider
          Text(
            'Select Novel Level to Buy/Upgrade',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 10),

          // Novel Level Selector (1-7)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (index) {
                final level = index + 1;
                final isSelected = _selectedNovelLevel == level;
                return GestureDetector(
                  onTap: () => setState(() => _selectedNovelLevel = level),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'N$level',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.white38,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),

          // Pricing Grid for Novel
          Text(
            'Select Duration Package',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 10),
          _buildDurationGrid(
            pricingMap: novelPricing[_selectedNovelLevel] ?? {},
            selectedDuration: _selectedNovelDuration,
            onSelect: (dur) => setState(() => _selectedNovelDuration = dur),
          ),
          const SizedBox(height: 20),

          // Action Button
          Builder(
            builder: (context) {
              final isLowerOrEqual = _selectedNovelLevel <= currentLevel;
              return ElevatedButton(
                onPressed: isLowerOrEqual ? null : () {
                  final price = novelPricing[_selectedNovelLevel]?[_selectedNovelDuration] ?? 0.0;
                  Get.toNamed(
                    '/checkout',
                    arguments: {
                      'name': 'Novel Level $_selectedNovelLevel',
                      'category': 'Novel',
                      'basePrice': price,
                      'duration': _selectedNovelDuration,
                    }
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: isLowerOrEqual ? Colors.grey : const Color(0xFF10B981),
                ),
                child: Text(
                  isLowerOrEqual
                      ? 'Locked (Active: Novel $currentLevel)'
                      : 'Unlock Novel $_selectedNovelLevel ($_selectedNovelDuration) • ₹${novelPricing[_selectedNovelLevel]?[_selectedNovelDuration]?.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
              );
            }
          ),
          const SizedBox(height: 24),

          // Novel Features comparison deck
          Text(
            'Novel Perks Breakdown',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          _buildNovelPerksBreakdown(),
        ],
      );
    });
  }

  Widget _buildStatusCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Gradient gradient,
    required bool isAutoRenew,
    required VoidCallback onRenewToggle,
    required bool showClaim,
    required String claimText,
    required double claimProgress,
    required VoidCallback onClaim,
    required int claimCoins,
  }) {
    final canClaim = claimText == 'Available Now';

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isAutoRenew ? 'Auto-Renew' : 'One-Time',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Auto-Renewal',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: isAutoRenew,
                    onChanged: (val) => onRenewToggle(),
                    activeColor: Colors.white,
                    activeTrackColor: Colors.white30,
                  )
                ],
              ),
              if (showClaim)
                ElevatedButton(
                  onPressed: canClaim ? onClaim : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: Text(
                    canClaim ? 'Claim $claimCoins Coins' : claimText,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDurationGrid({
    required Map<String, double> pricingMap,
    required String selectedDuration,
    required Function(String) onSelect,
  }) {
    final durations = ['3 Days', '7 Days', '15 Days', '1 Month', '6 Months', 'Yearly'];
    final discountLabels = {
      '3 Days': 'Base',
      '7 Days': '5% Off',
      '15 Days': '10% Off',
      '1 Month': '15% Off',
      '6 Months': '20% Off',
      'Yearly': '25% Off',
    };

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: durations.length,
      itemBuilder: (context, index) {
        final dur = durations[index];
        final price = pricingMap[dur] ?? 0.0;
        final isSelected = selectedDuration == dur;
        final discount = discountLabels[dur] ?? '';

        return GestureDetector(
          onTap: () => onSelect(dur),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.bgLight : AppTheme.bgLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dur,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${price.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor.withOpacity(0.2) : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    discount,
                    style: const TextStyle(fontSize: 9, color: Colors.white70),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVipPerksBreakdown() {
    final perks = {
      1: ['Bronze Border Frame', '5 Daily Coins', 'Dust Sparkles Entrance', '5% Book Discount', '100k AI Tokens'],
      2: ['Silver Sage Frame', '10 Daily Coins', 'Silver Mist Entrance', '10% Book Discount', '250k AI Tokens'],
      3: ['Gold Mentor Frame', '20 Daily Coins', 'Golden Flash Entrance', '15% Book Discount', '600k AI Tokens'],
      4: ['Amethyst Arch Frame', '35 Daily Coins', 'Amethyst Rift Entrance', '20% Book Discount', '1.2M AI Tokens'],
      5: ['Emerald Throne Frame', '55 Daily Coins', 'Emerald Beacon Entrance', '3 Books/Week Free Reads', '3M AI Tokens'],
      6: ['Ruby Emperor Frame', '80 Daily Coins', 'Ruby Tempest Entrance', '1 Book/Day Free Reads', '7.5M AI Tokens'],
      7: ['Obsidian Sovereign Frame', '120 Daily Coins', 'Sovereign Rift Entrance', '2 Books/Day Free Reads', 'Unlimited AI'],
    };

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: perks.entries.map((entry) {
          final level = entry.key;
          final perksList = entry.value;
          final isCurrent = _vipCtrl.vipLevel.value == level;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrent ? AppTheme.primaryColor.withOpacity(0.15) : Colors.white10.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: isCurrent ? Border.all(color: AppTheme.primaryColor) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Level $level Perks',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                    if (isCurrent)
                      const Text(
                        'CURRENT PLAN',
                        style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                      )
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: perksList.map((perk) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        perk,
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    );
                  }).toList(),
                )
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNovelPerksBreakdown() {
    final perks = {
      1: ['Sepia Cream Theme', '20 Daily Coins', '5 Coins/hr rewards', '5% Book Discount'],
      2: ['Mint Ice Theme', '40 Daily Coins', '10 Coins/hr rewards', '10% Book Discount'],
      3: ['Midnight Forest Theme', '70 Daily Coins', '20 Coins/hr rewards', '15% Book Discount'],
      4: ['Crimson Velvet Theme', '110 Daily Coins', '3 Books/Week Free Reads', '25% Book Discount'],
      5: ['Obsidian Gold Theme', '160 Daily Coins', '1 Book/Day Free Reads', '25% Book Discount'],
      6: ['Scribble Neon Theme', '220 Daily Coins', '2 Books/Day Free Reads', '25% Book Discount'],
      7: ['Sovereign Archivist Theme', '300 Daily Coins', '4 Books/Day Free Reads', '25% Book Discount'],
    };

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: perks.entries.map((entry) {
          final level = entry.key;
          final perksList = entry.value;
          final isCurrent = _novelCtrl.novelLevel.value == level;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrent ? AppTheme.accentColor.withOpacity(0.15) : Colors.white10.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: isCurrent ? Border.all(color: AppTheme.accentColor) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Level $level Perks',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                    if (isCurrent)
                      const Text(
                        'CURRENT PLAN',
                        style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                      )
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: perksList.map((perk) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        perk,
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    );
                  }).toList(),
                )
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
