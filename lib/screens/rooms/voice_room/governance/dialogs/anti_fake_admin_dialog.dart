import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../models/room/room_governance_model.dart';
import '../../../../../services/room/room_governance_controller.dart';

class AntiFakeAdminDialog extends StatefulWidget {
  final String roomId;
  final String targetUserId;
  final String targetUserName;

  const AntiFakeAdminDialog({
    super.key,
    required this.roomId,
    required this.targetUserId,
    required this.targetUserName,
  });

  static Future<void> show(
    BuildContext context, {
    required String roomId,
    required String targetUserId,
    required String targetUserName,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AntiFakeAdminDialog(
        roomId: roomId,
        targetUserId: targetUserId,
        targetUserName: targetUserName,
      ),
    );
  }

  @override
  State<AntiFakeAdminDialog> createState() => _AntiFakeAdminDialogState();
}

class _AntiFakeAdminDialogState extends State<AntiFakeAdminDialog> {
  int _step = 1;
  String _selectedRole = 'Admin';
  int? _selectedExpiryHours; // null = permanent, 6, 24, 168 (7 days)
  AdminCustomPermissions _permissions = AdminCustomPermissions();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Text(_step == 1 ? '🛡️ Step 1: Role Configuration' : '⚠️ Step 2: Anti-Fake Confirmation',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: _step == 1 ? _buildStep1() : _buildStep2(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const TextStyle(color: Colors.grey) != null ? const Text('Cancel', style: TextStyle(color: Colors.grey)) : const SizedBox(),
        ),
        if (_step == 1)
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            onPressed: () {
              setState(() => _step = 2);
            },
            child: const Text('Proceed to Confirm →', style: TextStyle(color: Colors.white)),
          )
        else
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              final controller = RoomGovernanceController.to;
              final success = await controller.promoteMemberV2(
                roomId: widget.roomId,
                targetUserId: widget.targetUserId,
                newRole: _selectedRole,
                expiryHours: _selectedExpiryHours,
                permissions: _permissions,
              );
              if (mounted && success) {
                Navigator.pop(context);
              }
            },
            child: const Text('Confirm Promotion 👑', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configuring promotion for ${widget.targetUserName}',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 16),
        const Text('Target Role', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [
            _roleChip('Admin', '🛡️'),
            const SizedBox(width: 8),
            _roleChip('Co-Owner', '💎'),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Role Duration / Expiry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _expiryChip('6 Hours', 6),
            _expiryChip('24 Hours', 24),
            _expiryChip('7 Days', 168),
            _expiryChip('Permanent', null),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Granular Permissions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        _permSwitch('Kick Members', _permissions.kick, (val) => setState(() => _permissions = _permissions.copyWith(kick: val))),
        _permSwitch('Mute Audience', _permissions.mute, (val) => setState(() => _permissions = _permissions.copyWith(mute: val))),
        _permSwitch('Lock/Unlock Seats', _permissions.seatLock, (val) => setState(() => _permissions = _permissions.copyWith(seatLock: val))),
        _permSwitch('Change Background', _permissions.backgroundChange, (val) => setState(() => _permissions = _permissions.copyWith(backgroundChange: val))),
        _permSwitch('Ban Members', _permissions.ban, (val) => setState(() => _permissions = _permissions.copyWith(ban: val))),
      ],
    );
  }

  Widget _buildStep2() {
    String durationText = _selectedExpiryHours == null ? 'Permanent' : '$_selectedExpiryHours Hours';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade900.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber, width: 1),
          ),
          child: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Anti-Fake Admin Warning: Please re-verify before promoting user to avoid accidental admin access.',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Are you sure you want to promote ${widget.targetUserName}?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _summaryRow('User:', widget.targetUserName),
        _summaryRow('Assigned Role:', '$_selectedRole ($_selectedRole == "Co-Owner" ? "💎" : "🛡️")'),
        _summaryRow('Duration:', durationText),
      ],
    );
  }

  Widget _roleChip(String label, String icon) {
    final selected = _selectedRole == label;
    return ChoiceChip(
      label: Text('$icon $label', style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 12)),
      selected: selected,
      selectedColor: const Color(0xFF3B82F6),
      backgroundColor: const Color(0xFF1E293B),
      onSelected: (val) {
        if (val) setState(() => _selectedRole = label);
      },
    );
  }

  Widget _expiryChip(String label, int? hours) {
    final selected = _selectedExpiryHours == hours;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 11)),
      selected: selected,
      selectedColor: const Color(0xFF8B5CF6),
      backgroundColor: const Color(0xFF1E293B),
      onSelected: (val) {
        if (val) setState(() => _selectedExpiryHours = hours);
      },
    );
  }

  Widget _permSwitch(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      value: value,
      activeColor: const Color(0xFF10B981),
      onChanged: onChanged,
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}
