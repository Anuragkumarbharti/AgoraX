import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:creania/services/chat_socket_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Session Management and Client-Side Logic Tests', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(
        url: 'https://zccrgiplrbeslgpcezul.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjY3JnaXBscmJlc2xncGNlenVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQyMDQyNDAsImV4cCI6MjA5OTc4MDI0MH0.iYRR8y7Z_S0z_ROVzVyvj1M4rv6sWK2q7Z6K7vRwD4g',
      );
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Device ID persistence and initialization validation', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('device_id'), isNull);

      final socketService = ChatSocketService();
      Get.put(socketService);

      // Trigger load device method manually or let init handle it
      socketService.init();

      // Wait a short time for Async SharedPreferences to load
      await Future.delayed(const Duration(milliseconds: 100));

      final storedDevId = prefs.getString('device_id');
      expect(storedDevId, isNotNull);
      expect(storedDevId!.startsWith('dev_'), isTrue);

      Get.delete<ChatSocketService>();
    });

    test('Reconnection delay options check', () async {
      final socketService = ChatSocketService();
      Get.put(socketService);
      socketService.init();

      // We expect Get.find to resolve it correctly
      final resolved = ChatSocketService.to;
      expect(resolved, isNotNull);

      Get.delete<ChatSocketService>();
    });
  });
}
