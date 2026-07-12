import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/theme.dart';
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
import 'services/livekit_service.dart';
import 'services/theme_controller.dart';
import 'services/user_profile_cache_manager.dart';
import 'services/career_daily_controller.dart';
import 'services/id_daily_controller.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://ghtdisjlvqhlglojdcda.supabase.co'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdodGRpc2psdnFobGdsb2pkY2RhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2MDI1MzAsImV4cCI6MjA5OTE3ODUzMH0.fImqA0xi7Y7-EXuTG7idFDhK1Z3XkSlj5GT7tTtVq2w'),
  );

  UserProfileCacheManager.initializeRealtimeSubscription();

  Get.put(StoreController());
  Get.put(CareerProgressionController());
  Get.put(CareerDailyController());
  Get.put(IdDailyController());
  Get.put(StudyCategoryController());
  Get.put(RoomController());
  Get.put(ChatController());
  Get.put(CommunityController());
  Get.put(EventController());
  Get.put(VipController());
  Get.put(NovelController());
  Get.put(CustomizationController());
  Get.put(PremiumIdentityController());
  Get.put(LivekitService());
  Get.put(RazorpayBackendService());
  Get.put(ThemeController());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeCtrl = ThemeController.to;
    return Obx(() => GetMaterialApp(
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
        ));
  }
}
