import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/novel_controller.dart';
import 'novel_purchase_screen.dart';

class NovelExpiredScreen extends StatelessWidget {
  const NovelExpiredScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final NovelController novelCtrl = Get.find<NovelController>();

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        title: Text(
          'COLLECTIBLE EXPIRED',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.0, -0.4),
            radius: 1.2,
            colors: [
              Colors.red.withOpacity(0.08),
              const Color(0xFF09090B),
            ],
            stops: const [0.0, 0.6],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Expired lock emblem icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.01),
                border: Border.all(color: Colors.white12, width: 2),
              ),
              child: const Center(
                child: Icon(
                  Icons.lock_person_rounded,
                  color: Colors.white30,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Header text
            Text(
              'Novel Customizations Deactivated',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your prestigious Novel status has expired, and all active borders, badges, and chat customizations have been set back to normal.',
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Grace period card info
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'NO GRACE PERIOD LEFT',
                        style: GoogleFonts.outfit(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'All exclusive benefits like daily reward multipliers, lucky spins, and chat themes are locked. Renew now to restore your legendary status.',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Spacer(),

            // Action buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Get.back();
                  Get.to(() => const NovelPurchaseScreen());
                },
                child: Text(
                  'Renew Novel Membership',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                'Explore other features',
                style: GoogleFonts.poppins(
                  color: Colors.white30,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
