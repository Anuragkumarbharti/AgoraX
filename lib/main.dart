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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(RoomController());
  Get.put(ChatController());
  Get.put(CommunityController());
  Get.put(EventController());
  Get.put(StudyCategoryController());
  Get.put(CareerProgressionController());
  Get.put(VipController());
  Get.put(NovelController());
  Get.put(CustomizationController());
  Get.put(PremiumIdentityController());
  Get.put(StoreController());
  Get.put(RazorpayBackendService());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => GetMaterialApp(
        title: 'AgoraX',
        theme: AppTheme.darkTheme,
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
        ],
      );
}
