import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../services/chat_controller.dart';
import '../../services/study_vault_controller.dart';
import '../../services/user_progress_sync_service.dart';
import '../home/home_screen.dart';
import '../explore/explore_screen.dart';
import '../rooms/rooms_screen.dart';
import '../chat/chats_list_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    UserProgressSyncService.syncFromSupabase();
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const ExploreScreen(),
    const RoomsScreen(),
    const ChatsListScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Ensure StudyVaultController is registered
    if (!Get.isRegistered<StudyVaultController>()) {
      Get.put(StudyVaultController());
    }
    // Ensure ChatController is registered
    if (!Get.isRegistered<ChatController>()) {
      Get.put(ChatController());
    }
    final chatCtrl = Get.find<ChatController>();

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Obx(() {
        final unread = chatCtrl.totalUnread;
        return BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_filled),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search),
              activeIcon: Icon(Icons.search),
              label: 'Explore',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.radio_button_checked_outlined),
              activeIcon: Icon(Icons.radio_button_checked),
              label: 'Arenas',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
                backgroundColor: AppTheme.primaryColor,
                child: const Icon(Icons.chat_bubble_outline_rounded),
              ),
              activeIcon: Badge(
                isLabelVisible: unread > 0,
                label: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
                backgroundColor: AppTheme.primaryColor,
                child: const Icon(Icons.chat_bubble_rounded),
              ),
              label: 'Messages',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        );
      }),
    );
  }
}
