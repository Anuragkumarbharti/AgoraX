import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:creania/core/theme.dart';
import 'package:get/get.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Terms & Privacy Policy',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.primaryColor.withOpacity(0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const SizedBox(),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryColor.withOpacity(0.06),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: const SizedBox(),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subtitle / Intro text
                  Text(
                    'Creaniaa Platform Guidelines',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Effective Date: July 19, 2026. Please read these terms carefully before connecting or creating on the Creaniaa platform.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: context.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildTermCard(
                    context: context,
                    icon: Icons.assignment_turned_in_rounded,
                    title: '1. Acceptance of Terms',
                    content: 'Welcome to Creaniaa. By registering an account, starting voice rooms, joining community circles, or posting educational materials, you agree to bound by all of these Terms of Service. If you do not agree, you must immediately delete or deactivate your account.',
                  ),
                  _buildTermCard(
                    context: context,
                    icon: Icons.gavel_rounded,
                    title: '2. Community Conduct & Guidelines',
                    content: 'Creaniaa is an interactive voice ecosystem. Harassment, verbal abuse, toxic discussions, copyright infringement, spam, and adult/sensitive content are strictly forbidden. Moderation decisions are final and breaking rules will lead to instant, permanent bans with no refunds.',
                  ),
                  _buildTermCard(
                    context: context,
                    icon: Icons.security_rounded,
                    title: '3. Study Vault & Anti-Piracy DRM',
                    content: 'All educational notes, mock exams, capstone projects, and resources uploaded in the Study Vault are protected. We implement dynamic, personalized watermarking containing your account details (IP, User ID, name) to prevent piracy. Downloading materials is only supported for purchased items and offline caches are encrypted. Clipboard sharing is disabled inside the secure reader view.',
                  ),
                  _buildTermCard(
                    context: context,
                    icon: Icons.monetization_on_rounded,
                    title: '4. Creator Payouts & VIP Memberships',
                    content: 'VIP and Novel memberships receive percentage discounts and unlock access to official materials subject to daily unique book limits. User-to-creator payouts are governed by a platform split (taxes + gateway fee + platform fee). Real gold coins credited from rewards cannot be directly converted to INR withdrawable balances unless specified under creator revenue splits.',
                  ),
                  _buildTermCard(
                    context: context,
                    icon: Icons.phonelink_ring_rounded,
                    title: '5. Privacy & Data Encryption',
                    content: 'We encrypt private direct messages client-side using standard end-to-end encryption protocols. Your voice room coordinates are served securely. We do not sell or leak your student profiling details, interests, or credentials to third-party ad networks.',
                  ),
                  _buildTermCard(
                    context: context,
                    icon: Icons.contact_support_rounded,
                    title: '6. Support & Inquiries',
                    content: 'For questions regarding payments, refunds, reports, copyright complaints, or account queries, you can reach out to our team at support@creaniaa.com or file a report within the app settings panel.',
                  ),
                  const SizedBox(height: 24),

                  Center(
                    child: Text(
                      'Thank you for keeping Creaniaa a safe and educational space! 🚀',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.accentOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor, width: 1),
        boxShadow: context.smallShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: context.primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: context.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
