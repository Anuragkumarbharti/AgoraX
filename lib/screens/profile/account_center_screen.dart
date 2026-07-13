import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/store_controller.dart';
import '../../services/vip_controller.dart';
import '../../services/novel_controller.dart';
import '../../services/customization_controller.dart';
import '../store/store_home_screen.dart';
import '../store/checkout_screen.dart';
import '../vip/vip_purchase_screen.dart';
import '../novel/novel_purchase_screen.dart';
import 'profile_customization_screen.dart';

class AccountCenterScreen extends StatefulWidget {
  const AccountCenterScreen({Key? key}) : super(key: key);

  @override
  State<AccountCenterScreen> createState() => _AccountCenterScreenState();
}

class _AccountCenterScreenState extends State<AccountCenterScreen> {
  final StoreController _storeCtrl = Get.find<StoreController>();
  final VipController _vipCtrl = Get.find<VipController>();
  final NovelController _novelCtrl = Get.find<NovelController>();
  final CustomizationController _custCtrl = Get.find<CustomizationController>();

  // PageController for sticky top cards
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Mock balances & values (some reactive)
  RxInt get _silverCoins => _storeCtrl.silverCoinsBalance;
  RxInt get _diamonds => _storeCtrl.diamondsBalance;
  final RxInt _rewardPoints = 450.obs;
  final RxInt _bonusCoins = 200.obs;
  final RxDouble _voucherBalance = 15.00.obs;

  // Mock Income
  RxDouble get _availableIncome => _storeCtrl.availableIncomeBalance;
  final double _totalIncome = 1250.00;
  final double _todayIncome = 15.00;
  final double _weeklyIncome = 120.00;
  final double _monthlyIncome = 450.00;
  final double _lifetimeIncome = 5000.00;

  // Track if daily reward is claimed
  final RxBool _dailyRewardClaimed = false.obs;

  // Developer toggle for Creator & Agency eligibility
  final RxBool _isCreatorEligible = true.obs;

