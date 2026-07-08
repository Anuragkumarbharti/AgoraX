import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../home/main_screen.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({Key? key}) : super(key: key);

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen>
    with TickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _otp1 = TextEditingController();
  final _otp2 = TextEditingController();
  final _otp3 = TextEditingController();
  final _otp4 = TextEditingController();
  final _otp5 = TextEditingController();
  final _otp6 = TextEditingController();

  late AnimationController _bgAnimCtrl;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  bool _isOtpSent = false;
  bool _isLoading = false;
  bool _isVerifying = false;
  int _resendCountdown = 0;
  String _selectedCountry = '🇮🇳 +91';

  final List<Map<String, String>> _countries = const [
    {'flag': '🇮🇳', 'code': '+91', 'name': 'India'},
    {'flag': '🇺🇸', 'code': '+1', 'name': 'USA'},
    {'flag': '🇬🇧', 'code': '+44', 'name': 'UK'},
    {'flag': '🇦🇪', 'code': '+971', 'name': 'UAE'},
    {'flag': '🇨🇦', 'code': '+1', 'name': 'Canada'},
    {'flag': '🇦🇺', 'code': '+61', 'name': 'Australia'},
    {'flag': '🇩🇪', 'code': '+49', 'name': 'Germany'},
    {'flag': '🇫🇷', 'code': '+33', 'name': 'France'},
    {'flag': '🇯🇵', 'code': '+81', 'name': 'Japan'},
    {'flag': '🇸🇬', 'code': '+65', 'name': 'Singapore'},
  ];

  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  late List<TextEditingController> _otpCtrls;

  @override
  void initState() {
    super.initState();
    _otpCtrls = [_otp1, _otp2, _otp3, _otp4, _otp5, _otp6];
    _bgAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    _bgAnimCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _sendOtp() {
    if (_phoneCtrl.text.length < 7) {
      Get.snackbar(
        'Invalid Number',
        'Please enter a valid phone number',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      _shakeCtrl.forward(from: 0);
      return;
    }
    setState(() => _isLoading = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isOtpSent = true;
        _resendCountdown = 30;
      });
      _startCountdown();
      FocusScope.of(context).requestFocus(_otpFocusNodes[0]);
    });
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
        _startCountdown();
      }
    });
  }

  void _verifyOtp() {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length < 6) {
      Get.snackbar(
        'Enter OTP',
        'Please enter the 6-digit OTP code',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      _shakeCtrl.forward(from: 0);
      return;
    }
    setState(() => _isVerifying = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      Get.snackbar(
        '✅ Verified!',
        'Phone number verified successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.accentColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      Future.delayed(const Duration(milliseconds: 800), () {
        Get.offAll(() => const MainScreen());
      });
    });
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Country',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppTheme.borderColor),
          Expanded(
            child: ListView.builder(
              itemCount: _countries.length,
              itemBuilder: (_, i) {
                final c = _countries[i];
                return ListTile(
                  leading: Text(c['flag']!, style: const TextStyle(fontSize: 24)),
                  title: Text(
                    c['name']!,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  trailing: Text(
                    c['code']!,
                    style: const TextStyle(
                        color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    setState(() =>
                        _selectedCountry = '${c['flag']} ${c['code']}');
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          // Animated background
          AnimatedBuilder(
            animation: _bgAnimCtrl,
            builder: (_, __) {
              final t = _bgAnimCtrl.value;
              return Stack(
                children: [
                  Positioned(
                    top: -80 + (t * 50),
                    right: -60,
                    child: _blob(200, const Color(0xFF10B981), 0.25),
                  ),
                  Positioned(
                    bottom: -80 + (t * 40),
                    left: -60,
                    child: _blob(220, const Color(0xFF6366F1), 0.22),
                  ),
                ],
              );
            },
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF10B981).withOpacity(0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.phone_rounded,
                              color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          _isOtpSent ? 'Verify Your Number' : 'Phone Sign-In',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isOtpSent
                              ? 'Enter the 6-digit code sent to\n$_selectedCountry ${_phoneCtrl.text}'
                              : 'Enter your phone number to receive\na one-time verification code',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Glass card
                        _buildGlassCard(
                          child: _isOtpSent
                              ? _buildOtpStep()
                              : _buildPhoneStep(),
                        ),
                        const SizedBox(height: 32),
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

  Widget _buildPhoneStep() {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(_shakeAnim.value, 0),
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Phone Number',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Country code picker
              GestureDetector(
                onTap: _showCountryPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedCountry,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.textTertiary, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 15,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '9876543210',
                    hintStyle: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 15),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppTheme.accentColor, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Privacy note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.accentColor.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined,
                    color: AppTheme.accentColor, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your number is encrypted and will never be shared with third parties.',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Send OTP button
          _buildActionButton(
            label: 'Send OTP',
            isLoading: _isLoading,
            icon: Icons.send_rounded,
            onTap: _sendOtp,
            color: AppTheme.accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    return Column(
      children: [
        // OTP Boxes
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (_, child) => Transform.translate(
            offset: Offset(_shakeAnim.value, 0),
            child: child,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (i) => _buildOtpBox(i)),
          ),
        ),
        const SizedBox(height: 24),

        // Resend row
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              "Didn't receive? ",
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            ),
            GestureDetector(
              onTap: _resendCountdown == 0 ? _sendOtp : null,
              child: Text(
                _resendCountdown > 0
                    ? 'Resend in ${_resendCountdown}s'
                    : 'Resend OTP',
                style: TextStyle(
                  color: _resendCountdown == 0
                      ? AppTheme.primaryColor
                      : AppTheme.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Verify button
        _buildActionButton(
          label: 'Verify OTP',
          isLoading: _isVerifying,
          icon: Icons.verified_rounded,
          onTap: _verifyOtp,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(height: 16),

        // Back to phone
        TextButton(
          onPressed: () => setState(() {
            _isOtpSent = false;
            for (final c in _otpCtrls) c.clear();
          }),
          child: const Text(
            'Change Phone Number',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 44,
      height: 54,
      child: TextFormField(
        controller: _otpCtrls[index],
        focusNode: _otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white.withOpacity(0.07),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: AppTheme.primaryColor, width: 2),
          ),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) {
            FocusScope.of(context)
                .requestFocus(_otpFocusNodes[index + 1]);
          }
          if (v.isEmpty && index > 0) {
            FocusScope.of(context)
                .requestFocus(_otpFocusNodes[index - 1]);
          }
          if (index == 5 && v.isNotEmpty) {
            FocusScope.of(context).unfocus();
          }
        },
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required bool isLoading,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.15),
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.4)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: TextStyle(
            color: isLoading ? AppTheme.textTertiary : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _blob(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: const SizedBox(),
      ),
    );
  }
}
