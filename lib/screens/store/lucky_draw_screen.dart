import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'dart:ui';
import '../../core/theme.dart';
import '../../services/store_controller.dart';

class LuckyDrawScreen extends StatefulWidget {
  const LuckyDrawScreen({Key? key}) : super(key: key);

  @override
  State<LuckyDrawScreen> createState() => _LuckyDrawScreenState();
}

class _LuckyDrawScreenState extends State<LuckyDrawScreen> with SingleTickerProviderStateMixin {
  final StoreController _storeCtrl = Get.find<StoreController>();
  late AnimationController _rotationCtrl;
  
  bool _isSpinning = false;
  double _currentRotation = 0.0;
  int _lastRewardIndex = 0;

  @override
  void initState() {
    super.initState();
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    super.dispose();
  }

  void _startSpin() {
    if (_isSpinning) return;
    if (_storeCtrl.coinsBalance.value < 100) {
      Get.snackbar(
        'Insufficient Coins! 🪙',
        'A lucky spin costs 100 coins. Top up your wallet in the Coin Store.',
        backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() {
      _isSpinning = true;
    });

    _storeCtrl.deductCoins(100, 'Lucky Spin Fee');

    // Simulate winning index
    final rewardIdx = _storeCtrl.performLuckySpin();
    _lastRewardIndex = rewardIdx;

    // Calculate rotation: 5 full spins + offset to land on the reward segment
    // Each segment is 45 degrees (2 * pi / 8)
    final double segmentAngle = 2 * pi / 8;
    // Align wheel so pointer at top (index 0 is at offset angle)
    final double targetAngle = (8 - rewardIdx) * segmentAngle - (pi / 2);
    final double totalSpinAngle = _currentRotation + (10 * pi) + targetAngle;

    final Animation<double> spinAnimation = Tween<double>(
      begin: _currentRotation,
      end: totalSpinAngle,
    ).animate(CurvedAnimation(parent: _rotationCtrl, curve: Curves.easeOutQuint));

    spinAnimation.addListener(() {
      setState(() {
        _currentRotation = spinAnimation.value;
      });
    });

    _rotationCtrl.forward(from: 0.0).then((_) {
      setState(() {
        _isSpinning = false;
        _currentRotation = _currentRotation % (2 * pi);
      });
      _showRewardDialog();
    });
  }

  void _showRewardDialog() {
    final reward = _storeCtrl.wheelRewards[_lastRewardIndex];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151518),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: reward.color.withOpacity(0.3), width: 1.5),
        ),
        title: Center(
          child: Text(
            '🎉 REWARD UNLOCKED!',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: reward.color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Text(reward.icon, style: const TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 20),
            Text(
              reward.name,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Your reward was added to your profile inventory.',
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: reward.color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Awesome',
                style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070A),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: 200,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.08),
                    blurRadius: 120,
                  )
                ],
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: const Color(0xFF07070A).withOpacity(0.85),
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    onPressed: () => Get.back(),
                  ),
                  title: Text(
                    'LUCKY WHEEL',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        _buildTopBalanceHeader(),
                        const SizedBox(height: 30),
                        _buildSpinWheelContainer(),
                        const SizedBox(height: 40),
                        _buildSpinHistoryList(),
                        const SizedBox(height: 30),
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

  Widget _buildTopBalanceHeader() {
    return Obx(() => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111115),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SPIN FEE: 100 COINS', style: GoogleFonts.outfit(color: const Color(0xFFFFB800), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Your Balance: 🪙 ${_storeCtrl.coinsBalance.value}', style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12)),
                ],
              ),
              const Icon(Icons.stars_rounded, color: Color(0xFFFFB800)),
            ],
          ),
        ));
  }

  Widget _buildSpinWheelContainer() {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.15), blurRadius: 40, spreadRadius: 10)
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Spin Wheel Graphic
          Transform.rotate(
            angle: _currentRotation,
            child: CustomPaint(
              size: const Size(270, 270),
              painter: WheelPainter(rewards: _storeCtrl.wheelRewards),
            ),
          ),

          // Wheel Center Button
          GestureDetector(
            onTap: _isSpinning ? null : _startSpin,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))
                ],
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  _isSpinning ? 'SPINNING' : 'SPIN',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
                ),
              ),
            ),
          ),

          // Spinner Pointer (Pointer at Top)
          Positioned(
            top: 2,
            child: CustomPaint(
              size: const Size(20, 20),
              painter: PointerPainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpinHistoryList() {
    return Obx(() {
      final history = _storeCtrl.luckySpinHistory;
      if (history.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SPIN REWARDS HISTORY',
            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: min(5, history.length),
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
                    Text(log['icon'] as String, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Won ${log['reward']}',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      'Just Now',
                      style: GoogleFonts.poppins(color: Colors.white24, fontSize: 10),
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

class WheelPainter extends CustomPainter {
  final List<LuckyDrawReward> rewards;
  WheelPainter({required this.rewards});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final double segmentAngle = 2 * pi / 8;
    final center = Offset(radius, radius);

    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black45
      ..strokeWidth = 1.5;

    for (int i = 0; i < 8; i++) {
      paint.color = rewards[i].color.withOpacity(0.2);
      final double startAngle = i * segmentAngle;

      // Draw segment arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        paint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        borderPaint,
      );

      // Draw reward label texts
      final double textAngle = startAngle + segmentAngle / 2;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(textAngle);

      final textSpan = TextSpan(
        text: '${rewards[i].icon} ${rewards[i].name.split(' ')[0]}',
        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.bold),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(radius * 0.45, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawShadow(path, Colors.black, 4, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
