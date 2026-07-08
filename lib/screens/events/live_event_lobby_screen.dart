import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../models/event_model.dart';
import 'live_event_play_screen.dart';

class LiveEventLobbyScreen extends StatefulWidget {
  const LiveEventLobbyScreen({Key? key, required this.event}) : super(key: key);
  final Event event;

  @override
  State<LiveEventLobbyScreen> createState() => _LiveEventLobbyScreenState();
}

class _LiveEventLobbyScreenState extends State<LiveEventLobbyScreen> {
  late Timer _lobbyTimer;
  late Timer _pingTimer;

  int _countdownSeconds = 30; // 30 seconds count down for simulation
  int _participantsJoined = 14;
  int _ping = 42;
  int _batteryPercent = 88;
  String _networkQuality = 'Excellent';
  bool _isReady = false;
  bool _voiceConnected = false;
  bool _isMuted = true;
  bool _handRaised = false;

  final List<String> _joinedUserNames = [
    'AdityaK', 'SnehaP', 'KunalR', 'RohanM', 'TanyaS', 'AmitB', 'VikramS',
    'NehaW', 'KabirD', 'PriyaR', 'ArjunV', 'IshitaJ', 'RakeshT', 'DivyaM'
  ];

  @override
  void initState() {
    super.initState();
    // Simulate countdown and joined users
    _lobbyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        setState(() {
          _countdownSeconds--;
          // Randomly add participants
          if (_countdownSeconds % 3 == 0 && _participantsJoined < widget.event.maxParticipants) {
            _participantsJoined++;
            if (_participantsJoined % 3 == 0) {
              _joinedUserNames.add('User_${Random().nextInt(800) + 100}');
            }
          }
        });
      } else {
        _lobbyTimer.cancel();
        _pingTimer.cancel();
        // Go to play screen automatically
        Get.off(() => LiveEventPlayScreen(event: widget.event));
      }
    });

    // Simulate diagnostics updates
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      setState(() {
        _ping = Random().nextInt(30) + 30; // 30-60 ms
        _batteryPercent = max(2, _batteryPercent - (Random().nextDouble() > 0.9 ? 1 : 0));
        if (_ping > 50) {
          _networkQuality = 'Good';
        } else {
          _networkQuality = 'Excellent';
        }
      });
    });
  }

  @override
  void dispose() {
    _lobbyTimer.cancel();
    _pingTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ev = widget.event;
    final minPrize = ev.isPaid ? (ev.minParticipants * ev.entryFeeAmount * 0.58).toInt() : 0;
    final maxPrize = ev.isPaid ? (ev.maxParticipants * ev.entryFeeAmount * 0.58).toInt() : 0;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Event Waiting Lobby',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: NetworkImage(ev.bannerUrl),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Event Name & Category Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ev.title,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Category: ${ev.category} • Format: ${ev.format.name.toUpperCase()}',
                      style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, color: AppTheme.primaryColor, size: 14),
                    const SizedBox(width: 4),
                    Text('$_participantsJoined Joined', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Countdown Timer Banner ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor.withOpacity(0.12), AppTheme.secondaryColor.withOpacity(0.12)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Text(
                  'EVENT STARTING IN',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _timeBox('00', 'MIN'),
                    const Text(' : ', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                    _timeBox(_countdownSeconds.toString().padLeft(2, '0'), 'SEC'),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Event will start automatically. Do not close this screen.',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Diagnostics Monitor ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _diagnosticItem(Icons.wifi_rounded, 'Ping', '$_ping ms', Colors.green),
                _diagnosticItem(Icons.network_cell_rounded, 'Network', _networkQuality, Colors.blue),
                _diagnosticItem(Icons.battery_charging_full_rounded, 'Battery', '$_batteryPercent%', Colors.amber),
                _diagnosticItem(Icons.security_rounded, 'Secure Mode', ev.antiCheat.screenMonitoring ? 'ACTIVE' : 'OFF', ev.antiCheat.screenMonitoring ? Colors.purple : Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Prize Pool Card ─────────────────────────────────────────────────
          if (ev.isPaid) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🏆 Total Prize Pool', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('₹$minPrize - ₹$maxPrize', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 16, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const Divider(color: AppTheme.borderColor, height: 20),
                  _prizeDetail('🥇 1st Place (50%)', '₹${(minPrize * 0.5).toInt()} - ₹${(maxPrize * 0.5).toInt()}', const Color(0xFFFFD700)),
                  _prizeDetail('🥈 2nd Place (30%)', '₹${(minPrize * 0.3).toInt()} - ₹${(maxPrize * 0.3).toInt()}', const Color(0xFFC0C0C0)),
                  _prizeDetail('🥉 3rd Place (20%)', '₹${(minPrize * 0.2).toInt()} - ₹${(maxPrize * 0.2).toInt()}', const Color(0xFFCD7F32)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Voice Room Widget ───────────────────────────────────────────────
          if (ev.voiceRoomEnabled) ...[
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🎙️ Lobby Voice Channel', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('Owner is presenting live', style: TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
                        ],
                      ),
                      Switch(
                        value: _voiceConnected,
                        activeColor: AppTheme.accentColor,
                        onChanged: (v) {
                          setState(() {
                            _voiceConnected = v;
                          });
                        },
                      ),
                    ],
                  ),
                  if (_voiceConnected) ...[
                    const Divider(color: AppTheme.borderColor),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isMuted ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                            side: BorderSide(color: _isMuted ? Colors.red : Colors.green),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => setState(() => _isMuted = !_isMuted),
                          icon: Icon(_isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, color: _isMuted ? Colors.red : Colors.green, size: 14),
                          label: Text(_isMuted ? 'Muted' : 'Unmuted', style: TextStyle(color: _isMuted ? Colors.red : Colors.green, fontSize: 11)),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _handRaised ? AppTheme.primaryColor : AppTheme.textTertiary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => setState(() => _handRaised = !_handRaised),
                          icon: Icon(Icons.pan_tool_rounded, color: _handRaised ? AppTheme.primaryColor : AppTheme.textTertiary, size: 14),
                          label: Text(_handRaised ? 'Hand Raised' : 'Raise Hand', style: TextStyle(color: _handRaised ? AppTheme.primaryColor : AppTheme.textTertiary, fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Rules Box ───────────────────────────────────────────────────────
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
                const Text('📝 Event Rules', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...ev.rules.map((rule) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                          Expanded(child: Text(rule.trim(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Ready Button ────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isReady ? Colors.green : AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      setState(() {
                        _isReady = !_isReady;
                      });
                      HapticFeedback.mediumImpact();
                    },
                    icon: Icon(_isReady ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: Colors.white, size: 20),
                    label: Text(
                      _isReady ? 'READY TO START' : 'MARK AS READY',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _timeBox(String val, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Text(
            val,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _diagnosticItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 9)),
      ],
    );
  }

  Widget _prizeDetail(String title, String value, Color goldColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: goldColor, fontSize: 11, fontWeight: FontWeight.w700)),
          Text(value, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
