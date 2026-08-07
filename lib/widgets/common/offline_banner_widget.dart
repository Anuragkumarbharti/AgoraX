import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/network/network_connectivity_service.dart';

/// Global Reusable Offline Banner Widget
/// Displays a clean animated top banner whenever internet connectivity is lost or weak.
class OfflineBannerWidget extends StatelessWidget {
  final bool showWeakWarning;

  const OfflineBannerWidget({
    Key? key,
    this.showWeakWarning = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final netService = NetworkConnectivityService.to;

    return Obx(() {
      final bool online = netService.isOnline.value;
      final bool weak = netService.isWeak.value;

      if (online && (!weak || !showWeakWarning)) {
        return const SizedBox.shrink();
      }

      final bool isOffline = !online;
      final Color bgColor = isOffline ? const Color(0xFFD32F2F) : const Color(0xFFF57C00);
      final IconData icon = isOffline ? Icons.wifi_off_rounded : Icons.signal_cellular_connected_no_internet_4_bar_rounded;
      final String label = isOffline
          ? "📶 No Internet Connection"
          : "⚠️ Weak / Unstable Network";

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await netService.forceRetryCheck();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Retry",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Offline Mode Cache Badge
/// Displayed on cached data lists, profiles, or feeds when viewed offline.
class OfflineCacheBadge extends StatelessWidget {
  const OfflineCacheBadge({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final netService = NetworkConnectivityService.to;

    return Obx(() {
      if (netService.isOnline.value) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF424242).withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: Colors.amber, size: 13),
            SizedBox(width: 5),
            Text(
              "Offline Mode • Showing cached data",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    });
  }
}
