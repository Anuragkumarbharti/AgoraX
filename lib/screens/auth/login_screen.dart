import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import 'signup_flow_screen.dart';
import 'forgot_password_screen.dart';
import 'phone_auth_screen.dart';
import '../home/main_screen.dart';
import '../../services/user_profile_cache_manager.dart';
import '../../services/user_progress_sync_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _socialEmailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _showEmailForm = false; // Toggle between selector and email form

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
    _socialEmailCtrl.dispose();
    _bgAnimCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _checkProfileAndNavigate(String userId) async {
    try {
      // 1. Force refresh profile and progress cache from Supabase
      await UserProfileCacheManager.getOrFetchCanonicalId();
      await UserProfileCacheManager.fetchUserProfile('me', forceRefresh: true);
      await UserProgressSyncService.syncFromSupabase();

      final res = await Supabase.instance.client
          .from('profiles')
          .select('username, display_name, interests')
          .eq('id', userId)
          .maybeSingle();

      if (res == null) {
        Get.offAll(() => SignupFlowScreen(userId: userId, startStep: 1));
        return;
      }

      final username = res['username'] ?? '';
      final interests = List<String>.from(res['interests'] ?? []);

      if (username.startsWith('user_') || username.isEmpty || interests.length < 5) {
        Get.offAll(() => SignupFlowScreen(userId: userId, startStep: 1));
      } else {
        Get.offAll(() => const MainScreen());
      }
    } catch (_) {
      Get.offAll(() => const MainScreen());
    }
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    final email = _emailCtrl.text.trim();
    try {
      // 1. Check if email exists in profiles table
      final res = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (res == null) {
        setState(() => _isLoading = false);
        Get.defaultDialog(
          title: 'No Account Found ⚠️',
          titleStyle: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
          backgroundColor: AppTheme.bgLight,
          contentPadding: const EdgeInsets.all(20),
          content: Column(
            children: [
              Text(
                'No account found with this email.',
                style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () {
                  Get.back();
                  Get.to(() => SignupFlowScreen(startStep: 0, prefilledEmail: email));
                },
                child: Text('Create New Account', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: null, // Disabled Forgot Password since account doesn't exist
                child: Text('Forgot Password?', style: GoogleFonts.poppins(color: AppTheme.textTertiary)),
              ),
            ],
          ),
        );
        return;
      }

      // 2. Perform Login
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _passCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.user != null) {
        _checkProfileAndNavigate(response.user!.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      final errStr = e.toString().toLowerCase();
      String finalMsg = e.toString().replaceAll('AuthException: ', '');
      if (errStr.contains('invalid login credentials') || errStr.contains('invalid_credentials')) {
        finalMsg = 'Incorrect password.';
      }

      Get.snackbar(
        'Login Failed ⚠️',
        finalMsg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  void _handleSocialLogin(String provider) async {
    // Show input dialog to simulate OAuth flow email
    Get.defaultDialog(
      title: 'Simulate $provider Sign In',
      titleStyle: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
      backgroundColor: AppTheme.bgLight,
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        children: [
          Text(
            'Enter the $provider account email to simulate the OAuth authentication:',
            style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _socialEmailCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'user@domain.com',
            ),
          ),
        ],
      ),
      textConfirm: 'Continue',
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.primaryColor,
      textCancel: 'Cancel',
      cancelTextColor: AppTheme.textSecondary,
      onConfirm: () {
        final email = _socialEmailCtrl.text.trim();
        if (email.isEmpty || !email.contains('@')) {
          Get.snackbar('Error', 'Please enter a valid email');
          return;
        }
        Get.back(); // Close input dialog
        _processSocialLogin(provider, email);
      }
    );
  }

  void _processSocialLogin(String provider, String email) async {
    setState(() => _isLoading = true);
    try {
      final providerColumn = provider.toLowerCase() == 'google' ? 'google_provider_id' : 'apple_provider_id';
      
      // Check if both provider ID and email are completely new
      final res = await Supabase.instance.client
          .from('profiles')
          .select('id, email, google_provider_id, apple_provider_id')
          .or('email.eq.$email,$providerColumn.eq.$email')
          .maybeSingle();

      if (res == null) {
        setState(() => _isLoading = false);
        // Both provider ID and email are completely new: show "No account found..."
        Get.defaultDialog(
          title: 'Account Not Found ⚠️',
          titleStyle: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
          backgroundColor: AppTheme.bgLight,
          contentPadding: const EdgeInsets.all(20),
          content: Column(
            children: [
              Text(
                'No account found with this $provider account.',
                style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () {
                  Get.back();
                  Get.to(() => SignupFlowScreen(
                    startStep: 0, 
                    prefilledEmail: email,
                    prefilledProvider: provider,
                  ));
                },
                child: Text('Create Account', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(color: AppTheme.borderColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () => Get.back(),
                child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ],
          ),
        );
        return;
      }

      // If exists, perform sandbox password reset and sign in to link the provider
      // Set the password to 'SocialPassword123!' so we can sign in
      await Supabase.instance.client.rpc('dev_reset_password', params: {
        'user_email': email,
        'user_phone': '',
        'new_password': 'SocialPassword123!',
      });

      // Sign In with mock OAuth credentials
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: 'SocialPassword123!',
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.user != null) {
        _checkProfileAndNavigate(response.user!.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Get.snackbar(
        'Social Auth Failed ⚠️',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          // Animated blobs background
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

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 36),

                      _buildGlassCard(
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: _showEmailForm ? _buildEmailLoginForm() : _buildAuthSelector(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Terms & Policy
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: GoogleFonts.poppins(color: AppTheme.textTertiary, fontSize: 11, height: 1.5),
                            children: [
                              const TextSpan(text: 'By continuing, you agree to the '),
                              TextSpan(
                                text: 'Terms of Service',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                              ),
                              const TextSpan(text: ' & '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Auth Options Selector ---
  Widget _buildAuthSelector() {
    return Column(
      children: [
        Text(
          'Create. Connect. Grow.',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),

        _socialButton(
          label: 'Continue with Google',
          icon: _googleIcon(),
          onTap: () => _handleSocialLogin('Google'),
        ),
        const SizedBox(height: 12),

        _socialButton(
          label: 'Continue with Apple',
          icon: const Icon(Icons.apple_rounded, color: Colors.white, size: 22),
          onTap: () => _handleSocialLogin('Apple'),
        ),
        const SizedBox(height: 12),

        _socialButton(
          label: 'Continue with Phone',
          icon: const Icon(Icons.phone_iphone_rounded, color: AppTheme.accentColor, size: 22),
          onTap: () => Get.to(() => const PhoneAuthScreen()),
        ),
        const SizedBox(height: 12),

        _socialButton(
          label: 'Continue with Email',
          icon: const Icon(Icons.email_outlined, color: AppTheme.primaryColor, size: 22),
          onTap: () {
            setState(() {
              _showEmailForm = true;
            });
          },
        ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Don't have an account? ", style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13)),
            GestureDetector(
              onTap: () => Get.to(() => const SignupFlowScreen(startStep: 0)),
              child: Text(
                'Sign Up',
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Email Login Form ---
  Widget _buildEmailLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Welcome Back', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                onPressed: () {
                  setState(() {
                    _showEmailForm = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildLabel('Email Address'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _emailCtrl,
            hint: 'name@domain.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),

          _buildLabel('Password'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _passCtrl,
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            isPasswordVisible: _isPasswordVisible,
            onTogglePassword: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              return null;
            },
          ),
          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => Get.to(() => const ForgotPasswordScreen()),
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.poppins(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 24),

          _buildPrimaryButton(
            label: 'Login',
            isLoading: _isLoading,
            onTap: _handleLogin,
          ),
        ],
      ),
    );
  }

  // --- Utility Widgets ---
  Widget _blob(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(opacity)),
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
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => Center(
                child: Text(
                  'C',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Creania',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
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
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
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
                  isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppTheme.textTertiary,
                  size: 20,
                ),
                onPressed: onTogglePassword,
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _socialButton({
    required String label,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.12)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.white.withOpacity(0.04),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
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
          backgroundColor: AppTheme.primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
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

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), -1.047, 2.094, true, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), 0.524, 1.047, true, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), 2.094, 1.047, true, paint);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), 3.142, 1.047, true, paint);

    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.6, paint);

    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTRB(cx, cy - r * 0.14, cx + r, cy + r * 0.14), paint);

    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.38, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
