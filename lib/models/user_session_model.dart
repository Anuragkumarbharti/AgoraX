import 'package:flutter/foundation.dart';

class UserSession {
  final String id;
  final String userId;
  final String sessionId;
  final String deviceId;
  final String deviceName;
  final String deviceModel;
  final String platform;
  final String osVersion;
  final String appVersion;
  final String browser;
  final String ipAddress;
  final String country;
  final String city;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final bool isCurrent;

  UserSession({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.deviceId,
    required this.deviceName,
    this.deviceModel = '',
    required this.platform,
    this.osVersion = '',
    this.appVersion = '',
    this.browser = '',
    this.ipAddress = '127.0.0.1',
    this.country = 'India',
    this.city = '',
    required this.createdAt,
    required this.lastActiveAt,
    this.expiresAt,
    this.revokedAt,
    this.isCurrent = false,
  });

  factory UserSession.fromJson(Map<String, dynamic> json, {String? currentSessionId}) {
    final sessId = json['session_id']?.toString() ?? '';
    final isCurr = currentSessionId != null && currentSessionId.isNotEmpty && sessId == currentSessionId;

    return UserSession(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      sessionId: sessId,
      deviceId: json['device_id']?.toString() ?? '',
      deviceName: json['device_name']?.toString() ?? 'Unknown Device',
      deviceModel: json['device_model']?.toString() ?? '',
      platform: json['platform']?.toString() ?? 'Mobile',
      osVersion: json['os_version']?.toString() ?? '',
      appVersion: json['app_version']?.toString() ?? '',
      browser: json['browser']?.toString() ?? '',
      ipAddress: json['ip_address']?.toString() ?? '127.0.0.1',
      country: json['country']?.toString() ?? 'India',
      city: json['city']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      lastActiveAt: json['last_active_at'] != null ? DateTime.parse(json['last_active_at']) : DateTime.now(),
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at']) : null,
      revokedAt: json['revoked_at'] != null ? DateTime.tryParse(json['revoked_at']) : null,
      isCurrent: isCurr || (json['is_current'] == true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'session_id': sessionId,
      'device_id': deviceId,
      'device_name': deviceName,
      'device_model': deviceModel,
      'platform': platform,
      'os_version': osVersion,
      'app_version': appVersion,
      'browser': browser,
      'ip_address': ipAddress,
      'country': country,
      'city': city,
      'created_at': createdAt.toIso8601String(),
      'last_active_at': lastActiveAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'revoked_at': revokedAt?.toIso8601String(),
      'is_current': isCurrent,
    };
  }

  UserSession copyWith({
    String? id,
    String? userId,
    String? sessionId,
    String? deviceId,
    String? deviceName,
    String? deviceModel,
    String? platform,
    String? osVersion,
    String? appVersion,
    String? browser,
    String? ipAddress,
    String? country,
    String? city,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    DateTime? expiresAt,
    DateTime? revokedAt,
    bool? isCurrent,
  }) {
    return UserSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceModel: deviceModel ?? this.deviceModel,
      platform: platform ?? this.platform,
      osVersion: osVersion ?? this.osVersion,
      appVersion: appVersion ?? this.appVersion,
      browser: browser ?? this.browser,
      ipAddress: ipAddress ?? this.ipAddress,
      country: country ?? this.country,
      city: city ?? this.city,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      expiresAt: expiresAt ?? this.expiresAt,
      revokedAt: revokedAt ?? this.revokedAt,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}

class LoginActivityLog {
  final String id;
  final String userId;
  final String eventType;
  final String deviceName;
  final String platform;
  final String ipAddress;
  final String country;
  final String? sessionId;
  final String status;
  final String? failureReason;
  final String authMethod;
  final DateTime loginAt;

  LoginActivityLog({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.deviceName,
    required this.platform,
    this.ipAddress = '127.0.0.1',
    this.country = 'India',
    this.sessionId,
    this.status = 'success',
    this.failureReason,
    this.authMethod = 'Password',
    required this.loginAt,
  });

  factory LoginActivityLog.fromJson(Map<String, dynamic> json) {
    return LoginActivityLog(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? 'Successful Login',
      deviceName: json['device_name']?.toString() ?? 'Unknown Device',
      platform: json['platform']?.toString() ?? 'Mobile',
      ipAddress: json['ip_address']?.toString() ?? '127.0.0.1',
      country: json['country']?.toString() ?? 'India',
      sessionId: json['session_id']?.toString(),
      status: json['status']?.toString() ?? 'success',
      failureReason: json['failure_reason']?.toString(),
      authMethod: json['auth_method']?.toString() ?? 'Password',
      loginAt: json['login_at'] != null ? DateTime.parse(json['login_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'event_type': eventType,
      'device_name': deviceName,
      'platform': platform,
      'ip_address': ipAddress,
      'country': country,
      'session_id': sessionId,
      'status': status,
      'failure_reason': failureReason,
      'auth_method': authMethod,
      'login_at': loginAt.toIso8601String(),
    };
  }

  /// Masked IP address for privacy/security display e.g. 103.xxx.xxx.42
  String get maskedIp {
    if (ipAddress.isEmpty) return 'xxx.xxx.xxx.xxx';
    final parts = ipAddress.split('.');
    if (parts.length == 4) {
      return '${parts[0]}.xxx.xxx.${parts[3]}';
    }
    return ipAddress.length > 6 ? '${ipAddress.substring(0, 3)}...${ipAddress.substring(ipAddress.length - 2)}' : ipAddress;
  }
}
