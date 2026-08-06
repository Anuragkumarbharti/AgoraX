import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// ============================================================
//  NovelVideoPreloader — helper for caching and background loading
// ============================================================
class NovelVideoPreloader {
  static const String videoUrl =
      'https://zccrgiplrbeslgpcezul.supabase.co/storage/v1/object/public/entry-effects/novel1.mp4';

  static File? _cachedFile;
  static bool _isPreloaded = false;
  static bool _isPreloading = false;
  static VideoPlayerController? _prewarmedCtrl;

  /// Asynchronously preloads and pre-warms the Novel 1 entry effect video.
  /// Runs in the background and does not block the UI.
  static Future<void> preload({int maxRetries = 3}) async {
    if (_isPreloaded || _isPreloading) return;
    _isPreloading = true;

    // 1. Pre-warm local asset controller for instant <50ms playback
    try {
      if (_prewarmedCtrl == null) {
        final ctrl = VideoPlayerController.asset(
          'assets/entryeffect/novel/novel1.mp4',
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        await ctrl.initialize();
        ctrl.setVolume(0.0);
        ctrl.setLooping(false);
        _prewarmedCtrl = ctrl;
      }
      _isPreloaded = true;
      _isPreloading = false;
      debugPrint('Novel 1 Entry Effect local asset pre-warmed successfully.');
      return;
    } catch (e) {
      debugPrint('Error pre-warming local asset: $e');
    }

    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        final file = await DefaultCacheManager().getSingleFile(videoUrl);
        _cachedFile = file;
        _isPreloaded = true;
        _isPreloading = false;
        debugPrint(
            'Novel 1 Entry Effect video cached successfully: ${file.path}');
        return;
      } catch (e) {
        attempt++;
        debugPrint(
            'Failed to preload entry effect video (attempt $attempt/$maxRetries): $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    _isPreloading = false;
  }

  static VideoPlayerController? consumePrewarmedCtrl() {
    final ctrl = _prewarmedCtrl;
    _prewarmedCtrl = null;
    _isPreloaded = false;
    return ctrl;
  }

  static File? get cachedFile => _cachedFile;
  static bool get isPreloaded => _isPreloaded;
}

// ============================================================
//  EntryParticlePainter — kept for fallback & other components
// ============================================================
class EntryParticlePainter extends CustomPainter {
  final double progress;
  final Color color;
  EntryParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.55)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 12; i++) {
      final double lp = (progress + (i * 0.12)) % 1.0;
      final double x = size.width * lp;
      final double y = (size.height / 2) + 16 * math.sin(lp * 4 * math.pi + i);
      final double r = 1.0 + 2.5 * (1.0 - lp);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant EntryParticlePainter o) => true;
}

// ============================================================
//  NovelEntryAnimation  — Novel Level 1: FULL-SCREEN MP4 VIDEO + OVERLAY
//  All other levels: elegant pill card
// ============================================================
class NovelEntryAnimation extends StatefulWidget {
  final String username;
  final String? avatarUrl;
  final int novelLevel;
  final VoidCallback? onFinished;

  const NovelEntryAnimation({
    Key? key,
    required this.username,
    this.avatarUrl,
    required this.novelLevel,
    this.onFinished,
  }) : super(key: key);

  static OverlayEntry? _activeEntry;

