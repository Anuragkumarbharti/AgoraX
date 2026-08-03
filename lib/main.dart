import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'core/theme.dart';
import 'core/performance_config.dart';
import 'core/shader_warmup.dart';
import 'screens/index.dart';
import 'services/room_controller.dart';
import 'services/chat_controller.dart';
import 'services/community_controller.dart';
import 'services/event_controller.dart';
import 'services/study_category_controller.dart';
import 'services/career_progression_controller.dart';
import 'services/vip_controller.dart';
import 'services/novel_controller.dart';
import 'services/customization_controller.dart';
import 'services/premium_identity_controller.dart';
import 'services/store_controller.dart';
import 'services/razorpay_backend_service.dart';
import 'services/theme_controller.dart';
import 'services/user_profile_cache_manager.dart';
import 'services/isar_storage_service.dart';
import 'services/chat_socket_service.dart';
import 'services/admob_service.dart';
import 'services/fcm_notification_service.dart';
import 'services/network_adaptive_manager.dart';
import 'services/network_connectivity_service.dart';
import 'services/ultra_network_client.dart';
import 'services/request_batcher.dart';
import 'services/delta_sync_manager.dart';
import 'services/offline_queue_manager.dart';
import 'services/websocket_resilience_manager.dart';
import 'services/adaptive_media_manager.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  // ── 1. Binding & system chrome ──────────────────────────────────
  final binding = WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // ── 2. Shader warmup (eliminates first-frame jank) ───────────────
  binding.deferFirstFrame();
  await const AppShaderWarmup().execute();

  // ── 3. Detect device refresh rate ────────────────────────────────
  await PerformanceConfig.initialize();

  // ── 4. Critical services (blocking — needed before first screen) ──
  await AdmobService.initialize();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL',
        defaultValue: 'https://zccrgiplrbeslgpcezul.supabase.co'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjY3JnaXBscmJlc2xncGNlenVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQyMDQyNDAsImV4cCI6MjA5OTc4MDI0MH0.iYRR8y7Z_S0z_ROVzVyvj1M4rv6sWK2q7Z6K7vRwD4g'),
  );

  final isarService = IsarStorageService();
  await isarService.init();
  Get.put(isarService);

  // Register network resilience & adaptive services
  Get.put(NetworkConnectivityService());
  Get.put(NetworkAdaptiveManager());
  Get.put(UltraNetworkClient());
  Get.put(RequestBatcher());
  Get.put(DeltaSyncManager());
  Get.put(OfflineQueueManager());
  Get.put(WebSocketResilienceManager());
  Get.put(AdaptiveMediaManager());

  await UserProfileCacheManager.initOfflineCache();

  // ── 5. Register critical GetX controllers ─────────────────────────
  Get.put(ThemeController());
  Get.put(StoreController());
  Get.put(CareerProgressionController());
  Get.put(CareerDailyController());
  Get.put(IdDailyController());
  Get.put(VipController());
  Get.put(NovelController());
  Get.put(ChatController());
  Get.put(RoomController());
  Get.put(CustomizationController());
  Get.put(PremiumIdentityController());

  // ── 6. Render the app immediately ────────────────────────────────
  binding.allowFirstFrame();
  runApp(const MyApp());

  // ── 7. Defer non-critical services to after first frame ───────────
  SchedulerBinding.instance.addPostFrameCallback((_) async {
    // Socket and realtime — non-blocking background
    final socketService = ChatSocketService();
    socketService.init();
    Get.put(socketService);

    UserProfileCacheManager.initializeRealtimeSubscription();
    UserProfileCacheManager.syncDeltaProfiles();

    Get.put(StudyCategoryController());
    Get.put(CommunityController());
    Get.put(EventController());
    Get.put(RazorpayBackendService());

    final fcmService = FCMNotificationService();
    Get.put(fcmService);
    fcmService.init(); // fire-and-forget
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeCtrl = ThemeController.to;
    return Obx(() {
      final pref = themeCtrl.currentThemePreference.value;
      final Brightness brightness = MediaQuery.platformBrightnessOf(context);
      final bool isDark = pref == 'dark' || (pref == 'system' && brightness == Brightness.dark);

      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ));

      return GetMaterialApp(
        title: 'Creania',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeCtrl.activeThemeMode,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
        getPages: [
          GetPage(
            name: '/',
            page: () => const SplashScreen(),
          ),
          GetPage(
            name: '/store',
            page: () => const StoreHomeScreen(),
          ),
          GetPage(
            name: '/checkout',
            page: () => const CheckoutScreen(productName: '', category: '', basePrice: 0, duration: ''),
          ),
          GetPage(
            name: '/membership_center',
            page: () => const MembershipCenterScreen(),
          ),
        ],
      );
    });
  }
}
