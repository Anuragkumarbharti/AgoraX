import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../services/user_profile_cache_manager.dart';
import '../../services/user_progress_sync_service.dart';
import '../home/main_screen.dart';
import 'login_screen.dart';
import '../../services/email_validation_service.dart';

class SignupFlowScreen extends StatefulWidget {
  final String? userId; // If authenticated via Google/Apple, pass the user ID
  final int startStep; // Start step (0 for normal email signup, 1 for step 2)
  final String? prefilledEmail;
  final String? prefilledProvider;
  const SignupFlowScreen({
    Key? key,
    this.userId,
    this.startStep = 0,
    this.prefilledEmail,
    this.prefilledProvider,
  }) : super(key: key);

  @override
  State<SignupFlowScreen> createState() => _SignupFlowScreenState();
}

class _SignupFlowScreenState extends State<SignupFlowScreen> {
  late int _currentStep;
  bool _isLoading = false;
  late String _userId;

  // Step 1 Controllers
  final _emailPhoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _otpSent = false;
  bool _isPhoneAuth = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Step 2 Controllers
  final _usernameCtrl = TextEditingController();
  bool _usernameChecked = false;
  bool _usernameAvailable = false;
  List<String> _usernameSuggestions = [];
  String? _usernameError;

  // Step 3 Controllers
  final _displayNameCtrl = TextEditingController();
  DateTime? _dob;
  int _calculatedAge = 0;
  String? _selectedCountry = 'India';
  String? _selectedGender;

  // Step 4 Controllers
  File? _avatarFile;

  // Step 5 Controllers
  final _bioCtrl = TextEditingController();
  final List<String> _bioExamples = [
    'Learning every day 🚀',
    'Developer | Student',
    'Music & Technology',
    'Dream. Build. Inspire.',
  ];

  // Step 6 Controllers
  final List<String> _allInterests = [
    'Knowledge', 'Technology', 'Programming', 'AI', 'Cybersecurity',
    'Business', 'Education', 'Gaming', 'Music', 'Movies', 'Sports',
    'Anime', 'Photography', 'Travel', 'Fashion', 'Science', 'Finance',
    'Startups', 'Books', 'Comedy', 'Art', 'Voice Rooms', 'Communities', 'Events'
  ];
  final Set<String> _selectedInterests = {};

  // Step 7 Controllers
  Map<String, PermissionStatus> _permissionStatuses = {};

  @override
  void initState() {
    super.initState();
    _currentStep = widget.startStep;
    _userId = widget.userId ?? '';
    if (widget.prefilledEmail != null) {
      _emailPhoneCtrl.text = widget.prefilledEmail!;
      _isPhoneAuth = false;
      if (widget.prefilledProvider != null) {
        _passwordCtrl.text = 'SocialPassword123!';
        _confirmPasswordCtrl.text = 'SocialPassword123!';
      }
    }
  }

