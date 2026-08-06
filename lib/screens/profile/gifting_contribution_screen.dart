// lib/screens/profile/gifting_contribution_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/user/user_profile_cache_manager.dart';
import '../../utils/number_formatter.dart';

class GiftingContributionScreen extends StatefulWidget {
  final String userId;
  final String username;
  final int initialTabIndex;
  
  const GiftingContributionScreen({
    Key? key,
    required this.userId,
    required this.username,
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  State<GiftingContributionScreen> createState() => _GiftingContributionScreenState();
}

class _GiftingContributionScreenState extends State<GiftingContributionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isLoadingStats = true;
  bool _isLoadingReceived = true;
  bool _isLoadingSent = true;

  Map<String, dynamic>? _overallStats;
  List<dynamic> _receivedGifts = [];
  List<dynamic> _sentGifts = [];
  Map<String, String> _giftCurrencies = {};
  late final Worker _giftStatsWorker;
  
  // Search and filter parameters
  String _receivedSearch = '';
  String _sentSearch = '';
  String _receivedFilter = 'lifetime'; // today, week, month, lifetime
  String _sentFilter = 'lifetime'; // today, week, month, lifetime

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    _loadAllData();

    // Recalculate ranking instantly on every successful gift realtime event
    _giftStatsWorker = ever(UserProfileCacheManager.giftTransactionsTrigger, (_) {
      debugPrint('[GiftingContributionScreen] Realtime gift transaction event detected. Refreshing data...');
      _loadAllData();
    });
  }

