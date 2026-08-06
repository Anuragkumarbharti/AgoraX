import 'package:flutter/material.dart';
import '../../../../../models/room/room_governance_model.dart';

class RolePriorityBadgeWidget extends StatelessWidget {
  final String role;
  final String? familyTag;
  final String? agencyTag;
  final bool isVip;
  final bool isVerified;
  final int userLevel;
  final double fontSize;

  const RolePriorityBadgeWidget({
    super.key,
    required this.role,
    this.familyTag,
    this.agencyTag,
    this.isVip = false,
    this.isVerified = false,
    this.userLevel = 1,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> badges = [];

    // 1. Primary Room Role (Creator/Owner > Co-Owner > Admin > Host)
    if (role.isNotEmpty && role.toLowerCase() != 'listener' && role.toLowerCase() != 'visitor') {
      final color = RolePriorityEngine.getRoleBadgeColor(role);
      final icon = RolePriorityEngine.getRoleBadgeIcon(role);
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: TextStyle(fontSize: fontSize)),
              const SizedBox(width: 4),
              Text(
                role,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Verified Badge
    if (isVerified) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueAccent, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✔️', style: TextStyle(fontSize: fontSize)),
              const SizedBox(width: 2),
              Text('Verified', style: TextStyle(color: Colors.blueAccent, fontSize: fontSize, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    // 3. Family Tag
    if (familyTag != null && familyTag!.isNotEmpty) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orangeAccent, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🏠', style: TextStyle(fontSize: fontSize)),
              const SizedBox(width: 2),
              Text(familyTag!, style: TextStyle(color: Colors.orangeAccent, fontSize: fontSize)),
            ],
          ),
        ),
      );
    }

    // 4. Agency Tag
    if (agencyTag != null && agencyTag!.isNotEmpty) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.tealAccent, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🏢', style: TextStyle(fontSize: fontSize)),
              const SizedBox(width: 2),
              Text(agencyTag!, style: TextStyle(color: Colors.tealAccent, fontSize: fontSize)),
            ],
          ),
        ),
      );
    }

    // 5. VIP Tag
    if (isVip) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purpleAccent, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('💎', style: TextStyle(fontSize: fontSize)),
              const SizedBox(width: 2),
              Text('VIP', style: TextStyle(color: Colors.purpleAccent, fontSize: fontSize, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    // 6. User Level
    badges.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade700, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏅', style: TextStyle(fontSize: fontSize)),
            const SizedBox(width: 2),
            Text('Lv.$userLevel', style: TextStyle(color: Colors.amber.shade300, fontSize: fontSize, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: badges,
    );
  }
}
