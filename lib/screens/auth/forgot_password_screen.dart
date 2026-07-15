import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:creania/core/theme.dart';
import 'otp_verification_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late TextEditingController _inputController;
  bool _isLoading = false;
  bool _isPhone = false;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _handleSendOTP() async {
    final value = _inputController.text.trim();
    if (value.isEmpty) {
      Get.snackbar(
        'Required',
        'Please enter your ${_isPhone ? 'phone number' : 'email address'}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final column = _isPhone ? 'phone' : 'email';
      final res = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq(column, value)
          .maybeSingle();

      if (res == null) {
        setState(() => _isLoading = false);
        Get.snackbar(
          'Account Not Found ⚠️',
          _isPhone
              ? 'No account found with this phone number.'
              : 'No account found with this email.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: context.errorColor,
          colorText: Colors.white,
        );
        return;
      }
      
      setState(() => _isLoading = false);
      
      Get.snackbar(
        'OTP Sent ✉️',
        'Use code 0 to verify (Sandbox mode)',
        backgroundColor: context.accentOrange.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      Get.to(
        () => OTPVerificationScreen(email: value),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'Error ⚠️',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Reset Password',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Select method and enter credentials to recover password.',
                  style: GoogleFonts.poppins(
                    color: context.textSecondary,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 36),

                // Selector Tabs
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text('Email Address'),
                        selected: !_isPhone,
                        onSelected: (val) {
                          setState(() {
                            _isPhone = false;
                            _inputController.clear();
                          });
                        },
                        selectedColor: context.primaryColor.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: !_isPhone ? Colors.white : context.caption,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: Text('Phone Number'),
                        selected: _isPhone,
                        onSelected: (val) {
                          setState(() {
                            _isPhone = true;
                            _inputController.clear();
                          });
                        },
                        selectedColor: context.primaryColor.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: _isPhone ? Colors.white : context.caption,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 36),

                // Illustration
                Center(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: context.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      _isPhone ? Icons.phone_iphone_rounded : Icons.mail_outline_rounded,
                      size: 52,
                      color: context.primaryColor,
                    ),
                  ),
                ),
                SizedBox(height: 48),

                // Input Field
                Text(
                  _isPhone ? 'Phone Number' : 'Email Address',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _inputController,
                  keyboardType: _isPhone ? TextInputType.phone : TextInputType.emailAddress,
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: _isPhone ? '+91 98765 43210' : 'name@example.com',
                    prefixIcon: Icon(
                      _isPhone ? Icons.phone_android_rounded : Icons.alternate_email_rounded,
                      color: context.caption,
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(height: 40),

                // Send OTP Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSendOTP,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Send OTP',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
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
