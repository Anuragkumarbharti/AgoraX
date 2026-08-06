import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/store/store_controller.dart';
import '../../screens/profile/account_center_screen.dart';
import '../../screens/store/coin_store_screen.dart';
import '../../utils/number_formatter.dart';

/// Formats wallet coins balance using universal compact representation.
String formatWalletCoins(int coins) {
  return formatCompactNumber(coins);
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
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFFDF00), Color(0xFFF59E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x66FFD700),
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
            fontSize: 11,
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color pillBg = isDark
        ? const Color(0xFF1E1C38).withOpacity(0.65)
        : const Color(0xFFF1F5F9);

    final Color pillBorder = isDark
        ? const Color(0xFFFFD700).withOpacity(0.35)
        : const Color(0xFFF59E0B).withOpacity(0.45);

    final Color textColor = isDark
        ? Colors.white
        : const Color(0xFF0F172A);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── READ-ONLY COMPACT WALLET PILL CONTAINER ──
        GestureDetector(
          onTap: _handlePillClick,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: pillBorder,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.10)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.06),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildGoldCoinIcon(),
                const SizedBox(width: 5),
                Obx(() {
                  final coins = storeCtrl.coinsBalance.value;
                  final formattedText = formatWalletCoins(coins);
                  return Text(
                    formattedText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: textColor,
                      fontSize: 12.5,
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
          const SizedBox(width: 5),
          // ── SEPARATE SMALL CIRCULAR (+) BUTTON ──
          GestureDetector(
            onTap: _handlePlusClick,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.40),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
