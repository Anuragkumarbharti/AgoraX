import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../models/event_model.dart';
import '../../models/user_model.dart';
import '../profile/user_profile_screen.dart';

class LiveEventWinnerScreen extends StatefulWidget {
  const LiveEventWinnerScreen({
    Key? key,
    required this.event,
    this.finalScore = 0,
    this.correctCount = 0,
    this.averageTime = 0.0,
    this.accruedCoins = 0,
    this.wasDisqualified = false,
  }) : super(key: key);

  final Event event;
  final int finalScore;
  final int correctCount;
  final double averageTime;
  final int accruedCoins;
  final bool wasDisqualified;

  @override
  State<LiveEventWinnerScreen> createState() => _LiveEventWinnerScreenState();
}

class _LiveEventWinnerScreenState extends State<LiveEventWinnerScreen> {
  // Mock prize release details
  final String _verificationStatus = 'Verification Pending'; // Pending -> Verified -> Prize Locked -> Released
  final int _daysRemaining = 7;
  bool _isReleased = false;

  final List<Map<String, dynamic>> _allRankings = [
    {
      'rank': 1,
      'name': 'AdityaK',
      'score': 42,
      'correct': 4,
      'time': '3.8s',
      'prize': 500,
      'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde',
      'community': 'CompSci Hub',
    },
    {
      'rank': 2,
      'name': 'SnehaP',
      'score': 38,
      'correct': 4,
      'time': '4.5s',
      'prize': 300,
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
      'community': 'Dev Coders',
    },
    {
      'rank': 3,
      'name': 'KunalR',
      'score': 32,
      'correct': 3,
      'time': '3.9s',
      'prize': 200,
      'avatar': 'https://images.unsplash.com/photo-1599566150163-29194dcaad36',
      'community': 'CompSci Hub',
    },
    {
      'rank': 4,
      'name': 'RohanM',
      'score': 30,
      'correct': 3,
      'time': '5.2s',
      'prize': 50,
      'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
      'community': 'Alpha Tech',
    },
    {
      'rank': 5,
      'name': 'TanyaS',
      'score': 24,
      'correct': 2,
      'time': '4.8s',
      'prize': 50,
      'avatar': 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2',
      'community': 'Alpha Tech',
    },
  ];

  @override
  void initState() {
    super.initState();
    // If not disqualified and user got high score, insert themselves in rankings
    if (!widget.wasDisqualified) {
      final exists = _allRankings.any((r) => r['name'] == 'AnuragK');
      if (!exists) {
        _allRankings.add({
          'rank': 6,
          'name': 'AnuragK (You)',
          'score': widget.finalScore,
          'correct': widget.correctCount,
          'time': '${widget.averageTime.toStringAsFixed(1)}s',
          'prize': widget.finalScore > 30 ? 50 : 0,
          'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
          'community': 'My Custom Community',
        });
        _allRankings.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
        // Reset ranks
        for (int i = 0; i < _allRankings.length; i++) {
          _allRankings[i]['rank'] = i + 1;
        }
      }
    }
  }

  void _navigateToUserProfile(String name) {
    final targetUser = User(
      id: 'uid_${name.toLowerCase()}',
      username: name.toLowerCase(),
      email: '${name.toLowerCase()}@agorax.app',
      displayName: name,
      interests: ['Coding', 'Competitions'],
      communities: [widget.event.organizer],
      followers: 180,
      following: 90,
      isVerified: false,
      isPremium: false,
      reputation: 340,
      sid: '984024',
    );
    Get.to(() => UserProfileScreen(user: targetUser));
  }

  @override
  Widget build(BuildContext context) {
    final ev = widget.event;
    final int userRank = widget.wasDisqualified ? 99 : (_allRankings.indexWhere((r) => r['name'].toString().contains('AnuragK')) + 1);
    final double userPrize = (userRank > 0 && userRank <= _allRankings.length) ? _allRankings[userRank - 1]['prize'].toDouble() : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          '🏁 Event Completed',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Disqualification Banner ─────────────────────────────────────────
          if (widget.wasDisqualified) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.gavel_rounded, color: Colors.red, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DISQUALIFIED', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text('Due to AI secure mode screen violations, you are ineligible for rewards.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── My Performance Metrics ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📊 Your Event Scorecard', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _scoreMetric('Final Rank', widget.wasDisqualified ? 'N/A' : '#$userRank', Colors.amber),
                    _scoreMetric('Final Score', '${widget.finalScore} pts', Colors.white),
                    _scoreMetric('Accuracy', '${widget.correctCount}/4', Colors.green),
                    _scoreMetric('Avg Speed', '${widget.averageTime.toStringAsFixed(1)}s', Colors.blue),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Wallet Held Prize Details ───────────────────────────────────────
          if (userPrize > 0 && !widget.wasDisqualified) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('💰 Winning Prize held in Wallet', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('₹${userPrize.toInt()}', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const Divider(color: AppTheme.borderColor, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Verification Status', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.withOpacity(0.4)),
                        ),
                        child: Text(_verificationStatus, style: const TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Prize Hold policy period', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      Text('$_daysRemaining days remaining', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isReleased ? AppTheme.primaryColor : Colors.grey.withOpacity(0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isReleased
                              ? () => Get.snackbar('Success', 'Prize withdrawn successfully to your bank account!')
                              : null,
                          child: Text('Withdraw Prize', style: TextStyle(color: _isReleased ? Colors.white : Colors.white24, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Anti-Cheat Audit Logs ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🛡️ AI Anti-Cheat Verification Check', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _auditRow('VPN Usage Check', 'No VPN detected', true),
                _auditRow('Device Emulator Detections', 'Physical Mobile Device Verified', true),
                _auditRow('Screen Switching violations check', widget.wasDisqualified ? 'Failed (exceeded limit)' : 'Passed (0 tab switches)', !widget.wasDisqualified),
                _auditRow('Speed click automation bot check', 'Passed (human pattern verified)', true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Podium Leaderboard ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🏆 Official Event Leaderboard', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ..._allRankings.map((r) {
                  final isMe = r['name'].toString().contains('You');
                  final medal = r['rank'] == 1 ? '🥇' : r['rank'] == 2 ? '🥈' : r['rank'] == 3 ? '🥉' : '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: InkWell(
                      onTap: () => _navigateToUserProfile(r['name'] as String),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isMe ? AppTheme.primaryColor.withOpacity(0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text(
                                medal.isNotEmpty ? medal : '${r['rank']}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            CircleAvatar(radius: 14, backgroundImage: NetworkImage(r['avatar'] as String)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r['name'] as String,
                                    style: TextStyle(color: isMe ? AppTheme.primaryColor : Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    r['community'] as String,
                                    style: const TextStyle(color: AppTheme.textTertiary, fontSize: 9),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${r['score']} pts', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                if ((r['prize'] as int) > 0)
                                  Text('₹${r['prize']}', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Exit Button
          SizedBox(
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.borderColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Get.back(),
              child: const Text('Back to Event detail', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _scoreMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
      ],
    );
  }

  Widget _auditRow(String label, String value, bool isSuccess) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isSuccess ? Colors.green : Colors.red, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
          Text(value, style: TextStyle(color: isSuccess ? Colors.white70 : Colors.red, fontSize: 10)),
        ],
      ),
    );
  }
}
