import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:creania/core/theme.dart';
import '../../services/chat_controller.dart';
import '../../services/study_vault_controller.dart';
import '../../services/user_progress_sync_service.dart';
import '../../services/voice/room_voice_manager.dart';
import '../../services/user_profile_cache_manager.dart';
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
    // Register lazy controllers once here — never inside build()
    if (!Get.isRegistered<StudyVaultController>()) {
      Get.put(StudyVaultController());
    }
    UserProgressSyncService.syncFromSupabase();

    // Preload ZEGOCLOUD engine and fetch token asynchronously in the background
    final currentUid = UserProfileCacheManager.currentUserId;
    if (currentUid.isNotEmpty) {
      RoomVoiceManager().preloadEngine(currentUid);
    }
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    ExploreScreen(),
    RoomsScreen(),
    ChatsListScreen(),
    ProfileScreen(),
  ];

  Widget _buildAnimatedBadgeIcon(int unread, IconData iconData) {
    final String labelStr = unread > 99 ? '99+' : '$unread';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(iconData),
        if (unread > 0)
          Positioned(
            top: -6,
            right: -10,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Container(
                key: ValueKey<String>(labelStr),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  labelStr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatCtrl = Get.find<ChatController>();

    return Scaffold(
      // IndexedStack keeps every tab alive — zero rebuild on tab switch
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Obx(() {
        final unread = chatCtrl.totalUnread;
        return BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          iconSize: AppDimensions.minIconSize,
          selectedItemColor: context.primaryColor,
          unselectedItemColor: context.textSecondary,
          selectedLabelStyle: GoogleFonts.poppins(
            fontSize: AppTypography.caption,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: AppTypography.caption,
          ),
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
              icon: _buildAnimatedBadgeIcon(
                  unread, Icons.chat_bubble_outline_rounded),
              activeIcon:
                  _buildAnimatedBadgeIcon(unread, Icons.chat_bubble_rounded),
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
