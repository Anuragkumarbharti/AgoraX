import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import 'login_screen.dart';
import 'email_verification_screen.dart';
import 'phone_auth_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isPassVisible = false;
  bool _isConfirmPassVisible = false;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  int _currentStep = 0;
  int _passwordStrength = 0; // 0=empty 1=weak 2=medium 3=strong 4=very strong

  late AnimationController _bgAnimCtrl;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _bgAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _bgAnimCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _handleSignup() {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      Get.snackbar(
        'Terms Required',
        'Please agree to the Terms & Conditions to continue.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }
    setState(() => _isLoading = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Get.offAll(() => EmailVerificationScreen(
            email: _emailCtrl.text,
            userId: '123',
          ));
    });
  }

  void _handleSocialSignup(String provider) {
    Get.snackbar(
      '$provider Sign-Up',
      'Connecting to $provider…',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.bgLight,
      colorText: Colors.white,
    );
    Future.delayed(const Duration(seconds: 2), () {
      Get.offAll(() => EmailVerificationScreen(
            email: '${provider.toLowerCase()}@agorax.app',
            userId: '456',
          ));
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          // ── Animated blobs ──────────────────────────────
          AnimatedBuilder(
            animation: _bgAnimCtrl,
            builder: (_, __) {
              final t = _bgAnimCtrl.value;
              return Stack(
                children: [
                  Positioned(
                    top: -100 + (t * 70),
                    right: -60 + (t * 30),
                    child: _blob(240, const Color(0xFF8B5CF6), 0.30),
                  ),
                  Positioned(
                    bottom: -80 + (t * 40),
                    left: -60 + (t * 40),
                    child: _blob(200, const Color(0xFF6366F1), 0.22),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.5,
                    left: -30 + (t * 20),
                    child: _blob(140, const Color(0xFF10B981), 0.15),
                  ),
                ],
              );
            },
          ),

          // ── Main Content ─────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SlideTransition(
                    position: _slideAnim,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _buildStepIndicator(),
                          const SizedBox(height: 20),
                          _buildGlassCard(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Join AgoraX 🚀',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Create your account in 30 seconds',
                                    style: TextStyle(
                                      color: AppTheme.textTertiary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // ── Social Row ───────────────────
                                  _buildSocialRow(),
                                  const SizedBox(height: 20),
                                  _buildDivider('or sign up with email'),
                                  const SizedBox(height: 20),

                                  // ── Full Name ───────────────────
                                  _buildLabel('Full Name'),
                                  const SizedBox(height: 8),
                                  _buildTextField(
                                    controller: _nameCtrl,
                                    hint: 'e.g. Anurag Kumar',
                                    icon: Icons.person_outline_rounded,
                                    validator: (v) => v == null || v.isEmpty
                                        ? 'Enter your name'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),

                                  // ── Username ─────────────────────
                                  _buildLabel('Username'),
                                  const SizedBox(height: 8),
                                  _buildTextField(
                                    controller: _usernameCtrl,
                                    hint: 'e.g. anurag_99',
                                    icon: Icons.alternate_email_rounded,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Enter a username';
                                      }
                                      if (v.contains(' ')) {
                                        return 'No spaces allowed';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // ── Email ────────────────────────
                                  _buildLabel('Email Address'),
                                  const SizedBox(height: 8),
                                  _buildTextField(
                                    controller: _emailCtrl,
                                    hint: 'john@gmail.com',
                                    icon: Icons.mail_outline_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Email address is required';
                                      }
                                      final emailRegex = RegExp(
                                        r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
                                      );
                                      if (!emailRegex.hasMatch(v.trim())) {
                                        return 'Enter a valid email (e.g. john@gmail.com)';
                                      }
                                      final domain = v.trim().split('@').last.toLowerCase();
                                      const blockedDomains = [
                                        'example.com', 'example.org',
                                        'example.net', 'test.com',
                                        'sample.com', 'dummy.com',
                                      ];
                                      if (blockedDomains.contains(domain)) {
                                        return 'Please use a real email address';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // ── Password ─────────────────────
                                  _buildLabel('Password'),
                                  const SizedBox(height: 8),
                                  _buildTextField(
                                    controller: _passCtrl,
                                    hint: 'Min 8 chars, A-Z, a-z, 0-9',
                                    icon: Icons.lock_outline_rounded,
                                    isPassword: true,
                                    isPasswordVisible: _isPassVisible,
                                    onTogglePassword: () => setState(
                                        () => _isPassVisible = !_isPassVisible),
                                    onChanged: (v) {
                                      setState(() => _passwordStrength = _calcStrength(v));
                                    },
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Password is required';
                                      }
                                      if (v.length < 8) {
                                        return 'Password must be at least 8 characters';
                                      }
                                      if (!RegExp(r'[A-Z]').hasMatch(v)) {
                                        return 'Add at least one uppercase letter (A-Z)';
                                      }
                                      if (!RegExp(r'[a-z]').hasMatch(v)) {
                                        return 'Add at least one lowercase letter (a-z)';
                                      }
                                      if (!RegExp(r'[0-9]').hasMatch(v)) {
                                        return 'Add at least one number (0-9)';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  // Password strength meter
                                  if (_passCtrl.text.isNotEmpty)
                                    _buildPasswordStrengthMeter(),
                                  const SizedBox(height: 16),

                                  // ── Confirm Password ─────────────
                                  _buildLabel('Confirm Password'),
                                  const SizedBox(height: 8),
                                  _buildTextField(
                                    controller: _confirmPassCtrl,
                                    hint: 'Re-enter password',
                                    icon: Icons.lock_outline_rounded,
                                    isPassword: true,
                                    isPasswordVisible: _isConfirmPassVisible,
                                    onTogglePassword: () => setState(() =>
                                        _isConfirmPassVisible =
                                            !_isConfirmPassVisible),
                                    validator: (v) {
                                      if (v != _passCtrl.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  // ── Terms ────────────────────────
                                  _buildTermsRow(),
                                  const SizedBox(height: 24),

                                  // ── Create Account Button ─────────
                                  _buildPrimaryButton(
                                    label: 'Create Account',
                                    isLoading: _isLoading,
                                    onTap: _handleSignup,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Login Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Already have an account? ',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13),
                              ),
                              GestureDetector(
                                onTap: () => Get.back(),
                                child: const Text(
                                  'Login',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
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

  // ── WIDGETS ─────────────────────────────────────────────

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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const Spacer(),
          const Text(
            'AgoraX',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40), // balance
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepDot(0, 'Account'),
        Container(
          width: 32,
          height: 2,
          color: AppTheme.primaryColor.withOpacity(0.3),
          margin: const EdgeInsets.symmetric(horizontal: 6),
        ),
        _stepDot(1, 'Verify'),
        Container(
          width: 32,
          height: 2,
          color: AppTheme.primaryColor.withOpacity(0.3),
          margin: const EdgeInsets.symmetric(horizontal: 6),
        ),
        _stepDot(2, 'Done'),
      ],
    );
  }

  Widget _stepDot(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? AppTheme.primaryColor
                : Colors.white.withOpacity(0.1),
            border: Border.all(
              color: isActive
                  ? AppTheme.primaryColor
                  : Colors.white.withOpacity(0.2),
            ),
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : AppTheme.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              color: isActive ? AppTheme.primaryColor : AppTheme.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            )),
      ],
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onTogglePassword,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !isPasswordVisible,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 14),
        prefixIcon: Icon(icon, color: AppTheme.textTertiary, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppTheme.textTertiary,
                  size: 20,
                ),
                onPressed: onTogglePassword,
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
        errorStyle: const TextStyle(color: AppTheme.errorColor, fontSize: 11),
      ),
    );
  }

  // ── Password Strength Helpers ───────────────────────────────────────────────
  int _calcStrength(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
    if (score <= 1) return 1; // Weak
    if (score <= 3) return 2; // Medium
    if (score <= 4) return 3; // Strong
    return 4;                  // Very Strong
  }

  Widget _buildPasswordStrengthMeter() {
    final labels = ['', 'Weak', 'Medium', 'Strong', 'Very Strong'];
    final colors = [
      Colors.transparent,
      const Color(0xFFEF4444), // red
      const Color(0xFFF59E0B), // amber
      const Color(0xFF3B82F6), // blue
      const Color(0xFF10B981), // green
    ];
    final strength = _passwordStrength.clamp(0, 4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i < strength
                      ? colors[strength]
                      : Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              strength > 0 ? labels[strength] : '',
              style: TextStyle(
                color: colors[strength],
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Use A-Z, a-z, 0-9 & symbols',
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _socialIconButton(
          icon: _googleColorIcon(),
          onTap: () => _handleSocialSignup('Google'),
        ),
        const SizedBox(width: 20),
        _socialIconButton(
          icon: const Icon(Icons.apple_rounded, color: Colors.white, size: 26),
          onTap: () => _handleSocialSignup('Apple'),
        ),
        const SizedBox(width: 20),
        _socialIconButton(
          icon: const Icon(Icons.phone_iphone_rounded, color: AppTheme.accentColor, size: 26),
          onTap: () => Get.to(() => const PhoneAuthScreen()),
        ),
      ],
    );
  }

  Widget _socialIconButton({
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Center(
          child: SizedBox(width: 26, height: 26, child: icon),
        ),
      ),
    );
  }

  Widget _buildTermsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: _agreeToTerms,
            onChanged: (v) => setState(() => _agreeToTerms = v ?? false),
            activeColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: const TextSpan(
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12, height: 1.5),
              children: [
                TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms of Service',
                  style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600),
                ),
                TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding: EdgeInsets.zero,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(String text) {
    return Row(
      children: [
        Expanded(
            child: Divider(color: Colors.white.withOpacity(0.12), height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(text,
              style: const TextStyle(
                  color: AppTheme.textTertiary, fontSize: 11)),
        ),
        Expanded(
            child: Divider(color: Colors.white.withOpacity(0.12), height: 1)),
      ],
    );
  }

  Widget _googleColorIcon() {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -1.047, 2.094, true, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        0.524, 1.047, true, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        2.094, 1.047, true, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        3.142, 1.047, true, paint);

    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.6, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
        Rect.fromLTRB(cx, cy - r * 0.14, cx + r, cy + r * 0.14), paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.38, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
