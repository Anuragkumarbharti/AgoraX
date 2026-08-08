import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Novel Level 1 Entry Effect — Full-screen transparent Flutter animation.
/// Replaces the video file approach. True transparent background,
/// anti-gravity particles, golden glow rings, dynamic avatar + username.
///
/// Usage:
///   NovelEntryEffect.show(context, avatarUrl: user.avatar, username: user.username);
class NovelEntryEffect extends StatefulWidget {
  final String? avatarUrl;
  final String username;
  final VoidCallback? onFinished;

  const NovelEntryEffect({
    Key? key,
    this.avatarUrl,
    required this.username,
    this.onFinished,
  }) : super(key: key);

  static OverlayEntry? _activeEntry;

  static void show(
    BuildContext context, {
    String? avatarUrl,
    required String username,
    VoidCallback? onFinished,
  }) {
    _activeEntry?.remove();
    _activeEntry = null;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => NovelEntryEffect(
        avatarUrl: avatarUrl,
        username: username,
        onFinished: () {
          entry.remove();
          _activeEntry = null;
          onFinished?.call();
        },
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
  }

  @override
  State<NovelEntryEffect> createState() => _NovelEntryEffectState();
}

class _NovelEntryEffectState extends State<NovelEntryEffect>
    with TickerProviderStateMixin {
  late AnimationController _masterCtrl;
  late AnimationController _ringCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _breathCtrl;
  late AnimationController _particleCtrl;

  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;
  late Animation<double> _avatarScale;
  late Animation<double> _usernameOpacity;
  late Animation<double> _usernameSlide;

  late List<_Particle> _particles;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _particles = List.generate(45, (_) => _Particle(_rng));

    _masterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500));
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _breathCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500));

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _masterCtrl, curve: const Interval(0.0, 0.18, curve: Curves.easeOut)));
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _masterCtrl, curve: const Interval(0.84, 1.0, curve: Curves.easeIn)));
    _avatarScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _masterCtrl, curve: const Interval(0.08, 0.35, curve: Curves.elasticOut)));
    _usernameOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _masterCtrl, curve: const Interval(0.28, 0.50, curve: Curves.easeOut)));
    _usernameSlide = Tween<double>(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(parent: _masterCtrl, curve: const Interval(0.28, 0.50, curve: Curves.easeOut)));

    _masterCtrl.forward();
    _particleCtrl.forward();
    _masterCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    _breathCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final avatarR = size.width * 0.16;

    return AnimatedBuilder(
      animation: Listenable.merge([_masterCtrl, _ringCtrl, _pulseCtrl, _breathCtrl, _particleCtrl]),
      builder: (context, _) {
        final mo = (_fadeIn.value * _fadeOut.value).clamp(0.0, 1.0);
        return Opacity(
          opacity: mo,
          child: SizedBox.expand(
            child: Stack(
              children: [
                // 1. Anti-gravity particles
                CustomPaint(
                  size: size,
                  painter: _ParticlePainter(
                    particles: _particles,
                    progress: _particleCtrl.value,
                    masterOpacity: mo,
                    cx: cx,
                    cy: cy - size.height * 0.08,
                  ),
                ),

                // 2. Glow rings
                ..._buildRings(cx, cy - size.height * 0.08, avatarR, mo),

                // 3. Avatar
                Positioned(
                  left: cx - avatarR,
                  top: cy - size.height * 0.08 - avatarR,
                  child: Transform.scale(
                    scale: _avatarScale.value,
                    child: _buildAvatar(avatarR * 2),
                  ),
                ),

                // 4. Username
                Positioned(
                  top: cy - size.height * 0.08 + avatarR + 18,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: _usernameOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, _usernameSlide.value),
                      child: _buildUsername(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildRings(double cx, double cy, double baseR, double mo) {
    const specs = [
      (1.55, 1.0, 0.18, 0xFFD97706),
      (2.15, 0.7, 0.28, 0xFFFBBF24),
      (2.95, 0.45, 0.42, 0xFFEAB308),
    ];
    return specs.asMap().entries.map((e) {
      final i = e.key;
      final r = baseR * e.value.$1;
      final alpha = e.value.$2;
      final w = e.value.$3;
      final col = Color(e.value.$4);
      final rot = _ringCtrl.value * (1.0 + i * 0.4) * 2 * math.pi + i * math.pi / 3;
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
              border: Border.all(color: col.withOpacity(alpha * pulse * mo), width: w),
              boxShadow: [BoxShadow(color: col.withOpacity(0.12 * pulse * mo), blurRadius: 10, spreadRadius: 2)],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildAvatar(double size) {
    final pulse = 0.75 + 0.25 * _pulseCtrl.value;
    final glow = 8.0 + 6.0 * _pulseCtrl.value;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(colors: [
          Color(0xFFD97706), Color(0xFFFBBF24), Color(0xFFEAB308), Color(0xFFFBBF24), Color(0xFFD97706),
        ]),
        boxShadow: [
          BoxShadow(color: const Color(0xFFD97706).withOpacity(0.55 * pulse), blurRadius: glow, spreadRadius: 3),
          BoxShadow(color: const Color(0xFFFBBF24).withOpacity(0.25 * pulse), blurRadius: glow * 2.5, spreadRadius: 0),
        ],
      ),
      padding: const EdgeInsets.all(3.5),
      child: ClipOval(
        child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
            ? Image.network(widget.avatarUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(size))
            : _placeholder(size),
      ),
    );
  }

  Widget _placeholder(double s) => Container(
        color: const Color(0xFF1C1917),
        child: Icon(Icons.person, color: const Color(0xFFD97706), size: s * 0.5),
      );

  Widget _buildUsername() {
    final breathScale = 1.0 + 0.015 * _breathCtrl.value;
    final breathOpacity = 0.85 + 0.15 * _breathCtrl.value;
    return Transform.scale(
      scale: breathScale,
      child: Opacity(
        opacity: breathOpacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              _GoldLine(), SizedBox(width: 8),
              Text('✦', style: TextStyle(color: Color(0xFFD97706), fontSize: 10, decoration: TextDecoration.none)),
              SizedBox(width: 8), _GoldLine(),
            ]),
            const SizedBox(height: 6),
            Text(widget.username,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white,
                letterSpacing: 2.5, decoration: TextDecoration.none,
                shadows: [
                  Shadow(color: Color(0xFFD97706), blurRadius: 14),
                  Shadow(color: Color(0xFFFBBF24), blurRadius: 28),
                  Shadow(color: Colors.white, blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text('N O V E L   1',
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w400,
                color: Color(0xFFD97706), letterSpacing: 5,
                decoration: TextDecoration.none,
                shadows: [Shadow(color: Color(0xFFD97706), blurRadius: 8)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldLine extends StatelessWidget {
  const _GoldLine();
  @override
  Widget build(BuildContext context) => Container(
        width: 48, height: 1,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Colors.transparent, Color(0xFFD97706), Colors.transparent]),
        ),
      );
}

class _Particle {
  final math.Random rng;
  late double startX, startY, size, speed, opacity, phase, wobble;
  late bool isOrbiter;

  _Particle(this.rng) {
    startX   = rng.nextDouble();
    startY   = rng.nextDouble();
    size     = 1.5 + rng.nextDouble() * 2.5;
    speed    = 0.05 + rng.nextDouble() * 0.12;
    opacity  = 0.3 + rng.nextDouble() * 0.55;
    phase    = rng.nextDouble() * math.pi * 2;
    wobble   = 8 + rng.nextDouble() * 20;
    isOrbiter = rng.nextDouble() < 0.25;
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress, masterOpacity, cx, cy;
  _ParticlePainter({required this.particles, required this.progress, required this.masterOpacity, required this.cx, required this.cy});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    for (final pt in particles) {
      double px, py;
      final t = (progress + pt.phase / (math.pi * 2)) % 1.0;
      if (pt.isOrbiter) {
        final orbitR = 60 + pt.wobble;
        final angle = t * math.pi * 2 * pt.speed * 8 + pt.phase;
        px = cx + orbitR * math.cos(angle);
        py = cy + orbitR * math.sin(angle) * 0.55;
      } else {
        final riseT = (t * pt.speed * 12) % 1.0;
        px = pt.startX * size.width + math.sin(riseT * math.pi * 2 + pt.phase) * pt.wobble;
        py = size.height - size.height * riseT * 0.85 - pt.startY * 100;
      }
      final pOp = pt.opacity * masterOpacity;
      if (pOp <= 0) continue;
      final shimmer = (math.sin(progress * math.pi * 4 + pt.phase) + 1) / 2;
      final col = Color.lerp(const Color(0xFFD97706), const Color(0xFFFBBF24), shimmer)!.withOpacity(pOp);
      p.color = col;
      canvas.drawCircle(Offset(px, py), pt.size, p);
      p.color = col.withOpacity(pOp * 0.3);
      canvas.drawCircle(Offset(px, py), pt.size * 2.5, p);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

