import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../services/user_profile_cache_manager.dart';
import 'send_gift_dialog.dart';

class MessageLimitDialog extends StatelessWidget {
  final String targetUserId;
  final String targetUserName;
  final String conversationId;
  final VoidCallback? onGiftUnlocked;
  final VoidCallback? onFollowUpdated;

  const MessageLimitDialog({
    Key? key,
    required this.targetUserId,
    required this.targetUserName,
    required this.conversationId,
    this.onGiftUnlocked,
    this.onFollowUpdated,
  }) : super(key: key);

  static Future<void> show({
    required BuildContext context,
    required String targetUserId,
    required String targetUserName,
    required String conversationId,
    VoidCallback? onGiftUnlocked,
    VoidCallback? onFollowUpdated,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => MessageLimitDialog(
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        conversationId: conversationId,
        onGiftUnlocked: onGiftUnlocked,
        onFollowUpdated: onFollowUpdated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isFollowing = UserProfileCacheManager.followedUserIds.contains(targetUserId);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0F172A).withOpacity(0.92),
                const Color(0xFF1E293B).withOpacity(0.88),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.25),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Lock Badge Icon
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.3),
                      AppTheme.accentColor.withOpacity(0.2),
                    ],
                  ),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5), width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.lock_clock_rounded, color: Colors.amberAccent, size: 34),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'Message Limit Reached',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Detailed Bullet Description
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You've used your 3 message request limit for @$targetUserName.",
                      style: GoogleFonts.outfit(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'To continue chatting, choose one of these:',
                      style: GoogleFonts.outfit(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildOptionBullet('• Wait for $targetUserName to reply.'),
                    _buildOptionBullet('• Become mutual followers for unlimited messaging.'),
                    _buildOptionBullet('• Send a gift worth 2★ or more to unlock 3 additional messages.'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Column(
                children: [
                  // Primary Button: Send a Gift 🎁
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        _showGiftSelector(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.card_giftcard_rounded, size: 20, color: Colors.amberAccent),
                          const SizedBox(width: 8),
                          Text(
                            'Send a Gift 🎁',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Secondary Button: Follow Back / Follow
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () async {
                        Get.back();
                        if (isFollowing) {
                          await UserProfileCacheManager.unfollowUser(targetUserId);
                        } else {
                          await UserProfileCacheManager.followUser(targetUserId);
                        }
                        onFollowUpdated?.call();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isFollowing ? 'Following' : 'Follow Back',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Text button: Maybe Later
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text(
                      'Maybe Later',
                      style: GoogleFonts.outfit(
                        color: AppTheme.textTertiary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: Colors.white.withOpacity(0.8),
          fontSize: 12,
          height: 1.3,
        ),
      ),
    );
  }

  void _showGiftSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SendGiftDialog(
        roomId: 'dm_$conversationId',
        occupiedSeatsCount: 1,
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        onGiftSent: (giftName, giftIcon, giftCost, currency) {
          if (currency == 'gold' && giftCost >= 2) {
            onGiftUnlocked?.call();
          }
        },
      ),
    );
  }
}
