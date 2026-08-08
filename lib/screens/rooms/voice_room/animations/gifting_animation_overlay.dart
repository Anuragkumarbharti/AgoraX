import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../widgets/gifting/creania_gift_animation_engine.dart';
import '../../../../models/gift/gift_animation_metadata.dart';
import '../../../../services/gifting/gift_animation_controller.dart';
import '../../../../services/gifting/gift_overlay_manager.dart';
import '../../../../services/gifting/sender_position_resolver.dart';
import '../../../../services/gifting/receiver_resolver.dart';
import '../../../../services/room/room_controller.dart';

class GiftingAnimationOverlay extends StatefulWidget {
  final RxList<Map<String, dynamic>> activeAnimations;
  final Map<int, GlobalKey> seatKeys;
  final Function(bool isMajor) onExplosion;

  const GiftingAnimationOverlay({
    Key? key,
    required this.activeAnimations,
    required this.seatKeys,
    required this.onExplosion,
  }) : super(key: key);

  @override
  State<GiftingAnimationOverlay> createState() =>
      _GiftingAnimationOverlayState();
}

class _GiftingAnimationOverlayState extends State<GiftingAnimationOverlay> {
  final List<Map<String, dynamic>> _currentAnims = [];
  Worker? _animWorker;
  Worker? _globalGiftWorker;
  final Map<String, Offset> _lastKnownSeatPositions = {};

