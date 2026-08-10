import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../services/memberships/entry_effect_manager.dart';
import './vip_badge_widget.dart';

// ============================================================
//  VipVideoPreloader — helper for caching and pre-warming VIP video
// ============================================================
class VipVideoPreloader {
  static VideoPlayerController? _prewarmedCtrl;
  static bool _isPreloaded = false;
  static bool _isPreloading = false;

  /// Asynchronously preloads and pre-warms the VIP entry effect video asset.
  static Future<void> preload() async {
    if (_isPreloaded || _isPreloading) return;
    _isPreloading = true;

    try {
      if (_prewarmedCtrl == null) {
        final ctrl = VideoPlayerController.asset(
          'assets/entryeffect/vip/vip2.mov',
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        await ctrl.initialize();
        ctrl.setVolume(0.0);
        ctrl.setLooping(false);
        _prewarmedCtrl = ctrl;
      }
      _isPreloaded = true;
      _isPreloading = false;
      debugPrint('VIP 2 Entry Effect local video asset pre-warmed successfully.');
      return;
    } catch (e) {
      debugPrint('Error pre-warming VIP 2 local video asset: $e');
      _isPreloading = false;
    }
  }

  static VideoPlayerController? consumePrewarmedCtrl() {
    final ctrl = _prewarmedCtrl;
    _prewarmedCtrl = null;
    _isPreloaded = false;
    return ctrl;
  }
}

class EntryParticlePainter extends CustomPainter {
  final double progress;
  final Color color;

  EntryParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 10; i++) {
      final double localProgress = (progress + (i * 0.15)) % 1.0;
      final double x = size.width * localProgress;
      final double y =
          (size.height / 2) + 14 * math.sin(localProgress * 3 * math.pi + i);
      final double radius = 1.5 + 2.0 * (1.0 - localProgress);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant EntryParticlePainter oldDelegate) => true;
}

class VipEntryAnimation extends StatefulWidget {
  final String username;
  final String? avatarUrl;
  final int vipLevel;
  final VoidCallback? onFinished;

  const VipEntryAnimation({
    Key? key,
    required this.username,
    this.avatarUrl,
    required this.vipLevel,
    this.onFinished,
  }) : super(key: key);

  static OverlayEntry? _activeEntry;

  static void show(
    BuildContext context, {
    required String username,
    String? avatarUrl,
    required int vipLevel,
    required VoidCallback onFinished,
  }) {
    _activeEntry?.remove();
    _activeEntry = null;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => VipEntryAnimation(
        username: username,
        avatarUrl: avatarUrl,
        vipLevel: vipLevel,
        onFinished: () {
          entry.remove();
          if (_activeEntry == entry) {
            _activeEntry = null;
          }
          onFinished();
        },
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
  }

  @override
  State<VipEntryAnimation> createState() => _VipEntryAnimationState();
}

class _VipEntryAnimationState extends State<VipEntryAnimation>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _shineController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Staggered Opacities & Scales
  late Animation<double> _usernameOpacity;
  late Animation<double> _avatarScale;

  // Video Controller for Full-Screen VIP 2 Entry Effect (vip2.mov)
  VideoPlayerController? _videoCtrl;
  bool _videoInitialized = false;
  late AnimationController _masterCtrl;
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;

  bool get _isFullScreen => widget.vipLevel == 2;

  // ── Diagnostic timing fields ──
  int? _startTimestampMs;
  int? _slideForwardCalledMs;
  int? _delayStartMs;
  int? _delayEndMs;
  int? _reverseCalledMs;

