import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class LegalTermsScreen extends StatefulWidget {
  final int initialTabIndex;
  const LegalTermsScreen({Key? key, this.initialTabIndex = 0}) : super(key: key);

  @override
  State<LegalTermsScreen> createState() => _LegalTermsScreenState();
}

class _LegalTermsScreenState extends State<LegalTermsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Legal Information',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.primaryColor,
          labelColor: context.primaryColor,
          unselectedLabelColor: context.textSecondary,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Terms of Service'),
            Tab(text: 'Privacy Policy'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTermsView(),
          _buildPrivacyView(),
        ],
      ),
    );
  }

  Widget _buildTermsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Creania Terms of Service',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Effective Date: August 11, 2026',
            style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('1. Acceptance of Terms'),
          _buildParagraph(
              'By accessing or using the Creania application, voice communities, Study Vault marketplace, or services, you agree to be bound by these Terms of Service. If you do not agree to these terms, do not use the service.'),
          _buildSectionTitle('2. User Conduct & Community Guidelines'),
          _buildParagraph(
              'Creania fosters a safe, supportive learning and voice community environment. Hate speech, harassment, piracy of educational resources, unauthorized automated bot access, and fraudulent gifting or coin exploitation are strictly prohibited and result in permanent account termination.'),
          _buildSectionTitle('3. Virtual Items & Economy Rules'),
          _buildParagraph(
              'Creania Balance (CB), Gold Coins, and Diamond balances represent digital utility assets within the application ecosystem. Virtual currencies are non-refundable except where explicitly required by law or wallet withdrawal rules.'),
          _buildSectionTitle('4. Study Vault & Intellectual Property'),
          _buildParagraph(
              'Creators retaining digital rights to uploaded Study Vault materials grant Creania non-exclusive hosting distribution rights. Academic resources protected under digital rights management (DRM) watermarks cannot be redistributed outside authorized devices.'),
          _buildSectionTitle('5. Limitation of Liability'),
          _buildParagraph(
              'Creania is provided "as is" without warranty of any kind. Under no circumstances shall Creania or its parent entity be liable for direct, indirect, incidental, or consequential damages resulting from platform usage.'),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPrivacyView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Creania Privacy Policy',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Effective Date: August 11, 2026',
            style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('1. Data We Collect'),
          _buildParagraph(
              'We collect information you provide directly (such as profile username, bio, and educational choices) and technical usage data (including IP address, device model, login timestamps, and push notification tokens) to operate the platform securely.'),
          _buildSectionTitle('2. End-to-End Encryption (E2EE)'),
          _buildParagraph(
              'Private direct messages between users are protected using end-to-end encryption. Message contents are encrypted locally on your device prior to transmission.'),
          _buildSectionTitle('3. Use of Information'),
          _buildParagraph(
              'Your information is used solely to authenticate sessions, customize your learning progression, process authorized virtual purchases, deliver notifications, and enforce platform anti-cheat and security measures.'),
          _buildSectionTitle('4. Data Control & Private Profiles'),
          _buildParagraph(
              'You have full control over your privacy settings. Enabling "Private Profile" restricts visibility of your posts and activities to approved followers only.'),
          _buildSectionTitle('5. Security & Contact'),
          _buildParagraph(
              'We utilize industry-standard security safeguards. If you have any privacy-related inquiries, please submit a ticket via our Help & Support Center.'),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: context.primaryColor,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: context.textPrimary,
        fontSize: 13,
        height: 1.5,
      ),
    );
  }
}
