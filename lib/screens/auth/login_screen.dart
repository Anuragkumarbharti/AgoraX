import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:creania/core/theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import './signup_flow_screen.dart';
import './terms_screen.dart';
import '../home/main_screen.dart';
import '../../services/user/user_profile_cache_manager.dart';
import '../../services/user/user_progress_sync_service.dart';
import '../../core/api_error_handler.dart';
import '../../services/auth/auth_memory_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _socialEmailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _otpSent = false;
  bool _isPasswordVisible = false;
  bool _usePasswordLogin = true;
  bool _showEmailForm = false;
  bool _rememberMe = true;
  StreamSubscription<AuthState>? _authSubscription;

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

    // Load auth memory synchronously before first frame
    _loadAuthMemory();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      if (event == AuthChangeEvent.signedIn && session != null) {
        // Save OAuth login memory on social sign-in callback
        if (_pendingSocialMethod != null) {
          final email = session.user.email;
          AuthMemoryService.saveSuccessfulLogin(
            method: _pendingSocialMethod!,
            rememberMe: _rememberMe,
            email: email,
            refreshToken: session.refreshToken,
          );
          _pendingSocialMethod = null;
        }
        _checkProfileAndNavigate(session.user.id);
      }
    });
  }

  Future<void> _loadAuthMemory() async {
    await AuthMemoryService.load();
    if (!mounted) return;
    setState(() {
      _rememberMe = AuthMemoryService.rememberMe;
      // Smart auto-fill: pre-fill email if last login was email-based
      if (AuthMemoryService.lastEmail != null &&
          (AuthMemoryService.lastMethod == LoginMethod.email ||
           AuthMemoryService.lastMethod == null)) {
        _emailCtrl.text = AuthMemoryService.lastEmail!;
      }
    });
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _socialEmailCtrl.dispose();
    _bgAnimCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  bool _isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    final regExp = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return regExp.hasMatch(id);
  }

  void _checkProfileAndNavigate(String userId) async {
    if (!_isValidUuid(userId)) {
      Get.offAll(() => SignupFlowScreen(userId: null, startStep: 1));
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('username, display_name, interests, status, is_banned, ban_reason, signup_status, age, gender, avatar_url, bio')
          .eq('id', userId)
          .maybeSingle();

      if (res == null) {
        Get.offAll(() => SignupFlowScreen(userId: userId, startStep: 1));
        return;
      }

      final status = res['status'] as String?;
      final isBanned = res['is_banned'] as bool? ?? false;
      final banReason = res['ban_reason'] as String?;

      if (status == 'suspended' || status == 'banned' || isBanned) {
        await UserProfileCacheManager.forceLogout(
          message: banReason != null && banReason.isNotEmpty
              ? "Your account has been suspended. Reason: $banReason"
              : "Your account has been suspended.",
        );
        return;
      }

      final signupStatus = res['signup_status'] as String? ?? 'completed';
      if (signupStatus != 'completed') {
        int startStep = 1;
        final username = res['username'] ?? '';
        final interests = List<String>.from(res['interests'] ?? []);
        final age = res['age'] as int? ?? 0;
        final gender = res['gender'] as String?;
        final avatar = res['avatar_url'] as String?;
        final bio = res['bio'] as String?;

        if (username.isNotEmpty && !username.startsWith('user_')) {
          if (age == 0 || gender == null || gender.isEmpty) {
            startStep = 2;
          } else if (avatar == null || avatar.isEmpty) {
            startStep = 3;
          } else if (bio == null || bio.isEmpty) {
            startStep = 4;
          } else if (interests.isEmpty) {
            startStep = 5;
          } else {
            startStep = 6;
          }
        }
        Get.offAll(() => SignupFlowScreen(userId: userId, startStep: startStep));
        return;
      }

      // Force refresh profile and progress cache from Supabase
      await UserProfileCacheManager.getOrFetchCanonicalId();
      await UserProfileCacheManager.fetchUserProfile('me', forceRefresh: true);
      await UserProgressSyncService.syncFromSupabase();

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

  void _handlePasswordLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;

      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user != null) {
        // Save successful login to device secure storage
        await AuthMemoryService.saveSuccessfulLogin(
          method: LoginMethod.email,
          rememberMe: _rememberMe,
          email: email,
          refreshToken: response.session?.refreshToken,
        );
        _checkProfileAndNavigate(user.id);
      } else {
        throw Exception("Login failed. Please check credentials.");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'Authentication Failed ⚠️',
        e.toString().replaceAll('AuthException: ', ''),
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _showForgotPasswordBottomSheet() {
    Get.bottomSheet(
      const ForgotPasswordBottomSheet(),
      isScrollControlled: true,
    );
  }

  void _sendLoginOTP() async {
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
          titleStyle: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold),
          backgroundColor: context.secondaryBackgroundColor,
          contentPadding: EdgeInsets.all(20),
          content: Column(
            children: [
              Text(
                'No account found with this email.',
                style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () {
                  Get.back();
                  Get.to(() => SignupFlowScreen(startStep: 0, prefilledEmail: email));
                },
                child: Text('Create New Account', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        );
        return;
      }

      // 2. Send 6-digit OTP to Email
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
        emailRedirectTo: 'io.supabase.flutter://login-callback/',
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpSent = true;
      });

      Get.snackbar(
        'OTP Sent ✉️',
        'Please check your email for the login verification code.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.accentOrange.withOpacity(0.9),
        colorText: Colors.white,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      String errMsg = e.toString().replaceAll('AuthException: ', '');
      if (errMsg.toLowerCase().contains('rate limit') || errMsg.toLowerCase().contains('429')) {
        errMsg = "Email rate limit exceeded.\nPlease wait a few minutes before trying again.";
      }

      Get.snackbar(
        'Failed to Send OTP ⚠️',
        errMsg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  void _verifyLoginOTP() async {
    final otpCode = _otpCtrl.text.trim();
    if (otpCode.isEmpty) {
      Get.snackbar('Error', 'Please enter the verification code');
      return;
    }

    setState(() => _isLoading = true);
    final email = _emailCtrl.text.trim();
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.email,
        token: otpCode,
        email: email,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.user != null) {
        // Save successful OTP login to device secure storage
        await AuthMemoryService.saveSuccessfulLogin(
          method: LoginMethod.email,
          rememberMe: _rememberMe,
          email: email,
          refreshToken: response.session?.refreshToken,
        );
        _checkProfileAndNavigate(response.user!.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Get.snackbar(
        'Verification Failed ⚠️',
        e.toString().replaceAll('AuthException: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  void _handleSocialLogin(String provider) async {
    setState(() => _isLoading = true);
    try {
      final targetProvider =
          provider.toLowerCase() == 'facebook' ? OAuthProvider.facebook : OAuthProvider.google;
      final method = provider.toLowerCase() == 'google' ? LoginMethod.google : LoginMethod.facebook;

      final success = await Supabase.instance.client.auth.signInWithOAuth(
        targetProvider,
        redirectTo: 'io.supabase.flutter://login-callback/',
      );
      if (!success) {
        setState(() => _isLoading = false);
        Get.snackbar(
          'OAuth Error ⚠️',
          'Failed to open the browser for social authentication.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: context.errorColor.withOpacity(0.9),
          colorText: Colors.white,
        );
      } else {
        // Session will be captured by the authStateChange listener.
        // We store the login method for the next time the listener fires.
        // The actual save happens when the signedIn event is received.
        _pendingSocialMethod = method;
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'Social Login Failed ⚠️',
        ApiErrorHandler.parseError(e),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  LoginMethod? _pendingSocialMethod;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
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
                    child: _blob(220, Color(0xFF6366F1), 0.35),
                  ),
                  Positioned(
                    bottom: -100 + (t * 50),
                    right: -80 + (t * 30),
                    child: _blob(260, Color(0xFF8B5CF6), 0.25),
                  ),
                  Positioned(
                    top: size.height * 0.45 - (t * 40),
                    right: -40,
                    child: _blob(160, Color(0xFF10B981), 0.18),
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
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogo(),
                      SizedBox(height: 36),

                      _buildGlassCard(
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: _showEmailForm ? _buildEmailLoginForm() : _buildAuthSelector(),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome Back',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Create. Connect. Grow.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 20),

        // ── Last Login Card (hidden if no prior login) ─────────────────
        if (AuthMemoryService.hasLastLogin) ...[
          _buildLastLoginCard(),
          const SizedBox(height: 16),
        ],

        // ── Smart Google quick-login if last method was Google ─────────
        if (AuthMemoryService.lastMethod == LoginMethod.google) ...[
          _socialButton(
            label: 'Continue with Google',
            icon: _googleIcon(),
            onTap: () => _handleSocialLogin('Google'),
          ),
          const SizedBox(height: 10),
          _socialButton(
            label: 'Continue with Facebook',
            icon: _facebookIcon(),
            onTap: () => _handleSocialLogin('Facebook'),
          ),
        ] else if (AuthMemoryService.lastMethod == LoginMethod.facebook) ...[
          _socialButton(
            label: 'Continue with Facebook',
            icon: _facebookIcon(),
            onTap: () => _handleSocialLogin('Facebook'),
          ),
          const SizedBox(height: 10),
          _socialButton(
            label: 'Continue with Google',
            icon: _googleIcon(),
            onTap: () => _handleSocialLogin('Google'),
          ),
        ] else ...[
          _socialButton(
            label: 'Continue with Google',
            icon: _googleIcon(),
            onTap: () => _handleSocialLogin('Google'),
          ),
          SizedBox(height: 12),
          _socialButton(
            label: 'Continue with Facebook',
            icon: _facebookIcon(),
            onTap: () => _handleSocialLogin('Facebook'),
          ),
        ],
        SizedBox(height: 12),

        _socialButton(
          label: 'Continue with Email',
          icon: Icon(Icons.email_outlined, color: context.primaryColor, size: 22),
          onTap: () {
            setState(() {
              _showEmailForm = true;
            });
          },
        ),
        SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Don't have an account? ", style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13)),
            GestureDetector(
              onTap: () => Get.to(() => SignupFlowScreen(startStep: 0)),
              child: Text(
                'Sign Up',
                style: GoogleFonts.poppins(
                  color: context.primaryColor,
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

  // --- Last Login Card ---
  Widget _buildLastLoginCard() {
    final method = AuthMemoryService.lastMethod ?? LoginMethod.email;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.primaryColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.primaryColor.withOpacity(0.22),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 14, color: context.primaryColor),
              const SizedBox(width: 6),
              Text(
                'Last Login',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.primaryColor,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Method row
          Row(
            children: [
              Text(
                method.emoji,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 6),
              Text(
                method.displayLabel,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Account row
          Row(
            children: [
              Icon(Icons.alternate_email_rounded, size: 13, color: context.textSecondary),
              const SizedBox(width: 6),
              Text(
                AuthMemoryService.maskedEmail,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: context.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Time row
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 13, color: context.textSecondary),
              const SizedBox(width: 6),
              Text(
                AuthMemoryService.formattedLoginTime,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.4),
              ),
            ),
            child: Text(
              '✓  Last login successful',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
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
              Text(
                _otpSent
                    ? 'Enter OTP'
                    : (_usePasswordLogin ? 'Password Login' : 'Email OTP Login'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
                onPressed: () {
                  setState(() {
                    if (_otpSent) {
                      _otpSent = false;
                      _otpCtrl.clear();
                    } else {
                      _showEmailForm = false;
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (!_otpSent) ...[
            // Tab Toggle
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _usePasswordLogin = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _usePasswordLogin ? context.primaryColor : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Password',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: _usePasswordLogin ? FontWeight.bold : FontWeight.normal,
                          color: _usePasswordLogin ? context.textPrimary : context.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _usePasswordLogin = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: !_usePasswordLogin ? context.primaryColor : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Email OTP',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: !_usePasswordLogin ? FontWeight.bold : FontWeight.normal,
                          color: !_usePasswordLogin ? context.textPrimary : context.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          _buildLabel('Email Address'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _emailCtrl,
            hint: 'name@domain.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            enabled: !_otpSent,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),

          if (_otpSent) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLabel('OTP Code'),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _otpSent = false;
                      _otpCtrl.clear();
                    });
                  },
                  child: Text(
                    'Change Email',
                    style: GoogleFonts.poppins(
                      color: context.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 18),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: '••••••',
                counterText: '',
              ),
            ),
            const SizedBox(height: 24),
            _buildPrimaryButton(
              label: 'Verify OTP & Login',
              isLoading: _isLoading,
              onTap: _verifyLoginOTP,
            ),
          ] else ...[
            if (_usePasswordLogin) ...[
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
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordBottomSheet,
                  child: Text(
                    'Forgot Password?',
                    style: GoogleFonts.poppins(
                      color: context.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ── Remember Me checkbox ─────────────────────────────
              GestureDetector(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _rememberMe ? context.primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: _rememberMe ? context.primaryColor : context.textSecondary,
                          width: 1.5,
                        ),
                      ),
                      child: _rememberMe
                          ? const Icon(Icons.check, color: Colors.white, size: 13)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Remember Me',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: context.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildPrimaryButton(
                label: 'Login with Password',
                isLoading: _isLoading,
                onTap: _handlePasswordLogin,
              ),
            ] else ...[
              // ── Remember Me checkbox (OTP flow) ─────────────────────
              GestureDetector(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _rememberMe ? context.primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: _rememberMe ? context.primaryColor : context.textSecondary,
                          width: 1.5,
                        ),
                      ),
                      child: _rememberMe
                          ? const Icon(Icons.check, color: Colors.white, size: 13)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Remember Me',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: context.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildPrimaryButton(
                label: 'Send 6-digit OTP',
                isLoading: _isLoading,
                onTap: _sendLoginOTP,
              ),
            ],
          ],
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
        child: SizedBox(),
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
            gradient: LinearGradient(
              colors: [context.primaryColor, AppTheme.secondaryColor],
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
        SizedBox(height: 12),
        Text(
          'Creaniaa',
          style: GoogleFonts.plusJakartaSans(color: context.textPrimary, fontSize: 26, fontWeight: FontWeight.w900),
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
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: context.borderColor, width: 1),
            boxShadow: context.smallShadow,
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
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
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !isPasswordVisible,
      keyboardType: keyboardType,
      validator: validator,
      enabled: enabled,
      style: TextStyle(color: context.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.caption, fontSize: 14),
        prefixIcon: Icon(icon, color: context.caption, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: context.caption,
                  size: 20,
                ),
                onPressed: onTogglePassword,
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: BorderSide(color: context.primaryColor, width: 1.5),
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
          side: BorderSide(color: context.borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: context.secondaryBackgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
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
          backgroundColor: context.primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _googleIcon() {
    return SvgPicture.string(
      '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="22" height="22">
        <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
        <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
        <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l3.66-2.85z"/>
        <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.85c.87-2.6 3.3-4.53 6.16-4.53z"/>
      </svg>''',
      width: 22,
      height: 22,
    );
  }

  Widget _facebookIcon() {
    return SvgPicture.string(
      '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="22" height="22">
        <path fill="#1877F2" d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
      </svg>''',
      width: 22,
      height: 22,
    );
  }
}

class ForgotPasswordBottomSheet extends StatefulWidget {
  const ForgotPasswordBottomSheet({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordBottomSheet> createState() => _ForgotPasswordBottomSheetState();
}

class _ForgotPasswordBottomSheetState extends State<ForgotPasswordBottomSheet> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _otpSent = false;
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _sendRecoveryOTP() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      Get.snackbar('Error', 'Please enter a valid email address');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
      );
      setState(() {
        _isLoading = false;
        _otpSent = true;
      });
      Get.snackbar(
        'OTP Sent ✉️',
        'Verification code has been sent to your email.',
        backgroundColor: Colors.orange.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'Error ⚠️',
        e.toString().replaceAll('AuthException: ', ''),
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final otpCode = _otpCtrl.text.trim();
    final newPassword = _passCtrl.text;
    final confirmPassword = _confirmPassCtrl.text;

    if (otpCode.isEmpty || otpCode.length < 6) {
      Get.snackbar('Error', 'Please enter the 6-digit verification code');
      return;
    }

    if (newPassword != confirmPassword) {
      Get.snackbar('Error', 'Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.recovery,
        token: otpCode,
        email: email,
      );

      if (response.user != null) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );

        setState(() => _isLoading = false);
        Get.back();
        Get.snackbar(
          'Password Changed 🎉',
          'Your password has been successfully updated. Logging you in...',
          backgroundColor: Colors.green.withOpacity(0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        throw Exception("Verification failed");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'Reset Failed ⚠️',
        e.toString().replaceAll('AuthException: ', ''),
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: context.secondaryBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: context.borderColor),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _otpSent ? 'Reset Password' : 'Forgot Password',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: context.textPrimary),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_otpSent) ...[
                Text(
                  'Enter your email address associated with your account, and we will send you a 6-digit recovery code to reset your password.',
                  style: GoogleFonts.poppins(
                    color: context.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Email Address',
                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'name@domain.com',
                    prefixIcon: Icon(Icons.alternate_email_rounded, color: context.caption),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendRecoveryOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Send Code',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ] else ...[
                Text(
                  'Enter the 6-digit reset code sent to your email along with your new password.',
                  style: GoogleFonts.poppins(
                    color: context.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '6-digit Reset Code',
                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textPrimary, letterSpacing: 8, fontSize: 18),
                  decoration: const InputDecoration(
                    hintText: '••••••',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'New Password',
                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: context.caption),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: context.caption,
                      ),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'New password is required';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Confirm New Password',
                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPassCtrl,
                  obscureText: _obscureConfirmPass,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: context.caption),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: context.caption,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm password is required';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Reset & Login',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