  final Set<String> _processedEventIds = {};

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<GiftOverlayManager>()) {
      GiftOverlayManager.to.registerRoomOverlay();
    }
    _animWorker =
        ever(widget.activeAnimations, (List<Map<String, dynamic>> anims) {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final newAnim in anims) {
        final animId = newAnim['id']?.toString() ?? '';
        if (animId.isNotEmpty && _processedEventIds.contains(animId)) continue;
        if (animId.isNotEmpty) _processedEventIds.add(animId);

        final sender = (newAnim['senderName'] ?? '').toString();
        final gift = (newAnim['name'] ?? newAnim['giftId'] ?? '').toString();

        final existingIndex = _currentAnims.indexWhere((p) {
          final pSender = (p['senderName'] ?? '').toString();
          final pGift = (p['name'] ?? p['giftId'] ?? '').toString();
          final pTime = p['_addedAt'] as int? ?? now;
          return pSender == sender && pGift == gift && (now - pTime).abs() < 3000;
        });

        if (existingIndex != -1) {
          setState(() {
            final currentCount = (_currentAnims[existingIndex]['count'] as int? ?? 1);
            final addCount = (newAnim['count'] as int? ?? 1);
            _currentAnims[existingIndex]['count'] = currentCount + addCount;
            _currentAnims[existingIndex]['_addedAt'] = now;
          });
        } else {
          setState(() {
            _currentAnims.add({
              ...newAnim,
              '_addedAt': now,
            });
          });
        }
      }
    });

    final giftAnimCtrl = GiftAnimationController.to;
    for (final evt in giftAnimCtrl.activeEvents) {
      _addEventFromPayload(evt);
    }

    _globalGiftWorker = ever(giftAnimCtrl.activeEvents,
        (List<GiftAnimationEventPayload> events) {
      for (final evt in events) {
        _addEventFromPayload(evt);
      }
    });
  }

  void _addEventFromPayload(GiftAnimationEventPayload evt) {
    if (_processedEventIds.contains(evt.id)) return;
    _processedEventIds.add(evt.id);

    final now = DateTime.now().millisecondsSinceEpoch;

    final existingIndex = _currentAnims.indexWhere((p) {
      final pSender = (p['senderName'] ?? '').toString();
      final pGift = (p['name'] ?? p['giftId'] ?? '').toString();
      final pTime = p['_addedAt'] as int? ?? now;
      return pSender == evt.senderName && pGift == evt.giftName && (now - pTime).abs() < 3000;
    });

    final roomId = RoomController.to.activeRoomId ?? '';
    final roomSeats = RoomController.to.roomSeatsInfo[roomId] ?? [];

    final startPos = SenderPositionResolver.resolve(
      senderId: evt.senderId,
      roomSeats: roomSeats,
      seatKeys: widget.seatKeys,
    );

    final resolvedReceivers = ReceiverResolver.resolve(
      receiverIds: evt.receiverIds,
      seatIndices: evt.receiverSeats,
      receiverNames: evt.receiverNames,
      roomSeats: roomSeats,
      seatKeys: widget.seatKeys,
      lastKnownPositions: _lastKnownSeatPositions,
    );

    final List<Offset> targets =
        resolvedReceivers.map((r) => r.roomPosition).toList();
    final receiverNamesText = resolvedReceivers.map((r) => r.userName).join(', ');

    if (existingIndex != -1) {
      setState(() {
        final currentCount = (_currentAnims[existingIndex]['count'] as int? ?? 1);
        _currentAnims[existingIndex]['count'] = currentCount + evt.count;
        _currentAnims[existingIndex]['_addedAt'] = now;
        _currentAnims[existingIndex]['receiverName'] = receiverNamesText.isNotEmpty ? receiverNamesText : 'Seat';
        _currentAnims[existingIndex]['targets'] = targets;
      });
      debugPrint('[GIFT_OVERLAY] COMBO ACCUMULATED | gift=${evt.giftName} | new total=${_currentAnims[existingIndex]['count']}');
      return;
    }

    setState(() {
      _currentAnims.add({
        'id': evt.id,
        'giftId': evt.giftId,
        'name': evt.giftName,
        'icon': evt.giftIcon,
        'price': evt.price,
        'currency': evt.currency,
        'senderName': evt.senderName,
        'senderAvatar': evt.senderAvatar,
        'start': startPos,
        'receiverName': receiverNamesText.isNotEmpty ? receiverNamesText : 'Seat',
        'receiverAvatar': resolvedReceivers.isNotEmpty
            ? resolvedReceivers.first.userAvatar
            : null,
        'targets': targets,
        'count': evt.count,
        '_addedAt': now,
      });
    });
  }

  @override
  void dispose() {
    debugPrint('[GIFT_OVERLAY] WIDGET DISPOSE | active count=${_currentAnims.length}');
    _animWorker?.dispose();
    _globalGiftWorker?.dispose();
    if (Get.isRegistered<GiftOverlayManager>()) {
      GiftOverlayManager.to.unregisterRoomOverlay();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[GIFT_OVERLAY] PARENT REBUILD | active count=${_currentAnims.length}');
    if (_currentAnims.isEmpty) return const SizedBox.shrink();

    final media = MediaQuery.of(context).size;

    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          children: [
            for (final anim in _currentAnims)
              CreaniaGiftAnimationEngine(
                key: ValueKey(anim['id']),
                event: GiftRequestEvent(
                  giftId: anim['giftId'] ?? anim['name'] ?? 'gift',
                  giftName: anim['name'] ?? 'Gift',
                  giftIcon: anim['icon'] ?? '🎁',
                  price: anim['price'] ?? 10,
                  currency: anim['currency'] ?? 'gold',
                  mode: GiftAnimationMode.roomSeat,
                  senderName: anim['senderName'] ?? 'Member',
                  senderAvatar: anim['senderAvatar'],
                  startOffset: anim['start'] ??
                      Offset(media.width / 2, media.height * 0.92),
                  receiverName: anim['receiverName'] ?? 'Seat',
                  receiverAvatar: anim['receiverAvatar'],
                  targetOffset: (anim['targets'] as List<Offset>).isNotEmpty
                      ? (anim['targets'] as List<Offset>).first
                      : Offset(media.width / 2, media.height * 0.4),
                  targetOffsets: anim['targets'] as List<Offset>?,
                  count: anim['count'] ?? 1,
                ),
                onCompleted: () {
                  debugPrint('[GIFT_OVERLAY] OVERLAY REMOVED | animId=${anim['id']}');
                  if (mounted) {
                    final animId = anim['id'].toString();
                    setState(() {
                      _currentAnims.removeWhere((a) => a['id'].toString() == animId);
                    });
                    widget.activeAnimations.removeWhere((a) => a['id'].toString() == animId);
                    if (Get.isRegistered<GiftAnimationController>()) {
                      GiftAnimationController.to.removeEvent(animId);
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivePathAnimation {
  final String id;
  final AnimationController controller;
  final Offset start;
  final List<Offset> targets;
  final String icon;
  final String name;
  final int count;
  final bool isMajor;
  final List<Offset> controlPoints = [];
  final RxBool showExplosion = false.obs;

  _ActivePathAnimation({
    required this.id,
    required this.controller,
    required this.start,
    required this.targets,
    required this.icon,
    required this.name,
    required this.count,
    required this.isMajor,
  }) {
    final random = Random();
    for (int i = 0; i < targets.length; i++) {
      final target = targets[i];
      final midX = (start.dx + target.dx) / 2;
      final midY = (start.dy + target.dy) / 2;
      final displacement =
          (random.nextBool() ? 1 : -1) * (50 + random.nextInt(70));
      controlPoints.add(Offset(midX + displacement, midY - 40));
    }
  }

  void triggerExplosion() {
    showExplosion.value = true;
    HapticFeedback.mediumImpact();
  }
}

class _GiftingFlightPainter extends CustomPainter {
  final List<_ActivePathAnimation> paths;
  _GiftingFlightPainter({required this.paths});

  @override
  void paint(Canvas canvas, Size size) {
    final paintTrail = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final path in paths) {
      final t = path.controller.value;
      if (t >= 1.0) continue;

      for (int i = 0; i < path.targets.length; i++) {
        final target = path.targets[i];
        final control = path.controlPoints[i];

        final pos = _getBezierPoint(path.start, control, target, t);

        // 1. Draw Sparkle Trail
        final random = Random(path.id.hashCode + i);
        for (int p = 0; p < 5; p++) {
          final trailT = (t - (p * 0.05)).clamp(0.0, 1.0);
          final trailPos = _getBezierPoint(path.start, control, target, trailT);
          final offsetDist = 8.0 * (1 - trailT);
          final trailX =
              trailPos.dx + (random.nextDouble() * 2 - 1) * offsetDist;
          final trailY =
              trailPos.dy + (random.nextDouble() * 2 - 1) * offsetDist;

          paintTrail.color =
              (path.isMajor ? const Color(0xFFFFD700) : const Color(0xFFAF52DE))
                  .withOpacity((1 - trailT) * 0.6);
          canvas.drawCircle(
              Offset(trailX, trailY), 2.5 * (1 - trailT), paintTrail);
        }

        // 2. Draw Flying Icon (scaled up/down based on progress)
        final double scale = 0.5 + 0.5 * sin(t * 3.14159);
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.scale(scale);

        textPainter.text = TextSpan(
          text: path.icon,
          style: const TextStyle(fontSize: 24),
        );
        textPainter.layout();
        textPainter.paint(
            canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
        canvas.restore();
      }
    }
  }

  Offset _getBezierPoint(Offset p0, Offset p1, Offset p2, double t) {
    final double u = 1 - t;
    final double tt = t * t;
    final double uu = u * u;
    final double dx = uu * p0.dx + 2 * u * t * p1.dx + tt * p2.dx;
    final double dy = uu * p0.dy + 2 * u * t * p1.dy + tt * p2.dy;
    return Offset(dx, dy);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ExplosionBurstWidget extends StatefulWidget {
  final _ActivePathAnimation path;
  const _ExplosionBurstWidget({required this.path});

  @override
  State<_ExplosionBurstWidget> createState() => _ExplosionBurstWidgetState();
}

class _ExplosionBurstWidgetState extends State<_ExplosionBurstWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    widget.path.showExplosion.listen((exploded) {
      if (exploded && !_triggered) {
        _triggered = true;
        if (mounted) {
          _ctrl.forward();
        }
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        if (!_triggered) return const SizedBox.shrink();
        return CustomPaint(
          painter: _ExplosionPainter(
            progress: _ctrl.value,
            targets: widget.path.targets,
            isMajor: widget.path.isMajor,
          ),
        );
      },
    );
  }
}

class _ExplosionPainter extends CustomPainter {
  final double progress;
  final List<Offset> targets;
  final bool isMajor;
  _ExplosionPainter(
      {required this.progress, required this.targets, required this.isMajor});

  @override
  void paint(Canvas canvas, Size size) {
    final paintRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final paintSparkle = Paint()..style = PaintingStyle.fill;

    for (final target in targets) {
      // 1. Expanding ring
      paintRing.color =
          (isMajor ? const Color(0xFFFFD700) : const Color(0xFFE0F2FE))
              .withOpacity((1 - progress).clamp(0.0, 1.0));
      canvas.drawCircle(target, 45.0 * progress, paintRing);

      // 2. Dispersing sparkle particles
      final int sparkleCount = isMajor ? 20 : 12;
      final double maxRadius = isMajor ? 60.0 : 40.0;
      final random = Random(target.dx.toInt());

      for (int i = 0; i < sparkleCount; i++) {
        final double angle = i * (2 * 3.14159 / sparkleCount);
        final double distance =
            maxRadius * progress * (0.8 + 0.2 * random.nextDouble());
        final double x = target.dx + distance * cos(angle);
        final double y = target.dy + distance * sin(angle);

        paintSparkle.color = (isMajor
                ? (random.nextBool()
                    ? const Color(0xFFFFD700)
                    : const Color(0xFFFF2D55))
                : const Color(0xFFAF52DE))
            .withOpacity((1 - progress).clamp(0.0, 1.0));

        canvas.drawCircle(Offset(x, y), 3.5 * (1 - progress), paintSparkle);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