  @override
  void dispose() {
    _giftStatsWorker.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadOverallStats(),
      _loadReceivedHistory(),
      _loadSentHistory(),
      _loadGiftCatalogCurrencies(),
    ]);
  }

  Future<void> _loadGiftCatalogCurrencies() async {
    try {
      final response = await Supabase.instance.client
          .from('gift_catalog')
          .select('id, currency');
      if (response != null) {
        final Map<String, String> mapping = {};
        for (final item in response as List<dynamic>) {
          final id = item['id'] as String?;
          final currency = item['currency'] as String?;
          if (id != null && currency != null) {
            mapping[id] = currency;
          }
        }
        if (mounted) {
          setState(() {
            _giftCurrencies = mapping;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading gift catalog currencies: $e');
    }
  }

  Future<void> _loadOverallStats() async {
    try {
      final response = await Supabase.instance.client
          .rpc('get_user_contribution_stats', params: {'p_user_id': widget.userId});
      if (mounted) {
        setState(() {
          _overallStats = response as Map<String, dynamic>?;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching overall stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Future<void> _loadReceivedHistory() async {
    try {
      final response = await Supabase.instance.client
          .from('user_received_gifts')
          .select()
          .eq('receiver_id', widget.userId);
      if (mounted) {
        setState(() {
          _receivedGifts = response as List<dynamic>? ?? [];
          _isLoadingReceived = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching received history: $e');
      if (mounted) {
        setState(() {
          _isLoadingReceived = false;
        });
      }
    }
  }

  Future<void> _loadSentHistory() async {
    try {
      final response = await Supabase.instance.client
          .from('user_sent_gifts')
          .select()
          .eq('sender_id', widget.userId);
      if (mounted) {
        setState(() {
          _sentGifts = response as List<dynamic>? ?? [];
          _isLoadingSent = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching sent history: $e');
      if (mounted) {
        setState(() {
          _isLoadingSent = false;
        });
      }
    }
  }

  bool _isWithinFilter(DateTime date, String filter) {
    final now = DateTime.now();
    if (filter == 'today') {
      return date.year == now.year && date.month == now.month && date.day == now.day;
    } else if (filter == 'week') {
      final weekAgo = now.subtract(const Duration(days: 7));
      return date.isAfter(weekAgo);
    } else if (filter == 'month') {
      final monthAgo = now.subtract(const Duration(days: 30));
      return date.isAfter(monthAgo);
    }
    return true; // lifetime
  }

  List<dynamic> _getFilteredReceived() {
    return _receivedGifts.where((item) {
      final String sender = item['sender_username'] ?? '';
      final String gift = item['gift_name'] ?? '';
      final DateTime date = DateTime.parse(item['created_at']);
      
      final matchesSearch = sender.toLowerCase().contains(_receivedSearch.toLowerCase()) ||
          gift.toLowerCase().contains(_receivedSearch.toLowerCase());
      
      return matchesSearch && _isWithinFilter(date, _receivedFilter);
    }).toList();
  }

  List<dynamic> _getFilteredSent() {
    return _sentGifts.where((item) {
      final String receiver = item['receiver_username'] ?? '';
      final String gift = item['gift_name'] ?? '';
      final DateTime date = DateTime.parse(item['created_at']);
      
      final matchesSearch = receiver.toLowerCase().contains(_sentSearch.toLowerCase()) ||
          gift.toLowerCase().contains(_sentSearch.toLowerCase());
      
      return matchesSearch && _isWithinFilter(date, _sentFilter);
    }).toList();
  }

  String _formatStars(double stars) {
    return formatCompactNumber(stars);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161925),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Gifting & Contribution Center',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF8B5CF6),
          labelColor: const Color(0xFF8B5CF6),
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: '🎁 Received'),
            Tab(text: '📤 Sent'),
            Tab(text: '📈 Contribution'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildReceivedTab(),
            _buildSentTab(),
            _buildContributionTab(),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getGroupedReceived() {
    final filtered = _getFilteredReceived();
    final Map<String, Map<String, dynamic>> grouped = {};
    
    for (final item in filtered) {
      final String senderId = item['sender_id'] ?? '';
      if (senderId.isEmpty) continue;
      
      final String sender = item['sender_username'] ?? 'User';
      final String avatar = item['sender_avatar'] ?? '';
      final String giftName = item['gift_name'] ?? 'Gift';
      final String giftIcon = item['gift_icon'] ?? '🎁';
      final int qty = item['quantity'] ?? 1;
      final double stars = (item['stars_value'] as num?)?.toDouble() ?? 0.0;
      final DateTime date = DateTime.parse(item['created_at']);
      final String? roomId = item['room_id'] as String?;

      if (!grouped.containsKey(senderId)) {
        grouped[senderId] = {
          'sender_id': senderId,
          'sender_username': sender,
          'sender_avatar': avatar,
          'total_stars': 0.0,
          'total_qty': 0,
          'gifts': <String, Map<String, dynamic>>{}, 
          'last_date': date,
          'room_ids': <String>{},
        };
      }
      
      final g = grouped[senderId]!;
      g['total_stars'] = (g['total_stars'] as double) + stars;
      g['total_qty'] = (g['total_qty'] as int) + qty;
      if (date.isAfter(g['last_date'] as DateTime)) {
        g['last_date'] = date;
      }
      if (roomId != null && roomId.isNotEmpty) {
        (g['room_ids'] as Set<String>).add(roomId);
      }
      
      final giftKey = '${giftIcon}_${giftName}';
      final giftsMap = g['gifts'] as Map<String, Map<String, dynamic>>;
      if (!giftsMap.containsKey(giftKey)) {
        giftsMap[giftKey] = {
          'icon': giftIcon,
          'name': giftName,
          'qty': 0,
        };
      }
      giftsMap[giftKey]!['qty'] = (giftsMap[giftKey]!['qty'] as int) + qty;
    }
    
    final result = grouped.values.toList();
    result.sort((a, b) => (b['total_stars'] as double).compareTo(a['total_stars'] as double));
    return result;
  }

  List<Map<String, dynamic>> _getGroupedSent() {
    final filtered = _getFilteredSent();
    final Map<String, Map<String, dynamic>> grouped = {};
    
    for (final item in filtered) {
      final String receiverId = item['receiver_id'] ?? '';
      if (receiverId.isEmpty) continue;
      
      final String giftId = item['gift_id'] ?? '';
      final String currency = _giftCurrencies[giftId] ?? 'gold';
      
      if (currency != 'gold') continue;

      final String receiver = item['receiver_username'] ?? 'User';
      final String avatar = item['receiver_avatar'] ?? '';
      final String giftName = item['gift_name'] ?? 'Gift';
      final String giftIcon = item['gift_icon'] ?? '🎁';
      final int qty = item['quantity'] ?? 1;
      final double stars = (item['stars_value'] as num?)?.toDouble() ?? 0.0;
      final DateTime date = DateTime.parse(item['created_at']);
      final String? roomId = item['room_id'] as String?;

      if (!grouped.containsKey(receiverId)) {
        grouped[receiverId] = {
          'receiver_id': receiverId,
          'receiver_username': receiver,
          'receiver_avatar': avatar,
          'total_stars': 0.0,
          'total_qty': 0,
          'gifts': <String, Map<String, dynamic>>{}, 
          'last_date': date,
          'room_ids': <String>{},
        };
      }
      
      final g = grouped[receiverId]!;
      g['total_stars'] = (g['total_stars'] as double) + stars;
      g['total_qty'] = (g['total_qty'] as int) + qty;
      if (date.isAfter(g['last_date'] as DateTime)) {
        g['last_date'] = date;
      }
      if (roomId != null && roomId.isNotEmpty) {
        (g['room_ids'] as Set<String>).add(roomId);
      }
      
      final giftKey = '${giftIcon}_${giftName}';
      final giftsMap = g['gifts'] as Map<String, Map<String, dynamic>>;
      if (!giftsMap.containsKey(giftKey)) {
        giftsMap[giftKey] = {
          'icon': giftIcon,
          'name': giftName,
          'qty': 0,
        };
      }
      giftsMap[giftKey]!['qty'] = (giftsMap[giftKey]!['qty'] as int) + qty;
    }
    
    final result = grouped.values.toList();
    result.sort((a, b) => (b['total_stars'] as double).compareTo(a['total_stars'] as double));
    return result;
  }

  Widget _buildReceivedTab() {
    if (_isLoadingReceived) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6))));
    }

    final groupedList = _getGroupedReceived();

    return Column(
      children: [
        _buildFiltersRow(
          onSearchChanged: (val) => setState(() => _receivedSearch = val),
          selectedFilter: _receivedFilter,
          onFilterChanged: (val) => setState(() => _receivedFilter = val),
        ),
        Expanded(
          child: groupedList.isEmpty
              ? _buildEmptyState('No received gifts found.')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: groupedList.length,
                  itemBuilder: (context, index) {
                    final item = groupedList[index];
                    final sender = item['sender_username'] ?? 'User';
                    final avatar = item['sender_avatar'] ?? '';
                    final double totalStars = item['total_stars'] ?? 0.0;
                    final DateTime lastDate = item['last_date'];
                    final roomIds = item['room_ids'] as Set<String>;
                    final String? roomId = roomIds.isNotEmpty ? roomIds.first : null;
                    
                    final giftsMap = item['gifts'] as Map<String, Map<String, dynamic>>;
                    final subtitleParts = giftsMap.values.map((g) {
                      return '${g['qty']}× ${g['icon']} ${g['name']}';
                    }).toList();
                    final subtitle = subtitleParts.join(', ');

                    return _buildGiftListTile(
                      title: 'From $sender',
                      subtitle: subtitle,
                      stars: totalStars,
                      date: lastDate,
                      avatar: avatar,
                      roomId: roomId,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSentTab() {
    if (_isLoadingSent || _isLoadingStats) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6))));
    }

    final groupedList = _getGroupedSent();
    final double totalSent = groupedList.fold(0.0, (sum, item) => sum + (item['total_stars'] as double));
    final String topFriend = _overallStats?['top_friend'] ?? 'None';
    final String favoriteGift = _overallStats?['favorite_gift'] ?? 'None';

    return Column(
      children: [
        // Gifting Analytics Cards
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gifting Analytics', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAnalyticsMetric('Total Sent', '${_formatStars(totalSent)} ★'),
                  _buildAnalyticsMetric('Top Receiver', topFriend),
                  _buildAnalyticsMetric('Favorite Gift', favoriteGift),
                ],
              ),
            ],
          ),
        ),

        _buildFiltersRow(
          onSearchChanged: (val) => setState(() => _sentSearch = val),
          selectedFilter: _sentFilter,
          onFilterChanged: (val) => setState(() => _sentFilter = val),
        ),
        Expanded(
          child: groupedList.isEmpty
              ? _buildEmptyState('No sent gifts found.')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: groupedList.length,
                  itemBuilder: (context, index) {
                    final item = groupedList[index];
                    final receiver = item['receiver_username'] ?? 'User';
                    final avatar = item['receiver_avatar'] ?? '';
                    final double totalStars = item['total_stars'] ?? 0.0;
                    final DateTime lastDate = item['last_date'];
                    final roomIds = item['room_ids'] as Set<String>;
                    final String? roomId = roomIds.isNotEmpty ? roomIds.first : null;

                    final giftsMap = item['gifts'] as Map<String, Map<String, dynamic>>;
                    final subtitleParts = giftsMap.values.map((g) {
                      return '${g['qty']}× ${g['icon']} ${g['name']}';
                    }).toList();
                    final subtitle = subtitleParts.join(', ');

                    return _buildGiftListTile(
                      title: 'Sent to $receiver',
                      subtitle: subtitle,
                      stars: totalStars,
                      date: lastDate,
                      avatar: avatar,
                      roomId: roomId,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildContributionTab() {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6))));
    }

    final double lifetime = (_overallStats?['lifetime_contribution'] as num?)?.toDouble() ?? 0.0;
    final double today = (_overallStats?['today_contribution'] as num?)?.toDouble() ?? 0.0;
    final double monthly = (_overallStats?['monthly_contribution'] as num?)?.toDouble() ?? 0.0;
    final double yearly = (_overallStats?['yearly_contribution'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBigContributionCard('Lifetime Contribution', '${_formatStars(lifetime)} ★', const Color(0xFFFFD700)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildContributionSubCard('Today', '${_formatStars(today)} ★', Colors.tealAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildContributionSubCard('This Month', '${_formatStars(monthly)} ★', Colors.purpleAccent)),
            ],
          ),
          const SizedBox(height: 16),
          _buildBigContributionCard('This Year\'s Contribution', '${_formatStars(yearly)} ★', Colors.cyanAccent),
        ],
      ),
    );
  }

  Widget _buildAnalyticsMetric(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(val, style: GoogleFonts.poppins(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBigContributionCard(String title, String val, Color glowColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.03), Colors.white.withOpacity(0.01)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glowColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.03),
            blurRadius: 15,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(val, style: GoogleFonts.poppins(color: glowColor, fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildContributionSubCard(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(val, style: GoogleFonts.poppins(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFiltersRow({
    required Function(String) onSearchChanged,
    required String selectedFilter,
    required Function(String) onFilterChanged,
  }) {
    final filters = ['today', 'week', 'month', 'lifetime'];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search box
          TextField(
            onChanged: onSearchChanged,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Search by user or gift name...',
              hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Colors.white30, size: 16),
              filled: true,
              fillColor: Colors.white.withOpacity(0.02),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),

          // Pills filter row
          Row(
            children: filters.map((f) {
              final isSelected = selectedFilter == f;
              return GestureDetector(
                onTap: () => onFilterChanged(f),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: isSelected ? const Color(0xFFA78BFA) : Colors.white.withOpacity(0.06)),
                  ),
                  child: Text(
                    f.substring(0, 1).toUpperCase() + f.substring(1),
                    style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftListTile({
    required String title,
    required String subtitle,
    required double stars,
    required DateTime date,
    required String avatar,
    String? roomId,
  }) {
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(date);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: avatar.isNotEmpty
                ? NetworkImage(avatar)
                : const AssetImage('assets/images/placeholder.png') as ImageProvider,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(subtitle, style: GoogleFonts.inter(color: Colors.white70, fontSize: 10.5)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(dateStr, style: GoogleFonts.inter(color: Colors.white30, fontSize: 8)),
                    if (roomId != null && roomId.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('•', style: GoogleFonts.inter(color: Colors.white30, fontSize: 8)),
                      const SizedBox(width: 8),
                      Text('Room: $roomId', style: GoogleFonts.inter(color: Colors.white30, fontSize: 8)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${_formatStars(stars)} ★',
            style: GoogleFonts.poppins(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Text(
        msg,
        style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
      ),
    );
  }
}