  @override
  void dispose() {
    _emailPhoneCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  bool _isPasswordStrong(String pass) {
    if (pass.length < 8) return false;
    final hasUppercase = pass.contains(RegExp(r'[A-Z]'));
    final hasLowercase = pass.contains(RegExp(r'[a-z]'));
    final hasDigits = pass.contains(RegExp(r'[0-9]'));
    final hasSpecialCharacters = pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return hasUppercase && hasLowercase && hasDigits && hasSpecialCharacters;
  }

  // --- Step 1: Verify Email/Phone (OTP) ---
  void _sendOTP() async {
    final value = _emailPhoneCtrl.text.trim();
    if (value.isEmpty) {
      Get.snackbar('Required', 'Please enter Email or Phone Number');
      return;
    }

    final password = _passwordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (password.isEmpty) {
      Get.snackbar('Required', 'Please enter a password');
      return;
    }

    if (password != confirmPassword) {
      Get.snackbar('Validation Error', 'Passwords do not match');
      return;
    }

    if (!_isPasswordStrong(password)) {
      Get.snackbar(
        'Weak Password ⚠️',
        'Password must be at least 8 characters long, and contain uppercase, lowercase, a number, and a special character.',
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final validator = EmailValidationService();

    // Check Cooldown
    if (await validator.isCoolingDown()) {
      Get.snackbar(
        'Too many attempts ⚠️',
        'Too many failures. Please wait before trying again.',
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!_isPhoneAuth) {
      // 1. Format validation
      if (!validator.isValidFormat(value)) {
        await validator.logFailure();
        Get.snackbar(
          'Invalid Email ⚠️',
          'Please enter a valid email address format.',
          backgroundColor: AppTheme.errorColor.withOpacity(0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // 2. Disposable Email Check
      if (await validator.isDisposable(value)) {
        await validator.logFailure();
        Get.snackbar(
          'Disposable Email Blocked 🚫',
          'This temporary email address is not allowed. Please use your real email.',
          backgroundColor: AppTheme.errorColor.withOpacity(0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      // 3. Deliverability / MX Check
      setState(() => _isLoading = true);
      final deliverable = await validator.isDeliverable(value);
      if (!deliverable) {
        setState(() => _isLoading = false);
        await validator.logFailure();
        Get.snackbar(
          'Undeliverable Domain ⚠️',
          'This email domain is undeliverable. Please check spelling or use a different email.',
          backgroundColor: AppTheme.errorColor.withOpacity(0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // 4. Optional Role-based check
      if (validator.isRoleBased(value)) {
        setState(() => _isLoading = false);
        Get.snackbar(
          'Business Email Blocked ⚠️',
          'Role-based/business administrative emails are not permitted.',
          backgroundColor: AppTheme.errorColor.withOpacity(0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
    }

    // 5. Rate limiting / Abuse prevention for OTP Requests
    if (await validator.checkOtpLimitExceeded(value)) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'Rate Limit Exceeded ⚠️',
        'Too many OTP requests. Please wait before trying again.',
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // 6. Rate limiting / Abuse prevention for signup attempts per device
    if (await validator.checkSignupLimitExceeded()) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'Device Limit Reached ⚠️',
        'Too many registration attempts from this device. Please try again later.',
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final column = _isPhoneAuth ? 'phone' : 'email';
      final existing = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq(column, value)
          .maybeSingle();

      if (existing != null) {
        setState(() => _isLoading = false);
        Get.snackbar(
          'Account Exists ⚠️',
          _isPhoneAuth
              ? 'This phone number already has an account. Please sign in.'
              : 'This email already has an account. Please sign in.',
          backgroundColor: AppTheme.errorColor.withOpacity(0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        Future.delayed(const Duration(seconds: 2), () {
          Get.offAll(() => const LoginScreen());
        });
        return;
      }
    } catch (_) {}

    await Future.delayed(const Duration(seconds: 1)); // Simulate networking
    setState(() {
      _isLoading = false;
      _otpSent = true;
    });

    Get.snackbar(
      'OTP Sent ✉️',
      'Use code 0 to verify (Sandbox mode)',
      backgroundColor: AppTheme.accentColor.withOpacity(0.9),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _verifyOTP() async {
    if (_otpCtrl.text.trim() != '0') {
      Get.snackbar('Error', 'Invalid verification code');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final rawVal = _emailPhoneCtrl.text.trim();
      final mockEmail = _isPhoneAuth 
          ? '${rawVal.replaceAll('+', '')}@creania.com' 
          : rawVal;
      
      AuthResponse response;
      try {
        response = await Supabase.instance.client.auth.signUp(
          email: mockEmail,
          password: _passwordCtrl.text,
        );
      } catch (_) {
        response = await Supabase.instance.client.auth.signInWithPassword(
          email: mockEmail,
          password: _passwordCtrl.text,
        );
      }

      final user = response.user;
      if (user != null) {
        setState(() {
          _userId = user.id;
          _isLoading = false;
          _currentStep = 1; // Move to Step 2
        });
      } else {
        throw Exception("Authentication session creation failed");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Auth Error', e.toString().replaceAll('AuthException: ', ''));
    }
  }

  // --- Step 2: Choose Username ---
  void _checkUsername(String val) async {
    final cleanVal = val.trim().toLowerCase();
    if (cleanVal.length < 3 || cleanVal.length > 20) {
      setState(() {
        _usernameError = 'Length must be between 3 and 20 characters';
        _usernameChecked = false;
      });
      return;
    }

    final validCharacters = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!validCharacters.hasMatch(cleanVal)) {
      setState(() {
        _usernameError = 'Only letters, numbers, and underscores allowed';
        _usernameChecked = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _usernameError = null;
    });

    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('username', cleanVal)
          .maybeSingle();

      if (res != null) {
        // Taken
        setState(() {
          _usernameChecked = true;
          _usernameAvailable = false;
          _usernameSuggestions = [
            '${cleanVal}_123',
            '${cleanVal}_creania',
            '${cleanVal}_99',
          ];
          _isLoading = false;
        });
      } else {
        // Available
        setState(() {
          _usernameChecked = true;
          _usernameAvailable = true;
          _usernameSuggestions = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // --- Step 3: Basic Information ---
  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.bgLight,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dob = picked;
        // Age calculation
        final today = DateTime.now();
        int age = today.year - picked.year;
        if (today.month < picked.month || (today.month == picked.month && today.day < picked.day)) {
          age--;
        }
        _calculatedAge = age;
      });
    }
  }

  // --- Step 4: Profile Photo ---
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _avatarFile = File(pickedFile.path);
      });
    }
  }

  // --- Step 7: Permissions ---
  Future<void> _requestPermissions() async {
    final mic = await Permission.microphone.request();
    final cam = await Permission.camera.request();
    final notification = await Permission.notification.request();
    final contacts = await Permission.contacts.request();
    final storage = await Permission.storage.request();

    setState(() {
      _permissionStatuses = {
        'Microphone': mic,
        'Camera': cam,
        'Notifications': notification,
        'Contacts': contacts,
        'Storage': storage,
      };
    });

    _nextStep();
  }

  // --- Step 8: Save & Finish ---
  void _completeOnboardingFlow() async {
    setState(() => _isLoading = true);
    try {
      final currentAuthUser = Supabase.instance.client.auth.currentUser;
      final rawUserId = _userId.isEmpty ? (currentAuthUser?.id ?? 'temp_uid') : _userId;

      String userIdToUse = rawUserId;

      // 1. Upload photo if selected
      String? uploadedUrl;
      if (_avatarFile != null) {
        try {
          final path = '$userIdToUse/avatar.png';
          await Supabase.instance.client.storage
              .from('avatars')
              .upload(
                path,
                _avatarFile!,
                fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
              );
          uploadedUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(path);
        } catch (storageError) {
          debugPrint('Storage Upload Warning: $storageError');
          // Fallback to default dicebear avatar on RLS / storage exception
          uploadedUrl = 'https://api.dicebear.com/7.x/bottts/png?seed=${_usernameCtrl.text.trim()}';
        }
      }

      // 2. Update Database Record
      await Supabase.instance.client.from('profiles').upsert({
        'id': userIdToUse,
        'username': _usernameCtrl.text.trim().toLowerCase(),
        'display_name': _displayNameCtrl.text.trim(),
        'full_name': _displayNameCtrl.text.trim(),
        'avatar_url': uploadedUrl ?? 'https://api.dicebear.com/7.x/bottts/png?seed=${_usernameCtrl.text.trim()}',
        'profile_photo': uploadedUrl ?? 'https://api.dicebear.com/7.x/bottts/png?seed=${_usernameCtrl.text.trim()}',
        'bio': _bioCtrl.text.trim().isNotEmpty ? _bioCtrl.text.trim() : 'Learning every day 🚀',
        'dob': _dob?.toIso8601String(),
        'age': _calculatedAge,
        'gender': _selectedGender,
        'country': _selectedCountry,
        'interests': _selectedInterests.toList(),
        'verified': false,
        'badges': ['Early Explorer'],
        'avatar_frame': 'Early Explorer Frame',
        'email_verified': !_isPhoneAuth,
        'verification_timestamp': DateTime.now().toIso8601String(),
        'verification_method': _isPhoneAuth ? 'SMS' : 'OTP',
        'last_verification_date': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 3. Grant Reward Coins (100 coins)
      try {
        final walletRes = await Supabase.instance.client
            .from('wallets')
            .select('coins_balance')
            .eq('id', userIdToUse)
            .maybeSingle();
        final currentCoins = walletRes?['coins_balance'] ?? 0;
        await Supabase.instance.client.from('wallets').upsert({
          'id': userIdToUse,
          'coins_balance': currentCoins + 100,
          'inr_balance': 0.00,
          'withdrawable_balance': 0.00,
        });
      } catch (_) {}

      // Invalidate profile cache & sync from DB
      UserProfileCacheManager.invalidateCache(userIdToUse);
      await UserProfileCacheManager.getOrFetchCanonicalId();
      await UserProgressSyncService.syncFromSupabase();

      setState(() => _isLoading = false);
      Get.offAll(() => const MainScreen());
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Error saving profile', e.toString());
    }
  }

  void _nextStep() {
    if (_currentStep < 7) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          // Background blobs
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.12),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: const SizedBox(),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryColor.withOpacity(0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: const SizedBox(),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top header with step bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep < 7)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                          onPressed: () {
                            if (_currentStep > 0) {
                              _prevStep();
                            } else {
                              Get.back();
                            }
                          },
                        )
                      else
                        const SizedBox(width: 40),
                      Text(
                        'Step ${_currentStep + 1} of 8',
                        style: GoogleFonts.poppins(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_currentStep > 0 && _currentStep < 7 && (_currentStep == 3 || _currentStep == 4))
                        TextButton(
                          onPressed: _nextStep,
                          child: Text(
                            'Skip',
                            style: GoogleFonts.poppins(
                              color: AppTheme.primaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 40),
                    ],
                  ),
                ),

                // Indicator line
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: (size.width - 48) * ((_currentStep + 1) / 8),
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: _buildStepContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Verify();
      case 1:
        return _buildStep2Username();
      case 2:
        return _buildStep3BasicInfo();
      case 3:
        return _buildStep4Photo();
      case 4:
        return _buildStep5Bio();
      case 5:
        return _buildStep6Interests();
      case 6:
        return _buildStep7Permissions();
      case 7:
        return _buildStep8Congrats();
      default:
        return const SizedBox();
    }
  }

  // --- Step 1 Layout ---
  Widget _buildStep1Verify() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Verify Account', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Enter email or phone to receive a verification OTP code.', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 32),

        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Email'),
                selected: !_isPhoneAuth,
                onSelected: (val) {
                  setState(() {
                    _isPhoneAuth = false;
                    _emailPhoneCtrl.clear();
                  });
                },
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                labelStyle: TextStyle(color: !_isPhoneAuth ? Colors.white : AppTheme.textTertiary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Text('Phone'),
                selected: _isPhoneAuth,
                onSelected: (val) {
                  setState(() {
                    _isPhoneAuth = true;
                    _emailPhoneCtrl.clear();
                  });
                },
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                labelStyle: TextStyle(color: _isPhoneAuth ? Colors.white : AppTheme.textTertiary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Text(_isPhoneAuth ? 'Phone Number' : 'Email Address', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailPhoneCtrl,
          keyboardType: _isPhoneAuth ? TextInputType.phone : TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: _isPhoneAuth ? '+91 98765 43210' : 'name@domain.com',
            prefixIcon: Icon(_isPhoneAuth ? Icons.phone_android_rounded : Icons.email_outlined, color: AppTheme.textTertiary),
          ),
          enabled: !_otpSent,
        ),
        Text('Password', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textTertiary),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppTheme.textTertiary),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          enabled: !_otpSent,
        ),
        const SizedBox(height: 20),

        Text('Confirm Password', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmPasswordCtrl,
          obscureText: _obscureConfirmPassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textTertiary),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppTheme.textTertiary),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          enabled: !_otpSent,
        ),
        const SizedBox(height: 24),

        if (_otpSent) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('OTP Code', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              TextButton(
                onPressed: () {
                  setState(() {
                    _otpSent = false;
                    _otpCtrl.clear();
                  });
                },
                child: Text(
                  'Change ${_isPhoneAuth ? 'Phone' : 'Email'}',
                  style: GoogleFonts.poppins(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
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
          const SizedBox(height: 32),
          _buildActionButton('Verify OTP', _verifyOTP),
        ] else ...[
          _buildActionButton('Send Verification Code', _sendOTP),
        ],
      ],
    );
  }

  // --- Step 2 Layout ---
  Widget _buildStep2Username() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose Username', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Create a unique handle for your Creania profile.', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 32),

        Text('Username', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: _usernameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixText: '@ ',
            prefixStyle: const TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold, fontSize: 16),
            suffixIcon: _isLoading 
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : _usernameChecked 
                    ? Icon(_usernameAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded, 
                           color: _usernameAvailable ? AppTheme.successColor : AppTheme.errorColor)
                    : null,
          ),
          onChanged: (val) {
            setState(() {
              _usernameChecked = false;
              _usernameAvailable = false;
            });
            _checkUsername(val);
          },
        ),
        if (_usernameError != null) ...[
          const SizedBox(height: 8),
          Text(_usernameError!, style: TextStyle(color: AppTheme.errorColor, fontSize: 12)),
        ],
        if (_usernameChecked && !_usernameAvailable) ...[
          const SizedBox(height: 16),
          Text('Username is taken. Try suggestions:', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textTertiary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _usernameSuggestions.map((sug) => ActionChip(
              label: Text('@$sug'),
              backgroundColor: AppTheme.bgLight,
              onPressed: () {
                _usernameCtrl.text = sug;
                _checkUsername(sug);
              },
            )).toList(),
          ),
        ],

        const SizedBox(height: 40),
        _buildActionButton('Continue', () async {
          final username = _usernameCtrl.text.trim().toLowerCase();
          if (username.isEmpty) {
            Get.snackbar('Error', 'Username cannot be empty');
            return;
          }
          if (username.length < 3 || username.length > 20) {
            Get.snackbar('Error', 'Length must be between 3 and 20 characters');
            return;
          }
          final validCharacters = RegExp(r'^[a-zA-Z0-9_]+$');
          if (!validCharacters.hasMatch(username)) {
            Get.snackbar('Error', 'Only letters, numbers, and underscores allowed');
            return;
          }

          setState(() => _isLoading = true);
          try {
            final res = await Supabase.instance.client
                .from('profiles')
                .select('id')
                .eq('username', username)
                .maybeSingle();

            final currentAuthUser = Supabase.instance.client.auth.currentUser;
            final rawUserId = _userId.isEmpty ? (currentAuthUser?.id ?? 'temp_uid') : _userId;
            
            String userIdToUse = rawUserId;
            try {
              final mappingRes = await Supabase.instance.client
                  .from('user_auth_mappings')
                  .select('canonical_id')
                  .eq('auth_id', rawUserId)
                  .maybeSingle();
              if (mappingRes != null && mappingRes['canonical_id'] != null) {
                userIdToUse = mappingRes['canonical_id'] as String;
              }
            } catch (_) {}

            if (res != null && res['id'] != userIdToUse) {
              setState(() {
                _usernameAvailable = false;
                _usernameChecked = true;
                _isLoading = false;
                _usernameSuggestions = [
                  '${username}_123',
                  '${username}_creania',
                  '${username}_99',
                ];
              });
              Get.snackbar('Error', 'Please choose an available username');
            } else {
              setState(() {
                _usernameAvailable = true;
                _usernameChecked = true;
                _isLoading = false;
              });
              _nextStep();
            }
          } catch (e) {
            setState(() => _isLoading = false);
            _nextStep();
          }
        }),
      ],
    );
  }

  // --- Step 3 Layout ---
  Widget _buildStep3BasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Basic Information', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Tell us a bit about yourself. Only display name is visible to others.', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 32),

        Text('Display Name *', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: _displayNameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'John Doe'),
        ),
        const SizedBox(height: 20),

        Text('Date of Birth *', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dob == null ? 'Select Birthday' : DateFormat('dd MMM yyyy').format(_dob!),
                  style: TextStyle(color: _dob == null ? AppTheme.textTertiary : Colors.white),
                ),
                const Icon(Icons.calendar_month_rounded, color: AppTheme.textTertiary),
              ],
            ),
          ),
        ),
        if (_dob != null) ...[
          const SizedBox(height: 8),
          Text('Calculated Age: $_calculatedAge years old', 
               style: TextStyle(color: _calculatedAge >= 13 ? AppTheme.successColor : AppTheme.errorColor, fontSize: 12)),
        ],
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Country', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCountry,
                        dropdownColor: AppTheme.bgLight,
                        style: const TextStyle(color: Colors.white),
                        isExpanded: true,
                        items: ['India', 'United States', 'United Kingdom', 'Canada', 'Australia']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedCountry = val),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gender (Optional)', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGender,
                        hint: const Text('Select', style: TextStyle(color: AppTheme.textTertiary)),
                        dropdownColor: AppTheme.bgLight,
                        style: const TextStyle(color: Colors.white),
                        isExpanded: true,
                        items: ['Male', 'Female', 'Non-Binary', 'Prefer not to say']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedGender = val),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 40),
        _buildActionButton('Continue', () {
          if (_displayNameCtrl.text.trim().isEmpty) {
            Get.snackbar('Error', 'Display Name is required');
            return;
          }
          if (_dob == null) {
            Get.snackbar('Error', 'Date of Birth is required');
            return;
          }
          if (_calculatedAge < 13) {
            Get.snackbar('Error', 'You must be at least 13 years old to use Creania');
            return;
          }
          _nextStep();
        }),
      ],
    );
  }

  // --- Step 4 Layout ---
  Widget _buildStep4Photo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Profile Photo', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Add a profile picture so friends can recognize you.', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 14)),
        ),
        const SizedBox(height: 48),

        Center(
          child: Stack(
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryColor, width: 3),
                  color: AppTheme.bgLight,
                  image: _avatarFile != null 
                      ? DecorationImage(image: FileImage(_avatarFile!), fit: BoxFit.cover)
                      : null,
                ),
                child: _avatarFile == null 
                    ? const Icon(Icons.person_rounded, size: 70, color: AppTheme.textTertiary)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    Get.bottomSheet(
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: AppTheme.bgLight,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Wrap(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                              title: const Text('Camera', style: TextStyle(color: Colors.white)),
                              onTap: () {
                                Get.back();
                                _pickImage(ImageSource.camera);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library_rounded, color: Colors.white),
                              title: const Text('Gallery', style: TextStyle(color: Colors.white)),
                              onTap: () {
                                Get.back();
                                _pickImage(ImageSource.gallery);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 54),

        _buildActionButton('Continue', _nextStep),
      ],
    );
  }

  // --- Step 5 Layout ---
  Widget _buildStep5Bio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About You', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Write a short bio to introduce yourself (max 150 chars).', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 32),

        Text('Bio', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: _bioCtrl,
          maxLines: 4,
          maxLength: 150,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Share a little about yourself...',
          ),
        ),
        const SizedBox(height: 16),

        Text('Suggestions:', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textTertiary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _bioExamples.map((ex) => ActionChip(
            label: Text(ex),
            backgroundColor: AppTheme.bgLight,
            onPressed: () {
              _bioCtrl.text = ex;
            },
          )).toList(),
        ),

        const SizedBox(height: 40),
        _buildActionButton('Continue', _nextStep),
      ],
    );
  }

  // --- Step 6 Layout ---
  Widget _buildStep6Interests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose Interests', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Select at least 5 interests to customize your recommendations.', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 24),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allInterests.map((interest) {
            final isSelected = _selectedInterests.contains(interest);
            return FilterChip(
              label: Text(interest),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedInterests.add(interest);
                  } else {
                    _selectedInterests.remove(interest);
                  }
                });
              },
              selectedColor: AppTheme.primaryColor.withOpacity(0.3),
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: AppTheme.bgLight,
              side: BorderSide(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text('Selected: ${_selectedInterests.length} of 5 minimum', 
             style: TextStyle(color: _selectedInterests.length >= 5 ? AppTheme.successColor : AppTheme.errorColor, fontSize: 12)),

        const SizedBox(height: 42),
        _buildActionButton('Continue', () {
          if (_selectedInterests.length < 5) {
            Get.snackbar('Required', 'Please select at least 5 interests.');
            return;
          }
          _nextStep();
        }),
      ],
    );
  }

  // --- Step 7 Layout ---
  Widget _buildStep7Permissions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Device Permissions', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Grant permissions for a complete Creania experience.', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 32),

        _permissionItemTile('Microphone', 'Speak in voice rooms and audio circles.', Icons.mic_rounded),
        _permissionItemTile('Camera', 'Take profile picture and stream video.', Icons.camera_alt_rounded),
        _permissionItemTile('Notifications', 'Get notified about direct chats and event start times.', Icons.notifications_rounded),
        _permissionItemTile('Contacts (Optional)', 'Find your friends already on Creania.', Icons.contacts_rounded),
        _permissionItemTile('Storage (Optional)', 'Select files and graphics.', Icons.photo_library_rounded),

        const SizedBox(height: 48),
        _buildActionButton('Enable Permissions', _requestPermissions),
      ],
    );
  }

  Widget _permissionItemTile(String title, String desc, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(desc, style: GoogleFonts.poppins(color: AppTheme.textTertiary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 8 Layout ---
  Widget _buildStep8Congrats() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          // Creania Logo
          Image.asset(
            'assets/images/logo.png',
            width: 100,
            height: 100,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 32),

          Text('Congratulations! 🎉', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Text('Welcome to Creania! Your profile is ready.', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 15), textAlign: TextAlign.center),
          const SizedBox(height: 40),

          // Rewards Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Early Explorer Rewards Unlocked:', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentColor)),
                const SizedBox(height: 16),
                _rewardRow('🎖️', 'Early Explorer Badge', 'Exclusive profile recognition'),
                const SizedBox(height: 12),
                _rewardRow('🪙', '100 Gold Coins', 'Credited directly to your wallet'),
                const SizedBox(height: 12),
                _rewardRow('✨', '7-Day Avatar Frame', 'Equipped automatically'),
                const SizedBox(height: 12),
                _rewardRow('📈', 'Boosted Visibility', 'Higher ranking in recommendations'),
              ],
            ),
          ),

          const SizedBox(height: 48),
          _buildActionButton('Enter Creania', _completeOnboardingFlow),
        ],
      ),
    );
  }

  Widget _rewardRow(String icon, String title, String desc) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            Text(desc, style: GoogleFonts.poppins(color: AppTheme.textTertiary, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: AppTheme.primaryColor,
        ),
        child: _isLoading 
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}
