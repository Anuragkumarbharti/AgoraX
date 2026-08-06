import 'package:flutter/material.dart';

class RoomPermissionHistory {
  final String id;
  final String roomId;
  final String actorId;
  final String actorRole;
  final String targetUserId;
  final String actionType; // 'PROMOTED', 'DEMOTED', 'PERMISSION_CHANGED', 'REMOVED'
  final String? oldRole;
  final String? newRole;
  final DateTime? expiresAt;
  final DateTime createdAt;

  RoomPermissionHistory({
    required this.id,
    required this.roomId,
    required this.actorId,
    required this.actorRole,
    required this.targetUserId,
    required this.actionType,
    this.oldRole,
    this.newRole,
    this.expiresAt,
    required this.createdAt,
  });

  factory RoomPermissionHistory.fromJson(Map<String, dynamic> json) {
    return RoomPermissionHistory(
      id: json['id'] ?? '',
      roomId: json['room_id'] ?? '',
      actorId: json['actor_id'] ?? '',
      actorRole: json['actor_role'] ?? 'Visitor',
      targetUserId: json['target_user_id'] ?? '',
      actionType: json['action_type'] ?? '',
      oldRole: json['old_role'],
      newRole: json['new_role'],
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class AdminActivityLog {
  final String id;
  final String roomId;
  final String adminId;
  final String actionType;
  final String? targetUserId;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  AdminActivityLog({
    required this.id,
    required this.roomId,
    required this.adminId,
    required this.actionType,
    this.targetUserId,
    required this.details,
    required this.createdAt,
  });

  factory AdminActivityLog.fromJson(Map<String, dynamic> json) {
    return AdminActivityLog(
      id: json['id'] ?? '',
      roomId: json['room_id'] ?? '',
      adminId: json['admin_id'] ?? '',
      actionType: json['action_type'] ?? '',
      targetUserId: json['target_user_id'],
      details: json['details'] is Map ? Map<String, dynamic>.from(json['details']) : {},
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class UserWarning {
  final String id;
  final String roomId;
  final String userId;
  final String issuedBy;
  final int warningLevel;
  final String reason;
  final bool isActive;
  final DateTime createdAt;

  UserWarning({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.issuedBy,
    required this.warningLevel,
    required this.reason,
    required this.isActive,
    required this.createdAt,
  });

  factory UserWarning.fromJson(Map<String, dynamic> json) {
    return UserWarning(
      id: json['id'] ?? '',
      roomId: json['room_id'] ?? '',
      userId: json['user_id'] ?? '',
      issuedBy: json['issued_by'] ?? '',
      warningLevel: json['warning_level'] ?? 1,
      reason: json['reason'] ?? '',
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class AdminCustomPermissions {
  final bool kick;
  final bool mute;
  final bool seatLock;
  final bool backgroundChange;
  final bool roomInfoEdit;
  final bool pkStart;
  final bool ban;
  final bool announcement;

  AdminCustomPermissions({
    this.kick = true,
    this.mute = true,
    this.seatLock = true,
    this.backgroundChange = true,
    this.roomInfoEdit = true,
    this.pkStart = true,
    this.ban = false,
    this.announcement = false,
  });

  factory AdminCustomPermissions.fromJson(Map<String, dynamic> json) {
    return AdminCustomPermissions(
      kick: json['kick'] ?? true,
      mute: json['mute'] ?? true,
      seatLock: json['seat_lock'] ?? true,
      backgroundChange: json['background_change'] ?? true,
      roomInfoEdit: json['room_info_edit'] ?? true,
      pkStart: json['pk_start'] ?? true,
      ban: json['ban'] ?? false,
      announcement: json['announcement'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kick': kick,
      'mute': mute,
      'seat_lock': seatLock,
      'background_change': backgroundChange,
      'room_info_edit': roomInfoEdit,
      'pk_start': pkStart,
      'ban': ban,
      'announcement': announcement,
    };
  }

  AdminCustomPermissions copyWith({
    bool? kick,
    bool? mute,
    bool? seatLock,
    bool? backgroundChange,
    bool? roomInfoEdit,
    bool? pkStart,
    bool? ban,
    bool? announcement,
  }) {
    return AdminCustomPermissions(
      kick: kick ?? this.kick,
      mute: mute ?? this.mute,
      seatLock: seatLock ?? this.seatLock,
      backgroundChange: backgroundChange ?? this.backgroundChange,
      roomInfoEdit: roomInfoEdit ?? this.roomInfoEdit,
      pkStart: pkStart ?? this.pkStart,
      ban: ban ?? this.ban,
      announcement: announcement ?? this.announcement,
    );
  }
}

class RoomRoleCounters {
  final int owner;
  final int maxOwners;
  final int coOwner;
  final int maxCoOwners;
  final int admin;
  final int maxAdmins;
  final int audience;

  RoomRoleCounters({
    required this.owner,
    required this.maxOwners,
    required this.coOwner,
    required this.maxCoOwners,
    required this.admin,
    required this.maxAdmins,
    required this.audience,
  });

  factory RoomRoleCounters.fromJson(Map<String, dynamic> json) {
    return RoomRoleCounters(
      owner: json['owner'] ?? 1,
      maxOwners: json['max_owners'] ?? 1,
      coOwner: json['co_owner'] ?? 0,
      maxCoOwners: json['max_co_owners'] ?? 1,
      admin: json['admin'] ?? 0,
      maxAdmins: json['max_admins'] ?? 4,
      audience: json['audience'] ?? 0,
    );
  }
}

class RoomGovernanceOverview {
  final String roomId;
  final double securityScore;
  final int healthScore;
  final int governanceLevel;
  final bool isEmergencyMode;
  final String? backupOwnerId;
  final RoomRoleCounters roleCounters;
  final List<RoomPermissionHistory> permissionHistory;
  final List<AdminActivityLog> adminActivityLogs;
  final List<UserWarning> activeWarnings;

  RoomGovernanceOverview({
    required this.roomId,
    required this.securityScore,
    required this.healthScore,
    required this.governanceLevel,
    required this.isEmergencyMode,
    this.backupOwnerId,
    required this.roleCounters,
    required this.permissionHistory,
    required this.adminActivityLogs,
    required this.activeWarnings,
  });

  factory RoomGovernanceOverview.fromJson(Map<String, dynamic> json) {
    return RoomGovernanceOverview(
      roomId: json['room_id'] ?? '',
      securityScore: (json['security_score'] is num) ? (json['security_score'] as num).toDouble() : 5.0,
      healthScore: json['health_score'] ?? 100,
      governanceLevel: json['governance_level'] ?? 1,
      isEmergencyMode: json['is_emergency_mode'] ?? false,
      backupOwnerId: json['backup_owner_id'],
      roleCounters: RoomRoleCounters.fromJson(json['role_counters'] is Map ? Map<String, dynamic>.from(json['role_counters']) : {}),
      permissionHistory: (json['permission_history'] is List)
          ? (json['permission_history'] as List).map((x) => RoomPermissionHistory.fromJson(x)).toList()
          : [],
      adminActivityLogs: (json['admin_activity_logs'] is List)
          ? (json['admin_activity_logs'] as List).map((x) => AdminActivityLog.fromJson(x)).toList()
          : [],
      activeWarnings: (json['active_warnings'] is List)
          ? (json['active_warnings'] as List).map((x) => UserWarning.fromJson(x)).toList()
          : [],
    );
  }

  String get governanceRankName {
    switch (governanceLevel) {
      case 1:
        return 'New Governance';
      case 2:
        return 'Trusted Governance';
      case 3:
        return 'Professional Governance';
      case 4:
        return 'Elite Governance';
      case 5:
        return 'Official Governance';
      case 6:
        return 'Premium Governance';
      case 7:
      default:
        return 'Legendary Governance';
    }
  }
}

/// Helper engine for Role Priority ordering & color badges
class RolePriorityEngine {
  static const int RANK_OWNER = 1;
  static const int RANK_CO_OWNER = 2;
  static const int RANK_ADMIN = 3;
  static const int RANK_HOST = 4;
  static const int RANK_VERIFIED = 5;
  static const int RANK_FAMILY = 6;
  static const int RANK_AGENCY = 7;
  static const int RANK_VIP = 8;
  static const int RANK_USER_LEVEL = 9;

  static Color getRoleBadgeColor(String role) {
    final lower = role.toLowerCase().trim();
    if (lower.contains('owner') || lower.contains('creator')) {
      return const Color(0xFFFFD700); // Gold
    } else if (lower.contains('co-owner') || lower.contains('co owner')) {
      return const Color(0xFF9D4EDD); // Purple
    } else if (lower.contains('admin')) {
      return const Color(0xFF3A86EF); // Blue
    } else if (lower.contains('host')) {
      return const Color(0xFFEF476F); // Crimson Red
    } else {
      return Colors.white70;
    }
  }

  static String getRoleBadgeIcon(String role) {
    final lower = role.toLowerCase().trim();
    if (lower.contains('owner') || lower.contains('creator')) {
      return '⭐';
    } else if (lower.contains('co-owner') || lower.contains('co owner')) {
      return '💎';
    } else if (lower.contains('admin')) {
      return '🛡️';
    } else if (lower.contains('host')) {
      return '🎤';
    } else {
      return '🎧';
    }
  }
}
