import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'network_connectivity_service.dart';

/// Network Guard Utility
/// Prevents network-dependent actions from executing when offline,
/// shows clear instant feedback to the user, and logs analytics events.
class NetworkGuard {
  /// Checks if internet connectivity is active.
  /// If offline, presents a standardized notification snackbar and logs the blocked action.
  static bool checkInternet({
    String? actionName,
    String? customOfflineMessage,
    BuildContext? context,
    bool showSnackbar = true,
  }) {
    final netService = NetworkConnectivityService.to;
    final bool online = netService.isOnline.value;

    if (!online) {
      if (actionName != null) {
        netService.logAnalyticsEvent('action_blocked_offline', {'action': actionName});
      }

      if (showSnackbar) {
        final message = customOfflineMessage ?? _getDefaultOfflineMessage(actionName);
        _showOfflineSnackbar(message);
      }
      return false;
    }
    return true;
  }

  /// Runs the provided asynchronous [action] ONLY if internet is available.
  /// Returns `true` if executed, `false` if blocked due to offline state.
  static Future<bool> runIfOnline({
    required Future<void> Function() action,
    String? actionName,
    String? customOfflineMessage,
    BuildContext? context,
    VoidCallback? onOfflineBlocked,
  }) async {
    if (!checkInternet(
      actionName: actionName,
      customOfflineMessage: customOfflineMessage,
      context: context,
    )) {
      if (onOfflineBlocked != null) {
        onOfflineBlocked();
      }
      return false;
    }

    try {
      await action();
      return true;
    } catch (e) {
      debugPrint('[NetworkGuard] Error executing online action ($actionName): $e');
      rethrow;
    }
  }

  static String _getDefaultOfflineMessage(String? actionName) {
    if (actionName == null) return "No internet connection.";

    switch (actionName.toLowerCase()) {
      case 'room_join':
      case 'room_entry':
        return "No internet connection. You can't join the room.";
      case 'gift':
      case 'send_gift':
        return "No internet. Gift not sent.";
      case 'post':
      case 'comment':
      case 'like':
      case 'share':
      case 'follow':
        return "No internet connection.";
      case 'wallet':
      case 'recharge':
      case 'withdraw':
      case 'purchase':
        return "Recharge & Wallet actions unavailable offline.";
      case 'chat':
        return "Waiting for internet connection...";
      case 'search':
        return "Internet required to search.";
      default:
        return "No internet connection.";
    }
  }

  static void _showOfflineSnackbar(String message) {
    if (Get.context == null || Get.overlayContext == null) return;
    if (Get.isSnackbarOpen) return;

    Get.rawSnackbar(
      messageText: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFE53935),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      mainButton: TextButton(
        onPressed: () async {
          Get.back();
          final restored = await NetworkConnectivityService.to.forceRetryCheck();
          if (restored) {
            Get.rawSnackbar(
              message: "📶 Internet connection restored!",
              backgroundColor: const Color(0xFF43A047),
              snackPosition: SnackPosition.TOP,
              duration: const Duration(seconds: 2),
            );
          }
        },
        child: const Text(
          "RETRY",
          style: TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }
}
