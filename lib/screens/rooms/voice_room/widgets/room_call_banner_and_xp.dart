import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/room/room_connection_controller.dart';
import '../../../../services/room/room_controller.dart';
import '../../../../widgets/index.dart';

class RoomCallBannerAndXp {
  static Widget buildDisconnectOverlay() {
    final RoomController controller = RoomController.to;

    return Obx(() {
      final isDisconnecting = controller.isRoomDisconnecting.value;
      if (!isDisconnecting) {
        return const SizedBox.shrink();
      }

      final title = controller.disconnectTitle.value.isNotEmpty
          ? controller.disconnectTitle.value
          : 'Network Issue Detected 📡';
      final reason = controller.disconnectReason.value.isNotEmpty
          ? controller.disconnectReason.value
          : 'Connecting to room... Please wait';

      final isKick = title.contains('Kick') || title.contains('Removed');

      return Positioned.fill(
        child: Container(
          color: Colors.black.withOpacity(0.85),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isKick ? Colors.redAccent : Colors.orangeAccent,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isKick ? Colors.red : Colors.orange)
                          .withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: (isKick ? Colors.red : Colors.orange)
                            .withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          isKick ? '🥾' : '📡',
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      reason,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isKick ? Colors.redAccent : Colors.orangeAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  static Widget buildNonBlockingNetworkStatusBanner() {
    return Obx(() {
      if (!Get.isRegistered<RoomConnectionController>()) {
        return const SizedBox.shrink();
      }
      final connCtrl = RoomConnectionController.to;
      final netState = connCtrl.roomNetworkState.value;
      final isReconnecting = connCtrl.isReconnecting.value;

      final bool showBanner = isReconnecting ||
          netState == RoomNetworkState.networkIssue ||
          netState == RoomNetworkState.networkLost;

      if (!showBanner) {
        return const SizedBox.shrink();
      }

      final String message = netState == RoomNetworkState.networkLost
          ? "No internet connection. Reconnecting..."
          : "Network issue. Reconnecting...";

      return Positioned(
        top: 90,
        left: 20,
        right: 20,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade900.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.6), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  static Widget buildCustomBackground() {
    final RoomController controller = RoomController.to;

    return Obx(() {
      final bg = controller.activeRoomBackground.value;
      return RoomDynamicBackgroundWidget(background: bg);
    });
  }
}
