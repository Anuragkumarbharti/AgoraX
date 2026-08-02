import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/store_controller.dart';
import '../screens/profile/account_center_screen.dart';
import '../screens/store/coin_store_screen.dart';

/// Formats wallet coins balance using high-contrast compact representation:
/// Examples: 9499, 12.5K, 29549, 2.4M
String formatWalletCoins(int coins) {
  if (coins < 0) return '0';
  if (coins >= 1000000) {
    final double val = coins / 1000000.0;
    return val % 1 == 0 ? '${val.toInt()}M' : '${val.toStringAsFixed(1)}M';
  }
  if (coins >= 100000) {
    final double val = coins / 1000.0;
    return val % 1 == 0 ? '${val.toInt()}K' : '${val.toStringAsFixed(1)}K';
  }
  if (coins >= 10000) {
    if (coins % 1000 == 0) {
      return '${(coins ~/ 1000)}K';
    }
    if (coins % 100 == 0) {
      final double val = coins / 1000.0;
      return '${val.toStringAsFixed(1)}K';
    }
  }
  return coins.toString();
}

class WalletHeaderPill extends StatefulWidget {
  final bool showPlusButton;
  final VoidCallback? onPillPressed;
  final VoidCallback? onPlusPressed;

  const WalletHeaderPill({
    Key? key,
    this.showPlusButton = true,
    this.onPillPressed,
    this.onPlusPressed,
  }) : super(key: key);

  @override
  State<WalletHeaderPill> createState() => _WalletHeaderPillState();
}

class _WalletHeaderPillState extends State<WalletHeaderPill> {
  DateTime _lastPillClick = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPlusClick = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _debounceDuration = Duration(milliseconds: 600);

  void _handlePillClick() {
    final now = DateTime.now();
    if (now.difference(_lastPillClick) < _debounceDuration) return;
    _lastPillClick = now;

    if (widget.onPillPressed != null) {
      widget.onPillPressed!();
    } else {
      Get.to(() => const AccountCenterScreen());
    }
  }

  void _handlePlusClick() {
    final now = DateTime.now();
    if (now.difference(_lastPlusClick) < _debounceDuration) return;
    _lastPlusClick = now;

    if (widget.onPlusPressed != null) {
      widget.onPlusPressed!();
    } else {
      Get.to(() => const CoinStoreScreen());
    }
  }

  Widget _buildGoldCoinIcon() {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x55FFD700),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '\$',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storeCtrl = StoreController.to;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── READ-ONLY WALLET PILL CONTAINER ──
        GestureDetector(
          onTap: _handlePillClick,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B).withOpacity(0.45),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.08),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildGoldCoinIcon(),
                const SizedBox(width: 6),
                Obx(() {
                  final coins = storeCtrl.coinsBalance.value;
                  final formattedText = formatWalletCoins(coins);
                  return Text(
                    formattedText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        if (widget.showPlusButton) ...[
          const SizedBox(width: 8),
          // ── SEPARATE (+) BUTTON ──
          GestureDetector(
            onTap: _handlePlusClick,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
