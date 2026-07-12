import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import 'interests_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String userId;

  const EmailVerificationScreen({
    Key? key,
    required this.email,
    required this.userId,
  }) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late List<TextEditingController> _otpControllers;
  bool _isLoading = false;
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    _otpControllers = List.generate(6, (_) => TextEditingController());
    _startTimer();
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_secondsRemaining > 0 && mounted) {
        setState(() => _secondsRemaining--);
        _startTimer();
      }
    });
  }

  void _handleVerifyEmail() {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      Get.snackbar(
        'Error',
        'Please enter 6-digit code',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor,
      );
      return;
    }

    setState(() => _isLoading = true);

    Supabase.instance.client.auth.verifyOTP(
      token: otp,
      type: OtpType.signup,
      email: widget.email,
    ).then((_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Get.to(
        () => InterestsScreen(userId: widget.userId),
      );
    }).catchError((e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Get.snackbar(
        'Verification Failed ⚠️',
        e.toString().replaceAll('AuthException: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Verify Email',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the verification code sent to ${widget.email}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 60),

                // Illustration
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.mail_outline,
                      size: 60,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 60),

                // OTP Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    6,
                    (index) => SizedBox(
                      width: 50,
                      height: 60,
                      child: TextField(
                        controller: _otpControllers[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        decoration: InputDecoration(
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.borderColor,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.borderColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.length == 1 && index < 5) {
                            FocusScope.of(context).nextFocus();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Resend Timer
                Center(
                  child: _secondsRemaining > 0
                      ? Text(
                          'Resend code in $_secondsRemaining seconds',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textTertiary,
                              ),
                        )
                      : GestureDetector(
                          onTap: () {
                            setState(() => _secondsRemaining = 60);
                            _startTimer();
                          },
                          child: Text(
                            'Resend Code',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                ),
                const SizedBox(height: 40),

                // Verify Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerifyEmail,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Verify Email',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
