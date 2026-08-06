import 'package:flutter/material.dart';
import '../../models/room/room_background_model.dart';
import '../../services/room/room_background_controller.dart';

class RoomDynamicBackgroundWidget extends StatefulWidget {
  final RoomBackgroundItem background;
  final Widget? child;

  const RoomDynamicBackgroundWidget({
    Key? key,
    required this.background,
    this.child,
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

  @override
  Widget build(BuildContext context) {
    final bg = widget.background;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: Full-Screen Background Image with 250ms Smooth Fade Animation
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: KeyedSubtree(
            key: ValueKey(bg.id),
            child: SizedBox.expand(
              child: Image.asset(
                bg.assetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to Theme 1 if image fails to load
                  return Image.asset(
                    RoomBackgroundCatalog.defaultBackground.assetPath,
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
          ),
        ),

        // Layer 2: Readability Gradient Scrim Overlay
        // Top area darker for room information, bottom area darker for chat/controls,
        // center clean for seat avatars.
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.22, 0.65, 1.0],
                  colors: [
                    Color(0x99000000), // Top dark scrim for title bar readability
                    Color(0x1F000000), // Middle upper subtle tint
                    Color(0x29000000), // Middle lower clean area for seats
                    Color(0xCC050711), // Bottom dark scrim for chat & controls
                  ],
                ),
              ),
            ),
          ),
        ),

        // Layer 3: Optional Child Content Overlay
        if (widget.child != null) widget.child!,
      ],
    );
  }
}
