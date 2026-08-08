import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../utils/number_formatter.dart';
import '../../../../widgets/gems/gem_widgets.dart';

class RoomStarGiftStatsDialog extends StatefulWidget {
  final String roomId;
  final String? roomName;
  final int totalStars;

  const RoomStarGiftStatsDialog({
    Key? key,
    required this.roomId,
    this.roomName,
    this.totalStars = 0,
  }) : super(key: key);

  @override
  State<RoomStarGiftStatsDialog> createState() =>
      _RoomStarGiftStatsDialogState();
}

class _RoomStarGiftStatsDialogState extends State<RoomStarGiftStatsDialog> {
  bool _isLoading = true;
  int _selectedPeriodIndex = 0; // 0 = Today's, 1 = Total
  int _selectedTypeIndex = 0; // 0 = Sent Gift, 1 = Received Gift

  double _totalStars = 0;
  double _todayStars = 0;

  List<Map<String, dynamic>> _todaySentGifts = [];
  List<Map<String, dynamic>> _todayReceivedGifts = [];
  List<Map<String, dynamic>> _totalSentGifts = [];
  List<Map<String, dynamic>> _totalReceivedGifts = [];

  @override
  void initState() {
    super.initState();
    _totalStars = widget.totalStars.toDouble();
    _fetchGiftStats();
  }

  Future<void> _fetchGiftStats() async {
    try {
      final response = await Supabase.instance.client
          .rpc('get_room_contribution_stats', params: {'p_room_id': widget.roomId});

      if (mounted && response != null && response is Map<String, dynamic>) {
        setState(() {
          _totalStars = ((response['total_gems'] ?? response['total_stars']) as num?)?.toDouble() ?? _totalStars;
          _todayStars = ((response['today_gems'] ?? response['today_stars'] ?? response['session_stars']) as num?)?.toDouble() ?? 0;

          final todaySent = response['today_top_contributors'] as List<dynamic>?;
          final todayRecv = response['today_top_receivers'] as List<dynamic>?;
          final totalSent = (response['total_top_contributors'] ?? response['top_contributors']) as List<dynamic>?;
          final totalRecv = (response['total_top_receivers'] ?? response['top_receivers']) as List<dynamic>?;

          _todaySentGifts = todaySent != null ? List<Map<String, dynamic>>.from(todaySent) : [];
          _todayReceivedGifts = todayRecv != null ? List<Map<String, dynamic>>.from(todayRecv) : [];
          _totalSentGifts = totalSent != null ? List<Map<String, dynamic>>.from(totalSent) : [];
          _totalReceivedGifts = totalRecv != null ? List<Map<String, dynamic>>.from(totalRecv) : [];

          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching room star gift stats: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatStars(double stars) {
    if (stars >= 1000) {
      return formatCompactNumber(stars);
    }
    return stars.toInt().toString();
  }

  List<Map<String, dynamic>> _getActiveList() {
    if (_selectedPeriodIndex == 0) {
      // Today's
      return _selectedTypeIndex == 0 ? _todaySentGifts : _todayReceivedGifts;
    } else {
      // Total
      return _selectedTypeIndex == 0 ? _totalSentGifts : _totalReceivedGifts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeList = _getActiveList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF0F111A).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 24,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Title & Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const GemIcon(size: 20),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Room Gem Gifts',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (widget.roomName != null && widget.roomName!.isNotEmpty)
                            Text(
                              widget.roomName!,
                              style: GoogleFonts.poppins(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            // Top Stat Cards (Total & Today's Gems Summary)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      label: "Today's Gems 💎",
                      stars: _todayStars,
                      iconColor: const Color(0xFF00F2FE),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryCard(
                      label: "Total Gems 💎",
                      stars: _totalStars,
                      iconColor: const Color(0xFF00F2FE),
                    ),
                  ),
                ],
              ),
            ),

            // 1. Primary Section: Period Toggle Tabs (Today's vs Total)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        label: "Today's",
                        isSelected: _selectedPeriodIndex == 0,
                        onTap: () {
                          setState(() {
                            _selectedPeriodIndex = 0;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildTabButton(
                        label: "Total",
                        isSelected: _selectedPeriodIndex == 1,
                        onTap: () {
                          setState(() {
                            _selectedPeriodIndex = 1;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Secondary Sub-Section: Category Toggle (Sent Gift vs Received Gift)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSubTabButton(
                      label: 'Sent Gift 🎁',
                      isSelected: _selectedTypeIndex == 0,
                      onTap: () {
                        setState(() {
                          _selectedTypeIndex = 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSubTabButton(
                      label: 'Received Gift ⭐',
                      isSelected: _selectedTypeIndex == 1,
                      onTap: () {
                        setState(() {
                          _selectedTypeIndex = 1;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Star Ranking List Content
            if (_isLoading)
              const SizedBox(
                height: 240,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB800)),
                  ),
                ),
              )
            else if (activeList.isEmpty)
              SizedBox(
                height: 220,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white.withValues(alpha: 0.25),
                        size: 38,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No gem gifts recorded for this period.',
                        style: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                height: 260,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: activeList.length,
                  itemBuilder: (context, index) {
                    final item = activeList[index];
                    final String name = item['username'] ?? 'User';
                    final String avatar = item['avatar'] ?? '';
                    final double gems =
                        ((item['gems_value'] ?? item['stars_value']) as num?)?.toDouble() ?? 0.0;
                    final rank = index + 1;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          // Rank Indicator
                          _buildRankBadge(rank),
                          const SizedBox(width: 10),

                          // User Avatar
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white10,
                            backgroundImage: avatar.isNotEmpty
                                ? NetworkImage(avatar)
                                : null,
                            child: avatar.isEmpty
                                ? const Icon(Icons.person,
                                    color: Colors.white54, size: 16)
                                : null,
                          ),
                          const SizedBox(width: 10),

                          // Username
                          Expanded(
                            child: Text(
                              name.startsWith('@') ? name : '@$name',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Total Gems
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_formatStars(gems)} Gems',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF00F2FE),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Text('💎', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required double stars,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _formatStars(stars),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              GemIcon(size: 15),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF8B5CF6)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: isSelected ? Colors.white : Colors.white60,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFB800).withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFB800)
                : Colors.white.withValues(alpha: 0.06),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: isSelected ? const Color(0xFFFFD700) : Colors.white54,
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color badgeColor;
    Color textColor;

    if (rank == 1) {
      badgeColor = const Color(0xFFFFD700);
      textColor = Colors.black;
    } else if (rank == 2) {
      badgeColor = const Color(0xFFC0C0C0);
      textColor = Colors.black;
    } else if (rank == 3) {
      badgeColor = const Color(0xFFCD7F32);
      textColor = Colors.white;
    } else {
      badgeColor = Colors.white.withValues(alpha: 0.10);
      textColor = Colors.white70;
    }

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$rank',
          style: GoogleFonts.poppins(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
