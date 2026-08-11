import 'package:flutter_test/flutter_test.dart';
import 'package:creania/models/user_session_model.dart';

void main() {
  group('Creania Login Activity & Device Session Tests', () {
    test('UserSession identifies current device based on session_id', () {
      final currentSessionId = 'sess_12345_abc';

      final jsonCurrent = {
        'id': 'uuid-1',
        'user_id': 'user-101',
        'session_id': 'sess_12345_abc',
        'device_id': 'dev_iphone',
        'device_name': 'iPhone 15',
        'platform': 'iOS',
        'ip_address': '103.42.18.99',
        'country': 'India',
        'created_at': DateTime.now().toIso8601String(),
        'last_active_at': DateTime.now().toIso8601String(),
      };

      final jsonOther = {
        'id': 'uuid-2',
        'user_id': 'user-101',
        'session_id': 'sess_99999_xyz',
        'device_id': 'dev_windows',
        'device_name': 'Windows PC',
        'platform': 'Windows',
        'ip_address': '182.70.10.42',
        'country': 'India',
        'created_at': DateTime.now().toIso8601String(),
        'last_active_at': DateTime.now().toIso8601String(),
      };

      final session1 = UserSession.fromJson(jsonCurrent, currentSessionId: currentSessionId);
      final session2 = UserSession.fromJson(jsonOther, currentSessionId: currentSessionId);

      expect(session1.isCurrent, isTrue);
      expect(session1.deviceName, equals('iPhone 15'));

      expect(session2.isCurrent, isFalse);
      expect(session2.deviceName, equals('Windows PC'));
    });

    test('LoginActivityLog correctly masks IP address for security privacy', () {
      final log = LoginActivityLog(
        id: 'log-1',
        userId: 'user-101',
        eventType: 'Successful Login',
        deviceName: 'Windows PC',
        platform: 'Windows',
        ipAddress: '103.42.18.99',
        country: 'India',
        authMethod: 'Password + 2FA',
        loginAt: DateTime.now(),
      );

      expect(log.maskedIp, equals('103.xxx.xxx.99'));
    });

    test('Device grouping correctly isolates CURRENT DEVICE from OTHER DEVICES', () {
      final currentSessionId = 'sess_current_777';

      final mockSessions = [
        UserSession(
          id: '1',
          userId: 'u1',
          sessionId: 'sess_current_777',
          deviceId: 'd1',
          deviceName: 'iPhone 15',
          platform: 'iOS',
          createdAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
          isCurrent: true,
        ),
        UserSession(
          id: '2',
          userId: 'u1',
          sessionId: 'sess_other_888',
          deviceId: 'd2',
          deviceName: 'Windows PC',
          platform: 'Windows',
          createdAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
          isCurrent: false,
        ),
        UserSession(
          id: '3',
          userId: 'u1',
          sessionId: 'sess_other_999',
          deviceId: 'd3',
          deviceName: 'MacBook Pro',
          platform: 'macOS',
          createdAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
          isCurrent: false,
        ),
      ];

      UserSession? currentDev;
      final otherDevs = <UserSession>[];

      for (var s in mockSessions) {
        if (s.isCurrent || s.sessionId == currentSessionId) {
          currentDev = s;
        } else {
          otherDevs.add(s);
        }
      }

      expect(currentDev, isNotNull);
      expect(currentDev!.deviceName, equals('iPhone 15'));
      expect(otherDevs.length, equals(2));
      expect(otherDevs.any((d) => d.sessionId == currentSessionId), isFalse);
    });
  });
}
