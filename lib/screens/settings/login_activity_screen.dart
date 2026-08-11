import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/user/user_profile_cache_manager.dart';

class LoginActivityScreen extends StatefulWidget {
  const LoginActivityScreen({Key? key}) : super(key: key);

  @override
  State<LoginActivityScreen> createState() => _LoginActivityScreenState();
}

class _LoginActivityScreenState extends State<LoginActivityScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _loginLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchLoginActivity();
  }

  Future<void> _fetchLoginActivity() async {
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('user_login_activity')
          .select()
          .eq('user_id', userId)
          .order('login_at', ascending: false)
          .limit(30);

      setState(() {
        _loginLogs = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[LoginActivityScreen] Error fetching logs: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Login Activity',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loginLogs.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _loginLogs.length,
                  itemBuilder: (context, index) {
                    final log = _loginLogs[index];
                    final String deviceName = log['device_name'] ?? 'Unknown Device';
                    final String platform = log['platform'] ?? 'Mobile';
                    final String ipAddress = log['ip_address'] ?? '127.0.0.1';
                    final String loginAtStr = log['login_at'] ?? '';
                    DateTime? loginAt;
                    if (loginAtStr.isNotEmpty) {
                      loginAt = DateTime.tryParse(loginAtStr);
                    }

                    IconData platformIcon = Icons.phonelink_setup_rounded;
                    if (platform.toLowerCase().contains('ios') || platform.toLowerCase().contains('iphone')) {
                      platformIcon = Icons.phone_iphone_rounded;
                    } else if (platform.toLowerCase().contains('web') || platform.toLowerCase().contains('desktop')) {
                      platformIcon = Icons.laptop_mac_rounded;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.borderColor, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: context.scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(platformIcon, color: context.primaryColor, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  deviceName,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'IP: $ipAddress • Platform: $platform',
                                  style: GoogleFonts.poppins(
                                    color: context.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                if (loginAt != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat.yMMMd().add_jm().format(loginAt),
                                    style: GoogleFonts.poppins(
                                      color: context.caption,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 64, color: context.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No Recent Login Records',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your recent account login sessions will be recorded here.',
            style: GoogleFonts.poppins(
              color: context.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
