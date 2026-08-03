// lib/widgets/gift_animation_overlay.dart

import 'package:flutter/material.dart';
import '../models/gift_animation_metadata.dart';
import 'creania_gift_animation_engine.dart';

class GiftAnimationEvent {
  final String giftId;
  final String giftName;
  final String giftIcon;
  final String senderName;
  final String? senderAvatar;
  final String receiverName;
  final String? receiverAvatar;
  final int count;
  final String currency;
  final int price;
  final dynamic mode;
  final Offset? startOffset;
  final Offset? targetOffset;
  final List<Offset>? targetOffsets;

  GiftAnimationEvent({
    required this.giftId,
    required this.giftName,
    required this.giftIcon,
    required this.senderName,
    this.senderAvatar,
    required this.receiverName,
    this.receiverAvatar,
    this.count = 1,
    this.currency = 'gold',
    this.price = 10,
    this.mode,
    this.startOffset,
    this.targetOffset,
    this.targetOffsets,
  });
}

class GiftAnimationOverlayWidget extends StatelessWidget {
  final GiftAnimationEvent? event;
  final VoidCallback? onFinished;

  const GiftAnimationOverlayWidget({
    Key? key,
    this.event,
    this.onFinished,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (event == null) {
      return const SizedBox.shrink();
    }

    final e = event!;
    final reqEvent = GiftRequestEvent(
      giftId: e.giftId,
      giftName: e.giftName,
      giftIcon: e.giftIcon,
      price: e.price,
      currency: e.currency,
      mode: e.mode is GiftAnimationMode ? e.mode : GiftAnimationMode.roomSeat,
      senderName: e.senderName,
      senderAvatar: e.senderAvatar,
      startOffset: e.startOffset ?? Offset.zero,
      receiverName: e.receiverName,
      receiverAvatar: e.receiverAvatar,
      targetOffset: e.targetOffset ?? Offset.zero,
      targetOffsets: e.targetOffsets,
      count: e.count,
    );

    return CreaniaGiftAnimationEngine(
      event: reqEvent,
      onCompleted: onFinished,
    );
  }
}
