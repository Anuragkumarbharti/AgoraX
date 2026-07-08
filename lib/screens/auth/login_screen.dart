import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'phone_auth_screen.dart';
import '../home/main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;

  late AnimationController _bgAnimCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _bgAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _bgAnimCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }



  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      Get.offAll(() => const MainScreen());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Get.snackbar(
        'Login Failed ⚠️',
        e.toString().replaceAll('AuthException: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  void _handleSocialLogin(String provider) {
    Get.snackbar(
      '$provider Sign-In',
      'Connecting to $provider…',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.bgLight,
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
    );
    Future.delayed(const Duration(seconds: 2), () {
      Get.offAll(() => const MainScreen());
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          // ── Animated gradient blobs ──────────────────────
          AnimatedBuilder(
            animation: _bgAnimCtrl,
            builder: (_, __) {
              final t = _bgAnimCtrl.value;
              return Stack(
                children: [
                  Positioned(
                    top: -80 + (t * 60),
                    left: -60 + (t * 40),
                    child: _blob(220, const Color(0xFF6366F1), 0.35),
                  ),
                  Positioned(
                    bottom: -100 + (t * 50),
                    right: -80 + (t * 30),
                    child: _blob(260, const Color(0xFF8B5CF6), 0.25),
                  ),
                  Positioned(
                    top: size.height * 0.45 - (t * 40),
                    right: -40,
                    child: _blob(160, const Color(0xFF10B981), 0.18),
                  ),
                ],
              );
            },
          ),

          // ── Main Content ─────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),

                    // Logo + App Name
                    _buildLogo(),
                    const SizedBox(height: 36),

                    // Glass card
                    _buildGlassCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome back 👋',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Login to continue your journey',
                              style: TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Email Field
                            _buildLabel('Email or Username'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _emailCtrl,
                              hint: 'name@domain.com',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email address is required';
                                }
                                // Proper email regex
                                final emailRegex = RegExp(
                                  r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
                                );
                                if (!emailRegex.hasMatch(v.trim())) {
                                  return 'Enter a valid email (e.g. john@gmail.com)';
                                }
                                // Block dummy/placeholder domains
                                final domain = v.trim().split('@').last.toLowerCase();
                                const blockedDomains = [
                                  'example.com', 'example.org', 'example.net',
                                  'test.com', 'sample.com', 'dummy.com',
                                ];
                                if (blockedDomains.contains(domain)) {
                                  return 'Please use a real email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            // Password Field
                            _buildLabel('Password'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _passCtrl,
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                              isPasswordVisible: _isPasswordVisible,
                              onTogglePassword: () => setState(
                                  () => _isPasswordVisible = !_isPasswordVisible),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Password is required';
                                }
                                if (v.length < 8) {
                                  return 'Password must be at least 8 characters';
                                }
                                if (!RegExp(r'[A-Z]').hasMatch(v)) {
                                  return 'Must contain at least one uppercase letter';
                                }
                                if (!RegExp(r'[a-z]').hasMatch(v)) {
                                  return 'Must contain at least one lowercase letter';
                                }
                                if (!RegExp(r'[0-9]').hasMatch(v)) {
                                  return 'Must contain at least one number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Remember me + Forgot password
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          onChanged: (v) => setState(
                                              () => _rememberMe = v ?? false),
                                          activeColor: AppTheme.primaryColor,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Flexible(
                                        child: Text(
                                          'Remember me',
                                          style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => Get.to(
                                      () => const ForgotPasswordScreen()),
                                  child: const Text(
                                    'Forgot?',
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),

                            // Login Button
                            _buildPrimaryButton(
                              label: 'Login',
                              isLoading: _isLoading,
                              onTap: _handleLogin,
                            ),
                            const SizedBox(height: 24),

                            // Divider
                            _buildDivider('or continue with'),
                            const SizedBox(height: 20),

                            // Social Buttons Row (Google, Apple, Phone)
                            _buildSocialRow(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sign Up Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: () => Get.to(() => const SignupScreen()),
                          child: const Text(
                            'Create Account',
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
    );
  }

  // ── WIDGETS ───────────────────────────────────────────────

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

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.5),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Ax',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'AgoraX',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const Text(
          'Learn · Discuss · Connect',
          style: TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
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
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !isPasswordVisible,
      keyboardType: keyboardType,
      validator: validator,
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      letterSpacing: 0.3,
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
          child: Text(
            text,
            style:
                const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
          ),
        ),
        Expanded(
            child: Divider(color: Colors.white.withOpacity(0.12), height: 1)),
      ],
    );
  }

  Widget _buildSocialRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _socialIconButton(
          icon: _googleIcon(),
          onTap: () => _handleSocialLogin('Google'),
        ),
        const SizedBox(width: 20),
        _socialIconButton(
          icon: const Icon(Icons.apple_rounded, color: Colors.white, size: 26),
          onTap: () => _handleSocialLogin('Apple'),
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

  Widget _googleIcon() {
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

    // Blue sector
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -1.047,
      2.094,
      true,
      paint,
    );
    // Green sector
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      0.524,
      1.047,
      true,
      paint,
    );
    // Yellow sector
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      2.094,
      1.047,
      true,
      paint,
    );
    // Red sector
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      3.142,
      1.047,
      true,
      paint,
    );

    // White center circle
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.6, paint);

    // Inner blue bar
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTRB(cx, cy - r * 0.14, cx + r, cy + r * 0.14),
      paint,
    );
    // Inner white to separate
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.38, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
