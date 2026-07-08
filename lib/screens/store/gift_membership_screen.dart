import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../core/theme.dart';
import '../../services/store_controller.dart';
import 'checkout_screen.dart';

class GiftMembershipScreen extends StatefulWidget {
  const GiftMembershipScreen({Key? key}) : super(key: key);

  @override
  State<GiftMembershipScreen> createState() => _GiftMembershipScreenState();
}

class _GiftMembershipScreenState extends State<GiftMembershipScreen> {
  final StoreController _storeCtrl = Get.find<StoreController>();
  final TextEditingController _friendCtrl = TextEditingController();
  final TextEditingController _msgCtrl = TextEditingController();

  String _selectedItem = 'VIP Level 3';
  String _selectedDuration = '30 Days';
  bool _isAnonymous = false;
  bool _isScheduled = false;
  DateTime? _scheduledDate;

  final List<String> items = ['Coins (1,000)', 'VIP Level 3', 'VIP Level 5', 'Novel Level 2', 'Novel Level 4', 'Celestial Wings Frame'];

  @override
  void dispose() {
    _friendCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF8B5CF6),
            onPrimary: Colors.white,
            surface: Color(0xFF111115),
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() {
        _scheduledDate = date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070A),
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD946EF).withOpacity(0.06),
                    blurRadius: 100,
                  )
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRecipientCard(),
                        const SizedBox(height: 20),
                        _buildItemSelectorCard(),
                        const SizedBox(height: 20),
                        _buildMessageCard(),
                        const SizedBox(height: 20),
                        _buildGiftingOptionsCard(),
                        const SizedBox(height: 30),
                        _buildProceedButton(),
                        const SizedBox(height: 30),
                        _buildGiftingHistory(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
            'GIFT PRESTIGE',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 2,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111115),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECIPIENT ACCOUNT',
            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _friendCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: "Enter Friend's Username or SID",
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.person_search_rounded, color: Colors.white30, size: 18),
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemSelectorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111115),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECT GIFT ITEM',
            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedItem,
            dropdownColor: const Color(0xFF111115),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _selectedItem = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111115),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GIFT CARD MESSAGE',
            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _msgCtrl,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Enter a custom gift note...',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftingOptionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111115),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Anonymous Gift', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              Switch(
                value: _isAnonymous,
                onChanged: (v) => setState(() => _isAnonymous = v),
                activeColor: const Color(0xFF8B5CF6),
              ),
            ],
          ),
          const Divider(color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Schedule Gifting', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              Switch(
                value: _isScheduled,
                onChanged: (v) => setState(() {
                  _isScheduled = v;
                  if (!v) _scheduledDate = null;
                }),
                activeColor: const Color(0xFF8B5CF6),
              ),
            ],
          ),
          if (_isScheduled) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _scheduledDate == null
                          ? 'Select Gifting Date'
                          : 'Deliver on: ${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
                    ),
                    const Icon(Icons.calendar_month_outlined, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildProceedButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B5CF6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () {
          final friend = _friendCtrl.text.trim();
          if (friend.isEmpty) {
            Get.snackbar('Validation Warning', 'Recipient name cannot be empty.', backgroundColor: const Color(0xFFEF4444).withOpacity(0.9), colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
            return;
          }

          double basePrice = 799.0;
          String category = 'VIP';
          if (_selectedItem.contains('Coins')) {
            basePrice = 799.0;
            category = 'Coins';
          } else if (_selectedItem.contains('VIP Level 5')) {
            basePrice = 1999.0;
            category = 'VIP';
          } else if (_selectedItem.contains('Novel Level 2')) {
            basePrice = 399.0;
            category = 'Novel';
          } else if (_selectedItem.contains('Novel Level 4')) {
            basePrice = 1499.0;
            category = 'Novel';
          } else if (_selectedItem.contains('Wings')) {
            basePrice = 400.0;
            category = 'Frame';
          }

          Get.to(() => CheckoutScreen(
                productName: _selectedItem,
                category: category,
                basePrice: basePrice,
                duration: _selectedDuration,
                giftToFriend: true,
                friendUsername: friend,
                giftMessage: _msgCtrl.text,
                anonymous: _isAnonymous,
                scheduledDate: _scheduledDate,
              ));
        },
        child: Text(
          'PROCEED TO PAY GIFT',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildGiftingHistory() {
    return Obx(() {
      final history = _storeCtrl.giftHistory;
      if (history.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECENT GIFTS LOG',
            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final log = history[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111115),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.02)),
                ),
                child: Row(
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${log['item']} sent to @${log['recipient']}',
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            log['message'] as String,
                            style: GoogleFonts.poppins(color: Colors.white24, fontSize: 9.5, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      log['anonymous'] == true ? 'Anonymous' : 'Public',
                      style: GoogleFonts.poppins(color: const Color(0xFFFFB800), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      );
    });
  }
}
