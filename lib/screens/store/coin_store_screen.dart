import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:creania/core/theme.dart';
import '../../services/store_controller.dart';
import 'checkout_screen.dart';

class CoinStoreScreen extends StatelessWidget {
  const CoinStoreScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final StoreController storeCtrl = Get.find<StoreController>();

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Gradient Glows
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFFD700).withOpacity(0.08),
                    blurRadius: 100,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF8B5CF6).withOpacity(0.08),
                    blurRadius: 120,
                  )
                ],
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: context.scaffoldBackgroundColor.withOpacity(0.85),
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 18),
                    onPressed: () => Get.back(),
                  ),
                  title: Text(
                    'COIN STORE',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                  actions: [
                    Obx(() => Container(
                          margin: EdgeInsets.only(right: 16, top: 12, bottom: 12),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Center(
                            child: Text(
                              '🪙 ${storeCtrl.coinsBalance.value}',
                              style: GoogleFonts.poppins(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        )),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopOffersBanner(),
                        SizedBox(height: 20),
                        Text(
                          'SELECT A COIN PACK',
                          style: GoogleFonts.outfit(color: Colors.white60, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.5),
                        ),
                        SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final pack = storeCtrl.coinPacks[index];
                        return _buildCoinPackCard(context, pack);
                      },
                      childCount: storeCtrl.coinPacks.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopOffersBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Color(0xFF1E1B4B),
            Color(0xFF0F172A).withOpacity(0.9),
          ],
        ),
        border: Border.all(color: Color(0xFFFFD700).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text('🔥', style: TextStyle(fontSize: 32)),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FIRST PURCHASE BONUS!',
                  style: GoogleFonts.outfit(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                SizedBox(height: 2),
                Text(
                  'Get double bonus coins on packs above ₹799.',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinPackCard(BuildContext context, CoinPack pack) {
    final themeColor = pack.isSpecial ? Color(0xFFFFD700) : Color(0xFF8B5CF6);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: context.secondaryBackgroundColor.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: pack.tag != null ? themeColor.withOpacity(0.4) : context.borderColor,
              width: pack.tag != null ? 1.5 : 1.0,
            ),
          ),
          child: Stack(
            children: [
              if (pack.tag != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: themeColor,
                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10)),
                    ),
                    child: Text(
                      pack.tag!,
                      style: GoogleFonts.poppins(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pack.name,
                          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('🪙', style: TextStyle(fontSize: 22)),
                            SizedBox(width: 4),
                            Text(
                              pack.coins.toString(),
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        if (pack.bonusCoins > 0)
                          Container(
                            margin: EdgeInsets.only(top: 6),
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(0xFF10B981).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+${pack.bonusCoins} Bonus Coins',
                              style: GoogleFonts.poppins(color: Color(0xFF34D399), fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GST Included',
                          style: GoogleFonts.poppins(color: Colors.white24, fontSize: 8),
                        ),
                        SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: pack.isSpecial ? Color(0xFFFFD700) : Color(0xFF1E1B4B),
                              side: BorderSide(color: themeColor.withOpacity(0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () {
                              Get.to(() => CheckoutScreen(
                                    productName: pack.name,
                                    category: 'Coins',
                                    basePrice: pack.price,
                                    duration: 'One-Time',
                                  ));
                            },
                            child: Text(
                              '₹${pack.price.toInt()}',
                              style: GoogleFonts.poppins(
                                color: pack.isSpecial ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
