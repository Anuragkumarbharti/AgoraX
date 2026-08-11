import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../models/user_session_model.dart';
import '../user/user_profile_cache_manager.dart';
import '../../screens/auth/login_screen.dart';

class DeviceSessionService extends GetxService {
  static DeviceSessionService get to {
    if (!Get.isRegistered<DeviceSessionService>()) {
      Get.put(DeviceSessionService());
    }
    return Get.find<DeviceSessionService>();
  }

  final SupabaseClient _supabase = Supabase.instance.client;
  static const _uuid = Uuid();

  static const String _prefDeviceIdKey = 'creania_device_id';
  static const String _prefSessionIdKey = 'creania_current_session_id';

  String _deviceId = '';
  String _sessionId = '';

  String get currentDeviceId => _deviceId;
  String get currentSessionId => _sessionId;

  final RxList<UserSession> activeSessions = <UserSession>[].obs;
  final RxList<LoginActivityLog> loginLogs = <LoginActivityLog>[].obs;
  final RxBool isLoadingDevices = false.obs;
  final RxBool isLoadingLogs = false.obs;
  final RxMap<String, bool> revokingSessionIds = <String, bool>{}.obs;
  final RxBool isRevokingAll = false.obs;

  RealtimeChannel? _realtimeChannel;

  @override
  void onInit() {
    super.onInit();
    _loadLocalIdentifiers();
  }

  /// Initialize local device_id and session_id from SharedPreferences
  Future<void> _loadLocalIdentifiers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _deviceId = prefs.getString(_prefDeviceIdKey) ?? '';
      if (_deviceId.isEmpty) {
        _deviceId = 'dev_${_uuid.v4()}';
        await prefs.setString(_prefDeviceIdKey, _deviceId);
      }

