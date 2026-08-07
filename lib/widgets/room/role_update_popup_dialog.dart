import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

enum RoleUpdateType { assigned, removed }

class RoleUpdatePopupDialog extends StatefulWidget {
  final RoleUpdateType type;
  final String roleName;
  final String roomName;
  final String? oldRoleName;
  final String? reason;

  const RoleUpdatePopupDialog({
    Key? key,
    required this.type,
    required this.roleName,
    required this.roomName,
    this.oldRoleName,
    this.reason,
  }) : super(key: key);

  static void showRoleAssigned({
    required String roleName,
    required String roomName,
  }) {
    Get.dialog(
      RoleUpdatePopupDialog(
        type: RoleUpdateType.assigned,
        roleName: roleName,
        roomName: roomName,
      ),
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.65),
    );
  }

  static void showRoleRemoved({
    required String oldRoleName,
    required String roomName,
    String? reason,
  }) {
    Get.dialog(
      RoleUpdatePopupDialog(
        type: RoleUpdateType.removed,
        roleName: 'Audience',
        oldRoleName: oldRoleName,
        roomName: roomName,
        reason: reason,
      ),
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.65),
    );
  }

  @override
  State<RoleUpdatePopupDialog> createState() => _RoleUpdatePopupDialogState();
}

class _RoleUpdatePopupDialogState extends State<RoleUpdatePopupDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _fadeAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAssigned = widget.type == RoleUpdateType.assigned;
    final primaryColor =
        isAssigned ? const Color(0xFFFFD700) : const Color(0xFFFF453A);
    final secondaryColor =
        isAssigned ? const Color(0xFFFF9500) : const Color(0xFFFF375F);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF141724).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.2),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Icon / Celebration
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withOpacity(0.2),
                            secondaryColor.withOpacity(0.3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.6),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isAssigned
                            ? Icons.verified_user_rounded
                            : Icons.gavel_rounded,
                        color: primaryColor,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header Text
                    Text(
                      isAssigned ? '🎉 Congratulations!' : 'Role Updated',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),

                    // Content text
                    if (isAssigned) ...[
                      Text(
                        'You have been promoted to',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Role Tag Box
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor.withOpacity(0.25),
                              secondaryColor.withOpacity(0.25),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: primaryColor.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_rounded,
                                color: primaryColor, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              widget.roleName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        'Room: ${widget.roomName}',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white60,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),

                      Text(
                        'Your new permissions are now active.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      Text(
                        'Your ${widget.oldRoleName ?? "Admin"} role has been removed.',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),

                      Text(
                        'You are now an Audience member.',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      if (widget.reason != null &&
                          widget.reason!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reason:',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white54,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.reason!,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                        onPressed: () => Get.back(),
                        child: Text(
                          isAssigned ? 'Got it!' : 'Dismiss',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
