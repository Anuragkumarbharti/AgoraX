import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../core/theme.dart';
import '../../services/store_controller.dart';
import '../../services/razorpay_backend_service.dart';

class AdminStorePanel extends StatefulWidget {
  const AdminStorePanel({Key? key}) : super(key: key);

  @override
  State<AdminStorePanel> createState() => _AdminStorePanelState();
}

class _AdminStorePanelState extends State<AdminStorePanel> {
  final StoreController _storeCtrl = Get.find<StoreController>();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController();

  final List<String> products = [
    'Ice Dragon Avatar Frame', 'Celestial Phoenix Frame', 'Cyberpunk Glowing Border',
    'Sakura Entrance Portal Effect', 'VIP Golden Crown Seat', 'Galaxy Wings Aura Decor'
  ];

  @override
  void dispose() {
    _codeCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070A),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSalesStatsOverview(),
                        const SizedBox(height: 20),
                        _buildRevenueMockChart(),
                        const SizedBox(height: 24),
                        _buildFlashSaleToggleCard(),
                        const SizedBox(height: 20),
                        _buildPricingModifierSlider(),
                        const SizedBox(height: 24),
                        _buildCouponManagementCard(),
                        const SizedBox(height: 24),
                        _buildProductControlCard(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                )
              ],
            ),
          )
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
            'ADMIN COMMAND CONSOLE',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 2,
              color: const Color(0xFFFFD700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesStatsOverview() {
    return Obx(() {
      final orders = RazorpayBackendService.to.dbOrders;
      
      double totalRev = 0;
      int successCount = 0;
      int pendingCount = 0;
      int failedCount = 0;
      int refundReqCount = 0;
      
      int coinPurchases = 0;
      int vipPurchases = 0;
      int novelPurchases = 0;

      for (var o in orders) {
        if (o.status == 'Success') {
          totalRev += o.amount;
          successCount++;
          if (o.product.contains('Coins')) {
            coinPurchases++;
          } else if (o.product.contains('VIP')) {
            vipPurchases++;
          } else if (o.product.contains('Novel')) {
            novelPurchases++;
          }
        } else if (o.status == 'Pending') {
          pendingCount++;
        } else if (o.status == 'Failed') {
          failedCount++;
        } else if (o.status == 'Refund Requested' || o.status == 'Refunded') {
          refundReqCount++;
        }
      }

      return Column(
        children: [
          // Mode Switcher Banner
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.yellow.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.yellow.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.toggle_on_rounded, color: Colors.yellow, size: 20),
                    const SizedBox(width: 8),
                    Text('GATEWAY MODE', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => RazorpayBackendService.to.setMode('Test'),
                      child: Obx(() => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: RazorpayBackendService.to.activeMode.value == 'Test' ? Colors.yellow : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('TEST', style: GoogleFonts.poppins(color: RazorpayBackendService.to.activeMode.value == 'Test' ? Colors.black : Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                      )),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => RazorpayBackendService.to.setMode('Live'),
                      child: Obx(() => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: RazorpayBackendService.to.activeMode.value == 'Live' ? Colors.redAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('LIVE', style: GoogleFonts.poppins(color: RazorpayBackendService.to.activeMode.value == 'Live' ? Colors.white : Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                      )),
                    ),
                  ],
                )
              ],
            ),
          ),

          // Total Stats
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF111115),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('VERIFIED REVENUE', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                          const SizedBox(height: 4),
                          Text('₹${totalRev.toStringAsFixed(2)}', style: GoogleFonts.poppins(color: const Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.white10),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SETTLED ORDERS', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                          const SizedBox(height: 4),
                          Text('$successCount orders', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 24),
                // Detailed breakdown grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _subStat('Coins', '$coinPurchases'),
                    _subStat('VIP', '$vipPurchases'),
                    _subStat('Novel', '$novelPurchases'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _subStat('Pending', '$pendingCount', color: Colors.amberAccent),
                    _subStat('Failed', '$failedCount', color: Colors.redAccent),
                    _subStat('Refunds', '$refundReqCount', color: Colors.cyanAccent),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _subStat(String label, String value, {Color color = Colors.white70}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(color: Colors.white24, fontSize: 9.5)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.poppins(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRevenueMockChart() {
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
          Text('WEEKLY STORE METRICS CHART', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _barItem('Mon', 0.4, const Color(0xFF8B5CF6)),
                _barItem('Tue', 0.6, const Color(0xFF8B5CF6)),
                _barItem('Wed', 0.35, const Color(0xFF8B5CF6)),
                _barItem('Thu', 0.8, const Color(0xFFD946EF)),
                _barItem('Fri', 0.55, const Color(0xFF8B5CF6)),
                _barItem('Sat', 0.95, const Color(0xFFFFD700)),
                _barItem('Sun', 0.75, const Color(0xFF8B5CF6)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _barItem(String label, double fillFactor, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 16,
          height: 80 * fillFactor,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.3), blurRadius: 6)
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9)),
      ],
    );
  }

  Widget _buildFlashSaleToggleCard() {
    return Obx(() {
      final active = _storeCtrl.isFlashSaleActive.value;
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF111115),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: active ? const Color(0xFFD946EF).withOpacity(0.4) : Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LAUNCH STORE-WIDE FLASH SALE', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Applies an instant 35% discount to all checkout screens.', style: GoogleFonts.poppins(color: Colors.white24, fontSize: 10)),
                ],
              ),
            ),
            Switch(
              value: active,
              onChanged: (v) => _storeCtrl.toggleFlashSale(v),
              activeColor: const Color(0xFFD946EF),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPricingModifierSlider() {
    return Obx(() {
      final val = _storeCtrl.priceModifier.value;
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('GLOBAL PRICE MODIFIER', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                Text('${(val * 100).toInt()}%', style: GoogleFonts.poppins(color: const Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Modify prices globally (e.g. increase for inflation or decrease for sales).', style: GoogleFonts.poppins(color: Colors.white24, fontSize: 9.5)),
            const SizedBox(height: 12),
            Slider(
              value: val,
              min: 0.5,
              max: 1.5,
              divisions: 10,
              onChanged: (v) => _storeCtrl.setPriceModifier(v),
              activeColor: const Color(0xFF8B5CF6),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCouponManagementCard() {
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
          Text('COUPON & PROMO MANAGEMENT', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _codeCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'CODE (e.g. FESTIVAL50)',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _discountCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'DISCOUNT % (e.g. 50)',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: () {
                  final code = _codeCtrl.text.toUpperCase().trim();
                  final disc = double.tryParse(_discountCtrl.text.trim());
                  if (code.isNotEmpty && disc != null) {
                    _storeCtrl.couponCodes[code] = disc / 100.0;
                    _codeCtrl.clear();
                    _discountCtrl.clear();
                    setState(() {});
                    Get.snackbar('Success', 'Promo Coupon $code created successfully!', snackPosition: SnackPosition.BOTTOM);
                  }
                },
                child: Text('Add', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('ACTIVE COUPONS LIST', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 8.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Obx(() {
            final codes = _storeCtrl.couponCodes;
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: codes.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.key, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Text('(${(e.value * 100).toInt()}% off)', style: GoogleFonts.poppins(color: const Color(0xFFFFD700), fontSize: 9.5)),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProductControlCard() {
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
          Text('COSMETIC CATALOG CONTROLS', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final prod = products[index];
              return Obx(() {
                final isDisabled = _storeCtrl.disabledProducts.contains(prod);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(prod, style: GoogleFonts.poppins(color: isDisabled ? Colors.white24 : Colors.white70, fontSize: 11.5)),
                      Switch(
                        value: !isDisabled,
                        onChanged: (v) {
                          if (v) {
                            _storeCtrl.enableProduct(prod);
                          } else {
                            _storeCtrl.disableProduct(prod);
                          }
                        },
                        activeColor: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                );
              });
            },
          ),
        ],
      ),
    );
  }
}