  // Track expanded states for categories
  final RxMap<String, bool> _expandedSections = <String, bool>{
    'vip': true, // VIP & Purchases default expanded
    'store': false,
    'wallet': false,
    'income': false,
    'rewards': false,
    'tasks': false,
    'referrals': false,
    'creator': false,
    'history': false,
    'support': false,
  }.obs;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070A),
      body: Stack(
        children: [
          // Background Gradient Glows
          Positioned(
            top: -150,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withOpacity(0.12),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            top: 250,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withOpacity(0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAppBar(),
                
                // Pinned Top Summary Cards
                _buildPinnedSummarySection(),
                
                // Scrollable category list
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      _buildVipPurchasesSection(),
                      const SizedBox(height: 12),
                      _buildStoreSection(),
                      const SizedBox(height: 12),
                      _buildWalletSection(),
                      const SizedBox(height: 12),
                      _buildIncomeSection(),
                      const SizedBox(height: 12),
                      _buildRewardsSection(),
                      const SizedBox(height: 12),
                      _buildTaskSection(),
                      const SizedBox(height: 12),
                      _buildReferralSection(),
                      const SizedBox(height: 12),
                      _buildCreatorAgencySection(),
                      const SizedBox(height: 12),
                      _buildHistorySection(),
                      const SizedBox(height: 12),
                      _buildSupportSection(),
                      const SizedBox(height: 32),
                      
                      // Developer panel toggle at the bottom
                      _buildDevPanel(),
                      const SizedBox(height: 40),
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

  // --- APP BAR ---
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Get.back(),
          ),
          const SizedBox(width: 8),
          Text(
            'ACCOUNT & WALLET',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // --- PINNED TOP SUMMARY CARDS ---
  Widget _buildPinnedSummarySection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 160,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              _buildWalletSummaryCard(),
              _buildIncomeSummaryCard(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            2,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index
                    ? const Color(0xFF8B5CF6)
                    : Colors.white24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildWalletSummaryCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: const Color(0xFF13131A).withOpacity(0.85),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1E1B4B).withOpacity(0.4),
              const Color(0xFF0F172A).withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wallet_rounded, color: Color(0xFFA78BFA), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'My Wallet Summary',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Obx(() {
                  // Notification if there are unclaimed rewards
                  final hasUnclaimed = !_dailyRewardClaimed.value;
                  return hasUnclaimed
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Reward Claimable', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        )
                      : const SizedBox();
                }),
              ],
            ),
            const Spacer(),
            Obx(() {
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 2.2,
                children: [
                  _buildSummaryItem('Gold Coins', '${_storeCtrl.coinsBalance.value}', '🪙'),
                  _buildSummaryItem('Silver Coins', '${_silverCoins.value}', '🥈'),
                  _buildSummaryItem('Diamonds', '${_diamonds.value}', '💎'),
                  _buildSummaryItem('Reward Points', '${_rewardPoints.value}', '✨'),
                  _buildSummaryItem('Bonus Coins', '${_bonusCoins.value}', '🪙'),
                  _buildSummaryItem('Voucher Bal.', '\$${_voucherBalance.value.toStringAsFixed(2)}', '🎟️'),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeSummaryCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: const Color(0xFF13131A).withOpacity(0.85),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF022C22).withOpacity(0.3),
              const Color(0xFF0F172A).withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.monetization_on_rounded, color: Color(0xFF34D399), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Income Center Dashboard',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                // Pending withdrawal badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('1 Pending', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Spacer(),
            Obx(() {
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 2.2,
                children: [
                  _buildSummaryItem('Avail. Balance', '\$${_availableIncome.value.toStringAsFixed(2)}', '💵'),
                  _buildSummaryItem('Today\'s Income', '\$${_todayIncome.toStringAsFixed(2)}', '📈'),
                  _buildSummaryItem('Weekly Income', '\$${_weeklyIncome.toStringAsFixed(2)}', '📊'),
                  _buildSummaryItem('Monthly Income', '\$${_monthlyIncome.toStringAsFixed(2)}', '📅'),
                  _buildSummaryItem('Total Income', '\$${_totalIncome.toStringAsFixed(2)}', '💼'),
                  _buildSummaryItem('Lifetime Income', '\$${_lifetimeIncome.toStringAsFixed(2)}', '👑'),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, String emoji) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- EXPANDABLE GROUP CARD BUILDER ---
  Widget _buildCategoryGroup({
    required String id,
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? badge,
    bool initiallyExpanded = false,
  }) {
    return Obx(() {
      final isExpanded = _expandedSections[id] ?? initiallyExpanded;
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: const Color(0xFF111116).withOpacity(0.7),
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  _expandedSections[id] = !isExpanded;
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(icon, color: const Color(0xFFA78BFA), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        badge,
                        const SizedBox(width: 8),
                      ],
                      AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 14),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.02)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                ),
                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ],
          ),
        ),
      );
    });
  }

  // --- SECTION 1: VIP & PURCHASES ---
  Widget _buildVipPurchasesSection() {
    return _buildCategoryGroup(
      id: 'vip',
      title: '💎 VIP & Purchases',
      icon: Icons.diamond_outlined,
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
        ),
        child: const Text('Expiring', style: TextStyle(color: Color(0xFFEF4444), fontSize: 8, fontWeight: FontWeight.bold)),
      ),
      children: [
        // VIP Membership Status
        Obx(() {
          final vipLevel = _vipCtrl.vipLevel.value;
          final remaining = _vipCtrl.getRemainingTime();
          final isVipActive = vipLevel > 0;
          return _buildFeatureTile(
            title: 'VIP Membership',
            subtitle: isVipActive ? 'VIP $vipLevel • ${remaining['displayText']}' : 'Not Subscribed',
            trailing: TextButton(
              onPressed: () => Get.to(() => const VipPurchaseScreen()),
              child: Text(isVipActive ? 'Extend' : 'Join VIP', style: const TextStyle(color: Color(0xFFA78BFA), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          );
        }),
        const Divider(color: Colors.white10),

        // Novel Membership Status
        Obx(() {
          final novelLevel = _novelCtrl.novelLevel.value;
          final isNovelActive = novelLevel > 0;
          return _buildFeatureTile(
            title: 'Novel Membership',
            subtitle: isNovelActive ? 'Novel Level $novelLevel • Active' : 'Not Subscribed',
            trailing: TextButton(
              onPressed: () => Get.to(() => const NovelPurchaseScreen()),
              child: Text(isNovelActive ? 'Extend' : 'Join Novel', style: const TextStyle(color: Color(0xFFA78BFA), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          );
        }),
        const Divider(color: Colors.white10),

        // Purchased Items & Expiries (My Purchases)
        const SizedBox(height: 4),
        Text(
          'MY PURCHASES (COSMETICS INVENTORY)',
          style: GoogleFonts.outfit(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 8),

        Obx(() {
          // Filter unlocked items that are in the expiries database
          final items = _custCtrl.itemExpiries.keys.toList();
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('No purchased cosmetics found.', style: TextStyle(color: Colors.white30, fontSize: 12)),
            );
          }

          return Column(
            children: items.map((itemName) {
              final expiry = _custCtrl.itemExpiries[itemName]!;
              final now = DateTime.now();
              final isExpired = now.isAfter(expiry);
              final diff = expiry.difference(now);
              final remainingDays = isExpired ? 0 : diff.inDays;

              // Check if equipped
              bool isEquipped = false;
              String category = 'Avatar Frame';
              final dbItem = _custCtrl.customizationDb.firstWhere(
                (e) => e['name'] == itemName,
                orElse: () => <String, dynamic>{},
              );
              if (dbItem.isNotEmpty) {
                category = dbItem['category'] as String;
              }

              if (category == 'Avatar Frame') {
                isEquipped = _custCtrl.activeFrame.value == itemName;
              } else if (category == 'Avatar Effect') {
                isEquipped = _custCtrl.activeAvatarEffect.value == itemName;
              } else if (category == 'Chat Bubble') {
                isEquipped = _custCtrl.activeBubble.value == itemName;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C24),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isEquipped ? const Color(0xFF8B5CF6).withOpacity(0.3) : Colors.transparent),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                itemName,
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isExpired
                                      ? const Color(0xFFEF4444).withOpacity(0.15)
                                      : (isEquipped ? const Color(0xFF10B981).withOpacity(0.15) : Colors.white10),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isExpired ? 'Expired' : (isEquipped ? 'Active' : 'Equippable'),
                                  style: TextStyle(
                                    color: isExpired
                                        ? const Color(0xFFEF4444)
                                        : (isEquipped ? const Color(0xFF10B981) : Colors.white60),
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isExpired
                                ? 'Expired on ${expiry.day}/${expiry.month}/${expiry.year}'
                                : 'Expires: ${expiry.day}/${expiry.month}/${expiry.year} ($remainingDays Days Left)',
                            style: GoogleFonts.poppins(color: isExpired ? Colors.white24 : Colors.white54, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isExpired) ...[
                          ElevatedButton(
                            onPressed: () {
                              if (isEquipped) {
                                _custCtrl.removeItem(category);
                              } else {
                                _custCtrl.equipItem(category, itemName);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEquipped ? const Color(0xFFEF4444).withOpacity(0.12) : const Color(0xFF8B5CF6),
                              foregroundColor: isEquipped ? const Color(0xFFEF4444) : Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: const Size(60, 26),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(isEquipped ? 'Unequip' : 'Equip', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ] else ...[
                          ElevatedButton(
                            onPressed: () => Get.to(() => const StoreHomeScreen()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: const Size(60, 26),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Buy Again', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    )
                  ],
                ),
              );
            }).toList(),
          );
        }),

        const Divider(color: Colors.white10),
        const SizedBox(height: 4),
        Text(
          'COLLECTIONS',
          style: GoogleFonts.outfit(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 6),
        // Collections Grid Layout
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildCollectionTag('Avatar Frames'),
            _buildCollectionTag('Avatar Backgrounds'),
            _buildCollectionTag('Entry Effects'),
            _buildCollectionTag('Chat Bubbles'),
            _buildCollectionTag('Badges'),
            _buildCollectionTag('Tag Lights'),
            _buildCollectionTag('Gift Showcase'),
            _buildCollectionTag('Community Tags'),
            _buildCollectionTag('Premium Tools'),
          ],
        )
      ],
    );
  }

  Widget _buildCollectionTag(String name) {
    return ActionChip(
      backgroundColor: const Color(0xFF1A1A24),
      side: const BorderSide(color: Colors.white10),
      label: Text(name, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 9.5)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      onPressed: () => Get.to(() => const ProfileCustomizationScreen()),
    );
  }

  // --- SECTION 2: CREANIA STORE ---
  Widget _buildStoreSection() {
    return _buildCategoryGroup(
      id: 'store',
      title: '🛒 Creania Store',
      icon: Icons.storefront_outlined,
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text('Sale', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
      ),
      children: [
        _buildFeatureTile(
          title: 'Open Store',
          subtitle: 'Go to Creania Marketplace',
          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
          onTap: () => Get.to(() => const StoreHomeScreen()),
        ),
        const Divider(color: Colors.white10),
        
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.8,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _buildStoreGridButton(Icons.local_fire_department, 'Featured Items', () => Get.to(() => const StoreHomeScreen())),
            _buildStoreGridButton(Icons.new_releases, 'New Arrivals', () => Get.to(() => const StoreHomeScreen())),
            _buildStoreGridButton(Icons.flash_on, 'Limited Offers', () => Get.to(() => const StoreHomeScreen())),
            _buildStoreGridButton(Icons.shopping_bag, 'My Orders', () => _showOrdersDialog()),
            _buildStoreGridButton(Icons.history, 'Order History', () => _showOrdersDialog()),
            _buildStoreGridButton(Icons.favorite, 'Wishlist', () {
              Get.snackbar('Wishlist', 'You have no items in your wishlist.', snackPosition: SnackPosition.BOTTOM);
            }),
            _buildStoreGridButton(Icons.confirmation_number, 'Coupons', () => _showCouponsDialog()),
            _buildStoreGridButton(Icons.qr_code, 'Redeem Code', () => _showRedeemDialog()),
          ],
        )
      ],
    );
  }

  Widget _buildStoreGridButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF161620),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFA78BFA), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SECTION 3: MY WALLET ---
  Widget _buildWalletSection() {
    return _buildCategoryGroup(
      id: 'wallet',
      title: '💰 My Wallet',
      icon: Icons.account_balance_wallet_outlined,
      children: [
        // Wallet Balances summary
        Obx(() {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF13131A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildWalletBalanceRow('Gold Coins', '${_storeCtrl.coinsBalance.value}', '🪙'),
                const Divider(color: Colors.white10, height: 12),
                _buildWalletBalanceRow('Silver Coins', '${_silverCoins.value}', '🥈'),
                const Divider(color: Colors.white10, height: 12),
                _buildWalletBalanceRow('Diamonds', '${_diamonds.value}', '💎'),
                const Divider(color: Colors.white10, height: 12),
                _buildWalletBalanceRow('Reward Points', '${_rewardPoints.value}', '✨'),
                const Divider(color: Colors.white10, height: 12),
                _buildWalletBalanceRow('Bonus Coins', '${_bonusCoins.value}', '🪙'),
                const Divider(color: Colors.white10, height: 12),
                _buildWalletBalanceRow('Voucher Balance', '\$${_voucherBalance.value.toStringAsFixed(2)}', '🎟️'),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),

        // Quick Actions Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          childAspectRatio: 1.5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _buildStoreGridButton(Icons.add_card, 'Recharge', () => _showRechargeDialog()),
            _buildStoreGridButton(Icons.account_balance, 'Withdraw', () => _showWithdrawDialog()),
            _buildStoreGridButton(Icons.send_rounded, 'Transfer', () => _showTransferDialog()),
          ],
        ),
        const Divider(color: Colors.white10),
        _buildFeatureTile(
          title: 'Wallet History',
          subtitle: 'All credit and debit transactions',
          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
          onTap: () => _showWalletHistoryDialog(),
        ),
      ],
    );
  }

  Widget _buildWalletBalanceRow(String name, String balance, String emoji) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Text(name, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
          ],
        ),
        Text(balance, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- SECTION 4: INCOME CENTER ---
  Widget _buildIncomeSection() {
    return _buildCategoryGroup(
      id: 'income',
      title: '💵 Income Center',
      icon: Icons.payments_outlined,
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
        ),
        child: const Text('Pending', style: TextStyle(color: Color(0xFFEF4444), fontSize: 8, fontWeight: FontWeight.bold)),
      ),
      children: [
        // Available balance
        Obx(() {
          return Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF13131A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Available Balance', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
                    const SizedBox(height: 4),
                    Text('\$${_availableIncome.value.toStringAsFixed(2)}', style: GoogleFonts.poppins(color: const Color(0xFF10B981), fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => _showIncomeWithdrawDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Withdraw', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),

        Text(
          'INCOME SOURCES',
          style: GoogleFonts.outfit(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 8),

        // Income Sources Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 3.2,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          children: [
            _buildSourceTile('Gifts Received', '\$480.00', '🎁'),
            _buildSourceTile('Voice Arenas', '\$320.00', '🎙️'),
            _buildSourceTile('Events Hosted', '\$150.00', '🎪'),
            _buildSourceTile('Completed Tasks', '\$75.00', '📋'),
            _buildSourceTile('Referrals', '\$115.00', '👥'),
            _buildSourceTile('Creator Program', '\$80.00', '🎤'),
            _buildSourceTile('Agency Share', '\$30.00', '💼'),
            _buildSourceTile('Bonus Income', '\$0.00', '⚡'),
          ],
        ),
        const Divider(color: Colors.white10),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => _showPaymentAccountsDialog(),
              icon: const Icon(Icons.link, size: 14, color: Color(0xFFA78BFA)),
              label: const Text('Payment Accounts', style: TextStyle(fontSize: 11, color: Color(0xFFA78BFA))),
            ),
            TextButton.icon(
              onPressed: () => _showWithdrawalHistoryDialog(),
              icon: const Icon(Icons.history, size: 14, color: Color(0xFFA78BFA)),
              label: const Text('Withdrawal History', style: TextStyle(fontSize: 11, color: Color(0xFFA78BFA))),
            ),
            TextButton.icon(
              onPressed: () {
                Get.snackbar('Analytics', 'Income Analytics coming soon!', snackPosition: SnackPosition.BOTTOM);
              },
              icon: const Icon(Icons.analytics_outlined, size: 14, color: Color(0xFFA78BFA)),
              label: const Text('Income Analytics', style: TextStyle(fontSize: 11, color: Color(0xFFA78BFA))),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildSourceTile(String name, String val, String emoji) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 8), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(val, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION 5: REWARDS ---
  Widget _buildRewardsSection() {
    return _buildCategoryGroup(
      id: 'rewards',
      title: '🎁 Rewards',
      icon: Icons.card_giftcard_outlined,
      badge: Obx(() {
        return !_dailyRewardClaimed.value
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              )
            : const SizedBox();
      }),
      children: [
        Obx(() {
          return _buildFeatureTile(
            title: 'Daily Rewards',
            subtitle: _dailyRewardClaimed.value ? 'Claimed Today ✓' : '50 Gold Coins available to claim',
            trailing: ElevatedButton(
              onPressed: _dailyRewardClaimed.value
                  ? null
                  : () {
                      _storeCtrl.coinsBalance.value += 50;
                      _dailyRewardClaimed.value = true;
                      Get.snackbar(
                        'Claim Success 🎉',
                        '50 Gold Coins added to your wallet!',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: const Color(0xFF10B981),
                        colorText: Colors.white,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                disabledBackgroundColor: Colors.white12,
                minimumSize: const Size(60, 28),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                _dailyRewardClaimed.value ? 'Claimed' : 'Claim',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _dailyRewardClaimed.value ? Colors.white38 : Colors.white),
              ),
            ),
          );
        }),
        const Divider(color: Colors.white10),
        _buildFeatureTile(
          title: 'Weekly Rewards',
          subtitle: 'Active 7-day streak rewards',
          trailing: const Text('Locked', style: TextStyle(color: Colors.white24, fontSize: 11)),
        ),
        const Divider(color: Colors.white10),
        _buildFeatureTile(
          title: 'Monthly Rewards',
          subtitle: 'End of month loyalty rewards',
          trailing: const Text('Locked', style: TextStyle(color: Colors.white24, fontSize: 11)),
        ),
        const Divider(color: Colors.white10),
        _buildFeatureTile(
          title: 'Lucky Spin',
          subtitle: 'Spin the wheel for premium rewards',
          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
          onTap: () => Get.to(() => const StoreHomeScreen()), // Lucky Spin is in Store Home
        ),
        const Divider(color: Colors.white10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => _showRewardHistoryDialog(),
              child: const Text('Reward History', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11)),
            ),
            TextButton(
              onPressed: () => _showCouponsDialog(),
              child: const Text('Active Coupons', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11)),
            ),
            TextButton(
              onPressed: () {
                Get.snackbar('Promo', 'No promotional rewards currently available.', snackPosition: SnackPosition.BOTTOM);
              },
              child: const Text('Promo Rewards', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11)),
            ),
          ],
        )
      ],
    );
  }

  // --- SECTION 6: TASK CENTER ---
  Widget _buildTaskSection() {
    return _buildCategoryGroup(
      id: 'tasks',
      title: '📋 Task Center',
      icon: Icons.task_alt_outlined,
      children: [
        _buildFeatureTile(
          title: 'XP Progress',
          subtitle: 'Level 25 • 1850 / 3000 XP',
          trailing: const SizedBox(
            width: 100,
            child: LinearProgressIndicator(
              value: 1850 / 3000,
              backgroundColor: Colors.white10,
              color: Color(0xFF8B5CF6),
              minHeight: 4,
            ),
          ),
        ),
        const Divider(color: Colors.white10),
        _buildFeatureTile(
          title: 'Daily Streak',
          subtitle: '5 Days Active Streak 🔥',
          trailing: const Text('+10% XP Boost', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        const Divider(color: Colors.white10),
        _buildFeatureTile(
          title: 'My Tasks',
          subtitle: '2 active daily tasks remaining',
          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
          onTap: () => _showTasksDialog(),
        ),
        const Divider(color: Colors.white10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => _showTasksDialog(),
              child: const Text('Completed Tasks', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11)),
            ),
            TextButton(
              onPressed: () => _showTasksDialog(),
              child: const Text('Pending Tasks', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11)),
            ),
            TextButton(
              onPressed: () {
                Get.snackbar('Achievements', 'Achievement rewards already claimed.', snackPosition: SnackPosition.BOTTOM);
              },
              child: const Text('Achievement Rewards', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11)),
            ),
          ],
        )
      ],
    );
  }

  // --- SECTION 7: REFERRAL CENTER ---
  Widget _buildReferralSection() {
    return _buildCategoryGroup(
      id: 'referrals',
      title: '👥 Referral Center',
      icon: Icons.people_outline_rounded,
      children: [
        _buildFeatureTile(
          title: 'Invite Friends',
          subtitle: 'Earn 10% commission on friend recharges',
          trailing: ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: 'AGX-783-DEV'));
              Get.snackbar(
                'Copied Code 🔗',
                'Referral code copied to clipboard!',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFF8B5CF6),
                colorText: Colors.white,
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 10, color: Colors.white),
            label: const Text('AGX-783-DEV', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1B4B),
              minimumSize: const Size(80, 28),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const Divider(color: Colors.white10),
        _buildFeatureTile(
          title: 'Referral Earnings',
          subtitle: 'Total Earned: \$115.00',
          trailing: const Text('Available: \$25.00', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const Divider(color: Colors.white10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                Get.snackbar('Referral History', 'You have referred 14 friends successfully.', snackPosition: SnackPosition.BOTTOM);
              },
              child: const Text('Referral History', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11)),
            ),
            TextButton(
              onPressed: () {
                Get.snackbar('Leaderboard', 'Referral Leaderboard is updated weekly.', snackPosition: SnackPosition.BOTTOM);
              },
              child: const Text('Referral Leaderboard', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11)),
            ),
          ],
        )
      ],
    );
  }

  // --- SECTION 8: CREATOR & AGENCY (WITH LOCKED CHECK) ---
  Widget _buildCreatorAgencySection() {
    return Obx(() {
      final isEligible = _isCreatorEligible.value;

      return _buildCategoryGroup(
        id: 'creator',
        title: '🎤 Creator & Agency',
        icon: Icons.mic_external_on_outlined,
        badge: !isEligible ? const Icon(Icons.lock_rounded, color: Colors.white30, size: 14) : null,
        children: [
          if (!isEligible) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_rounded, color: Color(0xFFEF4444), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Locked Section',
                        style: GoogleFonts.outfit(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Eligibility requirements:\n• Reached ID Level 20+ (Your Level: 25)\n• Have 10,000+ Followers (Your Followers: 150K)\n• Official verification approved (Status: Pending)',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '*Toggle eligibility using the Developer Panel at the bottom to view unlocked features.',
                    style: TextStyle(color: Colors.white30, fontSize: 8, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildFeatureTile(
              title: 'Creator Dashboard',
              subtitle: 'Manage streams, analytics, and payouts',
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
              onTap: () => _showCreatorDashboard(),
            ),
            const Divider(color: Colors.white10),
            _buildFeatureTile(
              title: 'Agency Dashboard',
              subtitle: 'Host & agency management interface',
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
              onTap: () => _showAgencyDashboard(),
            ),
            const Divider(color: Colors.white10),
            _buildFeatureTile(
              title: 'My Arenas',
              subtitle: '3 owned active voice arenas',
              trailing: const Text('Configure', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11)),
            ),
            const Divider(color: Colors.white10),
            _buildFeatureTile(
              title: 'My Events',
              subtitle: '1 scheduled live webinar event',
              trailing: const Text('Manage', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11)),
            ),
            const Divider(color: Colors.white10),
            _buildFeatureTile(
              title: 'My Communities',
              subtitle: 'Manage community moderator settings',
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
            ),
            const Divider(color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Get.snackbar('Earnings', 'Host earnings total: \$720.00 this month.', snackPosition: SnackPosition.BOTTOM);
                  },
                  child: const Text('Host Earnings', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11)),
                ),
                TextButton(
                  onPressed: () {
                    Get.snackbar('Analytics', 'Analytics updated daily at midnight PST.', snackPosition: SnackPosition.BOTTOM);
                  },
                  child: const Text('Creator Analytics', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11)),
                ),
              ],
            )
          ]
        ],
      );
    });
  }

  // --- SECTION 9: HISTORY ---
  Widget _buildHistorySection() {
    return _buildCategoryGroup(
      id: 'history',
      title: '📜 History',
      icon: Icons.history_edu_outlined,
      children: [
        _buildFeatureTile(
          title: 'Coin Transactions',
          subtitle: 'All Gold and Silver coin history',
          onTap: () => _showWalletHistoryDialog(),
        ),
        const Divider(color: Colors.white10),
        _buildFeatureTile(
          title: 'Purchase History',
          subtitle: 'VIP, Novel, and cosmetic buys',
          onTap: () => _showOrdersDialog(),
        ),
        const Divider(color: Colors.white10),
        _buildFeatureTile(
          title: 'Gift History',
          subtitle: 'Sent and received gift records',
          onTap: () => _showGiftHistoryDialog(),
        ),
        const Divider(color: Colors.white10),
        _buildFeatureTile(
          title: 'Recharge History',
          subtitle: 'Cash to coin recharge orders',
          onTap: () => _showRechargeHistoryDialog(),
        ),
        const Divider(color: Colors.white10),
        _buildFeatureTile(
          title: 'Withdrawal History',
          subtitle: 'Income withdrawal bank payouts',
          onTap: () => _showWithdrawalHistoryDialog(),
        ),
        const Divider(color: Colors.white10),
        _buildFeatureTile(
          title: 'Event & Task History',
          subtitle: 'Host rewards & completed tasks logs',
          onTap: () => _showTaskHistoryDialog(),
        ),
      ],
    );
  }

  // --- SECTION 10: SUPPORT ---
  Widget _buildSupportSection() {
    return _buildCategoryGroup(
      id: 'support',
      title: '🆘 Support',
      icon: Icons.support_agent_outlined,
      children: [
        _buildFeatureTile(
          title: 'Help Center',
          subtitle: 'Browse documentation & guides',
          onTap: () => _showFaqDialog(),
        ),
        const Divider(color: Colors.white10),
        _buildFeatureTile(
          title: 'Contact Support',
          subtitle: 'Open a live chat ticket with us',
          onTap: () => _showContactSupportDialog(),
        ),
        const Divider(color: Colors.white10),
        _buildFeatureTile(
          title: 'Report Problem',
          subtitle: 'Submit bug reports & arena abuse logs',
          onTap: () => _showReportDialog(),
        ),
        const Divider(color: Colors.white10),
        _buildFeatureTile(
          title: 'FAQs',
          subtitle: 'Frequently Asked Questions',
          onTap: () => _showFaqDialog(),
        ),
      ],
    );
  }

  // --- FEATURE TILE BUILDER ---
  Widget _buildFeatureTile({
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  // --- DEV PANEL TESTER (ELIGIBILITY SWITCH) ---
  Widget _buildDevPanel() {
    return Card(
      color: const Color(0xFF1E1E28).withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🛠️ DEVELOPER TESTING PANEL',
              style: GoogleFonts.outfit(color: const Color(0xFFA78BFA), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Creator Section Eligibility',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Toggle to lock/unlock Creator & Agency',
                        style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                Obx(() {
                  return Switch(
                    value: _isCreatorEligible.value,
                    onChanged: (v) {
                      _isCreatorEligible.value = v;
                    },
                    activeColor: const Color(0xFF8B5CF6),
                  );
                }),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- DIALOG POPUPS & SHEETS (interactive simulation) ---

  // Order history
  void _showOrdersDialog() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F16),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order History & Purchases', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildHistoryItem('Neon Frame (Animated)', '-\$5.99', 'Purchased • 30 Days', 'Completed'),
            _buildHistoryItem('500 Coins Bundle', '-\$4.99', 'Recharge • Wallet Credit', 'Completed'),
            _buildHistoryItem('VIP 3 Upgrade', '-\$12.99', 'Membership • 30 Days', 'Completed'),
            _buildHistoryItem('Gold Glow Frame', '-\$2.99', 'Purchased • 7 Days', 'Completed'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                child: const Text('Close'),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Active coupons list
  void _showCouponsDialog() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F16),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Active Store Coupons', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildCouponItem('FESTIVAL50', '50% Discount on all store cosmetics', 'Valid till: 30 Jul'),
            _buildCouponItem('CREATOR10', '10% Discount on VIP purchases', 'Valid till: 15 Aug'),
            _buildCouponItem('STUDENT20', '20% Discount on Novel volumes', 'Valid till: 10 Sep'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                child: const Text('Close'),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Redeem code dialog
  void _showRedeemDialog() {
    final textController = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF13131A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Redeem Promo Code', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter code (e.g. FESTIVAL50)',
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel', style: TextStyle(color: Colors.white30))),
          ElevatedButton(
            onPressed: () {
              final code = textController.text.trim().toUpperCase();
              if (code.isEmpty) return;
              Get.back();
              if (code == 'FESTIVAL50' || code == 'CREATOR10' || code == 'STUDENT20') {
                Get.snackbar(
                  'Code Redeemed 🏷️',
                  'Coupon code $code applied successfully! Use it at checkout.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: const Color(0xFF10B981),
                  colorText: Colors.white,
                );
              } else {
                Get.snackbar(
                  'Redemption Failed ⚠️',
                  'Invalid or expired code. Please try another.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: const Color(0xFFEF4444),
                  colorText: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
  }

  // Recharge coins
  void _showRechargeDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF13131A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Recharge Wallet', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'Recharge options are integrated through Razorpay. You can buy Gold Packs inside the store.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel', style: TextStyle(color: Colors.white30))),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.to(() => const StoreHomeScreen());
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Go to Store'),
          ),
        ],
      ),
    );
  }

  // Withdraw wallet cash
  void _showWithdrawDialog() {
    _showIncomeWithdrawDialog();
  }

  // Transfer coins to friend
  void _showTransferDialog() {
    final userController = TextEditingController();
    final amountController = TextEditingController();

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF13131A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Transfer Coins to Friend', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Recipient Username',
                hintStyle: TextStyle(color: Colors.white24),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Amount (Gold Coins)',
                hintStyle: TextStyle(color: Colors.white24),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel', style: TextStyle(color: Colors.white30))),
          ElevatedButton(
            onPressed: () {
              final user = userController.text.trim();
              final amtVal = int.tryParse(amountController.text) ?? 0;
              
              if (user.isEmpty || amtVal <= 0) return;
              if (amtVal > _storeCtrl.coinsBalance.value) {
                Get.back();
                Get.snackbar('Transfer Error ⚠️', 'Insufficient balance.', snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFFEF4444), colorText: Colors.white);
                return;
              }

              _storeCtrl.coinsBalance.value -= amtVal;
              _storeCtrl.coinTransactions.insert(0, CoinTransaction(
                type: 'Used',
                amount: amtVal,
                description: 'Transferred $amtVal Gold to @$user',
                dateTime: DateTime.now(),
              ));
              Get.back();
              Get.snackbar(
                'Transfer Successful 💸',
                '$amtVal Gold Coins transferred to $user successfully!',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFF10B981),
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
  }


  // Income Withdraw
  void _showIncomeWithdrawDialog() {
    final amtController = TextEditingController();
    String selectedMethod = 'UPI Address';

    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF13131A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Withdraw Diamonds', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() {
                  return Text(
                    'Available Diamonds: ${_storeCtrl.diamondsBalance.value} 💎 (₹${_storeCtrl.diamondsBalance.value})',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  );
                }),
                const SizedBox(height: 12),
                const Text(
                  'Withdrawal Rules:\n• Min withdrawal is 1000 Diamonds (₹1000).\n• 1 Diamond = ₹1 INR.',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amtController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Withdrawal Amount (Diamonds)',
                    labelStyle: TextStyle(color: Colors.white30, fontSize: 11),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF10B981))),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  dropdownColor: const Color(0xFF13131A),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Payout Method',
                    labelStyle: TextStyle(color: Colors.white30, fontSize: 11),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'UPI Address', child: Text('UPI Address (GPay/PhonePe)')),
                    DropdownMenuItem(value: 'Bank Transfer', child: Text('Direct Bank Transfer (HDFC)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedMethod = val;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('Cancel', style: TextStyle(color: Colors.white30))),
              ElevatedButton(
                onPressed: () {
                  final val = int.tryParse(amtController.text) ?? 0;
                  if (val < 1000) {
                    Get.snackbar('Withdraw Error ⚠️', 'Minimum withdrawal is 1000 Diamonds.', snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFFEF4444), colorText: Colors.white);
                    return;
                  }
                  
                  final success = _storeCtrl.requestDiamondWithdrawal(val, selectedMethod, 'anurag@ybl');
                  if (success) {
                    Get.back();
                    Get.snackbar(
                      'Withdrawal Requested 💵',
                      'Your withdrawal of ₹$val INR (using $selectedMethod) has been requested.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: const Color(0xFF10B981),
                      colorText: Colors.white,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                child: const Text('Request Payout'),
              ),
            ],
          );
        }
      ),
    );
  }

  // Link payment accounts
  void _showPaymentAccountsDialog() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F16),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Linked Payment Accounts', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildLinkedAccountItem('PayPal Account', 'anurag.dev@gmail.com', true),
            _buildLinkedAccountItem('Bank Account (HDFC)', '**** **** 8245', false),
            _buildLinkedAccountItem('UPI Address', 'anurag@ybl', false),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Get.back();
                  Get.snackbar('Link Account', 'Linking page coming soon!', snackPosition: SnackPosition.BOTTOM);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                child: const Text('+ Link New Account'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedAccountItem(String type, String val, bool isPrimary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C24),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(type, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Text(val, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
            ],
          ),
          if (isPrimary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: const Text('Primary', style: TextStyle(color: Color(0xFF10B981), fontSize: 8, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // Wallet history transactions list
  void _showWalletHistoryDialog() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F16),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Coin Transactions History', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildHistoryItem('Daily Reward Claimed', '+50 Gold', 'Claimed reward coins', 'Success'),
            _buildHistoryItem('Dragon Wings Aura unlock', '-300 Gold', 'Cosmetics unlock purchase', 'Success'),
            _buildHistoryItem('Referral Bonus Coins', '+100 Gold', 'Friend signup commission', 'Success'),
            _buildHistoryItem('Vip 3 subscription gift', '+500 Gold', 'Bonus gift for subscribing', 'Success'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                child: const Text('Close'),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Withdrawal history transactions list
  void _showWithdrawalHistoryDialog() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F16),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Withdrawal History', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildHistoryItem('PayPal Payout P-9428', '\$100.00', 'Pending • Processing payout', 'Processing'),
            _buildHistoryItem('Bank Account H-2940', '\$150.00', 'Transferred • 04 Jun', 'Completed'),
            _buildHistoryItem('PayPal Payout P-8392', '\$50.00', 'Transferred • 12 May', 'Completed'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                child: const Text('Close'),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Tasks dialog
  void _showTasksDialog() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F16),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Active Task Center', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildTaskTile('Host a voice arena for 30 mins', '+200 XP • +50 Gold', true),
            _buildTaskTile('Comment on 5 trending posts', '+100 XP • +10 Gold', false),
            _buildTaskTile('Send a gift to any co-host speaker', '+150 XP • +30 Gold', true),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                child: const Text('Close'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTile(String desc, String rewards, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C24),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                Text(rewards, style: GoogleFonts.poppins(color: const Color(0xFFA78BFA), fontSize: 9)),
              ],
            ),
          ),
          Icon(
            isCompleted ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
            color: isCompleted ? const Color(0xFF10B981) : Colors.white24,
            size: 18,
          ),
        ],
      ),
    );
  }

  // FAQ support dialog
  void _showFaqDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF13131A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Frequently Asked Questions', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildFaqItem('How do I upgrade to VIP?', 'You can join or extend VIP levels in the store using Gold Coins or Razorpay.'),
              _buildFaqItem('What is the Creator Program?', 'Users with Level 20+ and 10k+ followers can unlock Stream payouts and Agency share earnings.'),
              _buildFaqItem('When is income payout processed?', 'Payouts to bank accounts or PayPal are processed every Friday.'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String q, String a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Q: $q', style: GoogleFonts.poppins(color: const Color(0xFFA78BFA), fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(a, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  // Contact support dialog
  void _showContactSupportDialog() {
    final txtController = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF13131A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Contact Live Support', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter message describing your issue. Support response time is typically <12 hours.', style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 8),
            TextField(
              controller: txtController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Describe issue...',
                hintStyle: TextStyle(color: Colors.white24),
                border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel', style: TextStyle(color: Colors.white30))),
          ElevatedButton(
            onPressed: () {
              if (txtController.text.trim().isEmpty) return;
              Get.back();
              Get.snackbar('Ticket Opened 📩', 'Support ticket opened successfully. Reference: #AGX-${DateTime.now().millisecond}', snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Send Message'),
          ),
        ],
      ),
    );
  }

  // Report issue dialog
  void _showReportDialog() {
    final txtController = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF13131A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Report Abuse / Bug', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: txtController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter bug details or user ID to report...',
                hintStyle: TextStyle(color: Colors.white24),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel', style: TextStyle(color: Colors.white30))),
          ElevatedButton(
            onPressed: () {
              if (txtController.text.trim().isEmpty) return;
              Get.back();
              Get.snackbar('Report Submitted 🛡️', 'Thank you for reporting. Our moderation team will investigate.', snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  // Dummy methods for dialog builders
  Widget _buildHistoryItem(String title, String amt, String desc, String status) {
    Color statColor = const Color(0xFF10B981);
    if (status == 'Failed' || status == 'Processing') {
      statColor = const Color(0xFFEF4444);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF161620), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                Text(desc, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amt, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              Text(status, style: TextStyle(color: statColor, fontSize: 8, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCouponItem(String code, String desc, String valDate) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1C1C24), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.1))),
      child: Row(
        children: [
          const Icon(Icons.confirmation_number_outlined, color: Color(0xFFA78BFA), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(code, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                Text(desc, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 9)),
                Text(valDate, style: GoogleFonts.poppins(color: Colors.white24, fontSize: 8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGiftHistoryDialog() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F16),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sent & Received Gifts', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildHistoryItem('Rose Gift 🌹 from sky_limit', '+\$2.50', 'Received in Voice Arena #12', 'Success'),
            _buildHistoryItem('Crown Castle 🏰 to anurag_dev', '-\$15.00', 'Sent in Voice Arena #24', 'Success'),
            _buildHistoryItem('Love Balloon 🎈 from user_482', '+\$1.20', 'Received in Private Message', 'Success'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                child: const Text('Close'),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showRechargeHistoryDialog() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F16),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recharge Orders Log', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildHistoryItem('1000 Gold Coins Recharge', '+\$9.99', 'Razorpay Order ID: pay_9428', 'Completed'),
            _buildHistoryItem('2500 Gold Coins Recharge', '+\$24.99', 'Razorpay Order ID: pay_2841', 'Completed'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                child: const Text('Close'),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showTaskHistoryDialog() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F16),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Completed Milestones History', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildHistoryItem('Host for 30 minutes', '+200 XP • +50 Gold', 'Daily task reward', 'Success'),
            _buildHistoryItem('Reach ID Level 25 milestone', '+1000 XP • +100 Gold', 'Milestone reward achievement', 'Success'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                child: const Text('Close'),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showRewardHistoryDialog() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F16),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Claimed Rewards History', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildHistoryItem('Daily Login Bonus', '+50 Gold Coins', 'Day 5 Streak claim', 'Success'),
            _buildHistoryItem('Lucky Draw Spin Win', '3 Days VIP', 'Spin Wheel reward', 'Success'),
            _buildHistoryItem('Promo Code FESTIVAL50', '50% Off Store Coupon', 'Redeemed promo code', 'Success'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                child: const Text('Close'),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showCreatorDashboard() {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF13131A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Creator Dashboard', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back, Creator!', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('• Live streams hosted: 14\n• Total viewers: 42,800\n• Diamonds earned: 8,420\n• Current status: Active & Verified', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 12),
            const Text('Your monthly creator payout will be automatically credited to PayPal.', style: TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAgencyDashboard() {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF13131A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Agency Dashboard', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agency: Creania Talent Network', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('• Registered host count: 8\n• Active hosts streaming: 3\n• Today\'s agency commission: \$12.40\n• Current monthly agency tier: Gold (2.5%)', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
