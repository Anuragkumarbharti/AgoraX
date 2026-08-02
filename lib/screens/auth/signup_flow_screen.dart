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
import 'package:creania/core/theme.dart';
import 'terms_screen.dart';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/user_model.dart';
import '../../services/user_profile_cache_manager.dart';
import '../../services/user_progress_sync_service.dart';
import '../home/main_screen.dart';
import 'login_screen.dart';
import '../../services/email_validation_service.dart';
import '../../core/api_error_handler.dart';
import '../../widgets/custom_image_editor.dart';

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
  bool _agreeToTerms = false;
  bool _showEmailForm = false;
  StreamSubscription<AuthState>? _authSubscription;

  // Step 2 Controllers
  final _usernameCtrl = TextEditingController();
  bool _usernameChecked = false;
  bool _usernameAvailable = false;
  List<String> _usernameSuggestions = [];
  String? _usernameError;

  // Step 3 Controllers
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
    if (_userId.isNotEmpty) {
      _loadExistingProfileData();
    }
    if (widget.prefilledEmail != null) {
      _emailPhoneCtrl.text = widget.prefilledEmail!;
      _isPhoneAuth = false;
      if (widget.prefilledProvider != null) {
        _passwordCtrl.text = 'SocialPassword123!';
        _confirmPasswordCtrl.text = 'SocialPassword123!';
      }
    }

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      if (event == AuthChangeEvent.signedIn && session != null) {
        try {
          await Supabase.instance.client
              .from('profiles')
              .update({'signup_status': 'otp_verified'})
              .eq('id', session.user.id);
        } catch (_) {}

        setState(() {
          _userId = session.user.id;
          _currentStep = 1; // Move to Step 2 (Choose Username)
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailPhoneCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _usernameCtrl.dispose();
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

  bool _isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    final regExp = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return regExp.hasMatch(id);
  }

  String _mapAuthError(dynamic e) {
    final errString = e.toString().toLowerCase();
    final cleanMsg = e.toString().replaceAll('AuthException: ', '');
    
    if (errString.contains('authretryablefetchexception') ||
        errString.contains('500') ||
        errString.contains('504') ||
        errString.contains('timeout')) {
      return 'Unable to create account. Please try again in a moment.\nDetails: $cleanMsg';
    }
    
    if (errString.contains('smtp') || 
        errString.contains('email provider') || 
        errString.contains('failed to send email') ||
        errString.contains('confirmation email')) {
      return 'Unable to send verification email. Please try again later.\nDetails: $cleanMsg';
    }

    if (errString.contains('database') || 
        errString.contains('postgres') || 
        errString.contains('uuid') || 
        errString.contains('profiles') || 
        errString.contains('22p02')) {
      return 'Profile setup failed.\nDetails: $cleanMsg';
    }

    return 'Unable to create account.\nDetails: $cleanMsg';
  }

  Future<AuthResponse> _signUpWithRetry({required String email, required String password}) async {
    try {
      return await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'io.supabase.flutter://login-callback/',
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('timeout') || errStr.contains('authretryablefetchexception') || errStr.contains('504')) {
        await Future.delayed(const Duration(seconds: 1));
        return await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: 'io.supabase.flutter://login-callback/',
        ).timeout(const Duration(seconds: 15));
      }
      rethrow;
    }
  }

  Future<void> _resendWithRetry({required String email, required OtpType type}) async {
    try {
      await Supabase.instance.client.auth.resend(
        type: type,
        email: email,
        emailRedirectTo: 'io.supabase.flutter://login-callback/',
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('timeout') || errStr.contains('authretryablefetchexception') || errStr.contains('504')) {
        await Future.delayed(const Duration(seconds: 1));
        await Supabase.instance.client.auth.resend(
          type: type,
          email: email,
          emailRedirectTo: 'io.supabase.flutter://login-callback/',
        ).timeout(const Duration(seconds: 15));
        return;
      }
      rethrow;
    }
  }

  void _loadExistingProfileData() async {
    if (!_isValidUuid(_userId)) return;
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('username, dob, age, gender, country, bio, interests')
          .eq('id', _userId)
          .maybeSingle();

      if (res != null) {
        setState(() {
          if (res['username'] != null && !res['username'].toString().startsWith('user_')) {
            _usernameCtrl.text = res['username'].toString();
          }
          if (res['dob'] != null) {
            _dob = DateTime.tryParse(res['dob'].toString());
          }
          _calculatedAge = res['age'] ?? 0;
          if (res['gender'] != null) {
            _selectedGender = res['gender'].toString();
          }
          if (res['country'] != null) {
            _selectedCountry = res['country'].toString();
          }
          if (res['bio'] != null) {
            _bioCtrl.text = res['bio'].toString();
          }
          if (res['interests'] != null) {
            final list = List<String>.from(res['interests']);
            _selectedInterests.addAll(list);
          }
        });
      }
    } catch (_) {}
  }

  // --- Step 1: Verify Email/Phone (OTP) ---
  void _sendOTP() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final value = _emailPhoneCtrl.text.trim();
    if (value.isEmpty) {
      setState(() => _isLoading = false);
      Get.snackbar('Required', 'Please enter Email or Phone Number');
      return;
    }

    final password = _passwordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (password.isEmpty) {
      setState(() => _isLoading = false);
      Get.snackbar('Required', 'Please enter a password');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _isLoading = false);
      Get.snackbar('Validation Error', 'Passwords do not match');
      return;
    }

    if (!_isPasswordStrong(password)) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'Weak Password ⚠️',
        'Password must be at least 8 characters long, and contain uppercase, lowercase, a number, and a special character.',
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final validator = EmailValidationService();

    // Check Cooldown
    if (await validator.isCoolingDown()) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'Too many attempts ⚠️',
        'Too many failures. Please wait before trying again.',
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!_isPhoneAuth) {
      // 1. Format validation
      if (!validator.isValidFormat(value)) {
        await validator.logFailure();
        setState(() => _isLoading = false);
        Get.snackbar(
          'Invalid Email ⚠️',
          'Please enter a valid email address format.',
          backgroundColor: context.errorColor.withOpacity(0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // 2. Disposable Email Check
      if (await validator.isDisposable(value)) {
        await validator.logFailure();
        setState(() => _isLoading = false);
        Get.snackbar(
          'Disposable Email Blocked 🚫',
          'This temporary email address is not allowed. Please use your real email.',
          backgroundColor: context.errorColor.withOpacity(0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      // 3. Deliverability / MX Check
      final deliverable = await validator.isDeliverable(value);
      if (!deliverable) {
        setState(() => _isLoading = false);
        await validator.logFailure();
        Get.snackbar(
          'Undeliverable Domain ⚠️',
          'This email domain is undeliverable. Please check spelling or use a different email.',
          backgroundColor: context.errorColor.withOpacity(0.9),
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
          backgroundColor: context.errorColor.withOpacity(0.9),
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
        backgroundColor: context.errorColor.withOpacity(0.9),
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
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      final existing = await Supabase.instance.client
          .from('profiles')
          .select('id, signup_status')
          .eq('email', value)
          .maybeSingle();

      if (existing != null) {
        final signupStatus = existing['signup_status'] as String? ?? 'completed';
        if (signupStatus == 'completed') {
          setState(() => _isLoading = false);
          Get.snackbar(
            'Account Exists ⚠️',
            'This email already has an account. Please sign in.',
            backgroundColor: context.errorColor.withOpacity(0.9),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
          Future.delayed(const Duration(seconds: 2), () {
            Get.offAll(() => const LoginScreen());
          });
          return;
        } else {
          // Incomplete signup: resend OTP and continue
          await _resendWithRetry(email: value, type: OtpType.signup);
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _otpSent = true;
          });
          Get.snackbar(
            'Verification Required ✉️',
            'Resent verification code to continue your signup.',
            backgroundColor: context.accentOrange.withOpacity(0.9),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }
      }

      final response = await _signUpWithRetry(email: value, password: password);

      if (response.session != null) {
        final user = response.user;
        setState(() {
          _userId = user?.id ?? '';
          _isLoading = false;
          _currentStep = 1; // Move to Step 2
        });
        Get.snackbar(
          'Success 🎉',
          'Successfully registered!',
          backgroundColor: context.successColor.withOpacity(0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        // Verification is required, OTP sent
        setState(() {
          _isLoading = false;
          _otpSent = true;
        });

        Get.snackbar(
          'OTP Sent ✉️',
          'Please check your email for the verification code.',
          backgroundColor: context.accentOrange.withOpacity(0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'Auth Error ⚠️',
        _mapAuthError(e),
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 8),
      );
    }
  }

  void _verifyOTP() async {
    if (_isLoading) return;
    final otpCode = _otpCtrl.text.trim();
    if (otpCode.isEmpty) {
      Get.snackbar('Error', 'Please enter the verification code');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final rawVal = _emailPhoneCtrl.text.trim();
      
      final response = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.signup,
        token: otpCode,
        email: rawVal,
      ).timeout(const Duration(seconds: 10));

      final user = response.user;
      if (user != null && _isValidUuid(user.id)) {
        try {
          await Supabase.instance.client
              .from('profiles')
              .update({'signup_status': 'otp_verified'})
              .eq('id', user.id);
        } catch (_) {}

        setState(() {
          _userId = user.id;
          _isLoading = false;
          _currentStep = 1; // Move to Step 2
        });
      } else {
        throw Exception("Authentication session creation failed or invalid user ID.");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'Verification Failed ⚠️',
        _mapAuthError(e),
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
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
            colorScheme: ColorScheme.dark(
              primary: context.primaryColor,
              onPrimary: Colors.white,
              surface: context.secondaryBackgroundColor,
              onSurface: context.textPrimary,
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
      final editedFile = await CustomImageEditor.editImage(context, File(pickedFile.path));
      if (editedFile != null) {
        setState(() {
          _avatarFile = editedFile;
        });
      }
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
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final currentAuthUser = Supabase.instance.client.auth.currentUser;
      final rawUserId = _userId.isEmpty ? (currentAuthUser?.id ?? '') : _userId;

      if (!_isValidUuid(rawUserId)) {
        throw Exception("Invalid user ID. Please log in again.");
      }

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

      if (!_isValidUuid(userIdToUse)) {
        throw Exception("Invalid profile ID. Please log in again.");
      }

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
          uploadedUrl = 'https://api.dicebear.com/7.x/bottts/png?seed=${_usernameCtrl.text.trim()}';
        }
      }

      // 2. Update Database Record
      await Supabase.instance.client.from('profiles').upsert({
        'id': userIdToUse,
        'username': _usernameCtrl.text.trim().toLowerCase(),
        'avatar_url': uploadedUrl ?? 'https://api.dicebear.com/7.x/bottts/png?seed=${_usernameCtrl.text.trim()}',
        'profile_photo': uploadedUrl ?? 'https://api.dicebear.com/7.x/bottts/png?seed=${_usernameCtrl.text.trim()}',
        'bio': _bioCtrl.text.trim().isNotEmpty ? _bioCtrl.text.trim() : 'Learning every day 🚀',
        'dob': _dob?.toIso8601String(),
        'age': _calculatedAge,
        'gender': _selectedGender,
        'country': _selectedCountry,
        'interests': _selectedInterests.toList(),
        'verified': false,
        'avatar_frame': 'Early Explorer Frame',
        'email_verified': !_isPhoneAuth,
        'verification_timestamp': DateTime.now().toIso8601String(),
        'verification_method': _isPhoneAuth ? 'SMS' : 'OTP',
        'last_verification_date': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'signup_status': 'completed',
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
      Get.snackbar(
        'Profile Setup Failed ⚠️',
        _mapAuthError(e),
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _saveOnboardingState() async {
    final currentAuthUser = Supabase.instance.client.auth.currentUser;
    final rawUserId = _userId.isEmpty ? (currentAuthUser?.id ?? '') : _userId;
    if (!_isValidUuid(rawUserId)) return;

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

    if (!_isValidUuid(userIdToUse)) return;

    try {
      final Map<String, dynamic> updates = {};
      
      if (_dob != null) {
        updates['dob'] = _dob!.toIso8601String();
        updates['age'] = _calculatedAge;
      }
      if (_selectedGender != null && _selectedGender!.isNotEmpty) {
        updates['gender'] = _selectedGender;
      }
      if (_selectedCountry != null && _selectedCountry!.isNotEmpty) {
        updates['country'] = _selectedCountry;
      }
      if (_bioCtrl.text.trim().isNotEmpty) {
        updates['bio'] = _bioCtrl.text.trim();
      }
      if (_selectedInterests.isNotEmpty) {
        updates['interests'] = _selectedInterests.toList();
      }

      if (_currentStep >= 2) {
        updates['signup_status'] = 'onboarding_in_progress';
      }

      if (updates.isNotEmpty) {
        await Supabase.instance.client
            .from('profiles')
            .update(updates)
            .eq('id', userIdToUse);
      }
    } catch (e) {
      debugPrint('[SignupFlow] Error auto-saving onboarding state: $e');
    }
  }

  void _nextStep() {
    if (_currentStep < 7) {
      _saveOnboardingState();
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
      backgroundColor: context.scaffoldBackgroundColor,
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
                color: context.primaryColor.withOpacity(0.12),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: SizedBox(),
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
                child: SizedBox(),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top header with step bar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep < 7)
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                          onPressed: () {
                            if (_currentStep > 0) {
                              _prevStep();
                            } else {
                              Get.back();
                            }
                          },
                        )
                      else
                        SizedBox(width: 40),
                      Text(
                        'Step ${_currentStep + 1} of 8',
                        style: GoogleFonts.poppins(
                          color: context.textSecondary,
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
                              color: context.primaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        SizedBox(width: 40),
                    ],
                  ),
                ),

                // Indicator line
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: (size.width - 48) * ((_currentStep + 1) / 8),
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [context.primaryColor, AppTheme.secondaryColor],
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
                    padding: EdgeInsets.all(24),
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
        return SizedBox();
    }
  }

  // --- Step 1 Layout ---
  Widget _buildStep1Verify() {
    if (!_showEmailForm) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sign Up', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Choose how you want to sign up on Creania.', style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 14)),
          const SizedBox(height: 32),

          _socialButton(
            label: 'Continue with Google',
            icon: _googleIcon(),
            onTap: () => _handleSocialSignUp('Google'),
          ),
          const SizedBox(height: 12),

          _socialButton(
            label: 'Continue with Facebook',
            icon: _facebookIcon(),
            onTap: () => _handleSocialSignUp('Facebook'),
          ),
          const SizedBox(height: 12),

          _socialButton(
            label: 'Continue with Email',
            icon: Icon(Icons.email_outlined, color: context.primaryColor, size: 22),
            onTap: () {
              setState(() {
                _showEmailForm = true;
              });
            },
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 20),
              onPressed: () {
                setState(() {
                  _showEmailForm = false;
                });
              },
            ),
            const SizedBox(width: 8),
            Text('Verify Account', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Text('Enter your email to receive a verification OTP code.', style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 14)),
        const SizedBox(height: 32),

        Text('Email Address', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailPhoneCtrl,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            hintText: 'name@domain.com',
            prefixIcon: Icon(Icons.email_outlined, color: context.caption),
          ),
          enabled: !_otpSent,
        ),
        const SizedBox(height: 20),
        Text('Password', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: Icon(Icons.lock_outline_rounded, color: context.caption),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: context.caption),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          enabled: !_otpSent,
          onChanged: (val) => setState(() {}),
        ),
        _buildPasswordStrengthTip(),
        const SizedBox(height: 20),

        Text('Confirm Password', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmPasswordCtrl,
          obscureText: _obscureConfirmPassword,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: Icon(Icons.lock_outline_rounded, color: context.caption),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: context.caption),
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
              Text('OTP Code', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
              TextButton(
                onPressed: () {
                  setState(() {
                    _otpSent = false;
                    _otpCtrl.clear();
                  });
                },
                child: Text(
                  'Change Email',
                  style: GoogleFonts.poppins(color: context.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
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
        SizedBox(height: 8),
        Text('Create a unique handle for your Creania profile.', style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 14)),
        SizedBox(height: 32),

        Text('Username', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
        SizedBox(height: 8),
        TextField(
          controller: _usernameCtrl,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            prefixText: '@ ',
            prefixStyle: TextStyle(color: context.accentOrange, fontWeight: FontWeight.bold, fontSize: 16),
            suffixIcon: _isLoading 
                ? Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : _usernameChecked 
                    ? Icon(_usernameAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded, 
                           color: _usernameAvailable ? context.successColor : context.errorColor)
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
          SizedBox(height: 8),
          Text(_usernameError!, style: TextStyle(color: context.errorColor, fontSize: 12)),
        ],
        if (_usernameChecked && !_usernameAvailable) ...[
          SizedBox(height: 16),
          Text('Username is taken. Try suggestions:', style: GoogleFonts.poppins(fontSize: 12, color: context.caption)),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _usernameSuggestions.map((sug) => ActionChip(
              label: Text('@$sug'),
              backgroundColor: context.secondaryBackgroundColor,
              onPressed: () {
                _usernameCtrl.text = sug;
                _checkUsername(sug);
              },
            )).toList(),
          ),
        ],

        const SizedBox(height: 24),
        _buildTermsRow(),
        const SizedBox(height: 24),
        _buildActionButton('Continue', () async {
          if (!_agreeToTerms) {
            Get.snackbar(
              'Agreement Required ⚠️',
              'Please agree to the Terms of Service & Privacy Policy to proceed.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: context.errorColor.withOpacity(0.9),
              colorText: Colors.white,
            );
            return;
          }
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
            final rawUserId = _userId.isEmpty ? (currentAuthUser?.id ?? '') : _userId;
            
            if (!_isValidUuid(rawUserId)) {
              throw Exception("Invalid user ID. Please log in again.");
            }

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

            if (!_isValidUuid(userIdToUse)) {
              throw Exception("Invalid profile ID. Please log in again.");
            }

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
              try {
                await Supabase.instance.client
                    .from('profiles')
                    .update({
                      'username': username,
                      'signup_status': 'profile_created',
                    })
                    .eq('id', userIdToUse);
              } catch (_) {}
              
              setState(() {
                _usernameAvailable = true;
                _usernameChecked = true;
                _isLoading = false;
              });
              _nextStep();
            }
          } catch (e) {
            setState(() => _isLoading = false);
            Get.snackbar(
              'Profile Setup Failed ⚠️',
              _mapAuthError(e),
              backgroundColor: context.errorColor.withOpacity(0.9),
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM,
            );
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
        SizedBox(height: 8),
        Text('Tell us a bit about yourself. Only display name is visible to others.', style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 14)),
        SizedBox(height: 32),



        Text('Date of Birth *', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
        SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.secondaryBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dob == null ? 'Select Birthday' : DateFormat('dd MMM yyyy').format(_dob!),
                  style: TextStyle(color: _dob == null ? context.caption : Colors.white),
                ),
                Icon(Icons.calendar_month_rounded, color: context.caption),
              ],
            ),
          ),
        ),
        if (_dob != null) ...[
          SizedBox(height: 8),
          Text('Calculated Age: $_calculatedAge years old', 
               style: TextStyle(color: _calculatedAge >= 13 ? context.successColor : context.errorColor, fontSize: 12)),
        ],
        SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Country', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: context.secondaryBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCountry,
                        dropdownColor: context.secondaryBackgroundColor,
                        style: TextStyle(color: context.textPrimary),
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
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gender (Optional)', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: context.secondaryBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGender,
                        hint: Text('Select', style: TextStyle(color: context.caption)),
                        dropdownColor: context.secondaryBackgroundColor,
                        style: TextStyle(color: context.textPrimary),
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

        SizedBox(height: 40),
        _buildActionButton('Continue', () {
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
        SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Add a profile picture so friends can recognize you.', style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 14)),
        ),
        SizedBox(height: 48),

        Center(
          child: Stack(
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.primaryColor, width: 3),
                  color: context.secondaryBackgroundColor,
                  image: _avatarFile != null 
                      ? DecorationImage(image: FileImage(_avatarFile!), fit: BoxFit.cover)
                      : null,
                ),
                child: _avatarFile == null 
                    ? Icon(Icons.person_rounded, size: 70, color: context.caption)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    Get.bottomSheet(
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.secondaryBackgroundColor,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Wrap(
                          children: [
                            ListTile(
                              leading: Icon(Icons.camera_alt_rounded, color: Colors.white),
                              title: Text('Camera', style: TextStyle(color: context.textPrimary)),
                              onTap: () {
                                Get.back();
                                _pickImage(ImageSource.camera);
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.photo_library_rounded, color: Colors.white),
                              title: Text('Gallery', style: TextStyle(color: context.textPrimary)),
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
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 54),

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
        SizedBox(height: 8),
        Text('Write a short bio to introduce yourself (max 150 chars).', style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 14)),
        SizedBox(height: 32),

        Text('Bio', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
        SizedBox(height: 8),
        TextField(
          controller: _bioCtrl,
          maxLines: 4,
          maxLength: 150,
          style: TextStyle(color: context.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Share a little about yourself...',
          ),
        ),
        SizedBox(height: 16),

        Text('Suggestions:', style: GoogleFonts.poppins(fontSize: 12, color: context.caption)),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _bioExamples.map((ex) => ActionChip(
            label: Text(ex),
            backgroundColor: context.secondaryBackgroundColor,
            onPressed: () {
              _bioCtrl.text = ex;
            },
          )).toList(),
        ),

        SizedBox(height: 40),
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
        SizedBox(height: 8),
        Text('Select at least 5 interests to customize your recommendations.', style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 14)),
        SizedBox(height: 24),

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
              selectedColor: context.primaryColor.withOpacity(0.3),
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : context.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: context.secondaryBackgroundColor,
              side: BorderSide(color: isSelected ? context.primaryColor : context.borderColor),
            );
          }).toList(),
        ),
        SizedBox(height: 16),
        Text('Selected: ${_selectedInterests.length} of 5 minimum', 
             style: TextStyle(color: _selectedInterests.length >= 5 ? context.successColor : context.errorColor, fontSize: 12)),

        SizedBox(height: 42),
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
        SizedBox(height: 8),
        Text('Grant permissions for a complete Creania experience.', style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 14)),
        SizedBox(height: 32),

        _permissionItemTile('Microphone', 'Speak in voice rooms and audio circles.', Icons.mic_rounded),
        _permissionItemTile('Camera', 'Take profile picture and stream video.', Icons.camera_alt_rounded),
        _permissionItemTile('Notifications', 'Get notified about direct chats and event start times.', Icons.notifications_rounded),
        _permissionItemTile('Contacts (Optional)', 'Find your friends already on Creania.', Icons.contacts_rounded),
        _permissionItemTile('Storage (Optional)', 'Select files and graphics.', Icons.photo_library_rounded),

        SizedBox(height: 48),
        _buildActionButton('Enable Permissions', _requestPermissions),
      ],
    );
  }

  Widget _permissionItemTile(String title, String desc, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.secondaryBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: context.primaryColor, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 4),
                  Text(desc, style: GoogleFonts.poppins(color: context.caption, fontSize: 11)),
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
          SizedBox(height: 24),
          // Creania Logo
          Image.asset(
            'assets/images/logo.png',
            width: 100,
            height: 100,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 32),

          Text('Congratulations! 🎉', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          SizedBox(height: 12),
          Text('Welcome to Creania! Your profile is ready.', style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 15), textAlign: TextAlign.center),
          SizedBox(height: 40),

          // Rewards Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Early Explorer Rewards Unlocked:', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: context.accentOrange)),
                SizedBox(height: 16),
                _rewardRow('🎖️', 'Early Explorer Badge', 'Exclusive profile recognition'),
                SizedBox(height: 12),
                _rewardRow('🪙', '100 Gold Coins', 'Credited directly to your wallet'),
                SizedBox(height: 12),
                _rewardRow('✨', '7-Day Avatar Frame', 'Equipped automatically'),
                SizedBox(height: 12),
                _rewardRow('📈', 'Boosted Visibility', 'Higher ranking in recommendations'),
              ],
            ),
          ),

          SizedBox(height: 48),
          _buildActionButton('Enter Creania', _completeOnboardingFlow),
        ],
      ),
    );
  }

  Widget _rewardRow(String icon, String title, String desc) {
    return Row(
      children: [
        Text(icon, style: TextStyle(fontSize: 20)),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
            Text(desc, style: GoogleFonts.poppins(color: context.caption, fontSize: 10)),
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
          backgroundColor: context.primaryColor,
        ),
        child: _isLoading 
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  void _handleSocialSignUp(String provider) async {
    setState(() => _isLoading = true);
    try {
      final targetProvider =
          provider.toLowerCase() == 'facebook' ? OAuthProvider.facebook : OAuthProvider.google;

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
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'Social SignUp Failed ⚠️',
        ApiErrorHandler.parseError(e),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    }
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

  Widget _buildTermsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _agreeToTerms,
              onChanged: (v) {
                setState(() {
                  _agreeToTerms = v ?? false;
                });
              },
              activeColor: context.primaryColor,
              checkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              side: BorderSide(color: context.borderColor.withOpacity(0.5), width: 1.5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12, height: 1.5),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: () => Get.to(() => const TermsScreen()),
                      child: Text(
                        'Terms of Service',
                        style: TextStyle(
                          color: context.primaryColor,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: ' & '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: () => Get.to(() => const TermsScreen()),
                      child: Text(
                        'Privacy Policy',
                        style: TextStyle(
                          color: context.primaryColor,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthTip() {
    final password = _passwordCtrl.text;
    
    // Evaluate requirements
    final hasLength = password.length >= 8;
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSymbol = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
    
    Widget requirementRow(String text, bool isMet) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(
              isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isMet ? context.successColor : context.textSecondary.withOpacity(0.4),
              size: 14,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: isMet ? context.textPrimary : context.textSecondary.withOpacity(0.7),
                  fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: context.accentOrange, size: 16),
              const SizedBox(width: 8),
              Text(
                'Password Security Requirements:',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          requirementRow('At least 8 characters long', hasLength),
          requirementRow('Contains uppercase & lowercase letters', hasUppercase && hasLowercase),
          requirementRow('Contains at least one digit (0-9)', hasDigit),
          requirementRow('Contains at least one symbol (!@#\$%...)', hasSymbol),
        ],
      ),
    );
  }
}
