import 'package:get/get.dart';
import '../../screens/home/main_screen.dart';

class MainNavigationController extends GetxController {
  static MainNavigationController get to {
    if (!Get.isRegistered<MainNavigationController>()) {
      return Get.put(MainNavigationController(), permanent: true);
    }
    return Get.find<MainNavigationController>();
  }

  final RxInt selectedIndex = 0.obs;

  void changeTab(int index) {
    if (index >= 0 && index <= 4) {
      selectedIndex.value = index;
    }
  }

  void navigateToArena() {
    selectedIndex.value = 2; // Arenas tab index (0: Home, 1: Explore, 2: Arenas, 3: Messages, 4: Profile)
    try {
      Get.until((route) => route.isFirst || Get.currentRoute == '/MainScreen');
    } catch (_) {
      Get.offAll(() => const MainScreen(initialIndex: 2));
    }
  }

  void navigateToMessages() {
    selectedIndex.value = 3; // Messages tab index
    try {
      Get.until((route) => route.isFirst || Get.currentRoute == '/MainScreen');
    } catch (_) {
      Get.offAll(() => const MainScreen(initialIndex: 3));
    }
  }
}
