import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/vip_controller.dart';
import 'vip_purchase_screen.dart';

class VipExpiredScreen extends StatelessWidget {
  const VipExpiredScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final VipController vipCtrl = Get.find<VipController>();
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Obx(() {
        final remaining = vipCtrl.getRemainingTime();
        final bool inGrace = vipCtrl.isGracePeriodActive.value;
        final int graceDays = vipCtrl.gracePeriodDaysLeft.value;

        return Stack(
          children: [
            // 1. Decorative steel background gradients
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.02),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              right: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.015),
                ),
              ),
            ),

            // 2. Core Layout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Shield/broken crown icon
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 1.5),
                    ),
                    child: const Center(
                      child: Text(
                        '🛡️',
                        style: TextStyle(fontSize: 44),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Header Titles
                  Text(
                    'VIP Membership Expired',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your premium VIP status has ended. Renew now to reclaim your high-value perks.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Grace Period Warning Card
                  if (inGrace)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1.2),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'ACTIVE GRACE PERIOD',
                                style: GoogleFonts.outfit(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Your VIP borders, badges, and benefits are preserved temporarily. You have $graceDays days left in the grace period before all customizations are removed.',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        'All VIP customizations (avatar frames, username gradients, chat bubbles) have been deactivated and locked.',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 40),

                  // lost perks checklist summary
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'PERKS YOU ARE MISSING:',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white38,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLostPerkRow('Premium Profile Borders & Frames'),
                  _buildLostPerkRow('Up to 35% Coin Purchase Bonus'),
                  _buildLostPerkRow('Voice Room Join Announcement banner'),
                  _buildLostPerkRow('VIP 1-7 Badges shown in Chat, Seat & Comments'),

                  const SizedBox(height: 48),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37), // Luxury Gold
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        // Navigate directly to purchase
                        Get.off(() => const VipPurchaseScreen());
                      },
                      child: Text(
                        'Renew Membership Now',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text(
                      'Cancel and Go Back',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildLostPerkRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          const Icon(Icons.close_rounded, color: Colors.white30, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
