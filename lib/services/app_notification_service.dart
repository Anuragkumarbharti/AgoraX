import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class AppNotification {
  static void show({
    required String title,
    String message = '',
    IconData icon = Icons.info_outline_rounded,
  }) {
    try {
      final BuildContext? context = Get.overlayContext;
      final OverlayState? overlayState = context != null
          ? Overlay.of(context)
          : Get.key.currentState?.overlay;

      if (overlayState == null) return;

      OverlayEntry? entry;
      entry = OverlayEntry(
        builder: (ctx) => _AppCenterNotificationWidget(
          title: title,
          message: message,
          icon: icon,
          onDismiss: () {
            entry?.remove();
          },
        ),
      );

      overlayState.insert(entry);
    } catch (e) {
      debugPrint('[AppNotification] Error showing notification: $e');
    }
  }

  static void showCenter(
    BuildContext context, {
    required String title,
    String message = '',
    IconData icon = Icons.info_outline_rounded,
  }) {
    show(title: title, message: message, icon: icon);
  }
}

class _AppCenterNotificationWidget extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback onDismiss;

  const _AppCenterNotificationWidget({
    Key? key,
    required this.title,
    required this.message,
    required this.icon,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<_AppCenterNotificationWidget> createState() =>
      __AppCenterNotificationWidgetState();
}

class __AppCenterNotificationWidgetState
    extends State<_AppCenterNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            widget.onDismiss();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 280),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xEE1E1E2E),
                            Color(0xEE0F172A),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.purpleAccent.withOpacity(0.35),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.purpleAccent.withOpacity(0.15),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.icon,
                              color: const Color(0xFFA78BFA),
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (widget.message.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.message,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
