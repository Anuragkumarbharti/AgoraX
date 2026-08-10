import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../common/optimized_image.dart';
import '../../core/theme.dart';
import '../../services/user/user_profile_cache_manager.dart';
import '../gems/gem_widgets.dart';

class GiftHistoryBottomSheet extends StatefulWidget {
  final String userId;
  final bool isReceived; // true for Gifts Received, false for Contributions (Sent)

  const GiftHistoryBottomSheet({
    Key? key,
    required this.userId,
    required this.isReceived,
  }) : super(key: key);

  static void show(BuildContext context, String userId, bool isReceived) {
    Get.bottomSheet(
      GiftHistoryBottomSheet(userId: userId, isReceived: isReceived),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<GiftHistoryBottomSheet> createState() => _GiftHistoryBottomSheetState();
}

class _GiftHistoryBottomSheetState extends State<GiftHistoryBottomSheet> {
  final List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGiftHistory();
  }

  int _calculateStars(String itemId, int coinsValue, int quantity) {
    int starsPerUnit;
    if (itemId == '2-Star Gift' || itemId == '2-Gem Gift') {
      starsPerUnit = 2;
    } else if (itemId == '1-Star Gift' || itemId == '1-Gem Gift') {
      starsPerUnit = 1;
    } else {
      final double calc = coinsValue / 10.0;
      starsPerUnit = (calc.isNaN || calc.isInfinite) ? 1 : calc.clamp(1.0, 999999.0).toInt();
    }
    return starsPerUnit * quantity;
  }

  Future<void> _fetchGiftHistory() async {
    try {
      final response = await Supabase.instance.client
          .from('gift_history')
          .select('*, sender:sender_id(display_name, avatar_url, username), receiver:receiver_id(display_name, avatar_url, username)')
          .eq(widget.isReceived ? 'receiver_id' : 'sender_id', widget.userId)
          .order('created_at', ascending: false);

      if (response != null) {
        final List<Map<String, dynamic>> loaded = [];
        for (final item in response as List) {
          loaded.add(Map<String, dynamic>.from(item));
        }
        setState(() {
          _history.assignAll(loaded);
        });
      }
    } catch (e) {
      debugPrint('[GiftHistory] Error loading: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isReceived ? 'Gifts Received History' : 'Gifts Sent History';
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0E17).withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60),
                onPressed: () => Get.back(),
              )
            ],
          ),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),

          // Content list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: context.primaryColor))
                : _history.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        itemCount: _history.length,
                        physics: const BouncingScrollPhysics(),
                        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 16),
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          final other = widget.isReceived ? item['sender'] : item['receiver'];
                          final otherName = other != null ? (other['display_name'] ?? other['username'] ?? 'User') : 'Anonymous';
                          final otherAvatar = other != null ? (other['avatar_url'] as String?) : null;
                          
                          final itemId = item['item_id'] ?? 'Gift';
                          final quantity = item['quantity'] ?? 1;
                          final coinsValue = item['coins_value'] ?? 0;
                          final date = item['created_at'] != null ? DateTime.tryParse(item['created_at'].toString()) : null;
                          final stars = _calculateStars(itemId, coinsValue, quantity);

                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                // Other User Avatar
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: otherAvatar != null && otherAvatar.isNotEmpty
                                      ? OptimizedImage.getOptimizedImageProvider(
                                          otherAvatar,
                                          preset: MediaSizePreset.xs,
                                        )
                                      : null,
                                  child: otherAvatar == null || otherAvatar.isEmpty
                                      ? const Icon(Icons.person, size: 18, color: Colors.white30)
                                      : null,
                                ),
                                const SizedBox(width: 12),

                                // Gift Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.isReceived ? 'From $otherName' : 'To $otherName',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$itemId x$quantity ($coinsValue coins)',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white54,
                                          fontSize: 11,
                                        ),
                                      ),
                                      if (date != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal()),
                                          style: GoogleFonts.poppins(
                                            color: Colors.white24,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Gems Reward count
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      children: [
                                        const GemIcon(size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$stars',
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFF00F2FE),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Gems',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white24,
                                        fontSize: 9,
                                      ),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.card_giftcard_rounded, color: Colors.white30, size: 48),
          const SizedBox(height: 12),
          Text(
            widget.isReceived ? 'No gifts received yet.' : 'No gifts sent yet.',
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
