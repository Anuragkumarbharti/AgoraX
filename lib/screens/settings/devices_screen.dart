import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/user_session_model.dart';
import '../../services/auth/device_session_service.dart';
import './login_activity_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({Key? key}) : super(key: key);

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = DeviceSessionService.to;
      service.registerSessionOnLogin();
      service.fetchActiveSessions();
      service.fetchLoginActivityLogs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = DeviceSessionService.to;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Login Activity',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor, width: 0.5),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: context.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: context.textSecondary,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: 'Active Devices'),
                Tab(text: 'Login History'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveDevicesTab(context, service),
          const LoginActivityScreen(isEmbedded: true),
        ],
      ),
    );
  }

  /// Build Active Devices view (CURRENT DEVICE + OTHER DEVICES)
  Widget _buildActiveDevicesTab(BuildContext context, DeviceSessionService service) {
    return Obx(() {
      if (service.isLoadingDevices.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final sessions = service.activeSessions;
      UserSession? currentDevice;
      final otherDevices = <UserSession>[];

      for (var s in sessions) {
        if (s.isCurrent || s.sessionId == service.currentSessionId) {
          currentDevice = s;
        } else {
          otherDevices.add(s);
        }
      }

      // Fallback current device representation if backend list is empty or resolving
      currentDevice ??= UserSession(
        id: 'curr_temp',
        userId: 'temp',
        sessionId: service.currentSessionId,
        deviceId: service.currentDeviceId,
        deviceName: 'This Device (Mobile)',
        platform: 'Android / iOS',
        ipAddress: '103.42.18.99',
        country: 'India',
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        isCurrent: true,
      );

      return RefreshIndicator(
        onRefresh: () async {
          await service.fetchActiveSessions();
          await service.fetchLoginActivityLogs();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Subtitle
              Text(
                'Manage devices where your Creania account is currently signed in.',
                style: GoogleFonts.poppins(
                  color: context.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),

              // 1. CURRENT DEVICE SECTION
              _buildSectionTitle(context, 'CURRENT DEVICE'),
              const SizedBox(height: 10),
              _buildCurrentDeviceCard(context, currentDevice),

              const SizedBox(height: 24),

              // 2. OTHER DEVICES SECTION
              _buildSectionTitle(context, 'OTHER DEVICES'),
              const SizedBox(height: 10),

              if (otherDevices.isEmpty) ...[
                _buildEmptyOtherDevicesCard(context),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: otherDevices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final device = otherDevices[index];
                    return _buildOtherDeviceCard(context, service, device);
                  },
                ),
                const SizedBox(height: 28),

                // 3. LOGOUT FROM ALL OTHER DEVICES SECURITY ACTION
                _buildLogoutAllOtherDevicesButton(context, service),
              ],

              const SizedBox(height: 30),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: context.primaryColor,
        letterSpacing: 1.1,
      ),
    );
  }

  /// CURRENT DEVICE Card (No logout button!)
  Widget _buildCurrentDeviceCard(BuildContext context, UserSession device) {
    IconData iconData = Icons.smartphone_rounded;
    if (device.platform.toLowerCase().contains('ios') || device.platform.toLowerCase().contains('iphone')) {
      iconData = Icons.phone_iphone_rounded;
    } else if (device.platform.toLowerCase().contains('web') || device.platform.toLowerCase().contains('desktop') || device.platform.toLowerCase().contains('windows') || device.platform.toLowerCase().contains('mac')) {
      iconData = Icons.computer_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.primaryColor.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: context.primaryColor.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: context.primaryColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      device.deviceName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'This device',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${device.platform} • ${device.country}',
                  style: GoogleFonts.poppins(
                    color: context.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Active now',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card for OTHER active devices with individual logout button
  Widget _buildOtherDeviceCard(BuildContext context, DeviceSessionService service, UserSession device) {
    IconData iconData = Icons.phone_android_rounded;
    if (device.platform.toLowerCase().contains('ios') || device.platform.toLowerCase().contains('iphone')) {
      iconData = Icons.phone_iphone_rounded;
    } else if (device.platform.toLowerCase().contains('web') || device.platform.toLowerCase().contains('desktop') || device.platform.toLowerCase().contains('windows') || device.platform.toLowerCase().contains('mac')) {
      iconData = Icons.laptop_mac_rounded;
    }

    final isLoggingOut = service.revokingSessionIds[device.sessionId] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
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
            child: Icon(iconData, color: context.textSecondary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.deviceName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${device.platform} • ${device.country}',
                  style: GoogleFonts.poppins(
                    color: context.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatLastActive(device.lastActiveAt),
                  style: GoogleFonts.poppins(
                    color: context.caption,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Individual Logout Button
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: context.errorColor.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            onPressed: isLoggingOut
                ? null
                : () => _confirmLogoutSingleDevice(context, service, device),
            child: isLoggingOut
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Logout',
                    style: GoogleFonts.poppins(
                      color: context.errorColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Empty state when no other devices are logged in
  Widget _buildEmptyOtherDevicesCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(Icons.devices_other_rounded, size: 36, color: context.textSecondary.withOpacity(0.4)),
          const SizedBox(height: 10),
          Text(
            'No other active devices',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your Creania account is only active on this current device.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: context.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// LOGOUT FROM ALL OTHER DEVICES Button Component
  Widget _buildLogoutAllOtherDevicesButton(BuildContext context, DeviceSessionService service) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.errorColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.errorColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security_rounded, color: context.errorColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Security Action',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: context.errorColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Sign out your Creania account from every device except this one.',
            style: GoogleFonts.poppins(
              color: context.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.errorColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: Obx(() {
                return service.isRevokingAll.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.power_settings_new_rounded, color: Colors.white, size: 18);
              }),
              label: Obx(() {
                return Text(
                  service.isRevokingAll.value
                      ? 'Logging out other devices...'
                      : 'Logout from All Other Devices',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                );
              }),
              onPressed: service.isRevokingAll.value
                  ? null
                  : () => _confirmLogoutAllOtherDevices(context, service),
            ),
          ),
        ],
      ),
    );
  }

  /// Confirmation Modal for Single Device Logout
  void _confirmLogoutSingleDevice(BuildContext context, DeviceSessionService service, UserSession device) {
    Get.dialog(
      AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout this device?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Text(
          'This will sign out your Creania account from ${device.deviceName} (${device.platform}).',
          style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: context.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Get.back();
              service.revokeSession(device.sessionId, device.deviceName);
            },
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Confirmation Modal for Logout From All Other Devices
  void _confirmLogoutAllOtherDevices(BuildContext context, DeviceSessionService service) {
    Get.dialog(
      AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout from all other devices?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Text(
          'You will be signed out from all other devices. Your current device will remain logged in.',
          style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: context.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Get.back();
              service.revokeAllOtherSessions();
            },
            child: Text(
              'Logout from All Devices',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastActive(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) {
      return 'Active just now';
    } else if (diff.inMinutes < 60) {
      return 'Active ${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return 'Active ${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return 'Active yesterday';
    } else {
      return 'Active ${DateFormat.yMMMd().format(dt)}';
    }
  }
}
