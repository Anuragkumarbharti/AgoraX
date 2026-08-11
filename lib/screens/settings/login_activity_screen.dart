import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/user_session_model.dart';
import '../../services/auth/device_session_service.dart';

class LoginActivityScreen extends StatefulWidget {
  final bool isEmbedded;
  const LoginActivityScreen({Key? key, this.isEmbedded = false}) : super(key: key);

  @override
  State<LoginActivityScreen> createState() => _LoginActivityScreenState();
}

class _LoginActivityScreenState extends State<LoginActivityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeviceSessionService.to.fetchLoginActivityLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = DeviceSessionService.to;

    final content = Obx(() {
      if (service.isLoadingLogs.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final logs = service.loginLogs;
      if (logs.isEmpty) {
        return _buildEmptyState(context);
      }

      return RefreshIndicator(
        onRefresh: () async => await service.fetchLoginActivityLogs(),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final log = logs[index];
            return _buildActivityTile(context, log);
          },
        ),
      );
    });

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Login Activity History',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: content,
    );
  }

  Widget _buildActivityTile(BuildContext context, LoginActivityLog log) {
    final isSuccess = log.status.toLowerCase() == 'success';
    final is2FA = log.eventType.contains('2FA') || log.authMethod.contains('2FA');
    final isFailed = !isSuccess || log.eventType.toLowerCase().contains('failed');

    IconData platformIcon = Icons.phonelink_setup_rounded;
    if (log.platform.toLowerCase().contains('ios') || log.platform.toLowerCase().contains('iphone')) {
      platformIcon = Icons.phone_iphone_rounded;
    } else if (log.platform.toLowerCase().contains('web') || log.platform.toLowerCase().contains('desktop') || log.platform.toLowerCase().contains('windows')) {
      platformIcon = Icons.laptop_mac_rounded;
    } else if (log.platform.toLowerCase().contains('android')) {
      platformIcon = Icons.phone_android_rounded;
    }

    Color statusColor = isFailed
        ? context.errorColor
        : (is2FA ? const Color(0xFF3B82F6) : const Color(0xFF10B981));

    String statusLabel = log.eventType;
    if (isFailed) {
      statusLabel = log.failureReason ?? 'Failed login attempt';
    }

    return InkWell(
      onTap: () => _showActivityDetailsModal(context, log),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor, width: 0.5),
        ),
        child: Row(
          children: [
            // Status Icon Indicator
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isFailed
                    ? Icons.gpp_bad_rounded
                    : (is2FA ? Icons.verified_user_rounded : platformIcon),
                color: statusColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Activity Text Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        log.deviceName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusLabel,
                    style: GoogleFonts.poppins(
                      color: isFailed ? context.errorColor : context.textSecondary,
                      fontSize: 12,
                      fontWeight: isFailed ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat.yMMMd().add_jm().format(log.loginAt)} • ${log.country}',
                    style: GoogleFonts.poppins(
                      color: context.caption,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            Icon(Icons.chevron_right_rounded, color: context.textSecondary.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }

  /// Show Detailed Login Activity Item Modal
  void _showActivityDetailsModal(BuildContext context, LoginActivityLog log) {
    final isSuccess = log.status.toLowerCase() == 'success';
    final isFailed = !isSuccess || log.eventType.toLowerCase().contains('failed');

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  isFailed ? Icons.warning_amber_rounded : Icons.security_rounded,
                  color: isFailed ? context.errorColor : context.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  'Login Activity Details',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildDetailRow(context, 'Event', log.eventType),
            _buildDetailRow(context, 'Device', log.deviceName),
            _buildDetailRow(context, 'Platform', log.platform),
            _buildDetailRow(context, 'Location', log.country),
            _buildDetailRow(context, 'Login Time', DateFormat.yMMMMd().add_jm().format(log.loginAt)),
            _buildDetailRow(context, 'Auth Method', log.authMethod),
            _buildDetailRow(context, 'IP Address', log.maskedIp),
            _buildDetailRow(
              context,
              'Status',
              log.status.toUpperCase(),
              valueColor: isFailed ? context.errorColor : const Color(0xFF10B981),
            ),

            if (log.failureReason != null && log.failureReason!.isNotEmpty)
              _buildDetailRow(context, 'Reason', log.failureReason!, valueColor: context.errorColor),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Get.back(),
                child: Text(
                  'Close',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: context.textSecondary,
              fontSize: 13,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: valueColor ?? context.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 56, color: context.textSecondary.withOpacity(0.4)),
          const SizedBox(height: 14),
          Text(
            'No Recent Login Records',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your account login security events will be recorded here.',
            textAlign: TextAlign.center,
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
