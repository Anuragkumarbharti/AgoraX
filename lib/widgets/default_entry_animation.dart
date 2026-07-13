import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import '../services/user_profile_cache_manager.dart';
import '../models/user_model.dart';
import 'custom_avatar_frame.dart';
import 'premium_name_widget.dart';
import 'vip_badge_widget.dart';
import 'novel_badge_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DefaultEntryAnimation extends StatefulWidget {
  final String username;
  final String? avatarUrl;
  final String userId;
  final VoidCallback? onFinished;

  const DefaultEntryAnimation({
    Key? key,
    required this.username,
    this.avatarUrl,
    required this.userId,
    this.onFinished,
  }) : super(key: key);

  @override
  State<DefaultEntryAnimation> createState() => _DefaultEntryAnimationState();
}

class _DefaultEntryAnimationState extends State<DefaultEntryAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offset;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _offset = Tween<Offset>(
      begin: const Offset(-1.2, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward().then((_) async {
      await Future.delayed(const Duration(milliseconds: 2200));
      if (mounted) {
        _controller.reverse().then((_) {
          if (widget.onFinished != null) {
            widget.onFinished!();
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
    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.85),
                  const Color(0xFF1E293B).withOpacity(0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white24, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Obx(() {
              final u = UserProfileCacheManager.rxCache[widget.userId] ?? UserProfileCacheManager.getCachedUser(widget.userId);
              final String uName = u?.username ?? widget.username;
              final String? uAvatar = u?.avatar ?? widget.avatarUrl;
              final int uLevel = u?.level ?? 1;
              final int vipLevel = u?.vipLevel ?? 0;
              final int novelLevel = u?.novelLevel ?? 0;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomAvatarFrame(
                    userId: widget.userId,
                    username: uName,
                    size: 30,
                    defaultVipLevel: vipLevel,
                    defaultNovelLevel: novelLevel,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundImage: uAvatar != null && uAvatar.isNotEmpty
                          ? CachedNetworkImageProvider(uAvatar)
                          : null,
                      child: uAvatar == null || uAvatar.isEmpty
                          ? const Icon(Icons.person, size: 15, color: Colors.white54)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  PremiumNameWidget(
                    name: uName,
                    userId: widget.userId,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.4), width: 0.5),
                    ),
                    child: Text(
                      'LV.$uLevel',
                      style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (vipLevel > 0) ...[
                    VipBadgeWidget(level: vipLevel, fontSize: 7),
                    const SizedBox(width: 4),
                  ],
                  if (novelLevel > 0) ...[
                    NovelBadgeWidget(level: novelLevel, fontSize: 7),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    'entered the room 👋',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