  static void show(
    BuildContext context, {
    required String username,
    String? avatarUrl,
    required int novelLevel,
    required VoidCallback onFinished,
  }) {
    _activeEntry?.remove();
    _activeEntry = null;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => NovelEntryAnimation(
        username: username,
        avatarUrl: avatarUrl,
        novelLevel: novelLevel,
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

  static void dismiss() {
    _activeEntry?.remove();
    _activeEntry = null;
  }

  @override
  State<NovelEntryAnimation> createState() => _NovelEntryAnimationState();
}

class _NovelEntryAnimationState extends State<NovelEntryAnimation>
    with TickerProviderStateMixin {
  // ── Video Player Controller (Novel Level 1) ─────────────────────────────
  VideoPlayerController? _videoCtrl;
  bool _videoInitialized = false;
  bool _isLoading = true;

  // ── Shared controllers ────────────────────────────────────────────────────
  late AnimationController _slideController; // pill cards
  late AnimationController _shineController; // pill shine

  // ── Full-screen controllers (Novel Level 1) ──────────────────────────────
  late AnimationController _masterCtrl;
  late AnimationController _ringCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _breathCtrl;
  late AnimationController _particleCtrl;

  // ── Slide-in card animations ──────────────────────────────────────────────
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _usernameOpacity;
  late Animation<double> _avatarScale;

  // ── Full-screen timeline animations ──────────────────────────────────────
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;
  late Animation<double> _fxAvatarScale;
  late Animation<double> _fxUsernameOpacity;
  late Animation<double> _fxUsernameSlide;

  late List<_NParticle> _particles;
  final _rng = math.Random();

  bool get _isFullScreen => widget.novelLevel == 1;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(45, (_) => _NParticle(_rng));

    // ── Controllers for pill card (all levels except 1) ───────────────────
    _slideController = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this);
    _shineController = AnimationController(
        duration: const Duration(milliseconds: 1800), vsync: this)
      ..repeat();

    _slideAnimation =
        Tween<Offset>(begin: const Offset(-1.3, 0.0), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideController,
                curve: const Interval(0.0, 0.4, curve: Curves.elasticOut)));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _slideController,
            curve: const Interval(0.0, 0.3, curve: Curves.easeIn)));
    _usernameOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _slideController,
            curve: const Interval(0.4, 0.7, curve: Curves.easeIn)));
    _avatarScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0.7, 1.0, curve: Curves.elasticOut)));

    // ── Controllers for full-screen (Novel Level 1) ───────────────────────
    _masterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4800));
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _breathCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4800));

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.0, 0.15, curve: Curves.easeOut)));
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.85, 1.0, curve: Curves.easeIn)));
    _fxAvatarScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _masterCtrl,
            curve: const Interval(0.08, 0.35, curve: Curves.elasticOut)));
    _fxUsernameOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _masterCtrl,
            curve: const Interval(0.28, 0.50, curve: Curves.easeOut)));
    _fxUsernameSlide = Tween<double>(begin: 18.0, end: 0.0).animate(
        CurvedAnimation(
            parent: _masterCtrl,
            curve: const Interval(0.28, 0.50, curve: Curves.easeOut)));

    if (_isFullScreen) {
      _masterCtrl.addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted)
          widget.onFinished?.call();
      });
      _initVideo();
    } else {
      _slideController.forward().then((_) async {
        await Future.delayed(const Duration(milliseconds: 3000));
        if (mounted) {
          _slideController.reverse().then((_) {
            widget.onFinished?.call();
          });
        }
      });
    }
  }

  void _initVideo() async {
    if (!_isFullScreen) return;

    // Render particle layer immediately on frame 0
    _isLoading = false;
    if (mounted) setState(() {});

    VideoPlayerController? ctrl;
    bool success = false;

    // 1. Check pre-warmed local asset controller (Instant 0-10ms)
    try {
      final prewarmed = NovelVideoPreloader.consumePrewarmedCtrl();
      if (prewarmed != null && prewarmed.value.isInitialized) {
        ctrl = prewarmed;
        success = true;
        debugPrint("Novel 1 Entry Effect: Used pre-warmed asset controller.");
      }
    } catch (e) {
      debugPrint("Novel 1 Entry Effect: Error checking pre-warmed controller: $e");
    }

    // 2. Primary source: Direct local asset (<50ms)
    if (!success && mounted) {
      try {
        ctrl = VideoPlayerController.asset(
          'assets/entryeffect/novel/novel1.mp4',
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        await ctrl.initialize();
        success = true;
        debugPrint("Novel 1 Entry Effect: Initialized local asset novel1.mp4.");
      } catch (e) {
        debugPrint("Novel 1 Entry Effect: Error initializing local asset: $e");
      }
    }

    // 3. Secondary source: Cached file fallback
    if (!success && mounted) {
      try {
        File? cachedFile = NovelVideoPreloader.cachedFile;
        if (cachedFile == null || !await cachedFile.exists()) {
          try {
            final fileInfo = await DefaultCacheManager()
                .getFileFromCache(NovelVideoPreloader.videoUrl);
            if (fileInfo != null && await fileInfo.file.exists()) {
              cachedFile = fileInfo.file;
            }
          } catch (_) {}
        }

        if (cachedFile != null && await cachedFile.exists()) {
          ctrl = VideoPlayerController.file(
            cachedFile,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
          await ctrl.initialize();
          success = true;
        }
      } catch (e) {
        debugPrint("Novel 1 Entry Effect: Error initializing cached file: $e");
      }
    }

    // 4. Tertiary source: Network streaming fallback (with 3s timeout)
    if (!success && mounted) {
      try {
        ctrl = VideoPlayerController.networkUrl(
          Uri.parse(NovelVideoPreloader.videoUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        await ctrl.initialize().timeout(const Duration(seconds: 3));
        success = true;
      } catch (e) {
        debugPrint("Novel 1 Entry Effect: Error initializing network URL: $e");
      }
    }

    if (mounted) {
      if (success && ctrl != null) {
        try {
          ctrl.setVolume(0.0);
          ctrl.setLooping(false);
          await ctrl.seekTo(Duration.zero);
          await ctrl.play();

          setState(() {
            _videoCtrl = ctrl;
            _videoInitialized = true;
            _isLoading = false;
          });
        } catch (e) {
          debugPrint("Novel 1 Entry Effect: Error playing video: $e");
          setState(() {
            _videoInitialized = false;
            _isLoading = false;
          });
        }
      } else {
        debugPrint(
            "Novel 1 Entry Effect: All video sources failed. Falling back to particle animation.");
        setState(() {
          _videoInitialized = false;
          _isLoading = false;
        });
      }

      // Start the master timeline regardless
      _masterCtrl.forward();
      _particleCtrl.forward();
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    _slideController.dispose();
    _shineController.dispose();
    _masterCtrl.dispose();
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    _breathCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (widget.novelLevel < 1 || widget.novelLevel > 100)
      return const SizedBox.shrink();
    return _isFullScreen ? _buildFullScreen(context) : _buildPillCard(context);
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD97706).withOpacity(0.35),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'L O A D I N G   E N T R Y',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFD97706),
              letterSpacing: 3,
              decoration: TextDecoration.none,
              shadows: [
                Shadow(color: Color(0xFFD97706), blurRadius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  //  FULL-SCREEN  (Novel Level 1 — Video + Dynamic Overlay)
  // ==========================================================================
  Widget _buildFullScreen(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final avatarR = size.width * 0.155;

    return AnimatedBuilder(
      animation: Listenable.merge(
          [_masterCtrl, _ringCtrl, _pulseCtrl, _breathCtrl, _particleCtrl]),
      builder: (context, _) {
        final mo = (_fadeIn.value * _fadeOut.value).clamp(0.0, 1.0);
        if (mo == 0) return const SizedBox.shrink();

        return Material(
          color: Colors.black
              .withOpacity(0.65), // Dark overlay behind the video/animation
          child: SizedBox.expand(
            child: Opacity(
              opacity: mo,
              child: Stack(
                children: [
                  // 1. Fullscreen MP4 Video Player Layer (novel1.mp4)
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
                    // Particle fallback layer if video is loading
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _NParticlePainter(
                          particles: _particles,
                          progress: _particleCtrl.value,
                          masterOpacity: mo,
                          cx: cx,
                          cy: cy - size.height * 0.07,
                        ),
                      ),
                    ),

                  // 2. Anti-gravity particles overlay for extra depth
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _NParticlePainter(
                        particles: _particles,
                        progress: _particleCtrl.value,
                        masterOpacity: mo * 0.6,
                        cx: cx,
                        cy: cy - size.height * 0.07,
                      ),
                    ),
                  ),

                  // 3. Glow rings around avatar
                  ..._buildGlowRings(cx, cy - size.height * 0.07, avatarR, mo),

                  // 4. Avatar Circle
                  Positioned(
                    left: cx - avatarR,
                    top: cy - size.height * 0.07 - avatarR,
                    child: Transform.scale(
                      scale: _fxAvatarScale.value,
                      child: _buildAvatarCircle(avatarR * 2),
                    ),
                  ),

                  // 5. Username Overlay
                  Positioned(
                    top: cy - size.height * 0.07 + avatarR + 20,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: _fxUsernameOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _fxUsernameSlide.value),
                        child: _buildUsername(),
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

  List<Widget> _buildGlowRings(double cx, double cy, double baseR, double mo) {
    const specs = [
      (1.6, 0.9, 0.18, 0xFFD97706),
      (2.2, 0.65, 0.28, 0xFFFBBF24),
      (3.0, 0.42, 0.42, 0xFFEAB308),
    ];
    return specs.asMap().entries.map((e) {
      final i = e.key;
      final r = baseR * e.value.$1;
      final alpha = e.value.$2;
      final w = e.value.$3;
      final col = Color(e.value.$4);
      final rot =
          _ringCtrl.value * (1.0 + i * 0.4) * 2 * math.pi + i * math.pi / 3;
      final pulse = 0.7 + 0.3 * _pulseCtrl.value;
      return Positioned(
        left: cx - r,
        top: cy - r,
        child: Transform.rotate(
          angle: rot,
          child: Container(
            width: r * 2,
            height: r * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: col.withOpacity(alpha * pulse * mo), width: w),
              boxShadow: [
                BoxShadow(
                    color: col.withOpacity(0.12 * pulse * mo),
                    blurRadius: 10,
                    spreadRadius: 2)
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildAvatarCircle(double size) {
    final pulse = 0.75 + 0.25 * _pulseCtrl.value;
    final glow = 8.0 + 6.0 * _pulseCtrl.value;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(colors: [
          Color(0xFFD97706),
          Color(0xFFFBBF24),
          Color(0xFFEAB308),
          Color(0xFFFBBF24),
          Color(0xFFD97706),
        ]),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFD97706).withOpacity(0.55 * pulse),
              blurRadius: glow,
              spreadRadius: 3),
          BoxShadow(
              color: const Color(0xFFFBBF24).withOpacity(0.22 * pulse),
              blurRadius: glow * 2.5),
        ],
      ),
      padding: const EdgeInsets.all(3.5),
      child: ClipOval(
        child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
            ? Image.network(widget.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(size))
            : _placeholder(size),
      ),
    );
  }

  Widget _placeholder(double s) => Container(
        color: const Color(0xFF1C1917),
        child:
            Icon(Icons.person, color: const Color(0xFFD97706), size: s * 0.48),
      );

  Widget _buildUsername() {
    final breathScale = 1.0 + 0.014 * _breathCtrl.value;
    final breathOpacity = 0.85 + 0.15 * _breathCtrl.value;
    return Transform.scale(
      scale: breathScale,
      child: Opacity(
        opacity: breathOpacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              _GoldLine(),
              SizedBox(width: 8),
              Text('✦',
                  style: TextStyle(
                      color: Color(0xFFD97706),
                      fontSize: 10,
                      decoration: TextDecoration.none)),
              SizedBox(width: 8),
              _GoldLine(),
            ]),
            const SizedBox(height: 6),
            Text(
              widget.username,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 2.5,
                decoration: TextDecoration.none,
                shadows: [
                  Shadow(color: Color(0xFFD97706), blurRadius: 14),
                  Shadow(color: Color(0xFFFBBF24), blurRadius: 28),
                  Shadow(color: Colors.white, blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'N O V E L   1',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: Color(0xFFD97706),
                letterSpacing: 5,
                decoration: TextDecoration.none,
                shadows: [Shadow(color: Color(0xFFD97706), blurRadius: 8)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  //  PILL CARD  (Novel Level 2–100)
  // ==========================================================================
  Widget _buildPillCard(BuildContext context) {
    final accentColor = _getAccentColor();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 60,
          child: Stack(children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: Colors.black.withOpacity(0.85),
                border: Border.all(
                    color: accentColor.withOpacity(0.65),
                    width: widget.novelLevel >= 51 ? 2.0 : 1.3),
                boxShadow: [
                  BoxShadow(
                      color: accentColor.withOpacity(0.35),
                      blurRadius: 14,
                      spreadRadius: 2)
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Stack(children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _shineController,
                      builder: (_, __) => CustomPaint(
                        painter: EntryParticlePainter(
                            progress: _shineController.value,
                            color: accentColor),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 12, right: 24, top: 4, bottom: 4),
                    child: Row(children: [
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
                                    image: NetworkImage(widget.avatarUrl!),
                                    fit: BoxFit.cover)
                                : null,
                            gradient: (widget.avatarUrl == null ||
                                    widget.avatarUrl!.isEmpty)
                                ? SweepGradient(colors: [
                                    accentColor,
                                    Colors.black,
                                    accentColor
                                  ])
                                : null,
                          ),
                          child: (widget.avatarUrl == null ||
                                  widget.avatarUrl!.isEmpty)
                              ? Center(
                                  child: Text(
                                      widget.novelLevel == 100 ? '👑' : '☄️',
                                      style: const TextStyle(fontSize: 22)))
                              : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: FadeTransition(
                          opacity: _usernameOpacity,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.username,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: accentColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(_getJoinMessage(),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Color _getAccentColor() {
    if (widget.novelLevel <= 10) return const Color(0xFFEF4444);
    if (widget.novelLevel <= 20) return const Color(0xFF3B82F6);
    if (widget.novelLevel <= 30) return const Color(0xFF10B981);
    if (widget.novelLevel <= 40) return const Color(0xFFF59E0B);
    if (widget.novelLevel <= 50) return const Color(0xFFD946EF);
    if (widget.novelLevel <= 70) return const Color(0xFFF97316);
    if (widget.novelLevel <= 99) return const Color(0xFF8B5CF6);
    return const Color(0xFFFFD700);
  }

  String _getJoinMessage() {
    if (widget.novelLevel == 100) return 'Ascended to the Room Divinely! ☄️';
    if (widget.novelLevel >= 71) return 'Materialized into the Room! ✨';
    if (widget.novelLevel >= 41) return 'Manifested into the Room! 🌟';
    return 'Has entered the room.';
  }
}

class _GoldLine extends StatelessWidget {
  const _GoldLine();
  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 1,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent,
            Color(0xFFD97706),
            Colors.transparent
          ]),
        ),
      );
}

class _NParticle {
  final math.Random rng;
  late double startX, startY, size, speed, opacity, phase, wobble;
  late bool isOrbiter;

  _NParticle(this.rng) {
    startX = rng.nextDouble();
    startY = rng.nextDouble();
    size = 1.5 + rng.nextDouble() * 2.5;
    speed = 0.05 + rng.nextDouble() * 0.12;
    opacity = 0.3 + rng.nextDouble() * 0.55;
    phase = rng.nextDouble() * math.pi * 2;
    wobble = 8 + rng.nextDouble() * 20;
    isOrbiter = rng.nextDouble() < 0.25;
  }
}

class _NParticlePainter extends CustomPainter {
  final List<_NParticle> particles;
  final double progress, masterOpacity, cx, cy;

  _NParticlePainter({
    required this.particles,
    required this.progress,
    required this.masterOpacity,
    required this.cx,
    required this.cy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    for (final pt in particles) {
      final t = (progress + pt.phase / (math.pi * 2)) % 1.0;
      double px, py;

      if (pt.isOrbiter) {
        final r = 58 + pt.wobble;
        final angle = t * math.pi * 2 * pt.speed * 8 + pt.phase;
        px = cx + r * math.cos(angle);
        py = cy + r * math.sin(angle) * 0.55;
      } else {
        final riseT = (t * pt.speed * 12) % 1.0;
        px = pt.startX * size.width +
            math.sin(riseT * math.pi * 2 + pt.phase) * pt.wobble;
        py = size.height - size.height * riseT * 0.85 - pt.startY * 100;
      }

      final pOp = pt.opacity * masterOpacity;
      if (pOp <= 0) continue;

      final shimmer = (math.sin(progress * math.pi * 4 + pt.phase) + 1) / 2;
      final col =
          Color.lerp(const Color(0xFFD97706), const Color(0xFFFBBF24), shimmer)!
              .withOpacity(pOp);

      p.color = col;
      canvas.drawCircle(Offset(px, py), pt.size, p);
      p.color = col.withOpacity(pOp * 0.28);
      canvas.drawCircle(Offset(px, py), pt.size * 2.5, p);
    }
  }

  @override
  bool shouldRepaint(covariant _NParticlePainter o) => true;
}