      _sessionId = prefs.getString(_prefSessionIdKey) ?? '';
      if (_sessionId.isEmpty) {
        _sessionId = 'sess_${_uuid.v4()}';
        await prefs.setString(_prefSessionIdKey, _sessionId);
      }
    } catch (e) {
      debugPrint('[DeviceSessionService] Error loading local identifiers: $e');
      if (_deviceId.isEmpty) _deviceId = 'dev_${_uuid.v4()}';
      if (_sessionId.isEmpty) _sessionId = 'sess_${_uuid.v4()}';
    }
  }

  /// Ensure session ID exists or generate new unique session ID on fresh login
  Future<String> generateNewSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionId = 'sess_${_uuid.v4()}';
    await prefs.setString(_prefSessionIdKey, _sessionId);
    return _sessionId;
  }

  /// Get device metadata
  Map<String, String> _getDeviceMetadata() {
    String platform = 'Mobile';
    String deviceName = 'Creania Device';
    String osVersion = '';

    if (kIsWeb) {
      platform = 'Web';
      deviceName = 'Web Browser';
    } else if (Platform.isAndroid) {
      platform = 'Android';
      deviceName = 'Android Phone';
      osVersion = 'Android 15';
    } else if (Platform.isIOS) {
      platform = 'iOS';
      deviceName = 'iPhone 15';
      osVersion = 'iOS 18';
    } else if (Platform.isWindows) {
      platform = 'Windows';
      deviceName = 'Windows PC';
      osVersion = 'Windows 11';
    } else if (Platform.isMacOS) {
      platform = 'macOS';
      deviceName = 'MacBook Pro';
      osVersion = 'macOS Sonoma';
    }

    return {
      'platform': platform,
      'device_name': deviceName,
      'os_version': osVersion,
    };
  }

  /// Register current session on server upon login or app launch
  Future<void> registerSessionOnLogin({
    String authMethod = 'Password',
    String eventType = 'Successful Login',
    bool isNewLogin = false,
  }) async {
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty) return;

    await _loadLocalIdentifiers();
    if (isNewLogin) {
      await generateNewSessionId();
    }

    final meta = _getDeviceMetadata();

    try {
      // 1. Register Session on Backend
      await _supabase.rpc('register_user_session', params: {
        'p_session_id': _sessionId,
        'p_device_id': _deviceId,
        'p_device_name': meta['device_name'],
        'p_platform': meta['platform'],
        'p_device_model': meta['device_name'],
        'p_os_version': meta['os_version'],
        'p_app_version': '1.0.0',
        'p_browser': meta['platform'] == 'Web' ? 'Chrome' : '',
        'p_ip': '103.42.18.99', // Default approximate IP resolved server-side
        'p_country': 'India',
      });

      // 2. Log activity event if new login
      if (isNewLogin) {
        await _supabase.rpc('log_user_login_event', params: {
          'p_event_type': eventType,
          'p_device_name': meta['device_name'],
          'p_platform': meta['platform'],
          'p_ip': '103.42.18.99',
          'p_country': 'India',
          'p_session_id': _sessionId,
          'p_status': 'success',
          'p_auth_method': authMethod,
        });
      }

      // 3. Subscribe to real-time session revocation listener
      subscribeToRevocationEvents();
    } catch (e) {
      debugPrint('[DeviceSessionService] Error registering session: $e');
    }
  }

  /// Subscribe to real-time revocation channel for current user's session
  void subscribeToRevocationEvents() {
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty) return;

    _realtimeChannel?.unsubscribe();

    try {
      _realtimeChannel = _supabase
          .channel('user_sessions_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'user_sessions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord != null) {
                final String sessId = newRecord['session_id']?.toString() ?? '';
                final String? revokedAt = newRecord['revoked_at']?.toString();

                if (sessId == _sessionId && revokedAt != null && revokedAt.isNotEmpty) {
                  debugPrint('[DeviceSessionService] Current session was remotely revoked!');
                  handleRemoteLogout(
                    reason: 'Your Creania account session was signed out from another device.',
                  );
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[DeviceSessionService] Realtime subscription error: $e');
    }
  }

  /// Fetch active sessions from backend
  Future<void> fetchActiveSessions() async {
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty) return;

    isLoadingDevices.value = true;
    try {
      final res = await _supabase
          .from('user_sessions')
          .select()
          .eq('user_id', userId)
          .isFilter('revoked_at', null)
          .order('last_active_at', ascending: false);

      final list = (res as List).map((e) {
        return UserSession.fromJson(
          Map<String, dynamic>.from(e),
          currentSessionId: _sessionId,
        );
      }).toList();

      activeSessions.assignAll(list);
    } catch (e) {
      debugPrint('[DeviceSessionService] Error fetching active sessions: $e');
    } finally {
      isLoadingDevices.value = false;
    }
  }

  /// Fetch login activity event logs
  Future<void> fetchLoginActivityLogs() async {
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty) return;

    isLoadingLogs.value = true;
    try {
      final res = await _supabase
          .from('user_login_activity')
          .select()
          .eq('user_id', userId)
          .order('login_at', ascending: false)
          .limit(40);

      final list = (res as List).map((e) {
        return LoginActivityLog.fromJson(Map<String, dynamic>.from(e));
      }).toList();

      loginLogs.assignAll(list);
    } catch (e) {
      debugPrint('[DeviceSessionService] Error fetching login activity logs: $e');
    } finally {
      isLoadingLogs.value = false;
    }
  }

  /// Revoke an individual device session
  Future<bool> revokeSession(String targetSessionId, String deviceName) async {
    // Current session protection guard
    if (targetSessionId == _sessionId) {
      Get.snackbar(
        'Action Restricted',
        'You cannot log out your current active device from this screen.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
      );
      return false;
    }

    revokingSessionIds[targetSessionId] = true;

    try {
      final res = await _supabase.rpc('revoke_user_session', params: {
        'p_session_id': targetSessionId,
      });

      final success = res != null && res['success'] == true;
      if (success) {
        activeSessions.removeWhere((s) => s.sessionId == targetSessionId);
        await fetchLoginActivityLogs();
        Get.snackbar(
          'Device Logged Out',
          'Device $deviceName signed out successfully.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return true;
      } else {
        Get.snackbar(
          'Logout Failed',
          'Unable to log out this device. Please try again.',
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
    } catch (e) {
      debugPrint('[DeviceSessionService] Revoke session error: $e');
      Get.snackbar(
        'Logout Error',
        'Unable to log out this device. Please try again.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      revokingSessionIds[targetSessionId] = false;
    }
  }

  /// Revoke all active sessions except current session
  Future<bool> revokeAllOtherSessions() async {
    isRevokingAll.value = true;
    try {
      final res = await _supabase.rpc('revoke_all_other_user_sessions', params: {
        'p_current_session_id': _sessionId,
      });

      final success = res != null && res['success'] == true;
      if (success) {
        await fetchActiveSessions();
        await fetchLoginActivityLogs();
        Get.snackbar(
          'All Other Devices Signed Out',
          'All other devices have been logged out.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return true;
      } else {
        Get.snackbar(
          'Bulk Logout Failed',
          'Unable to log out other devices. Please try again.',
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
    } catch (e) {
      debugPrint('[DeviceSessionService] Revoke all other sessions error: $e');
      Get.snackbar(
        'Bulk Logout Error',
        'Unable to log out other devices. Please try again.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isRevokingAll.value = false;
    }
  }

  /// Validate active status of current session on API or launch
  Future<bool> validateCurrentSession() async {
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty || _sessionId.isEmpty) return true;

    try {
      final res = await _supabase.rpc('validate_user_session', params: {
        'p_session_id': _sessionId,
      });

      if (res != null && res['valid'] == false) {
        if (res['reason'] == 'session_revoked') {
          handleRemoteLogout(
            reason: 'Your session was signed out from another device.',
          );
          return false;
        }
      }
    } catch (e) {
      debugPrint('[DeviceSessionService] Validate session error: $e');
    }
    return true;
  }

  /// Perform remote logout cleanup and redirect to login screen
  Future<void> handleRemoteLogout({
    String reason = 'Your session was signed out from another device.',
  }) async {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefSessionIdKey);
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('[DeviceSessionService] Local cleanup error: $e');
    }

    Get.offAll(() => const LoginScreen());
    Get.snackbar(
      'Session Revoked',
      reason,
      backgroundColor: const Color(0xFFEF4444),
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
      snackPosition: SnackPosition.TOP,
    );
  }
}
