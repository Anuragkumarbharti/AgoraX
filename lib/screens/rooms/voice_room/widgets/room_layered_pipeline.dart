import 'package:flutter/material.dart';

/// Production-Grade 8-Layered Rendering System for Creania Voice Rooms (StarMaker Architecture).
/// Enforces strict Z-Index rendering hierarchy from Bottom (Layer 0) to Top (Layer 7):
/// 
/// Layer 0: Background Layer (Static/Animated Image, GIF, Lottie, Video, Gradient) - ALWAYS Lowest
/// Layer 1: Room Decoration & Ambient Layer (Theme Wallpaper, Light Ambient Scrims)
/// Layer 2: Seats & Stage Base Layer (Seat Grids, Locked Seat Icons, Speaking Glow Ripples)
/// Layer 3: User Avatars Layer (Avatars, VIP Frames, Username, Badges, Mic Icons)
/// Layer 4: Floating Room UI Layer (Top Header Bar, Bottom Controls Dock, Chat Stream, Arena Panels)
/// Layer 5: Gift Animations Layer (Flying Gifts, Combo Banners, Gift Particles - Above seats & avatars)
/// Layer 6: Entry Effects Layer (VIP Entry, Novel Entry, Vehicle/Castle/Dragon Entry - Above gifts)
/// Layer 7: Global Effects Layer (Confetti, Screen Flash, Celebration, Network Disconnect Overlay)
class RoomLayeredPipeline extends StatelessWidget {
  final Widget layer0Background;
  final Widget? layer1Decoration;
  final Widget layer4FloatingUI;
  final Widget? layer5Gifts;
  final Widget? layer6Entry;
  final Widget? layer7Global;

  const RoomLayeredPipeline({
    Key? key,
    required this.layer0Background,
    this.layer1Decoration,
    required this.layer4FloatingUI,
    this.layer5Gifts,
    this.layer6Entry,
    this.layer7Global,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── LAYER 0: Background Layer (ALWAYS LOWEST) ──
        // - Isolated in RepaintBoundary to prevent room UI repaints
        // - IgnorePointer guarantees zero touch event interference
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: RepaintBoundary(
              child: layer0Background,
            ),
          ),
        ),

        // ── LAYER 1: Room Decoration & Ambient Scrim Layer ──
        if (layer1Decoration != null)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: RepaintBoundary(
                child: layer1Decoration!,
              ),
            ),
          ),

        // ── LAYER 2, 3 & 4: Stage Seats, Avatars & Interactive Floating Room UI ──
        // Layer 2 (Seats Grid & Glow), Layer 3 (Avatars & VIP Frames), and Layer 4 (Header, Chat, Dock)
        // are cleanly arranged within the interactive UI container.
        Positioned.fill(
          child: layer4FloatingUI,
        ),

        // ── LAYER 5: Gift Animations Layer (ALWAYS ABOVE SEATS, AVATARS & UI) ──
        // Flying gifts, combo banners, particles, trail paths, and explosions.
        // Wrapped in IgnorePointer so user touches pass through seamlessly to UI below.
        if (layer5Gifts != null)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: RepaintBoundary(
                child: layer5Gifts!,
              ),
            ),
          ),

        // ── LAYER 6: Entry Effects Layer (ALWAYS ABOVE GIFTS) ──
        // VIP Entry, Novel Entry, Vehicle/Castle/Dragon Entry banners & animations.
        if (layer6Entry != null)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: RepaintBoundary(
                child: layer6Entry!,
              ),
            ),
          ),

        // ── LAYER 7: Global Effects Layer (HIGHEST LAYER) ──
        // Fireworks, Confetti, Victory Screen Flash, and Disconnect/Kick Overlays.
        if (layer7Global != null)
          Positioned.fill(
            child: RepaintBoundary(
              child: layer7Global!,
            ),
          ),
      ],
    );
  }
}
