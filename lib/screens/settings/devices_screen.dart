import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/user/user_profile_cache_manager.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({Key? key}) : super(key: key);

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _devices = [];

  @override
  void initState() {
    super.initState();
    _initDeviceAndFetch();
  }

  Future<void> _initDeviceAndFetch() async {
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty) return;

    try {
      final String platform = Platform.isAndroid
          ? 'Android'
          : (Platform.isIOS ? 'iOS' : 'Web/Desktop');
      final String deviceName = Platform.isAndroid
          ? 'Android Device'
          : (Platform.isIOS ? 'iPhone' : 'Web Session');
      final String deviceId = '${userId}_${platform.toLowerCase()}';

      // Auto-register current device
      await _supabase.rpc('register_user_device', params: {
        'p_device_id': deviceId,
        'p_device_name': deviceName,
        'p_platform': platform,
        'p_ip': '127.0.0.1',
      });
    } catch (e) {
      debugPrint('[DevicesScreen] Error registering current device: $e');
    }

    _fetchDevices();
  }

  Future<void> _fetchDevices() async {
    setState(() => _isLoading = true);
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty) return;

    try {
      final res = await _supabase
          .from('user_devices')
          .select()
          .eq('user_id', userId)
          .isFilter('revoked_at', null)
          .order('last_active', ascending: false);

      setState(() {
        _devices = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[DevicesScreen] Error fetching devices: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _revokeDevice(String deviceId, String deviceName) async {
    try {
      final res = await _supabase.rpc('revoke_user_device', params: {'p_device_id': deviceId});
      if (res != null && res['success'] == true) {
        setState(() {
          _devices.removeWhere((d) => d['device_id'] == deviceId);
        });
        Get.snackbar(
          'Access Revoked',
          'Session for $deviceName has been revoked.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar('Error', res?['error'] ?? 'Failed to revoke device');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to revoke device access: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Authorized Devices',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    final String deviceId = device['device_id'] ?? '';
                    final String deviceName = device['device_name'] ?? 'Unknown Device';
                    final String platform = device['platform'] ?? 'Mobile';
                    final bool isCurrent = device['is_current'] ?? false;
                    final String lastActiveStr = device['last_active'] ?? '';
                    DateTime? lastActive;
                    if (lastActiveStr.isNotEmpty) {
                      lastActive = DateTime.tryParse(lastActiveStr);
                    }

                    IconData platformIcon = Icons.phone_android_rounded;
                    if (platform.toLowerCase().contains('ios') || platform.toLowerCase().contains('iphone')) {
                      platformIcon = Icons.phone_iphone_rounded;
                    } else if (platform.toLowerCase().contains('web') || platform.toLowerCase().contains('desktop')) {
                      platformIcon = Icons.computer_rounded;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrent
                              ? context.primaryColor.withOpacity(0.5)
                              : context.borderColor,
                          width: isCurrent ? 1.5 : 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? context.primaryColor.withOpacity(0.12)
                                  : context.scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              platformIcon,
                              color: isCurrent ? context.primaryColor : context.textSecondary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      deviceName,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        color: context.textPrimary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (isCurrent) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: context.primaryColor,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'THIS DEVICE',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lastActive != null
                                      ? 'Active: ${DateFormat.yMMMd().add_jm().format(lastActive)}'
                                      : platform,
                                  style: GoogleFonts.poppins(
                                    color: context.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isCurrent)
                            IconButton(
                              icon: Icon(Icons.logout_rounded, color: context.errorColor, size: 20),
                              tooltip: 'Revoke Device',
                              onPressed: () => _revokeDevice(deviceId, deviceName),
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
          Icon(Icons.devices_rounded, size: 64, color: context.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No Active Devices Found',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
