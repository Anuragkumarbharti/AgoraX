import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import './core/theme.dart';
import './core/performance_config.dart';
import './core/shader_warmup.dart';
import './screens/index.dart';
import './services/room/room_controller.dart';
import './services/chat/chat_controller.dart';
import './services/community/community_controller.dart';
import './services/community/event_controller.dart';
import './services/vault/study_category_controller.dart';
import './services/progression/career_progression_controller.dart';
import './services/memberships/vip_controller.dart';
import './services/memberships/novel_controller.dart';
import './services/user/customization_controller.dart';
import './services/user/premium_identity_controller.dart';
import './services/store/store_controller.dart';
import './services/vault/vault_controller.dart';
import './services/vault/study_vault_controller.dart';
import './services/progression/progression_controller.dart';
import './services/voice/voice_controller.dart';
import './services/store/razorpay_backend_service.dart';
import './services/storage/theme_controller.dart';
import './services/user/user_profile_cache_manager.dart';
import './services/storage/isar_storage_service.dart';
import './services/chat/chat_socket_service.dart';
import './services/storage/admob_service.dart';
import './services/storage/fcm_notification_service.dart';
import './services/network/network_adaptive_manager.dart';
import './services/network/network_connectivity_service.dart';
import './services/network/ultra_network_client.dart';
import './services/network/request_batcher.dart';
import './services/network/delta_sync_manager.dart';
import './services/network/offline_queue_manager.dart';
import './services/network/websocket_resilience_manager.dart';
import './services/network/adaptive_media_manager.dart';

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
  runZonedGuarded(() async {
    // ── 1. Binding & system chrome ──────────────────────────────────
    final binding = WidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = MyHttpOverrides();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Filter background socket disconnect errors
    FlutterError.onError = (FlutterErrorDetails details) {
      final errStr = details.exception.toString();
      if (errStr.contains('SocketException') || errStr.contains('closed socket')) {
        debugPrint('[Network] Handled background socket error gracefully.');
        return;
      }
      FlutterError.presentError(details);
    };

    // ── 2. Shader warmup & pre-frame initialization ───────────────────
    binding.deferFirstFrame();
    try {
      try {
        await const AppShaderWarmup().execute();
      } catch (e) {
        debugPrint('[Main] ShaderWarmup skipped: $e');
      }

      try {
        await PerformanceConfig.initialize();
      } catch (e) {
        debugPrint('[Main] PerformanceConfig init skipped: $e');
      }

      try {
        await AdmobService.initialize();
      } catch (e) {
        debugPrint('[Main] AdmobService init skipped: $e');
      }

      try {
        await Supabase.initialize(
          url: const String.fromEnvironment('SUPABASE_URL',
              defaultValue: 'https://zccrgiplrbeslgpcezul.supabase.co'),
          anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY',
              defaultValue:
                  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjY3JnaXBscmJlc2xncGNlenVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQyMDQyNDAsImV4cCI6MjA5OTc4MDI0MH0.iYRR8y7Z_S0z_ROVzVyvj1M4rv6sWK2q7Z6K7vRwD4g'),
        );
      } catch (e) {
        debugPrint('[Main] Supabase init error: $e');
      }

      try {
        final isarService = IsarStorageService();
        await isarService.init();
        Get.put(isarService);
      } catch (e) {
        debugPrint('[Main] IsarStorageService init error: $e');
      }

      // Register network resilience & adaptive services
      Get.put(NetworkConnectivityService());
      Get.put(NetworkAdaptiveManager());
      Get.put(UltraNetworkClient());
      Get.put(RequestBatcher());
      Get.put(DeltaSyncManager());
      Get.put(OfflineQueueManager());
      Get.put(WebSocketResilienceManager());
      Get.put(AdaptiveMediaManager());

      try {
        await UserProfileCacheManager.initOfflineCache();
      } catch (e) {
        debugPrint('[Main] initOfflineCache error: $e');
      }

      // ── Register critical GetX controllers ─────────────────────────
      Get.put(ThemeController(), permanent: true);
      Get.put(StoreController(), permanent: true);
      Get.put(CareerProgressionController(), permanent: true);
      Get.put(CareerDailyController(), permanent: true);
      Get.put(IdDailyController(), permanent: true);
      Get.put(VipController(), permanent: true);
      Get.put(NovelController(), permanent: true);
      Get.put(ChatController(), permanent: true);
      Get.put(RoomController(), permanent: true);
      Get.put(CustomizationController(), permanent: true);
      Get.put(PremiumIdentityController(), permanent: true);
      Get.put(VaultController(), permanent: true);
      Get.put(ProgressionController(), permanent: true);
      Get.put(StudyVaultController(), permanent: true);
      Get.put(VoiceController(), permanent: true);
    } catch (err, stack) {
      debugPrint('[Main] Pre-frame init error: $err\n$stack');
    } finally {
      binding.allowFirstFrame();
    }

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
  }, (error, stack) {
    final errStr = error.toString();
    if (errStr.contains('SocketException') || errStr.contains('closed socket')) {
      debugPrint('[Network] Handled async background socket disconnect.');
    } else {
      debugPrint('[AppError] Unhandled zone error: $error\n$stack');
    }
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
        title: 'Creaniaa',
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
