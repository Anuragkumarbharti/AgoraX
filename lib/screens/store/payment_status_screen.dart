import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'store_home_screen.dart';

class PaymentStatusScreen extends StatefulWidget {
  final bool isSuccess;
  final String productName;
  final double pricePaid;
  final String? errorMessage;

  const PaymentStatusScreen({
    Key? key,
    required this.isSuccess,
    required this.productName,
    required this.pricePaid,
    this.errorMessage,
  }) : super(key: key);

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> with TickerProviderStateMixin {
  late AnimationController _animCtrl;
  late AnimationController _sparkleCtrl;
  final List<PointParticle> _sparks = [];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    if (widget.isSuccess) {
      _generateParticles();
    }
  }

  void _generateParticles() {
    final rand = Random();
    for (int i = 0; i < 40; i++) {
      _sparks.add(PointParticle(
        x: rand.nextDouble() * 300 - 150,
        y: rand.nextDouble() * 300 - 150,
        size: rand.nextDouble() * 8 + 4,
        speed: rand.nextDouble() * 1.5 + 0.5,
        angle: rand.nextDouble() * 2 * pi,
        color: rand.nextBool()
            ? const Color(0xFFFFD700)
            : rand.nextBool()
                ? const Color(0xFFD946EF)
                : const Color(0xFF8B5CF6),
      ));
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _sparkleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color mainColor = widget.isSuccess ? const Color(0xFFFFD700) : const Color(0xFFEF4444);

    return Scaffold(
      backgroundColor: const Color(0xFF07070A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF111115),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: mainColor.withOpacity(0.2), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: mainColor.withOpacity(0.05),
                      blurRadius: 30,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAnimatedGraphic(mainColor),
                    const SizedBox(height: 28),
                    Text(
                      widget.isSuccess ? 'PURCHASE SUCCESSFUL! 🎉' : 'TRANSACTION FAILED ⚠️',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.isSuccess
                          ? 'Thank you for upgrading! Your premium credentials are now active on your Creania profile.'
                          : widget.errorMessage ?? 'Something went wrong while communicating with Razorpay security channels. No coins were deducted.',
                      style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _buildReceiptPanel(mainColor),
                    const SizedBox(height: 32),
                    _buildActions(mainColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedGraphic(Color mainColor) {
    return AnimatedBuilder(
      animation: _sparkleCtrl,
      builder: (context, child) {
        return CustomPaint(
          painter: SuccessSparklePainter(
            particles: _sparks,
            progress: _animCtrl.value,
            sparkleProgress: _sparkleCtrl.value,
            isSuccess: widget.isSuccess,
          ),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mainColor.withOpacity(0.1),
              border: Border.all(color: mainColor.withOpacity(0.3), width: 2),
            ),
            child: Center(
              child: Icon(
                widget.isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: mainColor,
                size: 48,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptPanel(Color mainColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        children: [
          _receiptRow('Product', widget.productName),
          _receiptRow('Amount Paid', '₹${widget.pricePaid.toStringAsFixed(2)}', valueColor: mainColor),
          _receiptRow('Status', widget.isSuccess ? 'Settled' : 'Failed', valueColor: widget.isSuccess ? Colors.green : Colors.redAccent),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String val, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
          Text(
            val,
            style: GoogleFonts.poppins(color: valueColor ?? Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(Color mainColor) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: mainColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (widget.isSuccess) {
                Get.offAll(() => const StoreHomeScreen());
              } else {
                Get.back(); // Try again
              }
            },
            child: Text(
              widget.isSuccess ? 'Continue Shopping' : 'Retry Payment',
              style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
        if (!widget.isSuccess) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Get.snackbar('Support Ticket', 'A payment support ticket was opened.', snackPosition: SnackPosition.BOTTOM);
            },
            child: Text('Contact Support 💬', style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12)),
          ),
        ],
      ],
    );
  }
}

class PointParticle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double angle;
  final Color color;

  PointParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.angle,
    required this.color,
  });
}

class SuccessSparklePainter extends CustomPainter {
  final List<PointParticle> particles;
  final double progress;
  final double sparkleProgress;
  final bool isSuccess;

  SuccessSparklePainter({
    required this.particles,
    required this.progress,
    required this.sparkleProgress,
    required this.isSuccess,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isSuccess) return;

    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);

    for (var p in particles) {
      final double distance = p.speed * progress * 80;
      final double dx = center.dx + cos(p.angle + sparkleProgress) * distance;
      final double dy = center.dy + sin(p.angle + sparkleProgress) * distance;

      final double alpha = (1.0 - progress).clamp(0.0, 1.0);
      paint.color = p.color.withOpacity(alpha);

      canvas.drawCircle(Offset(dx, dy), p.size * (1.0 - progress * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant SuccessSparklePainter oldDelegate) => true;
}
