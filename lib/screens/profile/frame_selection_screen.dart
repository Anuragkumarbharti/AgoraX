import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:creania/core/theme.dart';
import '../../widgets/common/optimized_image.dart';
import '../../services/user/customization_controller.dart';
import '../../widgets/memberships/novel_avatar_decorator.dart';
import '../../services/user/user_profile_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FrameSelectionScreen extends StatefulWidget {
  const FrameSelectionScreen({Key? key}) : super(key: key);

  @override
  State<FrameSelectionScreen> createState() => _FrameSelectionScreenState();
}

class _FrameSelectionScreenState extends State<FrameSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  bool _isEquipped = false;

  CustomizationController get _custCtrl => Get.find<CustomizationController>();

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _isEquipped = _custCtrl.activeFrame.value == 'Novel Level 1';
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _toggleEquip() async {
    if (_isEquipped) {
      await _custCtrl.equipItem('Avatar Frame', 'Normal');
      if (mounted) setState(() => _isEquipped = false);
    } else {
      await _custCtrl.equipItem('Avatar Frame', 'Novel Level 1');
      if (mounted) setState(() => _isEquipped = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Avatar Frames',
          style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          _buildPreviewSection(context),
          const SizedBox(height: 24),
          _buildFrameCard(context),
          const Spacer(),
          _buildEquipButton(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final u = UserProfileCacheManager.rxCache[uid];
    final avatarUrl = u?.avatar ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFD97706).withOpacity(0.10),
            context.scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _glowController,
            builder: (ctx, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 152,
                    height: 152,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withOpacity(
                              0.22 + 0.18 * _glowController.value),
                          blurRadius: 28 + 12 * _glowController.value,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  NovelAvatarDecorator(
                    level: 1,
                    size: 136,
                    child: avatarUrl.isNotEmpty
                        ? OptimizedImage(
                            imageUrl: avatarUrl,
                            preset: MediaSizePreset.md,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  context.primaryColor.withOpacity(0.4),
                                  AppTheme.secondaryColor.withOpacity(0.3),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Text('👤', style: TextStyle(fontSize: 48)),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Novel Level 1',
            style: TextStyle(
                color: Color(0xFFD97706),
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          Text(
            'Royal golden crown • Exclusive frame',
            style: TextStyle(color: context.caption, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isEquipped
              ? const Color(0xFFD97706).withOpacity(0.10)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                _isEquipped ? const Color(0xFFD97706) : context.borderColor,
            width: _isEquipped ? 2 : 1,
          ),
          boxShadow: _isEquipped
              ? [
                  BoxShadow(
                      color: const Color(0xFFD97706).withOpacity(0.18),
                      blurRadius: 16,
                      spreadRadius: 2)
                ]
              : null,
        ),
        child: Row(
          children: [
            // Frame thumbnail
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [Color(0xFFD97706), Color(0xFFFBBF24), Color(0xFFD97706)],
                    ),
                  ),
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.scaffoldBackgroundColor,
                  ),
                ),
                Image.asset(
                  'assets/avtarframes/novel/novel_1.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Text('👑', style: TextStyle(fontSize: 32)),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Novel Level 1',
                        style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  const Color(0xFFD97706).withOpacity(0.4)),
                        ),
                        child: const Text('Rare',
                            style: TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Royal golden crown with "Novel 1" badge',
                    style: TextStyle(color: context.caption, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Text('✨', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 4),
                      Text(
                        'Free for all users',
                        style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_isEquipped)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: Color(0xFFD97706), shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isEquipped
                ? context.surfaceColor
                : const Color(0xFFD97706),
            foregroundColor:
                _isEquipped ? const Color(0xFFD97706) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color: const Color(0xFFD97706),
                  width: _isEquipped ? 2 : 0),
            ),
            elevation: _isEquipped ? 0 : 4,
            shadowColor: const Color(0xFFD97706).withOpacity(0.4),
          ),
          onPressed: _toggleEquip,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isEquipped
                    ? Icons.highlight_remove_rounded
                    : Icons.auto_fix_high_rounded,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                _isEquipped ? 'Unequip Frame' : '✨ Equip Novel Level 1',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Restore Guide ────────────────────────────────────────────────────────────
// To restore all frames later:
//   1. In customization_controller.dart → set 'isAvailable': true for each frame
//   2. Add back _frames list entries in this file
//   3. Restore category filter tabs
//   4. In custom_avatar_frame.dart → restore VipAvatarDecorator routing
// ─────────────────────────────────────────────────────────────────────────────