  @override
  void initState() {
    super.initState();
    _startTimestampMs = DateTime.now().millisecondsSinceEpoch;
    debugPrint('╔══════════════════════════════════════════════════════╗');
    debugPrint('[ENTRY_TIMING] EFFECT START          : $_startTimestampMs ms');
    debugPrint('[ENTRY_TIMING] IS FULLSCREEN          : $_isFullScreen');
    debugPrint('[ENTRY_TIMING] SLIDE CTRL DURATION    : 1400ms (hardcoded)');
    debugPrint('[ENTRY_TIMING] MASTER CTRL DURATION   : ${_isFullScreen ? "8000ms" : "N/A (pill card)"}');
    debugPrint('[ENTRY_TIMING] PILL TOTAL (EXPECTED)  : ${!_isFullScreen ? "1400 + 5600 + 1400 = 8400ms" : "N/A"}');
    debugPrint('[ENTRY_TIMING] USER                   : ${widget.username} | VIP: ${widget.vipLevel}');
    debugPrint('╚══════════════════════════════════════════════════════╝');
    debugPrint('[VIP_ENTRY] START | Configured Duration: 8000ms | user=${widget.username} | vipLevel=${widget.vipLevel}');
    debugPrint('[VIP_ENTRY] CONTROLLER CREATED');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[VIP_ENTRY] FIRST FRAME | user=${widget.username}');
    });

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _shineController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.2, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    ));

    _usernameOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.4, 0.7, curve: Curves.easeIn),
    ));

    _avatarScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.7, 1.0, curve: Curves.elasticOut),
    ));

    if (_isFullScreen) {
      _masterCtrl = AnimationController(
        duration: const Duration(milliseconds: 8000),
        vsync: this,
      );

      _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _masterCtrl,
          curve: const Interval(0.0, 0.12, curve: Curves.easeOut),
        ),
      );

      _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _masterCtrl,
          curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
        ),
      );

      _masterCtrl.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          debugPrint('[Lifecycle] VIP Entry Animation Completed (FullScreen): user=${widget.username}');
          widget.onFinished?.call();
        }
      });

      _initVideo();
    } else {
      debugPrint('[Lifecycle] VIP Entry Animation Started (Pill Card): user=${widget.username}');
      // Slide in (1.2s), pause (5.6s), then slide out (1.2s) for pill card = 8.0 SECONDS
      _slideForwardCalledMs = DateTime.now().millisecondsSinceEpoch;
      debugPrint('[ENTRY_TIMING] SLIDE FORWARD() CALLED : $_slideForwardCalledMs ms | elapsed: ${_slideForwardCalledMs! - (_startTimestampMs ?? _slideForwardCalledMs!)}ms since start');
      _slideController.forward().then((_) async {
        final slideEndMs = DateTime.now().millisecondsSinceEpoch;
        debugPrint('[ENTRY_TIMING] SLIDE FORWARD DONE     : $slideEndMs ms | elapsed: ${slideEndMs - (_startTimestampMs ?? slideEndMs)}ms | slide value: ${_slideController.value} | status: ${_slideController.status}');
        _delayStartMs = DateTime.now().millisecondsSinceEpoch;
        debugPrint('[ENTRY_TIMING] DELAY 5600ms START     : $_delayStartMs ms');
        await Future.delayed(const Duration(milliseconds: 5600));
        _delayEndMs = DateTime.now().millisecondsSinceEpoch;
        final actualDelay = _delayEndMs! - _delayStartMs!;
        debugPrint('[ENTRY_TIMING] DELAY 5600ms DONE      : $_delayEndMs ms | actual delay: ${actualDelay}ms (expected 5600ms)');
        if (mounted) {
          _reverseCalledMs = DateTime.now().millisecondsSinceEpoch;
          debugPrint('[ENTRY_TIMING] SLIDE REVERSE() CALLED : $_reverseCalledMs ms | total elapsed: ${_reverseCalledMs! - (_startTimestampMs ?? _reverseCalledMs!)}ms');
          _slideController.reverse().then((_) {
            final finishedMs = DateTime.now().millisecondsSinceEpoch;
            final totalMs = finishedMs - (_startTimestampMs ?? finishedMs);
            debugPrint('╔══════════════════════════════════════════════════════╗');
            debugPrint('[ENTRY_TIMING] ON_FINISHED CALLED     : $finishedMs ms');
            debugPrint('[ENTRY_TIMING] TOTAL ACTUAL PLAYBACK  : ${totalMs}ms (expected ~8400ms)');
            debugPrint('[ENTRY_TIMING] SLIDE VALUE AT END      : ${_slideController.value} | status: ${_slideController.status}');
            debugPrint('╚══════════════════════════════════════════════════════╝');
            debugPrint('[Lifecycle] VIP Entry Animation Completed (Pill Card): user=${widget.username}');
            widget.onFinished?.call();
          });
        } else {
          final disposedMs = DateTime.now().millisecondsSinceEpoch;
          debugPrint('[ENTRY_TIMING] !!! WIDGET UNMOUNTED before reverse !!! disposed at ${disposedMs}ms | elapsed: ${disposedMs - (_startTimestampMs ?? disposedMs)}ms');
        }
      });
    }
  }

  void _initVideo() async {
    if (!_isFullScreen) return;

    final ctrl = await EntryEffectManager.instance.acquireVideoController(
      'assets/entryeffect/vip/vip2.mov',
    );

    if (mounted) {
      if (ctrl != null) {
        try {
          _videoCtrl = ctrl;
          await ctrl.seekTo(Duration.zero);
          await ctrl.play();
          if (mounted) {
            setState(() {
              _videoInitialized = true;
            });
          }
        } catch (e) {
          debugPrint('VIP Entry Effect play error: $e');
          if (mounted) {
            setState(() {
              _videoInitialized = false;
            });
          }
        }
      }
      _masterCtrl.reset();
      _masterCtrl.forward();
    }
  }

  @override
  void dispose() {
    debugPrint('[VIP_ENTRY] WIDGET DISPOSE | user=${widget.username}');
    if (_videoCtrl != null) {
      EntryEffectManager.instance.releaseVideoController(_videoCtrl);
      _videoCtrl = null;
    }
    if (_isFullScreen) {
      _masterCtrl.dispose();
    }
    _slideController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  Color _getVipAccentColor() {
    switch (widget.vipLevel) {
      case 1:
        return const Color(0xFF2563EB); // Royal Blue
      case 2:
        return const Color(0xFF8B5CF6); // Purple
      case 3:
        return const Color(0xFFFFD700); // Gold
      case 4:
        return Colors.white; // Diamond
      case 5:
        return const Color(0xFF06B6D4); // Crystal Cyan
      case 6:
        return const Color(0xFFEC4899); // Rainbow Pink/Orange
      case 7:
        return const Color(0xFFD4AF37); // Legendary Gold
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[VIP_ENTRY] WIDGET REBUILD | user=${widget.username}');
    if (widget.vipLevel < 1 || widget.vipLevel > 7) {
      return const SizedBox.shrink();
    }

    return _isFullScreen ? _buildFullScreen(context) : _buildPillCard(context);
  }

  // ==========================================================================
  //  FULL-SCREEN VIP VIDEO ENTRY (Level 2: vip2.mov)
  // ==========================================================================
  Widget _buildFullScreen(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final accentColor = _getVipAccentColor();

    return AnimatedBuilder(
      animation: _masterCtrl,
      builder: (context, _) {
        final mo = (_fadeIn.value * _fadeOut.value).clamp(0.0, 1.0);
        if (mo == 0) return const SizedBox.shrink();

        return Material(
          color: Colors.black.withOpacity(0.65),
          child: SizedBox.expand(
            child: Opacity(
              opacity: mo,
              child: Stack(
                children: [
                  // 1. Fullscreen MP4/MOV Video Layer (vip2.mov)
                  if (_videoInitialized && _videoCtrl != null)
                    Positioned.fill(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoCtrl!.value.size.width > 0
                              ? _videoCtrl!.value.size.width
                              : size.width,
                          height: _videoCtrl!.value.size.height > 0
                              ? _videoCtrl!.value.size.height
                              : size.height,
                          child: VideoPlayer(_videoCtrl!),
                        ),
                      ),
                    )
                  else
                    // Fallback animated particles background
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _shineController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: EntryParticlePainter(
                              progress: _shineController.value,
                              color: accentColor,
                            ),
                          );
                        },
                      ),
                    ),

                  // 2. VIP User Card Overlay Details
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: accentColor.withOpacity(0.8),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // User Avatar
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: accentColor, width: 2),
                              image: widget.avatarUrl != null &&
                                      widget.avatarUrl!.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(widget.avatarUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: widget.avatarUrl == null ||
                                    widget.avatarUrl!.isEmpty
                                ? const Center(
                                    child: Text(
                                      '👑',
                                      style: TextStyle(fontSize: 28),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),

                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              VipBadgeWidget(
                                  level: widget.vipLevel, fontSize: 11),
                              const SizedBox(width: 8),
                              ShaderMask(
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    colors: [Colors.white, accentColor],
                                  ).createShader(bounds);
                                },
                                child: Text(
                                  widget.username,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          Text(
                            'Has entered the room as VIP 2! 👑',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  //  PILL CARD (Standard VIP Entrance Card)
  // ==========================================================================
  Widget _buildPillCard(BuildContext context) {
    final accentColor = _getVipAccentColor();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 60,
          child: Stack(
            children: [
              // 1. Background Card Glassmorphism
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.black.withOpacity(0.85),
                  border: Border.all(
                    color: accentColor.withOpacity(0.6),
                    width: widget.vipLevel >= 6 ? 1.8 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    children: [
                      // Particles background animation
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _shineController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: EntryParticlePainter(
                                progress: _shineController.value,
                                color: accentColor,
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 12, right: 24, top: 4, bottom: 4),
                        child: Row(
                          children: [
                            // Avatar Circle
                            ScaleTransition(
                              scale: _avatarScale,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: accentColor.withOpacity(0.6),
                                      width: 1.5),
                                  image: widget.avatarUrl != null &&
                                          widget.avatarUrl!.isNotEmpty
                                      ? DecorationImage(
                                          image:
                                              NetworkImage(widget.avatarUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  gradient: widget.avatarUrl == null ||
                                          widget.avatarUrl!.isEmpty
                                      ? SweepGradient(
                                          colors: [
                                            accentColor,
                                            Colors.black,
                                            accentColor,
                                          ],
                                        )
                                      : null,
                                ),
                                child: widget.avatarUrl == null ||
                                        widget.avatarUrl!.isEmpty
                                    ? const Center(
                                        child: Text(
                                          '🌟',
                                          style: TextStyle(fontSize: 22),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Text Info (Faded in after slide in)
                            Expanded(
                              child: FadeTransition(
                                opacity: _usernameOpacity,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        VipBadgeWidget(
                                            level: widget.vipLevel,
                                            fontSize: 10),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ShaderMask(
                                            shaderCallback: (bounds) {
                                              return LinearGradient(
                                                colors: widget.vipLevel >= 6
                                                    ? const [
                                                        Color(0xFFFF007F),
                                                        Color(0xFFFFBF00),
                                                        Color(0xFF00F0FF),
                                                      ]
                                                    : [
                                                        Colors.white,
                                                        accentColor
                                                      ],
                                              ).createShader(bounds);
                                            },
                                            child: Text(
                                              widget.username,
                                              style: GoogleFonts.outfit(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.vipLevel == 7
                                          ? 'Entered the Room Legendarily! 👑'
                                          : 'Has entered the room.',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Animated Shine Sweeper
              AnimatedBuilder(
                animation: _shineController,
                builder: (context, child) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: FractionallySizedBox(
                      widthFactor: 1.0,
                      heightFactor: 1.0,
                      child: ShaderMask(
                        shaderCallback: (bounds) {
                          final double slideVal =
                              _shineController.value * 2 - 0.5;
                          return LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: [
                              math.max(0.0, slideVal - 0.2),
                              math.max(0.0, slideVal),
                              math.min(1.0, slideVal + 0.2),
                            ],
                            colors: [
                              Colors.transparent,
                              accentColor.withOpacity(0.4),
                              Colors.transparent,
                            ],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcATop,
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

