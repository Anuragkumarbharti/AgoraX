import 'package:flutter/material.dart';
import '../../models/room/room_background_model.dart';
import '../../services/room/room_background_controller.dart';

/// Layer 0 (Background Layer) & Layer 1 (Theme Ambient Scrim) widget.
/// 
/// Strictly enforces Layer 0 WEBP (Static & Animated WEBP) / GIF / Lottie / Video rules:
/// 1. ALWAYS stays at the absolute bottom of the stack (Layer 0).
/// 2. NEVER overlaps room UI, seats, avatars, or gift animations.
/// 3. NEVER receives touch events (wrapped in IgnorePointer ignoring: true).
/// 4. Clipped to room bounds via ClipRect.
/// 5. Isolated RepaintBoundary prevents WEBP animation repaints from invalidating upper layers.
class RoomDynamicBackgroundWidget extends StatefulWidget {
  final RoomBackgroundItem background;
  final Widget? child;
  final bool showScrimOverlay;

  const RoomDynamicBackgroundWidget({
    Key? key,
    required this.background,
    this.child,
    this.showScrimOverlay = true,
  }) : super(key: key);

  @override
  State<RoomDynamicBackgroundWidget> createState() =>
      _RoomDynamicBackgroundWidgetState();
}

class _RoomDynamicBackgroundWidgetState
    extends State<RoomDynamicBackgroundWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && RoomBackgroundController.to != null) {
        RoomBackgroundController.to.preloadRoomBackgrounds(context);
      }
    });
  }

  Widget _buildProceduralClassicBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.30, 0.70, 1.0],
          colors: [
            Color(0xFF0F172A),
            Color(0xFF090D16),
            Color(0xFF0D111D),
            Color(0xFF050711),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x3306B6D4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -100,
            child: Container(
              width: 380,
              height: 380,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x2B8B5CF6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds Layer 0 WEBP / Image / Animated Asset Canvas
  Widget _buildBackgroundAsset(RoomBackgroundItem bg) {
    if (bg.assetPath.isEmpty || bg.id == 'theme_default') {
      return _buildProceduralClassicBackground();
    }

    return Image.asset(
      bg.assetPath,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        return _buildProceduralClassicBackground();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.background;
    debugPrint('[BACKGROUND] WebP rebuild (${bg.id})');

    return IgnorePointer(
      ignoring: true,
      child: ClipRect(
        child: RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── LAYER 0: WEBP / Image / Video Background Canvas (ALWAYS LOWEST) ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                child: KeyedSubtree(
                  key: ValueKey('bg_webp_layer0_${bg.id}'),
                  child: SizedBox.expand(
                    child: _buildBackgroundAsset(bg),
                  ),
                ),
              ),

              // ── LAYER 1: Readability Scrim Gradient Overlay ──
              if (widget.showScrimOverlay)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.22, 0.65, 1.0],
                        colors: [
                          const Color(0x99000000), // Top header dark scrim
                          const Color(0x1F000000), // Upper middle subtle tint
                          Color(0x29000000).withOpacity(bg.overlayDarkness.clamp(0.1, 0.8)), // Clean seats stage area
                          const Color(0xCC050711), // Bottom chat & controls dark scrim
                        ],
                      ),
                    ),
                  ),
                ),

              // Optional Child Content Overlay
              if (widget.child != null) widget.child!,
            ],
          ),
        ),
      ),
    );
  }
}
