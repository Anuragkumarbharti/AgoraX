// lib/widgets/room_contribution_dialog.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/number_formatter.dart';
import '../gems/gem_widgets.dart';
import '../common/optimized_image.dart';

class RoomContributionDialog extends StatefulWidget {
  final String roomId;
  const RoomContributionDialog({Key? key, required this.roomId}) : super(key: key);

  @override
  State<RoomContributionDialog> createState() => _RoomContributionDialogState();
}

class _RoomContributionDialogState extends State<RoomContributionDialog> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final response = await Supabase.instance.client
          .rpc('get_room_contribution_stats', params: {'p_room_id': widget.roomId});
      
      if (mounted) {
        setState(() {
          _stats = response as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading room contribution: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatStars(double stars) {
    return formatCompactNumber(stars);
  }

  @override
  Widget build(BuildContext context) {
    final double totalStars = ((_stats?['total_gems'] ?? _stats?['total_stars']) as num?)?.toDouble() ?? 0.0;
    final int totalGifts = (_stats?['total_gifts'] as num?)?.toInt() ?? 0;
    final double sessionStars = ((_stats?['today_gems'] ?? _stats?['session_stars']) as num?)?.toDouble() ?? 0.0;
    final int sessionGifts = (_stats?['session_gifts'] as num?)?.toInt() ?? 0;

    final contributors = _stats?['top_contributors'] as List<dynamic>? ?? [];
    final receivers = _stats?['top_receivers'] as List<dynamic>? ?? [];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F111A).withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Arena Stats & Contribution 🏆',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(48.0),
                child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6))),
              )
            else ...[
              // Room stats summary row
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(child: _buildStatTile('Total Room Gems', _formatStars(totalStars), '$totalGifts Gifts')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatTile('This Session Gems', _formatStars(sessionStars), '$sessionGifts Gifts')),
                  ],
                ),
              ),

              // Tab headers
              TabBar(
                controller: _tabCtrl,
                indicatorColor: const Color(0xFF8B5CF6),
                labelColor: const Color(0xFF8B5CF6),
                unselectedLabelColor: Colors.white38,
                labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Top Givers'),
                  Tab(text: 'Top Receivers'),
                ],
              ),

              // Tab Views
              SizedBox(
                height: 260,
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildRankingList(contributors),
                    _buildRankingList(receivers),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: GoogleFonts.poppins(color: const Color(0xFF00F2FE), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              const GemIcon(size: 14),
            ],
          ),
          const SizedBox(height: 2),
          Text(sub, style: GoogleFonts.inter(color: Colors.white38, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildRankingList(List<dynamic> users) {
    if (users.isEmpty) {
      return Center(
        child: Text(
          'No activity recorded in this room yet.',
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final u = users[index];
        final String name = u['username'] ?? 'User';
        final String avatar = u['avatar'] ?? '';
        final double gems = ((u['gems_value'] ?? u['stars_value']) as num?)?.toDouble() ?? 0.0;
        final rank = index + 1;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.01),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Rank number indicator
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: rank == 1 
                      ? const Color(0xFFFFD700) 
                      : (rank == 2 ? const Color(0xFFC0C0C0) : (rank == 3 ? const Color(0xFFCD7F32) : Colors.white10)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: GoogleFonts.poppins(
                      color: rank <= 3 ? Colors.black : Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Avatar
              CircleAvatar(
                radius: 14,
                backgroundImage: avatar.isNotEmpty
                    ? OptimizedImage.getOptimizedImageProvider(avatar)
                    : const AssetImage('assets/images/placeholder.png') as ImageProvider,
              ),
              const SizedBox(width: 12),

              // Username
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Total Gems
              GemCounter(amount: gems, iconSize: 13),
            ],
          ),
        );
      },
    );
  }
}
