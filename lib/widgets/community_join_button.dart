import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/community_model.dart';
import '../services/community_controller.dart';
import '../services/user_profile_cache_manager.dart';

class CommunityJoinButton extends StatefulWidget {
  final Community community;
  final double? height;
  final double? width;
  final double borderRadius;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;

  const CommunityJoinButton({
    Key? key,
    required this.community,
    this.height,
    this.width,
    this.borderRadius = 8.0,
    this.textStyle,
    this.padding,
  }) : super(key: key);

  @override
  State<CommunityJoinButton> createState() => _CommunityJoinButtonState();
}

class _CommunityJoinButtonState extends State<CommunityJoinButton>
    with TickerProviderStateMixin {
  late final CommunityController _controller;
  late final AnimationController _scaleController;
  late final AnimationController _checkController;
  StreamSubscription? _membershipSubscription;

  final RxBool _localJoined = false.obs;
  final RxBool _isSyncing = false.obs;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<CommunityController>();

    _localJoined.value =
        _controller.userMembership.value?.communityId == widget.community.id;

    _membershipSubscription = _controller.userMembership.listen((membership) {
      _localJoined.value = membership?.communityId == widget.community.id;
      if (_localJoined.value) {
        _checkController.forward();
      } else {
        _checkController.reverse();
      }
    });

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 0.1,
    );

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    if (_localJoined.value) {
      _checkController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _membershipSubscription?.cancel();
    _scaleController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  Future<void> _joinAction() async {
    _localJoined.value = true;
    _scaleController.forward(from: 0.0).then((_) => _scaleController.reverse());
    _checkController.forward(from: 0.0);

    Get.snackbar(
      'Joined Family 🎉',
      'You joined ${widget.community.name} successfully.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF10B981).withOpacity(0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );

    _isSyncing.value = true;
    final err = await _controller.joinCommunity(widget.community.id);
    _isSyncing.value = false;

    if (err != null) {
      _localJoined.value = false;
      _checkController.reverse();
      Get.snackbar(
        'Join Failed ⚠️',
        err,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _leaveAction() async {
    _localJoined.value = false;
    _checkController.reverse();

    Get.snackbar(
      'Family Left 🔴',
      'You left ${widget.community.name}',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );

    _isSyncing.value = true;
    final err = await _controller.leaveCommunity(widget.community.id);
    _isSyncing.value = false;

    if (err != null) {
      _localJoined.value = true;
      _checkController.forward();
      Get.snackbar(
        'Leave Failed ⚠️',
        err,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  void _showLeaveConfirmDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1B1D2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Leave ${widget.community.name}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to leave ${widget.community.name}? You can only be a member of one community at a time.',
          style: const TextStyle(
              color: Colors.white70, fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _leaveAction();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Leave Community',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isJoined = _localJoined.value;
      final accentColor = widget.community.isOfficial
          ? const Color(0xFF10B981)
          : const Color(0xFF6366F1);

      return GestureDetector(
        onTap: () {
          if (_isSyncing.value) return;
          if (isJoined) {
            final role = _controller.userMembership.value?.role;
            if (role?.toLowerCase() == 'owner' || role == 'Owner') {
              Get.snackbar(
                'Action Denied ⚠️',
                'Owner cannot leave the community.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
                colorText: Colors.white,
              );
              return;
            }
            _showLeaveConfirmDialog();
          } else {
            // Check if user is already a member of another community
            final otherJoined = _controller.userMembership.value != null;
            if (otherJoined) {
              Get.dialog(
                AlertDialog(
                  backgroundColor: const Color(0xFF1B1D2A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Family Membership Limit 🔒',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  content: const Text(
                    'You can only be a member of one community at a time. Please leave your current Family first.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.45),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('OK',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              return;
            }
            _joinAction();
          }
        },
        child: AnimatedBuilder(
          animation: _scaleController,
          builder: (context, child) {
            final scale = 1.0 - _scaleController.value;
            return Transform.scale(
              scale: scale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: widget.height ?? 32,
                width: widget.width,
                padding: widget.padding ??
                    const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isJoined ? Colors.transparent : accentColor,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: isJoined ? Colors.white24 : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: isJoined
                      ? Row(
                          key: const ValueKey('joined_row'),
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizeTransition(
                              sizeFactor: _checkController,
                              axis: Axis.horizontal,
                              axisAlignment: -1,
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.green, size: 14),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Joined',
                              style: widget.textStyle ??
                                  const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                            ),
                          ],
                        )
                      : Text(
                          'Join',
                          key: const ValueKey('join_text'),
                          style: widget.textStyle ??
                              const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
